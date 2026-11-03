import 'dart:math';

import 'package:dashboard/features/reading/local_library/local_reading_file_store.dart';
import 'package:dashboard/features/reading/local_library/local_reading_library_repository.dart';
import 'package:dashboard/features/reading/local_library/local_reading_record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as paths;

class LocalReadingImportService {
  LocalReadingImportService({
    required LocalReadingLibraryRepository repository,
    required LocalReadingFileStore fileStore,
  }) : _repository = repository,
       _fileStore = fileStore;

  final LocalReadingLibraryRepository _repository;
  final LocalReadingFileStore _fileStore;
  final Random _random = Random.secure();

  Future<LocalReadingRecord> importFile(PlatformFile file) async {
    final format = paths
        .extension(file.name)
        .replaceFirst('.', '')
        .toLowerCase();
    if (format != 'epub' && format != 'pdf') {
      throw const FormatException('只支持 EPUB 和 PDF 文件。');
    }
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(1 << 32)}';
    final storedPath = await _fileStore.importFile(
      fileName: '$id.$format',
      sourcePath: file.path,
      sourceStream: file.readAsByteStream(),
    );
    final record = LocalReadingRecord(
      id: id,
      name: paths.basenameWithoutExtension(file.name),
      path: storedPath,
      format: format,
      sizeBytes: await file.length() ?? 0,
      importedAt: DateTime.now(),
    );
    try {
      await _repository.add(record);
    } catch (_) {
      await _fileStore.deleteFile(storedPath);
      rethrow;
    }
    return record;
  }
}
