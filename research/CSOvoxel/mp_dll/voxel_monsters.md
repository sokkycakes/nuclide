# CSO Voxel Monster Code (mp.dll)

## Monster Factory Functions (Constructor Exports)

### Base VoxelMonster
```
voxel_monster @ 10a939f0
```
```c
void voxel_monster(uint param_1) {
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

### VoxelMonster_Zombie
```
voxel_monster_zombie @ aa52a0
```
```c
void voxel_monster_zombie(uint param_1) {
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

### VoxelMonster_Boomer
```
voxel_monster_boomer @ aa51c0
```
```c
void voxel_monster_boomer(uint param_1) {
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

### VoxelMonster_Boss_InfectedTitan
```
voxel_monster_boss_infectedtitan @ a9b8f0
```
```c
void voxel_monster_boss_infectedtitan(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0xe50), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10a99930();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_Boss_ProtoPhobos
```
voxel_monster_boss_protophobos @ a9cd50
```
```c
void voxel_monster_boss_protophobos(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  void *pvVar4;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xe18), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10a8b730();
    *puVar3 = VoxelMonster_Boss::vftable;
    puVar3[0x314] = VoxelMonster_Boss::vftable;
    FUN_1094bf70();
    puVar3[0x375] = 0;
    puVar3[0x376] = 0;
    puVar3[0x377] = 0;
    *puVar3 = VoxelMonster_Boss_ProtoPhobos::vftable;
    puVar3[0x314] = VoxelMonster_Boss_ProtoPhobos::vftable;
    puVar3[0x37e] = 0;
    puVar3[0x37f] = 0;
    puVar3[0x380] = 0;
    pvVar4 = operator_new(0xc);
    *(void **)pvVar4 = pvVar4;
    *(void **)((int)pvVar4 + 4) = pvVar4;
    puVar3[0x37f] = pvVar4;
    puVar3[0x381] = 0;
    puVar3[0x382] = 0;
    puVar3[899] = 0;
    puVar3[900] = 7;
    puVar3[0x385] = 8;
    puVar3[0x37e] = 0x3f800000;
    FUN_10641b40(0x10,puVar3[0x37f]);
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_Minion
```
voxel_monster_minion @ aa0640
```
```c
void voxel_monster_minion(uint param_1) {
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
    *puVar3 = VoxelMonster_Minion::vftable;
    puVar3[0x314] = VoxelMonster_Minion::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_Hooligan1
```
voxel_monster_hooligan1 @ a9f7a0
```
```c
void voxel_monster_hooligan1(uint param_1) {
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
    *puVar3 = VoxelMonster_Hooligan1::vftable;
    puVar3[0x314] = VoxelMonster_Hooligan1::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_Hooligan2
```
voxel_monster_hooligan2 @ a9f810
```
```c
void voxel_monster_hooligan2(uint param_1) {
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
    *puVar3 = VoxelMonster_Hooligan2::vftable;
    puVar3[0x314] = VoxelMonster_Hooligan2::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_Boss_AmpSuit
```
voxel_monster_boss_ampsuit @ a99440
```
```c
void voxel_monster_boss_ampsuit(uint param_1) {
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
    puVar3[0x380] = VoxelMonster_Boss_AmpSuit::FlameThrower::vftable;
    puVar3[0x385] = 0x3fc43958;
    puVar3[0x386] = 0x3fb33333;
    puVar3[0x387] = 0x4019999a;
    puVar3[0x388] = 0x4059999a;
    puVar3[0x381] = 0x3fc43958;
    puVar3[0x382] = 0x403bb646;
    puVar3[899] = 0x40aaa7f0;
    puVar3[900] = 0;
    puVar3[0x38e] = 0x3fc43958;
    puVar3[0x38f] = 0x3fb33333;
    puVar3[0x390] = 0x4019999a;
    puVar3[0x391] = 0x4059999a;
    puVar3[0x38a] = 0x3fc43958;
    puVar3[0x38b] = 0x403bb646;
    puVar3[0x38c] = 0x40aaa7f0;
    puVar3[0x38d] = 0;
    puVar3[0x389] = VoxelMonster_Boss_AmpSuit::Laser::vftable;
    puVar3[2] = param_1;
    puVar3[0x393] = 0;
    puVar3[0x394] = 0;
    puVar3[0x395] = 0;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_China
```
voxel_monster_china @ a9d770
```
```c
void voxel_monster_china(uint param_1) {
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
    *puVar3 = VoxelMonster_China::vftable;
    puVar3[0x314] = VoxelMonster_China::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_GasTurret
```
voxel_monster_gasturret @ aa1d30
```
```c
void voxel_monster_gasturret(uint param_1) {
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
    *puVar3 = VoxelMonster_GasTurret::vftable;
    puVar3[0x314] = VoxelMonster_GasTurret::vftable;
    puVar3[0x368] = 0;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_Ghost
```
voxel_monster_ghost @ a9f710
```
```c
void voxel_monster_ghost(uint param_1) {
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

### VoxelMonster_HooliganCan
```
voxel_monster_hooligancan @ a9f880
```
```c
undefined4 * voxel_monster_hooligancan(uint param_1) {
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
    puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xc60);
    uStack_8 = 0;
    if (puVar3 == (undefined4 *)0x0) {
      puVar3 = (undefined4 *)0x0;
    }
    else {
      FUN_10658080();
      puVar3[0x3b] = 0;
      puVar3[0x3c] = 0;
      puVar3[0x3d] = 0;
      puVar3[0x3e] = 0;
      puVar3[0x3f] = 0;
      puVar3[0x40] = 0;
      puVar3[0x41] = 0;
      puVar3[0x42] = 0;
      puVar3[0x43] = 0;
      puVar3[0x44] = 0;
      puVar3[0x45] = 0;
      puVar3[0x46] = 0;
      puVar3[0x49] = 0;
      puVar3[0x4a] = 0;
      puVar3[0x4c] = 0;
      puVar3[0x4d] = 0;
      puVar3[0x4e] = 0;
      puVar3[0x4f] = 0;
      puVar3[0x50] = 0;
      puVar3[0x51] = 0;
      *puVar3 = CBaseMonster::vftable;
      puVar1 = puVar3 + 0x79;
      puVar3[0x5e] = 0;
      puVar3[0x5f] = 0;
      puVar3[0x60] = 0;
      puVar3[0x61] = 0;
      puVar3[100] = 0;
      puVar3[0x65] = 0;
      puVar3[0x66] = 0;
      puVar3[0x67] = 0;
      puVar3[0x68] = 0;
      puVar3[0x69] = 0;
      puVar3[0x6b] = 0;
      puVar3[0x6c] = 0;
      puVar3[0x72] = 0;
      puVar3[0x73] = 0;
      puVar3[0x74] = 0;
      uStack_8._0_1_ = 1;
      *puVar1 = 0;
      puVar3[0x7a] = 0;
      puVar3[0x7b] = 0;
      puVar3[0x7c] = 0;
      puVar3[0x7d] = 0;
      puVar4 = operator_new(8);
      puVar4[1] = 0;
      *puVar1 = puVar4;
      *puVar4 = puVar1;
      uStack_8 = CONCAT31(uStack_8._1_3_,2);
      *(undefined1 *)(puVar3 + 0x7e) = 0;
      _eh_vector_constructor_iterator_
                (puVar3 + 0x80,0x50,0x21,FUN_113f4fe0,(_func_void_void_ptr *)&LAB_1065e2d0);
      *puVar3 = VoxelMonster_HooliganCan::vftable;
    }
    puVar3[2] = param_1;
  }
  ExceptionList = pvStack_10;
  return puVar3;
}
```

### VoxelMonster_Maple
```
voxel_monster_maple @ a9fe00
```
```c
void voxel_monster_maple(uint param_1) {
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
    *puVar3 = VoxelMonster_Maple::vftable;
    puVar3[0x314] = VoxelMonster_Maple::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_ShelterNormal
```
voxel_monster_shelternormal @ aa5230
```
```c
void voxel_monster_shelternormal(uint param_1) {
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
    *puVar3 = VoxelMonster_ShelterNormal::vftable;
    puVar3[0x314] = VoxelMonster_ShelterNormal::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_SHTurret
```
voxel_monster_shturret @ aa1db0
```
```c
void voxel_monster_shturret(uint param_1) {
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
    *puVar3 = VoxelMonster_SHTurret::vftable;
    puVar3[0x314] = VoxelMonster_SHTurret::vftable;
    puVar3[0x368] = 0;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_Snowball
```
voxel_monster_snowball @ aa2db0
```
```c
undefined4 * voxel_monster_snowball(uint param_1) {
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
    puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xc60);
    uStack_8 = 0;
    if (puVar3 == (undefined4 *)0x0) {
      puVar3 = (undefined4 *)0x0;
    }
    else {
      FUN_10658080();
      puVar3[0x3b] = 0;
      puVar3[0x3c] = 0;
      puVar3[0x3d] = 0;
      puVar3[0x3e] = 0;
      puVar3[0x3f] = 0;
      puVar3[0x40] = 0;
      puVar3[0x41] = 0;
      puVar3[0x42] = 0;
      puVar3[0x43] = 0;
      puVar3[0x44] = 0;
      puVar3[0x45] = 0;
      puVar3[0x46] = 0;
      puVar3[0x49] = 0;
      puVar3[0x4a] = 0;
      puVar3[0x4c] = 0;
      puVar3[0x4d] = 0;
      puVar3[0x4e] = 0;
      puVar3[0x4f] = 0;
      puVar3[0x50] = 0;
      puVar3[0x51] = 0;
      *puVar3 = CBaseMonster::vftable;
      puVar1 = puVar3 + 0x79;
      puVar3[0x5e] = 0;
      puVar3[0x5f] = 0;
      puVar3[0x60] = 0;
      puVar3[0x61] = 0;
      puVar3[100] = 0;
      puVar3[0x65] = 0;
      puVar3[0x66] = 0;
      puVar3[0x67] = 0;
      puVar3[0x68] = 0;
      puVar3[0x69] = 0;
      puVar3[0x6b] = 0;
      puVar3[0x6c] = 0;
      puVar3[0x72] = 0;
      puVar3[0x73] = 0;
      puVar3[0x74] = 0;
      uStack_8._0_1_ = 1;
      *puVar1 = 0;
      puVar3[0x7a] = 0;
      puVar3[0x7b] = 0;
      puVar3[0x7c] = 0;
      puVar3[0x7d] = 0;
      puVar4 = operator_new(8);
      puVar4[1] = 0;
      *puVar1 = puVar4;
      *puVar4 = puVar1;
      uStack_8 = CONCAT31(uStack_8._1_3_,2);
      *(undefined1 *)(puVar3 + 0x7e) = 0;
      _eh_vector_constructor_iterator_
                (puVar3 + 0x80,0x50,0x21,FUN_113f4fe0,(_func_void_void_ptr *)&LAB_1065e2d0);
      *puVar3 = VoxelMonster_Snowball::vftable;
    }
    puVar3[2] = param_1;
  }
  ExceptionList = pvStack_10;
  return puVar3;
}
```

### VoxelMonster_Snowman
```
voxel_monster_snowman @ aa2dc0
```
```c
void voxel_monster_snowman(uint param_1) {
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
    *puVar3 = VoxelMonster_Snowman::vftable;
    puVar3[0x314] = VoxelMonster_Snowman::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_Turret
```
voxel_monster_turret @ aa39d0
```
```c
void voxel_monster_turret(uint param_1) {
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
    *puVar3 = VoxelMonster_Turret::vftable;
    puVar3[0x314] = VoxelMonster_Turret::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_A101AR
```
voxel_monster_a101ar @ a95430
```
```c
void voxel_monster_a101ar(uint param_1) {
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
    *puVar3 = VoxelMonster_A101AR::vftable;
    puVar3[0x314] = VoxelMonster_A101AR::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_A104RL
```
voxel_monster_a104rl @ a96d20
```
```c
void voxel_monster_a104rl(uint param_1) {
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
    *puVar3 = VoxelMonster_A104RL::vftable;
    puVar3[0x314] = VoxelMonster_A104RL::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VoxelMonster_A104RL_Gun
```
voxel_monster_a104rl_gun @ a96d90
```
```c
undefined4 * voxel_monster_a104rl_gun(uint param_1) {
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
    puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0xc70);
    uStack_8 = 0;
    if (puVar3 == (undefined4 *)0x0) {
      puVar3 = (undefined4 *)0x0;
    }
    else {
      FUN_10658080();
      puVar3[0x3b] = 0;
      puVar3[0x3c] = 0;
      puVar3[0x3d] = 0;
      puVar3[0x3e] = 0;
      puVar3[0x3f] = 0;
      puVar3[0x40] = 0;
      puVar3[0x41] = 0;
      puVar3[0x42] = 0;
      puVar3[0x43] = 0;
      puVar3[0x44] = 0;
      puVar3[0x45] = 0;
      puVar3[0x46] = 0;
      puVar3[0x49] = 0;
      puVar3[0x4a] = 0;
      puVar3[0x4c] = 0;
      puVar3[0x4d] = 0;
      puVar3[0x4e] = 0;
      puVar3[0x4f] = 0;
      puVar3[0x50] = 0;
      puVar3[0x51] = 0;
      *puVar3 = CBaseMonster::vftable;
      puVar1 = puVar3 + 0x79;
      puVar3[0x5e] = 0;
      puVar3[0x5f] = 0;
      puVar3[0x60] = 0;
      puVar3[0x61] = 0;
      puVar3[100] = 0;
      puVar3[0x65] = 0;
      puVar3[0x66] = 0;
      puVar3[0x67] = 0;
      puVar3[0x68] = 0;
      puVar3[0x69] = 0;
      puVar3[0x6b] = 0;
      puVar3[0x6c] = 0;
      puVar3[0x72] = 0;
      puVar3[0x73] = 0;
      puVar3[0x74] = 0;
      uStack_8._0_1_ = 1;
      *puVar1 = 0;
      puVar3[0x7a] = 0;
      puVar3[0x7b] = 0;
      puVar3[0x7c] = 0;
      puVar3[0x7d] = 0;
      puVar4 = operator_new(8);
      puVar4[1] = 0;
      *puVar1 = puVar4;
      *puVar4 = puVar1;
      uStack_8 = CONCAT31(uStack_8._1_3_,2);
      *(undefined1 *)(puVar3 + 0x7e) = 0;
      _eh_vector_constructor_iterator_
                (puVar3 + 0x80,0x50,0x21,FUN_113f4fe0,(_func_void_void_ptr *)&LAB_1065e2d0);
      *puVar3 = VoxelMonster_A104RL_Gun::vftable;
      puVar3[0x318] = 0;
      puVar3[0x319] = 0;
      puVar3[0x31a] = 0;
      puVar3[0x31b] = 0;
    }
    puVar3[2] = param_1;
  }
  ExceptionList = pvStack_10;
  return puVar3;
}
```

---

## Base Class Constructors

### FUN_10a8b730 - VoxelMonster Base Constructor (0xc50 bytes)
```c
undefined4 * __fastcall FUN_10a8b730(undefined4 *param_1) {
  int *piVar1;
  undefined4 uVar2;
  uint uVar3;
  undefined4 *puVar4;
  void *pvVar5;
  undefined4 *puVar6;
  int iVar7;
  void *local_10;
  undefined1 *puStack_c;
  undefined4 local_8;
  local_8 = 0xffffffff;
  puStack_c = &LAB_115caf77;
  local_10 = ExceptionList;
  uVar3 = DAT_11d38180 ^ (uint)&stack0xfffffffc;
  ExceptionList = &local_10;
  memset(param_1,0,0xc50);
  FUN_10652d20(uVar3);
  param_1[0x3b] = 0;
  param_1[0x3c] = 0;
  param_1[0x3d] = 0;
  param_1[0x3e] = 0;
  param_1[0x3f] = 0;
  param_1[0x40] = 0;
  param_1[0x41] = 0;
  param_1[0x42] = 0;
  param_1[0x43] = 0;
  param_1[0x44] = 0;
  param_1[0x45] = 0;
  param_1[0x46] = 0;
  param_1[0x49] = 0;
  param_1[0x4a] = 0;
  param_1[0x4c] = 0;
  param_1[0x4d] = 0;
  param_1[0x4e] = 0;
  param_1[0x4f] = 0;
  param_1[0x50] = 0;
  param_1[0x51] = 0;
  *param_1 = CBaseMonster::vftable;
  puVar6 = param_1 + 0x79;
  param_1[0x5e] = 0;
  param_1[0x5f] = 0;
  param_1[0x60] = 0;
  param_1[0x61] = 0;
  param_1[100] = 0;
  param_1[0x65] = 0;
  param_1[0x66] = 0;
  param_1[0x67] = 0;
  param_1[0x68] = 0;
  param_1[0x69] = 0;
  param_1[0x6b] = 0;
  param_1[0x6c] = 0;
  param_1[0x72] = 0;
  param_1[0x73] = 0;
  param_1[0x74] = 0;
  local_8 = 0;
  *puVar6 = 0;
  param_1[0x7a] = 0;
  param_1[0x7b] = 0;
  param_1[0x7c] = 0;
  param_1[0x7d] = 0;
  puVar4 = operator_new(8);
  puVar4[1] = 0;
  *puVar6 = puVar4;
  *puVar4 = puVar6;
  local_8 = CONCAT31(local_8._1_3_,1);
  *(undefined1 *)(param_1 + 0x7e) = 0;
  _eh_vector_constructor_iterator_
            (param_1 + 0x80,0x50,0x21,FUN_113f4fe0,(_func_void_void_ptr *)&LAB_1065e2d0);
  param_1[0x314] = EntityAnimation::Component<class_VoxelMonster>::vftable;
  param_1[0x315] = param_1;
  param_1[0x318] = 0;
  local_8 = 2;
  param_1[0x319] = 0;
  param_1[0x31a] = 0;
  pvVar5 = operator_new(0x18);
  *(void **)pvVar5 = pvVar5;
  *(void **)((int)pvVar5 + 4) = pvVar5;
  param_1[0x319] = pvVar5;
  piVar1 = param_1 + 0x31b;
  *piVar1 = 0;
  param_1[0x31c] = 0;
  param_1[0x31d] = 0;
  param_1[0x31e] = 7;
  param_1[799] = 8;
  param_1[0x318] = 0x3f800000;
  uVar2 = param_1[0x319];
  local_8._0_1_ = 4;
  if ((uint)((int)param_1[0x31c] >> 2) < 0x10) {
    puVar6 = operator_new(0x40);
    iVar7 = param_1[0x31d] - *piVar1 >> 2;
    if (iVar7 != 0) {
      FUN_10643140(*piVar1,iVar7);
    }
    puVar4 = puVar6 + 0x10;
    *piVar1 = (int)puVar6;
    param_1[0x31c] = puVar4;
    param_1[0x31d] = puVar4;
    for (; puVar6 != puVar4; puVar6 = puVar6 + 1) {
      *puVar6 = uVar2;
    }
  }
  else {
    uVar3 = param_1[0x31c] + 3 >> 2;
    if (uVar3 != 0) {
      puVar6 = (undefined4 *)0x0;
      for (; uVar3 != 0; uVar3 = uVar3 - 1) {
        *puVar6 = uVar2;
        puVar6 = puVar6 + 1;
      }
    }
  }
  *param_1 = VoxelMonster::vftable;
  puVar6 = param_1 + 0x349;
  param_1[0x314] = VoxelMonster::vftable;
  param_1[0x321] = 0;
  param_1[0x323] = 0;
  param_1[0x324] = 0;
  param_1[0x325] = 0;
  param_1[0x326] = 0;
  param_1[0x327] = 0;
  param_1[0x328] = 0;
  param_1[0x329] = 0;
  param_1[0x32a] = 0;
  param_1[0x32b] = 0;
  param_1[0x32c] = 0;
  param_1[0x32d] = 0;
  param_1[0x32e] = 0;
  param_1[0x32f] = 0;
  param_1[0x331] = 0;
  param_1[0x332] = 0;
  param_1[0x333] = 0;
  param_1[0x334] = 0x42a00000;
  param_1[0x335] = 0;
  param_1[0x338] = 0;
  param_1[0x339] = 0;
  param_1[0x33a] = 0;
  param_1[0x33b] = 0;
  param_1[0x33c] = 0;
  param_1[0x33d] = 0;
  param_1[0x33e] = 0;
  param_1[0x33f] = 0;
  *(undefined2 *)(param_1 + 0x340) = 0x101;
  *(undefined1 *)((int)param_1 + 0xd02) = 0;
  param_1[0x341] = 0x20000;
  *(undefined2 *)(param_1 + 0x342) = 0;
  param_1[0x343] = 0;
  *(undefined2 *)(param_1 + 0x344) = 1;
  param_1[0x345] = 0;
  param_1[0x346] = 0;
  param_1[0x347] = 0;
  param_1[0x348] = 0xffffffff;
  local_8 = CONCAT31(local_8._1_3_,5);
  *puVar6 = 0;
  param_1[0x34a] = 0;
  param_1[0x34b] = 0;
  param_1[0x34c] = 0;
  param_1[0x34d] = 0;
  puVar4 = operator_new(8);
  puVar4[1] = 0;
  *puVar6 = puVar4;
  *puVar4 = puVar6;
  param_1[0x34e] = 0;
  param_1[0x34f] = 0;
  *(undefined1 *)(param_1 + 0x350) = 0;
  param_1[0x351] = 0;
  param_1[0x352] = 0;
  *(undefined2 *)(param_1 + 0x353) = 0;
  param_1[0x354] = 0x3f800000;
  param_1[0x355] = 0;
  param_1[0x356] = 0;
  *(undefined2 *)(param_1 + 0x357) = 0x100;
  *(undefined1 *)((int)param_1 + 0xd5e) = 1;
  param_1[0x358] = 0;
  param_1[0x359] = 0;
  param_1[0x35a] = 0;
  param_1[0x35b] = 0;
  param_1[0x35c] = 0;
  param_1[0x35d] = 0;
  param_1[0x35e] = 0;
  param_1[0x35f] = 0;
  param_1[0x360] = 0;
  param_1[0x361] = 0;
  param_1[0x362] = 0;
  *(undefined1 *)(param_1 + 0x363) = 0;
  param_1[0x364] = 0;
  param_1[0x365] = 0;
  param_1[0x366] = 0;
  param_1[0x367] = 0;
  ExceptionList = local_10;
  return param_1;
}
```

### FUN_10a99930 - VoxelMonster_Boss_InfectedTitan Base Constructor
```c
undefined4 * __fastcall FUN_10a99930(undefined4 *param_1) {
  int *piVar1;
  void *pvVar2;
  int *piVar3;
  void *local_10;
  undefined1 *puStack_c;
  undefined4 local_8;
  local_8 = 0xffffffff;
  puStack_c = &LAB_115cc204;
  local_10 = ExceptionList;
  ExceptionList = &local_10;
  FUN_10a8b730(DAT_11d38180 ^ (uint)&stack0xfffffffc);
  local_8 = 0;
  *param_1 = VoxelMonster_Boss::vftable;
  param_1[0x314] = VoxelMonster_Boss::vftable;
  FUN_1094bf70();
  param_1[0x375] = 0;
  param_1[0x376] = 0;
  param_1[0x377] = 0;
  *param_1 = VoxelMonster_Boss_InfectedTitan::vftable;
  param_1[0x314] = VoxelMonster_Boss_InfectedTitan::vftable;
  param_1[0x380] = 0;
  local_8 = 1;
  param_1[0x381] = 0;
  param_1[0x382] = 0;
  pvVar2 = operator_new(0xc);
  *(void **)pvVar2 = pvVar2;
  *(void **)((int)pvVar2 + 4) = pvVar2;
  param_1[0x381] = pvVar2;
  param_1[899] = 0;
  param_1[900] = 0;
  param_1[0x385] = 0;
  param_1[0x386] = 7;
  param_1[0x387] = 8;
  param_1[0x380] = 0x3f800000;
  local_8._0_1_ = 3;
  FUN_10641b40(0x10,param_1[0x381]);
  local_8._0_1_ = 4;
  piVar1 = param_1 + 0x38a;
  param_1[0x388] = CondFuncManager::vftable;
  *(undefined1 *)(param_1 + 0x389) = 0;
  *piVar1 = 0;
  param_1[0x38b] = 0;
  pvVar2 = operator_new(0x58);
  *(void **)pvVar2 = pvVar2;
  *(void **)((int)pvVar2 + 4) = pvVar2;
  *piVar1 = (int)pvVar2;
  piVar3 = param_1 + 0x38c;
  local_8 = CONCAT31(local_8._1_3_,5);
  *piVar3 = 0;
  param_1[0x38d] = 0;
  pvVar2 = operator_new(0x58);
  *(void **)pvVar2 = pvVar2;
  *(void **)((int)pvVar2 + 4) = pvVar2;
  *piVar3 = (int)pvVar2;
  FUN_10739870(piVar1,*piVar1);
  *(int *)*piVar1 = *piVar1;
  *(int *)(*piVar1 + 4) = *piVar1;
  param_1[0x38b] = 0;
  FUN_10739870(piVar3,*piVar3);
  *(int *)*piVar3 = *piVar3;
  *(int *)(*piVar3 + 4) = *piVar3;
  param_1[0x38d] = 0;
  param_1[0x38f] = 0;
  param_1[0x390] = 0;
  param_1[0x391] = 0;
  ExceptionList = local_10;
  return param_1;
}
```

---

## Monster Types Summary

| Monster Type | Address | Size | Notes |
|-------------|---------|------|-------|
| voxel_monster | 10a939f0 | base | VoxelMonster base class |
| voxel_monster_zombie | aa52a0 | 0xda0 | Standard zombie |
| voxel_monster_boomer | aa51c0 | 0xda0 | Exploding boomer |
| voxel_monster_boss_infectedtitan | a9b8f0 | 0xe50 | Boss with CondFuncManager |
| voxel_monster_boss_protophobos | a9cd50 | 0xe18 | Boss with weapon data |
| voxel_monster_minion | aa0640 | 0xda0 | Basic minion |
| voxel_monster_hooligan1 | a9f7a0 | 0xda0 | Hooligan type 1 |
| voxel_monster_hooligan2 | a9f810 | 0xda0 | Hooligan type 2 |
| voxel_monster_boss_ampsuit | a99440 | 0xe60 | Boss with FlameThrower + Laser |
| voxel_monster_china | a9d770 | 0xda0 | China variant |
| voxel_monster_gasturret | aa1d30 | 0xda8 | Gas turret |
| voxel_monster_ghost | a9f710 | 0xda8 | Ghost variant |
| voxel_monster_hooligancan | a9f880 | 0xc60 | Hooligan canister |
| voxel_monster_maple | a9fe00 | 0xda0 | Maple variant |
| voxel_monster_shelternormal | aa5230 | 0xda0 | Shelter normal |
| voxel_monster_shturret | aa1db0 | 0xda8 | SH turret |
| voxel_monster_snowball | aa2db0 | 0xc60 | Snowball |
| voxel_monster_snowman | aa2dc0 | 0xda0 | Snowman |
| voxel_monster_turret | aa39d0 | 0xda0 | Basic turret |
| voxel_monster_a101ar | a95430 | 0xda0 | AR-101 variant |
| voxel_monster_a104rl | a96d20 | 0xda0 | RL-104 variant |
| voxel_monster_a104rl_gun | a96d90 | 0xc70 | RL-104 gun mount |

---

## Entity Hierarchy

```
CBaseEntity
  └── CBaseAnimating
        └── CBaseMonster
              └── VoxelMonster (0xc50 bytes)
                    ├── VoxelMonster_Zombie
                    ├── VoxelMonster_Boomer
                    ├── VoxelMonster_Minion
                    ├── VoxelMonster_Hooligan1
                    ├── VoxelMonster_Hooligan2
                    ├── VoxelMonster_China
                    ├── VoxelMonster_Maple
                    ├── VoxelMonster_ShelterNormal
                    ├── VoxelMonster_Snowman
                    ├── VoxelMonster_Turret
                    ├── VoxelMonster_A101AR
                    ├── VoxelMonster_A104RL
                    ├── VoxelMonster_GasTurret
                    ├── VoxelMonster_Ghost
                    ├── VoxelMonster_SHTurret
                    └── VoxelMonster_Boss
                          ├── VoxelMonster_Boss_AmpSuit (with FlameThrower + Laser)
                          ├── VoxelMonster_Boss_InfectedTitan
                          └── VoxelMonster_Boss_ProtoPhobos
                                └── VoxelMonster_HooliganCan
                                └── VoxelMonster_Snowball
                                └── VoxelMonster_A104RL_Gun
```

---

## Key Field Offsets (from VoxelMonster base at offset 0)

### Animation/Component (0x314)
- 0x314: vftable pointer
- 0x315: owner pointer

### Think State (0x318-0x34d)
- 0x318: health float (initialized 0x3f800000 = 1.0f)
- 0x319: pointer to behavior data
- 0x31a: behavior state
- 0x31b-0x31e: behavior parameters

### AI/Schedule (0x321-0x34d)
- 0x321-0x332: schedule-related fields
- 0x334: float value (0x42a00000 = 80.0f?)
- 0x338-0x340: AI state fields
- 0x340: flags (0x101)
- 0x341: more flags (0x20000)
- 0x342-0x344: counters
- 0x348: 0xffffffff
- 0x349-0x34d: schedule state

### Damage/Combat (0x34e-0x357)
- 0x34e-0x34f: damage data
- 0x350: byte flag
- 0x351-0x353: damage state
- 0x354: 0x3f800000 (1.0f)
- 0x357: 0x100

### Boss-specific (0x375-0x391)
- 0x375-0x377: boss state counters
- 0x380-0x382: boss weapon data (AmpSuit)
- 0x389: Laser vftable (AmpSuit)
- 0x380: FlameThrower vftable (AmpSuit)