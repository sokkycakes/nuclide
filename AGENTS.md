## Learned User Preferences

- When porting Stiletto/Godot HUD layouts into QC or RmlUI, place widgets in the letterboxed HUD rect **`screen.HUDMins`** / **`screen.HUDSize`** when they should track the safe HUD area—not always the full viewport **`screen.Mins`** / **`screen.Size`** (see **`base/src/hud/hud.qc`**).
- Target a **minimal reusable Nuclide framework** for the game layer: roughly **three monster archetypes** via **`monster_base`** entityDefs, and map goals via **MapC / RuleC / `maps/*.add`** or **gs-entbase** triggers—not the full engine feature surface.
- Prefer **free/open** rich UI stacks for menus/HUDs; favor an in-process **WebCore CPU** path over proprietary **UltralightCore** or heavy **CEF** multiprocess. Avoid tools that require paid export (e.g. Rive).
- H3 / web menu layouts: keep content **centered/letterboxed**; mock white backgrounds mean **transparent**.
- Prefer pre-game **lobby/menu sessions** that do not force loading a gameplay map when FTE lobby/session APIs can avoid it.
- For active WebCore/engine work, use the FTE tree at **`C:\Users\sokky\Documents\Godot\bulwark_proto_funny\workspace\fteqw`** (not other nearby `fteqw` copies) unless explicitly redirected; WebCore menu work often lives under **`workspace/fteqw/_worktrees/webcore-cpu-renderer/`**.
- Prefer **engine-side** menu audio (not WebCore-played): looping title playlist **`music/menu_boot`** then **`music/menu1`**, **`music/menu2`**, … back to **`menu_boot`** (advance even under classic Quake menus); navigation SFX via FTE with non-`.wav` formats (e.g. **ogg**) allowed, and rapid scroll should not restart/interrupt the same nav sound.
- Wire WebCore menus like Slint: pause **Leave game** / **Return to game** must close the pause UI; keep the console usable while WebCore menus are visible.
- Prefer **WebCore** over **Slint** for in-game HUD and menus (HUD under **`base/data/web/hud/`**; QL-style warmup/pause/team UI under **`base/data/web/ql-menu/`** for functional demos—not necessarily a full VGUI wipe).
- WebCore menu text: prefer shipped TTFs **`standard_07_57`** (body) and **`hooge_05_57`** (mode/timelimit/fraglimit chips) over bitmap fonts; avoid CSS **`@font-face`** in WebCore (can crash).
- Duel/arena WebCore UX: no team-select; waiting offers **JOIN MATCH** / **SPECTATE** (spectate must close the selector); hero pick only records the choice—freeplay spawn on menu close or **READY UP**; ready-up and **COMPETING** show **CHOOSE HERO** / **LEAVE QUEUE** (leave = non-competing spectate; choose-hero keeps the match slot); spectators re-enter via **JOIN QUEUE** (slots stay internal TEAM_1/TEAM_2).
- Title-menu lobby UX: replace Map Browser / Create Server with **Create Lobby** / **Join Lobby**; Join Lobby opens a dialog listing join methods (room code, address, LAN)—LAN live for now, others grayed; visuals follow basemod foundation (semi-transparent panels, Trade Gothic).

## Deferred / Known Issues

- **Spectator target cycling (local two-client):** scroll / next-prev does not switch to the other player on same-machine multi-client; deferred — see **`docs/deferred/spectator-target-cycling.md`**.
- **Respawn health hardcodes 100 HP**: **`ncPlayer::MakePlayer()`** at **`src/shared/game/Player.qc`** (~line 1784) sets health = max_health = 100 instead of reading from hero entityDef on respawn.

## Learned Workspace Facts

- **LLM wiki / OKF**: Project knowledge wiki at **`wiki/`** (Hermes `WIKI_PATH`); OKF memory bundle at **`wiki/okf/`** (`hermes-okf`). Orient via `wiki/SCHEMA.md` + `wiki/index.md` before rediscovering settled facts from the tree.
- **RmlUI HUD**: markup and stylesheet at **`base/ui/rml/`** (`hud.rml`, `hud.rcss`), loaded via VFS as **`ui/rml/hud.rml`**. Laid out in a **4:3** logical box to avoid stretching; **`#hurt-overlay`** covers full viewport. Reload with **`menu_restart`** after edits. If HUD paints over pause menu-vgui, ensure **`RMLUI_DrawHud()`** runs before **`Menu_Draw()`** in **`SCR_DrawTwoDimensional`**. HUD PNGs at **`base/ui/`** (shared pip **`ui/pip.png`**); player movement sounds under **`base/sound/player/`**.
- **WebCore UI (in progress)**: FTE plugin **`webcore`** loads host **`ftewebcore.dll`** (build tree **`workspace/webcore-fte`**, MSVC build dir often **`C:\w\wc-fte`**; runtime often **`fteplug_webcore_x64.dll`**). Default fullscreen menu is **`base/data/web/title-menu/`** (`webcore_menu_url` → **`fte://data/web/title-menu/index.html`**); experimental **`title-menu-v2/`**; H3 under **`h3-main-menu/`**; QL in-game UI under **`ql-menu/`** (browser: `index.html` warmup/esc demos; `index.html?mode=arena` arena fixture); HUD under **`hud/`**; smoke under **`webcore-test/`**. Prefer **`%` + absolute** sizing over **`vw`/`vh`** (often 0 in WebCore). Canvas bitmaps need in-document **`<img>`** or data-URL packs—detached **`new Image()`** often fails to decode on WinCairo. Duel/arena state via **`src/client/webcore_arena.qc`** and plugin **`getarena`** / cvar **`webcore_arena_snapshot`**; arena waiting-cam must use **`Spectate`/`MakeTempSpectator`**, not **`ChangeToClass("spectator")`** (weapon churn breaks CSQC viewmodels). Slint under **`engine/ui/`**; menu host in **`m_webcore_menu.c`**. Goal: fullscreen **`menu_t`**, auto plugin load, in-game HUD—not UltralightCore.
- **Radiant tooling**: build from Nuclide root with **`make radiant`** or **`make netradiant-custom`** (or prebuilt **`Tools/netradiant/`** on Windows). Gamepacks via **`make defs GAME=base`**. FTE binary is **`fteqw64.exe`**. q3map2 writes **`.bsp` beside `.map`**; devmap from **`base/maps/`**. Radiant loads **`$(GAME)/scripts/entities.def`** (entityDef style). **TrenchBroom** Quake profile needs **`base/id1/gfx/palette.lmp`** for WAD2 textures.
- **`+game base`** runs **`base/progs.dat`** (Nuclide: entityDef, ncMonster, MapC/RuleC)—not retail/LibreQuake progs. For vanilla logic use **`+game id1`** or **`-librequake`**. On Windows without make, invoke **`fteqcc.exe -srcfile base/src/server/progs.src`** from the nuclide root (**`make game GAME=base`** needs WSL bash). Classic Quake episode BSPs need **`id1/`** or LibreQuake on the VFS (no **`trigger_secret`** in Nuclide).
- **Monster schedules:** **`ncSchedule::CreateSchedule`** in **`src/server/Schedule.qc`** must count only **`task_N`** keys in schedule **`.decl`** files. Miscounting yields `Task 4 not defined` spam.
- **Stiletto movement** tuning lives in shared framework **`src/shared/physics/stiletto_tuning.qc`** (wired from **`player_pmove.qc`**).
- **External references**: Godot prototype/protophase2 → **`D:\c drive\Godot\stiletto-protophase2`** (additive worlds handoff **`docs/godot-fte-additive-world-handoff.md`**). Source SDK / TF2 / L4D / ASW → **`D:\c drive\Godot\stiletto-proto\sourcesdk_reference`**. Smash Ultimate → GoldSrc **Bip01** animation retarget → **`docs/workflows/smash-ultimate-to-goldsrc-retarget.md`**.
- **Player IQM / skeletal anim**: Full guide **`Documentation/Models/IQM.md`** (wiki [[player-iqm-animation]]). Blender **`iqm_export`**: **Animations** required; local **`*`** = all **`.nuanmb`**; **`IQM_LOOP`** on locomotion only. Bake **Scale** + foot **Z** (~−36) into IQM—players do not network **`.scale`**. Vagrant: **`models/player/joker.iqm`** + numeric **`act_*`** in **`hero_vagrant.def`** (`cmd selecthero hero_vagrant`). Always **`RefreshPlayerAnimations`**; CSQC must set **`declclass`** from **`entityDefID`** (IQM has no HL **`frameforaction`** codes—all-`−1` acts → frame 0). Guard torso **`skel_build`** when Bip01 tags missing (`0,0` = all bones). Jump/crouch are oneshots (clamp time); no empty **`""`** entityDef overrides. Debug: **`anim_debug 1`**.
- **Melee base class**: **`ncWeaponBaseMelee`** at **`src/shared/game/WeaponBaseMelee.h`** / **`.qc`** with base entityDef **`weapon_melee_base.def`** at **`base/decls/def/weapons/weapon_melee_base.def`**. Spawnclass `ncWeaponBaseMelee`. TF2-style line then ±18 AABB hull (`MOVE_NORMAL` / entity BBOX, not mesh hitboxes); `testDistance` must be `0`—negative values gate the hull behind a line-only `UseAmmo` check so TF2 forgiveness never runs.
- **Duel scoring surfaces**: match points live in **`g_arenaPoints`** (HUD via serverinfo / **`arena_score*`**); Tab/`+showscores` reads classic **`.frags`**, so **`Arena_BroadcastState`** mirrors competitor points onto **`.frags`**.
- **EntityDef runtime behavior**: **`.def`** files are loaded at runtime by the engine — no recompilation needed for changes, only game restart. **`GetDefString()`** traverses parent entityDef inheritance hierarchy. **`snd_swing`** is the standard key for melee swing sounds (separate from hit/miss). **`snd_failed`** is dead — engine reads **`snd_fireFailed`** from sub-defs.

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

