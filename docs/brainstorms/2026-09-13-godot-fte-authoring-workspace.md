---
title: "Godot as Stiletto's FTE authoring workspace"
date: 2026-09-13
status: first-slice-implemented
type: architecture-proposal
---

# Godot as Stiletto's FTE authoring workspace

## Intended outcome

Use Godot Editor as the central workspace for scene construction, map logic, particle effects, model setup, materials, and native FTE script editing. FTE remains the game runtime. The user explicitly confirmed that GDScript gameplay is not required: the desired arrangement resembles Battlefield Portal, using Godot as the frontend while retaining natively supported scripting languages.

This expands the earlier [additive-world handoff](../godot-fte-additive-world-handoff.md) into an editor product. The first native-world slice is now implemented and has passed a two-client playtest, including native trigger-to-light I/O. See [the working editor and its limits](../../worldsrc/README.md). The broader feature set and delivery sequence below remain a proposal.

## Recommended structure

One Godot addon, provisionally `stiletto_tools`, with shared resources and export infrastructure:

- **World:** scene nodes, reusable scenes, evaluated CSG, meshes, collision, lights, spawnpoints, and volumes.
- **Logic:** typed FTE entities, connections, editable script components, and native QuakeC/MapC source.
- **Effects:** FTE particle resources, visual property controls, emitter placement, and preview.
- **Models:** model references, material assignments, collision previews, attachment markers, and animation/hero metadata.
- **Materials:** supported material presets and native FTE shader/material source editing.
- **Run:** validate, build changed resources, compile scripts when needed, launch/reload FTE, and collect diagnostics.

Godot loads and evaluates its own scenes. The addon serializes evaluated data to an FTE-owned export contract and native assets. Do not write a second TSCN parser or reconstruct Godot's scene runtime inside FTE.

The initial experience is one authoring workspace plus an FTE playtest window. A native FTE viewport embedded in Godot is a separate integration project, not something Godot's ordinary viewport provides. Start with a launched preview process; investigate embedding only after export and preview are reliable.

## World authoring

Authors should build unsealed environments from meshes, primitives, and CSG, arrange reusable scenes, and place collision, light, and gameplay nodes. Neither Radiant nor a BSP compile step needs to appear in this workflow.

The user clarified that raw MAP is acceptable for iteration, but the intended world format should follow a modern scene/resource architecture, taking inspiration from Source 2 and s&box. The production target is therefore a dedicated, versioned FTE world resource and compiled assets. Raw MAP is an optional diagnostic or temporary iteration path, not the shipping contract or a required intermediate representation.

FTE's existing heightmap, mesh collision, model, and entity systems remain reusable implementation foundations behind the new loader. Their existing serialization must not dictate the new world contract. The first implementation must prove a small native world resource with mesh placements, collision policies, and reliable client/server asset loading before freezing its binary layout. Having OBJ or glTF model support does not itself establish a complete world loader.

First support:

- Evaluated static meshes and CSG, including packaged textures and material assignments.
- Spawn markers and point entities.
- Box collision/trigger volumes.
- A calibrated point-light mapping.
- Reusable scene instances with stable exported object IDs.

Defer broad node compatibility, navigation conversion, lightmaps, streaming, and arbitrary physics bodies. Clearly report unsupported behavior with the source scene/node path. Test player hull movement, projectile traces, mirrored transforms, nonuniform scale, and dedicated-server loading.

OBJ is the previously proposed simple static mesh target. glTF/GLB deserves a bounded comparison because both Godot export APIs and FTE loader source exist; production support must be tested in the actual engine build. Preserve the existing IQM workflow for animated characters until a replacement is demonstrated.

## Native world resources and compilation

The proposed pipeline is:

```text
Godot scenes + reusable resources + native script source
    -> evaluate scene and validate supported behavior
    -> FTE world build data and dependency graph
    -> incremental resource compiler
    -> native world descriptor + compiled payloads
    -> FTE world loader
```

Godot scenes remain the editable source. The compiler produces runtime data tailored to FTE. A readable intermediate manifest can assist debugging, but renaming JSON or putting files in an archive does not by itself supply a modern world architecture.

Design the world resource around these separately addressable records/payloads:

| Resource | Purpose |
|---|---|
| World descriptor | Format version, required capabilities, coordinate/unit convention, bounds, dependencies, and resource IDs. |
| Render geometry | Indexed meshes, material bindings, shared instances, bounds, and supported vertex attributes. |
| Collision | Explicit collision meshes/convex volumes, contents masks, and acceleration data where a stable FTE encoding is implemented. |
| Spatial data | Cells or another hierarchy for culling and collision broad phase; optionally later streaming and occlusion data. |
| Entities and logic | Stable IDs, typed properties, FTE parent relationships where needed, event connections, and compiled MapC references. |
| Environment | Supported light, sky, fog, sound, and effect references; optional later bake/probe resources. |
| Development metadata | Source scene/node mapping and build hashes; removable from release output. |

These are proposed responsibilities, not claims that every subsystem already supports these payloads. Start with a small required core and versioned optional sections. Reserve supported vertex streams such as tangents, vertex colors, and secondary UVs in the design; they need corresponding loader/render support before being advertised to authors. Avoid inventing a universal replacement format for every texture, model, or sound.

Flatten static transforms for runtime efficiency while retaining source object identity. Preserve runtime parenting explicitly only for entities that need it. Reusable Godot scenes should produce shared resources and instance records wherever practical. Static scenery must not consume one networked QC entity per visible object; dynamic gameplay entities use the established authoritative server and replication model.

The logical resource format and its distribution container are separate decisions. Initially use loose files for development and evaluate the existing FTE package system for delivery. The same world descriptor and loader should serve both. Do not require Valve VPK, VMAP, or compiled Source 2 compatibility; borrow architectural ideas and use an FTE-owned contract.

**Fast build:** rebuild changed resources and use inexpensive supported lighting, while retaining the production world format and loader. **Full build:** apply implemented geometry optimization, collision preparation, visibility processing, and optional lighting/navigation bakes. Fast and full builds must preserve gameplay semantics. Streaming and advanced lighting remain later runtime features, not benefits obtained merely by reserving fields in a file.

Compilation should retain useful spatial granularity: neither one huge merged mesh nor thousands of unculled, independently submitted objects is an acceptable default. Choose chunk size and batching from measurements. Precomputed collision acceleration is a follow-up if the first loader builds FTE's existing structure at load time; do not serialize engine pointers or private structs as a durable file format.

The first native-world proof needs version validation, one static resource reused at multiple transforms, separate collision/trigger data, entity references, and server/client loading through the new path. Explicit-extension loading is acceptable initially; completion, package dependencies, and extension-free map selection must be integrated before routine use.

Relevant primary references:

- [s&box scene mapping](https://sbox.game/dev/doc/editor/mapping/) documents geometry editing directly in the scene, including mesh editing, materials, and vertex painting.
- [s&box HammerMesh](https://sbox.game/dev/doc/scene/components/reference/hammer-mesh) separately documents a compiled-geometry workflow that generates a runtime model and can provide rendering and collision components. This is evidence for that workflow, not a specification of every scene-map binary format.
- [s&box map loading](https://sbox.game/dev/doc/scene/maps/loading-maps) describes map resources instantiated into scenes, including multiple map instances.
- [s&box map networking](https://sbox.game/dev/doc/scene/maps/networking) distinguishes locally loaded static map content from replicated dynamic objects. Apply that separation using Nuclide's networking rules rather than copying s&box ownership behavior.

## Baseline and compatibility policy

The user prefers simplicity and flexibility over strict historical engine profiles. Use one project default: **FTE-native with the existing Nuclide game layer**. This is a proposed project preset, not an existing named FTE compatibility mode. Keep import formats, material syntax, render backend, and gameplay runtime as separate choices.

| Layer | Default | Flexibility |
|---|---|---|
| Game/runtime | Existing `base` Nuclide progs and native QC/MapC; preserve the manifest's `GAME quake` baseline. | Imported maps do not automatically gain their original game's entities, physics, or game code. Add explicit mappings where useful. |
| New worlds | The dedicated native world resource described above. | Retain existing FTE map loaders for legacy levels and tests; do not bind the new format to a BSP family. |
| Generated materials | One `.mat` resource per material, following Nuclide's documented convention and FTE's extended Q3-style syntax. | Reference existing `.mat`, `.shader`, or other working native materials directly; retain advanced source editing. |
| GPU shaders | Existing built-in programs where appropriate; OpenGL/GLSL as the initial verified target. | Additional renderer backends are supported according to their actual program/capability coverage, not inferred from material syntax alone. |
| Images | PNG/TGA as convenient defaults for newly generated images. | Preserve existing usable formats, including DDS/KTX when supported; compression/mip generation is optional build processing, not mandatory authoring friction. |
| Shading | A simple lit or unlit default with optional normal/emission/alpha controls. | Allow richer native materials and explicitly supported PBR variants without requiring PBR for every surface. |

Local evidence: `base.fmf` selects `GAME quake` and `GAMEDIR base`; saved `base/config.cfg` and `base/fte.cfg` select `vid_renderer gl`. These are configuration observations, not a live runtime capability probe. `Documentation/Materials.md` recommends individual `.mat` files and explicitly describes using modern materials with older BSPs. `Documentation/Shaders.md` documents the material `program` command. The engine parser scans both Q3-style shader files and Doom 3 `.mtr` files, while Source VMT/VTF loader code lives in `plugins/hl2/`. Presence in source does not prove a plugin is distributed or loaded.

The editor should normally ask for a texture or material, not an engine compatibility profile. Generate a default material for a plain image, preserve a supplied native material, and expose advanced properties on demand. Native passthrough does not require a complete Godot preview or round-trip parser: mark approximate previews and use FTE to inspect the true result. Track required loaders/dependencies during export.

Keep these semantics explicit:

- Material appearance and world collision/contents are separate runtime concerns. Extract supported imported surface semantics into world build data; do not assume passing through a shader creates water volumes, player clips, or sky collision behavior.
- `q3map_*`, `qer_*`, and `vmap_*` directives include toolchain instructions. FTE's runtime parser can ignore these; the new compiler must implement the subset it promises or report a meaningful omission. Nuclide's `vmap_*` prefix is not evidence of Source 2 VMAP compatibility.
- Different material dialects can interpret similar fields differently. Do not mechanically rename Doom 3/Source material fields into native FTE fields and assume equivalent shading.
- Color textures and numerical data textures need correct color-space handling. Normal orientation, alpha behavior, sampler settings, and packed roughness/specular channels need defined mappings only when relevant to an imported resource.
- Map format support is not game compatibility: foreign classnames and logic still need Nuclide equivalents. Keep format selection from changing gameplay mode or enabling broad compatibility heuristics.
- Match the shipped client/server build and renderer capabilities. Servers need world collision, entities, and scripts without requiring rendering assets to initialize a GPU. Optional client plugins should be recorded and shipped when used.

Validation should prevent broken exports without policing harmless choices. Use sensible defaults and visible fallbacks for optional appearance differences; fail for missing required resources, broken references, or unsupported gameplay/collision semantics. Do not impose one historical format on every asset, or a conversion step when FTE already handles it correctly.

## Native map logic with modern editor controls

The visual editor must be extensible beyond a fixed prefab palette.

1. Start with typed wrappers for useful existing entities: trigger volumes, relays, timers, particle emitters, and movers where supported.
2. Store editor connections as typed references. Resolve them into stable export IDs and Nuclide input/output records at export; do not rely on fragile typed target names or runtime Godot NodePaths.
3. Introduce a small component schema defining editable properties, defaults, inputs, outputs, and the native runtime implementation. Read entityDef metadata where sufficient; use a companion schema for editor information not present in entityDefs. Preserve arbitrary native keys through an advanced inspector.
4. Supply a native script editor dock with QuakeC/MapC syntax support, file navigation, compilation, and errors mapped back to source. This requires addon work; the built-in GDScript editor is not automatically a QC language service.
5. Use existing Nuclide I/O directly for ordinary event wiring. Compile MapC for custom map behavior and generated logic that needs code. Use RuleC for mode-wide rules rather than treating it as the default home for every map event.

Example authoring interaction: resize an entrance volume; connect its enter event to a door's open action and an emitter's start action; add a timer that stops the emitter; expose the delay in the inspector. A custom encounter can then use a MapC implementation with inspector-visible parameters and entity references, without expanding the editor's hardcoded behavior list.

The first node palette is illustrative. Some wrappers will map directly to existing entities; others, such as a reusable wave controller, need a small native implementation. Arbitrary Godot signal connections are not automatically executable FTE logic.

Gameplay authority remains on the server. Later live editing should distinguish temporary runtime overrides from saved authoring changes, and use stable IDs to associate an FTE entity with its source node. Start by reading logs/state; add selected property changes only when the runtime can safely apply them.

## Particle editing

Build an FTE particle resource inspector in Godot. Initially expose a documented subset: texture, lifetime, size, color/alpha, velocity/spread, gravity, and emission behavior. Add curves/ramps and advanced fields only where their mapping to FTE is defined.

Export FTE particle definitions and place them through Nuclide's `info_particle_system`, which already has start/stop/toggle inputs. Preserve native effect references and provide a native-source escape hatch rather than claiming a lossless importer for every particle script.

Godot preview can approximate the supported subset for convenient placement. The actual FTE preview is authoritative. Godot GPU particle shaders have their own processing semantics and are not portable FTE particle definitions. Existing particle resources can be converted only within an explicitly supported subset, with diagnostics for the rest.

FTE source already contains particle reload machinery. Connecting it to an external editor and proving existing emitters update correctly is still implementation work.

## Models

Godot can be the central place to arrange models, preview imported animation clips, edit material assignments, place sockets/attachment markers, and author FTE collision and animation metadata. FTE-specific attachments and collision need explicit export/runtime mappings; placing a Godot bone attachment alone does not implement them in FTE.

For existing IQM assets, permit a Godot-compatible preview asset alongside the actual FTE model reference. Do not replace the established hero animation mappings or runtime models just to enable editor placement.

This addresses model setup and iteration. Full topology editing, sculpting, UV work, and rig creation remain a DCC task, normally Blender; supporting those within Godot would be another substantial tool project.

## Materials and shaders

Offer two practical paths in one material workspace:

- **Visual material resource:** supported parameters generate an FTE material declaration and a Godot preview approximation. Start with texture/tint, alpha mode, normal/emission where supported, and a few deliberate presets.
- **Native source:** edit existing FTE material scripts and GLSL programs in a custom source dock, then compile/reload and inspect the result in FTE. Preserve hand-authored source and avoid overwriting it with generated output.

A future restricted visual graph could generate both Godot preview code and FTE shader code. That requires defining and maintaining both outputs; arbitrary Godot VisualShader graphs or ShaderMaterials do not transfer automatically. Similarity to GLSL does not supply matching uniforms, renderer passes, lighting, or screen/depth resources.

Record the active FTE renderer in preview settings. Native shader editing should initially target the renderer actually used by Stiletto; support for other render backends needs separate validation.

## Build and preview contract

Keep editable scenes/resources and native script source separate from generated map assets. Build into a dedicated output directory with a dependency manifest. Validate references, missing assets, unsupported features, and transforms before replacing the last successful output. Report errors against source nodes/resources.

Provide both an editor button and a headless export entry point so human iteration and automated/LLM changes use the same compiler. Deterministic output, undoable editor operations, stable IDs, reusable scenes, and small text resources are central requirements.

Use a capability-based preview bridge rather than promising universal hot reload:

- Geometry/collision: initially re-export and reload the map.
- Native scripts: compile and reload/restart the appropriate runtime scope initially; do not promise preservation of arbitrary live script state.
- Particle/material resources: connect existing engine reload facilities, verifying actual updates.
- Selected entity properties: later opt-in runtime changes with clear persistence behavior.

## Delivery sequence

**Milestone 1 — a useful map and logic loop.** An isolated Godot authoring project and addon; a minimal native world resource/compiler/loader; one mesh/CSG test environment, collision, two spawn markers, one point light, one trigger and controllable object/effect; typed references; one native MapC behavior editable and compilable from the addon; deterministic export; one-click FTE playtest and actionable diagnostics. Prove movement and trigger behavior on a server and two clients using the native world path. Raw MAP experiments alone do not complete this milestone. Movers can initially use a supported box/brush collision representation without requiring MAP files as the world format.

**Milestone 2 — effects and material iteration.** One real FTE particle effect with visual controls and native preview; a small material preset editor; native shader source editing and reload; model setup resources that preserve the IQM workflow.

**Milestone 3 — extensible authoring and live inspection.** Schema-driven custom components, reusable encounters/objectives, runtime entity inspection, selective property updates, and measured improvements to preview integration. Expand supported content in response to actual maps.

Production readiness additionally requires world visibility/performance measurements, lighting policy, distribution/download tests, and validation of larger maps. The inspected heightmap backend has no conventional cluster PVS result, so skipping BSP does not automatically replace its visibility benefits.

## Evidence checked on 2026-09-13

Local source inspection, not a runtime test:

- Canonical engine tree: `C:/Users/sokky/Documents/Godot/bulwark_proto_funny/workspace/fteqw`.
- `engine/gl/gl_heightmap.c`: `Terr_LoadTerrainModel`; format registration near lines 9234–9235; `exterior empty`; `Terr_AddMesh`; `Heightmap_ClusterPVS` returns NULL. Registration is currently in this file, unlike the location named by the older handoff.
- `engine/common/com_mesh.c`: OBJ loader and static mesh collision setup (`Mod_SetMeshModelFuncs`).
- `plugins/models/gltf.c`: glTF loader with documented material, animation, and mesh limitations; build inclusion and concrete assets remain to be tested.
- `engine/client/p_script.c`: native particle property parser and reload callback.
- `engine/client/textedit.c`: saves under `scripts/` request shader reload; saves under `particles/` force the particle-description callback. This is an internal editor path, not evidence of an existing Godot bridge.
- `src/server/MapDelegate.qc`: loads map-specific `.dat` through multi-progs and calls its main function.
- `src/gs-entbase/server/logic_timer.qc`, `logic_relay.qc`, and `src/gs-entbase/shared/info_particle_system.qc`: existing native logic/emitter implementations.
- [Known raw-map spawn issue](../solutions/runtime-errors/duel-map-spawnpoints-world-origin-initialization-race.md): retain regression coverage for entity origin/angle handling and avoid comment-sensitive generated spawn records.
- Existing Godot prototype: `D:/c drive/Godot/stiletto-protophase2/project.godot` declares Godot 4.4 features. Pin the addon implementation to a selected installed version; do not assume every API in current stable documentation exists in 4.4.

Godot primary references consulted:

- [EditorPlugin](https://docs.godotengine.org/en/stable/classes/class_editorplugin.html): custom node/resource editing, inspector hooks, gizmos, panels, and import/export extension points.
- [GLTFDocument](https://docs.godotengine.org/en/stable/classes/class_gltfdocument.html): scene-based glTF export APIs; these export asset data, not native FTE gameplay.
- [Shading language](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html): Godot's shader language and semantics.
- [Particle shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/particle_shader.html): Godot particle processing semantics.

## Next implementation decision

Scope the first milestone around an isolated authoring project, a supported node/resource list, and a minimal native world compiler/loader. Resolve the world descriptor, payload references, spatial organization, and reuse of existing FTE runtime internals through a focused proof. Raw MAP/HMP is an optional iteration aid; it is no longer a candidate production contract. Godot provides the editor, the world compiler produces FTE-native scene resources, and native FTE/Nuclide systems execute the game.
