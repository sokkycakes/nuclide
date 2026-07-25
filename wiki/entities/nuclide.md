---
title: Nuclide
created: 2026-07-17
updated: 2026-07-17
type: entity
tags: [architecture, engine, progs]
sources: [raw/articles/agents-md.md]
confidence: high
---

# Nuclide

Runtime / game repo root. Active gamedir is `base/`. Engine binary runs from this root as `fteqw64.exe` (not under `ThirdParty/`).

## Key paths

- Game logic: `base/src/` → `base/progs.dat`, `base/csprogs.dat`, `base/menu.dat`
- Web UI assets: `base/data/web/` (title-menu, lobby-menu, hud, webcore-test, h3-main-menu)
- RmlUI HUD: `base/ui/rml/`
- This wiki: `wiki/` (LLM wiki) + `wiki/okf/` (OKF memory bundle)

## Related

- [[fteqw-workspace]] — engine C source for WebCore/lobby
- [[rebuild-flow]] — how binaries and progs get rebuilt
- [[webcore-ui]] — menu/HUD HTML surfaces
