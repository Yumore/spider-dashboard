# Task Plan: Integrate Novel Sound Features

## Goal
Integrate the novel-sound Flutter/Rust application into this project as a locally migrated feature with its real services, native runtime wiring, user entry point, attribution, and license records.

## Next Step
None. Integration is locally committed; platform packaging and device acceptance remain separate follow-up validation.

## Current Phase
Complete

## Phases

### Phase 1: Requirements & Discovery
- [x] Identify supported features and exact source revision.
- [x] Confirm the upstream license and this repository's license.
- [x] Inspect the current novel/read/audio architecture and uncommitted workspace state.
- **Status:** complete

### Phase 2: Planning & Structure
- [x] Define migration boundaries for Flutter, assets, Rust, and native code.
- [x] Record dependencies, platform scope, and license obligations.
- **Status:** complete

### Phase 3: Implementation
- [x] Migrate the Flutter/Rust package, assets, Android bridges and Windows runtime packaging.
- [x] Add the host entry point and unify WebView dependencies.
- **Status:** complete

### Phase 4: Testing & Verification
- [x] Resolve the Flutter package graph with `flutter pub get`.
- [x] Analyze migrated Novel Sound Dart code and host entry points.
- [x] Record unavailable platform/device runtime validation.
- **Status:** complete

### Phase 5: Delivery
- [x] Review the migrated source boundaries, platform wiring, notices and local artifacts.
- [x] Create a local commit containing only this task.
- **Status:** complete

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Upstream source is pinned to `c9ffddbbf3c976ccc5735fc7daaf4d6f4426efa8`. | The requested GitHub repository is mutable; preserve an auditable exact source version. |
| Keep the upstream implementation under an isolated local feature/package boundary. | Its full app contains extensive Riverpod, Rust bridge, native playback, and persistence contracts that should remain connected instead of being flattened into unrelated readers. |
| Preserve GPL-3.0 attribution and ship upstream notices alongside the source. | Root project is AGPL-3.0; GPLv3 has an explicit combination permission for AGPLv3 under section 13. |
| Expose the complete app only on Android and Windows, the platforms supported by the source project. | Avoid presenting a partially wired backend as working on web, iOS, macOS or Linux. |
| Build the Windows Rust DLL beside the app executable and reuse the local Rust core on Android. | The upstream media service loads the native library in-process on both supported platforms. |
| Override both source packages to one local WebView fork with the union of the Kazumi headless API and Novel Sound fixed-origin cookie API. | A single shared plugin resolves the incompatible path and git sources without losing either business flow. |

## Errors Encountered
| Error | Resolution |
|-------|------------|
| `flutter pub get` found incompatible `screen_retriever` constraints and conflicting path/git WebView sources. | Aligned on `screen_retriever ^0.3.0`; added one shared `packages/webview_windows` path override that retains headless and cookie flows. |
| Secure storage 9.x required an older platform interface and selected a Windows implementation incompatible with the host `win32 6.x` graph. | Upgraded Novel Sound's API-compatible migration reader to `flutter_secure_storage 10.3.4` and pinned its Windows implementation to `4.2.2`. |
| Initial Dart analysis found a missing direct Riverpod dependency and an unsupported newer scroll-cache API. | Declared the direct host dependency, used the host-compatible cache extent API, and migrated display lookup to the current `DisplayManager` API. |
