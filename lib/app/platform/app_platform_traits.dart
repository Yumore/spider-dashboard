import 'app_platform_kind.dart';

/// 平台能力描述。
///
/// 只描述“该平台能做什么”，不访问任何平台 API，便于纯 Dart 单元测试。
class AppPlatformTraits {
  const AppPlatformTraits(this.kind);

  final AppPlatformKind kind;

  bool get isWeb => kind == AppPlatformKind.web;
  bool get isAndroid => kind == AppPlatformKind.android;
  bool get isIOS => kind == AppPlatformKind.ios;
  bool get isMacOS => kind == AppPlatformKind.macos;
  bool get isWindows => kind == AppPlatformKind.windows;
  bool get isLinux => kind == AppPlatformKind.linux;
  bool get isOhos => kind == AppPlatformKind.ohos;

  /// 手机形态平台（含鸿蒙手机）。
  bool get isMobile => isAndroid || isIOS || isOhos;

  /// 桌面形态平台。
  bool get isDesktop => isMacOS || isWindows || isLinux;

  /// 本地文件系统：Web 与无法识别的平台不允许调用原生路径接口。
  bool get supportsFileSystem => !isWeb && kind != AppPlatformKind.unknown;

  /// 图片选择：标准插件覆盖七个目标平台中的六个；OHOS 需单独接入实现。
  bool get supportsImagePicker => !isOhos && kind != AppPlatformKind.unknown;

  /// SQLite：移动端使用 sqflite 插件、桌面使用 ffi、Web 使用 ffi web。
  /// 未知平台没有可用的 databaseFactory，返回 false。
  bool get supportsSqlite => kind != AppPlatformKind.unknown;

  /// 内嵌 WebView：Android/iOS/macOS 有插件实现；桌面其余平台与 Web 降级。
  bool get supportsWebView => isAndroid || isIOS || isMacOS;

  /// 原生 Socket（局域网聊天）：仅已识别的 io 平台。
  bool get supportsSocket => !isWeb && kind != AppPlatformKind.unknown;

  /// 原生 toast：fluttertoast 仅声明 Android/iOS/Web；桌面与鸿蒙降级 SnackBar。
  bool get supportsNativeToast => isAndroid || isIOS || isWeb;

  /// 屏幕亮度：screen_brightness 声明 Android/iOS/macOS/Windows/鸿蒙。
  bool get supportsScreenBrightness =>
      isAndroid || isIOS || isMacOS || isWindows || isOhos;

  /// 内嵌视频播放：media_kit 依赖原生动态库，Web 与未知平台降级为提示。
  bool get supportsVideoPlayback =>
      isAndroid || isIOS || isMacOS || isWindows || isLinux;

  /// 应用内自更新（下载并安装安装包）：仅 Android/iOS 旧流程。
  bool get supportsSelfUpdate => isAndroid || isIOS;

  /// 后端接口 `channel` 参数取值。
  String get channel => switch (kind) {
    AppPlatformKind.android => 'android',
    AppPlatformKind.ios => 'ios',
    AppPlatformKind.macos => 'macos',
    AppPlatformKind.windows => 'windows',
    AppPlatformKind.linux => 'linux',
    AppPlatformKind.web => 'web',
    AppPlatformKind.ohos => 'ohos',
    AppPlatformKind.unknown => 'unknown',
  };

  /// 界面展示名称。
  String get displayName => switch (kind) {
    AppPlatformKind.android => 'Android',
    AppPlatformKind.ios => 'iOS',
    AppPlatformKind.macos => 'macOS',
    AppPlatformKind.windows => 'Windows',
    AppPlatformKind.linux => 'Linux',
    AppPlatformKind.web => 'Web',
    AppPlatformKind.ohos => 'HarmonyOS',
    AppPlatformKind.unknown => '未知平台',
  };
}
