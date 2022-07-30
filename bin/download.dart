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

  final List<String> _failed = [];
  List<String> get failed => _failed;

  Download({required this.log})
      : yt = Youtube(log: log),
        spotify = Spotify();

  Future<List<Track>?> playlistTracks(String link) async =>
      spotify.getPlaylistTracks(link);

  Map<String, String> fixTags(Map<String, String?>? tags) {
    if (tags == null) return {};
    for (final tag in tags.entries) {
      if (tag.value == null) tags.remove(tag.key);
    }
    return Map<String, String>.from(tags);
  }

  void fromQuery(String query, String outPath) async {
    log("Downloading '$query' to '$outPath'");
    String? properQuery;
    try {
      final tags = await spotify.getSongMetadata(query: query);
      if (tags == null) {
        properQuery = query;
      } else {
        properQuery = tags.remove("query")!;
      }

      withTags(properQuery, outPath, TagList.fromMap(fixTags(tags)));
    } catch (e, stacktrace) {
      stderr.writeln(
          "Something went wrong while downloading $query! Please send the log file generated at /tmp/ezmdlog.log to the developer at jaq.cat@protonmail.ch");
      File("/tmp/ezmdlog.log").writeAsString("$e\n$stacktrace");
      failed.add(query);
    }
  }

  void fromTrackLink(String link, String outPath) async {
    final id = link.split("/").last.split("?").first;
    String? properQuery;

    try {
      log("Downloading '$link' to '$outPath'");

      final tags = await spotify.getSongMetadata(id: id);
      if (tags == null) {
        stderr.writeln("Error fetching information on $link");
        return;
      }
      properQuery = tags.remove("query")!;

      withTags(properQuery, outPath, TagList.fromMap(fixTags(tags)));
    } catch (e, stacktrace) {
      stderr.writeln(
          "Something went wrong while downloading $link! Please send the log file generated at /tmp/ezmdlog.log to the developer at jaq.cat@protonmail.ch");
      File("/tmp/ezmdlog.log").writeAsString("$e\n$stacktrace");
      failed.add(properQuery ?? link);
    }
  }

  void fromTrack(Track? song, String outPath) async {
    String? query;
    try {
      if (song == null) {
        stderr.writeln("Song not found");
        return;
      }

      final tags = await spotify.extractSongMetadata(song);
      query = tags!.remove("query")!;

      await withTags(query, outPath, TagList.fromMap(fixTags(tags)));
    } catch (e, stacktrace) {
      stderr.writeln(
          "Something went wrong while downloading ${song!.name}! Please send the log file generated at /tmp/ezmdlog.log to the developer at jaq.cat@protonmail.ch");
      File("/tmp/ezmdlog.log").writeAsString("$e\n$stacktrace");
      failed.add(query ?? song.name!);
    }
  }

  Future<void> withTags(String query, String outPath, TagList tags) async {
    String tempname = "/tmp/${uuid.v4()}";
    try {
      await yt.downloadSongToMp3(query, tempname);
    } on VideoUnavailableException catch (_) {
      stderr.writeln("Failed to download video $query");
      failed.add(query);
      return;
    }

    log("Writing tags to $query.mp3");
    try {
      final mp3Bytes = File("$tempname.mp3").readAsBytesSync();
      String filename = path.join(outPath, query.replaceAll('/', '-'));
      final f = File("$filename.mp3");
      f.writeAsBytesSync(await makeId3v2(tags) + mp3Bytes);

      log("Downlodaded '$query'");
    } catch (_) {
      stderr.writeln("Failed to add tags to $query");
    }
  }
}
