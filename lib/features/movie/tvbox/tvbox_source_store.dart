import 'package:shared_preferences/shared_preferences.dart';

/// Stores only the user-entered TVBox catalog URL.
class TvBoxSourceStore {
  static const String _key = 'tvbox_source_catalog_url_v1';

  Future<String?> load() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  Future<void> save(String url) async =>
      (await SharedPreferences.getInstance()).setString(_key, url);
}
