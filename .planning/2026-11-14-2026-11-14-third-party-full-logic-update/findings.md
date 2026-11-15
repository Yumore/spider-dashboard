# Findings & Decisions

## Requirements
- User asks for a full inventory of already integrated third-party repositories and to update their logic/functionality.
- Prior clarification in the same conversation selected local functionality gap remediation; keep upstream snapshots pinned unless a concrete logic gap requires a source change.
- Do not wire unconfigured private services; no tests unless asked; no APK build unless asked; preserve unrelated untracked planning files.

## Research Findings
- Current baseline is commit `141790c fix(comic): wire PicaComic filters`; tracked worktree was clean at start. The only untracked items are planning files/root notes; don't stage them.
- `documents/THIRD_PARTY_NOTICES.md` has 25 rows mixing copied app/source code, runtime dependencies, vendored libraries, overlapping repositories, and references. Each row must be classified by whether executable source is actually present.
- Main content hub exposes reading, novel, anime, comic, movie, chat, live, and crawler; the source library and per-domain catalogs provide additional actual user entry points.
- Previous integration report already documents selected boundaries and revisions; update the same current audit document, rather than duplicate it.
- The immediately prior turn fixed PicaComic category/search option loading and language filters, so this broader audit must avoid repeating those changes and review the remaining integration paths.
- Existing code-based feature entry points are present for all eight top-level domains; specific catalogs include additional implementations such as Twitch VOD, PureLive, SimpleLive, TVBox/CMS, local media, Kazumi and comic sources.
- The prior integration report differentiates actual source code from overlap/reference-only candidates, and states explicit backend/platform exclusions. Keep those categories distinct; only executable code with a host entry qualifies for local logic updates.
- A whole-host scan found dozens of empty callbacks in chat/short-video demo screens, while the catalogs label those modules as offline UI previews. They are local UI gaps the new wording may include, but remote chat, camera capture and video upload need actual platform/backend contracts and must not be simulated as real services.
- Static scan also found explicit unimplemented guards in JM enum fallback and nhentai unsupported-host parsing, plus platform stubs for file access, JS and short-drama FFI. These may be deliberate unsupported-path guards; inspect their user-facing paths before changing them.
- The active PicaComic `nhentai_tags.dart` contains only about 59 ordinary tag IDs (plus language IDs), while the archived exact upstream commit has the complete source map; the current file documents this as a known gap. This is a self-contained, backend-free feature omission suitable for completion.
- Restored the exact 720-entry upstream `nhentaiTags` map from the retained PicaComic archive; language IDs/path names remain in host constants. The root manifest lists `assets/`, but that directory entry does not include nested directories; added an explicit `assets/picacomic/` entry for the translation dictionaries.
- The same PicaComic snapshot has two large Chinese tag dictionaries (`tags.json` and `tags_tw.json`, about 1.34 MB each, 12 namespaces) plus the upstream translation algorithm. The current host has no tag translation service; comic detail chips currently show raw tag labels and `enableTagsTranslation` is metadata only. This is a genuine local feature gap, but asset inclusion and a small locale-aware adapter are needed.
- The host `ComicInfoData` preserves `sourceKey` but not the `BaseComic.enableTagsTranslation` flag. The detail page can gate translation by source key (`ehentai`, `hitomi`, `nhentai`) without changing shared model contracts. The root Flutter manifest includes `assets/`, so localized tag JSON can be placed below it.
- The PicaComic translation JSON schema has 12 top-level dictionaries including namespace labels and the full 9 category vocabularies. The host now loads both simplified and traditional variants and applies namespace-aware translation based on the active locale.
- PicaComic e-hentai categories currently hardcode 10 tags per namespace. The upstream source uses the full translation database's namespace keys (roughly 35,000 entries across group/artist/etc.) and randomly samples 20 on each category refresh. Full local tag dictionaries can restore both complete category selection and the translated detail UI without a network service.
- A more serious integration break was confirmed: `ComicSourceRegistry._sources` is empty by default, and repository search finds no production call to `ComicSourceRegistry.init()` or `register()`; only tests initialize it. `PicacomicHomePageState` creates its default explore controller directly from that empty registry, so the catalog opens an empty source list. Added startup initialization after preferences/database setup and per-source failure reporting.
- Confirmed the ignored local archive exists under `document/migration_backups/PicaComic-155cf0c6d701.tar.gz` (singular `document/`). Extracted the exact MIT snapshot's `tags.json` and `tags_tw.json` into registered Flutter assets.
- Added source-declared E-Hentai/nhentai search completion, capped at 12 suggestions and retaining prior query text when completing a multiword tag; translated detail labels and values for Chinese locales.
- Other explicit port boundaries include the PicaComic custom JavaScript source runtime, ESO `@js` rules, EasyMyGo unsupported source business methods, Crawler charset handling, and platform-specific local media/reader/camera behavior. These need architecture/dependency review before implementation; no blanket stub removal.

## Technical Decisions
| Decision | Rationale |
|----------|-----------|
| Separate executable source integrations from reference-only/overlap records. | A reference or duplicate repository has no local logic to update; it should be audited as a scope boundary, not reported as a code integration. |
| Audit by real host path: source registration → adapter/service → user catalog/page → data and playback/read action. | Imported code alone does not establish a working feature. |

## Issues Encountered
| Issue | Resolution |
|-------|------------|
| Prior plan files and root notes are untracked. | Preserve; create this task's named plan in `.planning/` and explicitly stage only relevant source/docs. |
| One batched shell read exceeded output budget; a catalog loop also emitted a zsh `====` parse error. | Repeat the needed searches in narrower path-specific calls; no repository state was changed by the failed read. |
| Initial asset lookup searched plural `documents/`. | Located the archive under singular `document/` via the source register and extracted only the two needed JSON dictionaries. |

## Resources
- `documents/THIRD_PARTY_NOTICES.md`
- `documents/demands/2026-11-08-open-source-repository-integration.md`
- `documents/bugfixes/2026-11-14-third-party-feature-gap-audit.md`
