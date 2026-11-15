# Findings & Decisions

## Requirements
- User asks to inventory already integrated third-party repositories and “更新所有更能”; clarified intent is “补齐本地功能缺口”, not blanket upstream upgrades.

## Research Findings
- `documents/THIRD_PARTY_NOTICES.md` currently has 24 records. These mix complete source imports, partial integrations, dependencies vendored by another source, references/feature overlap, and projects intentionally excluded due to custom platform toolchains; do not treat all 24 as independently installed applications.
- Top-level migrated app packages currently include `packages/pure_live/app`, `packages/simple_live/*`, `packages/kazumi_webdav`, `packages/novel_sound`, and the shared `packages/webview_windows`. Other source integrations live under `lib/features/`, `native/`, or root Pub dependencies.
- The existing register explicitly records scope limits for vioclass, FiveHair/PureLive_TV, yanmo-null, overlapping PureLive forks, Reveric, TypeDreamMoon, and PDF. These are candidates for inventory findings, not automatic approval to import omitted backends, platform forks, or duplicate apps.
- Existing user-facing integration catalogs are centralized in `content_module_catalog.dart`, `reading_entry_catalog.dart`, `novel_entry_catalog.dart`, `comic_entry_catalog.dart`, `anime_entry_catalog.dart`, `movie_entry_catalog.dart`, `live_entry_catalog.dart`, and `chat_entry_catalog.dart`; `personal_page.dart` has the Novel Sound entry.
- The first case-insensitive placeholder scan matched hundreds of `toDouble()` calls because “TODO” also appears there. It did not produce a reliable incomplete-feature list; repeat with case-sensitive whole-word markers and inspect explicit `unsupported`/`disabled` paths.
- User selected: prioritize filling local feature gaps; do not blanket-upgrade all upstream repos to latest revisions.
- The host hub exposes eight business modules (reading, novel, anime, comic, movie, chat, live, crawler) plus a unified source library; specialized catalogs expose the primary integrated source entry points.
- A reliable whole-word scan found only a small set of explicit gaps/guards: PDF scan OCR remains absent; ESO's base API returns empty lists for sources that don't implement a business; a comic networking path contains `UnimplementedError`; a JM enum throws only for unknown values; unsupported-platform stubs deliberately guard file/native features. Inspect call paths before classifying any as a real user-visible omission.
- Chat examples are explicitly offline/local UI demonstrations in `chat_entry_catalog.dart`; they are not connected to Chat SDKs or private chat backends. This appears to be an intentional boundary rather than a broken integration.
- `NhentaiNetwork.getImages()` supports hosts matching `net` and `xxx`, then returns an error for other host strings; inspect the source's configured base URL options before treating this as a feature bug.
- `EsoBaseApi` is explicitly an empty base class; the main rule-source path uses `EsoApiFromRule`. Verify registrations use the real rule-backed implementation before proposing changes.
- `EsoApiManager` returns `EsoApiFromRule` for the registered rule configuration; `EsoBaseApi` is only a safe empty fallback, not the ordinary search/read path.
- The PicaComic `nhentai` adapter deliberately handles only its `nhentai.net` source and one `xxx` mirror markup. Any other host fails page-image parsing; verify whether source settings allow those hosts before broadening behavior.
- The static chat-demo catalog has many empty `onTap`/`onPressed` callbacks. This is a concrete candidate for local simulation improvements, but those demos are explicitly marketed as offline UI previews rather than real chat backends.
- The broader `documents/demands/2026-11-08-open-source-repository-integration.md` is the prior candidate audit: it distinguishes integrated functions from intentional exclusions for 28 requested content categories. These explicit boundaries must be compared with today's request, not silently treated as accidental omissions.
- Current obvious candidate classes separate into: (a) local-only UI dead-end actions, especially chat previews; (b) explicitly excluded backend/platform or upstream subfeatures; and (c) defensive unsupported-input paths. Only (a), plus verified user-visible defects in live integrated flows, is within the clarified local-gap scope by default.
- Current repository starts from commit `305282f` (Novel Sound integration); tracked worktree was clean at audit start. Root untracked `findings.md`, `progress.md`, and `task_plan.md` predate this task and must remain untouched.
- A source snapshot inside `document/migration_backups/PicaComic-155cf0c6d701.tar.gz` identifies the exact origin as `git@github.com:wgh136/PicaComic.git`, commit `155cf0c6d7018f9521f8c375b142bafd85e47a4d`, and includes the MIT license. The active third-party notice table did not previously list this port; the license has now been restored to the active module and the source added to the register.
- A confirmed local behavior bug exists in `PicacomicCategoryController`: `_load` reset all option selections to defaults, while `selectOption` only notified the UI. Category sorting/filtering therefore did not affect requests and pagination lost any selection. The controller now resets defaults only when the category context changes, refetches on selection, preserves options on pagination, and ignores stale responses.
- PicaComic search controls also only changed local dropdown state; choosing sort did not rerun current results, and subsequent searches always reset to defaults. Search option changes now rerun the current query and are retained for the next keyword; source changes restore that source's defaults.
- `enableLanguageFilter` was declared for PicaComic's E-Hentai, Hitomi, and nhentai sources but not exposed in the search page. The host now exposes a per-page language selector for sources that declare support; nhentai tag category results also expose language filtering. This intentionally does not persist the upstream global setting.
- User-facing feature inventory and explicit backend/platform boundaries are recorded in `documents/bugfixes/2026-11-14-third-party-feature-gap-audit.md`; full upstream revisions remain in `documents/THIRD_PARTY_NOTICES.md` and the existing integration demand log.
- Targeted static analysis passed on the five modified Dart files (`flutter analyze --no-pub ...`); `dart format` and `git diff --check` passed. No tests, APK build, remote source requests, or device UI checks were run.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Interpret “update all” as feature-gap remediation unless the user chooses upstream upgrades. | Upstream snapshots are pinned intentionally and may have extensive host adaptations, platform exclusions, or license obligations. |
| Keep current upstream snapshots pinned and repair the local option/request chain. | The user chose local gap filling, and these defects can be corrected without server credentials or replacing host adapters. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|

## Resources
- [Local third-party source/license register](../../documents/THIRD_PARTY_NOTICES.md)
