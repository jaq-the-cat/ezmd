import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:spotify/spotify.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path/path.dart' as path;
import 'package:args/args.dart';
import 'package:eztags/eztags.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

bool verbose = false;
bool lyrics = false;

final uuid = Uuid();

final parser = ArgParser();
const apiUrl = "https://ezmd.herokuapp.com";

void log(Object? o) {
  if (verbose) print(o.toString());
}

class Youtube extends YoutubeExplode {
  Future<VideoId?> getSongId(String query) async {
    VideoSearchList vs;
    vs = await search.search(query);
    if (vs.isEmpty) {
      return null;
    }
    return vs.first.id;
  }

  Future<Stream<List<int>>?> downloadSongFromId(VideoId? id) async {
    if (id == null) return null;
    final manifest = await videos.streamsClient.getManifest(id);
    final sinfo = manifest.audioOnly.withHighestBitrate();
    return videos.streamsClient.get(sinfo);
  }

  Future<Stream<List<int>>?> downloadSong(String query) async =>
      downloadSongFromId(await getSongId(query));

  Future<void> downloadSongToMp3(String query, String tempname) async {
    // Lyrics can sometimes help narrow down search results
    if (lyrics) query = "$query Lyrics";
    log("Downloading first Youtube result from query '$query'");
    final stream = await downloadSong(query);
    final tempstream = File("$tempname.webm").openWrite(mode: FileMode.write);
    if (stream == null) {
      throw VideoUnavailableException("Failed to download $query");
    }
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

class Spotify {
  Spotify();

  Future<dynamic> _request(String pathargs) async {
    final r = await http.get(Uri.parse(apiUrl + pathargs));
    if (r.statusCode == 200) return jsonDecode(r.body);
  }

  Future<Map<String, String>?> getSongMetadata(
      {String? query, String? id}) async {
    List<dynamic>? json;
    if (id != null) json = await _request("/track?id=$id");
    if (query != null) json = await _request("/track?query=$query");
    if (json == null || json.isEmpty) return null;
    return extractSongMetadata(Track.fromJson(json.first));
  }

  Future<List<Track>?> getPlaylistTracks(String link) async {
    final id = link.split('/').last.split('?').first;
    final tracks = await _request("/playlist/tracks?id=$id");
    if (tracks == null) return null;
    return List<Track>.from(
        tracks.map((item) => Track.fromJson(item["track"])));
  }

  Future<List<String>?> getGenres(ArtistSimple? artist) async {
    if (artist == null) return null;
    return List<String>.from(await _request("/artist/genres?id=${artist.id}"));
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

void downloadSongFromQuery(String query, String outPath) async {
  log("Downloading '$query' to '$outPath'");

  String? properQuery;

  final tags = await spotify.getSongMetadata(query: query);
  if (tags == null) {
    properQuery = query;
  } else {
    properQuery = tags.remove("query")!;
  }

  // appending " Lyrics" to the query can sometimes improve music search results in Youtube
  downloadAndAddTags(properQuery, outPath, TagList.fromMap(tags ?? {}));
}

void downloadSongFromTrack(Track? song, String outPath) async {
  if (song == null) return;

  final tags = await extractSongMetadata(song);
  String query = tags!.remove("query")!;

  // appending " Lyrics" to the query can sometimes improve music search results in Youtube
  downloadAndAddTags(query, outPath, TagList.fromMap(tags));
}

Future<void> downloadAndAddTags(
    String query, String outPath, TagList tags) async {
  String tempname = "/tmp/${uuid.v4()}";
  try {
    await yt.downloadSongToMp3(query, tempname);
  } on VideoUnavailableException catch (e) {
    stderr.writeln("Failed to download video $query");
    return;
  }

  log("Writing tags to $query.mp3");
  try {
    final mp3Bytes = File("$tempname.mp3").readAsBytesSync();
    String filename = path.join(outPath, query.replaceAll('/', '-'));
    final f = File("$filename.mp3");
    f.writeAsBytesSync(await makeId3v2(tags) + mp3Bytes);

    log("Downlodaded '$query'");
  } catch (e) {
    stderr.writeln("Failed to add tags to $query");
  }
}

String help() {
  return "ezmd: Easily download songs from a query, file of queries or a spotify playlist\n" +
      parser.usage;
}

void main(List<String> arguments) async {
  String? outPath;
  String? query;

  parser.addFlag("help", abbr: "h");
  parser.addOption("folder",
      abbr: "f", help: "Target folder", defaultsTo: null);
  parser.addOption("intype",
      abbr: "t",
      help: "How to interpret the input",
      allowed: ["query", "file", "spotify"],
      defaultsTo: "query");
  parser.addFlag("lyrics",
      abbr: "l",
      help: "Append ' Lyrics' to the Youtube query",
      defaultsTo: false);
  parser.addFlag("verbose",
      abbr: "v", help: "Print out extra information", defaultsTo: false);
  try {
    final results = parser.parse(arguments);

    if (results["help"] == true) {
      print(help());
      return;
    }

    lyrics = results["lyrics"] == true;
    verbose = results["verbose"] == true;

    // Get target folder
    outPath = results["folder"] ?? "./";
    if (outPath == null || outPath.isEmpty) {
      stderr.writeln("Invalid output path");
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
  } on ArgParserException catch (_) {
    stderr.writeln("Argument error\n${help()}");
  } catch (e, stacktrace) {
    stderr.writeln(
        "Something went wrong! Please send the log file generated at /tmp/ezmdlog.log to the developer at jaq.cat@protonmail.ch");
    File("/tmp/ezmdlog.log").writeAsString("$e\n$stacktrace");
  }
}
