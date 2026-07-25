---
title: Wiki Index
created: 2026-07-17
updated: 2026-07-24
type: summary
tags: [architecture]
---

# Nuclide / Bulwark Wiki Index

## Entities

- [[nuclide]] — Runtime repo / game gamedir host (`base/`, `fteqw64.exe`)
- [[fteqw-workspace]] — Canonical FTE engine tree for WebCore/lobby work
- [[webcore]] — In-process HTML/CSS UI plugin + host DLL
- [[godot-prototype]] — Stiletto protophase2 reference tree

## Concepts

- [[rebuild-flow]] — Progs + engine build/copy procedure
- [[webcore-ui]] — Title menu, lobby menu, in-game HUD paths
- [[lobby-session]] — Mapless pre-game lobby / serverless session direction
- [[hud-letterboxing]] — HUDMins/HUDSize vs full viewport
- [[entitydef]] — Runtime `.def` inheritance and keys
- [[player-iqm-animation]] — IQM heroes: export, `act_*`, CSQC declclass, oneshots
- [[user-preferences]] — Standing product/tech preferences from AGENTS.md

## Comparisons

- [[webcore-vs-cef-slint]] — Why WebCore is preferred over CEF / Slint for UI

## Deferred

- Spectator target cycling (local two-client) — `docs/deferred/spectator-target-cycling.md`
- Respawn health hardcodes 100 HP — `ncPlayer::MakePlayer()` in `src/shared/game/Player.qc`

## Raw sources

- `raw/articles/agents-md.md` — ingested AGENTS.md (2026-07-17)
