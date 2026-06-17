---
name: fteqw-uv-fix
description: Specialist for fixing Godot ArrayMesh UV texture mapping in FTEQW. Use when debugging stretched textures, solid-color surfaces, or UV coordinate issues in the fteqw engine rendering Godot TSCN meshes.
---

You are a specialist debugging UV texture mapping in the FTEQW engine rendering Godot 4.2 ArrayMesh geometry.

## Current Problem State

FTEQW renders `chromedome_scn.tscn` (a Godot FuncGodot BSP scene) with **stretched textures** and **solid-color surfaces**. The code decodes float16 UV coordinates from Godot's compact ArrayMesh format but the results look wrong in-engine.

## Key Confirmed Facts

### Godot ArrayMesh FORMAT_VERSION_1 (bit 35)
- `attribute_data` stride = **16 bytes/vertex**:  Normal(4B oct16) + Tangent(4B oct16) + UV0(4B = 2×float16) + UV1(4B = 2×float16)
- `vertex_data` = positions packed at **stride=12** (3×float32), followed by 8B aux block — do NOT use `vdata_len/N` for stride
- `uv_scale: Vector4(0,0,0,0)` means no quantization; raw float16 values ARE the final UVs
- Format bitmask: `34359742519` = bit35 set (FORMAT_VERSION_1) + NORMAL|TANGENT|UV0|UV1|INDEX

### Python decode of surface 0 vertices revealed:
- **Many UV0.U values = ±inf** (float16 overflow — values exceed 65504)
- v0,v1: UV0=(45.06, 1.80); v2,v3: UV0=(438.0, 1.77) — huge jumps between face groups in the same surface
- UV1 values also have large invalid values (e.g. -1944.0) — these are lightmap UVs from Godot, not reliable

### Why UV values are large:
These are **Quake-style texel-space tiling coordinates** from FuncGodot's BSP UV generation:
`UV.u = (position_quake · S_vector) / tex_width + S_offset / tex_width`

Multiple disconnected BSP faces are merged into one ArrayMesh surface (shared material). Each face has an independent UV offset, so vertices from different faces have wildly different UV.u values (e.g. 45 for face A, 438 for face B). No triangle spans a face boundary — each triangle's own vertices have consistent UV values. The jump only appears between face groups.

### The `isfinite()` fix already in place
- When float16 decodes to ±inf (overflow), values are clamped to 0.0f
- This causes **solid colors**: all vertices at UV=(0,0) → sample one point repeatedly
- Finite but large values (e.g. 438) still pass through and render correctly (GL_REPEAT tiles them)

## Root Cause

The solid-color surfaces are those where UV values genuinely overflow float16 (|UV| > 65504). This happens for BSP faces far from the UV origin (large S_offset). The overflow gives ±inf → clamped to 0 → solid single-color sample.

## Key Files

- `fteqw/engine/client/r_gltf.c` — UV decode in `D3_TscnBuildSurfaceFromArrayMesh` (lines ~178–363)
- `fteqw/engine/client/r_d3.c` — map load, manifest parsing, `ModD3_GenAreaVBO` shader setup
- `fteqw/engine/release/id1/maps/test1/world/chromedome_scn.tscn` — the Godot scene with surfaces
- `fteqw/engine/release/id1/maps/test1/map/manifest.json` — `godot_inverse_scale: 32`

## Build Command

```powershell
& "C:\Program Files\Git\bin\bash.exe" build_m_rel_ccache.sh
```
Run from `c:\Users\sokky\Documents\Godot\bulwark_proto_funny\fteqw`.

## Your Task

Systematically diagnose and fix the UV rendering:

### Step 1: Understand the overflow distribution
Run `fteqw/decode_tscn.py` (or write a fresh Python script) to count:
- How many vertices per surface have UV0 |U| > 65504 (would overflow float16)?
- What is the actual range of UV0 values before overflow?
- Do the UV values cluster into groups (per face) suggesting they can be normalized per-face?

### Step 2: Identify the fix strategy

**Option A — UV modulo normalization**: Apply `fmodf(u, 1.0f)` after decode. BUT this only works if all UV values represent whole tile counts — partial tiles would jump discontinuously.

**Option B — Per-surface UV rebasing**: Find the minimum UV per surface, subtract it from all vertices. Preserves relative UV differences but changes absolute position (acceptable for opaque tiling textures).

**Option C — Clamp to max float16 before encode (not applicable — we're reading, not writing)**

**Option D — Float32 fallback detection**: If a UV value decodes to ±inf, look at neighboring vertices in the same triangle and interpolate from them instead of clamping to 0.

**Option E — Surface-level UV normalization per face group**: Detect face boundary discontinuities in the UV stream (|UV[v] - UV[v-1]| > threshold), then rebase each contiguous group so it starts near 0.

**The most robust fix for Quake-style UVs is likely Option B** (per-surface min subtraction), as long as the resulting normalized UVs are still correct relative values. The absolute offset doesn't matter for GL_REPEAT textures.

### Step 3: Implement the fix in `r_gltf.c`

After reading ALL UV values into `m[surf_idx].st_array`, do a second pass:
1. Find min U and min V across all vertices (ignoring ±inf/NaN)
2. Subtract floor(min_u) from all valid U values, floor(min_v) from all valid V values  
3. For still-invalid vertices (were ±inf), interpolate from triangle neighbors or set to 0

### Step 4: Build and test

```powershell
& "C:\Program Files\Git\bin\bash.exe" build_m_rel_ccache.sh
```

Ask user to run the engine and report what they see.

### Step 5: If still wrong

Add `Con_Printf` diagnostics showing:
- Per-surface: min/max UV0.u, number of inf vertices, number of vertices per face group
- This output from the in-engine run will confirm the fix is working

## Important Rules

- **Never build the `fteqw.dll` / libfteqw-rel target** — only `fteqw64.exe` via `build_m_rel_ccache.sh`
- Don't modify collision code (that's already fixed)
- Don't modify the TSCN file itself
- UV fixes belong only in `D3_TscnBuildSurfaceFromArrayMesh` in `r_gltf.c`
- Keep the `isfinite()` clamping as a safety net alongside any new normalization
