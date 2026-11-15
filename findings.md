# Findings & Decisions

## Requirements
- Adjust this Flutter app's mobile UI to follow `/Users/nathaniel/workspace/AndroidStudio/SpiderMan/documents/designs`.
- Retain the existing multiple color themes and their selection behavior.
- Workspace started clean on `main` tracking `origin/main`.
- No project-level `AGENTS.md` was found in this app or the referenced Android project.

## Research Findings
- The reference folder contains 66+ actual-device screenshots plus `README.md` and `coverage.md`; core tabs include anime, comic, live, drama, bookshelf, and profile.
- `README.md` identifies screenshots 01–06 as the main tabs; screenshots 60–66 document newer profile/preferences states.
- The Flutter project is a large multi-platform app with feature modules under `lib/features/`; `pubspec.yaml` declares Flutter and multiple source/player integrations.
- The project has existing documents under `documents/demands/` and `documents/bugfixes/`.
- Visual inspection of reference screenshots 01–03: the selected theme's cyan fills the status/header region and active navigation affordance; content sits on a white canvas. Anime/comic use a dense two-column image-led catalog with readable titles beneath covers, while live uses a two-way section selector above two-column stream cards. All three retain a six-item bottom navigation (anime, comic, live, drama, bookshelf, profile).
- Avoid carrying screenshot-specific status-bar content, image data, or fixed dimensions into Flutter; use safe areas, existing dynamic content, and theme tokens.
- Visual inspection of references 04–06: drama keeps the same image-card rhythm as anime/comic; bookshelf switches to compact horizontal book rows with cover, title/author, latest/read progress and small unread/source indicators; profile is a long, flat action list with consistent icon/label/chevron alignment and thin accent dividers. The six-tab bottom bar persists across all main screens.
- References 60–62 show the current profile variant and the preferences hub: profile remains a flat list with accent dividers, while preferences groups related settings into labeled sections with one rounded container per group, leading icon tiles, title/subtitle pairs, and trailing chevrons. Secondary settings screens use a back affordance and the same theme-colored top bar. This supports using the existing theme's accent rather than hard-coding cyan.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Inspect reference screenshots and current mobile entry point before editing. | Need to distinguish visual alignment from a broad navigation rewrite. |
| Add design rationale to `documents/demands/` if UI scope is substantial. | Repository instructions require task documentation for broad changes and UI demands. |
| Keep six reference destinations; expose the rest of the existing module catalog from the profile screen. | Matches the screenshots without orphaning news, novel, movie, chat, and crawler modules. |
| Keep update prompting and current module implementations when moving the home shell. | The UI change should not remove existing behavior or replace live feature pages with mocks. |
| Derive app-bar and system-bar foreground brightness from the selected theme colors. | The yellow and other light accent palettes need readable status icons and titles. |

## Implementation & Validation
- The mobile home shell now maps directly to anime, comic, live, short drama, bookshelf, and profile pages; screens retain their original data and workflows.
- The profile page exposes the old content hub, novel channel, and news channel so changing the six main tabs does not strand previous entries.
- All seven accent colors and the three appearance modes remain selectable. App bars, system bars, selected navigation state, and profile dividers follow the selected color.
- Focused `flutter analyze --no-pub` on changed files reported no issues. `dart format` and `git diff --check` passed. A full-project analyze reported 1,508 diagnostics across the larger legacy/dependency tree, so it is not used as evidence for the changed-file result.
- No tests, APK build, or device UI validation were run.

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Python Pillow is unavailable for local contact-sheet composition. | Use native macOS image tools or inspect images individually instead of installing dependencies. |

## Resources
-
- Reference screenshots: `/Users/nathaniel/workspace/AndroidStudio/SpiderMan/documents/designs/README.md`, `01-anime.png`–`06-mine.png`, and `60-current-entry.png`–`66-comic-settings.png`.
