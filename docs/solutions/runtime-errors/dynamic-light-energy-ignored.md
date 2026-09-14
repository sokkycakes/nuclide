---
title: Godot light Energy exports but does not change FTE lighting
date: 2026-09-13
status: resolved-and-runtime-tested
component: Nuclide light_dynamic / Stiletto editor gamecode
---

## Cause and fix

The Godot exporter already writes OmniLight3D `light_energy` to native `brightness`. `light_dynamic` reads and networks this as `m_flIntensity`, but the client previously sent only the normalized RGB color to the renderer. Intensity-only updates were also ignored.

`light_dynamic::LightChanged` now refreshes `LFIELD_COLOUR` when color or intensity changes, using `m_vecLight * max(0, m_flIntensity)`. The stored network color stays normalized, so repeated changes do not compound intensity. Initial creation and video-resource reload already call this method with all flags. The constructor defaults intensity to 1 so omitted brightness retains the previous appearance; explicit zero produces no light. Native `brightness` inputs follow the same update path.

The nearby radius update checked `DLIGHTFL_CHANGED_RADIUS` despite using `m_flDistance`. It now checks `DLIGHTFL_CHANGED_DISTANCE`, matching the native `distance` input and preserving independent control over light reach.

## Build and use

Run `Tools/stiletto/build_gamecode.ps1`. The editor uses the paired `base/maps/ftew_framework.dat` and `base/maps/ftew_client.dat`; its launchers set `sv_progs` and `sv_csqc_progname` respectively. This leaves normal `base/progs.dat` and `base/csprogs.dat` untouched. A source change alone does not update a running playtest: close it and use Export + Play again.

In Godot, select the OmniLight3D and edit Light > Energy. Values are linear multipliers: 0 off, 1 normal, 4 four times emitted intensity. The display response also depends on material, distance and renderer settings.

## Verification

Run Godot's `addons/stiletto_tools/test_light_export.gd` script to check Energy serialization at 0, 0.25, 1 and 4 and create the separate test world. Compile `Tools/stiletto/light_probe.qc` to `base/maps/ftew_light_probe.dat` with `compile_map.ps1`, then run `python Tools/stiletto/test_light_runtime.py` (Pillow required).

The MapC test drives actual server brightness inputs and network updates in one client session. Coronas and light debug sprites are disabled. Measured average floor brightness was 67.00 at Energy 0, 70.01 at 1, 78.25 at 4, then exactly 67.00 when reset to 0. The world source and its authored light value are not modified by the test.
