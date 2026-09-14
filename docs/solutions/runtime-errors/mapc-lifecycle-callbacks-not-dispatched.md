---
title: MapC loads but frame and player callbacks never run
date: 2026-09-13
status: resolved-in-source
component: Nuclide server / MapC
---

## Symptom

`CodeCallback_Precache` runs from a map's compiled `.dat`, but `CodeCallback_FrameStart`, `CodeCallback_PlayerConnect`, `CodeCallback_PlayerDisconnect` and `CodeCallback_PlayerSpawn` never run. Entity I/O can still work, so a successful map load alone does not detect the problem.

## Cause and fix

`src/server/MapDelegate.qc` already bound these functions to `g_grMap`. `src/server/entry.qc` dispatched the corresponding game-rule and addon events but omitted the map delegate. It now dispatches those four events when a MapC program and map delegate exist. The frame callback runs after the rule callback, past the first second of map startup; the spawn callback runs after level-transition handling.

This fix does not wire the other declared MapC damage/death callbacks. Do not assume every declared callback is active without checking its call site.

## Verification

The Stiletto editor fixture `worldsrc/maps/editor_lab.qc` logs both clients connecting and uses its frame callback to move a test player into an exported trigger. On a separate native server, two clients loaded `editor_lab.ftew`, and the trigger changed `light_dynamic` state from `1` to `0`. All processes exited normally. `Tools/stiletto/test_multiplayer.py` reproduces this check.

For isolation, the updated server gamecode is built as `base/maps/ftew_framework.dat` by `Tools/stiletto/build_gamecode.ps1` and selected with `sv_progs`. The existing `base/progs.dat` was not overwritten. Other launches require rebuilding their selected server gamecode to receive the source fix.
