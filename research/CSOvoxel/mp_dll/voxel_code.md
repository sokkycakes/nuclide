# CSO Voxel Code Extracted from mp.dll (Server Game Logic)

## Voxel Monster Types (voxel_monster_*)
- `voxel_monster` - Base monster factory function
- `voxel_monster_a101ar` - AR assault rifle monster
- `voxel_monster_a104rl` - Rocket launcher monster
- `voxel_monster_a104rl_gun` - Rocket launcher gun variant
- `voxel_monster_boomer` - Boomer zombie
- `voxel_monster_boss_ampsuit` - Ampsuit boss
- `voxel_monster_boss_infectedtitan` - Infected Titan boss
- `voxel_monster_boss_protophobos` - Protophobos boss
- `voxel_monster_china` - China monster
- `voxel_monster_gasturret` - Gas turret
- `voxel_monster_ghost` - Ghost monster
- `voxel_monster_hooligan1` - Hooligan type 1
- `voxel_monster_hooligan2` - Hooligan type 2
- `voxel_monster_hooligancan` - Hooligan can
- `voxel_monster_maple` - Maple monster
- `voxel_monster_minion` - Minion monster
- `voxel_monster_shelternormal` - Shelter normal
- `voxel_monster_shturret` - SH turret
- `voxel_monster_snowball` - Snowball monster
- `voxel_monster_snowman` - Snowman monster
- `voxel_monster_turret` - Turret
- `voxel_monster_zombie` - Zombie monster

## Voxel Shared Entities (voxelShEnt*)
- `voxelShEntInWarehouse` - Warehouse entity
- `voxelShEntSpiderMine` - Spider mine entity
- `voxelShEntTrapTrigger` - Trap trigger entity

## Voxel Spawn System
- `voxelspawn` - Creates CVoxelSpawn entity
- CVoxelSpawn vftable at offset 0xb8
- Entity field at offset 0x2c = 0 (initialized)
- Entity field at offset 0x2 = param_1 (owner)

## Voxel Collision Handlers
- `CAirstrikeRocket::RocketTouch_Voxel` at 136d7a0
  - Iterates through voxel entities checking vftable at +0xa8
  - Checks entity type (0x2d = voxel type)
  - Calls FUN_1152d9c0 for impact handling
- `ThrowingKnifeEntity::FlyingTouch` at 115210f0
  - Handles knife collision with voxel terrain
  - Uses FUN_115112d0 to get voxel hit info
  - Calls entity vftable at +0x30, +0x38, +0xac, +0xbc

## Key Entity Vftable Offsets
- +0x30 - Entity type check function
- +0x38 - Some voxel interaction
- +0x80 - Voxel entity pointer check
- +0xa8 - Entity factory/creation
- +0xac - Another entity check
- +0xbc - Another entity check
- +0xb8 - CVoxelSpawn vftable pointer

## Game Modes (from client.dll strings)
- EGM_VOXEL_CREATE - Creation mode
- EGM_VOXEL_PVE - Player vs Environment
- EGM_VOXEL_PROPHUNT - Prop Hunt mode
- EGM_VOXEL_SHELTER - Shelter mode
- EGM_VOXEL_SCENARIOTX - Scenario TX mode

---

## Monster Factory Code

### voxelspawn (10a79c60)
```c
void voxelspawn(uint param_1)
{
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xb8), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10652d20();
    *puVar3 = CVoxelSpawn::vftable;
    DAT_11e9fbdc = puVar3;
    puVar3[0x2c] = 0;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### voxel_monster (10a939f0)
```c
void voxel_monster(uint param_1)
{
  uint uVar1;
  int iVar2;
  
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0xda0), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10a8b730();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster Base Initialization (FUN_10a8b730)
```c
undefined4 * __fastcall FUN_10a8b730(undefined4 *param_1)
{
  // Initializes VoxelMonster base class (0xc50 bytes total)
  
  // Hierarchy setup:
  *param_1 = CBaseMonster::vftable;          // Base entity
  param_1[0x314] = VoxelMonster::vftable;     // Monster AI vftable
  param_1[0x315] = param_1;                     // Self reference
  param_1[0x318] = 0x3f800000;                 // Scale = 1.0f
  
  // Animation component at offset 0x314
  param_1[0x314] = EntityAnimation::Component<class_VoxelMonster>::vftable;
  
  // Monster-specific fields:
  param_1[0x334] = 0x42a00000;                  // Float parameter (various uses)
  *(undefined2 *)(param_1 + 0x340) = 0x101;    // spawnflags
  param_1[0x341] = 0x20000;                     // spawnflag mask
  *(undefined2 *)(param_1 + 0x344) = 1;        // Entity type
  param_1[0x348] = 0xffffffff;                  // Some ID
  
  // Health/behavior params at 0x354+
  param_1[0x354] = 0x3f800000;                  // Default float value
  *(undefined2 *)(param_1 + 0x357) = 0x100;     // Some flag
}
```

### voxel_monster_zombie (10aa52a0)
```c
void voxel_monster_zombie(uint param_1)
{
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xda0), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10a8b730();
    *puVar3 = VoxelMonster_Zombie::vftable;
    puVar3[0x314] = VoxelMonster_Zombie::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### voxel_monster_boss_ampsuit (10a99440)
```c
void voxel_monster_boss_ampsuit(uint param_1)
{
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xe60), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10a8b730();
    *puVar3 = VoxelMonster_Boss::vftable;
    puVar3[0x314] = VoxelMonster_Boss::vftable;
    FUN_1094bf70();
    puVar3[0x375] = 0;
    puVar3[0x376] = 0;
    puVar3[0x377] = 0;
    *puVar3 = VoxelMonster_Boss_AmpSuit::vftable;
    puVar3[0x314] = VoxelMonster_Boss_AmpSuit::vftable;
    
    // Weapon systems
    puVar3[0x380] = VoxelMonster_Boss_AmpSuit::FlameThrower::vftable;
    puVar3[0x385] = 0x3fc43958;  // damage config
    puVar3[0x386] = 0x3fb33333;  // range config
    puVar3[0x387] = 0x4019999a;  // damage config
    puVar3[0x388] = 0x4059999a;  // range config
    
    puVar3[0x389] = VoxelMonster_Boss_AmpSuit::Laser::vftable;
    puVar3[0x38e] = 0x3fc43958;
    puVar3[0x38f] = 0x3fb33333;
    puVar3[0x390] = 0x4019999a;
    puVar3[0x391] = 0x4059999a;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### voxel_monster_ghost (10a9f710)
```c
void voxel_monster_ghost(uint param_1)
{
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xda8), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10a8b730();
    *puVar3 = VoxelMonster_Ghost::vftable;
    puVar3[0x314] = VoxelMonster_Ghost::vftable;
    puVar3[0x368] = 0;
    puVar3[0x369] = 0;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### voxel_monster_boomer (10aa51c0)
```c
void voxel_monster_boomer(uint param_1)
{
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xda0), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10a8b730();
    *puVar3 = VoxelMonster_Boomer::vftable;
    puVar3[0x314] = VoxelMonster_Boomer::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

---

## Collision Handlers

### CAirstrikeRocket::RocketTouch_Voxel (136d7a0)
```c
void __thiscall CAirstrikeRocket::RocketTouch_Voxel(CAirstrikeRocket *this, CBaseEntity *param_1)
{
  int *piVar1;
  int iVar2;
  int iVar3;
  int iVar4;
  
  FUN_1152d8f0();
  iVar3 = 1;
  iVar4 = *(int *)(this + 8) + 8;
  
  // Iterate through voxel entities
  if (0 < *(int *)(DAT_121b243c + 0x90)) {
    do {
      piVar1 = (int *)FUN_115126a0(iVar3);
      if ((piVar1 != (int *)0x0) && 
          (iVar2 = (**(code **)(*piVar1 + 0xa8))(), iVar2 != 0)) {
        FUN_1152d9c0(piVar1, iVar4, 
                     *(float *)(*(int *)(this + 8) + 0x178) * DAT_117574c8,
                     *(undefined4 *)(*(int *)(this + 8) + 0x1e8));
      }
      iVar3 = iVar3 + 1;
    } while (iVar3 <= *(int *)(DAT_121b243c + 0x90));
  }
  
  // Secondary collision check via FUN_11510fe0
  for (piVar1 = (int *)FUN_11510fe0(0,iVar4,*(undefined4 *)(*(int *)(this + 8) + 0x1e8));
      piVar1 != (int *)0x0;
      piVar1 = (int *)FUN_11510fe0(piVar1,iVar4,*(undefined4 *)(*(int *)(this + 8) + 0x1e8))) {
    iVar3 = FUN_1150e440(piVar1);
    if (((iVar3 == 0) && 
         (iVar3 = (**(code **)(*piVar1 + 0x30))(), iVar3 == 0x2d)) &&
        (iVar3 = (**(code **)(*piVar1 + 0xa8))(), iVar3 != 0)) {
      FUN_1152d9c0(piVar1,iVar4,*(undefined4 *)(*(int *)(this + 8) + 0x178),
                   *(undefined4 *)(*(int *)(this + 8) + 0x1e8));
    }
  }
  FUN_115142c0(*(int *)(this + 8) + 8,8,0x3f800000,0x3f800000);
  return;
}
```

### ThrowingKnifeEntity::FlyingTouch (115210f0)
```c
void __thiscall ThrowingKnifeEntity::FlyingTouch(ThrowingKnifeEntity *this, CBaseEntity *param_1)
{
  // Complex knife-voxel collision with velocity-based response
  // Uses entity vftable at +0x30, +0x38, +0xac, +0xbc for checks
  // Handles knockback and stuck-in-wall detection
  
  // Key offsets in entity:
  // +0x238 = CVoxelWorld pointer
  // +0x1bc = some ID field
  // +0x178 = velocity
  // +0x1e8 = position
  // +0x20, +0x24, +0x28 = velocity components
}
```

---

## Entity Vftable Structure

### Monster Entity Class Hierarchy
```
CBaseEntity (base)
  └── CBaseMonster (base AI)
        └── VoxelMonster (voxel AI base)
              ├── VoxelMonster_Zombie
              ├── VoxelMonster_Boomer  
              ├── VoxelMonster_Ghost
              ├── VoxelMonster_Boss
              │     ├── VoxelMonster_Boss_AmpSuit
              │     │     ├── VoxelMonster_Boss_AmpSuit::FlameThrower
              │     │     └── VoxelMonster_Boss_AmpSuit::Laser
              │     └── VoxelMonster_Boss_Protophobos
              └── ... (20+ monster types)
```

### Key Entity Fields (from monster factory)
| Offset | Type | Purpose |
|--------|------|---------|
| 0x00 | vftable* | Virtual function table |
| 0x08 | Entity* | Owner entity |
| 0x2c | int | Initialization flag |
| 0x80 | int | Voxel entity check |
| 0xb8 | vftable* | CVoxelSpawn vftable |
| 0x238 | CVoxelWorld* | Parent voxel world |
| 0x314 | vftable* | Monster AI vftable |
| 0x318 | float | Scale (1.0f default) |
| 0x334 | float | Various monster params |
| 0x340 | word | spawnflags |
| 0x344 | word | Entity type ID |
| 0x348 | int | Monster ID |

---

## BSP Integration

### Map Entity Classname
- `"classname" "voxelspawn"` - Voxel spawn entity in BSP maps

### Spawn Process
1. Engine parses BSP map file, finds `voxelspawn` entities
2. Calls `voxelspawn()` factory function
3. Factory allocates VoxelMonster via `FUN_10a8b730()`
4. Monster type determined by keyvalues on entity
5. Monster vftable set for AI behavior

---

## Additional Voxel Entity Factory Functions

### voxel_monster_boss_infectedtitan (10a9b8f0)
```c
void voxel_monster_boss_infectedtitan(uint param_1)
{
  // Allocates 0xe50 bytes for boss entity
  // Uses FUN_10a99930 for initialization
  
  iVar2 = (*DAT_121b21f8)(iVar2, 0xe50);
  // Initializes with VoxelMonster_Boss_InfectedTitan vftable
  // Has CondFuncManager at 0x388 for AI behavior
}
```

### VoxelMonster_Boss_InfectedTitan Init (FUN_10a99930)
```c
// Boss-specific initialization with AI behavior trees
param_1[0x380] = VoxelMonster_Boss::vftable;
param_1[0x381] = pvVar2;  // Behavior node 1
param_1[0x388] = CondFuncManager::vftable;
param_1[0x38a] = pvVar2;  // Behavior node 2
param_1[0x38c] = pvVar2;  // Behavior node 3
```

### voxel_monster_boss_protophobos (10a9cd50)
```c
void voxel_monster_boss_protophobos(uint param_1)
{
  // Allocates 0xe18 bytes
  // Initializes VoxelMonster_Boss_ProtoPhobos vftable
  // Has behavior nodes at 0x37f
  puVar3[899] = 0;
  puVar3[900] = 7;  // Some ID/count
}
```

### voxel_monster_turret (10aa39d0)
```c
void voxel_monster_turret(uint param_1)
{
  // Allocates 0xda0 bytes (same as zombie)
  *puVar3 = VoxelMonster_Turret::vftable;
  puVar3[0x314] = VoxelMonster_Turret::vftable;
}
```

### voxelShEntInWarehouse (10a88700)
```c
void voxelShEntInWarehouse(uint param_1)
{
  // Allocates 0xb0 bytes (smaller than monster)
  *puVar3 = CVoxelShEnt_InWarehouse::vftable;
  puVar3[2] = param_1;  // Owner
}
```

### voxelShEntSpiderMine (10a88770)
```c
void voxelShEntSpiderMine(uint param_1)
{
  // Allocates 0xd0 bytes
  *puVar3 = CVoxelShEnt_SpiderMine::vftable;
  puVar3[0x2c] = 0;  // State field
  puVar3[0x2d] = 0;  // State field
  puVar3[0x30] = 0;  // State field
  puVar3[0x31] = 0;  // State field
  puVar3[0x32] = 0;  // State field
}
```

### voxelitembox (10a79bf0)
```c
void voxelitembox(uint param_1)
{
  // Allocates 0xb0 bytes
  *puVar3 = CVoxelItemBox::vftable;
  puVar3[2] = param_1;  // Owner
}
```

---

## Monster Entity Size Allocations

Different monster types allocate different amounts of memory:

| Monster Type | Allocation Size | Notes |
|-------------|-----------------|-------|
| voxel_monster (base) | 0xda0 | Standard monster |
| voxel_monster_zombie | 0xda0 | Standard |
| voxel_monster_boomer | 0xda0 | Standard |
| voxel_monster_ghost | 0xda8 | Slightly larger |
| voxel_monster_boss_ampsuit | 0xe60 | Larger for boss |
| voxel_monster_boss_infectedtitan | 0xe50 | Boss size |
| voxel_monster_boss_protophobos | 0xe18 | Boss size |
| voxelspawn | 0xb8 | Spawn point only |
| voxelShEnt* | 0xb0-0xd0 | Shared entities |
| voxelitembox | 0xb0 | Item box |

---

## Monster AI Behavior System

The VoxelMonster uses a behavior tree system with:
- CondFuncManager at 0x388 for conditional behaviors
- Multiple behavior nodes (0x38a, 0x38c, etc.) for different AI states
- Boss monsters have more behavior nodes for complex AI

### Behavior Components
- `param_1[0x381]` = Primary behavior node
- `param_1[0x38a]` = Secondary behavior node  
- `param_1[0x38b]` = CondFuncManager
- `param_1[0x38c]` = Tertiary behavior node

---

## Monster AI Think State Machine

The VoxelMonster uses GoldSrc's think system:

### Think Function Fields
| Offset | Type | Purpose |
|--------|------|---------|
| 0x349 | m_pfnThink* | Think function pointer |
| 0x34a | int | Think next goal position time |
| nextthink | float | Next think time (scheduled) |

### Think Strings (from mp.dll)
- `"m_pfnThink"` - Think function pointer field name
- `"nextthink"` - Next think time field name
- `"Dormant entity %s is trying to think (ignoring think)!!"` - Dormant check
- `"Gibbed monster is thinking!"` - Gib state handling

### Think Function Types (RTTI)
```
?AIThink@ZBZZombieDog@@QAEXXZ
?AIThink@ZombiDog@ZombiAbility@Zombi5@@QAEXXZ
?AnimationThink@CNukeBomb@LightZombieState@@QAEXXZ
```

### Think State Flow
1. Entity becomes dormant when `m_fThinkNextGoalPosTime` is set
2. Think function called via vftable at think time
3. AI state machine updates behavior tree
4. Next think time scheduled based on AI state

### CBaseMonster Think Handler (FUN_10a8b730 context)
```c
// Think function pointer at offset 0x349
param_1[0x34a] = 0;  // Think goal position time
param_1[0x34b] = 0;
param_1[0x34c] = 0;
param_1[0x34d] = 0;
// Behavior tree nodes at 0x34e+
```

### Think-Related Think Functions (from strings)
- `Action_Think` - Action state think
- `CVoxelPartnerBlock::BlockThink` - Voxel partner block think
- Various monster-specific thinks in Zombie, Boss classes