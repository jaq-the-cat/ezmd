import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:spotify/spotify.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as path;
import 'package:args/args.dart';
import 'id3info.dart';

class Youtube extends YoutubeExplode {
  Future<VideoId> getSongId(String query) async {
    SearchList vs;
    vs = await search.getVideos(query);
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

void downloadSongTo(String query, String path) async {
  String? songName = "Numb";
  String? spotifiedQuery = "Linkin Park - Numb";
  Map<String, String?> tags = {};

  spotify.getSongMetadata(query).then((song) {
    if (song != null) {
      songName = song.name;
      spotifiedQuery =
          "$songName - ${song.artists!.map((a) => a.name).join(", ")}";
      var artworkAll = song.album!.images!;
      var artwork = artworkAll[artworkAll.length ~/ 2];
      tags = {
        "title": songName!,
        "artist": song.artists!.map((a) => a.name).join("/"),
        "genre": song.artists!.first.genres?.first,
        "album": song.album!.name!,
        "year": song.album!.releaseDate!.substring(0, 4),
        "artwork": artwork.url!,
      };
    }
  });

  if (spotifiedQuery == null) return;

  var stream = await yt.downloadSong(spotifiedQuery!);

  var f = File("$path/$songName.mp3");
  f.writeAsBytesSync(await makeId3Information(tags));
  var fstream = f.openWrite(mode: FileMode.append);
  await stream.pipe(fstream);
  await fstream.flush();
  await fstream.close();
}

void main(List<String> arguments) async {
  dotenv.load();
  String? musicPath;
  String? query;

  var parser = ArgParser();
  parser.addOption("folder",
      abbr: "f", help: "Target folder", defaultsTo: null);
  var results = parser.parse(arguments);

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
    downloadSongTo(query, musicPath);
  }
}
