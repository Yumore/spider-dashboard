import 'package:shared_preferences/shared_preferences.dart';

/// Persists the address of the user's self-hosted Pure Live NAS service.
class PureLiveNasEndpointStore {
  static const _endpointKey = 'pure_live_nas_endpoint';

  Future<String> read() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_endpointKey) ?? '';
  }

  Future<void> write(String endpoint) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_endpointKey, endpoint);
  }
}
