# 跨平台兼容改造与发布打包（2026-11-01）

## 2026-11-01 打包脚本与兼容补充

新增统一发布入口 `tool/package.dart`，并提供 `tool/package.sh`（macOS/Linux）和 `tool/package.ps1`（Windows）包装脚本。标准 Flutter 目标为 Android APK、iOS IPA、macOS `.app`、Windows Release 目录、Linux bundle 目录和 Web 静态目录；脚本逐目标检查宿主系统、Flutter/Dart 版本和预期产物。Windows 桌面构建需在 Windows，Linux 需在 Linux，iOS/macOS 需在 macOS；Android 和 Web 可在标准 Flutter 支持的主机上构建。

统一用法：

```sh
./tool/package.sh web
./tool/package.sh android
./tool/package.sh ios
./tool/package.sh macos
./tool/package.sh windows
./tool/package.sh linux
./tool/package.sh ohos
```

Windows 使用 `tool/package.ps1 <目标>`；也可在工程根目录运行 `dart tool/package.dart <目标>`。传入 `--dry-run` 仅显示命令，不检查工具链或启动构建。标准 SDK 可通过 `FLUTTER_BIN` 指定。

目标机器仍需安装相应原生工具链：Android SDK/签名配置、iOS/macOS 的 Xcode、Windows 的 Visual Studio C++ 桌面工具、Linux 的 clang/CMake/Ninja/GTK 开发库。脚本检查宿主系统和 Flutter/Dart 版本，原生 SDK、证书和签名错误由 Flutter/Xcode/DevEco 构建工具报告。

鸿蒙使用独立目标 `ohos`：设置 `OHOS_FLUTTER_BIN` 指向 OpenHarmony 适配版 Flutter。首次配置可执行 `dart tool/package.dart setup-ohos`，脚本只在尚无 `ohos/` 时调用 `flutter create --platforms=ohos .`，不会覆盖已有平台壳。工程当前最低要求 Flutter 3.32 / Dart 3.8，因此旧版 OHOS SDK 不能用于本工程。HAP 构建还要求 DevEco/OpenHarmony SDK、签名设置和各原生插件的 OHOS 实现；脚本不伪造插件适配或签名。

平台能力层新增图片选择能力：标准 Android、iOS、macOS、Windows、Linux、Web 使用 `image_picker`；OHOS 和未知平台在调用插件前返回不支持提示。未知平台同时不再宣称文件系统和 Socket 可用。Web、桌面和鸿蒙原有的 WebView、媒体、文件系统及 toast 降级继续由 `AppPlatformTraits` 管理。

本轮本机发现 `/opt/harmonyos` 为 Flutter 3.7.12-ohos-1.0.3 / Dart 2.19.6，且本机未发现 DevEco Studio、`ohos/` 平台壳、`hdc`、`ohpm` 或 `hvigor`，因此没有生成 OHOS 壳或构建 HAP。Windows 和 Linux 包也未在 macOS 上构建。发布命令以 Flutter 官方各平台构建目标为基础，OHOS 使用 OpenHarmony Flutter 分支的 `flutter build hap --release`。

验证记录：`dart analyze tool/package.dart` 无问题；`bash -n tool/package.sh` 通过；七个平台的 `--dry-run` 命令映射和 OHOS 初始化命令均通过。当前 Pub 缓存缺少 `image_picker` 等依赖，应用层定向 analyze 无法完成；未运行测试，也未实际构建或签名任何平台包。PowerShell 解析器本机不可用，因此 `.ps1` 仅做了人工审查。

## 历史兼容改造（2026-10-18）

以下盘点、实施记录和验证结果描述 2026-10-18 当时的工作，不代表本轮重新构建或设备验收。

## 需求

> 兼容 web/Windows/MacOS/Linux/鸿蒙 平台

目标：让 dashboard 在原有 Android/iOS 之外，能在 Web、Windows、macOS、Linux 上构建并启动主要业务，鸿蒙（OHOS）给出可执行结论与代码层准备；无法在本机验证的平台如实说明，不虚构"已支持"。

## 现状盘点（改造前）

| 项 | 状态 |
| --- | --- |
| 平台目录 | `android/ ios/ linux/ macos/ web/ windows/`，无 `ohos/` |
| 工具链 | Flutter 3.47.7 / Dart 3.13.5（工程要求 Dart ≥3.8） |
| 鸿蒙工具链 | `/opt/harmonyos` = Flutter 3.7.12-ohos / Dart 2.19.6 |
| Web 构建 | 编译失败（`dart:io` 顶层导入） |
| 桌面构建 | 无 sqlite 动态库初始化；macOS 缺 network.client 权限；本机未装 CocoaPods |

阻塞点：

1. `lib/main.dart` 顶层 `import 'dart:io'`，`main()`/`checkUpdate()` 使用 `Platform.isAndroid`；`initDatabase()` 直接 `getDatabasesPath()+openDatabase`（Web 无 databaseFactory，桌面无 sqlite 库）。
2. 35 个文件 `import 'dart:io'`（File/Directory/Socket），涉及下载、导出、本地书库、图片缓存、AnimeTrace 备份、LAN 聊天等。
3. 12 处 `path_provider`；Web 无文件系统。
4. 2 处实际使用 `webview_flutter`（`views/news/news_detail.dart`、`views/other/web_page.dart`；`comic/picacomic/sources/nhentai_source.dart` 仅在注释提及），Windows/Linux 无 webview 插件实现。
5. `Platform.operatingSystem` 写进接口 channel 参数（`app/api.dart`、`app/api/api_util.dart`）→ Web 直接崩溃。
6. `Platform.isIOS/isAndroid` 用于 UI 分支（comic/novel/news 推荐 banner、设置页、checkUpdate）。
7. 89 处 `Fluttertoast.showToast`：插件只声明 android/ios/web，桌面端会 MissingPluginException。
8. `screen_brightness` 只声明 android/ios/macos/windows/ohos；Web/Linux 调用需守卫。
9. `LanChatClient` 使用 `Socket`（仅 io）。
10. macOS 权限：`DebugProfile.entitlements` 只有 `network.server`，`Release.entitlements` 只有 `app-sandbox`；沙箱应用联网需要 `network.client`。
11. 鸿蒙：现有 SDK 为 Dart 2.19.6，工程要求 Dart ≥3.8，**当前无法编译**，不生成 `ohos/` 壳以免用旧模板污染工程。

## 方案

### 1) 平台能力层 `lib/app/platform/`（一个文件一个类）

- `app_platform.dart`：`AppPlatform`（平台种类 + 能力判定，可注入 traits 便于测试，不顶层 import `dart:io`）。
- `app_platform_traits.dart`：`AppPlatformTraits` 值对象（kind + 能力布尔）。
- `app_platform_detect_io.dart` / `app_platform_detect_web.dart`：条件导入检测（`Platform.operatingSystem` 含 `ohos` 判定 / `kIsWeb`）。
- `app_database_factory.dart` + `_io/_web` 条件实现：桌面（Windows/Linux/macOS）用 `sqflite_common_ffi`，移动端沿用 sqflite 插件，Web 用 `sqflite_common_ffi_web`。
- `app_directories.dart`：应用文档/数据库目录（Web 返回 null，能力层据此降级）。
- `app_toast.dart`：`AppToast.show()` 统一 toast（移动/Web 走 fluttertoast，桌面/鸿蒙走全局 ScaffoldMessenger）。
- `app_messenger.dart`：全局 `scaffoldMessengerKey`（脱离 context 的提示）。
- `app_web_view.dart`：`AppWebView`（Android/iOS/macOS 真 WebView；Web/Windows/Linux/鸿蒙 降级为"在浏览器打开"卡片）。
- `app_local_image.dart`：本地图片 provider（io→FileImage，web→NetworkImage/占位）。
- `app_capability.dart`：`AppCapability` 枚举 + `AppCapabilities.supports`，供入口 catalog 过滤。

### 2) 启动链路

`main.dart`：去掉 `dart:io`；`await AppPlatformBootstrap.initialize()`（SystemChrome 守护、DB factory 初始化、MediaKit 不在此初始化）；`initDatabase()` try/catch，失败置空 history/download provider 并允许启动；`MaterialApp` 挂 `scaffoldMessengerKey`；`checkUpdate()` 仅移动端执行并按平台取 URL。

### 3) 业务降级（Web/桌面）

- 入口 catalog 依据能力过滤：本次对 6 个入口标注 `requires`（B站/YouTube 下载、FeedBooks 下载、AnimeTrace 备份、抖音、本地短视频演示）；其余无文件系统/WebView/Socket 依赖的功能（漫画下载、爬虫导出、局域网聊天等）靠运行期能力守卫给出提示，不删除入口。
- `api`/`api_util` 的 channel 改 `AppPlatform.channel`（android/ios/macos/windows/linux/web/ohos）。
- `Platform.isIOS` / `Platform.isAndroid` 全部迁移到 `AppPlatform`。
- `Fluttertoast.showToast` 统一为 `AppToast.show`。
- 屏幕亮度、path_provider、Socket、File 访问按能力守卫，走提示而非抛异常。

### 4) 桌面与鸿蒙

- macOS：两个 entitlements 增加 `com.apple.security.network.client`。
- Windows/Linux：README/文档记录 `flutter config --enable-windows-desktop / --enable-linux-desktop`、Windows 需 VS 桌面 C++ 工具链、Linux 需 clang/cmake/ninja/GTK3/libsqlite3-dev。
- 鸿蒙：代码层用 `operatingSystem == 'ohos'` 识别，能力按移动端近似；文档记录升级路径（需 Flutter ≥3.32 / Dart ≥3.8 的 ohos fork，再 `flutter create --platforms=ohos .` 与插件替换）。本机旧 SDK 不编译。

## 验证矩阵

| 平台 | 验证方式 |
| --- | --- |
| Web | `flutter build web --release` 成功；`flutter test --platform chrome` 页面 smoke；浏览器 headless 控制台无未捕获异常 |
| macOS | `flutter build macos --debug`（需 CocoaPods；本机缺失则如实说明） |
| Windows / Linux | 静态分析 + 平台能力单测；本机 macOS 无法交叉构建，文档记录构建前置 |
| 鸿蒙 | 结论：工具链版本不兼容，未构建；给出升级步骤与缺口清单 |
| 全部 | `dart analyze lib test` 0 error；`flutter test --no-pub` 全部通过 |

## 风险

- Web 无文件系统：下载/导出/本地缓存类功能只能提示"当前平台不支持"，需在 UI 明确。
- `sqflite_common_ffi_web` 需要在 `web/` 放置 `sqlite3.wasm` 与 worker（`dart run sqflite_common_ffi_web:setup` 下载）；下载失败则 Web 关闭 DB 相关模块。
- 鸿蒙未验证，不宣称支持；仅代码层识别与文档。

## 实施结果（2026-10-18）

### 平台能力层（已落地）

`lib/app/platform/` 下按"一个文件一个类"拆分：

| 文件 | 职责 |
| --- | --- |
| `app_platform_kind.dart` | `AppPlatformKind { android, ios, macos, windows, linux, web, ohos, unknown }` |
| `app_platform_traits.dart` | `AppPlatformTraits(kind)` 纯值对象：`supportsFileSystem/sqlite/webView/socket/nativeToast/screenBrightness/videoPlayback/selfUpdate`、`channel`、`displayName` |
| `app_platform_detect_io.dart` / `_web.dart` | 运行时检测（`Platform.operatingSystem == 'ohos'` → ohos；web → web） |
| `app_platform.dart` | `AppPlatform` 门面；`@visibleForTesting overrideTraits/resetTraits` 便于单测注入平台 |
| `app_capability.dart` | `AppCapability` 枚举 + `AppCapabilities.supports` |
| `app_database_factory.dart` + `_stub/_io/_web.dart` | Android/iOS/macOS 沿用 sqflite；Windows/Linux `sqfliteFfiInit()+databaseFactoryFfi`；Web `databaseFactoryFfiWeb` |
| `app_directories.dart` | 文档/临时/支持目录；Web 返回 null 由调用方降级 |
| `app_toast.dart` + `app_messenger.dart` | 统一 toast：原生 toast 走 fluttertoast，桌面/鸿蒙走全局 `ScaffoldMessenger` |
| `app_local_image.dart` + `_io/_stub.dart` | 本地图片 provider：io→FileImage，Web→NetworkImage |
| `app_file_writer.dart` + `_io/_stub.dart` | 本地文件写入：Web 返回 null，调用方提示"当前平台不支持保存到本地" |
| `app_web_view.dart` + `_io/_stub.dart` + `_fallback.dart` | `AppWebView` + 自定义 scheme 拦截回调；无 WebView 插件平台降级为"在浏览器打开"卡片 |
| `app_platform_bootstrap.dart` | 启动时初始化数据库工厂 |

### 业务改造

- `main.dart`：去掉 `dart:io`，启动第一步 `AppPlatformBootstrap.initialize()`；`SystemChrome`、`initDatabase()` 全部 try/catch，SQLite 不可用时应用仍可启动（依赖历史/下载记录的旧版页面会因空数据库不可用）；`MaterialApp` 挂 `scaffoldMessengerKey`；自更新仅 Android/iOS。
- 接口 channel：`app/api.dart`、`app/api/api_util.dart` 改用 `AppPlatform.channel`（含 web/ohos 取值）。
- UI 平台分支：`Platform.isIOS/isAndroid` → `AppPlatform.isIOS/isAndroid`（漫画/小说/新闻推荐位、设置页等）。
- Toast：89 处 `Fluttertoast.showToast` → `AppToast.show`（29 个文件；这些文件仍保留 `fluttertoast` 导入以使用 `Toast` 常量类型，但不再直接调用插件方法）。
- 视频：`media_kit` 仅保留在 `short_video_player_state.dart`、`media_playback_page_state.dart`；Web 由条件导入改用 `short_video_player_state_stub.dart`、`media_playback_page_state_stub.dart`，明确显示"当前平台暂不支持内嵌播放"。
- WebView：`views/news/news_detail.dart`、`views/other/web_page.dart` 改用 `AppWebView`，dmzjimage/dmzjandroid 拦截与标题同步回调保留。
- 入口能力过滤：`ContentEntry.requires(AppCapability)` + `ContentEntrySectionView` 过滤；B站/YouTube/抖音/本地短视频、Feedbooks 下载、AnimeTrace 本地备份在 Web 隐藏。
- 运行时守卫：`AppPlatformBootstrap.initialize()`（失败仅记录日志，不阻断启动）、图片保存（`utils.dart` 先判断文件系统能力再走 `AppFileWriter`）、开眼社区头像/封面上传（Web 提示不支持）、微信气泡本地图、AnimeTrace 封面/笔记图、爬虫导出、局域网聊天入口、系统亮度（含 comic_reader 关闭与亮度滑杆两处）、阅读数据库路径（Web 走 `databaseFactory.getDatabasesPath()`）、EasyTV 本地订阅文件、ESO 压缩书源、TSDM deflate 解压，均在不支持平台上给出提示/降级而不是抛异常。

### SQLite 与构建材料

- `sqlite3` 3.x 通过 build hooks 下载预编译库；本机直连 GitHub 下载失败（`Connection closed before full header received`）。已在 `pubspec.yaml` 增加镜像 `url_pattern`（`ghproxy.net` 前缀，sha256 校验仍由 package 完成），hooks 可正常完成 → Windows/Linux/macOS 构建不再缺 sqlite 动态库。
- Web SQLite：`dart run sqflite_common_ffi_web:setup --sqlite3-wasm-url <镜像地址>` 生成 `web/sqflite_sw.js`（264,107 B）与 `web/sqlite3.wasm`（748,686 B，来自 sqlite3-3.6.0 release）；`flutter build web` 会把两者复制进 `build/web/`。
- macOS：`DebugProfile.entitlements` 与 `Release.entitlements` 均补 `com.apple.security.network.client`；`macos/Podfile` 调整为 `platform :osx, '12.0'`（适配当前插件最低版本）。`flutter build macos` 生成的 `macos/Flutter/ephemeral/*`、`Runner.xcodeproj/project.pbxproj`、`AppDelegate.swift`、`Runner.xcscheme` 属于本机生成物，已还原，不纳入改动。

## 实际验证（2026-10-18）

| 平台 | 证据 | 结论 |
| --- | --- | --- |
| Web 构建 | `flutter build web --no-wasm-dry-run` → `✓ Built build/web`（76.4s，main.dart.js 6.99 MB，含 sqlite3.wasm + sqflite_sw.js） | 通过 |
| Web 运行时 | 真实 Chrome 执行：`test/app_platform_test.dart` 9/9、`test/widget_test.dart`+`test/content_ui_kit_test.dart` 4/4（内容中心渲染 8 模块、打开模块页、入口栅格） | 通过（覆盖启动后主路径；未做完整浏览器人工走查） |
| macOS | `flutter build macos --debug` → `CocoaPods not installed or not in valid state`；开启 Swift Package Manager 后仍因 media_kit 系列插件未提供 SPM 而回退 CocoaPods；`gem install --user-install cocoapods` 被本机 ruby-china 镜像 SSL 证书错误阻断（`certificate rejected`） | 配置已就绪，构建受本机工具链阻塞 |
| Windows / Linux | 本机为 macOS，Flutter 不支持交叉构建 | 代码/依赖已就绪，未在本机构建 |
| 全量回归 | `flutter test --no-pub` → 1677 通过，exit 0；`dart analyze lib test` → 0 error / 9 warning / 1118 info（与改造前基线持平） | 通过 |
| 鸿蒙 | `/opt/harmonyos` 为 Flutter 3.7.12-ohos / Dart 2.19.6，工程要求 Dart ≥3.8 | 当前工具链无法编译；代码层已识别 `ohos` 并给予移动端能力，未生成 `ohos/` 壳 |

## 已知限制

1. Web 端不提供：本地文件下载/导出、内嵌 WebView、内嵌视频播放、局域网 Socket、系统亮度、应用内自更新；对应入口隐藏或提示。
2. Web 端 SQLite 依赖 `web/sqlite3.wasm` 与 `web/sqflite_sw.js`，重新克隆仓库后需保留这两个文件（已 `git add` 纳入工作区，随仓库提交生效）；若被删除需重新执行 setup。
3. 若 Web 端 SQLite worker/wasm 未能加载（文件缺失、隐私模式禁用 IndexedDB），启动不会崩溃，但依赖 `ComicHistoryProvider`/`ComicDownloadProvider` 的旧版页面会抛空值错误；此时仅内容中心与各模块页可用。
4. 未做设备级 UI 走查（按 AGENTS 约定不主动构建 APK）；桌面/鸿蒙只做到"代码与依赖就绪 + 本机可验证部分验证"。

## 各平台打包入口

请使用上方 `tool/package.dart` 或对应 shell/PowerShell 包装脚本。脚本执行后保留 Flutter 的标准输出目录：Android `build/app/outputs/flutter-apk/`、iOS `build/ios/ipa/`、macOS `build/macos/Build/Products/Release/`、Windows `build/windows/`、Linux `build/linux/`、Web `build/web/`、OHOS `ohos/entry/build/default/outputs/`。

## 独立审查与修复（2026-10-18）

本轮代码改动由两个只读审查者独立审查（只审查本会话跨平台改动，不含既有迁移改动）。审查范围：平台能力层、`main.dart` 启动链路、接口 channel、Toast 抽象、media_kit 条件导入、WebView 适配、入口能力过滤、Web SQLite 资产、macOS 配置与文档准确性。

审查发现与处理：

| 严重度 | 发现 | 处理 |
| --- | --- | --- |
| 阻塞 | `comic_reader.dart` 关闭与亮度滑杆两处 `ScreenBrightness` 未按能力守卫 | 已补 `AppPlatform.supportsScreenBrightness` 两处判断 |
| 阻塞 | `web/sqlite3.wasm`、`web/sqflite_sw.js` 未纳入版本控制，文档却称"已提交" | 已 `git add` 两文件；文档改为"已纳入工作区，随提交生效" |
| 重要 | `AppPlatformBootstrap.initialize()` 在 try/catch 之外，工厂初始化失败会白屏 | 已包 try/catch，失败仅记录日志并继续启动 |
| 重要 | Web SQLite 不可用时旧版历史/下载页会 `database!` 空值崩溃，与文档"降级显示"不符 | 文档与 `main.dart` 注释改为如实描述；不宣称已做 UI 降级 |
| 风险 | 开眼社区头像/封面上传在 Web 用 `MultipartFile.fromFile` 会抛异常 | 选择图片前判断文件系统能力，Web 提示"暂不支持上传图片" |
| 风险 | 图片保存绕过能力判定，Web 只显示"保存失败" | 保存前判断 `supportsFileSystem`，Web 明确提示"不支持保存到本地" |
| 风险 | `supportsSqlite` 对 unknown 恒为 true、`supportsVideoPlayback` 对 OHOS 为 true（无 media_kit OHOS 库） | 已收紧：unknown 的 SQLite 为 false；视频播放仅 Android/iOS/macOS/Windows/Linux |
| 风险 | macOS 生成物（`Flutter/ephemeral/*`、pbxproj、AppDelegate、xcscheme）被顺带修改 | 已 `git checkout` 还原，仅保留 entitlements 与 Podfile 调整 |
| 文档 | 版本号、媒体 stub 文件名、WebView 数量、能力过滤覆盖范围、toast 抽象描述不准确 | 已逐条修正 |

审查后复核：`dart analyze lib test` 0 error / 9 warning / 1118 info；`flutter test --no-pub` 1677 通过；`flutter build web --no-wasm-dry-run` 重新构建通过。

未修复（已知、非本轮范围）：`lib/features/reading/book/util/book_local_store.dart` 的 `DirectoryUtil`（无调用方的死代码）仍直接使用 path_provider；旧版 `lib/views/` 历史/下载页依赖 SQLite 且无降级 UI。
