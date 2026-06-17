# CSO Weapon Code (client.dll)

## Overview

client.dll contains the **full retail arsenal** — 796 weapon factory functions covering rifles, pistols, shotguns, SMGs, sniper rifles, heavy weapons, and event/buff variants. This is separate from mp.dll's special weapons (voxel, boss, music weapons).

---

## Base Weapon Constructor

### FUN_01e7c3e0 - CBasePlayerWeapon Base Constructor (client.dll)
```
Base Constructor @ 01e7c3e0
Size: ~0x88 bytes
```
```c
undefined4 * __fastcall FUN_01e7c3e0(undefined4 *param_1) {
  // Entity vftable
  *param_1 = CBaseEntity::vftable;

  // Initialize ammo struct (smart pointer, 0x10 bytes)
  // 6 rounds × 2 fields each (ammo type + count)

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

**Note:** Identical structure to mp.dll's FUN_10abefd0 — same field offsets, same initialization pattern.

---

## Sample Weapon Factory Functions

### AK-47 (weapon_ak47)
```
weapon_ak47 @ 025cd930
Size: 0x220
```
```c
void weapon_ak47(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_0387480c)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_038748c0)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_01e7c3e0();
    *puVar3 = CAK47::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

### 19S1 QBZ-95 (weapon_19s1qbz95)
```
weapon_19s1qbz95 @ 01ea23b0
Size: 0x220
```
```c
void weapon_19s1qbz95(uint param_1) {
  uint uVar1;
  int iVar2;
  undefined4 *puVar3;
  if (param_1 == 0) {
    iVar2 = (*DAT_0387480c)();
    param_1 = -(uint)(iVar2 != 0) & iVar2 + 0x84U;
  }
  iVar2 = *(int *)(param_1 + 0x238);
  if (((iVar2 == 0) || (uVar1 = _DAT_00000008, *(int *)(iVar2 + 0x80) == 0)) &&
     (puVar3 = (undefined4 *)(*DAT_038748c0)(iVar2,0x220), uVar1 = param_1,
     puVar3 != (undefined4 *)0x0)) {
    FUN_01e7c3e0();
    *puVar3 = C19S1QBZ95::vftable;
    puVar3[2] = param_1;
    return;
  }
  _DAT_00000008 = uVar1;
  return;
}
```

---

## Complete Weapon Export List (796 weapons)

### Primary Rifles

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_ak47 | 025cd930 | CAK47 |
| weapon_ak47G | 025d46d0 | - |
| weapon_ak47L | 025d5410 | - |
| weapon_ak47L2 | 01f2a360 | - |
| weapon_ak47L3 | 01f26fb0 | - |
| weapon_ak47dragon | 025d10e0 | - |
| weapon_ak47red | 025d6030 | - |
| weapon_ak74u | 01f2ae10 | - |
| weapon_akm | 025d6cc0 | - |
| weapon_akmgs | 01f2de50 | - |
| weapon_an94 | 025daf20 | - |
| weapon_aug | 025f8ad0 | - |
| weapon_augex | 01f4d0f0 | - |
| weapon_arx160 | 01f444f0 | - |
| weapon_famas | 01f7eb00 | - |
| weapon_fnc | 01f7e71 | - |
| weapon_galil | 01f829f0 | - |
| weapon_galilcraft | 01f7ef3 | - |
| weapon_g11 | 01f7ebb | - |
| weapon_g11g | 01f7ec7 | - |
| weapon_g3sg1 | 01f7ed4 | - |
| weapon_hk416 | 033a8137 | - |
| weapon_k1a | 033a8392 | - |
| weapon_k1acraft | 033a83ad | - |
| weapon_k1ase | 033a83ba | - |
| weapon_k3 | 033a83c4 | - |
| weapon_kh2002 | 033a83d2 | - |
| weapon_l85a2 | 033a84a5 | - |
| weapon_m16a1 | 033a86c1 | - |
| weapon_m16a1ep | 033a86ce | - |
| weapon_m16a4 | 033a86dd | - |
| weapon_m4a1 | 033a8868 | - |
| weapon_m4a1G | 033a8874 | - |
| weapon_m4a1dragon | 033a8881 | - |
| weapon_m4a1gold | 033a8893 | - |
| weapon_m4a1gs | 033a88b1 | - |
| weapon_m4a1red | 033a88c0 | - |
| weapon_m4a1wg_sr | 033a88d1 | - |
| weapon_m14ebr | 033a8691 | - |
| weapon_m14ebrgold | 033a869f | - |
| weapon_m14ebrgs | 033a86b1 | - |
| weapon_m400 | 033a885c | - |
| weapon_scarA | 033a8fb1 | - |
| weapon_scarH | 033a8fbe | - |
| weapon_scarL | 033a8fcb | - |
| weapon_sg550 | 033a90af | - |
| weapon_sg552 | 033a90bc | - |
| weapon_sprifle | 033a9417 | - |
| weapon_spriflezhc | 033a9426 | - |
| weapon_stg44 | 033a949f | - |
| weapon_stg44g | 033a94ac | - |
| weapon_stg44gs | 033a94ba | - |
| weapon_tar21 | 033a9500 | - |
| weapon_xm8A | 033a9a68 | - |
| weapon_xm8C | 033a9a74 | - |
| weapon_xm8S | 033a9a80 | - |

### Sniper Rifles

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_awp | 02600050 | - |
| weapon_awpcamo | 026033a0 | - |
| weapon_awpxmas | 026066f0 | - |
| weapon_as50 | 025e7160 | - |
| weapon_as50g | 025f0da0 | - |
| weapon_as50gs | 025f0e10 | - |
| weapon_aw50 | 025fcd20 | - |
| weapon_m24 | 033a879c | - |
| weapon_m82 | 033a8956 | - |
| weapon_m95 | 033a896c | - |
| weapon_m95desert | 033a89a6 | - |
| weapon_m95tiger | 033a89b6 | - |
| weapon_m95tigerm | 033a89c7 | - |
| weapon_m95xmas | 033a89d6 | - |
| weapon_m95xmaszhc | 033a89e8 | - |
| weapon_m95zhc | 033a89f6 | - |
| weapon_psg1 | 033a8e0c | - |
| weapon_scout | 033a8fd8 | - |
| weapon_scoutred | 033a8ff5 | - |
| weapon_sl8 | 033a9286 | - |
| weapon_sl8G | 033a9291 | - |
| weapon_sl8ex | 033a929d | - |
| weapon_sl8exzhc | 033a92aa | - |
| weapon_sl8gs | 033a92c7 | - |
| weapon_sl8zhc | 033a92d5 | - |
| weapon_svd | 033a94da | - |
| weapon_svdex | 033a94e5 | - |
| weapon_svdex2 | 033a94f2 | - |
| weapon_trg42 | 033a96bc | - |
| weapon_trg42g | 033a96ca | - |
| weapon_trg42gs | 033a96d9 | - |
| weapon_wa2000 | 033a9942 | - |
| weapon_wa2000desert | 033a9950 | - |
| weapon_wa2000g | 033a9964 | - |
| weapon_wa2000gs | 033a9973 | - |
| weapon_infinity | 033a81ed | - |
| weapon_infinityex1 | 033a8200 | - |
| weapon_infinityex1zhc | 033a8216 | - |
| weapon_infinityex2 | 033a8229 | - |
| weapon_infinityex2desert | 033a8242 | - |
| weapon_infinityex2zhc | 033a8258 | - |
| weapon_infinitysb | 033a826a | - |
| weapon_infinitysr | 033a827c | - |
| weapon_infinityss | 033a828e | - |
| weapon_infinityzhc | 033a82a1 | - |

### Shotguns

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_m3 | 033a87fe | - |
| weapon_m3dragon | 033a8839 | - |
| weapon_m3dragonex | 033a884b | - |
| weapon_m3dragonm | 033a885c | - |
| weapon_m1887 | 033a86ea | - |
| weapon_m1887G | 033a86f7 | - |
| weapon_m1887craft | 033a8705 | - |
| weapon_m1887craftb | 033a8717 | - |
| weapon_m1887gs | 033a872a | - |
| weapon_m1887w | 033a8739 | - |
| weapon_m1887xmas | 033a8747 | - |
| weapon_xm1014 | 033a9a29 | - |
| weapon_xm1014red | 033a9a37 | - |
| weapon_xm1014snow | 033a9a48 | - |
| weapon_spapas12 | 033a932d | - |
| weapon_spas12desert | 033a9341 | - |
| weapon_spas12ex | 033a9351 | - |
| weapon_spas12ex2 | 033a9362 | - |
| weapon_spas12ex2zhc | 033a9376 | - |
| weapon_spas12excraft | 033a938b | - |
| weapon_spas12exzhc | 033a939e | - |
| weapon_spas12zhc | 033a93af | - |
| weapon_usas12 | 033a9761 | - |
| weapon_usas12camo | 033a9773 | - |
| weapon_norinco86s | 033a8cb4 | - |
| weapon_qbarrel | 033a8e26 | - |
| weapon_qbarrel2 | 033a8e35 | - |
| weapon_dbarrel | 033a7c09 | - |
| weapon_dbarrelg | 033a7c19 | - |
| weapon_dbarrelzhc | 033a7c2b | - |
| weapon_tbarrel | 033a951c | - |
| weapon_tbarrelzhc | 033a952e | - |
| weapon_spas12 | 033a932d | - |
| weapon_anniv24xm1014 | 01f42c70 | - |

### SMGs

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_mac10 | 033a89f6 | - |
| weapon_mp5 | 033a8bf8 | - |
| weapon_mp5g | 033a8c04 | - |
| weapon_mp5gs | 033a8c11 | - |
| weapon_mp5gzhc | 033a8c20 | - |
| weapon_mp5tiger | 033a8c30 | - |
| weapon_mp7a160r | 033a8c40 | - |
| weapon_mp7a1C | 033a8c4e | - |
| weapon_mp7a1D | 033a8c5c | - |
| weapon_mp7a1D2 | 033a8c6b | - |
| weapon_mp7a1P | 033a8c79 | - |
| weapon_mp40 | 033a8be1 | - |
| weapon_p90 | 033a8cfd | - |
| weapon_p90lapin | 033a8d18 | - |
| weapon_tmp | 033a965d | - |
| weapon_tmpdragon | 033a966e | - |
| weapon_ump45 | 033a9746 | - |
| weapon_uzi | 033a97b2 | - |
| weapon_dualuzi | 033a7d78 | - |
| weapon_dualuziw | 033a7d87 | - |
| weapon_bison | 033a76a7 | - |
| weapon_bisonb | 033a76b5 | - |
| weapon_bisonfox | 033a76c5 | - |
| weapon_bison | 033a76a7 | - |
| weapon_bisonb | 033a76b5 | - |
| weapon_bisonfox | 033a76c5 | - |
| weapon_bison | 033a76a7 | - |
| weapon_mp5 | 033a8bf8 | - |

### Pistols

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_glock18 | 033a7f64 | - |
| weapon_glockred | 033a7f73 | - |
| weapon_usp | 033a977e | - |
| weapon_uspred | 033a978c | - |
| weapon_p228 | 033a8cf1 | - |
| weapon_deagle | 033a7c2b | - |
| weapon_deagleD | 033a7c39 | - |
| weapon_deagleD2 | 033a7c48 | - |
| weapon_deagleG | 033a7c58 | - |
| weapon_deagleGzhc | 033a7c67 | - |
| weapon_deaglegs | 033a7c79 | - |
| weapon_deaglered | 033a7c89 | - |
| weapon_elite | 033a7da4 | - |
| weapon_fiveseven | 033a7e41 | - |
| weapon_fnp45 | 033a7e7e | - |
| weapon_luger | 033a85ad | - |
| weapon_luger_ex | 033a85ba | - |
| weapon_lugerg | 033a85ca | - |
| weapon_lugergs | 033a85d8 | - |
| weapon_lugers | 033a85e7 | - |
| weapon_lugerszhc | 033a85f5 | - |
| weapon_python | 033a8e26 | - |
| weapon_mauserc96 | 033a8a32 | - |
| weapon_m1911a1 | 033a8767 | - |
| weapon_anaconda | 033a73c8 | - |
| weapon_automag | 033a748c | - |

### Heavy Weapons

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_m249 | 033a87a8 | - |
| weapon_m249camo | 033a87b8 | - |
| weapon_m249ep | 033a87c6 | - |
| weapon_m249ex | 033a87d4 | - |
| weapon_m249xmas | 033a87e4 | - |
| weapon_mg3 | 033a8a3d | - |
| weapon_mg3can | 033a8a81 | - |
| weapon_mg3chn | 033a8a8f | - |
| weapon_mg3desert | 033a8aa0 | - |
| weapon_mg3deu | 033a8aae | - |
| weapon_mg3g | 033a8aba | - |
| weapon_mg3gs | 033a8ac7 | - |
| weapon_mg3idn | 033a8ad5 | - |
| weapon_mg3jpn | 033a8ae3 | - |
| weapon_mg3kor | 033a8af1 | - |
| weapon_mg3rus | 033a8aff | - |
| weapon_mg3tur | 033a8b0d | - |
| weapon_mg3twn | 033a8b1b | - |
| weapon_mg3usa | 033a8b29 | - |
| weapon_mg3xmas | 033a8b38 | - |
| weapon_mg3xmaszhc | 033a8b4a | - |
| weapon_mg36 | 033a8a49 | - |
| weapon_mg36b | 033a8a56 | - |
| weapon_mg36g | 033a8a63 | - |
| weapon_mg36xmas | 033a8a73 | - |
| weapon_mg42 | 033a8b56 | - |
| weapon_m60 | 033a88dc | - |
| weapon_m60craft | 033a88ec | - |
| weapon_m60desert | 033a88fd | - |
| weapon_m60g | 033a8909 | - |
| weapon_m82 | 033a8956 | - |
| weapon_m134 | 033a8612 | - |
| weapon_m134ex | 033a8620 | - |
| weapon_m134exzhc | 033a8631 | - |
| weapon_m134hero | 033a8641 | - |
| weapon_m134hero2 | 033a8652 | - |
| weapon_m134w | 033a866f | - |
| weapon_m134xmas | 033a867f | - |
| weapon_m134xmaszhc | 033a8682 | - |
| weapon_m134zhc | 033a8691 | - |
| weapon_mg3 | 033a8a3d | - |
| weapon_pkm | 033a8d9b | - |
| weapon_pkmg | 033a8da7 | - |
| weapon_mk48 | 033a8b9a | - |
| weapon_gatling | 033a7f02 | - |
| weapon_gatlingex | 033a7f13 | - |
| weapon_gatlingm | 033a7f23 | - |
| weapon_gatlingzhc | 033a7f35 | - |

### Grenades & explosives

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_flashbang | 033a7e66 | - |
| weapon_hegrenade | 033a80e1 | - |
| weapon_smokegrenade | 033a92e9 | - |
| weapon_c4 | 033a79ae | - |
| weapon_rpg7 | 033a8f1a | - |
| weapon_m32 | 033a8809 | - |
| weapon_m32brbot | 033a8819 | - |
| weapon_m32venom | 033a8829 | - |
| weapon_m79 | 033a8914 | - |
| weapon_m79g | 033a8920 | - |
| weapon_m79gs | 033a892d | - |
| weapon_m79gzhc | 033a893c | - |
| weapon_m79w | 033a8948 | - |
| weapon_m79zhc | 033a8956 | - |
| weapon_at4 | 033a7467 | - |
| weapon_at4ex | 033a7474 | - |
| weapon_bazooka | 033a7610 | - |
| weapon_bazooka_zs2 | 033a7623 | - |
| weapon_claymore | 033a7b1d | - |
| weapon_sbmine | 033a8fa3 | - |

### Event/Buff Weapons

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_buffak47 | 033a77ec | - |
| weapon_buffak47tw | 033a77fe | - |
| weapon_buffak47zhc | 033a7811 | - |
| weapon_buffaug | 033a7820 | - |
| weapon_buffawp | 033a782f | - |
| weapon_bufffiveseven | 033a7844 | - |
| weapon_buffm249 | 033a7854 | - |
| weapon_buffm249zhc | 033a7867 | - |
| weapon_buffm4a1 | 033a7877 | - |
| weapon_buffm4a1tw | 033a7889 | - |
| weapon_buffm4a1zhc | 033a789c | - |
| weapon_buffng7 | 033a78ab | - |
| weapon_buffsg552 | 033a78bc | - |
| weapon_buffsg552ex | 033a78cf | - |
| weapon_buffsg552zhc | 033a78e3 | - |
| weapon_bloodhunter | 033a7725 | - |
| weapon_bloodhunterzhc | 033a773b | - |
| weapon_divinetitan | 033a7cf1 | - |
| weapon_divinetitanex | 033a7d06 | - |

### Special Weapons (shared with mp.dll)

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_coilgun | 033a7b2c | - |
| weapon_drillgun | 033a7d16 | - |
| weapon_laserminigun | 033a84ef | - |
| weapon_lockongun | 033a859c | - |
| weapon_mountgun | 033a8be1 | - |
| weapon_plasmagun | 033a8da7 | - |
| weapon_poisongun | 033a8dcc | - |
| weapon_railgun | 033a8ea0 | - |
| weapon_revivegun | 033a8ed6 | - |
| weapon_sfgun | 033a9002 | - |
| weapon_snakegun | 033a92f9 | - |
| weapon_speargun | 033a93bf | - |
| weapon_speargunex | 033a93d1 | - |
| weapon_transformgun | 033a9682 | - |
| weapon_violingun | 033a97c3 | - |
| weapon_vxljunkgun | 033a98e8 | - |
| weapon_vxllonggun | 033a98fa | - |
| weapon_vxlminigun | 033a990b | - |
| weapon_vxlshortgun | 033a9942 | - |
| weapon_watergun | 033a99bc | - |
| weapon_winggun | 033a99ef | - |

### Hero/Grenade Launchers

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_balrog1 | 033a7509 | - |
| weapon_balrog11 | 033a7518 | - |
| weapon_balrog11b | 033a7528 | - |
| weapon_balrog11zhc | 033a7539 | - |
| weapon_balrog1b | 033a754c | - |
| weapon_balrog1zhc | 033a755c | - |
| weapon_balrog3 | 033a756e | - |
| weapon_balrog3b | 033a757d | - |
| weapon_balrog3zhc | 033a758d | - |
| weapon_balrog5 | 033a759f | - |
| weapon_balrog5b | 033a75ae | - |
| weapon_balrog5zhc | 033a75bf | - |
| weapon_balrog7 | 033a75d0 | - |
| weapon_balrog7b | 033a75df | - |
| weapon_balrog7zhc | 033a75ef | - |
| weapon_cannon | 033a79bf | - |
| weapon_cannonex | 033a79cd | - |
| weapon_cannonexgold | 033a79dd | - |
| weapon_cannonm | 033a79f1 | - |
| weapon_cannonmzhc | 033a7a00 | - |
| weapon_cannonzhc | 033a7a12 | - |
| weapon_thanatos1 | 033a952e | - |
| weapon_thanatos11 | 033a953f | - |
| weapon_thanatos11zhc | 033a9551 | - |
| weapon_thanatos3 | 033a9566 | - |
| weapon_thanatos5 | 033a9577 | - |
| weapon_thanatos5zhc | 033a9588 | - |
| weapon_thanatos7 | 033a959c | - |
| weapon_thanatos7zhc | 033a95ad | - |
| weapon_vulcanus1 | 033a9819 | - |
| weapon_vulcanus11 | 033a982e | - |
| weapon_vulcanus11zhc | 033a983e | - |
| weapon_vulcanus1zhc | 033a9852 | - |
| weapon_vulcanus3 | 033a9867 | - |
| weapon_vulcanus3zhc | 033a9878 | - |
| weapon_vulcanus5 | 033a988c | - |
| weapon_vulcanus5zhc | 033a989d | - |
| weapon_vulcanus7 | 033a98b1 | - |
| weapon_vulcanus7zhc | 033a98c2 | - |
| weapon_janus1 | 033a82a1 | - |
| weapon_janus11 | 033a82af | - |
| weapon_janus11zhc | 033a82d0 | - |
| weapon_janus1zhc | 033a82e1 | - |
| weapon_janus3 | 033a82ef | - |
| weapon_janus3zhc | 033a8300 | - |
| weapon_janus5zhc | 033a8311 | - |
| weapon_janus7 | 033a8321 | - |
| weapon_janus7xmas | 033a8331 | - |
| weapon_janus7zhc | 033a8342 | - |
| weapon_janusmk5 | 033a8352 | - |
| weapon_kronos1 | 033a842e | - |
| weapon_kronos12 | 033a843e | - |
| weapon_kronos12ex | 033a8450 | - |
| weapon_kronos3 | 033a845f | - |
| weapon_kronos5 | 033a846e | - |
| weapon_kronos7 | 033a847d | - |
| weapon_turbulent1 | 033a96eb | - |
| weapon_turbulent11 | 033a96fe | - |
| weapon_turbulent3 | 033a9710 | - |
| weapon_turbulent5 | 033a9722 | - |
| weapon_turbulent7 | 033a9734 | - |
| weapon_skull1 | 033a916b | - |
| weapon_skull11 | 033a9179 | - |
| weapon_skull11zhc | 033a9188 | - |
| weapon_skull1zhc | 033a919a | - |
| weapon_skull2 | 033a91ab | - |
| weapon_skull3 | 033a91b9 | - |
| weapon_skull3d | 033a91c7 | - |
| weapon_skull3dzhc | 033a91d6 | - |
| weapon_skull3zhc | 033a91e8 | - |
| weapon_skull4 | 033a91f9 | - |
| weapon_skull4zhc | 033a9207 | - |
| weapon_skull5 | 033a9218 | - |
| weapon_skull5zhc | 033a9226 | - |
| weapon_skull6 | 033a9237 | - |
| weapon_skull6zhc | 033a9245 | - |
| weapon_skull7zhc | 033a9256 | - |
| weapon_skull8 | 033a9267 | - |
| weapon_skull8zhc | 033a9275 | - |

### Cross-Season Weapons (Y19-Y26)

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_y19s2dbarrel | 033a9aa0 | - |
| weapon_y19s2m1887 | 033a9ab2 | - |
| weapon_y19s2mauserc96 | 033a9ac8 | - |
| weapon_y19s2mosin | 033a9ada | - |
| weapon_y19s2python | 033a9aed | - |
| weapon_y19s2spmg | 033a9afe | - |
| weapon_y19s3bizon | 033a9b10 | - |
| weapon_y19s3coilmg | 033a9b23 | - |
| weapon_y19s3groza | 033a9b35 | - |
| weapon_y19s3m200 | 033a9b46 | - |
| weapon_y19s3m79 | 033a9b56 | - |
| weapon_y19s3rpg7 | 033a9b67 | - |
| weapon_y19s3uts15 | 033a9b79 | - |
| weapon_y19s4automag | 033a9b8d | - |
| weapon_y19s4dualkriss | 033a9ba3 | - |
| weapon_y19s4mk48 | 033a9bb4 | - |
| weapon_y19s4psg1 | 033a9bc5 | - |
| weapon_y19s4railcannon | 033a9bdc | - |
| weapon_y19s4tar21 | 033a9bee | - |
| weapon_y20s1bow | 033a9bfd | - |
| weapon_y20s1m1garand | 033a9c13 | - |
| weapon_y20s1musket | 033a9c26 | - |
| weapon_y20s2scara | 033a9c38 | - |
| weapon_y20s2scarb | 033a9c4a | - |
| weapon_y20s2scarc | 033a9c5c | - |
| weapon_y20s2scard | 033a9c6e | - |
| weapon_y20s3plasmaexa | 033a9c84 | - |
| weapon_y20s3plasmaexb | 033a9c9a | - |
| weapon_y20s3plasmaexc | 033a9cb0 | - |
| weapon_y20s3plasmaexd | 033a9cc6 | - |
| weapon_y21s1jetgunma | 033a9cdb | - |
| weapon_y21s1jetgunmb | 033a9cf0 | - |
| weapon_y21s1jetgunmc | 033a9d05 | - |
| weapon_y21s1jetgunmd | 033a9d1a | - |
| weapon_y21s2lockongunma | 033a9d32 | - |
| weapon_y21s2lockongunmb | 033a9d4a | - |
| weapon_y21s2lockongunmc | 033a9d62 | - |
| weapon_y21s2lockongunmd | 033a9d7a | - |
| weapon_y21s3cannonexma | 033a9d91 | - |
| weapon_y21s3cannonexmb | 033a9da8 | - |
| weapon_y21s3cannonexmc | 033a9dbf | - |
| weapon_y21s3cannonexmd | 033a9dd6 | - |
| weapon_y21s4janusa | 033a9de9 | - |
| weapon_y21s4janusb | 033a9dfc | - |
| weapon_y21s4janusc | 033a9e0f | - |
| weapon_y21s4janusd | 033a9e22 | - |
| weapon_y22s1crossbowex21mc | 033a9e3d | - |
| weapon_y22s1waterpistolma | 033a9e57 | - |
| weapon_y22s2lunarcannon | 033a9e6f | - |
| weapon_y22s2sfpistol | 033a9e84 | - |
| weapon_y22s3bufffiveseven | 033a9e9e | - |
| weapon_y22s3janus7 | 033a9eb1 | - |
| weapon_y23s1dartpistol | 033a9ec8 | - |
| weapon_y23s1sfmg | 033a9ed9 | - |
| weapon_y23s1sfsmg | 033a9eeb | - |
| weapon_y23s2buffaug | 033a9eff | - |
| weapon_y23s2dfpistol | 033a9f14 | - |
| weapon_y23s2sl8 | 033a9f24 | - |
| weapon_y23s3buffm249 | 033a9f39 | - |
| weapon_y23s3sapientia | 033a9f4f | - |
| weapon_y23s3sfsniper | 033a9f64 | - |
| weapon_y24s1crow1 | 033a9f76 | - |
| weapon_y24s1ethereal | 033a9f8b | - |
| weapon_y24s1laserminigun | 033a9fa4 | - |
| weapon_y24s2mg3 | 033a9fb4 | - |
| weapon_y24s2skull2 | 033a9fc7 | - |
| weapon_y24s2usas12 | 033a9fda | - |
| weapon_y24s3balrog7 | 033a9fee | - |
| weapon_y24s3kingcobra | 033aa004 | - |
| weapon_y24s3p90 | 033aa014 | - |
| weapon_y25s1sfgun | 033aa026 | - |
| weapon_y25s1turbulent1 | 033aa03d | - |
| weapon_y25s2hk121 | 033aa04f | - |
| weapon_y25s2sfsmg | 033aa061 | - |
| weapon_y25s2vulcanus1 | 033aa077 | - |
| weapon_y25s3m249ex | 033aa08a | - |
| weapon_y25s3python | 033aa09d | - |
| weapon_y25s3sflaser | 033aa0b1 | - |
| weapon_y25s4deagle | 033aa0c4 | - |
| weapon_y25s4f2000 | 033aa0d6 | - |
| weapon_y25s4uts15 | 033aa0e8 | - |
| weapon_y26s1deagleD | 033aa0fc | - |
| weapon_y26s1m32 | 033aa10c | - |
| weapon_y26s1plasmagun | 033aa122 | - |

### Utility/Other

| Weapon | Address | Class |
|--------|---------|-------|
| weapon_knife | 033a8402 | - |
| weapon_tknife | 033a9623 | - |
| weapon_tknifeex | 033a9631 | - |
| weapon_tknifeex2 | 033a9641 | - |
| weapon_19s1m24 | 01e97600 | - |
| weapon_19s1m950 | 01e9c9d0 | - |
| weapon_19s1mp5 | 01e9f3a0 | - |
| weapon_19s1usas12 | 01ea4470 | - |
| weapon_accelerator | 01f199d0 | - |
| weapon_airburster | 01f21c10 | - |
| weapon_airbursterzhc | 01f21c80 | - |
| weapon_bow | 01fae8d0 | - |
| weapon_boww | 01fafff0 | - |
| weapon_crossbow | 033a7b5a | - |
| weapon_crossbowcls | 033a7b6d | - |
| weapon_crossbowex | 033a7b7f | - |
| weapon_crossbowex21 | 033a7b93 | - |
| weapon_crossbowzhc | 033a7ba6 | - |
| weapon_huntbow | 033a8156 | - |
| weapon_huntgrenade | 033a8169 | - |
| weapon_huntgrenade1 | 033a817d | - |
| weapon_huntgrenade2 | 033a8191 | - |
| weapon_huntgrenade3 | 033a81a5 | - |
| weapon_huntgrenade4 | 033a81b9 | - |
| weapon_huntgrenade6 | 033a81cd | - |
| weapon_musket | 033a8c87 | - |
| weapon_mosin | 033a8bc4 | - |
| weapon_m1garand | 033a8787 | - |
| weapon_thompson | 033a95d1 | - |
| weapon_thompsongold | 033a95e5 | - |
| weapon_thompsongoldzhc | 033a95fc | - |
| weapon_thompsongs | 033a960e | - |
| weapon_stenmk2 | 033a9488 | - |
| weapon_sterlingbayonet | 033a949f | - |
| weapon_catapult | 033a7a75 | - |
| weapon_firecracker | 033a7e18 | - |
| weapon_fireextinguisher | 033a7e30 | - |
| weapon_jumpspirit | 033a8392 | - |
| weapon_patroldrone | 033a8d2b | - |
| weapon_pesticidesprayer | 033a8d43 | - |
| weapon_petrolboomer | 033a8d57 | - |
| weapon_ozwpnset1 | 033a8cd0 | - |
| weapon_ozwpnset2 | 033a8ce1 | - |
| weapon_monkeywpnset1 | 033a8bac | - |
| weapon_monkeywpnset2 | 033a8bc1 | - |
| weapon_cartblueC | 033a7a34 | - |
| weapon_cartblueS | 033a7a45 | - |
| weapon_cartredH | 033a7a55 | - |
| weapon_cartredL | 033a7a65 | - |
| weapon_19s1infinityex2 | 01e94b70 | - |

### Variant Suffixes

Many weapons have variants with these suffixes:
- **G** = Gold variant
- **L, L2, L3** = Camo/limited variants
- **Ex** = Enhanced variant
- **Zhc** = China exclusive
- **Tw** = Taiwan exclusive
- **Se** = Special edition
- **B, B2** = Blue variant
- **Dragon** = Dragon skin
- **Red** = Red skin
- **Craft** = Craftable version
- **Xmas** = Christmas variant
- **Tiger** = Tiger stripe

---

## Entity Hierarchy

```
CBaseEntity
  └── CBaseAnimating
        └── CBaseToggle
              └── CBasePlayerItem
                    └── CBasePlayerWeapon
                          ├── CAK47
                          ├── CAWP
                          ├── CM4A1
                          ├── [all retail weapons]
                          └── [mp.dll shared special weapons]
```

---

## Key Field Offsets

Same as mp.dll base constructor:
- 0x1c: byte (active flag)
- 0x1e-0x35: ammo counts and state flags
- 0x36: pointer (ammo ref count)
- 0x39: 0xbf800000 (-1.0f default)
- 0x3c: 0xbf800000 (-1.0f default)
- 0x46: primary ammo count
- 0x69-0x82: weapon-specific state

(End of file - total lines)