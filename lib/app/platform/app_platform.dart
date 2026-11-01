import 'package:flutter/foundation.dart';

import 'app_platform_detect_web.dart'
    if (dart.library.io) 'app_platform_detect_io.dart';
import 'app_platform_kind.dart';
import 'app_platform_traits.dart';

/// 全局平台能力入口。
///
/// 业务代码统一通过这里判断平台与能力，禁止再直接使用 `Platform.isXxx`、
/// `Platform.operatingSystem` 或 `kIsWeb`，以便 Web/桌面/鸿蒙构建时行为可预期。
abstract final class AppPlatform {
  static AppPlatformTraits _traits = detectAppPlatformTraits();

  static AppPlatformTraits get traits => _traits;

  /// 测试注入平台能力（例如模拟 Web / 鸿蒙）。
  @visibleForTesting
  static void overrideTraits(AppPlatformTraits traits) {
    _traits = traits;
  }

  /// 恢复为运行时检测到的真实平台。
  @visibleForTesting
  static void resetTraits() {
    _traits = detectAppPlatformTraits();
  }

  static AppPlatformKind get kind => _traits.kind;

  static bool get isWeb => _traits.isWeb;
  static bool get isAndroid => _traits.isAndroid;
  static bool get isIOS => _traits.isIOS;
  static bool get isMacOS => _traits.isMacOS;
  static bool get isWindows => _traits.isWindows;
  static bool get isLinux => _traits.isLinux;
  static bool get isOhos => _traits.isOhos;
  static bool get isMobile => _traits.isMobile;
  static bool get isDesktop => _traits.isDesktop;

  static bool get supportsFileSystem => _traits.supportsFileSystem;
  static bool get supportsImagePicker => _traits.supportsImagePicker;
  static bool get supportsSqlite => _traits.supportsSqlite;
  static bool get supportsWebView => _traits.supportsWebView;
  static bool get supportsSocket => _traits.supportsSocket;
  static bool get supportsNativeToast => _traits.supportsNativeToast;
  static bool get supportsScreenBrightness => _traits.supportsScreenBrightness;
  static bool get supportsVideoPlayback => _traits.supportsVideoPlayback;
  static bool get supportsSelfUpdate => _traits.supportsSelfUpdate;

  static String get channel => _traits.channel;
  static String get displayName => _traits.displayName;
}
