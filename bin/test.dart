import 'spotify.dart';

void log(Object? o) {
  print(o);
}

final spotify = Spotify();
const link = "https://open.spotify.com/playlist/2QUEEqqzuE9Vb5wMUYbBxh?si=84b030413d0940d4";

void main(List<String> args) async {
  log(await spotify.getPlaylistTracks(link));
}
