# CSO Weapon Code (mp.dll)

## Overview

CSO weapons are implemented as factory functions (constructors) exported from mp.dll. Each weapon type has a factory function that allocates memory, calls the base constructor, and sets the vftable. All weapons inherit from CBasePlayerWeapon.

---

## Base Weapon Constructor

### FUN_10abefd0 - CBasePlayerWeapon Base Constructor
```
Base Constructor @ 10abefd0
Size: ~0x88 bytes
```
```c
undefined4 * __fastcall FUN_10abefd0(undefined4 *param_1) {
  // Entity vftable
  *param_1 = CBaseEntity::vftable;

  // Initialize ammo struct (smart pointer, 0x10 bytes)
  // 7 rounds × 2 fields each (ammo type + count)

  // Set default player item state
  *(undefined1 *)(param_1 + 0x1c) = 1;
  param_1[0x1e] = 0;
  // ... more fields 0x1f-0x35

  // Upgrade to CBasePlayerItem vftable
  *param_1 = CBasePlayerItem::vftable;

  // Initialize weapon fields
  // 0x46: primary ammo
  // 0x48-0x4b: byte flags
  // 0x4c-0x54: counters
  // 0x69-0x82: more weapon state

  // Finalize to CBasePlayerWeapon vftable
  *param_1 = CBasePlayerWeapon::vftable;
  param_1[0x46] = 1;  // default rounds
}
```

---

## Weapon Factory Functions

### IgniteMG (weapon_ignitemg)
```
weapon_ignitemg @ 10d02390
Size: 0x230
```
```c
void weapon_ignitemg(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x230), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CIgniteMG::vftable;
    *(undefined1 *)(puVar3 + 0x89) = 0;
    puVar3[0x8a] = 0;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### SatelliteMG (weapon_satellitemg)
```
weapon_satellitemg @ 10f2f9c0
Size: 0x220
```
```c
void weapon_satellitemg(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CSatelliteMG::vftable;
    *(undefined2 *)(puVar3 + 0x86) = 0;
    puVar3[0x87] = 0;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### SatelliteMG3 (weapon_satellitemg3)
```
weapon_satellitemg3 @ 10f2fac0
Size: 0x228
```
```c
void weapon_satellitemg3(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x228), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CSatelliteMG3::vftable;
    *(undefined2 *)(puVar3 + 0x86) = 0;
    puVar3[0x87] = 0;
    puVar3[0x88] = 0;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### SatelliteMG4 (weapon_satellitemg4)
```
weapon_satellitemg4 @ 10f2fb40
Size: 0x238 (uses base constructor)
```
```c
void weapon_satellitemg4(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0x238), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10f26140();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### SatelliteMG5 (weapon_satellitemg5)
```
weapon_satellitemg5 @ 10f2fba0
Size: 0x238
```
```c
void weapon_satellitemg5(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0x238), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10f261a0();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### SatelliteMGEx (weapon_satellitemgex)
```
weapon_satellitemgex @ 10f2fc00
Size: 0x238
```
```c
void weapon_satellitemgex(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0x238), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10f26200();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### CoilGun (weapon_coilgun)
```
weapon_coilgun @ 11008480
Size: 0x220
```
```c
void weapon_coilgun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CCoilGun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### DrillGun (weapon_drillgun)
```
weapon_drillgun @ 11012390
Size: 0x228
```
```c
void weapon_drillgun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x228), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CDrillgun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### Gungnir (weapon_gungnir)
```
weapon_gungnir @ 10cc3240
Size: 0x248
```
```c
void weapon_gungnir(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0x248), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10cbf980();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### GungnirEx (weapon_gungnirex)
```
weapon_gungnirex @ 10cc3da0
Size: 0x248
```
```c
void weapon_gungnirex(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0x248), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10cc3920();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### GunKata (weapon_gunkata)
```
weapon_gunkata @ 10cc72b0
Size: 0x270
```
```c
void weapon_gunkata(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0x270), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10cc5ac0();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### GunKataM (weapon_gunkatam)
```
weapon_gunkatam @ 10cc7bc0
Size: 0x270
```
```c
void weapon_gunkatam(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x270), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    puVar3[0x89] = 0;
    puVar3[0x8a] = 0;
    puVar3[0x8b] = 0;
    puVar3[0x8c] = 0;
    puVar3[0x8d] = 0;
    puVar3[0x8e] = 0;
    puVar3[0x9a] = 0;
    *puVar3 = CGunKataM::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### HaloGun (weapon_halogun)
```
weapon_halogun @ 10cda970
Size: 0x290
```
```c
void weapon_halogun(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0x290), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10cc9470();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### HaloGunEx (weapon_halogunex)
```
weapon_halogunex @ 10cdbc00
Size: 0x290
```
```c
void weapon_halogunex(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0x290), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10cdb2d0();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### JetGun (weapon_jetgun)
```
weapon_jetgun @ 10d0af60
Size: 600 (0x258)
```
```c
void weapon_jetgun(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,600), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10d05110();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### JetGunEx (weapon_jetgunex)
```
weapon_jetgunex @ 10d0b760
Size: 600 (0x258)
```
```c
void weapon_jetgunex(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,600), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10d0b3d0();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### LaserMinigun (weapon_laserminigun)
```
weapon_laserminigun @ 10e5b7d0
Size: 0x288
```
```c
void weapon_laserminigun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x288), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CLaserMinigun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### LockOnGun (weapon_lockongun)
```
weapon_lockongun @ 10e800c0
Size: 0x2b8
```
```c
void weapon_lockongun(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0x2b8), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_10e7ed30();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### MountGun (weapon_mountgun)
```
weapon_mountgun @ 111284f0
Size: 0x220
```
```c
void weapon_mountgun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CMountgun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### PianoGun (weapon_pianogun)
```
weapon_pianogun @ 10ef3460
Size: 0x230
```
```c
void weapon_pianogun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x230), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CPianoGun::vftable;
    puVar3[0x87] = 0;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### PianoGunEx (weapon_pianogunex)
```
weapon_pianogunex @ 10ef50d0
Size: 0x238
```
```c
void weapon_pianogunex(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x238), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    puVar3[0x87] = 0;
    *puVar3 = CPianoGunEX::vftable;
    *(undefined1 *)(puVar3 + 0x8c) = 0;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### PlasmaGun (weapon_plasmagun)
```
weapon_plasmagun @ 111530b0
Size: 0x220
```
```c
void weapon_plasmagun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CPlasmaGun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### PoisonGun (weapon_poisongun)
```
weapon_poisongun @ 11154010
Size: 0x228
```
```c
void weapon_poisongun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x228), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CPoisonGun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### RailGun (weapon_railgun)
```
weapon_railgun @ 10f06960
Size: 0x220
```
```c
void weapon_railgun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CRailGun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### ReviveGun (weapon_revivegun)
```
weapon_revivegun @ 10f0d070
Size: 0x238
```
```c
void weapon_revivegun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x238), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CReviveGun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### SFGun (weapon_sfgun)
```
weapon_sfgun @ 1116d160
Size: 0x220
```
```c
void weapon_sfgun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CSFGun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### SnakeGun (weapon_snakegun)
```
weapon_snakegun @ 1121d6a0
Size: 0x220
```
```c
void weapon_snakegun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CSnakegun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### Speargun (weapon_speargun)
```
weapon_speargun @ 111b6550
Size: 0x240
```
```c
void weapon_speargun(uint param_1) {
  uint uVar1;
  int iVar2;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (iVar2 = (*DAT_121b21f8)(iVar2,0x240), uVar1 = param_1, iVar2 != 0)) {
    iVar2 = FUN_111aee30();
    *(uint *)(iVar2 + 8) = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### SpeargunEx (weapon_speargunex)
```
weapon_speargunex @ 10f79680
Size: 0x238
```
```c
void weapon_speargunex(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x238), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CSpeargunEX::vftable;
    puVar3[0x8b] = 0;
    puVar3[0x8c] = 0;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### TransformGun (weapon_transformgun)
```
weapon_transformgun @ 112102c0
Size: 0x220
```
```c
void weapon_transformgun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CTransformGun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### Violingun (weapon_violingun)
```
weapon_violingun @ 1122a7d0
Size: 0x220
```
```c
void weapon_violingun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CViolingun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VxlJunkGun (weapon_vxljunkgun)
```
weapon_vxljunkgun @ 11251c40
Size: 600 (0x258)
```
```c
void weapon_vxljunkgun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,600), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CVxlJunkGun::vftable;
    puVar3[2] = param_1;
    puVar3[0x8d] = 0;
    puVar3[0x8e] = 0;
    puVar3[0x8f] = 0;
    puVar3[0x91] = 0;
    puVar3[0x92] = 0;
    puVar3[0x93] = 0;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VxlLongGun (weapon_vxllonggun)
```
weapon_vxllonggun @ 11252dd0
Size: 0x220
```
```c
void weapon_vxllonggun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CVxlLongGun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VxlMiniGun (weapon_vxlminigun)
```
weapon_vxlminigun @ 112544f0
Size: 0x228
```
```c
void weapon_vxlminigun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x228), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CVxlMiniGun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### VxlShortGun (weapon_vxlshortgun)
```
weapon_vxlshortgun @ 11255460
Size: 0x220
```
```c
void weapon_vxlshortgun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CVxlShortGun::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### WaterGun (weapon_watergun)
```
weapon_watergun @ 112677b0
Size: 0x220
```
```c
void weapon_watergun(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_121b21f8)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar3 = CWATERGUN::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### WingGun (weapon_winggun)
```
weapon_winggun @ 11279bb0
Size: 0x278
```
```c
void weapon_winggun(uint param_1) {
  undefined4 uVar1;
  uint uVar2;
  int iVar3;
  undefined4 *puVar4;
  if (param_1 == 0) {
    iVar3 = (*DAT_121b2144)();
    param_1 = -(uint)(iVar3 != 0) & iVar3 + 0x84U;
  }
  iVar3 = *(int *)(param_1 + 0x238);
  if (((iVar3 == 0) || (uVar2 = _DAT_00000008, *(int *)(iVar3 + 0x80) == 0)) &&
     (puVar4 = (undefined4 *)(*DAT_121b21f8)(iVar3,0x278), uVar2 = param_1,
     puVar4 != (undefined4 *)0x0)) {
    FUN_10abefd0();
    *puVar4 = CWingGun::vftable;
    puVar4[0x89] = 0;
    puVar4[0x8a] = 0;
    puVar4[0x8b] = 0;
    puVar4[0x8c] = 0;
    puVar4[0x8d] = 0;
    puVar4[0x8e] = 0xbf800000;
    puVar4[0x8f] = 0;
    puVar4[0x90] = 0;
    *(undefined2 *)(puVar4 + 0x91) = 0;
    puVar4[0x92] = 0;
    puVar4[0x93] = 0;
    puVar4[0x94] = 0;
    puVar4[0x95] = 0;
    puVar4[0x96] = (undefined4)DAT_121b20cc;
    puVar4[0x97] = DAT_121b20cc._4_4_;
    uVar1 = DAT_121b20d4;
    *(undefined2 *)(puVar4 + 0x99) = 0;
    puVar4[0x9a] = 0xffffffff;
    puVar4[2] = param_1;
    puVar4[0x98] = uVar1;
    return;
  }
  _DAT_00000008 = uVar2;
  return;
}
```

---

## Complete Weapon Export List (mp.dll)

### Special Weapons
| Weapon | Address | Size | Class |
|--------|---------|------|-------|
| weapon_ignitemg | 10d02390 | 0x230 | CIgniteMG |
| weapon_satellitemg | 10f2f9c0 | 0x220 | CSatelliteMG |
| weapon_satellitemg2 | 10f2fa40 | - | - |
| weapon_satellitemg3 | 10f2fac0 | 0x228 | CSatelliteMG3 |
| weapon_satellitemg4 | 10f2fb40 | 0x238 | - |
| weapon_satellitemg5 | 10f2fba0 | 0x238 | - |
| weapon_satellitemgex | 10f2fc00 | 0x238 | - |

### Conventional Guns
| Weapon | Address | Size | Class |
|--------|---------|------|-------|
| weapon_coilgun | 11008480 | 0x220 | CCoilGun |
| weapon_drillgun | 11012390 | 0x228 | CDrillgun |
| weapon_laserminigun | 10e5b7d0 | 0x288 | CLaserMinigun |
| weapon_lockongun | 10e800c0 | 0x2b8 | - |
| weapon_mountgun | 111284f0 | 0x220 | CMountgun |
| weapon_plasmagun | 111530b0 | 0x220 | CPlasmaGun |
| weapon_poisongun | 11154010 | 0x228 | CPoisonGun |
| weapon_railgun | 10f06960 | 0x220 | CRailGun |
| weapon_snakegun | 1121d6a0 | 0x220 | CSnakegun |
| weapon_revivegun | 10f0d070 | 0x238 | CReviveGun |

### Thrown/Spear Weapons
| Weapon | Address | Size | Class |
|--------|---------|------|-------|
| weapon_gungnir | 10cc3240 | 0x248 | - |
| weapon_gungnirex | 10cc3da0 | 0x248 | - |
| weapon_speargun | 111b6550 | 0x240 | - |
| weapon_speargunex | 10f79680 | 0x238 | CSpeargunEX |
| weapon_speargunex17th | 10f79d00 | - | - |
| weapon_speargunm | 10f7b5c0 | - | - |
| weapon_speargunzhc | 111b65b0 | - | - |

### Sword/Kata Weapons
| Weapon | Address | Size | Class |
|--------|---------|------|-------|
| weapon_gunkata | 10cc72b0 | 0x270 | - |
| weapon_gunkatam | 10cc7bc0 | 0x270 | CGunKataM |
| weapon_gunkatazhc | 10cc7310 | - | - |
| weapon_alterationammogun | 10b845a0 | - | - |
| weapon_anniv24gunkata | 10b8ddc0 | - | - |

### Music/Art Weapons
| Weapon | Address | Size | Class |
|--------|---------|------|-------|
| weapon_pianogun | 10ef3460 | 0x230 | CPianoGun |
| weapon_pianogunex | 10ef50d0 | 0x238 | CPianoGunEX |
| weapon_violingun | 1122a7d0 | 0x220 | CViolingun |

### Jet/Flying Weapons
| Weapon | Address | Size | Class |
|--------|---------|------|-------|
| weapon_jetgun | 10d0af60 | 600 | - |
| weapon_jetgunex | 10d0b760 | 600 | - |
| weapon_jetgunzf | 10d0afc0 | - | - |
| weapon_halogun | 10cda970 | 0x290 | - |
| weapon_halogunex | 10cdbc00 | 0x290 | - |

### Transform/Mount Weapons
| Weapon | Address | Size | Class |
|--------|---------|------|-------|
| weapon_transformgun | 112102c0 | 0x220 | CTransformGun |
| weapon_transformgunadv | 11210330 | - | - |
| weapon_transformgunex | 112103a0 | - | - |
| weapon_winggun | 11279bb0 | 0x278 | CWingGun |
| weapon_winggunex | 1127afb0 | - | - |

### CJetGun Subclasses (Year 21-26 Special Weapons)
| Weapon | Address | Size | Class |
|--------|---------|------|-------|
| weapon_jetgun | 10d0af60 | 0x258 | CJetGun |
| weapon_jetgunex | 10d0b760 | 0x258 | CJetGunEx |
| weapon_jetgunzf | 10d0afc0 | - | CJetGunZf |
| weapon_y21s1jetgunma | 112a2180 | - | CY21S1JetGunMA |
| weapon_y21s1jetgunmb | 112a5350 | - | CY21S1JetGunMB |
| weapon_y21s1jetgunmc | 112a5b30 | - | CY21S1JetGunMC |
| weapon_y21s1jetgunmd | 112ac110 | - | CY21S1JetGunMD |
| jetgunmbearA | 10ad3de0 | - | CJetGunMBearA (projectile entity) |

### VXL Weapons (Voxel)
| Weapon | Address | Size | Class |
|--------|---------|------|-------|
| weapon_vxljunkgun | 11251c40 | 600 | CVxlJunkGun |
| weapon_vxllonggun | 11252dd0 | 0x220 | CVxlLongGun |
| weapon_vxlminigun | 112544f0 | 0x228 | CVxlMiniGun |
| weapon_vxlshortgun | 11255460 | 0x220 | CVxlShortGun |
| weapon_violingun | 1122a7d0 | 0x220 | CViolingun |
| weapon_sfgun | 1116d160 | 0x220 | CSFGun |

### Other
| Weapon | Address | Size | Class |
|--------|---------|------|-------|
| weapon_navalgun | 10edd880 | - | - |
| weapon_horsegun | 1105b830 | - | - |
| weapon_beamgun | 10bac360 | - | - |
| weapon_beamgunle | 10baca30 | - | - |
| weapon_cameragun | 10c1cb00 | - | - |
| weapon_leapstrikegun | 10e61540 | - | - |
| weapon_leapstrikegunex | 10e61b70 | - | - |
| weapon_watergun | 112677b0 | 0x220 | CWATERGUN |
| weapon_y21s1jetgunma | 112a2180 | - | - |
| weapon_y21s1jetgunmb | 112a5350 | - | - |
| weapon_y21s2lockongunma | 112ad310 | - | - |
| weapon_y24s1laserminigun | 112d1f20 | - | - |
| weapon_y25s1sfgun | 112da6a0 | - | - |
| weapon_y26s1plasmagun | 11153190 | - | - |
| weapon_zgun | 112eb6e0 | - | - |

---

## Item Entities

### VoxelItemBox (voxelitembox)
```
voxelitembox @ 10a79bf0
Size: 0xb8
```
```c
void CVoxelItemBox::ItemTouch(CVoxelItemBox *this, CBaseEntity *param_1) {
  // Physics-based push on player touch
  // Checks distance and applies force
}
```

---

## RTTI Class Hierarchy

```
CBaseEntity
  └── CBaseAnimating
        └── CBaseToggle
              └── CBasePlayerItem
                    └── CBasePlayerWeapon
                          └── CSimpleWpn<CJetGun>
                                ├── CJetGun (weapon_jetgun)
                                ├── CJetGunEx (weapon_jetgunex)
                                ├── CJetGunZf (weapon_jetgunzf)
                                ├── CY21S1JetGunMA (weapon_y21s1jetgunma)
                                ├── CY21S1JetGunMB (weapon_y21s1jetgunmb)
                                ├── CY21S1JetGunMC (weapon_y21s1jetgunmc)
                                └── CY21S1JetGunMD (weapon_y21s1jetgunmd)

CBaseEntity
  └── CBaseAnimating
        └── CVoxelItemBox (voxelitembox)

CBaseEntity
  └── CBaseAnimating
        └── CJetGunMBearA (jetgunmbearA)  // Projectile entity spawned by Y21S1 JetGun
```

## CJetGun Vftable

### CJetGun Vftable Address
- **Vftable**: `0x1184420c` (RVA 0x184420c)
- **Constructor**: `FUN_10d05110` (sets vftable at offset 0, initializes fields at 0x224, 0x234-0x248)

### CJetGun-Specific Fields (at offset 0)
| Offset | Type | Description |
|--------|------|-------------|
| 0x224 | byte | Charge state (0 = ready) |
| 0x234-0x248 | dword[7] | Charge/target tracking fields |

### Weapon Sound/Model Resources
| Asset Type | Path |
|------------|------|
| View model | models/v_jetgun.mdl |
| Player model | models/p_jetgun.mdl |
| Fire sound 1 | weapons/jetgun-1.wav |
| Fire sound 2 | weapons/jetgun-2.wav |
| Fire end sound | weapons/jetgun-1_end.wav |
| Dash sound | weapons/jetgun_dash.wav |
| Idle sound | weapons/jetgun_idle.wav |
| Beep sound | weapons/jetgun_beep.wav |
| Hit sprite | sprites/ef_jetgunhit.spr |

### AmmoTouch Functions (weapon pickup behavior)
| Function | Address | Purpose |
|----------|---------|---------|
| AmmoTouch | 10883d50 | Generic ammo pickup handler |
| AmmoTouch | 10bde4b0 | Alternative ammo pickup |
| AmmoTouch | 1123ebc0 | Extended ammo pickup (spawns effects) |

## Entity Hierarchy

```
CBaseEntity
  └── CBaseAnimating
        └── CBaseToggle
              └── CBasePlayerItem
                    └── CBasePlayerWeapon
                          ├── CIgniteMG (weapon_ignitemg)
                          ├── CSatelliteMG (weapon_satellitemg)
                          ├── CCoilGun (weapon_coilgun)
                          ├── CDrillgun (weapon_drillgun)
                          ├── CLaserMinigun (weapon_laserminigun)
                          ├── CMountgun (weapon_mountgun)
                          ├── CPlasmaGun (weapon_plasmagun)
                          ├── CPoisonGun (weapon_poisongun)
                          ├── CRailGun (weapon_railgun)
                          ├── CReviveGun (weapon_revivegun)
                          ├── CSFGun (weapon_sfgun)
                          ├── CSnakegun (weapon_snakegun)
                          ├── CSpeargunEX (weapon_speargunex)
                          ├── CTransformGun (weapon_transformgun)
                          ├── CViolingun (weapon_violingun)
                          ├── CVxlJunkGun (weapon_vxljunkgun)
                          ├── CVxlLongGun (weapon_vxllonggun)
                          ├── CVxlMiniGun (weapon_vxlminigun)
                          ├── CVxlShortGun (weapon_vxlshortgun)
                          ├── CWATERGUN (weapon_watergun)
                          ├── CWingGun (weapon_winggun)
                          ├── CGunKataM (weapon_gunkatam)
                          ├── CPianoGun (weapon_pianogun)
                          ├── CPianoGunEX (weapon_pianogunex)
                          ├── CJetGun (weapon_jetgun)
                          ├── CJetGunEx (weapon_jetgunex)
                          ├── CJetGunZf (weapon_jetgunzf)
                          ├── CY21S1JetGunMA (weapon_y21s1jetgunma)
                          ├── CY21S1JetGunMB (weapon_y21s1jetgunmb)
                          ├── CY21S1JetGunMC (weapon_y21s1jetgunmc)
                          ├── CY21S1JetGunMD (weapon_y21s1jetgunmd)
                          └── [more weapon types]

CBaseEntity
  └── CBaseAnimating
        └── CVoxelItemBox (voxelitembox)

CBaseEntity
  └── CBaseAnimating
        └── CJetGunMBearA (jetgunmbearA)
```

---

## Key Field Offsets (CBasePlayerWeapon base at offset 0)

### Ammo/State (0x1c-0x35)
- 0x1c: byte (active flag)
- 0x1e-0x35: ammo counts and state flags

### Weapon State (0x36-0x54)
- 0x36: pointer (ammo ref count)
- 0x39: 0xbf800000 (-1.0f)
- 0x3c: 0xbf800000 (-1.0f)
- 0x46: primary ammo count

### Extended State (0x69-0x83)
- 0x69-0x82: weapon-specific state
- 0x83: byte flag

### CJetGun-Specific Fields
- 0x224: byte - Charge state (0 = ready, non-zero = charging/firing)
- 0x234: dword - Charge level tracking
- 0x238: dword - Target tracking
- 0x23c: dword - Beam effect handle
- 0x240: dword - Damage accumulator
- 0x244: dword - Reserved
- 0x248: dword - Reserved

### CBasePlayerWeapon Common Offsets
- 0x50: dword - Last fire time
- 0x4c: dword - Fire count
- 0xB0: pointer - Player entity pointer
- 0xB4: pointer - Owner entity
- 0xB8: float - Position X
- 0xBC: word - Team ID
- 0xC8: dword - Ammo type for weapon
- 0xD0: pointer - Entity that owns this weapon
- 0x1BC: pointer - Player item data
- 0x238: dword - Ammo count

---

## Weapon Think/Behavior Functions

### Named Think Functions Found
| Function | Address | Description |
|----------|---------|-------------|
| BearThink | - | CJetGunMBearA think (mangled `?BearThink@CJetGunMBearA@@QAEXXZ`) |
| BearTouch | 10ad3410 | CJetGunMBearA touch handler - deals damage, spawns effects |
| DelayPrimaryAttack | 110a1570 | CKnife delay primary attack method |
| DelaySecondaryAttack | 110a15f0 | CKnife delay secondary attack method |

### CJetGunMBearA::BearTouch (10ad3410)
The bear touch function handles the Y21S1 JetGun's special bear projectile behavior:
- Calculates damage using traceline (0x30 damage, 0x5 team ID)
- Spawns hit effects at impact point
- Tracks damage over time with cooldown (0x3B = 59 damage threshold)
- Uses traceline for hit detection

### RTTI Method Signatures (mangled)
```
?BearThink@CJetGunMBearA@@QAEXXZ    - No args, void return (__thiscall)
?BearTouch@CJetGunMBearA@@QAEXPAVCBaseEntity@@@Z - Takes CBaseEntity*, void return
?RemoveThink@CJetGunMBearA@@QAEXXZ  - No args, void return (__thiscall)
```

### Fireball Methods
| Function | Address | Description |
|----------|---------|-------------|
| FireballTouch | 11049000 | Fireball entity touch handler |
| FireballThink | 113b0390 | Fireball entity think |
| cannon_fireball | 11049a40 | Cannon fireball spawn function |
| gatlingex_fireball | 10c8fe80 | Gatling EX fireball |

### Delay Attack Methods
These are vftable methods inherited from CBasePlayerWeapon:
- `DelayPrimaryAttack` - Called when primary attack is triggered with delay
- `DelaySecondaryAttack` - Called when secondary attack is triggered with delay
- These methods check weapon state and call the actual fire methods

(End of file - total lines)