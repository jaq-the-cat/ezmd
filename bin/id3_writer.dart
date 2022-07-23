/*
   The MIT License (MIT)

   Copyright Artyom Egorov mail@egoroof.ru

   Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

import './id3_sizes.dart';
import 'dart:typed_data';

// encoding: https://encoding.spec.whatwg.org/
dynamic strToCodePoints(String str) => (str).split('').map((c) => c.codeUnitAt(0));
dynamic encodeWindows1252(String str) => Uint8List.fromList(strToCodePoints(str));
dynamic encodeUtf16le(String str) => Uint16List.fromList(strToCodePoints(str));

// mime type
dynamic isId3v2(List<num> buf) => buf[0] == 0x49 && buf[1] == 0x44 && buf[2] == 0x33;

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
    bool isLeTiff = buf[0] == 0x49 && buf[1] == 0x49 && buf[2] == 0x2a && buf[3] == 0;
    bool isBeTiff = buf[0] == 0x4d && buf[1] == 0x4d && buf[2] == 0 && buf[3] == 0x2a;

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

class ID3Writer {
  _setIntegerFrame(String name, int value) {
    frames.push({
        "name": name,
        "value": value,
        "size": getNumericFrameSize(value.toString().length),
        });
  }

  _setStringFrame(String name, String value) {
    frames.push({
        "name": name,
        "value": value,
        "size": getStringFrameSize(value.length),
        });
  }

  _setPictureFrame(String pictureType, Uint8List data, String? description, bool useUnicodeEncoding) {
    String mimeType = getMimeType(Uint8List.fromList(data));
    if (description == null) {
      useUnicodeEncoding = false;
    }
    frames.push({
        "name": 'APIC',
        "value": data,
        "pictureType": pictureType,
        "mimeType": mimeType,
        "useUnicodeEncoding": useUnicodeEncoding,
        "description": description,
        "size": getPictureFrameSize(data.lengthInBytes, mimeType.length, description?.length ?? 0, useUnicodeEncoding),
        });
  }
  _setPrivateFrame(String id, data) {

    frames.push({
        "name": 'PRIV',
        "value": data,
        "id": id,
        "size": getPrivateFrameSize(id.length, data.byteLength),
        });
  }

  _setUrlLinkFrame(String name, String url) {

    frames.push({
        "name": name,
        "value": url,
        "size": getUrlLinkFrameSize(url.length),
        });
  }

  Uint8List arrayBuffer;
  int padding;
  List<Map<String, dynamic>> frames;
  String url;

  ID3Writer(this.arrayBuffer) : padding = 4096, frames = [], url = '';

  setFrame(String frameName, dynamic frameValue) {
    switch (frameName) {
      case 'TPE1': // song artists
      case 'TCOM': // song composers
      case 'TCON': { // song genres
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
      case 'TSRC': { // isrc
                     this._setStringFrame(frameName, frameValue);
                     break;
                   }
      case 'TBPM': // beats per minute
      case 'TLEN': // song duration
      case 'TDAT': // album release date expressed as DDMM
      case 'TYER': { // album release year
                     this._setIntegerFrame(frameName, frameValue);
                     break;
                   }
      case 'USLT': { // unsychronised lyrics
                     frameValue.language = frameValue.language || 'eng';
                     if (typeof frameValue !== 'object' || !('description' in frameValue) || !('lyrics' in frameValue)) {
                       throw new Error('USLT frame value should be an object with keys description and lyrics');
                     }
                     if (frameValue.language && !frameValue.language.match(/[a-z]{3}/i)) {
                       throw new Error('Language must be coded following the ISO 639-2 standards');
                     }
                     this._setLyricsFrame(frameValue.language, frameValue.description, frameValue.lyrics);
                     break;
                   }
      case 'APIC': { // song cover
                     if (typeof frameValue !== 'object' || !('type' in frameValue) || !('data' in frameValue) || !('description' in frameValue)) {
                       throw new Error('APIC frame value should be an object with keys type, data and description');
                     }
                     if (frameValue.type < 0 || frameValue.type > 20) {
                       throw new Error('Incorrect APIC frame picture type');
                     }
                     this._setPictureFrame(frameValue.type, frameValue.data, frameValue.description, !!frameValue.useUnicodeEncoding);
                     break;
                   }
      case 'TXXX': { // user defined text information
                     if (typeof frameValue !== 'object' || !('description' in frameValue) || !('value' in frameValue)) {
                       throw new Error('TXXX frame value should be an object with keys description and value');
                     }
                     this._setUserStringFrame(frameValue.description, frameValue.value);
                     break;
                   }
      case 'WCOM': // Commercial information
      case 'WCOP': // Copyright/Legal information
      case 'WOAF': // Official audio file webpage
      case 'WOAR': // Official artist/performer webpage
      case 'WOAS': // Official audio source webpage
      case 'WORS': // Official internet radio station homepage
      case 'WPAY': // Payment
      case 'WPUB': { // Publishers official webpage
                     this._setUrlLinkFrame(frameName, frameValue);
                     break;
                   }
      case 'COMM': { // Comments
                     frameValue.language = frameValue.language || 'eng';
                     if (typeof frameValue !== 'object' || !('description' in frameValue) || !('text' in frameValue)) {
                       throw new Error('COMM frame value should be an object with keys description and text');
                     }
                     if (frameValue.language && !frameValue.language.match(/[a-z]{3}/i)) {
                       throw new Error('Language must be coded following the ISO 639-2 standards');
                     }
                     this._setCommentFrame(frameValue.language, frameValue.description, frameValue.text);
                     break;
                   }
      case 'PRIV': { // Private frame
                     if (typeof frameValue !== 'object' || !('id' in frameValue) || !('data' in frameValue)) {
                       throw new Error('PRIV frame value should be an object with keys id and data');
                     }
                     this._setPrivateFrame(frameValue.id, frameValue.data);
                     break;
                   }
      default: {
                 throw new Error(`Unsupported frame ${frameName}`);
               }
    }
    return this;
  }

  removeTag() {
    const headerLength = 10;

    if (this.arrayBuffer.byteLength < headerLength) {
      return;
    }
    const bytes = new Uint8Array(this.arrayBuffer);
    const version = bytes[3];
    const tagSize = uint7ArrayToUint28([bytes[6], bytes[7], bytes[8], bytes[9]]) + headerLength;

    if (!isId3v2(bytes) || version < 2 || version > 4) {
      return;
    }
    this.arrayBuffer = (new Uint8Array(bytes.subarray(tagSize))).buffer;
  }

  addTag() {
    this.removeTag();

    const BOM = [0xff, 0xfe];
    const headerSize = 10;
    const totalFrameSize = frames.reduce((sum, frame) => sum + frame.size, 0);
    const totalTagSize = headerSize + totalFrameSize + this.padding;
    const buffer = new ArrayBuffer(this.arrayBuffer.byteLength + totalTagSize);
    const bufferWriter = new Uint8Array(buffer);

    let offset = 0;
    let writeBytes = [];

    writeBytes = [0x49, 0x44, 0x33, 3]; // ID3 tag and version
    bufferWriter.set(writeBytes, offset);
    offset += writeBytes.length;

    offset++; // version revision
    offset++; // flags

    writeBytes = uint28ToUint7Array(totalTagSize - headerSize); // tag size (without header)
    bufferWriter.set(writeBytes, offset);
    offset += writeBytes.length;

    for (var frame in frames) {
      {
        writeBytes = encodeWindows1252(frame.name); // frame name
        bufferWriter.set(writeBytes, offset);
        offset += writeBytes.length;

        writeBytes = uint32ToUint8Array(frame.length - headerSize); // frame size (without header)
        bufferWriter.set(writeBytes, offset);
        offset += writeBytes.length;

        offset += 2; // flags

        switch (frame.name) {
        case 'WCOM':
        case 'WCOP':
        case 'WOAF':
        case 'WOAR':
        case 'WOAS':
        case 'WORS':
        case 'WPAY':
        case 'WPUB': {
        writeBytes = encodeWindows1252(frame.value); // URL
        bufferWriter.set(writeBytes, offset);
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
        case 'TSRC': {
                       writeBytes = [1].concat(BOM); // encoding, BOM
                       bufferWriter.set(writeBytes, offset);
                       offset += writeBytes.length;

                       writeBytes = encodeUtf16le(frame.value); // frame value
                       bufferWriter.set(writeBytes, offset);
                       offset += writeBytes.length;
                       break;
                     }
        case 'TXXX':
        case 'USLT':
        case 'COMM': {
                       writeBytes = [1]; // encoding
                       if (frame.name == 'USLT' || frame.name == 'COMM') {
                         writeBytes = writeBytes.concat(frame.language); // language
                       }
                       writeBytes = writeBytes.concat(BOM); // BOM for content descriptor
                       bufferWriter.set(writeBytes, offset);
                       offset += writeBytes.length;

                       writeBytes = encodeUtf16le(frame.description); // content descriptor
                       bufferWriter.set(writeBytes, offset);
                       offset += writeBytes.length;

                       writeBytes = [0, 0].concat(BOM); // separator, BOM for frame value
                       bufferWriter.set(writeBytes, offset);
                       offset += writeBytes.length;

                       writeBytes = encodeUtf16le(frame.value); // frame value
                       bufferWriter.set(writeBytes, offset);
                       offset += writeBytes.length;
                       break;
                     }
        case 'TBPM':
        case 'TLEN':
        case 'TDAT':
        case 'TYER': {
                       offset++; // encoding

                       writeBytes = encodeWindows1252(frame.value); // frame value
                       bufferWriter.set(writeBytes, offset);
                       offset += writeBytes.length;
                       break;
                     }
        case 'PRIV': {
                       writeBytes = encodeWindows1252(frame.id); // identifier
                       bufferWriter.set(writeBytes, offset);
                       offset += writeBytes.length;

                       offset++; // separator

                       bufferWriter.set(new Uint8Array(frame.value), offset); // frame data
                       offset += frame.value.byteLength;
                       break;
                     }
        case 'APIC': {
                       writeBytes = [frame.useUnicodeEncoding ? 1 : 0]; // encoding
                       bufferWriter.set(writeBytes, offset);
                       offset += writeBytes.length;

                       writeBytes = encodeWindows1252(frame.mimeType); // MIME type
                       bufferWriter.set(writeBytes, offset);
                       offset += writeBytes.length;

                       writeBytes = [0, frame.pictureType]; // separator, pic type
                       bufferWriter.set(writeBytes, offset);
                       offset += writeBytes.length;

                       if (frame.useUnicodeEncoding) {
                         writeBytes = [].concat(BOM); // BOM
                         bufferWriter.set(writeBytes, offset);
                         offset += writeBytes.length;

                         writeBytes = encodeUtf16le(frame.description); // description
                         bufferWriter.set(writeBytes, offset);
                         offset += writeBytes.length;

                         offset += 2; // separator
                       } else {
                         writeBytes = encodeWindows1252(frame.description); // description
                         bufferWriter.set(writeBytes, offset);
                         offset += writeBytes.length;

                         offset++; // separator
                       }

                       bufferWriter.set(new Uint8Array(frame.value), offset); // picture content
                       offset += frame.value.byteLength;
                       break;
                     }
        }
    };
    }

    offset += this.padding; // free space for rewriting
    bufferWriter.set(new Uint8Array(this.arrayBuffer), offset);
    this.arrayBuffer = buffer;
    return buffer;
  }

  getBlob() {
    return new Blob([this.arrayBuffer], {type: 'audio/mpeg'});
  }

  getURL() {
    if (!this.url) {
      this.url = URL.createObjectURL(this.getBlob());
    }
    return this.url;
  }

  revokeURL() {
    URL.revokeObjectURL(this.url);
  }

}
