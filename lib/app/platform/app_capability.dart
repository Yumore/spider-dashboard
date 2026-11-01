import 'app_platform.dart';

/// 功能能力标签：入口 catalog 依据它决定是否展示某个功能入口。
enum AppCapability {
  fileSystem,
  imagePicker,
  sqlite,
  webView,
  socket,
  screenBrightness,
  videoPlayback,
  shortDrama,
  selfUpdate,
}

/// 能力查询入口，统一委托给 [AppPlatform]。
abstract final class AppCapabilities {
  static bool supports(AppCapability capability) => switch (capability) {
    AppCapability.fileSystem => AppPlatform.supportsFileSystem,
    AppCapability.imagePicker => AppPlatform.supportsImagePicker,
    AppCapability.sqlite => AppPlatform.supportsSqlite,
    AppCapability.webView => AppPlatform.supportsWebView,
    AppCapability.socket => AppPlatform.supportsSocket,
    AppCapability.screenBrightness => AppPlatform.supportsScreenBrightness,
    AppCapability.videoPlayback => AppPlatform.supportsVideoPlayback,
    AppCapability.shortDrama => AppPlatform.isAndroid,
    AppCapability.selfUpdate => AppPlatform.supportsSelfUpdate,
  };
}
