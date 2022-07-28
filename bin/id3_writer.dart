/*
   The MIT License (MIT)

   Copyright Artyom Egorov mail@egoroof.ru

   Permission is hereby granted, free of charge, to any person obtaining a copy of software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

   The above copyright notice and permission notice shall be included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import './id3_sizes.dart';
import 'dart:typed_data';

// encoding: https://encoding.spec.whatwg.org/
dynamic strToCodePoints(String str) =>
    (str).split('').map((c) => c.codeUnitAt(0));
dynamic encodeWindows1252(String str) =>
    Uint8List.fromList(strToCodePoints(str));
dynamic encodeUtf16le(String str) =>
    Uint16List.fromList(strToCodePoints(str)).length;

// mime type
dynamic isId3v2(List<num> buf) =>
    buf[0] == 0x49 && buf[1] == 0x44 && buf[2] == 0x33;

dynamic getMimeType(buf) {
  // https://github.com/sindresorhus/file-type
  if (!buf || !buf.length) {
    return null;
  }
  if (buf[0] == 0xff && buf[1] == 0xd8 && buf[2] == 0xff) {
    return 'image/jpeg';
  }
  if (buf[0] == 0x89 && buf[1] == 0x50 && buf[2] == 0x4e && buf[3] == 0x47) {
    return 'image/png';
  }
  if (buf[0] == 0x47 && buf[1] == 0x49 && buf[2] == 0x46) {
    return 'image/gif';
  }
  if (buf[8] == 0x57 && buf[9] == 0x45 && buf[10] == 0x42 && buf[11] == 0x50) {
    return 'image/webp';
  }
  bool isLeTiff =
      buf[0] == 0x49 && buf[1] == 0x49 && buf[2] == 0x2a && buf[3] == 0;
  bool isBeTiff =
      buf[0] == 0x4d && buf[1] == 0x4d && buf[2] == 0 && buf[3] == 0x2a;

  if (isLeTiff || isBeTiff) {
    return 'image/tiff';
  }
  if (buf[0] == 0x42 && buf[1] == 0x4d) {
    return 'image/bmp';
  }
  if (buf[0] == 0 && buf[1] == 0 && buf[2] == 1 && buf[3] == 0) {
    return 'image/x-icon';
  }
  return null;
}

Uint8List uint32ToUint8List(uint32) {
  const eightBitMask = 0xff;

  return Uint8List.fromList([
    (uint32 >>> 24) & eightBitMask,
    (uint32 >>> 16) & eightBitMask,
    (uint32 >>> 8) & eightBitMask,
    uint32 & eightBitMask,
  ]);
}

List<dynamic> uint28ToUint7List(uint28) {
  const sevenBitMask = 0x7f;

  return [
    (uint28 >>> 21) & sevenBitMask,
    (uint28 >>> 14) & sevenBitMask,
    (uint28 >>> 7) & sevenBitMask,
    uint28 & sevenBitMask,
  ];
}

int uint7ListToUint28(uint7List) {
  return (uint7List[0] << 21) +
      (uint7List[1] << 14) +
      (uint7List[2] << 7) +
      uint7List[3];
}

class ID3Writer {
  _setIntegerFrame(String name, int value) {
    frames.add({
      "name": name,
      "value": value,
      "size": getNumericFrameSize(value.toString().length),
    });
  }

  _setStringFrame(String name, String value) {
    frames.add({
      "name": name,
      "value": value,
      "size": getStringFrameSize(value.length),
    });
  }

  _setPictureFrame(String pictureType, Uint8List data, String? description,
      bool useUnicodeEncoding) {
    String mimeType = getMimeType(Uint8List.fromList(data));
    if (description == null) {
      useUnicodeEncoding = false;
    }
    frames.add({
      "name": 'APIC',
      "value": data,
      "pictureType": pictureType,
      "mimeType": mimeType,
      "useUnicodeEncoding": useUnicodeEncoding,
      "description": description,
      "size": getPictureFrameSize(data.lengthInBytes, mimeType.length,
          description?.length ?? 0, useUnicodeEncoding),
    });
  }

  _setPrivateFrame(String id, data) {
    frames.add({
      "name": 'PRIV',
      "value": data,
      "id": id,
      "size": getPrivateFrameSize(id.length, data.byteLength),
    });
  }

  _setUrlLinkFrame(String name, String url) {
    frames.add({
      "name": name,
      "value": url,
      "size": getUrlLinkFrameSize(url.length),
    });
  }

  Uint8List arrayBuffer;
  int padding;
  List<Map<String, dynamic>> frames;
  String url;

  ID3Writer(this.arrayBuffer)
      : padding = 4096,
        frames = [],
        url = '';

  setFrame(String frameName, dynamic frameValue) {
    switch (frameName) {
      case 'TPE1': // song artists
      case 'TCOM': // song composers
      case 'TCON':
        {
          // song genres
          if (frameValue.runtimeType != List) {
            return;
          }
          String delemiter = frameName == 'TCON' ? ';' : '/';
          String value = frameValue.join(delemiter);

          _setStringFrame(frameName, value);
          break;
        }
      case 'TLAN': // language
      case 'TIT1': // content group description
      case 'TIT2': // song title
      case 'TIT3': // song subtitle
      case 'TALB': // album title
      case 'TPE2': // album artist // spec doesn't say anything about separator, so it is a string, not array
      case 'TPE3': // conductor/performer refinement
      case 'TPE4': // interpreted, remixed, or otherwise modified by
      case 'TRCK': // song number in album: 5 or 5/10
      case 'TPOS': // album disc number: 1 or 1/3
      case 'TMED': // media type
      case 'TPUB': // label name
      case 'TCOP': // copyright
      case 'TKEY': // musical key in which the sound starts
      case 'TEXT': // lyricist / text writer
      case 'TSRC':
        {
          // isrc
          _setStringFrame(frameName, frameValue);
          break;
        }
      case 'TBPM': // beats per minute
      case 'TLEN': // song duration
      case 'TDAT': // album release date expressed as DDMM
      case 'TYER':
        {
          // album release year
          _setIntegerFrame(frameName, frameValue);
          break;
        }
      case 'USLT':
      case 'APIC':
        {
          // song cover
          // APIC frame value should be an object with keys type, data and description
          if (frameValue.type < 0 || frameValue.type > 20) {
            return;
          }
          _setPictureFrame(frameValue.type, frameValue.data,
              frameValue.description, !!frameValue.useUnicodeEncoding);
          break;
        }
      case 'WCOM': // Commercial information
      case 'WCOP': // Copyright/Legal information
      case 'WOAF': // Official audio file webpage
      case 'WOAR': // Official artist/performer webpage
      case 'WOAS': // Official audio source webpage
      case 'WORS': // Official internet radio station homepage
      case 'WPAY': // Payment
      case 'WPUB':
        {
          // Publishers official webpage
          _setUrlLinkFrame(frameName, frameValue);
          break;
        }
      case 'COMM':
      case 'PRIV':
      default:
    }
    return;
  }

  void removeTag() {
    const headerLength = 10;

    if (arrayBuffer.lengthInBytes < headerLength) {
      return;
    }
    final bytes = Uint8List.fromList(arrayBuffer);
    final version = bytes[3];
    final tagSize =
        uint7ListToUint28([bytes[6], bytes[7], bytes[8], bytes[9]]) +
            headerLength;

    if (!isId3v2(bytes) || version < 2 || version > 4) {
      return;
    }
    arrayBuffer = Uint8List.fromList(bytes.sublist(tagSize));
  }

  ByteData addTag() {
    removeTag();

    const BOM = [0xff, 0xfe];
    const headerSize = 10;
    int totalFrameSize = 0;
    for (var frame in frames) {
      totalFrameSize += frame.length;
    }
    final totalTagSize = headerSize + totalFrameSize + padding;
    final buffer = ByteData(arrayBuffer.lengthInBytes + totalTagSize);
    final bufferWriter = Uint8List.view(buffer.buffer);

    var offset = 0;
    List<dynamic> writeBytes = [];

    writeBytes = [0x49, 0x44, 0x33, 3]; // ID3 tag and version
    bufferWriter.setAll(offset, writeBytes as Uint8List);
    offset += writeBytes.length;

    offset++; // version revision
    offset++; // flags

    writeBytes = uint28ToUint7List(
        totalTagSize - headerSize); // tag size (without header)
    bufferWriter.setAll(offset, writeBytes as Uint8List);
    offset += writeBytes.length;

    for (var frame in frames) {
      {
        writeBytes = encodeWindows1252(frame["name"]); // frame name
        bufferWriter.setAll(offset, writeBytes as Uint8List);
        offset += writeBytes.length;

        writeBytes = uint32ToUint8List(
            frame.length - headerSize); // frame size (without header)
        bufferWriter.setAll(offset, writeBytes);
        offset += writeBytes.length;

        offset += 2; // flags

        switch (frame["name"]) {
          case 'WCOM':
          case 'WCOP':
          case 'WOAF':
          case 'WOAR':
          case 'WOAS':
          case 'WORS':
          case 'WPAY':
          case 'WPUB':
            {
              writeBytes = encodeWindows1252(frame["value"]); // URL
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;
              break;
            }
          case 'TPE1':
          case 'TCOM':
          case 'TCON':
          case 'TLAN':
          case 'TIT1':
          case 'TIT2':
          case 'TIT3':
          case 'TALB':
          case 'TPE2':
          case 'TPE3':
          case 'TPE4':
          case 'TRCK':
          case 'TPOS':
          case 'TKEY':
          case 'TMED':
          case 'TPUB':
          case 'TCOP':
          case 'TEXT':
          case 'TSRC':
            {
              writeBytes = [1] + BOM; // encoding, BOM
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;

              writeBytes = encodeUtf16le(frame["value"]); // frame value
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;
              break;
            }
          case 'TXXX':
          case 'USLT':
          case 'COMM':
            {
              writeBytes = [1]; // encoding
              if (frame["name"] == 'USLT' || frame["name"] == 'COMM') {
                writeBytes = writeBytes + frame["language"]; // language
              }
              writeBytes = writeBytes + BOM; // BOM for content descriptor
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;

              writeBytes =
                  encodeUtf16le(frame["description"]); // content descriptor
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;

              writeBytes = [0, 0] + BOM; // separator, BOM for frame value
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;

              writeBytes = encodeUtf16le(frame["value"]); // frame value
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;
              break;
            }
          case 'TBPM':
          case 'TLEN':
          case 'TDAT':
          case 'TYER':
            {
              offset++; // encoding

              writeBytes = encodeWindows1252(frame["value"]); // frame value
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;
              break;
            }
          case 'PRIV':
            {
              writeBytes = encodeWindows1252(frame["id"]); // identifier
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;

              offset++; // separator

              bufferWriter.setAll(
                  offset, Uint8List(frame["value"])); // frame data
              offset += frame["value"].byteLength as int;
              break;
            }
          case 'APIC':
            {
              writeBytes = [frame["useUnicodeEncoding"] ? 1 : 0]; // encoding
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;

              writeBytes = encodeWindows1252(frame["mimeType"]); // MIME type
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;

              writeBytes = [0, frame["pictureType"]]; // separator, pic type
              bufferWriter.setAll(offset, writeBytes as Uint8List);
              offset += writeBytes.length;

              if (frame["useUnicodeEncoding"]) {
                writeBytes = [] + BOM; // BOM
                bufferWriter.setAll(offset, writeBytes as Uint8List);
                offset += writeBytes.length;

                writeBytes = encodeUtf16le(frame["description"]); // description
                bufferWriter.setAll(offset, writeBytes as Uint8List);
                offset += writeBytes.length;

                offset += 2; // separator
              } else {
                writeBytes =
                    encodeWindows1252(frame["description"]); // description
                bufferWriter.setAll(offset, writeBytes as Uint8List);
                offset += writeBytes.length;

                offset++; // separator
              }

              bufferWriter.setAll(offset,
                  Uint8List.fromList(frame["value"])); // picture content
              offset += frame["value"].byteLength as int;
              break;
            }
        }
      }
    }

    offset += padding; // free space for rewriting
    bufferWriter.setAll(offset, arrayBuffer);
    /*arrayBuffer = buffer;*/
    return buffer;
  }
}
