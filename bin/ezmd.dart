import 'dart:io';

/*import 'package:dotenv/dotenv.dart' as dotenv;*/
import 'package:spotify/spotify.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as path;
import 'package:args/args.dart';
import 'package:eztags/eztags.dart';
import 'package:uuid/uuid.dart';

bool verbose = false;
final uuid = Uuid();

String sid = Platform.environment["SPOTIFY_CLIENT_ID"]!;
String sse = Platform.environment["SPOTIFY_CLIENT_SECRET"]!;

void log(Object? o) {
  if (verbose) print(o.toString());
}

class Youtube extends YoutubeExplode {
  Future<VideoId> getSongId(String query) async {
    VideoSearchList vs;
    vs = await search.search(query);
    if (vs.isEmpty) {
      throw VideoUnavailableException("$query turned up no results");
    }
    return vs.first.id;
  }

  Future<Stream<List<int>>> downloadSongFromId(VideoId id) async {
    final manifest = await videos.streamsClient.getManifest(id);
    final sinfo = manifest.audioOnly.withHighestBitrate();
    return videos.streamsClient.get(sinfo);
  }

  Future<Stream> downloadSong(String query) async =>
      downloadSongFromId(await getSongId(query));

  Future<void> downloadSongToMp3(String query, String tempname) async {
    log("Downloading first Youtube result from query '$query'");
    final stream = await downloadSong(query);
    final tempstream = File("$tempname.webm").openWrite(mode: FileMode.write);
    await stream.pipe(tempstream);
    await tempstream.flush();
    await tempstream.close();
    log("Downlodaded .webm file to $tempname.webm");

    // Convert webm to mp3 with ffmpeg
    log("Converting .webm to .mp3");
    final ffmpegargs =
        "-i $tempname.webm -vn -ab 128k -ar 44100 -y $tempname.mp3";
    await Process.run('ffmpeg', ffmpegargs.split(' '));
    log("Converted");
  }
}

class Spotify extends SpotifyApi {
  Spotify()
      : super(SpotifyApiCredentials(sid, sse));

  Future<Track?> _getSongMetadataByQuery(String query) async {
    Page page =
        (await search.get(query, types: [SearchType.track]).first()).first;
    final item = page.items?.first;
    if (item is Track) return item;
    return null;
  }

  Future<Track?> _getSongMetadataById(String query) async {
    Page page =
        (await search.get(query, types: [SearchType.track]).first()).first;
    final item = page.items?.first;
    if (item is Track) return item;
    return null;
  }

  Future<Map<String, String>?> getSongMetadata(
      {String? query, String? id}) async {
    Track? song;
    if (query != null) {
      song = await _getSongMetadataByQuery(query);
    } else if (id != null) {
      song = await _getSongMetadataById(id);
    }
    if (song == null) return null;
    return extractSongMetadata(song);
  }

  Future<List<Track>?> getPlaylistTracks(String link) async {
    final id = link.split('/').last.split('?').first;
    final playlist = await Playlists(this).get(id);
    final tracks = playlist.tracks?.itemsNative;
    return tracks?.map((item) => Track.fromJson(item["track"])).toList();
  }

  Future<List<String>?> getGenres(ArtistSimple? artist) async {
    if (artist == null) return null;
    final artistFull = await Artists(this).get(artist.id!);
    return artistFull.genres;
  }
}

Future<Map<String, String>?> extractSongMetadata(Track? song) async {
  if (song == null) return null;
  final artworkAll = song.album!.images!;
  // get middle artwork in case theres a lot
  final artwork = artworkAll[artworkAll.length ~/ 2];
  final genres = await spotify.getGenres(song.artists!.first);
  String genre = "";
  if (genres != null && genres.isNotEmpty) {
    genre = genres.first;
  }
  return {
    // data to be transfered to other functio
    "query": "${song.artists!.first.name} - ${song.name!}",

    // actual tags
    "title": song.name!,
    // artists name must be separated by "/" (ID3v2 standard)
    "artist": song.artists!.map((a) => a.name).join("/"),
    "album": song.album!.name!,
    "year": song.album!.releaseDate!.substring(0, 4),
    "track": song.trackNumber.toString(),
    "artwork": artwork.url ?? "",
    "duration": song.durationMs.toString(),
    "genre": genre,
  };
}

final yt = Youtube();
final spotify = Spotify();

void downloadSongFromQuery(String query, String outPath,
    {bool lyrics = false}) async {
  log("Downloading '$query' to '$outPath'");

  String? properQuery;

  final tags = await spotify.getSongMetadata(query: query);
  if (tags == null) {
    properQuery = query;
  } else {
    properQuery = tags.remove("query")!;
  }

  // appending " Lyrics" to the query can sometimes improve music search results in Youtube
  if (lyrics) properQuery = properQuery + " Lyrics";
  downloadAndAddTags(query, outPath, TagList.fromMap(tags ?? {}));
}

void downloadSongFromTrack(Track? song, String outPath,
    {bool lyrics = false}) async {
  if (song == null) return;

  final tags = await extractSongMetadata(song);
  String query = tags!.remove("query")!;

  // appending " Lyrics" to the query can sometimes improve music search results in Youtube
  if (lyrics) query = query + " Lyrics";
  downloadAndAddTags(query, outPath, TagList.fromMap(tags));
}

Future<void> downloadAndAddTags(
    String query, String outPath, TagList tags) async {
  String tempname = "/tmp/${uuid.v4()}";
  try {
    await yt.downloadSongToMp3(query, tempname);
  } catch (e) {
    throw Exception("Failed to download $query");
  }

  log("Writing tags to $query.mp3");
  final mp3Bytes = File("$tempname.mp3").readAsBytesSync();
  String filename = path.join(outPath, query.replaceAll('/', '-'));
  final f = File("$filename.mp3");
  f.writeAsBytesSync(await makeId3v2(tags) + mp3Bytes);

  log("Downlodaded '$query'");
}

void main(List<String> arguments) async {
  /*dotenv.load();*/
  String? outPath;
  String? query;

  final parser = ArgParser();
  parser.addOption("folder",
      abbr: "o", help: "Target folder", defaultsTo: null);
  parser.addOption("intype",
      abbr: "t",
      help: "How to interpret the input\n"
          "file: input is a file to be read line by line.\n"
          "query: input will be interpreted as a single query\n"
          "spotify: input will be interpreted as links to a spotify playlist",
      allowed: ["file", "query", "spotify"],
      defaultsTo: "query");
  parser.addFlag("lyrics",
      abbr: "l",
      help: "Append ' Lyrics' to the Youtube query",
      defaultsTo: false);
  parser.addFlag("verbose",
      abbr: "v", help: "Print out extra information", defaultsTo: false);
  final results = parser.parse(arguments);

  verbose = results["verbose"] == true;

  // Get target folder
  outPath = results["folder"] ?? getMusicFolder();
  if (outPath == null || outPath.isEmpty) {
    stderr.writeln("Unable to get output path");
    return;
  }

  // Get query and download song
  switch (results["intype"]) {
    case "query":
      query = results.rest.join(" ");
      downloadSongFromQuery(query, outPath);
      break;
    case "file":
      for (final filename in results.rest) {
        for (final query in File(filename).readAsLinesSync()) {
          try {
            downloadSongFromQuery(query.trim(), outPath);
          } catch (e) {
            continue;
          }
        }
      }
      break;
    case "spotify":
      for (final link in results.rest) {
        for (final song in (await spotify.getPlaylistTracks(link)) ?? []) {
          try {
            downloadSongFromTrack(song, outPath);
          } catch (e) {
            continue;
          }
        }
      }
      break;
  }
}

String? getMusicFolder() {
  String? musicPath;

  if (Platform.isMacOS || Platform.isLinux) {
    musicPath = path.join(Platform.environment["HOME"]!, "Music");
  } else if (Platform.isWindows) {
    musicPath = path.join(Platform.environment["UserProfile"]!, "Music");
  }

  return musicPath;
}
