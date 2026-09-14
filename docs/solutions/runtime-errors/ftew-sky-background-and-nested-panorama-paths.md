---
title: FTEW sky stays black despite a valid console selection
date: 2026-09-13
status: resolved-and-runtime-tested
component: FTEW renderer / Godot environment exporter
---

## Symptom

The FTE console reports the expected map sky and `r_skybox` override, but the world background stays black.

## Cause and fix

FTEW worlds have no BSP sky faces. The loader marks the world terrain with the internal `@ftew` sentinel; `Terr_FinishTerrain` registers a sky batch with a black fallback pass. The existing terrain renderer submits its empty sky mesh, allowing FTE's sky renderer to draw an infinite background. Submodels do not receive this sentinel. No sky collision geometry is added.

A separate resource-lookup issue affected nested panorama names. FTE's general image search strips directory components when applying fallback subpaths such as `env:gfx/env`. Thus `fteworld/day` does not resolve `env/fteworld/day.png`. Export the complete game-relative name, `env/fteworld/day`, without the image extension. Simple legacy skybox basenames retain their normal lookup behavior.

Worldspawn `skyname` records the default. A nonempty `r_skybox` overrides it locally; `r_skybox ""` restores it. Use `r_fastsky 0` to display the image. A console selection changes only the background, not the baked ambient tint or other players' settings.

## Verification

`Tools/stiletto/test_sky_runtime.py` captures default, day, dusk and reset in one owned client session. The final rebuilt executable passed with sky pixels `(5,7,19)`, `(29,74,148)`, `(46,7,33)`, `(5,7,19)`. Visual inspection confirms geometry remains in front of the sky. Environment conversion and deterministic exporter tests pass; the rebuilt dedicated server still passes floor/hull/ramp collision and MapC loading checks.

Authoring steps and fidelity limits are documented in `worldsrc/README.md` under Environment and live sky changes.
