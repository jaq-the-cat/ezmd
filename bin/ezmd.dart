import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:spotify/spotify.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as path;
import 'package:args/args.dart';
import 'id3info.dart';
import 'imagedl.dart';

bool verbose = false;

void log(Object? o) {
  if (verbose) print(o.toString());
}

class Youtube extends YoutubeExplode {
  Future<VideoId> getSongId(String query) async {
    VideoSearchList vs;
    vs = await search.search(query);
    return vs.first.id;
  }

  Future<Stream> downloadSongFromId(VideoId id) async {
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
    var item = page.items?.first;
    if (item is Track) return item;
    return null;
  }
}

final yt = Youtube();
final spotify = Spotify();

void downloadSongTo(String query, String path, {bool lyrics = false}) async {
  String? songName;
  String? spotifiedQuery;
  Map<String, dynamic> tags = {};

  var song = await spotify.getSongMetadata(query);
  if (song != null) {
    songName = song.name;
    log("Found song: $songName");

    // convert query to a nicer format
    spotifiedQuery =
        "${song.artists!.map((a) => a.name).join(", ")} - $songName";
    var artworkAll = song.album!.images!;
    // get middle artwork in case theres a lot
    var artwork = artworkAll[artworkAll.length ~/ 2];
    var genres = song.artists?.first.genres;
    tags = {
      "title": songName!,
      // artists name must be separated by "/" (ID3v2 standard)
      "artist": song.artists!.map((a) => a.name).join("/"),
      "genres": genres,
      "album": song.album!.name!,
      "year": song.album!.releaseDate!.substring(0, 4),
      "track": song.trackNumber.toString(),
      "artwork": await downloadImage(artwork.url!),
    };
    log("Found metadata: $tags");
  }

  // appending " Lyrics" to the query can sometimes improve music search results in Youtube
  if (lyrics) spotifiedQuery = spotifiedQuery! + " Lyrics";

  log("Downloading first Youtube result from query '$spotifiedQuery'");
  var stream = await yt.downloadSong(spotifiedQuery!);

  var f = File("$path/${song!.artists!.first.name} - $songName.mp3");
  f.writeAsBytesSync(await makeId3Information(tags));
  var fstream = f.openWrite(mode: FileMode.append);
  await stream.pipe(fstream);
  await fstream.flush();
  await fstream.close();
  log("Done");
}

void main(List<String> arguments) async {
  dotenv.load();
  String? musicPath;
  String? query;

  var parser = ArgParser();
  parser.addOption("folder",
      abbr: "f", help: "Target folder", defaultsTo: null);
  parser.addFlag("lyrics",
      abbr: "l",
      help: "Whether to append ' Lyrics' to the Youtube query",
      defaultsTo: false);
  parser.addFlag("verbose",
      abbr: "v", help: "Print out extra information", defaultsTo: false);
  var results = parser.parse(arguments);

  // Verbose?
  verbose = results["verbose"] == true;

  // Get target folder
  if (results["folder"] != null) {
    // If it was set in the CLI
    musicPath = results["folder"];
  } else {
    // Otherwise, get it automatically
    if (Platform.isMacOS || Platform.isLinux) {
      musicPath = path.join(Platform.environment["HOME"]!, "Music");
    } else if (Platform.isWindows) {
      musicPath = path.join(Platform.environment["UserProfile"]!, "Music");
    }

    // If failed to detect platform
    if (musicPath == null) {
      stderr.writeln("[!] Failed to detect platform");

      // Read path to Music/ directly from user
      stdout.write("Full path to Music/> ");
      musicPath = stdin.readLineSync();
    }
  }

  // Get query
  query = results.rest.join(" ");

  // Actually download song
  if (musicPath != null && musicPath.isNotEmpty && query.isNotEmpty) {
    log("Downloading '$query' to '$musicPath'");
    downloadSongTo(query, musicPath, lyrics: results["lyrics"]);
  }
}
