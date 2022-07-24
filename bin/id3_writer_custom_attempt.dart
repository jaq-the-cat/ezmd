import 'dart:io';
import 'dart:typed_data';
import 'package:utf_convert/utf_convert.dart';

class Mp3File {
  Uint8List content;
  int length = 0;
  Mp3File._create(this.content);

  static Future<Mp3File> create(String filename) async {
    Uint8List content = await File(filename).readAsBytes();
    return Mp3File._create(content);
  }

  void setMetadata() {
    length = content.sublist(8, 10).buffer.asByteData().getUint16(0);
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
