# CSO Voxel Code Extracted from Nexon GoldSrc DLLs

## Architecture Overview
- `hw.dll` (Nexon GoldSrc fork) - Core voxel system: CVoxelWorld, CVoxelDoc, CVoxelChunk, CVoxelSection, CVoxelClient
- `mp.dll` (Server game logic) - VoxelEntity, VoxelMonster AI, CVoxelSpawn, entity collision handlers
- `client.dll` (Client UI) - IVoxelPropertyEditor (90+ implementations), VoxelScriptBasePanel, VoxelPropertySheet

## Voxel Entity Types (from IVoxelPropertyEditor implementations in client.dll)
- CVoxelDoor, CVoxelPlayerSpawn, CVoxelTextboard, CVoxelPiston, CVoxelPush
- CVoxelToggleGate, CVoxelDelayGate, CVoxelBlinkGate, CVoxelItemSpawn, CVoxelItemChecker
- CVoxelReadingMemoBook, CVoxelReadingComputer, CVoxelWeaponSpawner, CVoxelCountDown
- CVoxelAnnounce, CVoxelSwitch, CVoxelMonsterSpawner, CVoxelItemSynthesizer
- CVoxelItemDisassembler, CVoxelC4Bomb, CVoxelPortal, CVoxelButton, CVoxelHitTarget
- CVoxelMP3, CVoxelEmitSound, CVoxelTransit, CStudioWeaponSpawner, CVoxelQuestNPC
- Plus 65+ more implementations

## Server-Side Voxel Functions (from mp.dll)
- `voxel_monster_*` - Various monster types (zombie, boomer, ghost, turret, etc.)
- `voxelShEnt*` - Shared entity handlers (Warehouse, SpiderMine, TrapTrigger)
- `voxelspawn` - Creates CVoxelSpawn entity with vftable at offset 0xb8
- `RocketTouch_Voxel` - Airstrike rocket collision with voxels
- `ThrowingKnifeEntity::FlyingTouch` - Knife collision with voxels

## Architecture Overview
- `hw.dll` is Nexon's GoldSrc fork - contains core voxel system
- Voxel file format uses `.vxl` extension
- Key classes: CVoxelWorld, CVoxelDoc, CVoxelChunk, CVoxelSection, CVoxelClient, VoxelHTTP

## .vxl File Format
- Magic header check: `0x766f7363 0x2e2e2e2e 0x1337ad9` (likely "vos....." + version)
  - `0x766f7363` = 'v', 'o', 's', 'c' (possibly "svoc" or "cvos" in little-endian)
  - `0x2e2e2e2e` = "...."
  - `0x1337ad9` = version identifier
- File loading uses LZMA compression (mentioned in CVoxelDoc::Load::Voxel_LzmaUncompress)

## Key Functions

---

### CVoxelWorld::Load_S (voxel world loading) at 02261b70

```c
/* WARNING: Function: __security_check_cookie replaced with injection: security_check_cookie */
/* WARNING: Type propagation algorithm not settling */

void FUN_02261b70(void)

{
  bool bVar1;
  char cVar2;
  int *piVar3;
  HLOCAL pvVar4;
  DWORD dwMessageId;
  int iVar5;
  LPCWSTR ******pppppppWVar6;
  wchar_t *pwVar7;
  int *piVar8;
  undefined4 *puVar9;
  undefined ***pppuVar10;
  int iVar11;
  undefined ***pppuVar12;
  char *lpOutputString;
  undefined **local_1e0 [4];
  undefined **local_1d0 [14];
  undefined4 local_198;
  wchar_t local_194;
  undefined1 local_192;
  undefined4 local_190;
  undefined4 local_18c;
  undefined1 local_188;
  FILE *local_184;
  wchar_t *local_180;
  wchar_t *local_17c;
  basic_ios<wchar_t,struct_std::char_traits<wchar_t>_> local_170 [72];
  undefined4 local_128;
  HLOCAL local_124;
  LPCWSTR ******local_120 [5];
  uint local_10c;
  CHAR local_108 [255];
  undefined1 local_9;
  uint local_8;
  
  local_8 = DAT_02d74c80 ^ (uint)&stack0xfffffffc;
  if (DAT_02e5518c == 0) {
    return;
  }
  if (DAT_03e30c70 != 0) {
    piVar3 = (int *)FUN_021308d0();
    (**(code **)(*piVar3 + 0xfc))(local_120);
    memset(local_108,0,0x100);
    pppppppWVar6 = (LPCWSTR ******)local_120;
    if (7 < local_10c) {
      pppppppWVar6 = local_120[0];
    }
    WideCharToMultiByte(0xfde9,0,(LPCWSTR)pppppppWVar6,-1,local_108,0xff,(LPCSTR)0x0,(LPBOOL)0x0);
    local_9 = 0;
    FUN_026d0120("Voxel_LoadWorld(%s)\n",local_108);
    pvVar4 = (HLOCAL)PathFileExistsA(local_108);
    if (pvVar4 == (HLOCAL)0x0) {
      local_124 = pvVar4;
      dwMessageId = GetLastError();
      FormatMessageA(0x1300,(LPCVOID)0x0,dwMessageId,0x409,(LPSTR)&local_124,0,(va_list *)0x0);
      if (local_124 != (HLOCAL)0x0) {
        FUN_026d0120("Last Error : %s\n",local_124);
      }
      LocalFree(local_124);
    }
    iVar11 = 0;
    local_1e0[0] = &PTR_02aebfc4;
    pppppppWVar6 = (LPCWSTR ******)local_120;
    if (7 < local_10c) {
      pppppppWVar6 = local_120[0];
    }
    std::basic_ios<wchar_t,struct_std::char_traits<wchar_t>_>::
    basic_ios<wchar_t,struct_std::char_traits<wchar_t>_>(local_170);
    std::basic_istream<wchar_t,struct_std::char_traits<wchar_t>_>::
    basic_istream<wchar_t,struct_std::char_traits<wchar_t>_>
              ((basic_istream<wchar_t,struct_std::char_traits<wchar_t>_> *)local_1e0,
               (basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_> *)local_1d0,false);
    *(undefined ***)((int)local_1e0 + (int)local_1e0[0][1]) =
         std::basic_ifstream<wchar_t,struct_std::char_traits<wchar_t>_>::vftable;
    *(undefined **)((int)local_1d0 + (int)(local_1e0[0][1] + -0x14)) = local_1e0[0][1] + -0x70;
    std::basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_>::
    basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_>
              ((basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_> *)local_1d0);
    local_1d0[0] = std::basic_filebuf<wchar_t,struct_std::char_traits<wchar_t>_>::vftable;
    local_188 = 0;
    local_192 = 0;
    std::basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_>::_Init
              ((basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_> *)local_1d0);
    local_18c = DAT_02e55218;
    local_184 = (FILE *)0x0;
    local_190 = DAT_02e55214;
    local_198 = 0;
    iVar5 = FUN_02258f10(pppppppWVar6,1,0x40);
    if (iVar5 == 0) {
      std::basic_ios<wchar_t,struct_std::char_traits<wchar_t>_>::setstate
                ((basic_ios<wchar_t,struct_std::char_traits<wchar_t>_> *)local_170,2,false);
    }
    bVar1 = std::ios_base::good((ios_base *)local_170);
    while (!bVar1) {
      Sleep(1000);
      iVar5 = FUN_022565c0();
      if (iVar5 == 0) {
        std::basic_ios<wchar_t,struct_std::char_traits<wchar_t>_>::setstate
                  ((basic_ios<wchar_t,struct_std::char_traits<wchar_t>_> *)local_170,2,false);
      }
      pppppppWVar6 = (LPCWSTR ******)local_120;
      if (7 < local_10c) {
        pppppppWVar6 = local_120[0];
      }
      iVar5 = FUN_02258f10(pppppppWVar6,1,0x40);
      if (iVar5 == 0) {
        std::basic_ios<wchar_t,struct_std::char_traits<wchar_t>_>::setstate
                  ((basic_ios<wchar_t,struct_std::char_traits<wchar_t>_> *)local_170,2,false);
      }
      else {
        std::basic_ios<wchar_t,struct_std::char_traits<wchar_t>_>::clear
                  ((basic_ios<wchar_t,struct_std::char_traits<wchar_t>_> *)local_170,0,false);
      }
      iVar11 = iVar11 + 1;
      if (4 < iVar11) break;
      bVar1 = std::ios_base::good((ios_base *)local_170);
    }
    bVar1 = std::ios_base::good((ios_base *)local_170);
    if (!bVar1) {
      FUN_0241bc00("CAN'T OPEN VOXEL MAP FILE!!!!!");
    }
    if (local_184 == (FILE *)0x0) {
      local_188 = 0;
      local_192 = 0;
      std::basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_>::_Init
                ((basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_> *)local_1d0);
LAB_02261f3c:
      local_184 = (FILE *)0x0;
      local_198 = 0;
      local_190 = DAT_02e55214;
      local_18c = DAT_02e55218;
      std::basic_ios<wchar_t,struct_std::char_traits<wchar_t>_>::setstate
                ((basic_ios<wchar_t,struct_std::char_traits<wchar_t>_> *)local_170,2,false);
    }
    else {
      pwVar7 = std::basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_>::eback
                         ((basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_> *)local_1d0);
      if (pwVar7 == &local_194) {
        std::basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_>::setg
                  ((basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_> *)local_1d0,local_180
                   ,local_180,local_17c);
      }
      cVar2 = FUN_0224f100();
      pppuVar10 = local_1d0;
      if (cVar2 == '\0') {
        pppuVar10 = (undefined ***)0x0;
      }
      iVar11 = fclose(local_184);
      local_188 = 0;
      local_192 = 0;
      pppuVar12 = (undefined ***)0x0;
      if (iVar11 == 0) {
        pppuVar12 = pppuVar10;
      }
      std::basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_>::_Init
                ((basic_streambuf<wchar_t,struct_std::char_traits<wchar_t>_> *)local_1d0);
      local_184 = (FILE *)0x0;
      local_190 = DAT_02e55214;
      local_18c = DAT_02e55218;
      local_198 = 0;
      if (pppuVar12 == (undefined ***)0x0) goto LAB_02261f3c;
    }
    FUN_0223b890();
    FUN_01ea5d90();
  }
  piVar3 = (int *)FUN_021308d0();
  piVar8 = (int *)(**(code **)(*piVar3 + 0x174))();
  if (DAT_03e30c70 != 0) {
    local_128 = 0;
    local_124 = (HLOCAL)0x0;
    puVar9 = (undefined4 *)(**(code **)(*piVar3 + 0xfc))(local_120);
    if (7 < (uint)puVar9[5]) {
      puVar9 = (undefined4 *)*puVar9;
    }
    cVar2 = FUN_02156970(puVar9,&local_128,&local_124);
    FUN_01ea5d90();
    if (cVar2 == '\0') {
      FUN_026d0120("CVoxelWorld::Load_S::FileReadWholeW() failed.\n");
      goto LAB_02262051;
    }
    FUN_01ea62f0(local_128,local_124);
  }
  if (piVar8[4] != 0) {
    piVar3 = piVar8;
    if (0xf < (uint)piVar8[5]) {
      piVar3 = (int *)*piVar8;
    }
    if ((*piVar3 == 0x766f7363) && (piVar3[1] == 0x2e2e2e2e)) {
      if (piVar3[2] == 0x1337ad9) {
        cVar2 = FUN_022458d0(piVar8);
        if (cVar2 != '\0') {
          return;
        }
        goto LAB_02262051;
      }
      lpOutputString = "CVoxelWorld::Load(): unknown version\n";
    }
    else {
      lpOutputString = "CVoxelWorld::Load::wrong header.\n";
    }
    OutputDebugStringA(lpOutputString);
  }
LAB_02262051:
  FUN_0223c520();
  return;
}
```

Key observations:
- File path passed via `Voxel_LoadWorld(%s)` debug print
- Magic header check: `0x766f7363 0x2e2e2e2e 0x1337ad9`
- Uses LZMA decompression via `FUN_02156970` and `FUN_01ea62f0`
- Actual parsing delegated to `FUN_022458d0`

---

### CVoxelWorld Loading variant at 02246660

```c
uint FUN_02246660(void)
{
  char cVar1;
  int *piVar2;
  int *piVar3;
  undefined4 *puVar4;
  int *piVar5;
  uint uVar6;
  int *extraout_EAX;
  char *lpOutputString;
  undefined4 local_34;
  undefined4 local_30;
  undefined1 local_2c [24];
  uint local_14;
  void *local_10;
  undefined1 *puStack_c;
  undefined4 local_8;
  
  // ... similar structure, same magic number check ...
  
  if ((*piVar5 == 0x766f7363) && (piVar5[1] == 0x2e2e2e2e)) {
      if (piVar5[2] == 0x1337ad9) {
        uVar6 = FUN_022458d0(piVar3);
        // ...
      }
  }
}
```

---

## Voxel String References (from hw.dll)

### File Format Strings
- `"voxel/voxel_cubeconvertrate.csv"` - cube conversion rates
- `".vxl"` - file extension
- `"map.vxl"` - default map file name
- `"voxel/voxel_list"` - voxel definition list
- `"voxel/voxel_item"` - voxel items

### Client Settings (CVars)
- `"cl_vxl_dist"` - voxel render distance
- `"cl_vxl_coord"` - coordinate display
- `"cl_vxl_hidevmdl"` - hide voxel models

### Class Names (RTTI)
- `.?AVCVoxelWorld@@` - CVoxelWorld class
- `.?AVCVoxelDoc@@` - CVoxelDoc class  
- `.?AVCVoxelChunk@@` - CVoxelChunk class
- `.?AVCVoxelSection@@` - CVoxelSection class
- `.?AVCVoxelClient@@` - CVoxelClient class
- `.?AVIVoxelClient@@` - IVoxelClient interface
- `.?AVVoxelHTTP@@` - VoxelHTTP class
- `.?AVCVoxelAdapter@@` - CVoxelAdapter class
- `.?AVCVoxelAreaMgr@@` - CVoxelAreaMgr class
- `.?AVCVoxelLightChunk@@` - CVoxelLightChunk class
- `.?AVCVoxelBillBoard@@` - CVoxelBillBoard class
- `.?AVVoxelParticlePool@@` - VoxelParticlePool class
- `.?AVCVoxelItemPropMgr@@` - CVoxelItemPropMgr class
- `.?AVCVoxelQuestNPCPropMgr@@` - CVoxelQuestNPCPropMgr class
- `.?AVCVoxelWeaponListMgr@@` - CVoxelWeaponListMgr class
- `.?AVCVoxelLinkRender@@` - CVoxelLinkRender class
- `.?AVCVoxelMdlRenderer@@` - CVoxelMdlRenderer class
- `.?AVIVoxelGameSave@@` - IVoxelGameSave interface
- `.?AVCVoxelGameSave@@` - CVoxelGameSave class
- `.?AVIVoxelHTTP@@` - IVoxelHTTP interface
- `.?AVIVoxelAdapter@@` - IVoxelAdapter interface

### Game Mode Enums
- `"EGM_VOXEL_CREATE"` - Voxel Create mode
- `"EGM_VOXEL_PVE"` - Voxel PVE mode
- `"EGM_VOXEL_PROPHUNT"` - Voxel Prop Hunt mode
- `"EGM_VOXEL_SHELTER"` - Voxel Shelter mode
- `"EGM_VOXEL_SCENARIOTX"` - Voxel Scenario TX mode

### Model Paths
- `"models/vxlshelter/shelter_b_shelter03.mdl"` - shelter models
- `"models/voxel/common/common_a_tr_partner01.mdl"` - common voxel models
- `"models/voxel/coin.mdl"` - coin model

### UI/Resource Paths
- `"voxel/OutUI/vxltrophy.webm"` - trophy video
- `"voxel/play/damage_field.tga"` - damage field texture
- `"voxel/play/rect_rain.tga"` - rain effect texture
- `"voxel/play/shadow.tga"` - shadow texture
- `"resource/voxel/e_use.tga"` - use icon
- `"resource/voxel/e_simulate.tga"` - simulate icon
- `"resource/voxel/x_edit.tga"` - edit icon

### Debug/Error Strings
- `"CVoxelWorld::Load_S::FileReadWholeW() failed.\n"`
- `"CVoxelWorld::Load::wrong header.\n"`
- `"CVoxelWorld::Load(): unknown version\n"`
- `"CVoxelDoc::Load::VOXEL_FORMAT_ID/VOXEL_VERSION failed.\n"`
- `"CVoxelDoc::Load::Voxel_LzmaUncompress failed.\n"`
- `"CVoxelDoc::Load::Parse failed.\n"`
- `"CVoxelDoc::HandleError::%s::%s\n"`
- `"VOXEL_HTTP : [%s] Exception (%s)\n"`
- `"Voxel_LoadWorld(%s)\n"`
- `"CAN'T OPEN VOXEL MAP FILE!!!!!\n"`

### Network Strings
- `"svc_voxel"` - network service message

### Entity Classes (from RTTI)
- `.?AVC_VoxelReplica@@` - Voxel replica
- `.?AVC_VoxelSoccerGoalNet@@` - Soccer goal
- `.?AVC_VoxelSoccerBallSpawn@@` - Ball spawn point
- `.?AVC_VoxelBreakableProp@@` - Breakable prop
- `.?AVC_VoxelSelectRandomProp@@` - Random prop selector
- `.?AVC_VoxelC4TargetArea@@` - C4 target
- `.?AVC_VoxelBuyZone@@` - Buy zone
- `.?AVC_VoxelMainShelter@@` - Main shelter
- `.?AVC_VoxelPartner@@` - Partner entity
- `.?AVC_VoxelPlayerSpawn@@` - Player spawn

### Additional Classes
- `.?AVVoxelDLight@@` - Dynamic light
- `.?AVCVoxelDmgFieldFx@@` - Damage field effect
- `.?AVVoxelParticleEmitter@@` - Particle emitter
- `.?AVCVoxelDmgFieldFxMgr@@` - Damage field manager
- `.?AVVoxelParticle@@` - Particle
- `.?AVIVoxelItemProp@@` - Item property interface
- `.?AVSVoxelQuestNPCProp@@` - Quest NPC property
- `.?AVCVoxelItemProp@@` - Item property
- `.?AVVoxelChatListener@BBVxlChat@@` - Chat listener

---

## VoxelChunkRenderer Functions (from strings)
- `VoxelChunkRenderer::PushVertices` at 02b5f5f8
- `VoxelChunkRenderer::PushTexOffset` at 02b5f61c
- `VoxelChunkRenderer::PushLight` at 02b5f640
- `VoxelChunkRenderer::SetRenderParam` at 02b5f660
- `VoxelChunkRenderer::Render` at 02b5f684

---

## VoxelHTTP API (from strings)
- `VoxelHTTP::RequestSlotDownload`
- `VoxelHTTP::RequestCube`
- `VoxelHTTP::ParseCube`
- `VoxelHTTP::RequestLocaleList`
- `VoxelHTTP::RequestDownloadLocale`
- `VoxelHTTP::RequestDownloadLocale_1`
- `VoxelHTTP::RequestDownloadLocale_2`
- `VoxelHTTP::UploadLocale`
- `VoxelHTTP::PostCreateLog`
- `VoxelHTTP::ParseHistoryInfo`
- `VoxelHTTP::RequestImageDownload`
- `VoxelHTTP::RequestImageUpload`
- `VoxelHTTP::RequestMapUpload`
- `VoxelHTTP::RequestMapUploadWithFile`
- `VoxelHTTP::RequestMapListForMain`
- `VoxelHTTP::RequestMapOneDetail`
- `VoxelHTTP::RequestMapListWithType`
- `VoxelHTTP::RequestMapListFromGameServer`
- `VoxelHTTP::RequestMapListDetail`
- `VoxelHTTP::RequestTemplateMap`
- `VoxelHTTP::ParseMapListForMain`
- `VoxelHTTP::ParseMapListSimple`
- `VoxelHTTP::ParseMapListDetail`
- `VoxelHTTP::ParseMapOneDetail`
- `VoxelHTTP::TestConnect`
- `VoxelHTTP::ParseUploadLocation`
- `VoxelHTTP::RequestHistoryInfo`
- `VoxelHTTP::RequestCheerList`
- `VoxelHTTP::PostRequestMapList`
- `VoxelHTTP::PostRequestNotificationCount`

---

## VoxelProp JSON Schema (from strings)
- `voxel/VoxelProp.json`
- Keys: `VoxelProps`, `VoxelID`, `VoxelEntityType`, `VoxelMoveType`, `VoxelLightType`, `VoxelDisplayType`, `VoxelExitType`, `VoxelBlendType`, `VoxelBillBoardType`, `VoxelDamageToType`, `VoxelDarkMatType`, `VoxelRenderType`

---

---

## CVoxelWorld Constructor at 022379b0

```c
undefined4 * __thiscall FUN_022379b0(undefined4 *param_1, undefined4 param_2)
{
  // CVoxelWorld constructor - massive initialization function
    
  *param_1 = CVoxelWorld::vftable;
  
  // Initialize multiple chunk lists (7 types/sublayers)
  param_1[9] = 0x3f800000;  // Default scale = 1.0f
  param_1[0xf] = 7;         // 7 layers
  param_1[0x10] = 8;
  
  // Creates chunk arrays via nested loops:
  // local_20[0] loops 0x18 (24) times
  // local_20[1] loops 0x18 (24) times  
  // local_20[2] loops 0xc (12) times
  // Creates VoxelChunk grid: 24 x 12 x 12 = 3456 chunks total
  
  // Chunk memory at param_1[0x2c] with size 0x1b00 (6912 bytes)
  
  // Material/texture indices initialized:
  // 0x101 (257) - some default material
  // Material IDs: 3, 0x43 (67), 0x4f (79), 0x45 (69), 0x5b (91), etc.
  
  // Default palette colors initialized:
  param_1[0x4e] = 0x435d0000;  // R=61, G=93
  param_1[0x4f] = 0x435f0000;  // R=95, G=111
  param_1[0x50] = 0x43660000;  // R=102, G=102
  *(undefined2 *)((int)param_1 + 0x147) = 0xffff;
  *(undefined1 *)((int)param_1 + 0x149) = 0xff;
  *(undefined2 *)(param_1 + 0x51) = 0x8000;
}
```

Key observations:
- VoxelWorld creates a 24x12x12 grid of VoxelChunks
- Multiple chunk layers (7 sublayers) for different data (lighting, materials, etc.)
- Default palette with RGB values
- Multiple material IDs for different block types
- Uses memory pools for chunk allocation

---

## CVoxelWorld vftable

### vftable Location
- Address: `02aeb5fc`
- Set at constructor offset: `*param_1 = CVoxelWorld::vftable` (at 022379e8)

### vftable Entries (partial)
| Offset | Address | Function |
|--------|---------|----------|
| +0x00 | 0223c120 | CVoxelWorld destructor (calls FUN_02809b8c with size 0xe30) |
| +0x04 | 02c26a00 | Unknown (follows pattern of first destructor) |
| +0x08 | 0223bf50 | Unknown |

### Static Data Section (02aeb5fc)
Following the vftable entries, this address contains string constants used by CVoxelWorld methods:
- `"Start Create VoxelWorld(%d)"`
- `"VoxelChunk Created(%d)"`
- `"End Create VoxelWorld(%d)"`
- `"Destroy VoxelWorld(%d)"`
- `"LightChunk(%d) is not allocated"`
- `"LightChunk(%d) index is wrong"`
- `"pChunk->Decompress FAIL (%d, %d, %d, %d, %d)."`
- And many more chunk/render related strings

### RTTI References
- CVoxelWorld RTTI: `.?AVCVoxelWorld@@` at 02d9e764
- RTTI pointer after class name: `08 43 b9 02` = 0x02b94308 (shared vftable offset reference)

---

## CVoxelDoc::Load at 021550b0

```c
undefined4 __thiscall FUN_021550b0(int param_1, int *param_2)
{
  int *piVar4;
  void *_Memory;
  int iVar3;
  int local_8;
  
  piVar4 = param_2;
  if (0xf < (uint)param_2[5]) {
    piVar4 = (int *)*param_2;
  }
  local_8 = param_1;
  
  // Magic header check: 0x766f7363 0x2e2e2e2e 0x1337ad9
  if (((*piVar4 == 0x766f7363) && (piVar4[1] == 0x2e2e2e2e)) && (piVar4[2] == 0x1337ad9)) {
    piVar4 = param_2;
    if (0xf < (uint)param_2[5]) {
      piVar4 = (int *)*param_2;
    }
    piVar1 = param_2 + 4;
    if (8 < *piVar1 - 0xcU) {
      param_2 = (int *)piVar4[3];
      local_8 = *piVar1 + -0x15;
      _Memory = malloc((size_t)param_2);
      
      // LZMA decompression via FUN_02853b00
      iVar3 = FUN_02853b00(_Memory, &param_2, (int)piVar4 + 0x15, &local_8, piVar4 + 4, 5);
      
      if (iVar3 == 0) {
        *(void **)(param_1 + 8) = _Memory;
        *(int *)(param_1 + 0xc) = (int)param_2 + (int)_Memory;
        *(void **)(param_1 + 0x10) = _Memory;
        *(undefined4 *)(param_1 + 0x14) = 0;
        *(undefined4 *)(param_1 + 0x18) = 0;
        
        // Parse decompressed data
        cVar2 = FUN_02155270();
        if (cVar2 == '\0') {
          FUN_026d0120("CVoxelDoc::Load::Parse failed.\n");
          free(_Memory);
          return 0;
        }
        *(void **)(param_1 + 4) = _Memory;
        return 1;
      }
      free(_Memory);
    }
    param_2 = (int *)0x0;
    FUN_026d0120("CVoxelDoc::Load::Voxel_LzmaUncompress failed.\n");
    return 0;
  }
  FUN_026d0120("CVoxelDoc::Load::VOXEL_FORMAT_ID/VOXEL_VERSION failed.\n");
  return 0;
}
```

Key observations:
- `.vxl` file format uses LZMA compression
- Magic header: `0x766f7363 0x2e2e2e2e 0x1337ad9`
  - `0x766f7363` = 'v', 'o', 's', 'c' in little-endian = "cvos" or "svoc"
  - `0x2e2e2e2e` = "...."
  - `0x1337ad9` = version marker
- After decompression, parses text-based section format

---

## CVoxelDoc Parser at 02155270

```c
// Text-based section parser for CVoxelDoc
// Parses format with [SECTION] blocks containing key-value pairs
// Whitespace-aware parsing (spaces, tabs, newlines skipped)
// Handles error reporting with section and key names
```

---

## VoxelHTTP::RequestSlotDownload at 021b32b0

Large async HTTP download function for voxel map slots. Uses:
- Thread pool scheduler for async operations
- Lambda callbacks for completion handling
- Web HTTP API calls via `FUN_02187910`
- Ref-counted shared_ptr objects
- Multiple lock/unlock sequences for thread safety

---

## Voxel Global Class Hierarchy (RTTI Strings in hw.dll)

### Core Voxel Classes
| RTTI Name | Class Name | Purpose |
|-----------|------------|---------|
| `.?AVCVoxelWorld@@` | CVoxelWorld | Main voxel world container |
| `.?AVCVoxelDoc@@` | CVoxelDoc | .vxl file document (load/save) |
| `.?AVCVoxelChunk@@` | CVoxelChunk | Individual chunk (24x12x12 grid) |
| `.?AVCVoxelSection@@` | CVoxelSection | Section within chunk |
| `.?AVCVoxelClient@@` | CVoxelClient | Client-side voxel interface |
| `.?AVIVoxelClient@@` | IVoxelClient | Client interface base |
| `.?AVCVoxelSection@@` | CVoxelSection | Chunk section |
| `.?AVCVoxelLightChunk@@` | CVoxelLightChunk | Light data per chunk |

### Entity Classes
| RTTI Name | Class Name | Purpose |
|-----------|------------|---------|
| `.?AVC_VoxelReplica@@` | CVoxelReplica | Replicated entity |
| `.?AVC_VoxelSoccerGoalNet@@` | CVoxelSoccerGoalNet | Soccer goal |
| `.?AVC_VoxelSoccerBallSpawn@@` | CVoxelSoccerBallSpawn | Ball spawn |
| `.?AVC_VoxelBreakableProp@@` | CVoxelBreakableProp | Destructible prop |
| `.?AVC_VoxelSelectRandomProp@@` | CVoxelSelectRandomProp | Random selector |
| `.?AVC_VoxelRandomProp@@` | CVoxelRandomProp | Random prop |
| `.?AVC_VoxelC4TargetArea@@` | CVoxelC4TargetArea | C4 target |
| `.?AVC_VoxelBuyZone@@` | CVoxelBuyZone | Purchase zone |
| `.?AVC_VoxelMainShelter@@` | CVoxelMainShelter | Main shelter building |
| `.?AVC_VoxelPartner@@` | CVoxelPartner | Partner NPC |
| `.?AVC_VoxelPlayerSpawn@@` | CVoxelPlayerSpawn | Spawn point |

### Rendering Classes
| RTTI Name | Class Name | Purpose |
|-----------|------------|---------|
| `.?AVCVoxelBillBoard@@` | CVoxelBillBoard | Billboard sprite |
| `.?AVVoxelDLight@@` | VoxelDLight | Dynamic light |
| `.?AVCVoxelLinkRender@@` | CVoxelLinkRender | Render connections |
| `.?AVCVoxelMdlRenderer@@` | CVoxelMdlRenderer | Model renderer |

### Effect/Particle Classes
| RTTI Name | Class Name | Purpose |
|-----------|------------|---------|
| `.?AVVoxelParticleEmitter@@` | VoxelParticleEmitter | Particle system |
| `.?AVVoxelParticle@@` | VoxelParticle | Individual particle |
| `.?AVCVoxelDmgFieldFx@@` | CVoxelDmgFieldFx | Damage field effect |
| `.?AVCVoxelDmgFieldFxMgr@@` | CVoxelDmgFieldFxMgr | Effect manager |

### HTTP/Network Classes
| RTTI Name | Class Name | Purpose |
|-----------|------------|---------|
| `.?AVVoxelHTTP@@` | VoxelHTTP | HTTP client |
| `.?AVIVoxelHTTP@@` | IVoxelHTTP | HTTP interface |
| `.?AVCVoxelAdapter@@` | CVoxelAdapter | Server adapter |
| `.?AVIVoxelAdapter@@` | IVoxelAdapter | Adapter interface |
| `.?AVCVoxelAreaMgr@@` | CVoxelAreaMgr | Area manager |

### Game System Classes
| RTTI Name | Class Name | Purpose |
|-----------|------------|---------|
| `.?AVIVoxelGameSave@@` | IVoxelGameSave | Save interface |
| `.?AVCVoxelGameSave@@` | CVoxelGameSave | Save implementation |
| `.?AVIVoxelItemProp@@` | IVoxelItemProp | Item property interface |
| `.?AVCVoxelItemPropMgr@@` | CVoxelItemPropMgr | Item manager |
| `.?AVCVoxelWeaponListMgr@@` | CVoxelWeaponListMgr | Weapon list |
| `.?AVCVoxelQuestNPCPropMgr@@` | CVoxelQuestNPCPropMgr | Quest NPC manager |

### Singleton Classes
| RTTI Name | Class Name |
|-----------|------------|
| `.?AV?$CSingleton@VCVoxelClient@@@@` | CVoxelClient singleton |
| `.?AV?$CSingleton@VCVoxelAreaMgr@@@@` | CVoxelAreaMgr singleton |
| `.?AV?$CSingleton@VCVoxelItemPropMgr@@@@` | CVoxelItemPropMgr singleton |
| `.?AV?$CSingleton@VCVoxelQuestNPCPropMgr@@@@` | CVoxelQuestNPCPropMgr singleton |
| `.?AV?$CSingleton@VCVoxelWeaponListMgr@@@@` | CVoxelWeaponListMgr singleton |
| `.?AV?$CSingleton@VCVoxelLinkRender@@@@` | CVoxelLinkRender singleton |
| `.?AV?$CSingleton@VCVoxelMdlRenderer@@@@` | CVoxelMdlRenderer singleton |
| `.?AV?$CSingleton@VVoxelParticlePool@@@@` | VoxelParticlePool singleton |
| `.?AV?$CSingleton@VCVoxelCreateLogger@@@@` | CVoxelCreateLogger singleton |
| `.?AV?$CSingleton@VCVoxelDmgFieldFxMgr@@@@` | CVoxelDmgFieldFxMgr singleton |

---

## .vxl File Format Specification (Confirmed 2026-05-17)

### Header (21 bytes)
```
Bytes 0-3:   0x766f7363 ('v','o','s','c' in ASCII)
Bytes 4-7:   0x2e2e2e2e ('....' - padding)
Bytes 8-11:  0x1337ad9  (version marker, or 0x1337ae5 for global_data)
Bytes 12-15: original_size (uint32, little-endian)
Bytes 16-20: LZMA properties (5 bytes)
Bytes 21+:   LZMA compressed data
```

### Decompressed Data Structure (122049 bytes for sample 01778908768485013001.vxl)

The decompressed data is a **hybrid text/binary format** with sections:

#### 1. [global_data] Section (offset 0)
- **Format**: Text keys, **binary values** (not text!)
- Each line: `key:value_bytes`
- Value types determined by key name:

| Key | Value Type | Description |
|-----|------------|-------------|
| version | uint32 | Format version (0x1337ae5 = 20151013) |
| skyname | string | Sky texture name (text, null-terminated) |
| fog_color | float[3] | RGB fog color (12 bytes) |
| day_light | uint8[4] | Day lighting RGBA |
| inv_light | uint8[4] | Inverse lighting RGBA |
| gamemode | uint32 | EGM_VOXEL_* enum |
| playtime | uint32 | Time limit in seconds |
| respawn | uint8 | Respawn enabled flag |
| weather | uint8 | Weather type |
| maxplayernum | uint32 | Maximum players |
| fog_density.v2 | float | Fog density |
| vis_dist | float | Visibility distance |
| reset_trigger | uint8 | Reset on trigger flag |
| friendly_fire | uint8 | Friendly fire enabled |
| player_collision | uint8 | Player-vs-player collision |
| enable_tps | uint8 | Third person view enabled |
| minplayernum | uint32 | Minimum players |
| end_rule | uint32 | End rule type |
| init_back | uint8 | Initial back flag |
| human_destroy | uint8 | Humans can destroy |
| zombi_destroy | uint8 | Zombies can destroy |
| zombi_seethru | uint8 | Zombie see-through mode |
| fog_on | uint8 | Fog enabled |
| respawntime | uint32 | Respawn time in seconds |
| defeatbywipe | uint8 | Defeat by wipe condition |
| enemyfire | uint8 | Enemy fire enabled |
| seekerPenalty | uint32 | Seeker penalty score |
| hiderproplimit | uint32 | Max props for hiders |
| maxplaydate | uint32 | Max play date |
| maxlevel | uint32 | Max level |
| maxsheltertier | uint32 | Max shelter tier |
| shelterlastdaywin | uint8 | Last day win condition |
| shelterbuildrange | uint32 | Building range |
| shelterMonsterInfo | float[750] | 50 monster slots × 15 floats each |
| remove_dim_light | uint8 | Remove dim light flag |
| gdmknifekillbonus | uint8 | Knife kill bonus |
| gdmupperlvkillbonus | uint8 | Upper level kill bonus |
| use_level | uint8 | Use level system |
| level_setting | float[2]+short | Level config |
| use_diff | uint8 | Use difficulty |
| diff_setting | float[?] | Difficulty config |

**Sample parsed values from 01778908768485013001.vxl:**
```
version=20151013
skyname=de_2storm
gamemode=39 (0x27) = EGM_VOXEL_PVE
playtime=600
respawn=1
weather=1
maxplayernum=8
fog_density.v2=1.5
vis_dist=5000.0
friendly_fire=1
player_collision=1
enable_tps=1
minplayernum=1
```

#### 2. [chunk] Section
- **Format**: Pure binary data
- Contains compressed voxel chunk grid (24x12x12 = 3456 chunks)
- Each chunk has multiple data layers (materials, lighting, etc.)

#### 3. [entity] Section (offset ~0x1dbf7)
- **Format**: Text metadata only (actual entity data loaded via network)
```
[entity]
version=20151003
```

#### 4. [water] Section (offset ~0x1dc07)
- **Format**: Text metadata only (water data stored in chunk binary)
```
[water]
version=20151008
frontier_count=0
```

#### 5. [treeview] Section (offset ~0x1dc20)
- **Format**: Text + binary tree view data
```
[treeview]
version=20200327
treeview:<binary data>
```

**Note:** Entity, water, and treeview **actual data** is stored in the binary `[chunk]` section or loaded dynamically via VoxelHTTP/VoxelClient packets. The text sections only contain version metadata.

### Decompressed File Layout
```
Offset 0x00000: [global_data] section (text keys + binary values)
Offset ~0x00f15: [chunk] section header
Offset ~0x00f25: Chunk binary data (3456 chunks × ~34 bytes avg)
Offset ~0x1de00: [entity] section header
Offset ~0x1de20: [water] section header  
Offset ~0x1de40: [treeview] section header + data
Total: 122049 bytes
```

### [chunk] Section Binary Format

The chunk section (118,075 bytes for sample) contains the 24×12×12 = 3456 voxel chunk grid.

```
[chunk]                    <- Section header (7 bytes)
version=20151002           <- Version line (text, 14 bytes)
chunk:                     <- Binary marker (6 bytes ASCII)
<6-byte chunk global header>
+:<6-byte chunk 0 header>
  <chunk data>
+:<6-byte chunk 1 header>
  <chunk data>
... (repeats for all 3456 chunks)
```

**Chunk Entry Structure:**
| Offset | Size | Description |
|--------|------|-------------|
| +0x00 | 2 | "+:" separator |
| +0x02 | 6 | Chunk header (chunk index + metadata) |
| +0x08 | ? | Chunk data (varies by compression) |

**Chunk Header (6 bytes):**
```
Byte 0-3: chunk index (uint32, little-endian)
Byte 4-5: unknown flags/metadata
```

**Sample chunk headers from 01778908768485013001.vxl:**
```
Chunk 0:  0C 00 00 00 00 00  (index=12)
Chunk 1:  0C 00 00 00 01 09  (index=12, metadata=0x0109)
Chunk 2:  0C 00 00 00 02 09  (index=12, metadata=0x0209)
```

**Note:** Chunk indices appear to be sequential but may not be in sorted order. Each chunk entry appears to include sub-layer information (the 0x09 value appears consistently).

**Chunk Data Interpretation:**
- Uses Direct3D fixed-function pipeline (0x8892 D3Dfvf per VoxelChunkRenderer::PushVertices)
- 7 vertex buffer streams per chunk for positions, texcoords, lights, etc.
- Chunk size: 12 bytes per vertex (0xc)
- Each chunk has ~6912 bytes of allocated data

### Material IDs (from VoxelWorld constructor)
```
0x101 = default
3     = stone/ground
0x43  = wood
0x4f  = metal
0x45  = glass
0x5b  = concrete
0x61  = brick
0x62  = sand
0x58  = water
0x64  = grass
0x65  = foliage
```

### Default Palette (RGB values in 0xRRGGBB format)
```
param_1[0x4e] = 0x435d0000  // R=61, G=93
param_1[0x4f] = 0x435f0000  // R=95, G=111  
param_1[0x50] = 0x43660000  // R=102, G=102
```

### LZMA Compression Details
- Uses LZMA1 (FILTER_LZMA), NOT LZMA2
- Python's `lzma` module uses LZMA2 internally - cannot decompress!
- Must use official LZMA SDK (LzmaDec.c) or equivalent
- Custom decompressor: `decode_vxl.c` (uses Nexon's LZMA SDK)

```c
void __thiscall
FUN_0264ed50(undefined4 *param_1,undefined4 param_2,undefined4 param_3,undefined4 param_4,
            undefined4 param_5,undefined4 param_6,uint param_7)

{
  size_t _Size;
  uint uVar1;
  uint uVar2;
  int iVar3;
  size_t _Size_00;
  
  uVar2 = param_7;
  if (param_7 != 0) {
    (*DAT_02e55f10)(*param_1);
    (*DAT_044716a8)(0x8892,param_1[1]);
    _Size_00 = uVar2 * 0xc;
    (*DAT_044716a4)(0x8892,_Size_00,param_2,0x88e8);
    (*DAT_0447163c)(0,3,0x1406,0,0xc,0);
    (*DAT_04471640)(0);
    (*DAT_044716a8)(0x8892,param_1[2]);
    (*DAT_044716a4)(0x8892,_Size_00,param_3,0x88e8);
    (*DAT_0447163c)(1,3,0x1406,0,0xc,0);
    (*DAT_04471640)(1);
    (*DAT_044716a8)(0x8892,param_1[3]);
    (*DAT_044716a4)(0x8892,_Size_00,param_4,0x88e8);
    (*DAT_0447163c)(2,3,0x1406,0,0xc,0);
    (*DAT_04471640)(2);
    (*DAT_044716a8)(0x8892,param_1[4]);
    _Size = uVar2 * 8;
    (*DAT_044716a4)(0x8892,_Size,param_5,0x88e8);
    (*DAT_0447163c)(3,2,0x1406,0,8,0);
    (*DAT_04471640)(3);
    (*DAT_044716a8)(0x8892,param_1[5]);
    (*DAT_044716a4)(0x8892,_Size,param_6,0x88e8);
    (*DAT_0447163c)(4,2,0x1406,0,8,0);
    (*DAT_04471640)(4);
    FUN_0264e450(uVar2,(int)&param_7 + 3);
    memset((void *)param_1[0xd],0,_Size);
    (*DAT_044716a8)(0x8892,param_1[6]);
    (*DAT_044716a4)(0x8892,_Size,param_1[0xd],0x88e0);
    (*DAT_0447163c)(5,2,0x1406,0,8,0);
    (*DAT_04471640)(5);
    param_7 = param_1[0xb];
    uVar1 = (int)(param_7 - param_1[10]) / 0xc;
    if (uVar2 < uVar1) {
      param_1[0xb] = param_1[10] + _Size_00;
    }
    else if (uVar1 < uVar2) {
      if ((uint)((int)(param_1[0xc] - param_1[10]) / 0xc) < uVar2) {
        FUN_0264e5a0(uVar2,(int)&param_7 + 3);
      }
      else {
        iVar3 = param_7;
        if (uVar2 - uVar1 != 0) {
          iVar3 = param_7 + (uVar2 - uVar1) * 0xc;
        }
        param_1[0xb] = iVar3;
      }
    }
    memset((void *)param_1[10],0,_Size_00);
    (*DAT_044716a8)(0x8892,param_1[7]);
    (*DAT_044716a4)(0x8892,_Size_00,param_1[10],0x88e0);
    (*DAT_0447163c)(6,3,0x1406,0,0xc,0);
    (*DAT_04471640)(6);
    (*DAT_044716a8)(0x8893,param_1[8]);
    (*DAT_044716a4)(0x8893,0xc000,0,0x88e0);
    FUN_022b5370("VoxelChunkRenderer::PushVertices");
    (*DAT_02e55f10)(0);
    (*DAT_044716a8)(0x8892,0);
    (*DAT_044716a8)(0x8893,0);
    iVar3 = 0;
    do {
      (*DAT_04471638)(iVar3);
      iVar3 = iVar3 + 1;
    } while (iVar3 < 7);
    param_1[9] = uVar2;
  }
  return;
}
```

Key observations:
- Uses Direct3D calls (0x8892 = D3Dfvf Position/color/texcoord, 0x8893 = D3Dfvf vertices)
- 7 vertex buffer streams for chunk rendering (positions, texcoords, lights, etc.)
- Chunk size appears to be 12 bytes per vertex (0xc)
- Direct3D fixed-function pipeline calls (DAT_044716a8, DAT_044716a4, etc.)

---

---

## VoxelGlobalData::Read - Complete Game Settings at 022488b0

This function parses the [global_data] section of .vxl files and sets all game mode parameters:

```c
uint __fastcall FUN_022488b0(int param_1)
{
  // Parses version 0x1337ae5 of global_data section
  
  // === ENVIRONMENT ===
  "skyname"              -> sky texture name
  "fog_color"            -> RGB fog color (3 floats)
  "fog_density.v2"      -> fog density
  "fog_on"              -> fog enable flag
  "day_light"           -> day lighting RGB (3 bytes)
  "inv_light"           -> inverse lighting RGB (3 bytes)
  
  // === GAME MODE ===
  "gamemode"            -> EGM_VOXEL_CREATE/PVE/PROPHUNT/SHELTER/SCENARIOTX
  "playtime"           -> time limit
  "maxplayernum"       -> maximum players
  "minplayernum"       -> minimum players
  
  // === RESPAWN ===
  "respawn"             -> respawn flag
  "respawntime"         -> respawn time in seconds
  
  // === WEAPONS/DAMAGE ===
  "friendly_fire"       -> friendly fire enabled
  "enemyfire"          -> enemy fire enabled
  "player_collision"    -> player-vs-player collision
  
  // === MONSTER SETTINGS ===
  "human_destroy"      -> humans can destroy
  "zombi_destroy"      -> zombies can destroy  
  "zombi_seethru"      -> zombie see-through mode
  "reset_trigger"      -> reset on trigger
  
  // === PROP HUNT SPECIFIC ===
  "hiderproplimit"     -> max props for hiders
  "seekerPenalty"     -> seeker penalty score
  
  // === SHELTER MODE ===
  "shelterbuildrange"   -> building range
  "shelterlastdaywin"  -> last day win condition
  "shelterMonsterInfo"  -> 50 monster slots! (0x32 = 50 iterations)
                          Each slot: 15 floats at 0xf each = 750 floats total
  
  // === UI/VIEW ===
  "enable_tps"         -> third person view enabled
  "defeatbywipe"      -> defeat by wipe condition
  
  // === LEVEL SETTINGS ===
  "maxplaydate"       -> max play date
  "maxlevel"          -> max level
  "maxsheltertier"    -> max shelter tier
  "use_level"         -> use level system
  "level_setting"     -> level config (2 floats + short)
  "use_diff"          -> use difficulty
  "diff_setting"      -> difficulty config
  
  // === KILL BONUSES ===
  "gdmknifekillbonus"       -> knife kill bonus
  "gdmupperlvkillbonus"    -> upper level kill bonus
  
  // === MISC ===
  "remove_dim_light"   -> remove dim light flag
}
```

### shelterMonsterInfo Structure
The shelterMonsterInfo field is a complex array with 50 slots:
```c
// 50 iterations of 0xf floats each = 750 total floats
// Format per monster: x, y, z, type, health, speed, ... (15 values)
param_1[0x7c] = monster_slot[0];
param_1[0x8b] = monster_slot[1];
// ... continues for 50 monsters
```

---

## Voxel Entity Loading at 0224cc10

This function handles loading entities from the [entity] section into the voxel world:

```c
void FUN_0224cc10(int param_1, /* chunk coord + 0xda8 */ 
                  ushort *param_3, /* entity hash/part1 */
                  ushort *param_4, /* entity hash/part2 */)
{
  // Entity hash = (entity_id ^ 0xdeadbeef) & 0x7fffffff
  // Hash table at param_1 + 0x30, size mask at param_1 + 0x3c
  
  // Entity stored in hash bucket: (hash & mask) * 8 into entity table
  // Uses std::_Tree for collision handling (doubly-linked list)
  
  // Entity removal: unlinks from hash chain, updates list pointers
  // Entity addition: links into hash chain
  
  // Entity vftable at offset +0xd checks if entity is active
  // Entity fields at +4: position/type, +8: next entity in bucket
  
  // Entity data stored at +0xddc for the chunk
}
```

### Entity Hash Formula
```c
hash = (entity_id ^ 0xdeadbeef) & 0x7fffffff;
hash = (hash % 0x1f31d) * 0x41a7 + (hash / 0x1f31d) * -0xb14;
hash = hash + 0x7fffffff;
if (-1 < old_hash) hash = old_hash;
// Final bucket index = hash & bucket_mask
```

### Entity Bucket Structure
```
param_1[0x30]         -> hash table base pointer
param_1[0x3c]         -> bucket mask (hash table size - 1)
param_1[0x28]         -> entity list head
param_1[0x2c]         -> entity count
param_1[0xddc]        -> per-chunk entity data pointer
```

---

## Voxel Game Settings (CVars from strings)
- `vxl_editor` - editor mode
- `vxl_treeviewedit` - tree view edit
- `vxl_treeviewjump` - tree view jump
- `vxl_skyname` - sky name
- `vxl_fogcolor` - fog color
- `vxl_gamemode` - game mode
- `vxl_invlight` - inverse lighting
- `vxl_daylight` - daylight
- `vxl_playtime` - play time
- `vxl_respawn` - respawn setting
- `vxl_restart` - restart setting
- `vxl_weather` - weather
- `vxl_maxplayernum` - max players
- `vxl_fogdensity` - fog density
- `vxl_visdist` - visibility distance
- `vxl_resettrigger` - reset trigger
- `vxl_friendlyfire` - friendly fire
- `vxl_playercollision` - player collision
- `vxl_enabletps` - enable TPS
- `vxl_minplayernum` - min players
- `vxl_endrule` - end rule
- `vxl_initback` - initial back
- `vxl_humandestroy` - human destroy
- `vxl_zombidestroy` - zombie destroy
- `vxl_fogon` - fog on
- `vxl_respawntime` - respawn time
- `vxl_defeatbywipe` - defeat by wipe
- `vxl_enemyfire` - enemy fire
- `vxl_seekerpenalty` - seeker penalty

---

## CVoxelClient vs IVoxelClient Relationship

### Key Discovery
The **IVoxelClient** interface is implemented in **client.dll** at address `02d89320`, while the concrete **CVoxelClient** singleton exists in both client.dll (RTTI) and hw.dll (implementation).

### RTTI Locations (client.dll)
- `IVoxelClient` RTTI: `.?AVIVoxelClient@@` at 02d89a20
- `CVoxelClient` RTTI: `.?AVCVoxelClient@@` at 02d898fc
- Singleton RTTI: `.?AV?$CSingleton@VCVoxelClient@@@@` at 02d8993c

### Relationship
```
hw.dll (Engine DLL - Nexon GoldSrc fork)
└── CVoxelClient implementation
    └── Contains actual voxel client logic
    └── Exported via CVoxelClient singleton

client.dll (Game Client DLL)
└── IVoxelClient interface (02d89320)
    └── Calls into hw.dll for implementation
    └── UI integration layer
```

### IVoxelClient Methods (client.dll:02d89320)
15 packet type handlers:
- `0xe0` - Entity data batch 1 (local_c4 buffer)
- `0xe1` - Entity data batch 2 (local_b4 buffer)
- `0x6d80` - Entity data batch 3 (local_88 buffer)
- `0x73c5` - String parsing
- `0xd7`, `0x83` - Numeric parsing
- `0x536e`, `0x22b59c`, `0x258688` - Entity creation
- `0x86`, `0x9c`, `0x63a2` - Various entity operations
- `0x56aa`, `0x56bb` - Result storage

### Attempted: CVoxelClient vftable Extraction (2026-05-17)

#### Search Methods Tried
1. **RTTI String Search**: Found CVoxelClient RTTI at 02d898fc in client.dll (`.?AVCVoxelClient@@`)
2. **Singleton Pattern Search**: Found CSingleton<VCVoxelClient> at 02d8993c
3. **Cross-DLL Reference Search**: No xrefs from hw.dll to CVoxelClient RTTI (expected - RTTI is in client.dll)
4. **Function Name Search**: No functions with "VoxelClient" in name (no symbols)
5. **Global Variable Search**: No g_pVoxelClient or similar globals found
6. **Vftable Pattern Search**: Found CVoxelWorld vftable at 02aeb5fc successfully, confirming vftable structure

#### Key Finding: CVoxelWorld vftable Location
The CVoxelWorld vftable was found at **02aeb5fc** with entries:
- `02aeb5fc`: 0223c120 (destructor)
- `02aeb600`: 02c26a00
- `02aeb604`: 0223bf50

This confirms the vftable pattern in hw.dll's data section.

#### Challenge
The CVoxelClient vftable in hw.dll cannot be found via simple pattern matching because:
1. No symbols means no function names to search
2. RTTI is in client.dll but implementation is in hw.dll
3. Cross-DLL calls from client.dll to hw.dll would go through IAT (Import Address Table)
4. The vftable location requires either:
   - Pattern matching for constructor `mov [ecx], offset CVoxelClient_vftable` instructions
   - Dynamic analysis (debugging) to trace vftable assignments
   - Cross-referencing from known CVoxelClient methods back to vftable

#### CVoxelClient Relationship (Confirmed)
```
hw.dll (0x01d00000 base) - Engine implementation
└── CVoxelClient concrete class (vftable in hw.dll data)
    └── Methods implement IVoxelClient interface

client.dll (0x01900000 base) - Game client
└── IVoxelClient interface (02d89320)
    └── Calls via vftable into hw.dll implementation
```

#### Next Steps for CVoxelClient vftable Extraction
1. **Memory Pattern Scan**: Scan hw.dll data section for pointer sequences that could be vftables
2. **Constructor Tracing**: Find CVoxelClient constructor by pattern `mov [ecx], imm32` near +0x0
3. **Dynamic Analysis**: Attach debugger and trace CVoxelClient::GetInstance() calls
4. **Cross-Reference from Methods**: Find any known CVoxelClient method, trace back to vftable

#### Pattern Scan Results (2026-05-17)
Searched for `c707` (mov [reg], imm32) patterns in hw.dll code section:

**Found Vftables:**
| Vftable Address | Constructor | Xrefs | Class |
|----------------|-------------|-------|-------|
| 02aeb5fc | 022379e8 | 2 | CVoxelWorld (confirmed) |
| 02af63fc | 022b0340 | 63 | Common base class (not voxel-specific) |
| 02adc0fc | 021839a2 | 3 | HTTP request class |

**Key Observations:**
1. CVoxelWorld constructor at 022379b0 sets vftable at +0x17 with `mov [edi], 02aeb5fc`
2. CVoxelClient constructor NOT found in pattern scan
3. Most `c707` patterns (1000+) are for non-voxel classes
4. Without symbols, cannot distinguish CVoxelClient constructor from other similar patterns

**Challenge Summary:**
The CVoxelClient vftable is likely somewhere in hw.dll but:
- Pattern scan yields 1000+ false positives
- No unique signature to identify CVoxelClient constructor
- RTTI is in client.dll, implementation in hw.dll - cross-DLL linkage not traceable statically

### Updated: IVoxelClient Cross-DLL Analysis (2026-05-17)

**IVoxelClient Call Sites in client.dll:**
- FUN_02d852c0 (02d8545f): Packet parsing loop calling IVoxelClient (02d89320) with type 0xae
- FUN_02d87d10 (02d88351): Large packet parsing with multiple type handlers

**Key Finding: IVoxelClient Implementation Location**
- IVoxelClient interface at 02d89320 is in client.dll (confirmed via xrefs)
- CVoxelClient RTTI also in client.dll at 02d898fc
- But CVoxelClient singleton is a hw.dll type
- client.dll likely loads hw.dll and calls through to CVoxelClient implementation

**Architecture Insight:**
The cross-DLL pattern suggests:
```
client.dll                           hw.dll
  IVoxelClient (02d89320)  ----->   CVoxelClient implementation
  (interface stub)                  (actual singleton)
```

This is a common Nexon pattern where client.dll provides interface wrappers that delegate to server/hw.dll implementations.

**Alternative Approach: IAT Tracing**
Since client.dll imports from hw.dll, the CVoxelClient singleton accessor would be in hw.dll's exports.
Need to examine hw.dll IAT entries for "VoxelClient" or similar function names.

### Blocked: IVoxelPropertyEditor vftables
The IVoxelPropertyEditor interface has **90+ specializations** in client.dll, each with its own vftable. Without symbols, extracting these requires:
- Pattern matching for vftable initialization sequences
- RTTI traversal for each specialization type
- Manual analysis of each derived class constructor

---

## CVoxelClient Approximated vftable

### Class Hierarchy
```
IVoxelClient (02d89320 in client.dll)
  └── IUIMsgEventReceiver
        └── CVoxelClient (hw.dll implementation)
```

### Inheritance Chain (from RTTI data at 02d898e0)
```
.?AVCVoxelClient@@ -> .?AVIVoxelClient@@ -> .?AVIUIMsgEventReceiver@@
```

### Approximated vftable Entries (based on IVoxelClient + UI event receiver pattern)

| Offset | Method Type | Purpose |
|--------|-------------|---------|
| +0x00 | Destructor | CVoxelClient destructor |
| +0x04 | Init | Initialize client connection |
| +0x08 | Connect | Connect to voxel server |
| +0x0C | Disconnect | Disconnect from server |
| +0x10 | HandlePacket | Packet handler (maps to 0xe0, 0xe1, 0x6d80, etc.) |
| +0x14 | LoadWorld | Load voxel world from server |
| +0x18 | SaveWorld | Save voxel world to server |
| +0x1C | SyncEntities | Synchronize voxel entities |
| +0x20 | HandleEntityCreate | Entity creation (types 0x536e, 0x22b59c, 0x258688) |
| +0x24 | HandleEntityUpdate | Entity updates (types 0xd7, 0x83, 0x23e383) |
| +0x28 | HandleBufferFill | Buffer management for batch packets |
| +0x2C | OnUIMsg | UI message handler (IUIMsgEventReceiver) |
| +0x30 | OnEvent | Event handler (IUIMsgEventReceiver) |
| +0x34 | GetUIState | Get UI state (local_6c values: 0, 1, 2, 0x21) |
| +0x38 | CreateUI | Create UI panel (FUN_02d1c1f1 calls) |
| +0x3C | GetSingleton | Return singleton instance |
| +0x40 | Destroy | Destroy client instance |

### Packet Type Mapping (from IVoxelClient 02d89320)
| Type | Handler | Buffer |
|------|---------|--------|
| 0xe0 | Entity batch | local_c4 |
| 0xe1 | Entity batch | local_b4 |
| 0x6d80 | Entity batch | local_88 |
| 0x73c5 | String parse | - |
| 0xd7 | Numeric (max 0x7e) | - |
| 0x83 | Numeric (max 0xfd) | - |
| 0x536e | Entity create | local_44 |
| 0x22b59c | Entity create | local_40 |
| 0x23e383 | Position/value | - |
| 0x86 | Entity data | local_3c |
| 0x9c | Single value (max 1) | - |
| 0x63a2 | Alloc | - |
| 0x258688 | Entity create | local_38 |
| 0x56aa | Result | local_54 |
| 0x56bb | Result | local_4c |

### Singleton Pattern
CSingleton<VCVoxelClient> at 02d8993c provides GetInstance() returning CVoxelClient*.

### Known Offsets in CVoxelClient
| Offset | Field | Type |
|--------|-------|------|
| +0x00 | vftable* | CVoxelClient_vftable* |
| +0x04 | instance_state | int |
| +0x08 | connection | connection* |
| +0x0C | world_id | int |
| +0x10 | entity_buffer | VoxelEntityBuffer |
| +0xC4 | local_c4 | buffer (0xe0 packets) |
| +0xB4 | local_b4 | buffer (0xe1 packets) |
| +0x88 | local_88 | buffer (0x6d80 packets) |