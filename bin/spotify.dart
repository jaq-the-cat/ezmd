import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:spotify/spotify.dart';
import 'package:dotenv/dotenv.dart' as dotenv;

String apiUrl = (() {
  if (File('.env').existsSync()) dotenv.load();
  return dotenv.env["EZMD_ENVIRONMENT"] == "DEBUG"
      ? "http://127.0.0.1:8000"
      : "https://ezmd.herokuapp.com";
})();

class Spotify {
  Future<dynamic> _request(String pathargs) async {
    final r = await http.get(Uri.parse(apiUrl + pathargs));
    if (r.statusCode == 200) return jsonDecode(r.body);
  }

  Future<Map<String, String?>?> getSongMetadata(
      {String? query, String? id}) async {
    List<dynamic>? json;
    if (id != null) json = await _request("/track?id=$id");
    if (query != null) json = await _request("/track?query=$query");
    if (json == null || json.isEmpty) return null;
    return extractSongMetadata(Track.fromJson(json.first));
  }

  Future<List<Track>?> getPlaylistTracks(String link) async {
    try {
      final id = link.split('/').last.split('?').first;
      dynamic tracks = await _request("/playlist/tracks?id=$id");
      if (tracks == null) return null;
      tracks = List<Track>.from(tracks
        .where((track) => track != null && track.containsKey("track") && track['track'] != null)
        .map((track) => Track.fromJson(track['track'])));
      if (tracks.isEmpty) {
        return null;
      }
      return tracks;
    } catch (e, tb) {
      stderr.writeln("Failed to download $link");
      stderr.writeln("$e\n$tb");
      return null;
    }
  }

  Future<List<String>?> getGenres(ArtistSimple? artist) async {
    if (artist == null) return null;
    return List<String>.from(await _request("/artist/genres?id=${artist.id}"));
  }

  Future<Map<String, String?>?> extractSongMetadata(Track? song) async {
    if (song == null) return null;
    final artworkAll = song.album?.images;
    // get middle artwork in case theres a lot
    final artwork =
        artworkAll == null ? null : artworkAll[artworkAll.length ~/ 2];
    final genres = await getGenres(song.artists?.first);
    String genre = "";
    if (genres != null && genres.isNotEmpty) {
      genre = genres.first;
    }
    return {
      // data to be transfered to other functio
      "query": "${song.artists?.first.name} - ${song.name!}",

      // actual tags
      "title": song.name!,
      // artists name must be separated by "/" (ID3v2 standard)
      "artist": song.artists?.map((a) => a.name).join("/"),
      "album": song.album?.name!,
      "year": song.album?.releaseDate?.substring(0, 4),
      "track": song.trackNumber.toString(),
      "artwork": artwork?.url,
      "duration": song.durationMs.toString(),
      "genre": genre,
    };
  }
}
