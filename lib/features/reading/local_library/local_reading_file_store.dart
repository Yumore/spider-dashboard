import 'dart:typed_data';

import 'local_reading_file_store_stub.dart'
    if (dart.library.io) 'local_reading_file_store_io.dart'
    as platform_store;

class LocalReadingFileStore {
  Future<String> importFile({
    required String fileName,
    String? sourcePath,
    Stream<List<int>>? sourceStream,
    Uint8List? bytes,
  }) => platform_store.importReadingFile(
    fileName: fileName,
    sourcePath: sourcePath,
    sourceStream: sourceStream,
    bytes: bytes,
  );

  Future<Uint8List> readBytes(String path) =>
      platform_store.readReadingFile(path);

  Future<void> deleteFile(String path) =>
      platform_store.deleteReadingFile(path);
}
