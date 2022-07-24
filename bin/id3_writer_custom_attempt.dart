import 'dart:io';
import 'dart:typed_data';
import 'package:utf_convert/utf_convert.dart';

Uint8List intToUint7List(int uint28) {
    const sevenBitMask = 0x7f;
    return Uint8List.fromList([
        (uint28 >>> 21) & sevenBitMask,
        (uint28 >>> 14) & sevenBitMask,
        (uint28 >>> 7) & sevenBitMask,
        uint28 & sevenBitMask,
    ]);
}

Uint8List stringToISO8859(String s) {
  List<int> noNull = [];
  encodeUtf8(s).forEach((int? n) {
    if (n != null) noNull.add(n);
  });

  return Uint8List.fromList(noNull);
}

int getTextFrameLength(String s) {
  // header + encoding+content
  return 4+4+2+1 + 1+stringToISO8859(s).lengthInBytes;
}

class Frame {
  Uint8List code;
  String text;
  Frame(List<int> code, this.text) : code = Uint8List.fromList(code);

  Uint8List get binary {
    int length = getTextFrameLength(text);
    Uint8List framebin = Uint8List(length);
    framebin.setAll(0, code); // 4 bytes
    framebin.setAll(4, intToUint7List(length-10)); // 4 bytes of uint7
    framebin.setAll(8, [0x00, 0x00]); // 2 bytes of flags
    framebin.setAll(10, [0x00]); // 0x00 = ISO-8859-1 is used
    framebin.setAll(11, stringToISO8859(text));
    return framebin;
  }
}

class ID3File {
  Uint8List header = Uint8List(10);
  Frame titleFrame;
  Frame artistFrame;
  Uint8List content;
  static const int length = 1061;

  ID3File._create(this.content, String title, String artist) :
    titleFrame = Frame([0x54, 0x49, 0x54, 0x32], title), // TIT2
    artistFrame = Frame([0x54, 0x50, 0x45, 0x31], artist); // TPE1

  static Future<ID3File> create(String filename, String title, String artist) async {
    Uint8List content = await File(filename).readAsBytes();
    return ID3File._create(content, title, artist);
  }

  void setHeader() {
    int totalSize = titleFrame.binary.lengthInBytes + artistFrame.binary.lengthInBytes + 1;
    header.setRange(0,  3, [0x49, 0x44, 0x33]); // declare ID3
    header.setRange(3,  5, [0x03, 0x00]); // declare ID3v3
    header.setRange(5,  6, [0x00]); // no flags
    header.setRange(6, 10, [0x00, 0x00, 0x08, 0x25]); // size

    for (int i in intToUint7List(totalSize)) {
      stdout.write("${i.toRadixString(16)} ");
    }
    print("");
    for (int i in header) {
      stdout.write("${i.toRadixString(16)} ");
    }
    print("");
  }

  bool hasId3v2() {
    return (content.sublist(0, 3).fold("", (String s, int byte) =>
          s + String.fromCharCode(byte))) == "ID3";
  }

  void test() {

  }
}
