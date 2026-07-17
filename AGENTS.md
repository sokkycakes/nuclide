## Learned User Preferences

- When porting Stiletto/Godot HUD layouts into QC or RmlUI, place widgets in the letterboxed HUD rect **`screen.HUDMins`** / **`screen.HUDSize`** when they should track the safe HUD area—not always the full viewport **`screen.Mins`** / **`screen.Size`** (see **`base/src/hud/hud.qc`**).
- Target a **minimal reusable Nuclide framework** for the game layer: roughly **three monster archetypes** via **`monster_base`** entityDefs, and map goals via **MapC / RuleC / `maps/*.add`** or **gs-entbase** triggers—not the full engine feature surface.
- Prefer **free/open** rich UI stacks for menus/HUDs; favor an in-process **WebCore CPU** path over proprietary **UltralightCore** or heavy **CEF** multiprocess. Avoid tools that require paid export (e.g. Rive).
- H3 / web menu layouts: keep content **centered/letterboxed**; mock white backgrounds mean **transparent**.
- Prefer pre-game **lobby/menu sessions** that do not force loading a gameplay map when FTE lobby/session APIs can avoid it.
- For active WebCore/engine work, use the FTE tree at **`C:\Users\sokky\Documents\Godot\bulwark_proto_funny\workspace\fteqw`** (not other nearby `fteqw` copies) unless explicitly redirected.

## Deferred / Known Issues

- **Spectator target cycling (local two-client):** scroll / next-prev does not switch to the other player on same-machine multi-client; deferred — see **`docs/deferred/spectator-target-cycling.md`**.
- **Respawn health hardcodes 100 HP**: **`ncPlayer::MakePlayer()`** at **`src/shared/game/Player.qc`** (~line 1784) sets health = max_health = 100 instead of reading from hero entityDef on respawn.

## Learned Workspace Facts

- **RmlUI HUD**: markup and stylesheet at **`base/ui/rml/`** (`hud.rml`, `hud.rcss`), loaded via VFS as **`ui/rml/hud.rml`**. Laid out in a **4:3** logical box to avoid stretching; **`#hurt-overlay`** covers full viewport. Reload with **`menu_restart`** after edits. If HUD paints over pause menu-vgui, ensure **`RMLUI_DrawHud()`** runs before **`Menu_Draw()`** in **`SCR_DrawTwoDimensional`**. HUD PNGs at **`base/ui/`** (shared pip **`ui/pip.png`**); player movement sounds under **`base/sound/player/`**.
- **WebCore UI (in progress)**: FTE plugin **`webcore`** loads host **`ftewebcore.dll`** (build tree **`workspace/webcore-fte`**, MSVC build dir often **`C:\w\wc-fte`**). Menu/HUD HTML lives under **`base/data/web/h3-main-menu/`** (H3 Figma mockup); smoke pages under **`base/data/web/webcore-test/`**. Goal: fullscreen **`menu_t`**, auto plugin load, in-game HUD—not UltralightCore.
- **Radiant tooling**: build from Nuclide root with **`make radiant`** or **`make netradiant-custom`** (or prebuilt **`Tools/netradiant/`** on Windows). Gamepacks via **`make defs GAME=base`**. FTE binary is **`fteqw64.exe`**. q3map2 writes **`.bsp` beside `.map`**; devmap from **`base/maps/`**. Radiant loads **`$(GAME)/scripts/entities.def`** (entityDef style). **TrenchBroom** Quake profile needs **`base/id1/gfx/palette.lmp`** for WAD2 textures.
- **`+game base`** runs **`base/progs.dat`** (Nuclide: entityDef, ncMonster, MapC/RuleC)—not retail/LibreQuake progs. For vanilla logic use **`+game id1`** or **`-librequake`**.
- **Monster schedules:** **`ncSchedule::CreateSchedule`** in **`src/server/Schedule.qc`** must count only **`task_N`** keys in schedule **`.decl`** files. Miscounting yields `Task 4 not defined` spam.
- **Stiletto movement** tuning lives in shared framework **`src/shared/physics/stiletto_tuning.qc`** (wired from **`player_pmove.qc`**).
- **Godot prototype reference**: When the user mentions the **Godot prototype** or **protophase2**, reference code from **`D:\c drive\Godot\stiletto-protophase2`**.
- **Source SDK reference**: When the user mentions **Source SDK**, **TF2 source code/SDK**, **L4D/Left 4 Dead**, **Alien Swarm/ASW** code/SDK, reference code from **`D:\c drive\Godot\stiletto-proto\sourcesdk_reference`**.
- **Melee base class**: **`ncWeaponBaseMelee`** at **`src/shared/game/WeaponBaseMelee.h`** / **`.qc`** with base entityDef **`weapon_melee_base.def`** at **`base/decls/def/weapons/weapon_melee_base.def`**. Spawnclass `ncWeaponBaseMelee`. Uses hull-only trace with cleave support.
- **EntityDef runtime behavior**: **`.def`** files are loaded at runtime by the engine — no recompilation needed for changes, only game restart. **`GetDefString()`** traverses parent entityDef inheritance hierarchy. **`snd_swing`** is the standard key for melee swing sounds (separate from hit/miss). **`snd_failed`** is dead — engine reads **`snd_fireFailed`** from sub-defs.
- **Build on Windows without make**: invoke **`fteqcc.exe -srcfile base/src/server/progs.src`** directly from the nuclide root. **`make game GAME=base`** requires WSL bash (make not available in Windows PATH).
- **Classic Quake BSP on Nuclide:** no **`trigger_secret`** entity; episode maps need **`id1/`** or LibreQuake on the VFS.

## CSO Voxel Research (in progress)

Extracting voxel and BSP related code from CSNZ DLLs into **`research/CSOvoxel/`**.

### DLL Architecture
- **`hw.dll`** (Nexon GoldSrc) - Core voxel system: CVoxelWorld, CVoxelDoc, CVoxelChunk, CVoxelSection, CVoxelClient
- **`mp.dll`** (Server) - VoxelEntity, VoxelMonster AI (20+ types), CVoxelSpawn, collision handlers
- **`client.dll`** (Client) - IVoxelPropertyEditor (90+ impls), VoxelScriptBasePanel, VoxelPropertySheet, IVoxelClient

### .vxl File Format (Confirmed)
- **Header (21 bytes)**: magic (`0x766f7363` "csov"), padding (`0x2e2e2e2e`), version (`0x1337ad9`), orig_size (4 bytes), LZMA_props (5 bytes)
- **Compression**: LZMA1 (FILTER_LZMA) - Python lzma module cannot decompress (uses LZMA2 internally)
- **Decompressed (122049 bytes)**: Hybrid text/binary format with sections [global_data], [chunk], [entity], [water], [treeview]
- **Custom decompressor**: `C:\Users\sokky\Documents\code\decode_vxl.c` (Nexon LZMA SDK)

### Voxel Chunk Grid
- 24x12x12 = 3456 chunks, 7 sublayers per chunk, Direct3D fixed-function pipeline

### Key Files
- `research/CSOvoxel/hw_dll/voxel_code.md` - Core voxel engine (~1000 lines)
- `research/CSOvoxel/mp_dll/voxel_code.md` - Server-side voxel entities (~530 lines)
- `research/CSOvoxel/client_dll/voxel_code.md` - Client UI and property editors (~380 lines)

### Game Modes
- EGM_VOXEL_CREATE, EGM_VOXEL_PVE, EGM_VOXEL_PROPHUNT, EGM_VOXEL_SHELTER, EGM_VOXEL_SCENARIOTX

