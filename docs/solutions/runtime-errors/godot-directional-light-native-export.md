---
title: Godot directional lights need native sunlight and compatible material shaders
date: 2026-09-13
category: runtime-errors
tags: [godot, ftew, lighting, shadows]
---

DirectionalLight3D was rejected by the scene exporter. Allowing the node alone would not implement sunlight: the native light entity also needed an orthographic mode, and Nuclide's custom realtime lighting shaders still computed point-light vectors in that mode.

## Implementation

- `worldsrc/addons/stiletto_tools/exporter.gd` maps Godot local -Z into native pitch/yaw and emits `light_dynamic` with `_directional 1`. Position is deliberately omitted from illumination; world bounds and the authored shadow distance establish camera-following coverage. Color, energy, visibility and shadow enable are preserved.
- `src/gs-entbase/shared/light_dynamic.qc` replicates directional/shadow flags, sets ORTHOSUN and SHADOWMAP, disables the sun corona, and uses IGNOREPVS so sunlight is not dependent on visibility of its entity origin. Existing brightness and toggle inputs work; `angles` and `_shadows` inputs update live rendering.
- `base/glsl/rtlight.glsl` and `rtlight_orm.glsl` use `-l_lightdirection` under ORTHO and provide the projection varying. Their original point-light path remains intact.
- The maintained installer patches `engine/gl/gl_shadow.c` so orthographic lights respect NOSHADOWS and the renderer's shadow switches while retaining the directional shader when shadows are disabled.

Build and distribute both editor client and server gamecode together. The editor runtime is `fteqw-world.exe`. Existing processes must restart to use its changes.

## Validation

Godot export verifies rotation conversion, energy, visibility/shadow enable, and an identical binary after moving the light thousands of units. A native render fixture exercises replicated energy, shadow and angle inputs. Its captures show lighting and world shadows, shadows disappearing when disabled, rotation changing illumination, and zero-energy reset matching the initial image. Aim the test sun toward the camera so occluder shadows are visible; the opposite angle largely hides shadows behind objects in this low camera view.

The point-light regression still increases floor brightness at energies 0, 1 and 4 and returns exactly to baseline at 0.

## Limits

This is native parallel-ray sunlight with one camera-following shadow map, not Godot cascaded shadows. Coverage is at least the authored shadow distance and twice the world's bounding-box diagonal; increasing it trades shadow detail for coverage. Per-light bias, masks, sky-only mode, negative lights and physical exposure matching are not mapped. Sky images remain independent of sunlight. OpenGL is the validated backend.
