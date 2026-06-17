# CVoxelReplica Class Research - Entity Synchronization

## Overview
CVoxelReplica is the base class for all replicated voxel entities in the CSO voxel system. It handles network synchronization, delta compression, and state management for voxel entities across the network.

**Research Target DLLs**: `mp.dll` (Server), `hw.dll` (Core Voxel Engine)
**Known Addresses**: CVoxelScriptCaller RTTI: `02d9d3c0`, CVoxelScriptTrigger RTTI: `02d9d354`

---

## 1. CVoxelReplica vftable

### 1.1 vftable Location
**Status**: NOT YET EXTRACTED - Requires IDA/hex analysis of mp.dll

**Search Strategy**:
```bash
# Pattern: constructor sets vftable via "mov [ecx], offset _??_CVoxelReplica"
# Or: constructor with pattern like "mov [edi], <vftable_addr>"
# Scan mp.dll code section for c707/mov [reg], imm32 patterns
```

### 1.2 Known CVoxelReplica References

| Source | Address | Description |
|--------|---------|-------------|
| hw.dll RTTI | `.?AVC_VoxelReplica@@` | RTTI type name string |
| client.dll | `T_VoxelEntity<UT_*, VC_VoxelReplica>` | Template pattern for entity types |

**RTTI hierarchy** (from hw.dll):
```
C_VoxelReplica (base replicated entity)
  └── T_VoxelEntity<UT_*, VC_VoxelReplica> (template specialization)
        └── CVoxelScriptCaller (specific subclass at 02d9d3c0)
        └── CVoxelScriptTrigger (at 02d9d354)
        └── CVoxelMonsterSpawner
        └── CVoxelPlayerSpawn
        └── CVoxelItemSpawn
        └── ... (90+ entity types)
```

---

## 2. Inheritance Chain

### 2.1 Replica Base Classes

Based on GoldSrc entity replication patterns and CSO analysis:

```
CBaseEntity (GoldSrc base entity)
  └── CBaseAnimating (animated entities)
        └── CBaseAnimatingExpand (expanded animating)
              └── CVoxelReplica (voxel-specific replicated entity base)
                    └── T_VoxelEntity<UT_Type, CVoxelReplica> (template)
                          ├── CVoxelScriptCaller
                          ├── CVoxelScriptTrigger
                          ├── CVoxelMonsterSpawner
                          ├── CVoxelPlayerSpawn
                          ├── CVoxelItemSpawn
                          └── ... (90+ specializations)
```

### 2.2 Template Pattern Analysis

The key template pattern found in client.dll:
```
. ? AV ? $T_VoxelEntity @ UT_VoxelMonsterSpawner @ @ VC_VoxelReplica @ @ @
. ? AV ? $T_VoxelEntity @ UT_VoxelPlayerSpawn @ @ VC_VoxelReplica @ @ @
. ? AV ? $T_VoxelEntity @ UT_VoxelItemSpawn @ @ VC_VoxelReplica @ @ @
```

This indicates:
- `T_VoxelEntity<UnitType, BaseReplica>` is the template
- `UnitType` varies by entity (e.g., `UT_VoxelMonsterSpawner`, `UT_VoxelPlayerSpawn`)
- `BaseReplica` is always `VC_VoxelReplica`

---

## 3. Key Virtual Functions for Entity Sync

### 3.1 Expected vftable Entries (Approximated)

Based on GoldSrc replication patterns and CSO network architecture:

| Index | Offset | Function | Purpose |
|-------|--------|----------|---------|
| 0 | +0x00 | Destructor | Cleanup |
| 1 | +0x04 | `Init` | Initialize replica state |
| 2 | +0x08 | `Think` | Per-frame logic |
| 3 | +0x0C | `Touch` | Collision handling |
| 4 | +0x10 | `Start` | First spawn |
| 5 | +0x14 | `Stop` | Despawn |
| 6 | +0x18 | `SendVars` | **CRITICAL: Send replicated variables** |
| 7 | +0x1C | `RecvVars` | **CRITICAL: Receive replicated variables** |
| 8 | +0x20 | `GetPackSize` | **Delta: Calculate packed size** |
| 9 | +0x24 | `Pack` | **Delta: Serialize state for network** |
| 10 | +0x28 | `Unpack` | **Delta: Deserialize state from network** |
| 11 | +0x2C | `SetDirty` | Mark state as changed |
| 12 | +0x30 | `ClearDirty` | Clear dirty flag after sync |
| 13 | +0x34 | `IsDirty` | Check if needs sync |
| 14 | +0x38 | `Interpolate` | **Client-side interpolation** |
| 15 | +0x3C | `PreThink` | Pre-frame processing |
| 16 | +0x40 | `PostThink` | Post-frame processing |

### 3.2 Critical Sync Functions

#### SendVars / RecvVars
```c
// Called to transmit replicated entity state
virtual void SendVars(CBitBuffer* buffer, float time);
virtual void RecvVars(CBitBuffer* buffer, float time);
```

#### Pack / Unpack (Delta Compression)
```c
// Serialize entity state for network transmission
virtual int GetPackSize(const entity_state_t* state);
virtual void Pack(const entity_state_t* state, byte* buffer, int size);
virtual void Unpack(byte* buffer, int size, entity_state_t* state);
```

#### Dirty Flag Management
```c
// Dirty flag pattern for selective synchronization
virtual void SetDirty();
virtual void ClearDirty();
virtual bool IsDirty() const;

// Optional: per-field dirty tracking
virtual void MarkFieldDirty(int fieldIndex);
virtual void ClearFieldDirty(int fieldIndex);
```

#### Interpolation (Client-Side Prediction)
```c
// Smooth client-side movement between server updates
virtual void Interpolate(float currentTime, float lastUpdateTime);
virtual void Extrapolate(float currentTime);
virtual vec3_t GetInterpolatedPosition() const;
virtual vec3_t GetInterpolatedAngles() const;
```

---

## 4. CVoxelScriptCaller vftable

**RTTI Location**: `02d9d3c0` (client.dll)
**RTTI String**: `.?AVCVoxelScriptCaller@@`

### 4.1 CVoxelScriptCaller Inheritance
```
CVoxelReplica (base)
  └── CVoxelScriptCaller (script-triggered replica)
```

### 4.2 Script System Integration

From mp.dll string analysis:
- `scpcall %s %d %s` - Script call with parameters
- `scpsig` - Script signal
- `GetScriptCaller` - Get calling entity
- `SyncValue only can save bool, number, string!!!` - Script value sync constraint

**Script Functions**:
```c
// Script integration methods
void scpcall(const char* functionName, int param1, const char* param2);
void scpsig(const char* signalName);  // Fire signal to script
CVoxelScriptCaller* GetScriptCaller();  // Get trigger entity
```

### 4.3 Expected CVoxelScriptCaller vftable (Approximated)

| Index | Offset | Function | Purpose |
|-------|--------|----------|---------|
| 0 | +0x00 | Destructor | Cleanup |
| 1 | +0x04 | `Init` | Initialize script caller |
| 2 | +0x08 | `CallScript` | Execute script function |
| 3 | +0x0C | `Signal` | Fire script signal |
| 4 | +0x10 | `GetScriptVars` | Get script variables |
| 5 | +0x14 | `SetScriptVars` | Set script variables |
| 6 | +0x18 | `OnScriptResult` | Handle script callback |
| 7 | +0x1C | `GetCaller` | Get triggering entity |
| 8 | +0x20 | `SendVars` | (inherited) |
| 9 | +0x24 | `RecvVars` | (inherited) |
| 10 | +0x28 | `Pack` | (inherited) |
| 11 | +0x2C | `Unpack` | (inherited) |
| 12 | +0x30 | `SetDirty` | (inherited) |
| 13 | +0x34 | `Interpolate` | (inherited) |

---

## 5. Replica / NetworkObject Related Classes

### 5.1 Entity State Synchronization

From IVoxelClient packet type analysis:
```
Packet Type  Handler        Purpose
----------  -------------- ---------------------------------
0xe0        local_c4       Entity data batch 1
0xe1        local_b4       Entity data batch 2
0x6d80      local_88       Entity data batch 3
0x73c5      String parse   Text-based entity sync
0xd7        FUN_02d8a710   Numeric value (max 0x7e)
0x83        FUN_02d8a710   Numeric value (max 0xfd)
0x536e      Entity create  Entity creation (local_44)
0x22b59c    Entity create  Entity creation (local_40)
0x23e383    Position/value Position/value update
0x86        Entity data   Entity data (local_3c)
0x9c        Single value  Single value (max 1)
0x63a2      Alloc         Memory allocation
0x258688    Entity create Entity creation (local_38)
0x56aa      Result        Result stored (local_54)
0x56bb      Result        Result stored (local_4c)
```

### 5.2 IVoxelClient Sync Method
```c
// From hw_dll/voxel_code.md - approximated IVoxelClient methods
| Offset | Method Type | Purpose |
|--------|-------------|---------|
| +0x1C | SyncEntities | Synchronize voxel entities |
```

### 5.3 Network Architecture

```
Server (mp.dll)                        Client (client.dll)
-----------                            ------
CVoxelReplica::SendVars()    ────────>  IVoxelClient::HandlePacket()
     │                                      │
     ├──> Pack()                            ├──> RecvVars()
     │                                      │
     └──> svc_voxel                        0xe0/0xe1/0x6d80 packets
                                              │
                                              └──> Update entity state
```

---

## 6. Known RTTI Classes (from hw.dll)

| RTTI Name | Class | Purpose |
|-----------|-------|---------|
| `.?AVC_VoxelReplica@@` | CVoxelReplica | Replicated entity |
| `.?AVCVoxelSoccerGoalNet@@` | CVoxelSoccerGoalNet | Soccer goal |
| `.?AVCVoxelSoccerBallSpawn@@` | CVoxelSoccerBallSpawn | Ball spawn |
| `.?AVCVoxelBreakableProp@@` | CVoxelBreakableProp | Breakable prop |
| `.?AVCVoxelSelectRandomProp@@` | CVoxelSelectRandomProp | Random selector |
| `.?AVCVoxelC4TargetArea@@` | CVoxelC4TargetArea | C4 target |
| `.?AVCVoxelBuyZone@@` | CVoxelBuyZone | Buy zone |
| `.?AVCVoxelMainShelter@@` | CVoxelMainShelter | Main shelter |
| `.?AVCVoxelPartner@@` | CVoxelPartner | Partner entity |
| `.?AVCVoxelPlayerSpawn@@` | CVoxelPlayerSpawn | Player spawn |

---

## 7. Next Steps for vftable Extraction

### 7.1 Required Analysis (IDA Required)

1. **Find CVoxelReplica constructor**:
   - Search mp.dll for `mov [ecx], offset _??_CVoxelReplica`
   - Pattern: `c7 01 ?? ?? ?? ??` (mov [ecx], imm32)
   - Constructor address will set vftable at +0x0

2. **Cross-reference vftable**:
   - Constructor will set vftable to known address
   - Search data section for vftable pointers

3. **Extract function names** (if PDB available):
   - Look for symbols like `CVoxelReplica::SendVars`
   - Or `CVoxelReplica::_SendVars`
   - Or `CVoxelReplica::Pack`

4. **Pattern match sync functions**:
   - `SendVars`: takes CBitBuffer*, likely 2-3 parameters
   - `Pack`: takes entity_state*, byte*, int - returns packed size
   - Look for functions calling `WRITE_*` macros

### 7.2 Function Signature Patterns

```c
// GoldSrc-style replication
void CVoxelReplica::SendVars(CBitBuffer* buffer, float time)
{
    // WRITE_* macros for each replicated field
    buffer->WriteFloat(m_flSimulationTime);
    buffer->WriteVec3(m_vecOrigin);
    buffer->WriteAngle(m_angRotation);
    // ...
}

// Delta packing
int CVoxelReplica::Pack(const entity_state_t* state, byte* buffer, int size)
{
    // Pack only changed fields based on dirty flags
    // Returns bytes written
}

// Interpolation
void CVoxelReplica::Interpolate(float currentTime, float lastUpdateTime)
{
    // Lerp between last state and current state
    // Based on interp_amount and lastUpdateTime
}
```

---

## 8. Key Offsets (Entity State)

Based on monster factory code patterns:

| Offset | Field | Type | Purpose |
|--------|-------|------|---------|
| +0x00 | vftable* | vftable* | Virtual function table |
| +0x08 | owner | Entity* | Owning entity |
| +0x2c | spawn_flag | int | Spawn state |
| +0x80 | entity_check | int | Voxel entity validity |
| +0xb8 | spawn_vftable | vftable* | CVoxelSpawn vftable |
| +0x238 | world | CVoxelWorld* | Parent voxel world |

---

## 9. SyncValue System

From mp.dll strings:
```
"SyncValue only can save bool, number, string!!!"
```

This indicates a script-accessible synchronization system:
- Script can call `SyncValue(key, value)` to sync values
- Values are transmitted via network packets
- Delta compression based on dirty tracking

**SyncValue Flow**:
```c
// 1. Script sets value
entity.SyncValue("health", 100);

// 2. Engine marks replica dirty
CVoxelReplica::SetDirty();

// 3. On next network update
CVoxelReplica::Pack(state, buffer, size);

// 4. Delta compression
// Only changed fields are sent

// 5. Client receives
IVoxelClient::HandlePacket(type, buffer);
CVoxelReplica::RecvVars(buffer, time);
```

---

## 10. References

- `research/CSOvoxel/hw_dll/voxel_code.md` - CVoxelReplica RTTI reference (line 630)
- `research/CSOvoxel/mp_dll/voxel_code.md` - Monster entity factory patterns
- `research/CSOvoxel/client_dll/voxel_code.md` - Template pattern `T_VoxelEntity`
- `research/CSOvoxel/mp_dll/voxel_strings.txt` - Script system strings
- `client.dll` RTTI at `02d9d3c0` - CVoxelScriptCaller type
- `client.dll` RTTI at `02d9d354` - CVoxelScriptTrigger type

---

## Appendix A: Hex Pattern Search Commands

```bash
# Search for vftable initialization in IDA
# Pattern: constructor sets vftable
# Look for: mov [reg], offset CVoxelReplica_vftable

# In IDA, search for:
# c7 01 ?? ?? ?? ??    # mov [ecx], imm32
# or
# 89 5? ?? ?? ?? ??    # mov [ebp+offset], eax

# Cross-reference from known RTTI
# RTTI string: ".?AVC_VoxelReplica@@"
# Follow xref to find vftable pointer table
```

---

## Appendix B: Draft CVoxelReplica Header

```c
// CVoxelReplica - Base class for replicated voxel entities
class CVoxelReplica {
public:
    // vftable at +0x00
    
    // === Core Functions ===
    virtual ~CVoxelReplica();
    virtual void Init();
    virtual void Think();
    virtual void Touch(CBaseEntity* other);
    virtual void Start();
    virtual void Stop();
    
    // === Network Synchronization ===
    virtual void SendVars(CBitBuffer* buffer, float time);
    virtual void RecvVars(CBitBuffer* buffer, float time);
    virtual int GetPackSize(const entity_state_t* state);
    virtual void Pack(const entity_state_t* state, byte* buffer, int size);
    virtual void Unpack(byte* buffer, int size, entity_state_t* state);
    
    // === Dirty Flag Management ===
    virtual void SetDirty();
    virtual void ClearDirty();
    virtual bool IsDirty() const;
    virtual void MarkFieldDirty(int fieldIndex);
    virtual void ClearFieldDirty(int fieldIndex);
    
    // === Interpolation ===
    virtual void Interpolate(float currentTime, float lastUpdateTime);
    virtual void Extrapolate(float currentTime);
    virtual vec3_t GetInterpolatedPosition() const;
    virtual vec3_t GetInterpolatedAngles() const;
    
    // === Script Integration ===
    virtual void CallScript(const char* functionName, int param1, const char* param2);
    virtual void Signal(const char* signalName);
    
    // === Fields ===
    // +0x08: owner entity
    // +0x2c: spawn state
    // +0x80: entity check
    // +0x238: voxel world pointer
    
    int m_nID;
    vec3_t m_vecOrigin;
    vec3_t m_vecAngles;
    float m_flSimulationTime;
    int m_fState;
    int m_nNumFields;
    int* m_pFieldDirty;
    float m_flLastUpdateTime;
    vec3_t m_vecLastOrigin;
    vec3_t m_vecLastAngles;
};
```