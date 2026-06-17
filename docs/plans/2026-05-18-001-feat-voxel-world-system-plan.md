---
title: Voxel World System Implementation for Nuclide
type: feat
status: active
date: 2026-05-18
---

# Voxel World System Implementation for Nuclide

## Summary

Implement a voxel world system in Nuclide (FTEQW-based Quake engine) that layers editable voxel terrain on top of the existing BSP map system. Inspired by CSO's voxel architecture but adapted for FTEQW's engine patterns and Nuclide's QuakeC entity system.

---

## Problem Frame

Nuclide currently lacks a voxel/terrain editing system. CSO demonstrates that layering voxels on top of BSP maps (via `voxelspawn` entities) creates compelling gameplay: editable environments, monster AI navigation, and dynamic destruction. Nuclide needs this capability. It allows for map creation in engine without external tools using an intuitive voxel based system, as well as scripting.

---

## Requirements

- R1. Voxel worlds load from file (`.vxl` or new format) on top of existing BSP maps
- R2. Voxel entities (doors, spawners, triggers) integrate with Nuclide's entity system
- R3. Collision detection prioritizes voxels over BSP geometry
- R4. Rendering uses FTEQW's existing mesh pipeline
- R5. Editor integration: Radiant spawns voxel entities via classname

---

## Scope Boundaries

- **In scope:** Engine-level voxel world (C), QuakeC entity classes, collision, file I/O, rendering hooks
- **Out of scope:** Custom .vxl format tooling (use simplified format), networked voxel editing (local-only first), performance optimization passes
- **Deferred:** Multiplayer voxel sync, procedural voxel generation, destructible voxels

---

## Context & Research

### Relevant Code and Patterns

**FTEQW Engine (fteqw/engine/):**
- `gl/gl_heightmap.c` - Existing heightmap terrain (~5200 lines) - **primary reference**
- `gl/gl_terrain.h` - `heightmap_t`, `hmsection_t`, `plugterrainfuncs_t` structures
- `server/world.c` - `World_Move()`, `World_BoxTrace()` collision functions
- `common/com_mesh.h` - Model type definitions (`mod_brush`, `mod_heightmap`)
- `common/world.h` - `world_t`, `trace_t`, model function pointer interface

**Nuclide QuakeC (nuclide/base/src/):**
- `src/shared/system/Entity.qc` - Base entity class with lifecycle, I/O, networking
- `src/shared/system/Trigger.qc` - Trigger base with touch/use callbacks
- `src/shared/game/Actor.qc` - NPC base with pathfinding and schedules
- `src/shared/system/entityDef.qc` - Declarative entity definition system

**CSO Research (nuclide/research/CSOvoxel/):**
- `hw_dll/voxel_code.md` - CVoxelWorld, chunk grid (24×12×12), collision priority
- `mp_dll/voxel_code.md` - VoxelEntity hierarchy, monster AI integration
- Key insight: voxel collision takes precedence over BSP

### Institutional Learnings

- FTEQW uses `model->funcs.NativeTrace` and `model->funcs.PointContents` for collision
- Heightmap terrain already has collision implemented via `HeightmapTraceThrough()`
- Nuclide entities inherit `ncEntity` base; use `SpawnKey()` for spawnarg parsing

### External References

- CSO voxel architecture: chunk grid + material layers + Direct3D rendering
- FTEQW heightmap: section-based streaming, shader rendering, lightmap support

---

## Key Technical Decisions

- **Collision priority**: Voxel models register with higher priority than BSP; engine checks voxel trace first
- **Voxel format**: Create simplified binary format (not .vxl) - text header + binary chunk grid
- **Model type**: Register as `mod_heightmap` variant or new `mod_voxel` - follow heightmap patterns
- **Entity storage**: Voxel entities use Nuclide's edict system, not separate voxel-specific storage
- **Rendering**: Generate mesh from chunk grid at load time; use `R_AddMeshToScene()` for rendering

---

## Open Questions

### Resolved During Planning

- **Q: Use existing heightmap system or create new voxel type?**
  - A: Create new `mod_voxel` type following heightmap patterns. Heightmap is height-based (2D grid); voxels are volumetric (3D grid). Overloading heightmap would add confusion.

- **Q: How does collision priority work in FTEQW?**
  - A: Model function pointers (`funcs.NativeTrace`) are checked in sequence by `World_Move()`. Register voxel model after BSP so its trace runs first.

### Deferred to Implementation

- Exact chunk size (CSO uses 24×12×12 = 3456 chunks, but we may use different dimensions)
- Material/texture system (CSO uses Direct3D fixed-function; FTEQW uses GLSL shaders)
- Performance implications of voxel traces vs BSP hull traces

---

## High-Level Technical Design

> *This illustrates the intended approach and is directional guidance for review, not implementation specification.*

```
BSP Map Load (SV_SpawnServer)
    │
    ▼
Voxel World Load (after BSP)
    │
    ├─► Parse voxel file (header + chunk grid)
    ├─► Generate mesh from chunks (R_MeshBuffer* for each chunk)
    └─► Register collision (funcs.NativeTrace = VoxelTrace)
           │
           ▼
Entity Spawn (SV_SpawnServerPhase2)
    │
    ▼
VoxelEntity QC classes ──► ncEntity base ──► Nuclide entity system
```

**Collision Flow:**
```
World_Move()
  ├─► BSP model trace (if no hit in voxel)
  └─► Voxel model trace (checked first)
        ├─► Chunk lookup (by position)
        └─► Voxel raycast (per-chunk data)
```

**Voxel File Format (simplified):**
```
[VoxelHeader - text]
version=1
chunk_dim=16 16 16
chunk_count=100

[ChunkData - binary]
<3456 chunks × 16×16×16 voxels × 1 byte material each>
```

---

## Implementation Units

- U1. **[Voxel Engine Core]**
- U2. **[Voxel Collision Interface]**
- U3. **[Voxel File I/O]**
- U4. **[Voxel Rendering]**
- U5. **[QuakeC VoxelEntity Baseclass]**
- U6. **[QuakeC Voxel Triggers and Doors]**
- U7. **[Radiant Integration]**

---

- U1. **Voxel Engine Core**

**Goal:** Create `mod_voxel` model type with chunk grid data structure.

**Requirements:** R1

**Dependencies:** None

**Files:**
- Create: `fteqw/engine/common/voxel.h` - Voxel structures and constants
- Create: `fteqw/engine/common/voxel.c` - Core voxel world management
- Modify: `fteqw/engine/common/com_mesh.h` - Add `mod_voxel` to modeltype_t enum
- Modify: `fteqw/engine/common/quakedef.h` - Any shared types

**Approach:**
- Define `voxel_chunk_t` as 16×16×16 voxel grid with material IDs
- Define `voxel_world_t` as 3D array of chunk pointers
- Chunk dimensions follow FTEQW heightmap section patterns (16×16)
- Material ID stored as single byte per voxel (supports 256 materials)

**Technical design:**
```c
// voxel.h
typedef struct voxel_chunk_s {
    unsigned char voxels[16][16][16];  // 4096 bytes per chunk
    int lighting[16][16][16];          // Optional per-voxel light data
} voxel_chunk_t;

typedef struct voxel_world_s {
    int dims[3];              // Chunk grid dimensions
    voxel_chunk_t **chunks;    // Flat array, indexed as [x][y][z]
    float voxel_size;         // World units per voxel (e.g., 1.0)
} voxel_world_t;
```

**Patterns to follow:**
- `heightmap_t` structure from `gl/gl_terrain.h`
- `model_t` initialization patterns from `common/com_mesh.h`

**Test scenarios:**
- Happy path: Create voxel world with known dimensions, verify chunk allocation
- Edge case: Request chunk outside bounds, verify NULL/empty return
- Memory: 100 chunks × 4KB = 400KB reasonable for test world

**Verification:**
- Voxel world can be allocated and freed without leaks
- Chunk access by index returns valid chunk or NULL

---

- U2. **Voxel Collision Interface**

**Goal:** Implement `NativeTrace` and `PointContents` for voxel worlds.

**Requirements:** R3

**Dependencies:** U1

**Files:**
- Modify: `fteqw/engine/common/voxel.c` - Add `VoxelTrace()`, `VoxelPointContents()`
- Modify: `fteqw/engine/server/sv_init.c` - Register voxel model after BSP

**Approach:**
- VoxelTrace(): Convert world start/end to chunk indices, iterate chunks, test ray against voxel data
- PointContents(): Determine which voxel a point is in, return material ID
- Register model with `funcs.NativeTrace` and `funcs.PointContents` function pointers
- Engine traces voxel first (registered after BSP), falls back to BSP on miss

**Technical design:**
```c
trace_t VoxelTrace(voxel_world_t *vw, vec3_t start, vec3_t end) {
    // Convert to voxel coordinates
    // Iterate chunks along ray
    // Per chunk: AABB test first, then voxel raycast
    // Return earliest hit with material ID
}

int VoxelPointContents(voxel_world_t *vw, vec3_t pos) {
    // Convert position to chunk index + voxel index
    // Return material ID at that voxel
    // Return CONTENTS_EMPTY if outside voxel bounds
}
```

**Patterns to follow:**
- `HeightmapTraceThrough()` from `gl/gl_heightmap.c`
- `World_BoxTrace()` from `server/world.c` for return type conventions

**Test scenarios:**
- Happy path: Ray through voxel world hits, returns correct fraction
- Edge case: Ray starts inside voxel, returns fraction 0
- Edge case: Ray outside voxel bounds, returns TRACERETYPE_AllClear
- Error path: NULL voxel world pointer, handle gracefully

**Verification:**
- VoxelTrace called for voxel models
- Collision with voxels produces correct trace results
- PointContents returns expected values at known positions

---

- U3. **Voxel File I/O**

**Goal:** Load voxel worlds from disk file.

**Requirements:** R1

**Dependencies:** U1

**Files:**
- Create: `fteqw/engine/common/voxel_parse.c` - File format parsing
- Modify: `fteqw/engine/server/sv_init.c` - Trigger voxel load after BSP

**Approach:**
- Define simple binary format with text header + binary data
- Load via `FS_LoadFile()` / `FS_OpenVFS()`
- Parse header first, allocate world, then load chunks
- Called after `SV_SpawnServer()` completes BSP load

**Technical design:**
```
File format:
+-----------+
// Text header (readable in hexdump)
// [voxel]
// version=1
// chunk_dim=16 16 16
// world_size=512 192 512
// chunks=100
// data_offset=1024
+-----------+
// Binary chunk data (offset from data_offset)
// [chunk 0] [chunk 1] ... [chunk N]
+-----------+
```

**Patterns to follow:**
- `Terr_ReadSection()` for section loading patterns
- `CVoxelDoc::Load()` pattern from CSO research

**Test scenarios:**
- Happy path: Load valid voxel file, verify world dimensions
- Edge case: File missing chunks, handle gracefully
- Error path: Invalid magic bytes, reject with console error

**Verification:**
- Voxel file loads without crash
- World dimensions match file header
- All chunks present and valid

---

- U4. **Voxel Rendering**

**Goal:** Render voxel worlds using FTEQW's mesh pipeline.

**Requirements:** R4

**Dependencies:** U1, U3

**Files:**
- Create: `fteqw/engine/gl/gl_voxel.c` - Voxel mesh generation
- Modify: `fteqw/engine/gl/gl_model.c` - Mesh submission on world load

**Approach:**
- At world load, iterate all chunks and generate surface meshes
- Use `R_AddMeshToScene()` or `R_MeshBuffer` for rendering
- Generate UV coordinates from voxel position for texturing
- Follow heightmap batching patterns for performance

**Technical design:**
```c
void Voxel_GenerateMesh(voxel_world_t *vw) {
    // For each non-empty chunk:
    //   Iterate all voxels
    //   Generate face mesh for exposed faces only
    //   Submit to render buffer
}
```

**Patterns to follow:**
- `HM_RenderSection()` from `gl/gl_heightmap.c`
- Terrain chunk batching for performance

**Test scenarios:**
- Happy path: Voxel world renders visible geometry
- Edge case: All voxels same material, verify no redundant faces
- Performance: Large world (1000+ chunks) renders without frame drop

**Verification:**
- Voxels visible in 3D view at correct positions
- Textures/materials applied correctly
- No z-fighting with BSP geometry

---

- U5. **QuakeC VoxelEntity Baseclass**

**Goal:** Create base QuakeC class for voxel-spawned entities.

**Requirements:** R2

**Dependencies:** U2, U3

**Files:**
- Create: `nuclide/base/src/shared/voxels/VoxelEntity.qc` - Base class
- Create: `nuclide/base/src/shared/voxels/voxels.qh` - Header with constants
- Modify: `nuclide/base/src/shared/include.src` - Include new files

**Approach:**
- Create `ncVoxelEntity` inheriting from `ncEntity`
- Voxel entities spawned via `voxelspawn` classname in Radiant
- `SpawnKey()` parses voxel-specific spawnargs (voxel_id, voxel_position, etc.)
- Use `Input()` / `output` system for trigger chaining

**Technical design:**
```quakec
class ncVoxelEntity extends ncEntity {
    vector voxel_origin;     // Position in voxel grid coordinates
    float voxel_chunk_x;
    float voxel_chunk_y;
    float voxel_chunk_z;

    override void Spawn() {
        // Parse spawnargs
        // Link to parent voxel world
        // Set model (if visual entity)
    }

    virtual void OnVoxelDamaged(float damage) {
        // Handle damage to voxel entity
    }
}
```

**Patterns to follow:**
- `ncTrigger` from `src/shared/system/Trigger.qc` for entity patterns
- `Entity.qc` I/O system for trigger chaining
- entityDef system for Radiant integration

**Test scenarios:**
- Happy path: Spawn via classname, verify entity created
- Happy path: Fire output, verify target triggered
- Edge case: Spawn with invalid voxel coords, handle gracefully

**Verification:**
- Entity spawns in world with correct position
- I/O system works (Use, FireOutput, etc.)
- Think() callback fires on schedule

---

- U6. **QuakeC Voxel Triggers and Doors**

**Goal:** Implement specific voxel entity types (doors, spawners, triggers).

**Requirements:** R2, R5

**Dependencies:** U5

**Files:**
- Create: `nuclide/base/src/shared/voxels/VoxelDoor.qc`
- Create: `nuclide/base/src/shared/voxels/VoxelTrigger.qc`
- Create: `nuclide/base/src/shared/voxels/VoxelSpawnPoint.qc`
- Create: `nuclide/base/decl/def/voxel_entities.def` - Entity definitions for Radiant

**Approach:**
- `ncVoxelDoor`: Extends `ncMover` to animate voxel geometry opening/closing
- `ncVoxelTrigger`: Extends `ncTrigger` to activate when player enters voxel region
- `ncVoxelSpawnPoint`: Spawn point for players/NPCs within voxel structure

**Patterns to follow:**
- `ncMoverEntity` for door movement patterns
- `ncTrigger` for trigger behavior
- entityDef declarations from existing `.def` files

**Test scenarios:**
- Happy path: VoxelDoor opens/closes on trigger
- Happy path: VoxelTrigger fires when player enters
- Integration: VoxelSpawnPoint teleports player to correct location

**Verification:**
- Doors animate smoothly
- Triggers fire at correct time
- Spawn points work for both player and NPC entities

---

- U7. **Radiant Integration**

**Goal:** Enable "voxelspawn" entity spawning in NetRadiant-Custom.

**Requirements:** R5

**Dependencies:** U5, U6

**Files:**
- Modify: `nuclide/base/scripts/entities.def` - Add voxelspawn classname
- Create: `nuclide/base/scripts/voxel_ents.def` - Voxel entity definitions

**Approach:**
- Add `voxelspawn` entity class pointing to `ncVoxelEntity`
- Add specific voxel entity classes (door, trigger, spawnpoint)
- Follow existing entityDef patterns in `base/scripts/entities.def`

**Patterns to follow:**
- Existing entity definitions from `base/scripts/entities.def`
- Doom3 entityDef style (key value pairs)

**Test scenarios:**
- Happy path: Place voxelspawn in Radiant, spawns correctly in game
- Edge case: Place entity with missing required spawnargs

**Verification:**
- Entity visible and placeable in Radiant
- Spawns with correct class in game

---

## System-Wide Impact

- **Interaction graph:** Voxel world loaded after BSP, collision checked before BSP trace
- **Error propagation:** Invalid voxel file logs error but continues with BSP-only world
- **State lifecycle risks:** Voxel world freed on map change; ensure no dangling pointers
- **Integration coverage:** QuakeC entities must sync with voxel collision state

---

## Risks & Dependencies

| Risk | Mitigation |
|------|------------|
| Performance: voxel traces could be slow | Defer optimization; use early-out in trace |
| Memory: large voxel worlds could be heavy | Implement chunk streaming later if needed |
| Collision priority: voxel vs BSP priority | Test thoroughly; priority via registration order |

---

## Documentation / Operational Notes

- Document simplified voxel file format for modders
- Add FTEQW console commands: `voxel_load <file>`, `voxel_debug 1`, `voxel_list`

---

## Sources & References

- FTEQW heightmap: `fteqw/engine/gl/gl_heightmap.c`, `gl/gl_terrain.h`
- FTEQW collision: `fteqw/engine/server/world.c`, `common/world.h`
- FTEQW model: `fteqw/engine/common/com_mesh.h`
- Nuclide Entity: `nuclide/base/src/shared/system/Entity.qc`
- Nuclide Triggers: `nuclide/base/src/shared/system/Trigger.qc`
- CSO voxel research: `nuclide/research/CSOvoxel/hw_dll/voxel_code.md`