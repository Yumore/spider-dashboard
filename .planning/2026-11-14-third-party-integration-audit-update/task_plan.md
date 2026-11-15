# Task Plan: Audit and Update Integrated Third-Party Features

## Goal
Inventory integrated third-party repositories, compare declared revisions and actual host feature wiring, then implement the user's selected update scope without replacing local adaptations.

## Next Step
None; implementation, review, validation, and local commit are complete.

## Current Phase
Phase 5

## Phases

### Phase 1: Requirements & Discovery
- [x] Understand the initial intent and record the ambiguity in “更新所有更能”.
- [x] Inventory integrated repositories, pinned revisions/licenses, host entry points, and current dependency versions.
- [x] Record the user-selected update scope: prioritize filling local feature gaps rather than upgrading every upstream snapshot.
- **Status:** complete

### Phase 2: Planning & Structure
- [x] Compare the integration record and code paths; select user-visible local comic search/category gaps.
- [x] Keep upstream revisions pinned and avoid backend-dependent changes per the user's selected scope.
- [x] Document inventory, remaining service boundaries, and source provenance.
- **Status:** complete

### Phase 3: Implementation
- [x] Make category/search controls invoke real paginated queries and expose language filtering.
- [x] Record the archived PicaComic revision and restore its MIT notice.
- **Status:** complete

### Phase 4: Testing & Verification
- [x] Format five Dart files and run focused `flutter analyze --no-pub` plus `git diff --check`.
- [x] Record that tests, APK, network, and device/UI validation were not run.
- **Status:** complete

### Phase 5: Delivery
- [x] Independently review the changes and stage only this task's files.
- [x] Create one local commit after review; do not push unless requested.
- **Status:** complete

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Fill local feature gaps instead of upgrading all upstream repos. | User explicitly selected local gap remediation; private service config is unavailable. |

## Errors Encountered
| Error | Resolution |
|-------|------------|

## Key Questions
1. Does “更新所有更能” mean filling local feature gaps or upgrading each upstream repository to latest?
2. Should repositories with host-specific adaptations remain pinned and receive local fixes only?
