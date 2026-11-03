import 'dart:typed_data';

Future<String> importReadingFile({
  required String fileName,
  String? sourcePath,
  Stream<List<int>>? sourceStream,
  Uint8List? bytes,
}) => throw UnsupportedError('Local document storage is unavailable.');

Future<Uint8List> readReadingFile(String path) =>
    throw UnsupportedError('Local document storage is unavailable.');

Future<void> deleteReadingFile(String path) =>
    throw UnsupportedError('Local document storage is unavailable.');
