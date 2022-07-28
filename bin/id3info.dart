import 'dart:typed_data';
import 'package:utf_convert/utf_convert.dart';
import 'dart:convert';
import 'package:convert/convert.dart';

import 'id3_writer.dart';

final int tagLength = 1071;
final int headerLength = 10;
final Uint8List tagLengthEncoded = Uint8List.fromList([0x08, 0x25]);

Uint8List encodeUtf8(String s) => Uint8List.fromList(utf8.encode(s));

Uint8List stringToUtf16be(String s) {
  List<int> noNull = [];
  encodeUtf16(s).forEach((int? n) {
    if (n != null) noNull.add(n);
  });

  return Uint8List.fromList(noNull);
}

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
      makeFrame(code, [0x00] + encodeUtf8(text));

  static Uint8List numberFrame(List<int> code, String number) =>
      makeFrame(code, encodeUtf8(number));

  static Uint8List picUrlFrame(List<int> code, String url) {
    final mimeTypeBin = encodeUtf8("-->") + [0x00];
    final descriptionBin = encodeUtf8("Artwork") + [0x00];
    final urlBin = encodeUtf8(url);
    final data = Uint8List(
        1 + mimeTypeBin.length + 1 + descriptionBin.length + urlBin.length);

    data.setAll(
        0,
        [0x00] + // uses ISO-8859 encoding
            mimeTypeBin +
            [0x03] + // pic type: cover (front)
            descriptionBin +
            urlBin);
    return makeFrame(code, data);
  }

  static Uint8List? binary(String id, String data) {
    switch (id) {
      case "title":
        return textFrame([0x54, 0x49, 0x54, 0x32], data);
      case "artist":
        return textFrame([0x54, 0x50, 0x45, 0x31], data);
      case "genre":
        return textFrame([], ""); // TODO: figure out how to do this
      case "album":
        return textFrame([0x54, 0x41, 0x4c, 0x42], data);
      case "year":
        return numberFrame([0x54, 0x59, 0x45, 0x52], data);
      case "artwork":
        return picUrlFrame([0x41, 0x50, 0x49, 0x43], data);
    }
    return null;
  }
}

Future<Uint8List> makeId3Information(Map<String, String> frames) async {
  final id3 = Uint8List(tagLength);

  // header
  id3.setAll(0, [
    0x49, 0x44, 0x33, // ID3
    0x03, 0x00, // v3
    0x00, // no flags
    0x00, 0x00, 0x08, 0x25 // size (1071 bytes)
  ]); // 10 header bytes

  int offset = 10;
  frames.forEach((String id, String value) {
    Uint8List? bin = Id3Frame.binary(id, value);
    if (bin != null) {
      id3.setAll(offset, bin);
      offset += bin.length;
    }
  });

  return id3;
}
