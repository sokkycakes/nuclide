# CSO Non-Voxel Monster Code (mp.dll)

## Monster Entity Factory Functions

### CApache (monster_apache)
```
monster_apache @ 113d8630
Size: 0xcf8 bytes
```
```c
void monster_apache(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xcf8), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_108ec670();
    *puVar3 = CApache::vftable;
    puVar3[2] = param_1;
    puVar3[0x316] = 0;
    puVar3[0x317] = 0;
    puVar3[0x318] = 0;
    puVar3[0x319] = 0;
    puVar3[0x31a] = 0;
    puVar3[0x31b] = 0;
    puVar3[0x31c] = 0;
    puVar3[0x31d] = 0;
    puVar3[0x31e] = 0;
    puVar3[799] = 0;
    puVar3[800] = 0;
    puVar3[0x321] = 0;
    puVar3[0x33a] = 0;
    puVar3[0x33b] = 0;
    puVar3[0x33c] = 0;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### CMonster (monster_entity)
```
monster_entity @ 1136b330
Size: 0x13b0 bytes
```
```c
void monster_entity(uint param_1) {
  undefined8 uVar1;
  uint uVar2;
  int iVar3;
  undefined4 *puVar4;
  if (param_1 == 0) {
    iVar3 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar3 != 0) & iVar3 + 0x84U;
  }
  iVar3 = *(int *)(param_1 + 0x238);
  if (((iVar3 == 0) || (uVar2 = _DAT_00000008, *(int *)(iVar3 + 0x80) == 0)) &&
     (puVar4 = (undefined4 *)(*DAT_121b21f8)(iVar3,0x13b0), uVar2 = param_1,
     puVar4 != (undefined4 *)0x0)) {
    FUN_107f1de0();
    *puVar4 = CMonster::vftable;
    puVar4[0x4c7] = 0;
    puVar4[0x4de] = 0;
    puVar4[0x4df] = 0;
    puVar4[0x4e0] = 0;
    puVar4[0x4e1] = 0;
    puVar4[0x4cb] = 0;
    uVar1 = DAT_117574d0;
    puVar4[0x4cc] = 0;
    puVar4[0x4cd] = 0;
    puVar4[0x4d3] = 0;
    puVar4[0x4d4] = 0;
    puVar4[0x4d5] = 0;
    puVar4[0x4d6] = 0;
    puVar4[0x4d7] = 0;
    puVar4[0x4d8] = 0;
    *(undefined8 *)(puVar4 + 0x4e2) = uVar1;
    FUN_10896de0();
    puVar4[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar2;
  return;
}
```

### CFlockingFlyer (monster_flyer)
```
monster_flyer @ 113cf150
Size: 0xca0 bytes
```
```c
undefined4 * monster_flyer(uint param_1) {
  undefined4 *puVar1;
  int iVar2;
  undefined4 *puVar3;
  undefined4 *puVar4;
  void *pvStack_10;
  undefined1 *puStack_c;
  undefined4 uStack_8;
  uStack_8 = 0xffffffff;
  puStack_c = &LAB_1158976c;
  pvStack_10 = ExceptionList;
  ExceptionList = &pvStack_10;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)(DAT_11d38180 ^ (uint)&stack0xfffffffc);
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if ((iVar2 == 0) || (puVar3 = *(undefined4 **)(iVar2 + 0x80), puVar3 == (undefined4 *)0x0)) {
    puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xca0);
    uStack_8 = 0;
    if (puVar3 == (undefined4 *)0x0) {
      puVar3 = (undefined4 *)0x0;
    }
    else {
      FUN_10652d20();
      // ... initialization of CBaseMonster fields ...
      *puVar3 = CBaseMonster::vftable;
      // ... more initialization ...
      *puVar3 = CFlockingFlyer::vftable;
      puVar3[0x319] = 0;
      puVar3[0x31a] = 0;
      puVar3[0x31b] = 0;
      puVar3[0x31c] = 0;
      puVar3[0x31d] = 0;
      puVar3[0x31e] = 0;
    }
    puVar3[2] = param_1;
  }
  ExceptionList = pvStack_10;
  return puVar3;
}
```

### CGoliath (monster_goliath)
```
monster_goliath @ 11347670
Size: 0xcd0 bytes
```
```c
void monster_goliath(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xcd0), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_108ec670();
    *puVar3 = CGoliath::vftable;
    puVar3[0x317] = 0;
    puVar3[0x1b] = 1;
    puVar3[0x31a] = 0xffffffff;
    puVar3[2] = param_1;
    puVar3[0x32a] = 0;
    puVar3[0x32b] = 0;
    puVar3[0x32c] = 0;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### CDeadHEV (monster_hevsuit_dead)
```
monster_hevsuit_dead @ 114e91e0
Size: 0xc58 bytes
```
```c
void monster_hevsuit_dead(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xc58), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_108ec670();
    *puVar3 = CDeadHEV::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### CMortar (monster_mortar)
```
monster_mortar @ 11490220
Size: 0xce8 bytes
```
```c
undefined4 * monster_mortar(uint param_1) {
  undefined4 *puVar1;
  int iVar2;
  undefined4 *puVar3;
  undefined4 *puVar4;
  void *pvStack_10;
  undefined1 *puStack_c;
  undefined4 uStack_8;
  uStack_8 = 0xffffffff;
  puStack_c = &LAB_1158976c;
  pvStack_10 = ExceptionList;
  ExceptionList = &pvStack_10;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)(DAT_11d38180 ^ (uint)&stack0xfffffffc);
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if ((iVar2 == 0) || (puVar3 = *(undefined4 **)(iVar2 + 0x80), puVar3 == (undefined4 *)0x0)) {
    puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xce8);
    uStack_8 = 0;
    if (puVar3 == (undefined4 *)0x0) {
      puVar3 = (undefined4 *)0x0;
    }
    else {
      FUN_10881390();
      *puVar3 = CBaseMonster::vftable;
      // ... initialization ...
      *puVar3 = CMortar::vftable;
      puVar3[0x315] = 0;
      puVar3[0x316] = 0;
      puVar3[0x318] = 0;
      puVar3[0x319] = 0;
      puVar3[0x329] = 0;
      puVar3[0x32a] = 0;
      puVar3[0x32b] = 0;
      puVar3[0x332] = 0;
      puVar3[0x333] = 0;
      puVar3[0x334] = 0;
      puVar3[0x335] = 0;
      *(undefined1 *)(puVar3 + 0x336) = 0;
    }
    puVar3[2] = param_1;
  }
  ExceptionList = pvStack_10;
  return puVar3;
}
```

---

## Zombie Variants

### ZombiDog (zombi_dog)
```
zombi_dog @ 107fb310
Size: 0x12d8 bytes
```
```c
void zombi_dog(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x12d8), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_107f1de0();
    *puVar3 = Zombi5::ZombiAbility::ZombiDog::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### ZombiDogEgg (zombi_dog_egg)
```
zombi_dog_egg @ 107fb380
Size: 0xb8 bytes
```
```c
void zombi_dog_egg(uint param_1) {
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
    *puVar3 = Zombi5::ZombiAbility::ZombiDogEgg::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### ZBZZombieDog (zbz_zombiedog)
```
zbz_zombiedog @ 108ed2b0
Size: 0x12f0 bytes
```
```c
void zbz_zombiedog(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  undefined4 *puVar4;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x12f0), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_108ec670();
    puVar3[0x31e] = 0;
    puVar3[799] = 0;
    iVar2 = 0x14;
    puVar3[800] = 0;
    puVar3[0x321] = 0;
    // ... 20+ fields initialized ...
    *puVar3 = ZBZZombieDog::vftable;
    puVar3[0x4b6] = 0;
    *(undefined1 *)(puVar3 + 0x4b7) = 0;
    puVar3[0x4b8] = 0;
    puVar3[0x4b9] = 0;
    puVar3[0x4ba] = 0;
    puVar3[0x4bb] = 0;
    puVar3[2] = param_1;
    puVar3[0x49f] = 0;
    puVar3[0x4a0] = 0;
    puVar3[0x4a1] = 0;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

---

## Monster Spawn Entities

### CPlayroomMonSpawnPoint (monster_spawn_point)
```
monster_spawn_point @ 10830e40
Size: 0xb8 bytes
```
```c
void monster_spawn_point(uint param_1) {
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
    *puVar3 = CPlayroomMonSpawnPoint::vftable;
    *(undefined1 *)(puVar3 + 0x2c) = 0;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### CGasTurretSpawn (gasturret_spawn)
```
gasturret_spawn @ 1092de60
Size: 0xd8 bytes
```
```c
void gasturret_spawn(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xd8), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10652d20();
    *puVar3 = CGasTurretSpawn::vftable;
    puVar3[0x2c] = 0;
    puVar3[0x2d] = 1;
    puVar3[0x2e] = 0x3f800000;
    puVar3[0x2f] = 0xbf800000;
    puVar3[0x30] = 0x447a0000;
    puVar3[0x31] = 0x41200000;
    puVar3[0x32] = 0x3dcccccd;
    puVar3[0x33] = 0x3f800000;
    puVar3[0x34] = 0x40d00000;
    puVar3[0x35] = 0x43fa0000;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### CVoxelSpawn (voxelspawn)
```
voxelspawn @ 10a79c60
Size: 0xb8 bytes
```
```c
void voxelspawn(uint param_1) {
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

### CZombiSpawn (zombiespawn)
```
zombiespawn @ 11374ac0
Size: 0xb8 bytes
```
```c
void zombiespawn(uint param_1) {
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
    *puVar3 = CZombiSpawn::vftable;
    puVar3[0x2d] = 0;
    puVar3[0x1b] = 3;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

---

## Monster Base Constructors

### FUN_108ec670 - CBaseMonster Constructor (Apache/Goliath Base)
```c
undefined4 * __fastcall FUN_108ec670(undefined4 *param_1) {
  undefined4 *puVar1;
  undefined4 *puVar2;
  void *local_10;
  undefined1 *puStack_c;
  undefined4 local_8;
  local_8 = 0xffffffff;
  puStack_c = &LAB_1158ab4b;
  local_10 = ExceptionList;
  ExceptionList = &local_10;
  FUN_10658080(DAT_11d38180 ^ (uint)&stack0xfffffffc);
  param_1[0x3b] = 0;
  // ... field initialization 0x3b through 0x51 ...
  *param_1 = CBaseMonster::vftable;
  puVar1 = param_1 + 0x79;
  // ... field initialization 0x5e through 0x74 ...
  local_8 = 0;
  *puVar1 = 0;
  // ... field initialization 0x7a through 0x7d ...
  puVar2 = operator_new(8);
  puVar2[1] = 0;
  *puVar1 = puVar2;
  *puVar2 = puVar1;
  local_8 = CONCAT31(local_8._1_3_,1);
  *(undefined1 *)(param_1 + 0x7e) = 0;
  _eh_vector_constructor_iterator_
            (param_1 + 0x80,0x50,0x21,FUN_113f4fe0,(_func_void_void_ptr *)&LAB_1065e2d0);
  ExceptionList = local_10;
  return param_1;
}
```

### FUN_107f1de0 - CHostage/CMonster Base Constructor
```c
undefined4 * __fastcall FUN_107f1de0(undefined4 *param_1) {
  undefined4 *puVar1;
  undefined4 *puVar2;
  int iVar3;
  void *local_10;
  undefined1 *puStack_c;
  undefined4 local_8;
  local_8 = 0xffffffff;
  puStack_c = &LAB_115a7cb3;
  local_10 = ExceptionList;
  ExceptionList = &local_10;
  FUN_10652d20(DAT_11d38180 ^ (uint)&stack0xfffffffc);
  // ... field initialization 0x3b through 0x7e (same as CBaseMonster) ...
  *param_1 = CBaseMonster::vftable;
  // ... field initialization ...
  *param_1 = CHostage::vftable;
  param_1[0x31e] = 0;
  iVar3 = 0x14;
  param_1[799] = 0;
  param_1[800] = 0;
  param_1[0x321] = 0;
  // ... 20+ fields ... (0x32b through 0x497)
  param_1[0x497] = 0;
  param_1[0x498] = 0;
  param_1[0x49f] = 0;
  param_1[0x4a0] = 0;
  param_1[0x4a1] = 0;
  ExceptionList = local_10;
  return param_1;
}
```

---

## Monster AI Think Functions

### AIThink (ZombiDog)
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
```c
void __thiscall Zombi5::ZombiAbility::RushBox::AirborneThink(RushBox *this) {
  FUN_107f2810();
  FUN_11513b70(this);
  return;
}
```

### ThinkDie (VoxelMonster_A104RL_Gun)
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

### WaitThink (TowerBossDummyXT300)
```c
void __thiscall TowerBossDummyXT300::WaitThink(TowerBossDummyXT300 *this) {
  // Complex movement AI - handles flying, pathfinding, velocity
  // Updates entity position based on target waypoint
  // Calculates distance and speed for movement
}
```

### FollowThink (Multiple implementations)
```c
void __thiscall FollowThink(...) {
  // Multiple FollowThink implementations for different entity types:
  // - 10664000, 1090deb0, 10927530, 10948720, 10949f00
  // - 109813a0, 10981710, 10981a80, 109b1390, 109d72f0
  // - 109d7430, 10b994d0, 10bc2cc0, 10ced3e0, 10e541e0
  // - 10fef820, 11011430, 110266d0, 11049060, 1106f030
  // - 1113cdd0, 111b3c50, 111dd140, 111eaa40
}
```

---

## Monster Damage/Death Functions

### CDeimosTail::TailTouch
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
```c
void __thiscall CKillTimer::KillThink(CKillTimer *this) {
  // Timer-based kill trigger
  // Uses functor to execute kill logic
}
```

### CCustomTurret::KillThinkFunc
```c
void __thiscall CCustomTurret::KillThinkFunc(CCustomTurret *this) {
  // Custom turret death handler
  (**(code **)(*(int *)this + 0x224))();
}
```

---

## Monster Entity Summary

| Monster Type | Address | Size | Base Class | Notes |
|-------------|---------|------|------------|-------|
| monster_apache | 113d8630 | 0xcf8 | CApache | Flying assault helicopter |
| monster_entity | 1136b330 | 0x13b0 | CMonster | Generic monster |
| monster_flyer | 113cf150 | 0xca0 | CFlockingFlyer | Flocking flyer |
| monster_goliath | 11347670 | 0xcd0 | CGoliath | Large brute |
| monster_hevsuit_dead | 114e91e0 | 0xc58 | CDeadHEV | Dead HEV suit |
| monster_mortar | 11490220 | 0xce8 | CMortar | Mortar turret |
| zombi_dog | 107fb310 | 0x12d8 | ZombiDog | Zombie dog |
| zombi_dog_egg | 107fb380 | 0xb8 | ZombiDogEgg | Zombie dog egg |
| zbz_zombiedog | 108ed2b0 | 0x12f0 | ZBZZombieDog | Boss zombie dog |

### Spawn Point Types

| Spawn Type | Address | Size | Notes |
|-----------|---------|------|-------|
| monster_spawn_point | 10830e40 | 0xb8 | Generic monster spawn |
| gasturret_spawn | 1092de60 | 0xd8 | Gas turret spawn |
| voxelspawn | 10a79c60 | 0xb8 | Voxel spawn point |
| zombiespawn | 11374ac0 | 0xb8 | Zombie spawn point |

---

## Entity Hierarchy

```
CBaseEntity
  └── CBaseAnimating
        └── CBaseToggle
              └── CBaseMonster
                    ├── CApache (monster_apache)
                    ├── CGoliath (monster_goliath)
                    ├── CDeadHEV (monster_hevsuit_dead)
                    ├── CMortar (monster_mortar)
                    ├── CFlockingFlyer (monster_flyer)
                    └── CHostage/CMonster (monster_entity)
                          └── ZombiDog (zombi_dog)
                          └── ZBZZombieDog (zbz_zombiedog)

CBaseEntity (spawn only)
  └── CBaseTrigger
        └── CPlayroomMonSpawnPoint (monster_spawn_point)
        └── CGasTurretSpawn (gasturret_spawn)
        └── CVoxelSpawn (voxelspawn)
        └── CZombiSpawn (zombiespawn)
```