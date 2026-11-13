# Novel Sound integration

Date: 2026-11-14

## Request and source

Integrate the application capabilities from [ch6vip/novel-sound](https://github.com/ch6vip/novel-sound) into Spider X as real in-repository code, preserve the current reading and shelf flows, and keep dependency and license records.

- Source revision: `c9ffddbbf3c976ccc5735fc7daaf4d6f4426efa8` (`master` at integration time).
- License: GPL-3.0. The source `LICENSE` remains at `packages/novel_sound/LICENSE`; its notices and bundled license records remain with the migrated code/assets. The host project is AGPL-3.0. GPLv3 section 13 provides a combination path with AGPLv3; each component retains its applicable terms.
- The package is integrated from local source at `packages/novel_sound`; the app does not load source code remotely.

## Migrated capabilities

The embedded application carries the upstream online book discovery/search, novel reader, TXT/EPUB import, reader appearance/page controls, local library and grouped shelves, reading/playback progress, backups and restore, WebDAV synchronization, offline chapter/media downloads, system TTS, audiobook playback and controls, short drama, manga drama and comic browsing/playback, and associated source/network settings. The Rust core, flutter_rust_bridge bindings, configuration/filter assets, Android native plugins/services, and original fonts/assets are included so these features use their real business logic.

The new entry is **我的 → 内容入口 → 什锦铺 · 小说与听书**. It opens the migrated `FqApp` in its own provider scope and initializes its runtime once. Existing Spider X novel, reader, and shelf entries remain available and keep their own persistence.

## Platform and dependency wiring

- Android: merges the upstream plugin/channel registrations, media and foreground services, permissions, CMake crypto/tempo JNI libraries, and a Gradle task that builds the Rust core for `arm64-v8a` and `armeabi-v7a`. The Rust and Android CMake builds use NDK `28.2.13676358`.
- Windows: uses the app's generated plugin registration and builds/copies the Rust DLL beside the executable, where the desktop media service loads it. The root CMake target expects Cargo on Windows.
- Other platforms: upstream does not provide a complete supported application runtime; the new entry displays a platform availability message. Existing host features are unchanged.
- The existing Kazumi Windows WebView fork and Novel Sound's fixed-origin cookie reader are unified through `packages/webview_windows`; `dependency_overrides` selects that shared source for both.
- `flutter_secure_storage` is upgraded to `10.3.4` to keep Novel Sound's legacy secure-key import path while allowing the Windows implementation to use the root's required `win32 6.x`; the Windows plugin is pinned to `4.2.2`. Version 10 retains the basic read/write API and provides migration from older Android ciphers.
- Flutter asset directory entries do not recurse. The host explicitly declares the upstream config, filters, images, Lottie data and bundled license text; the three font files are registered in the root font manifest.
- Android Kotlin sources now use `com.yumore.dashboard.novelsound.platform` and `com.yumore.dashboard.novelsound.crypto`; service declarations, host plugin imports and matching JNI export names were updated together.
- The upstream vendored `webview_windows` SDK range was updated for Dart 3.12+, and the unused pinned `screen_retriever 0.2.2` dependency was removed. The root's existing `window_manager` fork supplies the compatible `screen_retriever ^0.3.0` dependency.
- No private backend URL, account token, or production credential is included. The Rust client uses the upstream public content interfaces; optional AI, WebDAV, and user supplied data sources still require user configuration.

## Validation and remaining acceptance

- `flutter pub get`: passed with the shared WebView package and the unified secure-storage/`win32 6.x` dependency graph.
- `flutter analyze --no-pub packages/novel_sound/lib lib/features/novel_sound/novel_sound_entry_page.dart lib/views/user/personal_page.dart`: passed with no issues.
- The unified `webview_windows` package analysis reports 24 info-level lints from retained upstream code; it has no analyzer errors.
- A static asset coverage check found the migrated runtime asset files declared by the host manifest; the three runtime fonts are registered in the font section.
- A `flutter build bundle --no-pub` attempt did not produce a result and was stopped after two no-output Flutter build processes remained active. Asset packaging therefore remains unverified by Flutter's bundler.
- Android/Windows native compilation, packaged artifact, online content, and device UI remain unverified. No APK build was run during this integration.
