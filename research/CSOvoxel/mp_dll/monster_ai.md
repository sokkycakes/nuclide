# CSO Monster AI Code (mp.dll)

## Overview

All AI logic for CSO monsters lives in mp.dll. The DLL exposes factory functions (constructors) for monsters, plus standalone think functions that drive behavior.

---

## Think Function Exports

### AIThink (ZombiDog)
```
AIThink @ 107a59a0
```
```c
void __thiscall Zombi5::ZombiAbility::ZombiDog::AIThink(ZombiDog *this) {
  float fVar1;
  undefined4 uVar2;
  int *piVar3;
  int iVar4;
  float10 fVar5;
  uVar2 = (*DAT_121b2218)(*(undefined4 *)(*(int *)(this + 8) + 0x1bc));
  piVar3 = (int *)FUN_115126a0(uVar2);
  iVar4 = FUN_1150e440(piVar3);
  if ((((iVar4 != 0) || (iVar4 = (**(code **)(*piVar3 + 0xa8))(), iVar4 == 0)) ||
      (*(char *)((int)piVar3 + 0x2166) == '\0')) ||
     ((*(char *)((int)piVar3 + 0x218e) != '\x12' ||
      (fVar1 = *DAT_121b243c,
      *(float *)(this + 0x12a4) <= fVar1 && fVar1 != *(float *)(this + 0x12a4))))) {
    (**(code **)(*(int *)this + 0x54))(0,1);
    return;
  }
  *(float *)(*(int *)(this + 8) + 0x114) = fVar1 + DAT_11784974;
  fVar5 = (float10)FUN_113d0420(0);
  FUN_113cfa60((float)fVar5);
  if (*(int **)(this + 0x1294) != (int *)0x0) {
    (**(code **)(**(int **)(this + 0x1294) + 0xd4))(0x3d088889);
  }
  if (*DAT_121b243c < *(float *)(this + 0x1264)) {
    return;
  }
  *(float *)(this + 0x1264) = *DAT_121b243c + DAT_11759918;
  if (*(int **)(this + 0x1294) == (int *)0x0) {
    return;
  }
  (**(code **)(**(int **)(this + 0x1294) + 0xd0))(0x3dcccccd);
  return;
}
```

### AirborneThink (RushBox)
```
AirborneThink @ 107a5b30
```
```c
void __thiscall Zombi5::ZombiAbility::RushBox::AirborneThink(RushBox *this) {
  FUN_107f2810();
  FUN_11513b70(this);
  return;
}
```

### WaitThink (TowerBossDummyXT300)
```
WaitThink @ 107c66b0
```
```c
void __thiscall TowerBossDummyXT300::WaitThink(TowerBossDummyXT300 *this) {
  float fVar1;
  float fVar2;
  undefined4 *puVar3;
  int iVar4;
  int *piVar5;
  int iVar6;
  float fVar7;
  float fVar8;
  float fVar9;
  float fVar10;
  float fVar11;
  float fVar12;
  float fVar13;
  float fVar14;
  float fVar15;
  undefined4 uVar16;
  undefined4 uVar17;
  undefined4 uVar18;
  int local_4; // ... complex movement AI with pathfinding and velocity
}
```

### FollowThink (Multiple Implementations)
```
FollowThink implementations:
  10664000
  1090deb0
  10927530
  10948720
  10949f00
  109813a0
  10981710
  10981a80
  109b1390
  109d72f0
  109d7430
  10b994d0
  10bc2cc0
  10ced3e0
  10e541e0
  10fef820
  11011430
  110266d0
  11049060
  1106f030
  1113cdd0
  111b3c50
  111dd140
  111eaa40
```
```c
void __thiscall FollowThink(...) {
  // Multiple FollowThink implementations for different entity types
  // Each handles: target tracking, movement toward target, speed modulation
}
```

### ThinkDie (VoxelMonster_A104RL_Gun)
```
ThinkDie @ 10b59d30
```
```c
void __thiscall VoxelMonster_A104RL_Gun::ThinkDie(VoxelMonster_A104RL_Gun *this) {
  int *piVar1;
  int iVar2;
  VoxelMonster_A104RL_Gun *pVVar3;
  pVVar3 = this;
  FUN_1152d8f0();
  *(undefined4 *)(this + 0x4c) = 0;
  *(undefined4 *)(this + 0xc68) = 0;
  piVar1 = *(int **)(this + 0xc64);
  *(undefined4 *)(this + 0xc60) = 0;
  *(undefined4 *)(this + 0xc64) = 0;
  if (piVar1 != (int *)0x0) {
    LOCK();
    iVar2 = piVar1[2] + -1;
    piVar1[2] = iVar2;
    UNLOCK();
    if (iVar2 == 0) {
      (**(code **)(*piVar1 + 4))(pVVar3);
    }
  }
  return;
}
```

---

## Damage/Death Handlers

### CDeimosTail::TailTouch
```
TailTouch @ 107c98b0
```
```c
void __thiscall CDeimosTail::TailTouch(CDeimosTail *this, CBaseEntity *param_1) {
  // Tail attack touch handler
  // Checks if target is valid
  // Deals damage and triggers poison effect
  // Plays hit sound
  // Calls Kill() on the tail after successful hit
}
```

### CKillTimer::KillThink
```
KillThink @ 108a63a0
```
```c
void __thiscall CKillTimer::KillThink(CKillTimer *this) {
  // Timer-based kill trigger
  // Uses functor to execute kill logic
}
```

### CCustomTurret::KillThinkFunc
```
KillThinkFunc @ 1099f090
```
```c
void __thiscall CCustomTurret::KillThinkFunc(CCustomTurret *this) {
  // Custom turret death handler
  (**(code **)(*(int *)this + 0x224))();
}
```

---

## AI Helper Functions

### FUN_107f2810 - Movement Init
```c
// Initializes movement state for airborne entities
void FUN_107f2810(void);
```

### FUN_11513b70 - Physics Update
```c
// Updates physics state for RushBox airborne movement
void __thiscall FUN_11513b70(RushBox *this);
```

### FUN_115126a0 - AI State Lookup
```c
// Returns AI state pointer for ZombiDog
int * __thiscall FUN_115126a0(int *param_1);
```

### FUN_1150e440 - State Validation
```c
// Validates AI state is active
int FUN_1150e440(int *piVar1);
```

### FUN_113d0420 - Random Timer
```c
// Returns random float for attack timing
float10 FUN_113d0420(int param_1);
```

### FUN_113cfa60 - Attack Trigger
```c
// Triggers damage effect with given damage value
void FUN_113cfa60(float param_1);
```

### FUN_1152d8f0 - Death Cleanup
```c
// Cleanup function called on entity death
void FUN_1152d8f0(void);
```

---

## Think Function Summary

| Function | Address | Entity Type | Purpose |
|----------|---------|-------------|---------|
| AIThink | 107a59a0 | ZombiDog | Main AI loop, attack timing, damage triggers |
| AirborneThink | 107a5b30 | RushBox | Airborne physics/movement |
| WaitThink | 107c66b0 | TowerBossDummyXT300 | Movement with pathfinding |
| ThinkDie | 10b59d30 | VoxelMonster_A104RL_Gun | Death handling, spawner decref |
| FollowThink | 10664000+ | Multiple | Target tracking and approach |
| TailTouch | 107c98b0 | CDeimosTail | Melee attack touch handler |
| KillThink | 108a63a0 | CKillTimer | Timer-based kill |
| KillThinkFunc | 1099f090 | CCustomTurret | Turret death handler |

---

## Entity Hierarchy (AI Context)

```
CBaseEntity
  └── CBaseAnimating
        └── CBaseMonster
              ├── VoxelMonster
              │     ├── VoxelMonster_A104RL_Gun (ThinkDie)
              │     └── [other voxel types]
              ├── ZombiDog (AIThink)
              ├── Zombi5::ZombiAbility::RushBox (AirborneThink)
              ├── TowerBossDummyXT300 (WaitThink)
              ├── CDeimosTail (TailTouch)
              ├── CKillTimer (KillThink)
              └── CCustomTurret (KillThinkFunc)
```

---

## Key Field Offsets (AI State)

### ZombiDog (0x12d8 monster)
```
0x1264: Next attack time
0x1294: Damage functor pointer
0x12a4: Health value
```

### VoxelMonster_A104RL_Gun
```
0x4c:   Think function pointer
0xc60:  Spawner reference
0xc64:  Spawner pointer
0xc68:  Unknown
```

(End of file - total lines)