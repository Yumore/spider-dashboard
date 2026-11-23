# Task Plan: Refresh Integrated Upstream Sources

## Goal
Port current changes from active upstream repositories already integrated in the Dashboard, preserve host-specific behavior, record adopted revisions, review, commit, and push the changes.

## Next Step
Commit the reviewed upstream changes without including the pre-existing staged build outputs, then push `main` to `origin`.

## Current Phase
Phase 5

## Phases

### Phase 1: Requirements & Discovery
- [x] Understand user intent
- [x] Identify constraints
- [x] Record repository state and existing local changes in findings.md
- **Status:** complete

### Phase 2: Planning & Structure
- [x] Identify live refs, changed paths, licenses, and local integration boundaries
- [x] Select safe, source-scoped update method
- **Status:** complete

### Phase 3: Implementation
- [x] Port applicable upstream changes while preserving host adaptations
- [x] Update provenance records with adopted refs
- **Status:** complete

### Phase 4: Testing & Verification
- [x] Independently review source and integration boundaries
- [x] Document static checks and unrun validation levels
- **Status:** complete

### Phase 5: Delivery
- [ ] Commit only this task's relevant changes
- [ ] Push the reviewed task to the requested remote branch
- [ ] Deliver updated repositories, revisions, and validation scope
- **Status:** in_progress

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Selectively port changed active source paths and host bridges; retain package-specific integration files | Full upstream app runners would replace Dashboard host wiring and local package paths |
| Keep Guomu PointyCastle 3.9.1 and Workmanager 0.10.10 constraints; add compatible source-required dependencies | Existing root dependency graph and host setup already rely on these versions |
| Route iOS remote commands through Novel Sound AudioSessionBridge with Guomu fallback | Both apps publish Now Playing through the same iOS command center |
| Exclude unrelated staged build outputs and existing root modifications from the task commit | Preserve pre-existing workspace state and keep this commit scoped |


## Errors Encountered
| Error | Resolution |
|-------|------------|
