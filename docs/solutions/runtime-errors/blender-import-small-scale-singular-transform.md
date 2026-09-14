---
title: Small Blender import scales falsely rejected as singular transforms
date: 2026-09-13
category: runtime-errors
tags: [godot, blender, ftew, transforms]
---

## Symptom and cause

Exporting the nested `maps/neden-1.blend` scene rejected 175 of its 176 meshes with “Mesh has a singular transform.” Their basis axes were independent, but each axis had scale about 0.001724. The raw determinant was about 5.12e-9; normalizing the axes gave determinant 1.

The exporter compared the raw determinant against 1e-6, confusing small volume with a collapsed transform. The native FTEW reader had a similar absolute 1e-8 threshold and would reject the same scene even after an exporter-only fix.

## Fix

The exporter and native reader now test the determinant of individually normalized basis columns against 1e-6. They still reject non-finite, zero-axis, dependent-axis and nearly dependent-axis transforms. The reader uses double precision for normalization to avoid overflow/underflow when squaring float components. The exporter applies the same validation to explicit box colliders and identifies node/parent scale as a possible cause in error messages.

The serialized placement is unchanged: no source transforms are reset or applied. Rebuild both `fteqw-world.exe` and `fteqw-world-server.exe` after installing the updated maintained loader header.

## Verification

- `test_import_transforms.gd`: nested rotated small/nonuniform/mirrored scales, preserved placement, explicit box colliders, rejected zero/dependent axes.
- `Tools/stiletto/test_format.c`: small/nonuniform/mirrored/sheared bases accepted; collapsed and nearly dependent bases rejected, along with existing malformed-file checks.
- Actual imported scene: all 176 instances and 43,874 triangles export successfully.

Each source scene should have its own FTEWorld3D Map Name. A newly created root defaults to `editor_lab`; change it to a unique identifier (for example `neden_1`) to avoid replacing the lab's exported map. This is separate from the transform bug.
