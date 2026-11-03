class LocalReadingRecord {
  const LocalReadingRecord({
    required this.id,
    required this.name,
    required this.path,
    required this.format,
    required this.sizeBytes,
    required this.importedAt,
  });

  factory LocalReadingRecord.fromJson(Map<String, dynamic> json) {
    return LocalReadingRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      path: json['path'] as String,
      format: json['format'] as String,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      importedAt:
          DateTime.tryParse(json['importedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String name;
  final String path;
  final String format;
  final int sizeBytes;
  final DateTime importedAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'path': path,
    'format': format,
    'sizeBytes': sizeBytes,
    'importedAt': importedAt.toIso8601String(),
  };
}
