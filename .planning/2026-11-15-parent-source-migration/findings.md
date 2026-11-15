# Findings & Decisions

## Requirements
- User requests migrating every project in `/Users/nathaniel/workspace/Flutter` that already has a real entry in Dashboard, then deleting each source repository.
- User clarified that archiving the source and relying on an existing code integration does not satisfy the requested migration; the full current source tree must be physically integrated into the Dashboard repository, not only represented by a Git bundle or dependency path.
- Do not delete source code or local edits before verifying the migrated copy and preserving a recoverable source archive.
- The root `documents/` policy requires updating an existing same-topic document, independently reviewing code changes, and making one local commit after verification; do not push.

## Research Findings
- Host is `/Users/nathaniel/workspace/Flutter/dashboard`, a Flutter app with distinct module entry catalogs under `lib/features/*/*entry_catalog.dart`.
- Parent contains hundreds of sibling Git repositories; only projects with a demonstrable host entry are in scope.
- Existing `documents/bugfixes/2026-10-31-parent-source-migration-recheck.md` says 51 sources were already migrated, archived, and removed; 59 classified repositories remained, with no pending source at that time.
- Historical `document/loggers/content-migration-inventory.json` lists 110 selected Flutter sources; `content-migration-retirements.json` records verified archives for 51 retired sources. Remaining old candidates were skipped for private-service dependency, no business logic, native blockers, plugins, or dependency blockers.
- Dashboard's `documents/THIRD_PARTY_NOTICES.md` lists later 2026-11-08 integrations. Of these named source checkout paths, `../dart_simple_live` currently exists; `packages/simple_live/` contains the integrated application. Other listed upstream checkout names checked so far are absent.
- The 2026-11-08 integration record explicitly said `dart_simple_live` had been skipped by an earlier user scope, but it is now integrated and launched from Dashboard. Current user request supersedes that earlier scope; source checkout status and exact differences still need inspection before deletion.
- A current direct-child comparison confirms exactly 308 sibling directories, matching the historical inventory; no previously retired source directory has reappeared and no new directories are unrecorded.
- The sole still-present checkout whose current host module catalog has a direct source-specific launcher is `dart_simple_live`; the catalog's `simple-live` item builds `SimpleLiveEmbeddedPage`, and the host dependency points to `packages/simple_live/simple_live_app`.
- The complete 523 tracked paths (522 regular files) from `dart_simple_live` HEAD `ba828e6783b176ea5709fcd09f0eb01dfaceeb51` have been copied byte-for-byte under `packages/simple_live/upstream/`; this includes all four projects, assets, tests, licenses, and configuration.
- The committed index tree has an exact 523/523 blob match against the bundle's `master` commit. Root `.gitattributes` disables text conversion under `/packages/simple_live/upstream/**` to preserve the upstream CRLF file byte-for-byte; nested source ignore rules were bypassed when staging already tracked files.
- The existing adapted SimpleLive runtime package remains adjacent and is not overwritten; the host entry still opens `SimpleLiveEmbeddedPage`. All files and the complete Git history are now inside the Dashboard repository (tree plus Git bundle), and the parent/Trash checkout has been removed.
- Other present candidates inspected (`flutter_wechat_camera_picker`, `flutterApp`, `flutter-app`, `alltv_flutter`, and the Flutter Folio checkouts) have no corresponding project-specific source entry in the host catalogs; historical records identify their plugin/private-service/overlap boundaries. They are out of scope.
- At task start, `main` was ahead of `origin/main` by 4 pre-existing commits. The local migration commit was amended as `a4dda567f83c` and remains unpushed; the current branch is ahead by five commits including this task. Untracked planning files remain outside the migration commit.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Candidate identification must be based on actual entry catalog/import or a documented source launch path, not merely a feature category or name similarity. | Prevents deleting unrelated sibling projects. |
| Copy the complete current source tree under `packages/simple_live/upstream/`; leave the active integration package at its existing path. | This imports the complete project while retaining the entry's host-specific runtime behavior and avoiding destructive overlays on divergent files. |
| Remove the external checkout only after an exact file-level comparison against the migrated source tree and a verified complete Git bundle. | The user explicitly requires actual source migration before source deletion. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Initial recursive search included all vendored package source and was too broad. | Limited future searches to host catalogs, migration ledgers, and direct-child repo metadata. |

## Resources
- `documents/bugfixes/2026-10-31-parent-source-migration-recheck.md`
- `documents/demands/2026-11-08-open-source-repository-integration.md`
- `documents/THIRD_PARTY_NOTICES.md`
- `document/loggers/content-migration-inventory.json`
- `document/loggers/content-migration-triage.json`
- `document/loggers/content-migration-retirements.json`
