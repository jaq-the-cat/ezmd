import 'dart:io';

import 'package:dotenv/dotenv.dart' as dotenv;
import 'package:spotify/spotify.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'id3_writer_custom_attempt.dart';

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

  Future<Stream> downloadSong(String query) async => downloadSongFromId(await getSongId(query));
}

class Spotify extends SpotifyApi {
  Spotify() : super(SpotifyApiCredentials(dotenv.env["SPOTIFY_CLIENT_ID"], dotenv.env["SPOTIFY_CLIENT_SECRET"]));

  Future<Track?> getSongMetadata(String query) async {
    Page page = (await search.get(query, types: [SearchType.track]).first()).first;
    var item = page.items?.first;
    if (item is Track) return item;
    return null;
  }
}

class Ezmp {
  final Youtube yt;
  final Spotify? spotify = null;
  Ezmp() :
  yt = Youtube();
  /*spotify = Spotify() {*/
    /*dotenv.load();*/
  /*}*/

  void downloadSong(String query) async {
    String? songName;
    String? spotifiedQuery;
    Map<String, String> tags = {};

    /*spotify.getSongMetadata(query).then((song) {*/
      /*if (song != null) {*/
        /*songName = song.name;*/
        /*spotifiedQuery = "$songName ${song.artists!.map((a) => a.name).join(", ")}";*/
        /*var artworkAll = song.album!.images!;*/
        /*var artwork = artworkAll[artworkAll.length ~/ 2];*/
        /*tags = {*/
          /*"title": songName!,*/
          /*"artist": song.artists!.map((a) => a.name).join(", "),*/
          /*"genre": song.artists!.first.genres!.first,*/
          /*"trackNumber": song.trackNumber!.toString(),*/
          /*"discNumber": song.discNumber!.toString(),*/
          /*"album": song.album!.name!,*/
          /*"albumArtist": song.album!.artists!.first.name!,*/
          /*"year": song.album!.releaseDate!.substring(0, 4),*/
          /*"artwork": artwork.url!,*/
        /*};*/
      /*}*/
    /*});*/

    /*if (spotifiedQuery == null) return;*/

    spotifiedQuery = "Linkin Park - Numb";
    songName = "Numb";

    var stream = await yt.downloadSong(spotifiedQuery!);

    var fs = File("$songName.mp3").openWrite();
    await stream.pipe(fs);
    await fs.flush();
    await fs.close();

    // write tags
  }
}


void main(List<String> arguments) async {
  /*var ezmp = Ezmp();*/
  /*var input = stdin.readLineSync();*/
  /*if (input != null) {*/
    /*ezmp.downloadSong(input);*/
  /*}*/

  Mp3File tagged = await Mp3File.create("Numb.mp3");
  print(tagged.hasId3v2());
  tagged.test();
  /*tagged.setMetadata();*/
}
