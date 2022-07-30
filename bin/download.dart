import 'dart:io';

import 'package:spotify/spotify.dart';
import 'package:path/path.dart' as path;
import 'package:eztags/eztags.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:uuid/uuid.dart';

import 'spotify.dart';
import 'yt.dart';

class Download {
  void Function(Object? o) log;
  final Youtube yt;
  final Spotify spotify;
  final uuid = Uuid();

  Download({required this.log})
      : yt = Youtube(log: log),
        spotify = Spotify();

  Future<List<Track>?> playlistTracks(String link) async =>
      spotify.getPlaylistTracks(link);

  void fromQuery(String query, String outPath) async {
    try {
      log("Downloading '$query' to '$outPath'");

      String? properQuery;

      final tags = await spotify.getSongMetadata(query: query);
      if (tags == null) {
        properQuery = query;
      } else {
        properQuery = tags.remove("query")!;
      }

      withTags(properQuery, outPath, TagList.fromMap(tags ?? {}));
    } catch (e, stacktrace) {
      stderr.writeln(
          "Something went wrong with the query $query! Please send the log file generated at /tmp/ezmdlog.log to the developer at jaq.cat@protonmail.ch");
      File("/tmp/ezmdlog.log").writeAsString("$e\n$stacktrace");
    }
  }

  void fromTrack(Track? song, String outPath) async {
    try {
      if (song == null) return;

      final tags = await spotify.extractSongMetadata(song);
      String query = tags!.remove("query")!;

      await withTags(query, outPath, TagList.fromMap(tags));
    } catch (e, stacktrace) {
      stderr.writeln(
          "Something went wrong with track ${song!.name}! Please send the log file generated at /tmp/ezmdlog.log to the developer at jaq.cat@protonmail.ch");
      File("/tmp/ezmdlog.log").writeAsString("$e\n$stacktrace");
    }
  }

  Future<void> withTags(String query, String outPath, TagList tags) async {
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
}