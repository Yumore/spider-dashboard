import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/cbc.dart';

final Uint8List _key = Uint8List.fromList(utf8.encode('f5d965df75336270'));
final Uint8List _iv = Uint8List.fromList(utf8.encode('97b60394abc2fbe1'));

Future<Uint8List> decryptCover(Uint8List input) async {
  if (_looksLikeImage(input)) return input;
  if (input.isEmpty || input.length % 16 != 0) {
    throw const FormatException('封面密文长度无效');
  }

  final cipher = CBCBlockCipher(AESEngine())
    ..init(false, ParametersWithIV<KeyParameter>(KeyParameter(_key), _iv));
  final output = Uint8List(input.length);
  for (var offset = 0; offset < input.length; offset += 16) {
    cipher.processBlock(input, offset, output, offset);
  }
  final image = _removePkcs7(output);
  if (!_looksLikeImage(image)) {
    throw const FormatException('封面解密结果不是图片');
  }
  return _trimJpeg(image);
}

Uint8List _removePkcs7(Uint8List bytes) {
  if (bytes.isEmpty) return bytes;
  final padding = bytes.last;
  if (padding < 1 || padding > 16 || padding > bytes.length) return bytes;
  for (var index = bytes.length - padding; index < bytes.length; index++) {
    if (bytes[index] != padding) return bytes;
  }
  return Uint8List.sublistView(bytes, 0, bytes.length - padding);
}

Uint8List _trimJpeg(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) return bytes;
  for (var index = bytes.length - 2; index >= 2; index--) {
    if (bytes[index] == 0xff && bytes[index + 1] == 0xd9) {
      return Uint8List.sublistView(bytes, 0, index + 2);
    }
  }
  return bytes;
}

bool _looksLikeImage(Uint8List bytes) {
  if (bytes.length < 4) return false;
  final jpeg = bytes[0] == 0xff && bytes[1] == 0xd8;
  final png =
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47;
  final gif = bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46;
  final webp =
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
  return jpeg || png || gif || webp;
}
