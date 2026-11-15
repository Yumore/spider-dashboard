# Task Plan: Audit and Complete Integrated Third-Party Logic

## Goal
Inventory every registered integration that contributes executable code, trace its host entry and core request/state/render path, complete confirmed local gaps, and document any feature that remains backend/platform-bound.

## Next Step
Confirm the local commit and final working-tree scope; leave the remote untouched.

## Current Phase
Phase 5

## Phases

### Phase 1: Requirements & Discovery
- [x] Interpret the request using the user's prior clarification: close local implementation gaps rather than blindly replace pinned upstream revisions.
- [x] Identify constraints: skip unconfigured private services, preserve host adapters and local work, do not run tests unless requested, no APK build without request.
- [x] Confirm baseline commit `141790c` and no tracked worktree changes.
- **Status:** complete

### Phase 2: Planning & Structure
- [x] Build a code/entrypoint/functionality matrix for all registered source code, distinguish dependency/reference-only records.
- [x] Select only confirmed gaps that can be completed without private services or breaking host boundaries.
- [x] Update the existing audit document rather than creating a duplicate.
- **Status:** complete

### Phase 3: Implementation
- [x] Implement confirmed local gaps and preserve source revisions/license records.
- **Status:** complete

### Phase 4: Testing & Verification
- [x] Run focused static analysis, asset/provenance checks, and diff checks; no tests unless requested.
- [x] Document validation limits and remaining external dependencies.
- **Status:** complete

### Phase 5: Delivery
- [x] Independently review changed logic and stage only this task's files.
- [x] Create a local commit; do not push unless requested.
- **Status:** complete

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Treat the work as a complete local functional audit, not a blanket upstream update. | User previously chose local gap remediation; upstream revision replacement would be a separate, higher-risk migration because pinned copies have host-specific changes and license obligations. |

## Errors Encountered
| Error | Resolution |
|-------|------------|
| Initial asset lookup used `documents/` while the archived source is under `document/`. | Followed the path recorded in the third-party notice and extracted only the required tag dictionaries. |
| A combined planning-file patch did not match the active skeleton. | Re-read the current plan and applied the phase updates in smaller patches. |
