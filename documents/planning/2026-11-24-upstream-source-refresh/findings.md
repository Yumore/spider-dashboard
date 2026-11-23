# Findings & Decisions

## Initial State
- User requests transplanting the latest changes from already-integrated upstream sources and pushing them to the remote.
- Current branch is `main` at `f0a2fbe` (`fix: make release APK build succeed`); `origin/main` matched at inspection.
- The worktree already contains unrelated staged generated CMake/Rust/Flutter files, unrelated unstaged anime/comic/home edits, and untracked `.workbuddy/`, one bugfix note, and `lib/features/shared/ui/content_load_state.dart`. Preserve all of these and exclude them from the upstream task commit.
- The completed 2026-11-18 upstream refresh records active app revisions and migration boundaries; this task is a new refresh and keeps its own plan under `documents/planning/2026-11-24-upstream-source-refresh/`.
- The provenance table lists active integrations in Guomu, PureLive, SimpleLive, Kazumi-WebDAV, Novel Sound, PureLive NAS, Hongguo, Zhenguo, VioClass, Cuipi TV, and PicaComic, plus reference-only/overlapping sources. Re-check current refs and active-path deltas before selecting code.

## Current Upstream Evidence
- GitHub search indexed the PureLive v3.2.11 release notes, including Douyu stream renewal, Android ABI playback libraries, and platform-support changes. The active copy is the separate `wzgrx/PureLive` repository; inspect source refs rather than importing its release build outputs. [PureLive releases](https://github.com/wzgrx/pure_live/releases)
- GitHub search reports `ch6vip/novel-sound` updated on 2026-11-22, after the recorded 2026-11-18 baseline. Confirm its current `master` commit and active source-path delta before porting. [Novel Sound on GitHub](https://github.com/ch6vip/novel-sound)
- Direct GitHub commit-page opens were blocked by the web reader; use the public repository refs and source comparisons for exact revisions.
- Live refs checked on 2026-11-24: Guomu `main` `fb060c44b32e0f13c223db1455eec6c41050b02b` (recorded `3b00a52d...`); Novel Sound `master` `c5f252e392ee31bf15a1f4d95b773467e1f1dc66` (recorded `18161a89...`); PureLive NAS `custom` `5296995c806c1149a0c0551295e490550b45b42c` (recorded `acde546b...`); VioClass `main` `0b08303d906fbf5418f578c738498acab95cb3cd` (recorded `bff8d047...`). Other active source refs checked on 2026-11-24 matched their 2026-11-18 recorded revisions. Path-scoped comparisons are complete: Guomu and Novel Sound active app changes were selectively ported, PureLive NAS was checked against its current source tree because the recorded base is no longer reachable, and VioClass changes were outside the integrated path subset.
- GitHub REST comparisons report Guomu 33 commits/97 paths since the adopted ref, with active app changes across 57 non-test Android/iOS/assets/Flutter paths; Novel Sound 161 commits/249 paths, including 145 non-test active app/source paths. Both need selective porting because the Dashboard has host and package adaptations. [Guomu compare](https://github.com/DearLicy/guomu/compare/3b00a52d712b82e674cbad405aa537370bf01bab...fb060c44b32e0f13c223db1455eec6c41050b02b), [Novel Sound compare](https://github.com/ch6vip/novel-sound/compare/18161a89d5436c3004c453d2428cfd110c527b4e...c5f252e392ee31bf15a1f4d95b773467e1f1dc66)
- VioClass has 4 commits/41 files since the prior check; its code diff adds Twitch live DVR discovery/recovery, while the recorded Dashboard integration is limited to public Twitch VOD/Clip. This remains out of scope unless a change intersects those active paths.
- GitHub REST compare for PureLive NAS returned 404 despite a reachable current `custom` ref; determine whether the recorded base commit is unavailable/force-pushed, then compare only `nas/server/src` with a direct source fetch.
- GitHub's commit endpoint confirms the recorded PureLive NAS base `acde546b...` is no longer available in the repository (`422: No commit found`); the current `custom` commit resolves normally. This is likely a rewritten/disconnected history, so compare only the locally integrated NAS source paths against current `custom` and document the limitation.
- Latest upstream package metadata: Guomu `1.4.31+37` and Novel Sound remains `1.0.205+210`. Novel Sound's current dependency constraints differ from the Dashboard's validated Flutter 3.50 resolution, so preserve the Dashboard-compatible `screen_retriever` and host-owned Android setup rather than replacing package manifests wholesale.
- PureLive NAS latest `custom` source tree is directly available under `nas/server/src`; compare it against the local `packages/purelive_nas/nas/server/src` copy path-by-path because the previous base SHA is no longer resolvable.
- Downloaded path-scoped upstream diffs to temporary files. Guomu's selected `lib/`/`assets/`/manifest patch applied cleanly to 46 files; five adaptation conflicts were resolved manually. Novel Sound's selected library/Rust/assets/manifest patch applied cleanly to 137 files; `audio_playback_guard.dart`, `desktop_platform.dart`, log model imports and package dependencies were merged manually.
- Kept tests, release workflows, upstream app runners, and generated outputs excluded. All source conflicts have now been resolved while preserving Dashboard entry points, package paths, embedded mode, app-group identifiers, audio ownership, and dependency constraints.
- Guomu's latest Dart source now invokes an Android `com.guomu.huangguo/update` MethodChannel for signed APK installation and an iOS `com.guomu.huangguo/liveactivity` channel for App Group validation and cover staging. Port the handlers into Dashboard's existing `DashboardActivity` and `AppDelegate`; do not copy upstream runner classes.
- Novel Sound's update adds desktop/iOS media behavior, `media_kit_libs_ios_video`, `wakelock_plus`, and Android HTTP media diagnostics. Merge those into the local package manifest and host `CryptoNative.kt` while retaining the Dashboard `screen_retriever` pin and package path.
- Guomu upstream bumps to `1.4.31+37`, adds `wakelock_plus`, raises PointyCastle to 4.0, and downgrades Workmanager to 0.9.2. Preserve the Dashboard's Flutter-compatible Workmanager 0.10.10 and PointyCastle 3.9.1 pins unless the merged source requires otherwise; update the package version and add only compatible direct dependencies.
- For the nine patch-conflict files, perform three-way merges using their exact previously adopted upstream revision as the base, the Dashboard copy as local, and the current upstream file as remote. This retains custom host behavior while resolving upstream logic explicitly.
- Three-way merge retained the Novel Sound player protections and Dashboard desktop setup. Guomu app/source-router, bottom navigation, theme fonts, Live Activity, and manifests are merged with Dashboard embedded behavior preserved.

## Local Adaptation Boundaries
- Reuse the 2026-11-18 findings and `documents/THIRD_PARTY_NOTICES.md`; do not replace host wiring, local forks, or archived snapshots wholesale.
- Only update provenance to commits actually included in this task.

## Requirements
-

## Research Findings
-

## Technical Decisions
| Decision | Rationale |
|----------|-----------|

## Issues Encountered
| Issue | Resolution |
|-------|------------|

## Resources
-

## Current Task Results
- Guomu `main` at `fb060c44b32e0f13c223db1455eec6c41050b02b` was ported through package source and compatible dependencies. Dashboard Android now handles `installApk` with cache containment, package/signature checks, install-source permission recovery, and FileProvider; iOS handles Live Activity availability and securely staged covers using the Dashboard App Group.
- Novel Sound `master` at `c5f252e392ee31bf15a1f4d95b773467e1f1dc66` was ported through Dart/Rust/native source. iOS Runner registers independent secure-key, Fanqie login, file-share, TTS, audio-session and event bridges, with a single remote-command owner shared by Novel Sound and Guomu. Android media diagnostics retain the Dashboard JNI package and avoid logging signed URLs.
- PureLive NAS `custom` at `5296995c806c1149a0c0551295e490550b45b42c`: existing `nas/` paths are byte-identical to the live upstream tree; added upstream cloud deployment notes, fnOS packaging source and Windows portable packaging source. No packaging script was executed.
- Other checked refs have no applicable changed paths; VioClass changes remain outside the integrated VOD/Clip subset.
- `dart format` completed for the manually merged Dart files. `flutter pub get --offline` succeeded and updated the Guomu path-package version in `pubspec.lock`; no tests or app builds were run.
