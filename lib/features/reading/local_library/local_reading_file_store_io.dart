import 'dart:io';
import 'dart:typed_data';

import 'package:dashboard/app/platform/app_directories.dart';
import 'package:path/path.dart' as paths;

Future<String> importReadingFile({
  required String fileName,
  String? sourcePath,
  Stream<List<int>>? sourceStream,
  Uint8List? bytes,
}) async {
  final root =
      await AppDirectories.documentsPath() ??
      await AppDirectories.supportPath();
  if (root == null) {
    throw const FileSystemException('App storage is unavailable.');
  }

  final directory = Directory(paths.join(root, 'ReadingLibrary'));
  await directory.create(recursive: true);
  final target = File(paths.join(directory.path, fileName));
  try {
    if (sourcePath != null && sourcePath.trim().isNotEmpty) {
      final source = File(sourcePath);
      if (paths.equals(source.absolute.path, target.absolute.path)) {
        return target.path;
      }
      await source.openRead().pipe(target.openWrite());
    } else if (sourceStream != null) {
      await sourceStream.pipe(target.openWrite());
    } else if (bytes != null) {
      await target.writeAsBytes(bytes, flush: true);
    } else {
      throw const FileSystemException('Selected document has no readable data.');
    }
  } catch (_) {
    if (await target.exists()) await target.delete();
    rethrow;
  }
  return target.path;
}

Future<Uint8List> readReadingFile(String path) async =>
    Uint8List.fromList(await File(path).readAsBytes());

Future<void> deleteReadingFile(String path) async {
  final file = File(path);
  if (await file.exists()) await file.delete();
}
