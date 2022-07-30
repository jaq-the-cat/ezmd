import 'dart:io';

import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class Youtube extends YoutubeExplode {
  void Function(Object? o) log;
  Youtube({required this.log});

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

  Future<void> downloadSongToMp3(String query, String tempname,
      [bool lyrics = false]) async {
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
