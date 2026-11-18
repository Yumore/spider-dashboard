# Task Plan: Dashboard Dependency Upgrade

Use this file as the durable roadmap for the task. Create it before complex work and keep it current as phases change.

## Goal

State the intended end result in one clear sentence.

Upgrade the Dashboard dependency graph where compatible and simplify avoidable or duplicate constraints without breaking local package integrations.

## Next Step

All implementation and review steps are complete; the changes are recorded in one local commit.

## Current Phase

Complete

## Phases

Break the task into three to seven verifiable phases. Use only `pending`, `in_progress`, or `complete` for each status and update the value when work advances.

### Phase 1: Requirements & Discovery

- [x] Understand user intent
- [x] Identify constraints and requirements
- [x] Document findings in findings.md
- **Status:** complete

### Phase 2: Planning & Structure

- [x] Define technical approach
- [x] Create project structure if needed
- [x] Document decisions with rationale
- **Status:** complete

### Phase 3: Implementation

- [x] Update selected root constraints and resolve compatible package versions
- [x] Regenerate web SQLite worker assets for the upgraded package
- **Status:** complete

### Phase 4: Verification & Review

- [x] Check dependency graph, lockfile and generated assets
- [x] Review all changes for regressions and unrelated edits
- [x] Record validation limits
- **Status:** complete

### Phase 5: Delivery

- [x] Review all output files
- [x] Ensure deliverables are complete
- [x] Create one local commit
- **Status:** complete

## Key Questions

Record important questions and replace them with answers as they are resolved.

1. Which direct dependencies are behind the current resolvable version, and which have newer major versions?
   - Updated compatible upgrades, the PDF suite and selected major bumps after inspecting host usage; retained other major boundaries for a separate migration.
2. Which overrides or direct dependencies are redundant, and which are required by active local packages?
   - Removed the unused root `cupertino_icons` edge and redundant root umbrella media-kit libraries edge. Retained local `window_manager`, `webview_windows`, Windows storage, dbus/win32, and Guomu workmanager overrides.

## Decisions Made

Record significant choices and the reason for each one.

| Decision | Rationale |
|----------|-----------|
| Keep the lockfile as the resolved source of truth while auditing all root direct and override constraints. | Version constraints alone do not reveal whether local packages require a fork or pin. |
| Align root Dart and Flutter lower bounds with the resolved graph. | The updated lockfile aggregates Dart >=3.14.0 and Flutter >=3.50.0; `pdfium_flutter` raises the effective Flutter floor beyond the path packages. |
| Keep `pdf_document` and `pdf_graphics` on the exact same 16.1.0 suite release. | Root uses only document open/info, text extraction and merging; reviewed suite migration notes and found no touched API migration. |
| Update selected root direct constraints while retaining unrelated major-version boundaries. | Avoid broad migrations for foreground-task, protobuf, xml, and the local window-manager fork in a dependency-maintenance change. |
| Retain the discontinued `flutter_easyrefresh` package for now. | It remains imported across root pages and both embedded Simple Live UI packages; replacing it requires a separate UI refresh migration. |

## Errors Encountered

Record each distinct error, the attempt number, and the resolution. Change the approach before retrying a failed action.

| Error | Attempt | Resolution |
|-------|---------|------------|
| Initial Python dependency scan had a syntax error and PyYAML was unavailable. | 1 | Switched to Ruby standard-library YAML/JSON and `rg`; no files were changed by the failed scan. |
| Initial manifest patch context did not match the current `cupertino_icons` line. | 1 | Re-read the current manifest and applied a narrower patch with matching context. |
| `html ^0.15.7` conflicted with an exact transitive constraint. | 1 | Kept `html 0.15.6`; avoided an override and kept the git-pinned `papyrus_reader` source unchanged. |
| Final read-only validation command had an unmatched quote in a shell regex. | 1 | Re-ran validation with corrected single-quoted shell pattern. |

## Notes

- Update phase status as work progresses: `pending` to `in_progress` to `complete`.
- Re-read the goal and next step before major decisions.
- Log errors promptly so failed approaches are not repeated.
