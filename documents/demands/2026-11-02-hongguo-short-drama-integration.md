# 红果鉴短剧能力集成

日期：2026-11-02

## 目标与来源

将 [czgyz/hongguo](https://github.com/czgyz/hongguo) 中可独立运行的短剧业务接入 Dashboard，保留其站源逻辑和页面行为，并由宿主工程统一管理 Flutter 依赖。迁入源码对应版本：`b0b56ce18f2d66cdde715439eeaea7472d461301`。

本集成不依赖上游私有后端。站源请求仍由客户端直接访问各自公开服务；每个站点的可用性受其服务状态、网络、签名规则和反爬策略影响。

## 已迁入的能力

- 红果及全站短剧源的目录、搜索联想、榜单、推荐、详情、分集和多线路播放。
- 播放器控制、HLS 本地代理、弹幕、自动连播、重试、清晰度和倍速设置。
- 追剧记录、播放进度、下载队列、后台下载、本地媒体库、导入导出和多用户权限。
- 局域网设备发现、播放接续、Android TV 遥控器布局、画中画和本地 FFmpeg 媒体处理。
- Go 原生核心及 FFI 桥接、视频增强 shader 资源与对应上游许可证文件。

上游 README 对部分第三方站源标注“待验证”，并记录了特定站点的 Cloudflare 拦截、空数据或外部条件限制；迁入不代表这些站点当前可用。

## 宿主集成

- 入口位于“视频”和“短剧”目录，统一通过 `AppCapability.shortDrama` 仅在 Android 显示。
- 短剧模块复用上游独立工作台及其本地存储、Go 核心和媒体流程；离开工作台仍返回宿主目录。
- Android Activity 只负责 Flutter 生命周期，电视显示、设备状态、画中画、FFmpeg 和方法通道分别由独立 Kotlin 类处理。
- `ALL_SOURCES` 默认启用；Gradle 将 Dart define 同步给 Go 原生库，避免 Dart 与 Go 两侧站源配置不一致。
- Android 最低版本设为 API 23。Android Gradle `preBuild` 会调用 `tool/build_short_drama_native.py`，按 arm64-v8a、armeabi-v7a、x86_64 编译 Go 核心；需要 Go 1.24.1 或更新版本和 Android NDK 28.2.13676358（可通过 `ANDROID_NDK_HOME` 指定）。
- Android 本地媒体处理使用上游的 FFmpeg-Android v2.0.1 与 JitPack。上游 README 说明其 FFmpeg 原生库在 arm64 上验证；其他 ABI 的本地 FFmpeg 能力需设备验收。
- Web 使用平台占位页面，避免引入 `dart:io`、FFI 和 Android 方法通道；短剧入口不会在 Web 显示。

## 许可证与边界

用户已确认拥有上游源码复用权，并同意工程采用 AGPL-3.0；根目录 `LICENSE` 和 [第三方许可清单](../THIRD_PARTY_NOTICES.md) 记录了组合工程与各来源许可。视频增强资源原有的 LGPL、GPL 和 Anime4K 许可证文本及清单继续保留。公开发布前仍需按各依赖许可证履行声明与源码提供义务。

目标工程仍支持其他平台，但上游 README 已将 Windows、iOS 支持移除，并说明 macOS 不再构建；因此这些平台不提供短剧入口。鸿蒙也没有上游原生适配实现。

## 验收状态

- `flutter pub get`：当前整合工程依赖解析成功，锁文件已更新。
- Go 核心：`go -C native build -o /tmp/dashboard-native-core-danmaku-check ./bridge` 成功，包含 Zhenguo 核心及红果弹幕链路。
- 定向 Dart 分析：播放器、原生桥接、弹幕控制器和模型文件无 error/warning；31 项 info 级提示为代码风格提示。
- Web release、Android Gradle 编译与 APK：本轮均未构建；此前单模块构建记录不代表当前六仓库整合后的构建状态。
- Android 真机站源请求、播放、后台下载、画中画、局域网接续和 Android TV 遥控器：尚待设备验收。
- 第三方站源的当前接口、账号限制和反爬响应：未逐个在线验收。
