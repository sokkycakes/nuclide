# CSO Voxel Code Extracted from client.dll (Client UI)

## IVoxelPropertyEditor Interface (90 implementations)
Base interface for property editors for each voxel entity type:

### Voxel Entity Types with Property Editors:
- CVoxelDoor
- CVoxelPlayerSpawn
- CVoxelTextboard
- CVoxelPiston
- CVoxelPush
- CVoxelToggleGate
- CVoxelDelayGate
- CVoxelBlinkGate
- CVoxelItemSpawn
- CVoxelItemChecker
- CVoxelReadingMemoBook
- CVoxelReadingComputer
- CVoxelWeaponSpawner
- CVoxelCountDown
- CVoxelAnnounce
- CVoxelSwitch
- CVoxelMonsterSpawner
- CVoxelItemSynthesizer
- CVoxelItemDisassembler
- CVoxelC4Bomb
- CVoxelPortal
- CVoxelButton
- CVoxelHitTarget
- CVoxelMP3
- CVoxelEmitSound
- CVoxelTransit
- CStudioWeaponSpawner
- CVoxelQuestNPC
- Plus 65+ more implementations

## Voxel UI Panels (from strings)
- VoxelScriptBasePanel - Base panel for voxel scripts
- VoxelScheme - Color scheme
- VoxelGameSaveLoadQuery - Save/load query
- VoxelScenarioTXBasePanel - Scenario TX panel
- CVoxelPropHuntKeyPanel - Prop Hunt key panel
- VoxelItemFinderTabs - Item finder tabs
- VoxelLikePopup - Like popup

## Resource Paths
- resource/voxel/whitebox - White box texture
- resource/voxel/info_default - Default info panel
- resource/voxel/dice_* - Dice models
- resource/voxel/ball_* - Ball models (yellow, purple, cyan, pink, blue, red, green)
- resource/voxel/otp - OTP resource

## Voxel World Lifecycle (from strings)
- Start Create VoxelWorld(%d)
- End Create VoxelWorld(%d)
- Destroy VoxelWorld(%d)
- CVoxelWorld::Load_S::FileReadWholeW() failed
- CVoxelWorld::Load::wrong header
- CVoxelWorld::Load::unknown version
- CVoxelWorld::Load_C::vxlHeader(%d) failed
- CVoxelWorld::Load_C::CVoxelDoc::Load failed
- CVoxelWorld::Load_C::GetSection(chunk) failed
- CVoxelWorld::Load_C::version(chunk) failed
- CVoxelWorld::Load_C::version(treevuew) failed

## Voxel Chunk System (from strings)
- VoxelChunk Created(%d)
- VoxelChunkRenderer::PushVertices
- VoxelChunkRenderer::PushTexOffset
- VoxelChunkRenderer::PushLight
- VoxelChunkRenderer::SetRenderParam
- VoxelChunkRenderer::Render

## Voxel Document (from strings)
- CVoxelDoc::Load::VOXEL_FORMAT_ID/VOXEL_VERSION failed
- CVoxelDoc::Load::Voxel_LzmaUncompress failed
- CVoxelDoc::Load::Parse failed
- CVoxelDoc::Write::CVoxelSection::Write(%s) failed
- CVoxelDoc::Write::Voxel_LzmaCompress() failed
- CVoxelDoc::HandleError::%s::%s

## VoxelBlock Class
- VoxelBlock - Basic block class implementing IVoxelProp
- IVoxelProp - Base interface for voxel properties

---

## VoxelHTTP Client API (from strings in client.dll)

### HTTP Request Functions
- `VoxelHTTP::RequestSlotDownload` - Download voxel slot
- `VoxelHTTP::RequestCube` - Request cube data
- `VoxelHTTP::ParseCube` - Parse cube response
- `VoxelHTTP::RequestLocaleList` - Get locale list
- `VoxelHTTP::RequestDownloadLocale` - Download locale
- `VoxelHTTP::RequestDownloadLocale_1` - Download locale variant
- `VoxelHTTP::RequestDownloadLocale_2` - Download locale variant
- `VoxelHTTP::UploadLocale` - Upload locale
- `VoxelHTTP::PostCreateLog` - Post creation log
- `VoxelHTTP::ParseHistoryInfo` - Parse history info
- `VoxelHTTP::RequestImageDownload` - Download image
- `VoxelHTTP::RequestImageUpload` - Upload image
- `VoxelHTTP::RequestMapUpload` - Upload map
- `VoxelHTTP::RequestMapUploadWithFile` - Upload map with file
- `VoxelHTTP::RequestMapListForMain` - Get map list for main
- `VoxelHTTP::RequestMapOneDetail` - Get map detail
- `VoxelHTTP::RequestMapListWithType` - Get maps by type
- `VoxelHTTP::RequestMapListFromGameServer` - Get maps from game server
- `VoxelHTTP::RequestMapListDetail` - Get map list detail
- `VoxelHTTP::RequestTemplateMap` - Get template map
- `VoxelHTTP::ParseMapListForMain` - Parse map list
- `VoxelHTTP::ParseMapListSimple` - Parse simple map list
- `VoxelHTTP::ParseMapListDetail` - Parse detailed map list
- `VoxelHTTP::ParseMapOneDetail` - Parse single map detail
- `VoxelHTTP::TestConnect` - Test connection
- `VoxelHTTP::ParseUploadLocation` - Parse upload location
- `VoxelHTTP::RequestHistoryInfo` - Request history
- `VoxelHTTP::RequestCheerList` - Request cheer list
- `VoxelHTTP::PostRequestMapList` - Post map list request
- `VoxelHTTP::PostRequestNotificationCount` - Post notification request

### HTTP Error Strings
- `"VOXEL_HTTP : [%s] Exception (%s)\n"`
- `"VOXEL_HTTP : [%s] Response Header Status Error [%d(%s)]\n"`
- `"VOXEL_HTTP : [%s] Response get error from Json (%s)\n"`
- `"VOXEL_HTTP : [%s] Response get succeed(%d) from Json\n"`
- `"VOXEL_HTTP : [%s] Response Json Parsing Exception (%s)\n"`
- `"VOXEL_HTTP : [%s] Download HTTP Header Size (%d bytes)\n"`
- `"VOXEL_HTTP : [%s] Download Size (%d bytes)\n"`
- `"VOXEL_HTTP : [%s] Success\n"`

---

## IVoxelPropertyEditor Interface

### Interface Definition
The IVoxelPropertyEditor is a template interface with ~90 specializations for different voxel entity types.

### RTTI Type Names (from client.dll)
```
.?AV?$IVoxelPropertyEditor@VC_VoxelDoor@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelPlayerSpawn@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelTextboard@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelPiston@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelPush@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelToggleGate@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelDelayGate@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelBlinkGate@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelItemSpawn@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelItemChecker@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelMonsterSpawner@@@@
... (90+ total implementations)
```

### Voxel Entity Classes (RTTI)
- `.?AVVoxelScriptBasePanel@@` - VoxelScriptBasePanel
- `.?AVCVoxelPropHuntKeyPanel@@` - Prop Hunt key panel
- `.?AV?$T_VoxelEntity@UT_VoxelMonsterSpawner@@VC_VoxelReplica@@@@`
- `.?AV?$T_VoxelEntity@UT_VoxelPlayerSpawn@@VC_VoxelReplica@@@@`
- `.?AV?$T_VoxelEntity@UT_VoxelItemSpawn@@VC_VoxelReplica@@@@`

---

## Prop Hunt Specific (from strings)

### Game State Names
- `VoxelPropHunt_Play` - Playing state
- `VoxelPropHunt_Transform` - Transform state
- `VoxelPropHunt_Hider` - Hider state
- `VoxelPropHunt_Seeker` - Seeker state
- `VoxelPropHunt_Timeline` - Timeline state
- `VoxelPropHunt_Burning` - Burning effect
- `VoxelPropHunt_Tabom` - Unknown
- `VoxelPropHunt_Result` - Result display
- `VoxelPropHunt_Transform2nd` - Second transform

### Localization Strings
- `#CSO_Voxel_Loading_Downloading` - Downloading
- `#CSO_Voxel_Loading_BuildingWorld` - Building world

---

## UI Resource Paths (from strings)
- `voxel/OutUI/vxltrophy.webm` - Trophy video
- `voxel/OutUI/vxltrophy_global.webm` - Global trophy
- `voxel/OutUI/vxltrophy_year.webm` - Year trophy
- `voxel/OutUI/default_img_%02d` - Default image pattern
- `voxel/play/damage_field.tga` - Damage field
- `voxel/play/rect_rain.tga` - Rain effect
- `voxel/play/shadow.tga` - Shadow texture
- `voxel/play/zombiseethru_1.tga` - Zombie see-through
- `voxel/play/zombiseethru_2.tga` - Zombie see-through
- `voxel/play/zombiseethru_3.tga` - Zombie see-through
- `models/voxel/coin.mdl` - Coin model
- `models/voxel/partyblock/party_a_bomb01.mdl` - Bomb model

---

## Complete Voxel Entity Type List (90 IVoxelPropertyEditor implementations)

Based on RTTI strings found in client.dll:
1. CVoxelDoor
2. CVoxelPlayerSpawn
3. CVoxelTextboard
4. CVoxelPiston
5. CVoxelPush
6. CVoxelToggleGate
7. CVoxelDelayGate
8. CVoxelBlinkGate
9. CVoxelItemSpawn
10. CVoxelItemChecker
11. CVoxelReadingMemoBook (2 variants)
12. CVoxelReadingComputer
13. CVoxelWeaponSpawner
14. CVoxelCountDown
15. CVoxelAnnounce
16. CVoxelSwitch
17. CVoxelMonsterSpawner
18. CVoxelItemSynthesizer
19. CVoxelItemDisassembler
20. CVoxelC4Bomb
21. CVoxelPortal
22. CVoxelButton
23. CVoxelHitTarget
24. CVoxelMP3
25. CVoxelEmitSound
26. CVoxelTransit
27. CStudioWeaponSpawner
28. CVoxelQuestNPC
29. + 65+ more implementations

---

## Key Insight: Engine-to-Game DLL Interface

The IVoxelPropertyEditor pattern suggests the engine (hw.dll) exposes a property editing API that game DLLs (mp.dll, client.dll) implement for each voxel entity type. This allows:
- The engine to handle generic voxel world rendering/chunking
- Game DLLs to define entity-specific behaviors and properties
- Client DLL to provide UI for editing entity properties in the editor

The property editors are likely called when:
1. A voxel entity is selected in the editor
2. Entity properties need to be displayed/modified
3. Entity spawn/use behavior needs to be customized

---

## IVoxelClient Interface (RTTI: `.?AVIVoxelClient@@`)

### Interface Location
- Function: `FUN_02d89320` at 02d89320
- RTTI string at 02d89a20 (`.?AVIVoxelClient@@`)

### Interface Methods (from decompiled function at 02d89320)
The IVoxelClient interface handles client-side voxel world state management including:
- Voxel world loading/saving
- Chunk data streaming
- Entity synchronization
- UI state management

### Packet Type Handling
| Packet Type | Handler | Purpose |
|-------------|---------|---------|
| 0xe0 | local_c4 buffer | Entity data batch 1 |
| 0xe1 | local_b4 buffer | Entity data batch 2 |
| 0x6d80 | local_88 buffer | Entity data batch 3 |
| 0x73c5 | String parsing | Text-based entity data |
| 0xd7 | FUN_02d8a710 | Numeric value parsing (max 0x7e) |
| 0x83 | FUN_02d8a710 | Numeric value parsing (max 0xfd) |
| 0x536e | FUN_02d8a660 | Entity creation with local_44 buffer |
| 0x22b59c | FUN_02d8a660 | Entity creation with local_40 buffer |
| 0x23e383 | FUN_02d8a710 | Entity position/value parsing |
| 0x86 | FUN_02d8a660 | Entity data with local_3c buffer |
| 0x9c | FUN_02d8a710 | Single value (max 1) |
| 0x63a2 | Entity allocation | Memory allocation via FUN_02d7a020 |
| 0x258688 | FUN_02d8a660 | Entity creation with local_38 buffer |
| 0x56aa | FUN_02d8a710 | Result stored in local_54 |
| 0x56bb | FUN_02d8a710 | Result stored in local_4c |

### Local Buffer Fields
```c
local_c4  = buffer for packet type 0xe0 (iStack_c0 = position)
local_b4  = buffer for packet type 0xe1 (iStack_b0 = position)
local_88  = buffer for packet type 0x6d80 (local_94 = position)
```

### Calling Contexts
1. `FUN_02d852c0` - Calls IVoxelClient with packet type 0xae handling
2. `FUN_02d87d10` - Large packet parsing with multiple type handlers (0xae, 0x1549a966, 0x1654ae6b, etc.)

### UI State Management (local_6c values)
- `local_6c == 1` - Calls `FUN_02d854d0` for state 1
- `local_6c == 2` - Calls `FUN_02d82050` for state 2
- `local_6c == 0x21` - Special case with local_94 check
- Other values - Creates new UI via `FUN_02d1c1f1(0x90, ...)` then calls `FUN_02d7a8a0`

---

## Complete Voxel UI Panel List (from strings)

### Core Panels
- VoxelScriptBasePanel - Base panel for voxel scripts
- VoxelScheme - Color scheme manager
- VoxelGameSaveLoadQuery - Save/load query dialog
- VoxelScenarioTXBasePanel - Scenario TX panel
- CVoxelPropHuntKeyPanel - Prop Hunt key panel
- VoxelItemFinderTabs - Item finder tabs
- VoxelLikePopup - Like popup
- VoxelLoadDlg - Loading dialog

### Inventory & Storage UI
- VoxelInventoryUI - Main inventory
- VoxelItemHolderUI - Item holder
- VoxelItemTempHolderUI - Temporary item holder
- VoxelItemCheckerUI - Item checker
- VoxelNPCItemCheckerUI - NPC item checker
- VoxelItemSynthesizerUI - Synthesizer UI
- VoxelItemDisassemblerUI - Disassembler UI
- VoxelItemSellerUI - Seller UI
- VoxelItemShopUI - Shop UI
- VoxelItemPriceListUI - Price list
- VoxelStorageBaseUI - Base storage
- VoxelStoragePrivateUI - Private storage
- VoxelStoragePublicUI - Public storage
- VoxelInvenMom - Inventory mom helper

### Tool Panels
- VoxelItemFinder - Item finder
- VoxelManual - Manual
- VoxelMonsterTemplateEditor - Monster template editor
- VoxelMonsterTemplateEditorBg - Monster editor background

### Quick Slot & Settings
- VoxelQuickslot - Quickslot manager
- VoxelHudKeyGuide - HUD key guide
- VoxelHudQuickMenuItem - Quick menu item
- VoxelHudQuickMenu - Quick menu
- VoxelKeyItem - Key item

### Camera & Settings
- VoxelCameraMenuRow - Camera row
- VoxelCameraMenu - Camera menu
- VoxelSettingsMenuRow - Settings row
- VoxelSettingsMenu - Settings menu
- VoxelSpeedMenu - Speed menu
- VoxelGhostMenu - Ghost menu

### Browser & Script
- VoxelScriptMenu - Script menu
- VoxelStudioBrowser - Studio browser

### Block Selection
- VoxelBlockListPanel - Block list panel
- VoxelRandomBlockSelector - Random block selector

### vxl_editor Weapon
- weapon_vxleditor - Editor tool weapon
- models/v_vxleditor.mdl, models/p_vxleditor.mdl, models/w_vxleditor.mdl - Editor models

---

## Resource Paths (from strings)

### UI Resources
- voxel/OutUI/toast_right, toast_center, toast_left - Toast notifications
- voxel/OutUI/ingame_like_icon - Like icon
- voxel/OutUI/cheer_me, cheer_ranker - Cheer icons
- voxel/OutUI/btn_blue - Button style
- voxel/OutUI/icon_cube_piece_s - Cube icon

### Loading Screens
- resource/MapLoading/voxel/start_btn_* - Start button states
- resource/MapLoading/voxel/test_btn_* - Test button states
- resource/MapLoading/voxel/loadingtitle_bg - Title background
- resource/MapLoading/voxel/vxl_%d_bg, vxl_%d_info - Per-level backgrounds

### Block Editor
- resource/voxel/studio_block_select - Block select texture
- resource/voxel/newicon, upicon - New/update icons

### Shortcuts
- resource/voxel/shortcut_bg_left, center, right - Shortcut backgrounds
- resource/voxel/q_slot_box, q_slot_number_box - Quickslot boxes
- resource/voxel/q_menu_number_on, off - Menu number states
- resource/voxel/q_slot_menu_bg - Menu background
- resource/voxel/select_box, select_copy, select_area_copy - Selection tools

### Effect Images
- resource/voxel/bar_bg, bar_color - Bar textures
- resource/voxel/info_studio_* - Studio info states
- resource/voxel/info_* - Default info states
- voxel/play/dark_black - Dark effect

---

## IVoxelPropertyEditor Interface (Approximated)

### Interface Definition
```c
template<typename T>
class IVoxelPropertyEditor {
    // Base interface for property editors for each voxel entity type
    // 90+ specializations exist
};
```

### Known Entity Types (from RTTI)
```
CVoxelDoor, CVoxelPlayerSpawn, CVoxelTextboard, CVoxelPiston, CVoxelPush,
CVoxelToggleGate, CVoxelDelayGate, CVoxelBlinkGate, CVoxelItemSpawn,
CVoxelItemChecker, CVoxelReadingMemoBook, CVoxelReadingComputer,
CVoxelWeaponSpawner, CVoxelCountDown, CVoxelAnnounce, CVoxelSwitch,
CVoxelMonsterSpawner, CVoxelItemSynthesizer, CVoxelItemDisassembler,
CVoxelC4Bomb, CVoxelPortal, CVoxelButton, CVoxelHitTarget, CVoxelMP3,
CVoxelEmitSound, CVoxelTransit, CStudioWeaponSpawner, CVoxelQuestNPC
... (65+ more)
```

### RTTI Pattern
```
.?AV?$IVoxelPropertyEditor@VC_VoxelDoor@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelPlayerSpawn@@@@
.?AV?$IVoxelPropertyEditor@VC_VoxelTextboard@@@@
// etc.
```

### Approximated Base vftable (IVoxelPropertyEditor)

| Offset | Method | Purpose |
|--------|--------|---------|
| +0x00 | Destructor | Destroy property editor |
| +0x04 | Init | Initialize editor panel |
| +0x08 | Load | Load entity properties |
| +0x0C | Save | Save entity properties |
| +0x10 | GetPropertyCount | Get number of properties |
| +0x14 | GetProperty | Get property by index |
| +0x18 | SetProperty | Set property value |
| +0x1C | GetEntityType | GetVoxelEntityType for this editor |
| +0x20 | CreateUI | Create UI controls |
| +0x24 | RefreshUI | Refresh UI from entity |
| +0x28 | Validate | Validate property values |
| +0x2C | OnApply | Handle apply button |
| +0x30 | OnCancel | Handle cancel button |
| +0x34 | GetPanel | Get associated panel |

### Entity-Specific Property Panels

| Entity Type | Panel Class | Notes |
|-------------|------------|-------|
| CVoxelDoor | VoxelDoorEditor | Door open/close props |
| CVoxelPlayerSpawn | VoxelPlayerSpawnEditor | Spawn position |
| CVoxelPiston | VoxelPistonEditor | Piston extension |
| CVoxelPush | VoxelPushEditor | Push force |
| CVoxelToggleGate | VoxelToggleGateEditor | Toggle state |
| CVoxelDelayGate | VoxelDelayGateEditor | Delay timing |
| CVoxelBlinkGate | VoxelBlinkGateEditor | Blink interval |
| CVoxelItemSpawn | VoxelItemSpawnEditor | Item type/count |
| CVoxelMonsterSpawner | VoxelMonsterSpawnerEditor | Monster type |
| CVoxelWeaponSpawner | VoxelWeaponSpawnerEditor | Weapon type |
| ... | ... | (60+ more) |

### Common Properties Across Entities
| Property | Type | Description |
|----------|------|-------------|
| enabled | bool | Entity active state |
| name | string | Entity name |
| position | vec3 | World position |
| angles | vec3 | Rotation |
| scale | float | Scale factor |
| solid | bool | Collision enabled |

### Property Editor UI Layout (Approximated)
```
+--[Entity Type Panel]--+
| [Icon] Entity Name      |
+-----------------------+
| Common Properties      |
| ├─ Enabled: [x]       |
| ├─ Position: X[] Y[] Z[]|
| └─ Scale: [1.0]        |
+-----------------------+
| Type-Specific Props   |
| ├─ [Property 1] [___]  |
| ├─ [Property 2] [___]  |
| └─ [Property N] [___]  |
+-----------------------+
| [Apply] [Cancel] [Help]|
+-----------------------+
```

### Property Data Flow
1. User selects voxel entity in editor
2. Engine creates IVoxelPropertyEditor specialization for entity type
3. `Load()` populates UI from entity properties
4. User modifies properties in UI
5. `Validate()` checks values
6. `OnApply()` serializes and sends to server
7. Server validates and applies changes

### Key Offsets in IVoxelPropertyEditor
| Offset | Field | Type |
|--------|-------|------|
| +0x00 | vftable* | IVoxelPropertyEditor_vftable* |
| +0x04 | entity | CVoxelEntity* |
| +0x08 | panel | VoxelPropertyPanel* |
| +0x0C | property_count | int |
| +0x10 | properties | Property[] |