import 'dart:typed_data';
import 'dart:convert';
import 'genres.dart';
import 'imagedl.dart';

final int headerLength = 10;

Uint8List toUint7List(int n) {
  final list = Uint8List(4);
  // taken from https://github.com/egoroof/browser-id3-writer
  const sevenBitMask = 0x7f;
  // taken
  list.setAll(0, [
    (n >>> 21) & sevenBitMask,
    (n >>> 15) & sevenBitMask,
    (n >>> 7) & sevenBitMask,
    (n) & sevenBitMask
  ]);
  return list;
}

final Map<String, int> genresMap = (() {
  Map<String, int> genresProper = {};
  for (int i = 0; i < genresRaw.length; i++) {
    genresProper[genresRaw[i]] = i;
  }
  return genresProper;
})();

Uint8List numberToBytes(int n) {
  final bytes = Uint8List(4);
  bytes.setAll(0, [
    n >>> 24,
    n >>> 16,
    n >>> 8,
    n,
  ]);
  return bytes;
}

abstract class Id3Frame {
  static Uint8List makeFrame(List<int> code, List<int> data) {
    int length = data.length;
    var binary = Uint8List(4 + 4 + 2 + length); // header size + data size
    binary.setAll(0, code); // 4 bytes
    binary.setAll(4, numberToBytes(length));
    binary.setAll(8, [0x00, 0x00]); // 2 bytes of flags
    binary.setAll(10, data);

    return binary;
  }

  static Uint8List textFrame(List<int> code, String text) =>
      makeFrame(code, [0x00] + utf8.encode(text));

  static Uint8List genreFrame(List<String> genres) {
    List<int> bin = [];
    for (var g in genres) {
      bin.addAll(utf8.encode("($g)"));
    }
    return makeFrame([0x54, 0x43, 0x4F, 0x4E], bin);
  }

  static Uint8List picFrame(List<int> code, Image img) {
    final picType = [0x03]; // cover (front)
    final descriptionBin = utf8.encode("Artwork") + [0x00];
    final data = Uint8List.fromList([0x00] + // uses ISO-8859 encoding
        utf8.encode(img.mimetype) +
        picType +
        descriptionBin +
        img.binary);
    return makeFrame(code, data);
  }

  static Uint8List? binary(String id, dynamic data) {
    switch (id) {
      case "title":
        return textFrame([0x54, 0x49, 0x54, 0x32], data);
      case "artist":
        return textFrame([0x54, 0x50, 0x45, 0x31], data);
      case "genres":
        if (data != null) return genreFrame(data);
        break;
      case "album":
        return textFrame([0x54, 0x41, 0x4c, 0x42], data);
      case "year":
        return textFrame([0x54, 0x59, 0x45, 0x52], data);
      // TODO: Fix artwork, currently corrupting file
      /*case "artwork":*/
      /*return picFrame([0x41, 0x50, 0x49, 0x43], data);*/
      case "track":
        return textFrame([0x54, 0x52, 0x43, 0x4b], data);
    }
    return null;
  }
}

Future<Uint8List> makeId3Information(Map<String, dynamic> frames) async {
  List<int> id3 = [];

  // header
  id3.addAll([
    0x49, 0x44, 0x33, // ID3
    0x03, 0x00, // v3
    0x00, // no flags
    0xff, 0xff, 0xff, 0xff // temporary size
  ]); // 10 header bytes

  frames.forEach((String id, dynamic value) {
    if (value == null) return;
    Uint8List? bin = Id3Frame.binary(id, value);
    if (bin != null) {
      id3.addAll(bin);
    }
  });

  id3.setAll(6, toUint7List(id3.length));

  return Uint8List.fromList(id3);
}
