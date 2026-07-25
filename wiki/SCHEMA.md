# Wiki Schema

## Domain

Nuclide / Bulwark / Stiletto game development: FTEQW engine work, WebCore UI,
QuakeC progs (`base/`), lobby/session systems, HUD/menu ports, and related
reference trees (Godot prototype, Source SDK).

This wiki is the durable, cross-tool knowledge layer for Hermes (and Cursor).
Prefer compiling facts here over re-discovering them from the raw tree each session.

## Conventions

- File names: lowercase, hyphens, no spaces (e.g., `webcore-ui.md`)
- Every wiki page starts with YAML frontmatter (see below)
- Use `[[wikilinks]]` to link between pages (minimum 2 outbound links per page)
- When updating a page, always bump the `updated` date
- Every new page must be added to `index.md` under the correct section
- Every action must be appended to `log.md`
- **Code paths are absolute or repo-relative from nuclide root** — never invent sibling `fteqw` paths; canonical engine tree is documented under [[fteqw-workspace]]
- **Provenance markers:** On pages that synthesize 3+ sources, append `^[raw/...]`
  at the end of paragraphs whose claims come from a specific source.

## Frontmatter

```yaml
---
title: Page Title
created: YYYY-MM-DD
updated: YYYY-MM-DD
type: entity | concept | comparison | query | summary
tags: [from taxonomy below]
sources: [raw/articles/source-name.md]
confidence: high | medium | low
contested: true
contradictions: [other-page-slug]
---
```

### raw/ Frontmatter

```yaml
---
source_url: local://AGENTS.md
ingested: YYYY-MM-DD
sha256: <hex digest of body below frontmatter>
---
```

## Tag Taxonomy

- Stack: `engine`, `progs`, `webcore`, `cef`, `slint`, `rmlui`, `hud`, `menu`
- Networking: `lobby`, `session`, `lan`, `multiplayer`
- Content: `entitydef`, `mapc`, `rulec`, `radiant`, `maps`
- Gameplay: `movement`, `melee`, `monster`, `player`
- Process: `build`, `windows`, `preferences`, `deferred`, `reference-tree`
- Meta: `architecture`, `comparison`, `decision`

Rule: every tag on a page must appear in this taxonomy. Add new tags here first.

## Page Thresholds

- **Create a page** when a system/path appears in 2+ sources OR is central to active work
- **Add to existing page** when new facts land on something already covered
- **DON'T create a page** for one-off file greps or transient bug chatter
- **Split a page** when it exceeds ~200 lines
- **Archive a page** when fully superseded — move to `_archive/`, remove from index

## Entity Pages

Notable products, trees, tools, plugins (e.g. WebCore, FTEQW workspace, Nuclide).

## Concept Pages

Systems and conventions (lobby session, HUD letterboxing, entityDef inheritance, rebuild flow).

## Comparison Pages

Stack choices (WebCore vs CEF vs Slint; HUDMins vs full viewport).

## Orientation (every Hermes session)

1. Read `SCHEMA.md`
2. Read `index.md`
3. Scan the last ~30 lines of `log.md`
4. Search before creating duplicates
