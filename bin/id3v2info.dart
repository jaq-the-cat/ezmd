// TODO: Add documentation

import 'dart:typed_data';
import 'dart:convert';
import 'package:recase/recase.dart';
import 'imagedl.dart';
import 'bytestuff.dart';

const int _headerLength = 10;
const int _padding = 128;

enum FrameType { title, artist, genre, album, year, artwork, track, duration }

extension _FrameTypeExt on FrameType {
  Uint8List get code {
    switch (this) {
      case FrameType.title:
        return latin1.encode("TIT2");
      case FrameType.artist:
        return latin1.encode("TPE1");
      case FrameType.genre:
        return latin1.encode("TCON");
      case FrameType.album:
        return latin1.encode("TALB");
      case FrameType.year:
        return latin1.encode("TYER");
      case FrameType.artwork:
        return latin1.encode("APIC");
      case FrameType.track:
        return latin1.encode("TRCK");
      case FrameType.duration:
        return latin1.encode("TLEN");
    }
  }
}

FrameType? frameTypeFromString(String type) {
  switch (type) {
    case "title":
      return FrameType.title;
    case "artist":
      return FrameType.artist;
    case "genre":
      return FrameType.genre;
    case "album":
      return FrameType.album;
    case "year":
      return FrameType.year;
    case "artwork":
      return FrameType.artwork;
    case "track":
      return FrameType.track;
    case "duration":
      return FrameType.duration;
  }
  return null;
}

class FrameList extends Iterable {
  final _list = <Frame>[];
  FrameList();

  bool _hasFrameType(FrameType type) {
    for (var frame in _list) {
      if (frame.type == type) return true;
    }
    return false;
  }

  static FrameList fromList(List<Frame> frames) {
    final list = FrameList();
    for (final frame in frames) {
      list.add(frame);
    }
    return list;
  }

  static FrameList fromMap(Map<String, dynamic> frames) {
    final list = FrameList();
    for (final frame in frames.entries) {
      FrameType? type = frameTypeFromString(frame.key);
      if (type == null) continue;
      list.add(Frame(type, frame.value));
    }
    return list;
  }

  void add(Frame frame) {
    if (!_hasFrameType(frame.type)) {
      _list.add(frame);
    }
  }

  void remove(Frame frame) {
    _list.remove(frame);
  }

  @override
  Iterator get iterator => _list.iterator;
}

class Frame {
  final FrameType type;
  dynamic data;
  Frame(this.type, this.data);

  Uint8List makeFrame(Uint8List code, List<int> data) {
    int length = data.length;
    final binary = Uint8List(4 + 4 + 2 + length); // header size + data size
    binary.setAll(0, code); // 4 bytes
    binary.setAll(4, numberToBytes(length));
    binary.setAll(8, [0x00, 0x00]); // 2 bytes of flags
    binary.setAll(10, data);

    return binary;
  }

  Uint8List get textFrame => makeFrame(type.code, [0x00] + latin1.encode(data));

  Uint8List get picFrame {
    final descriptionBin = latin1.encode("Artwork");
    final bin = Uint8List.fromList([0x00] + // uses ISO-8859 encoding
        latin1.encode(data.mimetype) +
        [0x00] +
        [0x03] + // cover (front)
        descriptionBin +
        [0x00] +
        data.binary);
    return makeFrame(type.code, bin);
  }

  Future<Uint8List?> get binary async {
    switch (type) {
      case FrameType.title:
      case FrameType.artist:
      case FrameType.album:
      case FrameType.year:
      case FrameType.track:
      case FrameType.duration:
        return textFrame;
      case FrameType.genre:
        if (data != null) {
          data = ReCase(data).titleCase.toString();
          return textFrame;
        }
        break;
      case FrameType.artwork:
        data = await downloadImage(data);
        return picFrame;
    }
    return null;
  }
}

Future<Uint8List> makeId3v2(FrameList frames) async {
  if (frames.isEmpty) return Uint8List(0);
  List<int> id3list = [];

  // header
  id3list.addAll([
    0x49, 0x44, 0x33, // ID3
    0x03, 0x00, // v2.3
    0x00, // no flags
    0xff, 0xff, 0xff, 0xff // temporary size
  ]); // 10 header bytes

  for (final frame in frames) {
    if (frame.data == null) continue;
    Uint8List? bin = await frame.binary;
    if (bin != null) {
      id3list.addAll(bin);
    }
  }

  final tagLen = id3list.length + _padding;
  final id3 = Uint8List(tagLen + _headerLength);
  id3.setAll(0, id3list);
  id3.setRange(6, 10, Uint28.fromInt(tagLen).bytes);

  return id3;
}
