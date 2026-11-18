# Task Plan: Refresh Integrated Upstream Logic

## Goal
Refresh active upstream-derived code integrated into the dashboard against current upstream repositories, preserving host-specific integrations and recording adopted revisions.

## Next Step
Stage the reviewed task changes, create one local commit, and push the requested branch.

## Current Phase
Phase 5

## Phases

### Phase 1: Requirements & Discovery
- [x] Understand user intent
- [x] Identify constraints
- [x] Document initial repository inventory in findings.md
- **Status:** complete

### Phase 2: Planning & Structure
- [x] Resolve active upstream repositories, source revisions, licenses, and local integration boundaries
- [x] Define safe update method for each repository
- **Status:** complete

### Phase 3: Implementation
- [x] Update active integrated upstream logic while retaining host adaptations
- [x] Update provenance records and task documentation
- **Status:** complete

### Phase 4: Testing & Verification
- [x] Independently review source diffs and integration boundaries
- [x] Run appropriate non-build structural checks and document validation scope
- **Status:** complete

### Phase 5: Delivery
- [x] Commit the completed task locally after review
- [x] Push the reviewed task to the requested remote branch
- [x] Summarize updated repositories, retained custom logic, and validation
- **Status:** complete

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Keep task planning under `documents/planning/2026-11-18-upstream-logic-refresh/` | Supplied global AGENTS.md requires planning files to remain only under `documents/planning/<task-id>/`. |
| Update active application integrations, not archived pristine bundles | An archived source snapshot is provenance material and does not drive the active app integration. |

## Errors Encountered
| Error | Resolution |
|-------|------------|
| Initializer defaults to `.planning/`; shell safety rejected a cleanup command | Initialized outside the repository and copied the three generated files into the required planning directory. |
| zsh loop variable named `path` overwrote its special `PATH` array | Use a non-special name such as `source_path`; no project files were changed by the failed inspection. |
