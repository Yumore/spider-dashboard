import 'dart:convert';

import 'package:dashboard/features/reading/local_library/local_reading_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalReadingLibraryRepository {
  LocalReadingLibraryRepository({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _storageKey = 'reading.local_library.v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<List<LocalReadingRecord>> loadAll() async {
    final raw = (await _prefs).getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                LocalReadingRecord.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(growable: false);
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  Future<void> add(LocalReadingRecord record) async {
    final records = await loadAll();
    final next = records.where((item) => item.id != record.id).toList()
      ..insert(0, record);
    await (await _prefs).setString(
      _storageKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> remove(String id) async {
    final next = (await loadAll()).where((item) => item.id != id).toList();
    await (await _prefs).setString(
      _storageKey,
      jsonEncode(next.map((item) => item.toJson()).toList()),
    );
  }
}
