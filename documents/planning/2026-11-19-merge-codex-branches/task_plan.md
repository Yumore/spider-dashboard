# Task Plan: Merge Codex Branches into Main

## Goal
Merge every codex/* branch into main, remove all other branches after checking their contents, push main, and preserve unrelated working-tree changes.

## Next Step
Verify the atomic remote update, final branch inventory, and preserved working-tree changes; then report completion.

## Current Phase
Phase 5

## Phases

### Phase 1: Requirements & Discovery
- [x] Understand user intent
- [x] Identify constraints
- [x] Document branch topology and dirty-worktree findings
- **Status:** complete

### Phase 2: Planning & Structure
- [x] Define approach
- [x] Create task files in documents/planning/
- **Status:** complete

### Phase 3: Implementation
- [x] Merge `codex/dependency-upgrade` into main; its two unique commits are reachable from main
- [x] Remove local codex and legacy master branches while preserving master history under a local tag
- **Status:** complete

### Phase 4: Testing & Verification
- [ ] Verify requirements met
- [ ] Document test results
- **Status:** pending

### Phase 5: Delivery
- [x] Atomically push main and delete the remote codex branch
- [x] Leave main as the only branch and report the preserved master archive tag
- **Status:** complete

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Archive the local master tip as a tag before deleting the branch | It has 37 commits absent from main; this preserves its history without merging the unrelated legacy tree. |
| Stash only the modified pubspec.lock while switching branches | Keep user work intact and restore it on main after integration. |

## Errors Encountered
| Error | Resolution |
|-------|------------|
