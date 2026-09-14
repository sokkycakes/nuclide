# Stiletto World Editor — first working slice

Godot 4.5 authors the scene; FTE runs the compiled world and native QuakeC. Open `project.godot`, open `maps/editor_lab.tscn`, and use the **Stiletto** bottom panel's **Export + Play** button. The binaries and example resources have been built in this workspace.

This is an experimental foundation for the larger authoring workspace described in [the proposal](../docs/brainstorms/2026-09-13-godot-fte-authoring-workspace.md). It does not yet replace a complete level, model, material, and particle toolset.

To play the already-exported lab directly, double-click `play-editor-lab.cmd` in the Nuclide root. It selects `fteqw-world.exe` and the matching editor gamecode. `Unrecognised model format FTEW` means the running engine lacks the new loader; the normal `fteqw64.exe` cannot load this file yet.

## What works

| Author in Godot | Export/run in FTE |
| --- | --- |
| MeshInstance3D, primitive meshes, evaluated CSG | Versioned binary `.ftew` world; no MAP/BSP intermediate |
| Reused meshes, scene placements, rotations, scale and mirroring | Shared mesh records with independent transforms; current renderer expands instances |
| FTEWorldMesh3D | Visual + collision, visual only, or collision only |
| StaticBody3D + BoxShape3D | Native convex collision |
| FTEEntity3D with native classname/properties | Nuclide entities; explicit stable IDs become targetnames |
| CollisionShape3D under FTEEntity3D | Native inline collision model for trigger volumes |
| FTEConnection resources | Native entity outputs with target, action, parameter, delay and fire count |
| OmniLight3D | Native `light_dynamic`: Light Energy → brightness multiplier; Omni Range → distance |
| DirectionalLight3D | Native parallel-ray sunlight: rotation, color, energy, visibility, and optional shadows |
| AudioStreamPlayer | Nonpositional native audio: autoplay, volume, pitch, whole-file looping and entity I/O |
| Opaque albedo StandardMaterial3D | Content-addressed PNG + individual native `.mat` files |
| WorldEnvironment color, panorama or procedural gradient | Native sky panorama and map-default `skyname` |
| Explicit Environment ambient color | Approximate static vertex tint on generated lit materials |
| FTEWorldMesh3D `fte_material` override | Existing native material path, including richer FTE materials |
| MapC `.qc` source in the bottom panel | FTEQCC compilation to `maps/<world>.dat` |

The addon uses editor-only GDScript. Exported gameplay contains no GDScript and does not require Godot at runtime. Godot's regular Run button is not the FTE playtest button.

## Try the lab

1. Open this Godot project and `maps/editor_lab.tscn`.
2. Open the **Stiletto** bottom panel. Use **Export + Play**.
3. Use the separate FTE window to play. The green plate has a trigger volume connected to the light above it. Entering it toggles the light.
4. Move a mesh or change an entity property, then export/play again. Each play action starts a new process; close your previous playtest when finished.
5. Use **Open MapC**, edit the native source, and **Save + Compile MapC**. Map scripts are loaded on map startup, so reload the map after compilation.

Editor gizmos show entity origins, facing and output links. Targets are node paths relative to the entity owning the connection. Explicit `entity_id` values survive renames; omitted IDs are derived from scene paths and therefore change if those paths change. The editor does not yet provide a searchable entity schema or a logic graph.

The runtime uses this project's current Nuclide rules, HUD, hero selection and player assets. Existing player-model warnings and menu behavior can therefore appear in the lab. Environment export covers the subset described below; FTE remains the lighting reference.

## Environment and live sky changes

For dynamic-light brightness, select the **OmniLight3D** and change **Light > Energy**, then **Export + Play**. Energy `1` is normal, `0.25` is quarter intensity, `4` is four times the emitted light, and `0` emits none. Display brightness also depends on distance, materials and rendering settings. **Omni > Range** controls reach independently. Native `brightness` inputs update existing lights too; omitted brightness defaults to `1`. Restart older playtests after updating the gamecode.

**DirectionalLight3D** uses the same **Light > Color / Energy** controls. Rotate the node to aim its rays (Godot local -Z); moving it does not change illumination. For a simple downward sun, start with **Rotation X = -45°**. Enable **Shadow > Enabled** to cast shadows. Node visibility sets the initial on/off state for both directional and point lights. Native `TurnOn`, `TurnOff`, `Toggle`, `brightness`, `angles` and `_shadows` inputs can update the light during gameplay; exported connections can target the directional node.

Sunlight uses FTE's orthographic lighting without point-light distance attenuation. Shadows use one camera-following shadow map. **Directional Shadow > Max Distance** sets its minimum coverage in Godot units; the exporter expands coverage to include the authored world (at least twice its bounding-box diagonal). Larger coverage reduces shadow detail. Godot cascades, per-light shadow bias, light masks, sky-only mode, negative lights and physical exposure matching are not supported. The exported sky gradient is independent of the light and does not gain a sun disk when it rotates. Restart the playtest after updating the paired editor client/server gamecode.

Select the scene's **WorldEnvironment** and edit its **Environment** resource, then **Export + Play**. Color backgrounds, PanoramaSkyMaterial and the color gradient of ProceduralSkyMaterial export as native panorama PNGs. `environments/day.tres` and `environments/dusk.tres` are example Environment resources you can assign in the inspector. The lab's existing background has been retained.

Restart the playtest using the updated `fteqw-world.exe` (or `play-editor-lab.cmd`) after an engine rebuild. In the FTE console:

```text
r_fastsky 0
r_skybox env/fteworld/day
r_skybox env/fteworld/dusk
r_skybox ""
```

Each nonempty override changes the background immediately. The final command restores the exported map default. `sky` displays the current selection. Nested panorama names include the `env/` prefix but omit the extension: the examples are `base/env/fteworld/day.png` and `dusk.png`. Simple legacy skybox basenames still use FTE's normal search rules. These are client-local visual overrides; they neither edit the Godot scene nor synchronize other players.

For a permanent native asset selection, set the root **FTEWorld3D > Native Sky** to its basename and export. This takes precedence over the WorldEnvironment background (and the older `world_properties.skyname` field). Otherwise the exporter writes a content-addressed panorama and its `skyname` into worldspawn. Include `base/env/fteworld/` dependencies when distributing the map.

**Limits:** this is not full Godot Environment rendering. Procedural skies currently export only the static horizon/zenith/ground gradient, without sun disks, sky cover or atmospheric scattering. Panorama rotation and background energy are baked into a 512×256 LDR image; HDR values above one are clamped. Physical/custom sky shaders require a panorama bake. Multiple active WorldEnvironments are rejected.

Ambient Light **Source: Color** multiplies generated lit static vertex colors at export time. It does not relight player models, provide GI/reflections, or change when `r_skybox` changes. Other ambient modes retain the existing FTE lighting behavior. Godot fog, tonemapping and post-processing are not transferred; native fog remains available through FTE's `fog` console command or `world_properties._fog`.

## Nonpositional audio

Add **AudioStreamPlayer**, assign an MP3, Ogg Vorbis or PCM WAV stream, and enable **Autoplay** to start it when the map loads. **Volume dB** maps to linear native volume and **Pitch Scale** maps to playback speed/pitch (`1` = normal). Enable looping on the stream resource/import settings for a whole-file loop. Node position and listener position/direction do not affect playback. Keep **Max Polyphony** at `1`; separate nodes have independent channels.

MP3 is automatically decoded by Godot to stereo PCM WAV during export because this isolated FTE runtime does not reliably decode MP3 itself. This increases exported size but requires no external converter. Ogg sources are copied, and WAV resources are saved with their imported settings. Generated audio goes under `base/sound/fteworld/` and must accompany the map when distributed.

FTEConnection outputs can target the AudioStreamPlayer with **PlaySound**, **StopSound**, or **ToggleSound**. `PlaySound` restarts from the beginning. Native **Volume** accepts a linear multiplier (`0` mute, `0.5` half, `1` normal); **Pitch** accepts a percentage (`100` normal). These controls are replicated to clients. Each joining client starts active audio from the beginning; playback positions are not synchronized between clients. A non-looping clip ends naturally on each client. Stop/Play explicitly clears/restarts its server playback state.

Godot audio buses/effects, custom loop points, reverse/ping-pong looping, polyphonic/composite streams, pause/seek and `finished` signals are not mapped. Native playback uses FTE's master `volume` control without positional attenuation or reverb. The audio node's existing name can contain `3D`; its actual type must be **AudioStreamPlayer**. AudioStreamPlayer3D and AudioStreamPlayer2D are separate, currently unsupported types.

The opt-in native path extends `ambient_generic` with `_nonpositional`, `_autoplay`, and `_loop` keys. Existing ambient entities retain their original behavior. Rebuild the paired editor client/server gamecode and restart older playtests after this update. Export tests: `test_audio_export.gd`; runtime tests: compile `Tools/stiletto/audio_probe.qc` to `base/maps/ftew_audio_probe.dat`, then run `python Tools/stiletto/test_audio_runtime.py`. The runtime test uses actual decoded sample levels and playback times, at low master volume, to check MP3 conversion, looping, stop/restart and live parameter updates.

## Build and reproduce

Run these from the Nuclide root. The Windows helper scripts currently use this machine's installed MinGW/MSYS2, ccache and FTEQCC. Python 3.10+ is required for the installer and test helpers.

```powershell
python Tools/stiletto/install_engine.py --engine ../workspace/fteqw/_worktrees/webcore-cpu-renderer
& C:/msys64/usr/bin/bash.exe Tools/stiletto/build_engine.sh
& C:/msys64/usr/bin/bash.exe Tools/stiletto/build_engine.sh --server
& Tools/stiletto/build_gamecode.ps1
```

The engine installer copies the two maintained module headers from `Tools/stiletto/engine/` and applies small registration/map-discovery changes to the canonical engine worktree. It also fixes the worktree's duplicate no-Slint fallback stub and PNG screenshot I/O across different Windows C runtimes. Re-running is supported; unrelated engine changes are retained.

Outputs are `fteqw-world.exe`, `fteqw-world-server.exe`, `base/maps/ftew_framework.dat`, `base/maps/ftew_client.dat` and `base/maps/editor_lab.dat`. The normal `fteqw64.exe`, `base/progs.dat` and `base/csprogs.dat` are not replaced. The editor supplies `sv_progs maps/ftew_framework.dat` and `sv_csqc_progname maps/ftew_client.dat` to its playtest process and disables automatic configuration saving. The server advertises the matching client gamecode to joining players.

For headless export, substitute your Godot 4.5 executable and an absolute log path:

```text
godot --headless --path worldsrc --log-file ABSOLUTE_LOG_PATH --script addons/stiletto_tools/cli.gd -- res://maps/editor_lab.tscn ../base
```

Godot imports source assets in the usual way. Keep source models/textures in this Godot project. Exported files are written under `base/maps/` and `base/textures/fteworld/`. Native material references must resolve through FTE's game filesystem. To distribute a world, include its `.ftew`, MapC `.dat`, referenced materials/textures, and the normal game's dependencies, with an FTEW-enabled runtime. Stock FTE binaries do not know this new format.

## Native scripting

The MapC example includes Nuclide's `src/rules.src` API and implements `CodeCallback_Precache` and `CodeCallback_PlayerSpawn`. This change connects the previously unused MapC frame, connect, disconnect and spawn delegates in `src/server/entry.qc`. Existing native entity I/O is used directly. Additional mapped lifecycle callbacks such as damage/death have not been wired by this change.

The example's optional `ftew_probe` cvar enables integration-test diagnostics and moves a named test player into the trigger. It defaults to zero and does nothing in ordinary playtests.

Failed validation leaves the last published world intact. Failed native compilation preserves the last `.dat`. Export + Play stages its script compilation before publishing the world, then publishes the script and launches FTE. Publishing the complete world/script/resource collection is not a single atomic filesystem transaction; a final I/O error stops the launch and reports the problem.

## Current limits

- FTEW v1 is experimental and may change. It is inspired by a scene/resource workflow; it is not compatible with Source 2 or s&box files.
- Rendering currently reuses FTE's terrain patch batches, one degenerate quad per triangle, with flat normals. Collision uses FTE's shared BIH triangle/convex routines. Resource sharing in the file is not GPU instancing.
- The initial hard limit is 50,000 expanded triangles. Large-world streaming, baked visibility, lightmaps, smooth mesh normals and large-scene optimization are not implemented.
- Triangle collision is a surface shell, not a watertight BSP volume. Use explicit boxes where solid-volume contents are important. Axis-aligned trigger boxes are tested; rotated-volume player sweeps still need dedicated coverage.
- Supported explicit shapes are BoxShape3D. Moving entity render meshes, skeletal animation export, doors with moving geometry, particles, arbitrary Godot shaders and shader conversion are not implemented. The exporter rejects unsupported gameplay nodes; mark an editor-only subtree with metadata `fte_ignore = true` to omit it deliberately.
- Basic material export covers opaque albedo and unshaded/vertex-lit rendering. Lighting is approximate in the Godot viewport. Native materials remain the way to use richer FTE effects; a dedicated native material editor is future work.
- One connection per event is supported. Native relays can provide fan-out. Native event/action names and property values must match the entity implementation; the addon validates references and serialization, not every entity's semantic schema.
- A removed MapC source does not automatically delete an older `maps/<world>.dat`; remove that compiled file explicitly if abandoning the script. Mesh visibility is not an export switch; use the explicit mesh export mode or `fte_ignore`. Light visibility sets its initial native on/off state.
- Builds target the default desktop OpenGL path. Other renderers, platform distributions, legacy compatibility modes, and the combined client's `-dedicated` mode have not been qualified; use the separate server executable.

## Validation performed

- Godot addon parses and loads; deterministic repeated export; duplicate IDs, broken links, unsupported nodes and singular transforms rejected; last good world preserved.
- Portable C reader rejects every truncated length of the fixture, bad directory/version, NaN, invalid references, singular transforms and a missing entity terminator.
- Native client and dedicated server load the same world and MapC. Numeric floor point/hull and ramp collision checks match between both runtimes.
- Two independent clients join the dedicated server and load/render the native world. Physical trigger overlap changes the native light state from `1` to `0`; all three processes exit normally.
- An intentionally invalid QuakeC file fails without replacing the previous compiled script.
- PNG capture succeeds after replacing libpng's direct FILE access with callbacks in the isolated engine.
- Environment conversion checks cover explicit ambient color, uniform backgrounds, panorama coordinates and safe native sky paths. A live client captures the map default, day, dusk and reset; reset must match the default sky pixel.

Sky checks use `python Tools/stiletto/test_sky_runtime.py` (Pillow required) and Godot's `addons/stiletto_tools/test_environment.gd` script. The latter also regenerates the named day/dusk PNG presets from their `.tres` sources.

Dynamic-light Energy export and live brightness updates are covered by `test_light_export.gd` and `Tools/stiletto/test_light_runtime.py`. See [the brightness fix and reproduction steps](../docs/solutions/runtime-errors/dynamic-light-energy-ignored.md).

Directional export is covered by `test_directional_export.gd` (angle conversion, energy, visibility, shadows, and independence from node position). Compile `Tools/stiletto/sun_probe.qc` into `base/maps/ftew_sun_probe.dat`, then run `python Tools/stiletto/test_sun_runtime.py` for actual render captures of zero energy, sunlight with/without shadows, rotation, and reset. This also exercises native replication and the custom `rtlight` shaders. See [the directional-light implementation](../docs/solutions/runtime-errors/godot-directional-light-native-export.md).

Re-run with `Tools/stiletto/probe_runtime.py`, `probe_runtime.py --client`, `test_multiplayer.py`, the Godot `addons/stiletto_tools/test_exporter.gd` script, and the portable `Tools/stiletto/test_format.c` runner. Integration logs and captures live in `worldsrc/build/` and are ignored by Git. The format specification is in [FORMAT.md](FORMAT.md).
