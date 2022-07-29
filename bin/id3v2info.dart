import 'dart:typed_data';
import 'dart:convert';
import 'genres.dart';
import 'imagedl.dart';

const int _headerLength = 10;
/*const int padding = 128;*/

/*Uint8List toUint7List(int n) {*/
/*final list = Uint8List(4);*/
/*list.setAll(0, [n >>> (24 - 3), n >>> (16 - 2), n >>> (8 - 1), n]);*/
/*return list;*/
/*}*/

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
  static Uint8List makeFrame(String code, List<int> data) {
    int length = data.length;
    var binary = Uint8List(4 + 4 + 2 + length); // header size + data size
    binary.setAll(0, latin1.encode(code)); // 4 bytes
    binary.setAll(4, numberToBytes(length));
    binary.setAll(8, [0x00, 0x00]); // 2 bytes of flags
    binary.setAll(10, data);

    return binary;
  }

  static Uint8List textFrame(String code, String text) =>
      makeFrame(code, [0x00] + latin1.encode(text));

  static Uint8List genreFrame(List<String> genreTags) {
    List<int> bin = [];
    for (var g in genreTags) {
      if (genres.contains(g)) {
        bin.addAll(latin1.encode("(${genres.indexOf(g)})"));
      }
    }
    return makeFrame("TCON", bin);
  }

  static Uint8List picFrame(String code, Image img) {
    final descriptionBin = latin1.encode("Artwork");
    final data = Uint8List.fromList(
        [0x00] + // uses ISO-8859 encoding
        latin1.encode(img.mimetype) + [0x00] +
        [0x03] + // cover (front)
        descriptionBin + [0x00] +
        img.binary);
    return makeFrame(code, data);
  }

  static Future<Uint8List?> binary(String id, dynamic data) async {
    switch (id) {
      case "title":
        return textFrame("TIT2", data);
      case "artist":
        return textFrame("TPE1", data);
      case "genres":
        if (data != null) return genreFrame(data);
        break;
      case "album":
        return textFrame("TALB", data);
      case "year":
        return textFrame("TYER", data);
      // TODO: Fix artwork, currently corrupting file
      /*case "artwork":*/
        /*return picFrame("APIC", await downloadImage(data));*/
      case "track":
        return textFrame("TRCK", data);
      case "duration":
        return textFrame("TLEN", data);
    }
    return null;
  }
}

Future<Uint8List> makeId3v2Information(Map<String, dynamic> frames) async {
  if (frames.isEmpty) return Uint8List(0);
  List<int> id3list = [];

  // header
  id3list.addAll([
    0x49, 0x44, 0x33, // ID3
    0x03, 0x00, // v2.3
    0x00, // no flags
    0xff, 0xff, 0xff, 0xff // temporary size
  ]); // 10 header bytes

  frames.forEach((String id, dynamic value) async {
    if (value == null) return;
    Uint8List? bin = await Id3Frame.binary(id, value);
    if (bin != null) {
      id3list.addAll(bin);
    }
  });

  var id3 = Uint8List(1071);
  id3.setAll(0, id3list);
  id3.setAll(6, [0x0, 0x0, 0x8, 0x25]); // encoded 1071 (or 1061 idk)

  return id3;
}