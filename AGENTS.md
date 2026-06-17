## Learned User Preferences

- When porting Stiletto/Godot HUD layouts into QC or RmlUI, place widgets in the letterboxed HUD rect **`screen.HUDMins`** / **`screen.HUDSize`** when they should track the safe HUD area—not always the full viewport **`screen.Mins`** / **`screen.Size`** (see **`base/src/hud/hud.qc`**).
- Target a **minimal reusable Nuclide framework** for the game layer: roughly **three monster archetypes** via **`monster_base`** entityDefs, and map goals via **MapC / RuleC / `maps/*.add`** or **gs-entbase** triggers—not the full engine feature surface.

## Deferred / Known Issues

- **Spectator target cycling (local two-client):** scroll / next-prev does not switch to the other player on same-machine multi-client; deferred — see **`docs/deferred/spectator-target-cycling.md`**.

## Learned Workspace Facts

- Figma/Expresso-exported HUD PNGs for this gamepack live under **`base/ui/`**; elements named **`ammopip`** or **`abilitypip`** should use the shared **`pip.png`** asset in that folder (VFS path **`ui/pip.png`** relative to the game root as wired in RML/CSS). The Rml **`hud.rml`** layer also references **`huddeco-quickinfo@1x.png`**, **`infopanelleft@1x.png`** (649×423 art clipped to the 700×84 Godot strip, not stretched), **`reloadTimer@1x.png`**, **`heart.png`**, **`Star_1@1x.png`**, **`image_1@1x.png`** (weapon slot art), **`placeholder_huddeco-ring1@1x.png`**, **`placeholder_huddeco-bcenter@1x.png`**, **`favorite@1x.png`** (speedometer backing), and **`hurt.png`** (full-screen overlay; **`#hurt-overlay`** starts at opacity 0 until game code or engine drives it).
- The RmlUI in-game HUD markup and stylesheet live under **`base/ui/rml/`** (`hud.rml`, `hud.rcss`). FTE loads them as **`ui/rml/hud.rml`** on the VFS—your gamedir layout must map **`base/ui/`** to the **`ui/`** prefix (or copy **`base/ui/rml/`** into **`<gamedir>/ui/rml/`** when running a plain `id1`-only tree). The HUD is laid out in a **4:3** logical box (`#hud-root`, largest 4:3 rectangle inside the window via `vw`/`vh` + aspect media queries) so it does not stretch on non–4:3 windows; **`#hurt-overlay`** remains on `<body>` and still covers the full viewport. After edits, reload with **`menu_restart`** (FTE caches until RmlUI shuts down).
- If the Rml HUD paints over pause **menu-vgui**, ensure **`RMLUI_DrawHud()`** runs **before** **`Menu_Draw()`** in **`SCR_DrawTwoDimensional`** (`fteqw/engine/client/cl_screen.c` in the Bulwark monorepo).
- **GtkRadiant / NetRadiant-Custom**: build from the Nuclide root with **`make radiant`** or **`make netradiant-custom`** (clone + compile under **`ThirdParty/`**); gamepack via **`make defs GAME=base`** or **`make defs-wad GAME=base`** (NetRadiant-Custom **`make defs`** needs **`ThirdParty/netradiant-custom/install/plugins`** first). Pack output under **`ThirdParty/netradiant-custom/install/gamepacks/`** (GtkRadiant under its **`install/`** tree). **Windows** also ships a prebuilt tree at **`Tools/netradiant/`** (no local compile required). Linux/WSL: **`./radiant`** or **`./radiant.x86_64`**.
- **StilettoSwift / NetRadiant (Q3 BSP)**: gamepack **`shaderpath="scripts"`** (shaders and **`shaderlist.txt`** in **`base/scripts/`**, not **`texturesrc`**). **`textures/common/*`** tool shaders may lack **`.tga`** editor previews but still register via **`.mat`** / **`common.shader`**. Build menu uses shipped **`Tools/q3map2/q3map2.exe`** (not **`vmap`**); **`ericw-tools`** is Quake 1 BSP only. FTE binary at repo root is **`fteqw64.exe`** (not **`fteqw.exe`**). q3map2 writes **`.bsp` beside the `.map`**; **`devmap`** loads from **`base/maps/`** — build targets copy **`[BspFile]`** → **`base/maps/[MapName].bsp`**, and **`BuildRunGame`** with **`BuildEngineArgs=+game base +devmap [MapName]`** launches after compile. **View → Filter → Sky** hides **`surfaceParm sky`** / **`skyParms`** faces in the 3D view.
- **Radiant** loads **`$(GAME)/scripts/entities.def`** (Doom3 **`entityDef`** style), built by **`Tools/make_mapdef.sh`** when you **`make defs`**. Nuclide does **not** ship a TrenchBroom **`.fgd`**.
- **TrenchBroom** set to the **Quake** game profile looks for **`gfx/palette.lmp`** under the default mod **`id1/`** (e.g. **`base/id1/gfx/palette.lmp`** when the game path is **`base`**); **`base/gfx/palette.lmp` alone does not satisfy** TB for Quake **WAD2** textures. Stock **Generic** TB config does not enable **WAD** loading unless you add **`palette`** + **`attribute: "wad"`** to **`materials`** in a custom **`GameConfig.cfg`**.
- **NetRadiant-Custom** (WAD / **`type="q1"`** gamepack, e.g. **`StilettoSwift-wad.game`**) resolves **`gfx/palette.lmp`** through the same VFS as the mod directory: with **`basegame="base"`**, use **`base/gfx/palette.lmp`** at the Nuclide root (**`EnginePath`** = repo checkout, **Game** = **`base`**). Do not rely on **`base/id1/gfx/`** for NRC.
- **`+game base`** runs **`base/progs.dat`** (Nuclide: **`entityDef`**, **`ncMonster`**, MapC/RuleC)—not retail/LibreQuake progs. **LibreQuake** is **`lq1/`** assets plus a **GPL fork** of id QuakeC (BSD is mainly **art**). For wholesale vanilla logic use FTE **`+game id1`** or **`-librequake`**; do not swap external **`progs.dat`** into **`base/`**.
- **Monster schedules:** **`ncSchedule::CreateSchedule`** in **`src/server/Schedule.qc`** must count only **`task_N`** keys in schedule **`.decl`** files (not every decl key/value pair). Miscounting (e.g. **`idle.decl`**: three tasks plus **`NewEnemy`** / **`Damage`** message keys) yields **`Task 4 not defined in "idle"`** spam and idle AI never runs—rebuild with **`make game GAME=base`** after fixes.
- **Classic Quake BSP on Nuclide:** no **`trigger_secret`** entity yet; **`base/liblist.gam`** may set **`startmap "e0m1"`** with **no in-repo BSP**—episode maps need **`id1/`** or LibreQuake on the VFS. Rebuild all **`base`** progs from repo root: **`make game`** (alias **`make game GAME=base`**).
- **Stiletto movement** tuning lives in shared framework **`src/shared/physics/stiletto_tuning.qc`** (wired from **`player_pmove.qc`**), not only under **`base/`**.

## CSO Voxel Research (in progress)

Extracting voxel and BSP related code from CSNZ DLLs into **`research/CSOvoxel/`**.

### DLL Architecture
- **`hw.dll`** (Nexon GoldSrc) - Core voxel system: CVoxelWorld, CVoxelDoc, CVoxelChunk, CVoxelSection, CVoxelClient
- **`mp.dll`** (Server) - VoxelEntity, VoxelMonster AI (20+ types), CVoxelSpawn, collision handlers
- **`client.dll`** (Client) - IVoxelPropertyEditor (90+ impls), VoxelScriptBasePanel, VoxelPropertySheet, IVoxelClient

### .vxl File Format (Confirmed)
- **Header (21 bytes)**: magic (`0x766f7363` "csov"), padding (`0x2e2e2e2e`), version (`0x1337ad9`), orig_size (4 bytes), LZMA_props (5 bytes)
- **Compression**: LZMA1 (FILTER_LZMA) - Python's lzma module CANNOT decompress (uses LZMA2 internally)
- **Decompressed (122049 bytes for sample)**: Hybrid text/binary format
  - `[global_data]` at offset 0: text keys + binary values (floats, uints, etc.)
  - `[chunk]`: binary voxel grid (3456 chunks × 24×12×12)
  - `[entity]`: entity metadata (version=20151003)
  - `[water]`: water settings (version=20151008)
  - `[treeview]`: tree view data (version=20200327)
- **Key values from sample**: skyname=de_2storm, gamemode=39 (EGM_VOXEL_PVE), playtime=600, fog_density=1.5, vis_dist=5000
- **Custom decompressor**: `C:\Users\sokky\Documents\code\decode_vxl.c` (uses Nexon's LZMA SDK)

### Voxel Chunk Grid
- 24x12x12 = 3456 chunks, 7 sublayers per chunk
- Material IDs: 3, 0x43, 0x4f, 0x45, 0x5b, 0x101, etc.
- Direct3D fixed-function pipeline (0x8892 D3Dfvf)

### Key Files
- `research/CSOvoxel/hw_dll/voxel_code.md` - Core voxel engine (~1000 lines)
- `research/CSOvoxel/mp_dll/voxel_code.md` - Server-side voxel entities (~530 lines)
- `research/CSOvoxel/client_dll/voxel_code.md` - Client UI and property editors (~380 lines)

### Game Modes
- EGM_VOXEL_CREATE, EGM_VOXEL_PVE, EGM_VOXEL_PROPHUNT, EGM_VOXEL_SHELTER, EGM_VOXEL_SCENARIOTX

### Recent Updates (2026-05-17)
- **CVoxelWorld vftable extracted** at 02aeb5fc - entries at 0223c120 (destructor), 02c26a00, 0223bf50
- **CVoxelClient vftable approximated** (~20 methods, inherits IVoxelClient + IUIMsgEventReceiver)
- **IVoxelClient interface fully documented** at 02d89320 - handles 15 packet types (0xe0, 0xe1, 0x6d80, 0x73c5, 0xd7, 0x83, 0x536e, 0x22b59c, 0x23e383, 0x86, 0x9c, 0x63a2, 0x258688, 0x56aa, 0x56bb)
- **Monster AI think state machine documented** - m_pfnThink at offset 0x349, behavior tree nodes at 0x34e+, 0x381, 0x38a-0x38c
- **VoxelMonster base initialization** (0xc50 bytes) with entity hierarchy: CBaseMonster → VoxelMonster → type-specific monsters
- **Captured and decompressed .vxl sample** via Wireshark - confirmed 21-byte header + LZMA1 compression + hybrid text/binary sections
- **Identified .vxl value format**: keys are text, values are binary (uint8/uint32/float arrays), NOT plain text

### Next Steps
- Verify CVoxelClient approximation via dynamic analysis if kernel anticheat allows safe probing
- Extract remaining VoxelEntity factory vftables (CVoxelReplica, etc.)

### Blocked (2026-05-17)
- **CVoxelClient vftable**: Approximated (~20 methods). Full extraction requires dynamic debugging or PDB files.
- **IVoxelPropertyEditor vftables**: 90+ specializations approximated with base interface (~15 methods). Full extraction requires dynamic analysis.

### Key Discoveries
- **CVoxelWorld vftable**: 02aeb5fc (constructor 022379e8 sets via `mov [edi], 02aeb5fc`)
- **CVoxelWorld destructor**: 0223c120 (calls FUN_02809b8c with size 0xe30)
- **CVoxelClient vftable**: Approximated (~20 methods, inherits IVoxelClient + IUIMsgEventReceiver)
- **IVoxelClient call sites**: FUN_02d852c0 (02d8545f), FUN_02d87d10 (02d88351)
- **Singleton RTTI**: `.?AV?$CSingleton@VCVoxelClient@@@@` at 02d8993c
- **Cross-DLL architecture**: client.dll has IVoxelClient interface stub delegating to hw.dll CVoxelClient implementation
- **.vxl file header (21 bytes)**: bytes 0-3="csov", bytes 4-7="....", bytes 8-11=version(0x1337ad9), bytes 12-15=orig_size, bytes 16-20=LZMA_props(5 bytes)
- **.vxl decompressed format**: [global_data] (offset 0), [chunk], [entity], [water], [treeview] - keys are text, values are BINARY (not text!)
