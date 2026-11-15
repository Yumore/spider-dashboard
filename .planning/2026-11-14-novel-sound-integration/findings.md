# Findings & Decisions

## Requirements
- Integrate all usable features from `https://github.com/ch6vip/novel-sound` into the current Flutter project, not merely a URL or external source link.
- Preserve the real feature logic and ensure users can reach the integrated experience through the app.
- Respect the workspace's AGPL-3.0 licensing and document the upstream commit, license, local changes, and notices.
- Existing unrelated untracked planning files (`findings.md`, `progress.md`, `task_plan.md`) predate this task; do not overwrite or stage them.

## Research Findings
- Current requested upstream HEAD is `c9ffddbbf3c976ccc5735fc7daaf4d6f4426efa8` (`master`, checked 2026-11-14). It is a Flutter + Rust app, 42 MB shallow checkout.
- GitHub lists GPL-3.0. The root project already carries AGPL-3.0. GNU GPLv3 §13 expressly permits combining a covered work with AGPLv3, while the upstream component remains subject to GPLv3 terms.
- Upstream README lists novel search/read, TXT/EPUB import, reader appearance and page turns, system narration and audiobook playback, shelf/grouping/progress, offline downloads, short drama/manga drama/comics, history, WebDAV backup/sync, settings and other modules.
- Upstream runtime has 126 asset files with no path collisions against this project's existing assets. Flutter's directory asset declarations are non-recursive, so the upstream-used config/filter/image/Lottie/license paths are listed explicitly in the host manifest; fonts are declared through the font section.
- The app's novel pages and bookshelf already have existing business paths; the new project adds a substantially broader imported media/service stack. The existing root is a Flutter app with a local AGPL-3.0 `LICENSE`.
- Upstream directly depends on Flutter Riverpod, encrypted Hive, flutter_secure_storage, flutter_rust_bridge 2.13, system TTS, media_kit, Windows/Linux system adapters, and two in-repository third-party packages. Android behavior also depends on manually registered Kotlin plugins and an in-process Rust core.
- Upstream's current Windows and Android support are in its README; it does not claim a supported web/iOS/macOS build. Integrate supported targets first and retain explicit platform fallbacks where native backend integration is not available.
- The host already had a local `window_manager` fork depending on `screen_retriever ^0.3.0`; use that same version family and the new `DisplayManager` API. `CustomScrollView.cacheExtent` remains the compatibility path for the host's declared minimum Flutter SDK; `ScrollCacheExtent` was unavailable in the installed toolchain.
- Kazumi uses Predidit's `webview_windows` fork with a Windows headless WebView API; Novel Sound's vendored fork adds fixed-origin Fanqie cookie access but lacks the headless API. The shared plugin now uses the pinned Predidit source and implements Novel Sound's cookie method over the existing method channel and WebView2 `Network.getCookies` call with the origin fixed in native code.
- `flutter pub get` succeeds with the unified graph; root/Novel Sound entry analysis has no issues. Including the upstream WebView Dart source reports 24 informational lint notices (no Dart errors); Windows C++ and Android/Kotlin were not compiled, and no device, network-content, or APK validation was performed.
- The current Dart SDK resolves `win32 6.4.0`; `flutter_secure_storage 10.3.4` retains the basic legacy-key read/write surface and allows its Windows plugin to resolve as `4.2.2`. This replaces the initial 9.x constraint and lets the whole package graph resolve without the Windows plugin's older FFI bindings.
- The Flutter bundle command produced no output while two Flutter build processes remained active, so it was stopped; no Flutter-generated asset bundle result is available.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
- Vendor the upstream `lib/`, assets, Rust core, build scripts, and required native Android bridge code locally; keep its original package import namespace through a path dependency. | Gives the feature a real source-owned boundary and keeps its providers, cache, playback, and Rust API contracts connected. |
- Integrate via a host-app page entry rather than a remote link or a second process. | All source remains in this repository and navigates within the existing app. |
- Expose the new app from profile/content entry points without replacing existing book and novel modules. | Avoid regressions while the feature set overlaps. |
- Use a single shared local `webview_windows` package for Kazumi and Novel Sound. | The root graph cannot resolve two packages with the same name from git and path sources; one combined implementation preserves the features both clients call. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
-

## Resources
- Upstream README: https://github.com/ch6vip/novel-sound
- Upstream LICENSE: https://github.com/ch6vip/novel-sound/blob/c9ffddbbf3c976ccc5735fc7daaf4d6f4426efa8/LICENSE
- GPLv3/AGPLv3 compatibility: https://www.gnu.org/licenses/gpl-3.0.html#section13
- Local checkout for source review: `/tmp/novel-sound-upstream`
