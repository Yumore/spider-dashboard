import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';

class LocalTextDocumentDecoder {
  const LocalTextDocumentDecoder();

  String decode(Uint8List bytes) {
    if (_startsWith(bytes, const [0xef, 0xbb, 0xbf])) {
      return utf8.decode(bytes.sublist(3), allowMalformed: true);
    }
    if (_startsWith(bytes, const [0xff, 0xfe])) {
      return _decodeUtf16(bytes.sublist(2), Endian.little);
    }
    if (_startsWith(bytes, const [0xfe, 0xff])) {
      return _decodeUtf16(bytes.sublist(2), Endian.big);
    }
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return gbk.decode(bytes);
    }
  }

  bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var index = 0; index < prefix.length; index++) {
      if (bytes[index] != prefix[index]) return false;
    }
    return true;
  }

  String _decodeUtf16(Uint8List bytes, Endian endian) {
    final usableLength = bytes.length - (bytes.length % 2);
    final data = ByteData.sublistView(bytes, 0, usableLength);
    return String.fromCharCodes([
      for (var offset = 0; offset < usableLength; offset += 2)
        data.getUint16(offset, endian),
    ]);
  }
}
