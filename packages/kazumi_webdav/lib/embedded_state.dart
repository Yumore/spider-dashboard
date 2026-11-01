import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:kazumi/services/download/download_directory_service.dart';
import 'package:kazumi/services/network/ech_http_licenses.dart';
import 'package:kazumi/services/network/metered_network_service.dart';
import 'package:kazumi/services/network/proxy_manager.dart';
import 'package:kazumi/services/platform/webview_feature_service.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

/// Initializes Kazumi services once and isolates its persistent data from the
/// host application and other embedded modules.
class KazumiEmbeddedBootstrap {
  static Future<void>? _initialization;

  static Future<void> initialize() => _initialization ??= _initialize()
      .catchError((Object error, StackTrace stackTrace) {
        _initialization = null;
        Error.throwWithStackTrace(error, stackTrace);
      });

  static Future<void> _initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    registerEchHttpLicenses();
    MediaKit.ensureInitialized();

    if (Platform.isAndroid) {
      await WebViewFeatureService.initialize();
    }

    final supportDirectory = await getApplicationSupportDirectory();
    final hivePath = '${supportDirectory.path}/dashboard/kazumi/hive';
    await Hive.initFlutter(hivePath);
    await GStorage.init(hivePath: hivePath);
    await DownloadDirectoryService().restoreAccess();
    await MeteredNetworkService.refresh();
    ProxyManager.applyProxy();
  }
}
