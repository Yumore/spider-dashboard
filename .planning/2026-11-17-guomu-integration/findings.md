# Findings & Decisions

## Requirements
- Integrate all functional features in `https://github.com/DearLicy/guomu` into the current Flutter Dashboard.
- Keep the source-backed features reachable through Dashboard entry points, while retaining attribution, license notices, and provenance.

## Research Findings
- Repository: `/Users/nathaniel/workspace/Flutter/dashboard`; initial branch state was `main`, synchronized with `origin/main`, at commit `4a059e4f2fa892ae210408d91693f6a8ad5cbd08`.
- Existing workspace planning notes are untracked and belong to other tasks; preserve them and use this task's isolated `.planning/2026-11-17-guomu-integration/` directory.
- The supplied GitHub repository describes Guomu as a standalone Flutter client for Huangguo short drama; its upstream README lists content discovery, immersive playback, account/interactions, resume history, source management/failover, offline caching, theme preferences, and Android/iOS/Web support. This feature list is a discovery checklist, not yet code-verified.
- GitHub identifies the upstream license as GPL-3.0 and the visible tree as a complete Flutter app with `lib/`, `assets/`, platform folders, tests, build scripts, and `THIRD_PARTY_NOTICES.md`.
- The Dashboard already has a real short-drama feature under `lib/features/short_drama/hongguo/` and a short-drama catalog entry in `lib/features/movie/movie_entry_catalog.dart`; integration should retain that app and add Guomu as an independently reachable client unless code comparison shows a narrower adapter is needed.
- The repository page shows only one upstream commit; resolve the exact commit and inspect dependency/runtime contracts before editing.
- Downloaded the official `main` archive at commit `b2d61210d22a07fb021a9bfb510b2781cda665cd` (2026-11-16); archive SHA-256 is `2b2d09e71103fc476641ed5257e5975945a1f473c739e11fa5170a0a9c0f9ec6`. Source includes 73 Dart files, six declared asset files plus fonts, a full standalone Android/iOS/Web app, and a package lock.
- Upstream `GuomuApp` owns Provider state, source discovery, authentication, downloads, theme, and a five-tab shell (home, theater, posts, rankings, profile); page flows add categories, search, detail, comments, profiles, messages, creators, updates and downloads.
- Runtime capabilities include `video_player`, Dio-based source/API handling, local history/cache, workmanager, notifications, Android share/deep-link MethodChannels, iOS ActivityKit/live-activity extension, and a Web service worker/HLS cache. These native/web host requirements must be merged or given a deliberate runtime fallback; a plain Dart dependency alone would leave capabilities disconnected.
- The Dashboard already has a separate `ShortDramaModulePage` for Hongguo and is on Flutter SDK constraint `>=3.32.0`; Guomu requires Dart `^3.9.0` and its README targets Flutter 3.35.1. Root dependencies already include some compatible packages but not the complete Guomu set.
- Integration design should expose Guomu as a separate entry in the existing short-drama catalog while keeping its `guomu.*` preferences isolated from Hongguo. The upstream source tree and exact license/provenance need to be retained under a dedicated package directory.
- The host Android activity is `DashboardActivity` and already has a centralized plugin/channel registration point; the host AppDelegate is minimal, so Guomu's share and deep-link channels plus Workmanager background registration can be merged without replacing host launchers.
- The host Android manifest already grants internet, wake lock, notifications, foreground service and data-sync permissions; Guomu's narrower permission needs can be reconciled there. Its Android channels are only share and `guomu://` deep links.
- The host iOS app currently has no App Group entitlement or widget extension target. Guomu Live Activities require both an ActivityKit extension and shared App Group, so these need explicit host Xcode integration or a clearly documented capability fallback.
- Guomu's upstream `video_player` backend supports Android, iOS and Web; the Dashboard's broader `media_kit` capability includes Windows/Linux, where Guomu's player plugin is unavailable. The new catalog requirement should use a distinct platform capability and expose Guomu only on its upstream client platforms.
- Guomu Web runtime expects `window.guomuMediaCache`, a local `hls.min.js`, and `hg-media-sw.js`; the host Web entry currently has only the standard Flutter loader. Web HLS caching and playback need host-level asset/script integration, not only a path package.
- Guomu declares only one `rootBundle` asset path in Dart (`assets/data/source_manifest.json`); brand and font assets are declared through the upstream app pubspec. Additional package-font and asset-path behavior still needs checking when embedding.
- Upstream startup automatically checks Guomu's own GitHub Releases. This remains source-scoped and must not be redirected to Dashboard's version/update flow.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Keep Guomu's source-specific app state and user flows isolated behind a Dashboard entry. | This preserves its source switching, account state, playback state and data model instead of conflating them with the existing Hongguo client. |
| Vendor the complete pinned Flutter source under `packages/guomu` as a first-party path dependency. | This brings the actual user-facing feature implementation and upstream platform artifacts into the repository instead of only changing references or adapting the existing Hongguo source. |
| Preserve all upstream license and third-party attribution files, and add a dated integration record describing the pinned commit and local host adaptations. | Required open-source provenance and attribution. |
| Integrate Android share/deep links and background task registration into `DashboardActivity`; integrate iOS app delegate callbacks and the Guomu Live Activity extension in the host Xcode project; merge Guomu Web assets/scripts into the existing Flutter web shell. | Each contract is owned by the host runtime, so copying standalone entry points would leave the integrated app nonfunctional or replace Dashboard bootstrapping. |
| Pin the package's PointyCastle constraint to `^3.9.1` for the shared host dependency graph. | The only Guomu usage is the AES-CBC decoder, and PointyCastle 3.9.1 exposes the used CBC/AES API while satisfying the host's `crypton` dependency. |
| Advertise the Guomu entry only on Android, iOS and Web, and scope iOS AVAudioSession changes to the Guomu route lifetime. | Upstream `video_player` lacks Windows/Linux backends and the audio session is process-global; preserve working platform boundaries and the existing host session when the route closes. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Standard shallow Git clone ended with an OpenSSL EOF during ref listing; HTTP/1.1 clone also stalled. | Stopped both clone attempts and used the official GitHub codeload archive plus GitHub API to retrieve and pin the exact source commit. |
| Initial host-native file lookup assumed `MainActivity.kt` and Gradle Kotlin DSL paths that this repository does not use. | Located `DashboardActivity.kt`, the Groovy app Gradle file, and the actual host AppDelegate/manifest. |
| The first `flutter pub get` found Guomu PointyCastle 4 incompatible with the host's PointyCastle 3 constraint through `crypton`. | Confirmed Guomu only uses AES-CBC APIs present in 3.9.1, lowered the package constraint, and will resolve the graph again. |
| The installed Xcodeproj gem could not load the host Xcode 15 project as-is. | Added narrow Ruby parser compatibility for local Swift package references and object version 54; the widget target is registered without dropping the existing Flutter plugin package reference. |
| A package-wide `videoPlayback` capability would also expose Guomu on Windows/Linux where its `video_player` backend is not registered. | Added a separate platform capability matching the upstream Android/iOS/Web targets. |

## Resources
-
