# Task Plan: Migrate Entry-Backed Parent Projects

## Goal
Consolidate the complete source tree of every still-present direct-child project with a real Dashboard entry into this repository, including source, assets, tests, and project metadata; preserve the existing runtime integration and source history, then remove each external checkout only after verifying the migrated tree.

## Next Step
Task complete.

## Current Phase
Phase 5

## Phases

### Phase 1: Requirements & Discovery
- [x] Understand user intent
- [x] Identify constraints
- [x] Document in findings.md
- **Status:** complete

### Phase 2: Planning & Structure
- [x] Define approach
- [x] Create project structure
- **Status:** complete

### Phase 3: Implementation
- [x] Confirm the exhaustive candidate set against current siblings, catalogs, and migration records
- [x] Migrate the complete source tree into the repository and preserve the existing active integration
- [x] Remove the external source checkout only after file-level verification
- **Status:** complete

### Phase 4: Testing & Verification
- [x] Verify all source files, assets, project metadata, launch wiring, and source removal
- [x] Document validation limits
- **Status:** complete

### Phase 5: Delivery
- [x] Independently review scope and resulting changes
- [x] Amend the existing local commit for this same migration task
- [x] Deliver summary
- **Status:** complete

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Use existing migration ledger, source catalogs, licenses, and active sibling repositories to determine scope. | This repository has hundreds of siblings and an established migration history; a broad directory-name sweep would include unrelated projects. |
| Copy the complete source tree into `packages/simple_live/upstream/`, while keeping the currently integrated runtime package and launcher intact. | The user clarified that a bundle or path-only change is not a complete migration; the current upstream tree differs from host-adapted runtime files. |
| Keep the complete Git bundle as source history, and remove the external checkout only after the copied tree matches every tracked source file. | Preserves provenance and verifies the actual source migration before deletion. |

## Errors Encountered
| Error | Resolution |
|-------|------------|
| A broad `rg` across vendored packages produced excessive output. | Narrowed searches to migration documents, source catalogs, manifests, and direct-child repository metadata. |
| Temporary clone validation command was blocked because it also tried to recursively delete the temporary directory. | Re-ran bundle clone and integrity checks without temp cleanup. |
| A post-removal comparison referenced the old sibling path. | Re-ran against the preserved Trash checkout. |
| Nested upstream ignore rules hid five tracked source files and host EOL normalization changed one CRLF blob during staging. | Force-added the full upstream tree and disabled text conversion for that subtree; all 523 committed blobs now match the source tree. |
