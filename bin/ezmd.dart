import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:spotify/spotify.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as path;
import 'package:args/args.dart';
import 'package:uuid/uuid.dart';
import 'id3v2info.dart';

bool verbose = false;
final uuid = Uuid();

void log(Object? o) {
  if (verbose) print(o.toString());
}

class Youtube extends YoutubeExplode {
  Future<VideoId> getSongId(String query) async {
    VideoSearchList vs;
    vs = await search.search(query);
    return vs.first.id;
  }

  Future<Stream<List<int>>> downloadSongFromId(VideoId id) async {
    final manifest = await videos.streamsClient.getManifest(id);
    final sinfo = manifest.audioOnly.withHighestBitrate();
    return videos.streamsClient.get(sinfo);
  }

  Future<Stream> downloadSong(String query) async =>
      downloadSongFromId(await getSongId(query));
}

class Spotify extends SpotifyApi {
  Spotify()
      : super(SpotifyApiCredentials(dotenv.env["SPOTIFY_CLIENT_ID"],
            dotenv.env["SPOTIFY_CLIENT_SECRET"]));

  Future<Track?> getSongMetadata(String query) async {
    Page page =
        (await search.get(query, types: [SearchType.track]).first()).first;
    final item = page.items?.first;
    if (item is Track) return item;
    return null;
  }

  Future<List<String>?> getGenres(ArtistSimple? artist) async {
    if (artist == null) return null;
    final artistFull = await Artists(spotify).get(artist.id!);
    return artistFull.genres;
  }
}

final yt = Youtube();
final spotify = Spotify();

void downloadSongTo(String query, String path, {bool lyrics = false}) async {
  log("Downloading '$query' to '$path'");

  String? songName;
  String? correctedQuery;
  String? finalFilename;
  FrameList frames = FrameList();

  final song = await spotify.getSongMetadata(query);
  if (song != null) {
    songName = song.name;
    log("Found song: $songName");

    // convert query to a nicer format
    correctedQuery =
        "${song.artists!.map((a) => a.name).join(", ")} - $songName";
    final artworkAll = song.album!.images!;
    // get middle artwork in case theres a lot
    final artwork = artworkAll[artworkAll.length ~/ 2];
    final genres = spotify.getGenres(song.artists!.first);
    frames = FrameList.fromMap({
      "title": songName!,
      // artists name must be separated by "/" (ID3v2 standard)
      "artist": song.artists!.map((a) => a.name).join("/"),
      "album": song.album!.name!,
      "year": song.album!.releaseDate!.substring(0, 4),
      "track": song.trackNumber.toString(),
      "artwork": artwork.url ?? "",
      "duration": song.durationMs.toString(),
      "genre": (await genres)?.first,
    });
    log("Found metadata: $frames");
    finalFilename = "$path/${song.artists!.first.name} - $songName";
  } else {
    stderr.writeln(
        "Couldn't find song on Spotify, using query as filename instead");
    correctedQuery = query;
    finalFilename = "$path/$correctedQuery";
  }

  // appending " Lyrics" to the query can sometimes improve music search results in Youtube
  if (lyrics) correctedQuery = correctedQuery + " Lyrics";

  log("Downloading first Youtube result from query '$correctedQuery'");
  final stream = await yt.downloadSong(correctedQuery);
  final tempid = uuid.v4();
  final tempstream = File("/tmp/$tempid.webm").openWrite(mode: FileMode.write);
  await stream.pipe(tempstream);
  await tempstream.flush();
  await tempstream.close();
  log("Downlodaded .webm file to /tmp/$tempid.webm");

  // Convert webm to mp3 with ffmpeg
  log("Converting .webm to .mp3");
  final ffmpegargs =
      "-i /tmp/$tempid.webm -vn -ab 128k -ar 44100 -y /tmp/$tempid.mp3";
  await Process.run('ffmpeg', ffmpegargs.split(' '));
  log("Converted");

  log("Writing tags to $finalFilename.mp3");
  final mp3Bytes = File("/tmp/$tempid.mp3").readAsBytesSync();
  final f = File("$finalFilename.mp3");
  f.writeAsBytesSync(await makeId3v2(frames) + mp3Bytes);

  log("Downlodaded '$correctedQuery'");
}

String getMusicFolder() {
  String? musicPath;

  if (Platform.isMacOS || Platform.isLinux) {
    musicPath = path.join(Platform.environment["HOME"]!, "Music");
  } else if (Platform.isWindows) {
    musicPath = path.join(Platform.environment["UserProfile"]!, "Music");
  }

  // If failed to detect platform
  if (musicPath == null) {
    stderr.writeln("[!] Failed to detect platform");

    // Read path directly from the user
    stdout.write("Target path/> ");
    musicPath = stdin.readLineSync();
  }

  return musicPath ?? "";
}

void main(List<String> arguments) async {
  dotenv.load();
  String? outPath;
  String? query;

  final parser = ArgParser();
  parser.addOption("folder",
      abbr: "o", help: "Target folder", defaultsTo: null);
  parser.addOption("intype",
      abbr: "t",
      help:
          "Input type. 'file' indicates the input is a file to be read line by "
          "line. 'query' means the input will be interpreted as a single query",
      allowed: ["file", "query"],
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
    stderr.writeln("Unable to get target path");
    return;
  }

  // Get query and download song
  switch (results["intype"]) {
    case "query":
      query = results.rest.join(" ");
      downloadSongTo(query, outPath);
      break;
    case "file":
      for (String filename in results.rest) {
        for (String query in File(filename).readAsLinesSync()) {
          downloadSongTo(query.trim(), outPath);
        }
      }
      break;
  }
}
