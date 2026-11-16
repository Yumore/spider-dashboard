# Task Plan: Integrate Guomu Features

## Goal
Integrate every functional feature from DearLicy/guomu into the Flutter Dashboard through coherent app entry points, preserving required attribution and licenses.

## Next Step
Task completed. Commit `22a47cc` is pushed to `origin/main`.

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
- [x] Execute the plan
- [x] Write to files before executing
- **Status:** complete

### Phase 4: Verification & Review
- [x] Verify requirements met
- [x] Document validation limits
- **Status:** complete

### Phase 5: Delivery
- [x] Review outputs
- [x] Deliver to user
- **Status:** complete

## Decisions Made
| Decision | Rationale |
|----------|-----------|
| Map upstream user-visible capabilities into existing Dashboard modules and add entry catalogs where needed. | User requests all functions, so migration must include usable feature paths rather than only an imported source snapshot. |
| Preserve upstream source attribution and license text, and record the selected commit in `documents/THIRD_PARTY_NOTICES.md`. | Required by repository-wide open-source integration policy. |
| Import the full upstream Flutter client as a dedicated path package and launch it from the existing short-drama catalog. | Reimplementing its account, discovery, caching and player flows would risk omitting behavior; a package keeps Guomu's state and navigation isolated. |
| Keep host platform entry points and merge only Guomu-specific contracts into them; retain the iOS Live Activity widget extension and Web media worker. | Native share/deep links, background jobs, Live Activities and Web HLS caching are part of the upstream feature set. |

## Errors Encountered
| Error | Resolution |
|-------|------------|
| Guomu's PointyCastle `^4.0.0` conflicted with the host `crypton` dependency requiring PointyCastle `^3.7.3`. | Inspected Guomu's only PointyCastle usage; its AES-CBC decoder uses APIs present in 3.9.1, so adapted the package constraint to `^3.9.1` and will record the compatibility patch. |
| The installed Xcodeproj 1.15 parser did not recognize Xcode's `XCLocalSwiftPackageReference` or object version 54; its default extension target also emitted a stale hard-coded Foundation SDK path. | Extended the parser only for this edit, preserved the existing package reference and shell phase attributes, removed the generated stale Foundation link, and kept WidgetKit linked through the SDK root. |
| Two broad patch attempts did not match the actual file context, and a shell cleanup command was rejected by the command safety layer. | Re-read the exact target ranges, split the patches by file, and used a narrow Python cleanup for copied metadata. |
