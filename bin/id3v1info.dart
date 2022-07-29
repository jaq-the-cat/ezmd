import 'dart:typed_data';
import 'dart:convert';
import 'genres.dart';

Uint8List makeId3v1Information(Map<String, dynamic> frames) {
  final id3 = Uint8List(128);
  if (frames.isEmpty) return id3;

  id3.setAll(0,   latin1.encode("TAG")); // $54 41 47
  id3.setAll(3,   latin1.encode(frames["title"]));
  id3.setAll(33,  latin1.encode(frames["artist"]));
  id3.setAll(63,  latin1.encode(frames["album"]));
  id3.setAll(93,  latin1.encode(frames["year"]));
  id3.setAll(97,  []); // comment
  id3.setAll(127, [genres.indexOf(frames["genre"] ?? "")]);

  return id3;
}