import 'dart:typed_data';
import 'dart:convert';
import 'package:recase/recase.dart';
/*import 'genres.dart';*/
import 'imagedl.dart';

class Uint28 {
  final int _n;
  Uint28(this._n);

  static Uint28 fromInt(int n) {
    return Uint28((n << 3) & 0x7f000000 |
        (n << 2) & 0x007f0000 |
        (n << 1) & 0x00007f00 |
        n & 0x0000007f);
  }

  Uint8List get bytes =>
      Uint8List.fromList([_n >>> 24, _n >>> 16, _n >>> 8, _n]);

  int get raw => _n;

  String toRadixString(int n) {
    return _n.toRadixString(n);
  }
}

const int _headerLength = 10;
const int _padding = 128;

Uint8List toUint7List(int n) => Uint28.fromInt(n).bytes;

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

  static Uint8List picFrame(String code, Image img) {
    final descriptionBin = latin1.encode("Artwork");
    final data = Uint8List.fromList([0x00] + // uses ISO-8859 encoding
        latin1.encode(img.mimetype) +
        [0x00] +
        [0x03] + // cover (front)
        descriptionBin +
        [0x00] +
        img.binary);
    return makeFrame(code, data);
  }

  static Future<Uint8List?> binary(String id, dynamic data) async {
    switch (id) {
      case "title":
        return textFrame("TIT2", data);
      case "artist":
        return textFrame("TPE1", data);
      case "genre":
        if (data != null) {
          return textFrame("TCON", ReCase(data).titleCase.toString());
        }
        break;
      case "album":
        return textFrame("TALB", data);
      case "year":
        return textFrame("TYER", data);
      case "artwork":
        return picFrame("APIC", await downloadImage(data));
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

  for (var e in frames.entries) {
    if (e.value == null) continue;
    Uint8List? bin = await Id3Frame.binary(e.key, e.value);
    if (bin != null) {
      id3list.addAll(bin);
    }
  }

  int tagLen = id3list.length + _padding;
  var id3 = Uint8List(tagLen + _headerLength);
  id3.setAll(0, id3list);
  id3.setRange(6, 10, Uint28.fromInt(tagLen).bytes);

  return id3;
}
