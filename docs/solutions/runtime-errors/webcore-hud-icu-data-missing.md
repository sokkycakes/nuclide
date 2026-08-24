---
title: "WebCore HUD map-load AV when ICU data is missing"
date: 2026-08-18
type: fix
severity: high
module: "WebCore HUD / playtest packaging"
category: runtime-errors
affected_runtime: FTEQW-WebCore
tags:
  - webcore
  - hud
  - icu
  - playtest
  - packaging
problem_type: runtime_error
status: resolved
related:
  - Tools/qml-runtime-launcher/scripts/publish-staging.ps1
  - Tools/qml-runtime-launcher/docs/updater.md
---

# WebCore HUD map-load AV when ICU data is missing

## Summary

A playtest drop with matching engine, plugin, and HUD HTML still crashed on **every** map a few seconds after world load. The map was visible behind the console. Faulting module was `ftewebcore.dll` (`0xc0000005`). `webcore_hud 0` kept the game running. Copying `resources/icudt67l.dat` next to the exe fixed HUD-on map load.

## Causal chain

1. CSQC HUD init after world load creates a second WebCore view (`gecko_create("webcore_hud", …)`), which loads `data/web/hud/` including a large `@font-face` stylesheet.
2. `ftewebcore.dll` calls `u_setDataDirectory(<exe>\resources)` and needs `icudt67l.dat` there for OpenType decode.
3. The updater tracked `fteqw64.exe`, plugin DLLs, and `base/data/web/`, but not ICU data. Title-menu pixel fonts can survive; HUD `@font-face` AVs.

This is not a BSP, texture, or `vid_renderer` bug.

## Fix

Ship **`resources/icudt67l.dat`** next to the exe (same bytes as `nuclide/Resources/icudt67l.dat` or the WebCore CMake copy at `bin/resources/icudt67l.dat`).

`Tools/qml-runtime-launcher/scripts/publish-staging.ps1` includes that path and **throws** if WebCore is present and the file is missing.

## Verification

- `webcore_hud 0` then `map duel_alley` — game stays up (isolates HUD init).
- HUD on, with `resources/icudt67l.dat` present, `map duel_alley` — game stays up.
- Event Log fault module was `ftewebcore.DLL`, not the engine exe.

## Regression

Do not publish a WebCore playtest without `game/resources/icudt67l.dat`. The staging script must fail closed rather than skip the file.
