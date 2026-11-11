# 修复主题模式保存错误导致的页面文字可读性问题

日期：2026-11-12

## 问题

应用切换夜间模式时，`AppTheme.changeThemeMode` 错把模式索引写入 `themeColor`；`ConfigHelper.setThemeMode` 又固定写入 `0`，未保存传入值。用户选择浅色模式后，重启应用会退回“跟随系统”。设备使用深色系统主题时，部分固定浅色背景页面会继承浅色文字，造成白底白字、难以阅读。

## 修改

- 夜间模式选择改为写入 `themeMode` 配置项。
- 夜间模式配置保存调用实际写入传入的模式索引。
- 主题色仍由独立的 `themeColor` 配置维护，切换夜间模式不会改动主题色。

用户若此前已选浅色模式，需要在修复后的应用中重新选择一次“关闭”，之后该选择会正确保留。

## 验证

- 通过设备截图确认当前连接设备运行的是旧包名 `com.nsapp.dashboard`，不是本工程当前包名 `com.yumore.spiderx.flutter`，因此无法据此重现当前源码页面的白字问题。
- 查看设备日志，未发现可定位文字颜色问题的 Flutter 异常；该缺陷来自主题配置写入逻辑。
- 本次静态代码复核确认模式索引只写入 `themeMode`，主题色索引仍走 `setAppTheme`。
- 设备属性 `ro.eink.model` 为空，且连接设备型号为 Pixel 6 Pro，按普通 Android Release 变体处理。
- 用户于 2026-11-11 重新授权构建 APK；按 `--max-workers=6 --no-parallel` 修复并迁移到当前依赖公开 API，包括 `file_picker`、`tray_manager`、`screen_retriever`、`win32`、`media_kit`、Dio、`flutter_webrtc` 与 QuickJS hooks。
- 将 `network_info_plus` 升至 8.2.2，以兼容仓库统一使用的 `win32 6.4.0`。
- 移除 Android Gradle 脚本中没有源码调用、且与 FFmpegKit AAR 冲突的 `FFmpeg-Android v2.0.1` 依赖；短剧媒体流程仍使用 `ffmpeg_kit_flutter_new_min_gpl`。
- SQLite 原生钩子的 x64 Android 发布库通过项目配置的代理下载并校验 SHA-256，写入 `.dart_tool` 缓存；该本机生成文件不纳入 Git。
- `flutter_js` 上游 Android 模块将 Kotlin 字节码设为 1.8，但其 Java 目标被当前 AGP 默认设为 11；宿主仅对该插件将 Java 目标对齐到 1.8，应用本身仍使用 Java/Kotlin 17。
- `share_plus` 的 Kotlin 增量编译缓存漏解析插件内同包类；禁用本次构建的 Kotlin 增量编译后，插件及应用 Kotlin 编译通过。
- 应用最低 Android API 调整到 26，以满足整合的 `ffmpeg_kit_extended_flutter` 插件要求；Android 7.0/7.1（API 24/25）设备不再兼容。
- 短剧原生 FFmpeg 桥改为调用 FFmpegKit 会话 API，并为每个会话绑定日志、进度和取消回调；编译时通过 `compileOnly` 暴露已由 Flutter 插件提供的 API，不再重复打包 FFmpeg 原生库。
- AGP 9.1.1 的默认 Release ProGuard 路径与仓库集中构建目录不一致；Release 变体现将混淆配置指向已生成的共享构建目录文件。
- `flutter_displaymode` 插件自身固定 compileSdk 33，而 AndroidX 依赖要求至少 34；宿主构建现使该插件跟随应用 compileSdk 36。
- Release 构建通过：`./gradlew --max-workers=6 --no-parallel -Pkotlin.incremental=false :app:assembleRelease`。关闭本次 Kotlin 增量编译是为绕过 `share_plus` 任务缓存漏解析同包类的问题。
- APK 已复制至 `dist/spider-worker.apk`（318,698,048 字节，SHA-256：`c7b3838135d91a6b4906fe22bc617f645f4309606aa1986b86724662921ba4f1`）；包名 `com.yumore.spiderx.flutter`，版本 `1.23.0`，最低 API 26、目标 API 36。`apksigner verify` 确认 v2/v3 签名有效。
- 兼容边界：当前公开 `media_kit` API 没有原私有扩展的 `PlayerConfiguration.adBlocker`，因此 HLS 广告过滤仍用于短剧下载，但不作用于播放器播放；`mpv_engine` 的帧呈现计数也没有公开等价接口，`reportsFrames` 关闭。Android surface producer 配置使用插件默认值。上述播放器行为尚未真机验收。
- 当前设备尚未安装新 APK，未完成短视频、播放、滑动切换或页面 UI 验收。
