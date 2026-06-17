# Voxel World Implementation Plan for Nuclide

## Status: Research Complete, Planning Implementation

This document outlines the implementation approach for adding voxel world support to Nuclide (FTEQW-based Quake engine), based on reverse engineering of CSO (Crossfire Online) voxel system.

---

## 1. Lua Integration Strategy

### Option A: Embedded Lua 5.3 (Recommended)
**Pros:**
- Full control over Lua VM state
- Matches CSO architecture exactly
- Allows sandbox_script mode implementation
- No external dependencies beyond Lua itself

**Cons:**
- Requires integrating Lua 5.3 into FTEQW engine
- Memory management responsibility
- More initial implementation work

**Approach:**
1. Add `lua53` subdirectory to FTEQW engine with Lua 5.3.4 sources
2. Create `gLV_Init()` in `engine/common/lua_core.c` for VM creation
3. Register core API functions matching CSO's `game.*` table:
   - `GetTime()`, `Create()`, `RandomInt()`, `RandomFloat()`
   - `GetEntity()`, `FindPlayerAt()`, `GetTriggerEntity()`
   - `SyncValue()`, `GetSyncValue()`
   - Event hooks: `OnUpdate()`, `OnPlayerConnect()`, etc.
4. Implement sandbox mode by excluding dangerous functions (io, os, debug)

**Lua VM Initialization Chain:**
```
Host_Init()
  → gLV_Init()                    // Create lua_State
    → luaL_newstate()             // Allocate VM
    → luaL_openlibs()             // Standard libs (subset)
    → Register_game_api()          // Push 'game' table with functions
    → Register_voxel_api()         // Push 'voxel' table if needed
```

### Option B: LuaJIT FFI (Alternative)
**Pros:**
- Faster JIT compilation
- Easier integration via existing FTEQW FFI system
- Lower memory overhead

**Cons:**
- LuaJIT uses Lua 5.1 syntax, CSO uses 5.3
- FFI complexity for C function binding
- Sandbox control harder

**Recommendation:** Use Option A (embedded Lua 5.3) for closest CSO parity.

---

## 2. CVoxelScriptTrigger Equivalent Design

CSO uses `CVoxelScriptTrigger` and `CVoxelScriptCaller` entities for Lua script execution. Nuclide implementation:

### QuakeC Implementation (Preferred for game logic)

```qc
// base/src/shared/voxel/VoxelScript.qc

namespace VoxelScript
{
    // Base class for all script-triggered voxel entities
    .float script_version;
    .float script_running;
    .string script_file;
    .string trigger_name;

    void Trigger_Script(entity triggerer) = 1;
    void Run_Script(string func, ...) = 2;
    void SetSyncValue(string key, float value) = 3;
    float GetSyncValue(string key) = 4;
}

// Trigger that executes Lua via CVoxelScriptTrigger pattern
class ncVoxelScriptTrigger : ncTrigger
{
    .string script_text;
    .string trigger_func;
    .float  trigger_delay;

    void() ncVoxelScriptTrigger = 5;
    void() trigger = 6;

    virtual void() OnTrigger = 7;
    virtual void() OnUpdate = 8;
}
```

### C Implementation (For engine-level integration)

For performance-critical path and Lua VM ownership:

```c
// engine/common/lua_vowel.h

typedef struct lua_VoxelTrigger_s {
    edict_t *ent;
    int      lua_ref;        // Reference to script function
    char     trigger_name[64];
    qboolean running;
} lua_VoxelTrigger_t;

// In lua_core.c
void LV_RegisterScriptTrigger(edict_t *ent, const char *script);
void LV_ExecuteTrigger(edict_t *trigger, edict_t *activator);
void LV_RunTick(void);  // Calls game.OnUpdate() if defined
```

---

## 3. Voxel World Initialization Chain

### Map Loading Sequence

```
1. SV_SpawnServer(mapname)
   ├── BSP loaded normally
   ├── Entities spawned (including voxelspawn)
   │
2. VoxelWorld_Init(mapId, vxl_path)
   ├── VFS_LoadFile(vxl_path)           // Load .vxl
   ├── VXL_ParseHeader()                // Verify "csov" magic, version 0x1337ad9
   ├── VXL_Decompress()                  // LZMA1 decompression
   ├── VXL_ParseChunks()                // Parse 3456 chunks × 24×12×12 voxels
   │
3. VXL_LoadScript(vxl_data, "game.lua")
   ├── luaL_loadbuffer()
   ├── lua_pcall()                       // Execute in sandbox or full mode
   │
4. VXL_ParseTreeview()                  // Parse treeview section for entity tree
   └── CVoxelEntity spawn loop
       └── SV_LinkEdict()               // Add to physics world
```

### .vxl Parsing (Key Structures)

```c
// engine/common/voxel/vxl_parse.h

#define VXL_MAGIC    0x766f7363  // "csov"
#define VXL_VERSION  0x1337ad9

typedef struct {
    uint32_t magic;           // "csov"
    uint32_t padding;         // 0x2e2e2e2e
    uint32_t version;         // 0x1337ad9
    uint32_t orig_size;       // Decompressed size
    uint8_t  lzma_props[5];   // LZMA1 properties
} vxl_header_t;

typedef struct {
    char    *section_type;    // "global_data", "chunk", "entity", "water", "treeview"
    uint32_t section_size;
    void    *section_data;
} vxl_section_t;

// global_data key-value pairs (text keys, binary values)
typedef struct {
    char     key[64];
    uint8_t  type;           // 0=uint8, 1=uint32, 2=float, 3=string
    union { uint8_t u8; uint32_t u32; float f; char *str; } value;
} vxl_kv_t;

// chunk data (per 24×12×12 chunk)
typedef struct {
    uint8_t  material_id;
    uint8_t  sublayer;
    uint16_t flags;
    // ... voxel data follows
} vxl_chunk_t;
```

---

## 4. Entity Synchronization Approach

### CVoxelReplica Sync Pattern (from research)

CSO uses delta compression with dirty flags for network efficiency:

| Method | Offset | Purpose |
|--------|--------|---------|
| SendVars | +0x18 | Prepare state for transmission |
| Pack | +0x24 | Serialize to bitstream |
| Unpack | +0x28 | Deserialize from bitstream |
| SetDirty | +0x2C | Mark field as changed |
| IsDirty | +0x34 | Check if sync needed |

### Nuclide Implementation

```c
// engine/server/sv_voxel.c

// Voxel entity state structure
typedef struct voxelent_state_s {
    vec3_t    origin;
    vec3_t    angles;
    vec3_t    scale;
    int       modelindex;
    int       effects;
    float     anim_time;
    // ... additional replicated fields
} voxelent_state_t;

// Delta compression for voxel entities
void SV_VoxelDeltaPack(edict_t *ent, client_t *client, sizebuf_t *buf);
void SV_VoxelDeltaUnpack(edict_t *ent, const uint8_t *data, size_t len);

// Dirty flag tracking per entity
#define VOXELF_DIRTY_ORIGIN   BIT(0)
#define VOXELF_DIRTY_ANGLES   BIT(1)
#define VOXELF_DIRTY_MODEL    BIT(2)
#define VOXELF_DIRTY_EFFECTS  BIT(3)
```

---

## 5. QuakeC Gamecode Changes

### New Files

```
base/src/shared/voxel/
├── VoxelWorld.qc      // Voxel world management
├── VoxelChunk.qc      // Chunk rendering/collision
├── VoxelEntity.qc     // Base entity class
├── VoxelScript.qc     // Script trigger entities
├── VoxelMonster.qc    // Monster AI base
└── VoxelDefs.qc       // Shared constants
```

### Key Entities

```qc
// voxelspawn - Placed in BSP, triggers voxel world loading
class ncVoxelSpawn : ncEntity
{
    .string  vxl_filename;
    .string  map_id;
    .float   voxel_scale;

    void() ncVoxelSpawn = 1;
    virtual void() Spawn = 2;
}

// Voxel world singleton
class ncVoxelWorld : ncEntity
{
    static ncVoxelWorld world;

    .float  active;
    .float  chunk_count;
    .vector mins;
    .vector maxs;

    void() ncVoxelWorld = 3;
    virtual void() Spawn = 4;
    virtual void() Think = 5;
}

// Scripted trigger (CVoxelScriptTrigger equivalent)
class ncVoxelScriptTrigger : ncTrigger
{
    .string  script_func;
    .float   script_delay;
    .float   script_repeat;

    void() ncVoxelScriptTrigger = 6;
    virtual void() Trigger = 7;
}

// Monster spawner (CVoxelMonsterSpawner equivalent)
class ncVoxelMonsterSpawner : ncTrigger
{
    .string  monster_type;
    .float   spawn_interval;
    .float   spawn_count;
    .float   active;

    void() ncVoxelMonsterSpawner = 8;
    virtual void() Trigger = 9;
}
```

---

## 6. FTEQW Engine Changes

### New Source Files

```
fteqw/engine/common/
├── lua_core.c          // Lua VM management
├── lua_api.c           // game.* API implementation
├── lua_api_game.c      // Game-specific bindings
├── lua_api_voxel.c     // Voxel-specific bindings
├── vxl_parse.c         // .vxl file parser
└── vxl_decompress.c    // LZMA decompression

fteqw/engine/server/
├── sv_voxel.c          // Voxel entity server logic
├── sv_voxel_send.c     // Network delta compression
└── sv_voxel_physics.c  // Voxel collision

fteqw/engine/gl/
├── gl_voxel.c          // Voxel chunk rendering
└── gl_voxel_meshes.c   // Mesh generation from chunks
```

### Engine Hooks

```c
// sv_init.c - Map loading
void SV_SpawnServer(char *mapname)
{
    // ... existing BSP loading ...

    // Check for voxelspawn entity
    for (i = 0; i < sv.num_edicts; i++) {
        ent = EDICT_NUM(i);
        if (!strcmp(ent->classname, "voxelspawn")) {
            VoxelWorld_Init(ent->vxl_filename);
            break;
        }
    }
}

// cl_main.c - Client receives voxel world
void CL_ParseVoxelCreate(sizebuf_t *msg)
{
    int entnum = MSG_ReadShort(msg);
    // ... spawn voxel entity ...
}

// gl_model.c - Voxel chunk rendering
void Mod_LoadVoxelChunks(model_t *mod, vxl_chunk_t *chunks, int count)
{
    // Generate meshes for rendering
}
```

---

## 7. Implementation Phases

### Phase 1: Foundation (Week 1-2)
- [ ] Integrate Lua 5.3.4 into FTEQW build
- [ ] Implement `gLV_Init()` and core VM management
- [ ] Register `game.*` API functions
- [ ] Create `lua_core.c` with basic bindings

### Phase 2: .vxl Parsing (Week 2-3)
- [ ] Implement LZMA1 decompression
- [ ] Parse .vxl header and validate
- [ ] Parse global_data section (key-value pairs)
- [ ] Parse chunk section (3456 × 24×12×12 voxels)
- [ ] Parse treeview section (entity tree)

### Phase 3: Script Integration (Week 3-4)
- [ ] Implement `LV_LoadScript()` for game.lua
- [ ] Add sandbox mode (restrict dangerous functions)
- [ ] Implement `scpcall` / `scpsig` systems
- [ ] Connect script triggers to QuakeC entities

### Phase 4: Entity System (Week 4-6)
- [ ] Implement `ncVoxelWorld` singleton
- [ ] Implement `ncVoxelScriptTrigger`
- [ ] Implement `ncVoxelScriptCaller`
- [ ] Implement `ncVoxelMonsterSpawner`
- [ ] Add 108 entity type support (CVoxelEntity template)

### Phase 5: Network Sync (Week 6-7)
- [ ] Implement voxel entity delta compression
- [ ] Add `SendVars`/`RecvVars` equivalent
- [ ] Implement dirty flag tracking
- [ ] Client-side interpolation

### Phase 6: Rendering (Week 7-8)
- [ ] Generate meshes from chunk data
- [ ] Implement voxel material system
- [ ] Add water/liquid rendering
- [ ] Optimize with mesh batching

### Phase 7: Testing (Week 8+)
- [ ] Load sample .vxl files
- [ ] Test script execution (game.lua)
- [ ] Verify entity spawning from treeview
- [ ] Test network sync with multiple clients

---

## 8. Testing Strategy

### Unit Tests
- .vxl parser: Parse known sample, verify chunk count
- Lua API: Call each `game.*` function, verify behavior
- Delta compression: Pack/unpack cycle, verify equality

### Integration Tests
1. Load map with `voxelspawn` entity
2. Verify .vxl file loaded and parsed
3. Verify game.lua executed
4. Verify entities spawned from treeview
5. Connect 2+ clients, verify sync

### Sample .vxl
A sample .vxl file is needed for testing. Based on prior research:
- Header: 21 bytes (csov magic + version + orig_size + LZMA props)
- Decompressed size: 122,049 bytes
- global_data: text keys + binary values
- chunk: 3456 chunks × ~34 bytes avg
- entity: version=20151003
- water: version=20151008
- treeview: version=20200327

---

## 9. Open Questions

1. **LZMA1 Decompression**: Python's lzma module cannot decompress (uses LZMA2 internally). Nexon's custom LZMA SDK may be needed, or implement LZMA1 manually.

2. **Sample .vxl Files**: Where can test .vxl files be obtained? CSO game client installation?

3. **FTEQW Voxel Collision**: How does SV_Trace interact with voxel geometry? Need to map voxel voxels to clipnodes or implement separate collision.

4. **Material System**: How are voxel materials mapped to FTEQW textures? CSO likely has custom material IDs.

5. **Chunk LOD**: CSO may have level-of-detail rendering. Is this needed for Nuclide?

---

## 10. References

- CSO Research: `research/CSOvoxel/*.md`
- FTEQW Engine: `fteqw/engine/server/sv_init.c`, `fteqw/engine/common/world.h`
- Nuclide QuakeC: `nuclide/src/shared/system/Entity.qc`, `nuclide/src/shared/game/Actor.qc`
- Lua 5.3: https://www.lua.org/manual/5.3/

---

*Last Updated: 2026-05-18*
*Status: Implementation Ready*
