import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/main.dart' show initServices;

/// Starts SimpleLive once and stores its Hive data under an app-specific path.
class SimpleLiveEmbeddedBootstrap {
  static Future<void>? _initialization;

  static Future<void> initialize() => _initialization ??= _initialize();

  static Future<void> _initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();
    final supportDirectory = await getApplicationSupportDirectory();
    final hivePath = '${supportDirectory.path}/dashboard/simple_live/hive';
    Hive.init(hivePath);
    await initServices();
  }
}
