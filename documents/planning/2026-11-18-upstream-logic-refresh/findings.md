# Findings & Decisions

## Requirements
- Refresh logic from upstream repositories already integrated into the dashboard.
- Preserve host integration/adaptation rather than blindly replacing files.
- Update provenance records for source revisions actually adopted.
- A prior explicit user instruction in this conversation requests pushing the completed work; push after review and local commit.

## Research Findings
- Starting branch: `codex/dependency-upgrade`; starting commit `44a1b82` (`chore(deps): upgrade and simplify dependency graph`); worktree was clean at start.
- `documents/THIRD_PARTY_NOTICES.md` identifies active integrated applications: Guomu, PureLive, SimpleLive, Kazumi-WebDAV, Novel Sound, and PureLive NAS. It also lists references, vendored libraries, and overlapping alternatives that are not all active app roots.
- Active app source trees are ordinary copies rather than Git submodules. Documented source revisions: Guomu `b2d61210d22a07fb021a9bfb510b2781cda665cd`; PureLive `9bd38aaf10e5bd7c8db24c27af82f433507c1917`; SimpleLive `da2a0fdc9d9ca376bd3365e80a4589699a7b93b4`; Kazumi-WebDAV `d4c4ac4c50b0aad3479d97e68a9c21dbc1670941`; Novel Sound `c9ffddbbf3c976ccc5735fc7daaf4d6f4426efa8`; PureLive NAS `49de6d04bb90d1df1b1015ac342c7104a768062f`.
- `packages/simple_live/upstream/` is an archived pristine source tree with a fixed snapshot and migration bundle; it is not the active app integration.
- Kazumi-WebDAV is a featureful fork with WebDAV, subtitle/audio track, and other fork-specific logic; preserve these features when syncing its chosen upstream.
- Individual libraries/forks also exist under `packages/*/third_party`, `packages/webview_windows`, and other paths. Determine active linkage/provenance before changing them.
- Live refs checked on 2026-11-18: Guomu `main` = `3b00a52d712b82e674cbad405aa537370bf01bab`; PureLive `master` = `9b406e8ecc46642233176ece200ec9aef5921cf0`; SimpleLive default branch `tv-1.7.6-fix` = `a18aef6d0f5698e56b52709482ccba79ad32a9e5`; active copy base `da2a0fdc...` is its ancestor (3 commits ahead, 0 behind). Do not use the unrelated, divergent `master` branch; Kazumi-WebDAV `main` is still `d4c4ac4c50b0aad3479d97e68a9c21dbc1670941`; Novel Sound `master` = `18161a89d5436c3004c453d2428cfd110c527b4e`; PureLive NAS `custom` = `acde546b1bd52ee8a3824268f3bc8c4f6ee584cb`.
- Repository integration notes also identify migrated code from `czgyz/hongguo` and `youniube/zhenguo-app`; their current refs and changes must be considered because their logic lives outside standalone app package roots.
- Guomu changes since the adopted snapshot are 3 commits, primarily player/background audio, UI gesture/back behavior, native half-sheet/settings redesign, Android/iOS metadata and playback, and tests. The upstream diff touches 43 files with about 1.5k additions and 1.1k deletions; files needing adaptation-aware merge include iOS Runner/AppDelegate and Xcode project, app metadata, root shell, short video player, adaptive sheets, settings, and manifests.
- Source history comparisons show the refresh is substantial: PureLive has hundreds of changes spanning live platform logic, app UI, packages, tests, docs, and bundled native media; SimpleLive active default TV branch adds 3 commits affecting WebSocket recovery and TV release wiring; Novel Sound `master` has a large batch of reader, sync, startup, and short-drama fixes. This cannot safely be treated as a dependency-only update.
- `GIT_NO_LAZY_FETCH=1` prevents the partial clones from retrieving omitted Git objects; ranges for SimpleLive and Novel Sound can list commits but fail to resolve old trees. The full Guomu codeload archive is unsuitable for routine diffing (tar metadata reports about 2.8 GB expanded); prefer path-scoped Git diffs/sparse checkout rather than full archive downloads.
- The current source scope includes standalone apps under `packages/` and directly migrated source modules described in the notices. References explicitly marked as not copied/reimplemented are not candidates for blind code replacement. Current GitHub compare checks found no newer default-branch commits for Kazumi-WebDAV, Hongguo, Zhenguo, Cuipi TV, Wenku8, PicaComic, or Predidit/webview_windows. VioClass is 4 commits ahead, all relevant diffs in its live discovery/watch/DVR flow; those are outside the Dashboard VOD/Clip subset and were not imported.
- PureLive NAS current `custom` differs from the recorded snapshot in 2,777 paths, but 2,757 are checked-in `node_modules`, 19 are built `dist`, and only one path is `nas/server/src`. Update only the source logic and leave dependency/build artifacts alone.
- SimpleLive old and current commits both exist in the partial clone, but the diff needs missing promisor tree objects; lazy fetch failed with an OpenSSL unexpected EOF. The web tool could not open the public GitHub compare API URL, so use direct GitHub REST via `curl` or a fresh commit-scoped fetch.
- Novel Sound has 97 source-path changes since the recorded snapshot (39 services, 27 pages, 12 widgets, 10 Rust source files, and the remaining models/native files); refresh the active package tree while excluding test directories and build output.
- PureLive advanced from integrated `5.6.0+5133` to upstream `5.6.5+5144`; the documented source diff covers 196 paths: 136 under the app, 20 `live_core`, 18 `live_danmaku`, 10 `live_vod`, and the remaining live packages. The current upstream app path is `apps/pure_live`, while the embedded copy keeps its local `app/` path; map the source update without changing the host package path or replacing the local `third_party/window_manager` fork. The relevant upstream application/package pubspec changes only the app version; dependencies have no source-range delta.
- PureLive latest adds an Android-only isolated Xiaohongshu guest-browser MethodChannel (`pure_live/xiaohongshu_guest`) using AndroidX WebView multi-profile APIs. The Flutter feature is already in the source patch; root native host is `DashboardActivity` and currently has no channel registration, so port the guarded upstream handler there and add its WebKit dependency. The package-local app has no Android project after integration, so upstream child `MainActivity` patches are not active host code. Root Android uses Groovy `android/app/build.gradle`, minSdk 26, and had no AndroidX WebKit dependency. The guest handler was adapted into `com.yumore.dashboard.live.platform`, registered/cleaned with `DashboardActivity`, and added WebKit 1.14.0 to the host app dependencies; its run state is in a separate class file to honor the supplied one-class-per-file rule.
- A 12k-line text-only patch over active app/package source, with test directories excluded per developer instruction, applied after manually merging `packages/live_player/lib/src/mpv_engine.dart` diagnostics with the upstream Android hardware-decoder policy. The app package version is now `5.6.5+5144`; dependency manifests had no source-range changes.
- Guomu upstream patch applies cleanly to all changed files except `lib/hg/app.dart`, `lib/hg/pages/root_shell.dart`, `lib/hg/services/hg_live_activity_service.dart`, and `pubspec.lock`. The first three overlap local embedded-app adaptations and required manual merge; the child lockfile stays local. Retained `lib/hg/pages/review_prompt.dart` because Dashboard still invokes it.
- Guomu upstream adds a native Now Playing method channel used from its Flutter short-video page. In the embedded Dashboard, host `ios/Runner/AppDelegate.swift` is the active native implementation; package-local `packages/guomu/ios/Runner` is not built, so the host now has a matching channel and lock-screen remote commands while page-scoped audio-session restoration remains in the existing channel. Root `live_activities` lock resolves to 2.5.1; required activity APIs also exist in Guomu's existing 2.4.2 child lock. Root Info.plist and widget extension now include the upstream task/background/Live Activity declarations.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Use the current source branch matching the active integration (`main`, `master`, `custom`, or TV default) | Side branches diverge; active SimpleLive uses `tv-1.7.6-fix`, while its archived xiaoyaocz tree stays unchanged. |
| Consider migrated source fragments in addition to full `packages/` apps | The provenance docs describe migrated Hongguo/Zhenguo code outside standalone app package roots. |
| Compare source trees before applying changes | Retain Dashboard-specific wiring and fork-only features while importing upstream logic changes. |

## Issues Encountered
| Issue | Resolution |
|-------|-----------|
| Assumed the Dashboard host class was named `MainActivity.kt` under `com/yumore/dashboard`; the actual active class is `DashboardActivity.kt` | Located it with `rg --files android`; root host has a separate plugin registry. |
| First plan-note edit embedded a literal newline in a single-quoted Python string and failed before writing | Rewrote the note with triple-quoted strings; subsequent plan validation passed. |
| SimpleLive partial-clone tree fetch ended with TLS unexpected EOF; web open also rejects api.github.com compare URL | Queried GitHub REST compare for the default `tv-1.7.6-fix` branch and used its bounded 3-commit patch. |
| zsh loop variable `path` replaced the special `PATH` array and made later commands unavailable in that subprocess | Rename the loop variable before repeating the read-only inspection. |
| planning-with-files initializer defaults to `.planning/`, conflicting with supplied AGENTS.md | Initialized outside the repo and placed the resulting files under `documents/planning/<task-id>/`. |

## Resources
- `documents/THIRD_PARTY_NOTICES.md`
- `documents/demands/2026-11-08-open-source-repository-integration.md`
- `documents/demands/2026-11-14-novel-sound-integration.md`
- `packages/kazumi_webdav/NOTICE.upstream.md`
- `packages/simple_live/upstream/README.md`


## 2026-11-18 Refresh Decisions
- Applied Guomu `3b00a52d712b82e674cbad405aa537370bf01bab`, PureLive `9b406e8ecc46642233176ece200ec9aef5921cf0`, SimpleLive default `tv-1.7.6-fix` `a18aef6d0f5698e56b52709482ccba79ad32a9e5`, Novel Sound `18161a89d5436c3004c453d2428cfd110c527b4e`, and PureLive NAS `acde546b1bd52ee8a3824268fbc8c4f6ee584cb`.
- SimpleLive update: four active source files only; omitted the version JSON in the archived upstream tree.
- Novel Sound update: applied `lib/`, `rust/src/`, Linux TTS source, and the vendored shader patch; omitted upstream tests and build output. Adapted Android cloud sync plugins, package path, Dashboard registration, manifest, dependency configuration, and license assets in the active host. Updated the active JNI HTTP range bridge while retaining the offline-file allowlist.
- Guomu upstream test changes were excluded from the delivered diff. No tests were added or run.
- PureLive NAS update excludes checked-in `node_modules` and generated `dist`.
- License resolution: `javax.el 3.0.1-b12` POM declares CDDL/GPLv2 with Classpath Exception; `desugar_jdk_libs 2.1.5` uses GPLv2 with Classpath Exception. Added both full texts to runtime assets and Novel Sound's license registry.
- Structural checks: `git diff --check` passed; Android Manifest XML parsed; all three new license assets exist and are explicitly declared; cloud sync Java files use the adapted Dashboard package. No tests, analyzer, build, or device checks were run.
