import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's selected local media paths for the device library.
class LocalMediaLibraryStore {
  static const String _key = 'local_media_library_managed_paths_v1';

  Future<List<String>> load() async =>
      (await SharedPreferences.getInstance()).getStringList(_key) ?? const [];

  Future<void> save(List<String> paths) async =>
      (await SharedPreferences.getInstance()).setStringList(_key, paths);
}
