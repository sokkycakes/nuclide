# TrenchBroom profiles

Game profiles for [TrenchBroom](https://trenchbroom.github.io/) 2026.2 or
newer. Each game comes in two flavours:

- **Simple** (start here): textures are plain images, there is one map
  format and one compiler, and Run > Compile has three choices. New maps
  start as a small lit room with a player start.
- **Compat**: everything the simple profile has plus Q3 shader scripts, WAD
  textures, more map formats and the ericw-tools and VHLT compilers, for
  working on Quake, Half-Life and Quake 3 style maps.

| Profile | Game | Entity definitions |
| --- | --- | --- |
| **Bulwark** | any Bulwark game on the Nuclide framework | `Bulwark.fgd` |
| **Stiletto Proto (Bulwark)** | Stiletto Proto running on Bulwark | `Stiletto.fgd` |
| **Stiletto Proto (FTEQW)** | Stiletto Proto running on FTEQW | `Stiletto.fgd` |
| **Bulwark Compat** | as Bulwark, plus Half-Life maps | `Bulwark-Compat.fgd`, `Bulwark-Compat-HalfLife.fgd` (adds Rad-Therapy and the Sven Co-op style co-op game) |
| **Stiletto Proto Compat (Bulwark)** | as above | `Stiletto-Compat.fgd` |
| **Stiletto Proto Compat (FTEQW)** | as above | `Stiletto-Compat.fgd` |

Each profile is a folder under `games/` holding its `GameConfig.cfg`,
icon, entity definitions, compile profiles (`CompilationProfiles.cfg`) and
engine launch profiles (`GameEngineProfiles.cfg`). The same folder is kept
in both repos: `tools/trenchbroom/` in bulwark-engine and
`Tools/trenchbroom/` in nuclide.

## Install

    ./install.sh                     # Linux and macOS, into ~/.TrenchBroom/games
    powershell -File install.ps1     # Windows, into %APPDATA%\TrenchBroom\games

Either takes another games folder as its argument (for a Flatpak or a
`--portable` TrenchBroom, use the folder that the folder button under
TrenchBroom's game list opens). Re-running updates the profiles but keeps
your own compile and engine profiles.

Then in TrenchBroom's Preferences, for each game:

- **Game path**: the folder that holds the game directories.
  - Stiletto Proto: the root of the nuclide checkout (the folder with
    `base/`).
  - Bulwark: the folder that holds `base/` and your game. For the games in
    bulwark-engine that is `bulwark-engine/games` after
    `games/link-nuclide.sh`. In Bulwark Compat, add `valve` and `coop` as
    mods (the Mods list in the Map inspector) for Half-Life co-op maps.
- **Compilation tools**: the path to `q3map2` (Stiletto ships it as
  `Tools/q3map2/q3map2.exe`; Nuclide's `vmap` works too). The Compat
  profiles also take the ericw-tools (`qbsp`, `vis`, `light`, shipped in
  Stiletto's `Tools/ericw-tools-win64/`) and VHLT (`hlcsg`, `hlbsp`,
  `hlvis`, `hlrad`).
- **Engines** (Run > Launch): set the path of `bulwark` or `fteqw64`.

## Simple profiles

- **Textures** are the images under `<game>/textures/` (png, jpg, tga). Drop
  a picture into a subfolder there and it shows up in the material browser.
  Normal, gloss and other helper maps (`_norm`, `_gloss`, ...) are hidden.
  `common/` holds the tool textures: `caulk` (faces nobody sees), `clip`
  (invisible wall), `trigger`, `hint`, `skip`, `nodraw`, `origin`. The view
  menu's tag filters hide or show them, and trigger brushes get `common/trigger`
  when you make them.
- **Map format** is Quake 3 (the classic brush format every q3map2 reads).
- **Compile** (Run > Compile) has three choices, all of which put the BSP in
  `<game path>/<last mod>/maps/` and then start the engine on it:
  - *Build and play*: quick lighting, for testing.
  - *Final build*: full visibility and soft, bounced lighting. It doesn't
    start the engine unless you tick the last step.
  - *Quick build (no lighting)*: for checking layout; the map is fullbright.
- **Entities**: the same pool as the Compat profiles (QuakeC classes,
  entityDefs, scripted entities, I/O and Bulwark's script keys), minus the
  internal `nc*` base classes, with only the compiler keys most maps need.
  Use `func_detail` for small or complex shapes to keep compiles fast.

## Compat profiles

Map formats: Bulwark Compat offers Valve 220, Quake 3 (Valve and legacy)
and Standard; the Stiletto Compat profiles offer Quake 3 (legacy) first,
because the q3map2 2.5.17 Stiletto ships reads only that brush format,
then Quake 3 (Valve) and Valve 220 for a newer q3map2 or the ericw-tools.

### Materials

The Compat profiles read both kinds of texture at once:

- Loose images under `<game>/textures/` (tga, png, jpg, dds, ktx) with Q3
  shader scripts from `<game>/scripts/*.shader`, as q3map2 and Nuclide use
  them.
- WAD2 and WAD3 files listed in worldspawn's `wad` key, as Quake and
  Half-Life maps use them (Stiletto's `base/prototype_*.wad`, Half-Life's
  `halflife.wad`). TrenchBroom manages the key from its material browser.

Smart tags hide or highlight clip, caulk, skip, nodraw, null, hint, origin,
trigger and areaportal faces, sky and liquids (by name for WADs, by
surfaceparm for shaders), detail brushes and trigger and detail entities.

### Entities

The FGDs list every entity the game can spawn, from the three places
Bulwark spawns entities from:

1. **QuakeC classes** documented with `/*!QUAKED ... */` comments in
   Nuclide (`src/gs-entbase`, `src/shared`, `src/server`) and in a game's
   own `src/`.
2. **entityDefs** under a game's `decls/def/`. Each one gets the keys,
   inputs, outputs and spawnflags of the QC class it spawns as, plus its own
   model and size so it draws in the editor.
3. **Scripted entities**, `scripts/vscripts/entities/<classname>.lua` (or
   `.js`), which Bulwark spawns through `ncScriptedEntity` for classnames
   that have no QC class. Their keys come from the comment at the top of the
   script (the co-op game's `squadmaker`, `env_xenmaker`, `trigger_vote` and
   so on).

Every entity also gets:

- **Source-style I/O** from Nuclide's `ncIO`: `OnSpawn`, `OnTrigger`,
  `OnUser1-4` outputs, the `FireUser`, `Kill`, `SetParent`, `Show`, `Hide`
  inputs and the rest, and `parentname` (or Spirit of Half-Life's
  `movewith`). An output's value is `target,input,data,delay,times`. To fire
  several targets from one output, chain the groups in one value
  (`door1,Open,,0,-1,light1,TurnOn,,0.5,-1`); Nuclide splits them every five
  fields. TrenchBroom keeps only one key of a name per entity, so repeated
  keys as Hammer writes them don't survive an edit.
- **Bulwark's script layer** (every profile that runs on Bulwark): `vscripts` and
  `thinkfunction`, and the `RunScriptCode`, `RunScriptFile`,
  `CallScriptFunction` and `SetThinkFunction` inputs, as in Valve's VScript.
  Worldspawn's `vscripts` runs in the root scope. See
  `docs/spec/scripting.md` in bulwark-engine. These keys need a progs built
  from a Nuclide with the script hooks (`src/common/c_script.h`); FTEQW and
  older progs ignore them.
- **Compiler keys** for q3map2 (`_lightmapscale`, `_castshadows`,
  `_celshader`, `_shadeangle`), ericw-tools (`_phong`, `_minlight`,
  `_shadow`, `_dirt`, `_lmscale`, sun and bounce keys on worldspawn) and VHLT
  (`zhlt_lightflags`, `zhlt_noclip`, `zhlt_invisible`, `light_origin`) on
  brush entities, worldspawn and lights. Compilers skip keys they don't
  know, so a map can carry all of them.
- **Compile-only entities** the game code doesn't define: `misc_model`,
  `_skybox`, `misc_external_map`, ericw's `func_detail_*` variants,
  `light_spot` (as Source-converted maps place it), and VHLT's
  `info_texlights` and `info_compile_parameters`.

### Compiling

The compile profiles export the map as
`<map>-compile.map` next to it, compile that, and move the BSP to
`<game path>/<last mod>/maps/<map>.bsp`:

| Profile | Tools | Output |
| --- | --- | --- |
| Q3 BSP (q3map2): full, fast, no light, entities only | q3map2 | IBSP, which Bulwark and FTEQW both load |
| Quake BSP2 (ericw): full, fast | qbsp, vis, light | BSP2 with WAD textures |
| Half-Life BSP30 (VHLT): full, fast (Bulwark only) | hlcsg, hlbsp, hlvis, hlrad | GoldSrc BSP30 with WAD3 textures |

Each one ends with a **Launch engine** task, off by default: tick it to
start the map in Bulwark or FTEQW (`+devmap`) once it's built. "Entities
only" rewrites the entity lump of the BSP already in the game's maps
folder, so it needs a full compile first. For quick entity edits without
any compile, Bulwark also reads `maps/<map>.ent` in place of the BSP's
entities.

## Rebuilding the entity definitions

The FGDs are generated. After changing entities in Nuclide, a game's
`decls/def/` or its scripted entities, or the hand-written pieces in
`shared/` (entity I/O and engine keys in `io.fgd`, compiler keys in
`compile-simple.fgd` and `compile-compat.fgd`, script hooks in
`bulwark.fgd`, compile-only classes in `compile-entities-simple.fgd` and
`compile-entities-compat.fgd`), rebuild them:

    python3 build_fgd.py \
        --framework <nuclide checkout with the script hooks> \
        --stiletto  <nuclide checkout with Stiletto's base/> \
        --coop      <bulwark-engine>/games/coop

`--valve` defaults to `<framework>/valve`. A profile whose sources aren't
given keeps its current FGD. Then copy the folder to the other repo, so both
stay the same.
