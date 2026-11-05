import 'package:shared_preferences/shared_preferences.dart';

class LocalTextReadingProgressRepository {
  LocalTextReadingProgressRepository({SharedPreferences? preferences})
    : _preferences = preferences;

  static const String _keyPrefix = 'reading.local_text_progress.v1.';

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<double> loadOffset(String documentId) async =>
      (await _prefs).getDouble('$_keyPrefix$documentId') ?? 0;

  Future<void> saveOffset(String documentId, double offset) async {
    await (await _prefs).setDouble('$_keyPrefix$documentId', offset);
  }

  Future<void> clear(String documentId) async {
    await (await _prefs).remove('$_keyPrefix$documentId');
  }
}
