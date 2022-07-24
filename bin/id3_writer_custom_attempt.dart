import 'dart:io';
import 'dart:typed_data';
import 'package:utf_convert/utf_convert.dart';

Uint8List uint28ToUint7List(int uint28) {
    const sevenBitMask = 0x7f;

    return Uint8List.fromList([
        (uint28 >>> 21) & sevenBitMask,
        (uint28 >>> 14) & sevenBitMask,
        (uint28 >>> 7) & sevenBitMask,
        uint28 & sevenBitMask,
    ]);
}

class Mp3File {
  Uint8List header = Uint8List(10);
  Uint8List titleFrame;
  Uint8List artistFrame;
  Uint8List content;

  Mp3File._create(this.content, String title, String artist) :
    titleFrame = Uint8List(4+4+2),
    artistFrame = Uint8List(4+4+2);

  static Future<Mp3File> create(String filename, String title, String artist) async {
    Uint8List content = await File(filename).readAsBytes();
    return Mp3File._create(content, title, artist);
  }

  void setHeader() {
    int totalSize = 10 + titleFrame.lengthInBytes + artistFrame.lengthInBytes;
    header.setRange(0, 3, encodeUtf8("ID3") as List<int>); // declare ID3
    header.setRange(3, 5, [0x03, 0x00]); // declare ID3v3
    header.setRange(5, 6, [0x00]); // no flags
    header.setRange(6, 10, []); // size
  }

  bool hasId3v2() {
    return (content.sublist(0, 3).fold("", (String s, int byte) =>
          s + String.fromCharCode(byte))) == "ID3";
  }

  void test() {
    Uint8List a = Uint8List.fromList([1, 2, 3]);
    Uint8List b = a.buffer.asUint8List(0, 1);
  }
}
