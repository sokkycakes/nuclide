---
title: "Godot-authored additive worlds for FTEQW"
type: architecture-handoff
status: proposed
date: 2026-07-17
purpose: "Research and requirements handoff for a separate planning agent"
---

# Godot-authored additive worlds for FTEQW

## Purpose

This document captures the architecture, requirements, verified FTE seams, prior-art findings, and unresolved questions for a Godot-to-FTE world pipeline. It is intentionally not an implementation plan. Another agent should use it as the source document for a scoped plan after inspecting the current Nuclide and FTE trees.

The intended authoring model is closer to Godot, Unity, Unreal, or Battlefield Portal than traditional Quake mapping:

- Space is empty unless geometry or contents are added.
- Maps do not need to be sealed.
- There is no leak or traditional void failure.
- Authors place meshes, CSG, lights, collision, triggers, and point entities in a Godot scene.
- An exporter converts the evaluated scene and its resources into FTE-native runtime assets plus a small world manifest.
- FTE never parses `.tscn` and never embeds Godot's scene or scripting runtime.

The previous attempt to support Godot scenes inside FTE became difficult because FTE was made responsible for understanding Godot serialization and semantics. This proposal keeps that responsibility in Godot, where the scene has already been loaded and evaluated correctly.

## Product statement

A map author should be able to create a scene using ordinary Godot nodes and local project assets, press an export command, and run the resulting map in Nuclide. They should not need to pre-register every asset in a Battlefield-style catalog.

The exporter is a content compiler, not just a placement-list writer. It must produce or preserve every runtime resource needed by the exported world:

```text
Godot project and map scene
    |
    | Godot loads scenes, resources, scripts, imports, and CSG
    v
Godot-side FTE exporter
    |-- FTE world manifest
    |-- converted static meshes
    |-- copied or converted textures
    |-- generated FTE material/shader declarations
    |-- collision and trigger representations
    `-- FTE/QC entity data
    |
    v
Nuclide game directory
    |
    v
FTE additive world loader
```

## Non-negotiable architecture

### Godot is the source reader

The exporter must use Godot APIs against an instantiated scene tree. It may run as an `EditorPlugin`, an editor tool script, or a headless Godot export command.

It must not implement a second `.tscn` parser in FTE, Python, C, or QC.

Godot remains responsible for:

- `.tscn` and `.scn` parsing.
- `PackedScene` inheritance and instancing.
- `ExtResource` and `SubResource` resolution.
- Imported GLTF, FBX, Blender, and other source resources.
- Script-defined exported properties.
- Parent/child transform composition.
- Procedural and primitive `Mesh` resources.
- Evaluating CSG into final geometry.

FTE receives a versioned, FTE-owned interchange format containing already-resolved runtime data.

### FTE does not run GDScript

GDScript can perform editor-time generation and describe exported properties. Runtime gameplay remains QC or an existing FTE-native system.

A Godot script or component may declare that a node exports as `trigger_hurt`, `prop_static`, `info_player_start`, or another QC classname. The exporter serializes its properties. The matching QC implementation supplies runtime behavior.

### The format belongs to this project

Battlefield Portal's `.spatial.json` is prior art, not the proposed runtime contract. The FTE format must have its own name, version, schema, and semantics. Working names in this document include `.fteworld.json` and "FTE spatial manifest"; the planning pass may choose the final extension.

The first version should be deliberately small. A version field is required so incompatible changes fail clearly instead of being guessed.

## Battlefield Portal prior art

Battlefield Portal uses Godot as a spatial editor and exports a `.spatial.json` file for Frostbite. The inspected SDK flow does the following:

1. Saves the current Godot scene.
2. Runs an external exporter.
3. Reads a controlled subset of `.tscn` syntax.
4. Resolves asset types using a large asset registry.
5. Flattens local transforms into world transforms.
6. Resolves node references into exported IDs.
7. Writes instance records under `Portal_Dynamic` and `Static` layers.

A typical record has an asset type, stable ID, basis vectors, position, and typed properties:

```json
{
  "name": "CardboardBoxes_01_M",
  "type": "CardboardBoxes_01_M",
  "right": { "x": 1, "y": 0, "z": 0 },
  "up": { "x": 0, "y": 1, "z": 0 },
  "front": { "x": 0, "y": 0, "z": 1 },
  "position": { "x": -2.98783, "y": 0.597212, "z": 0.247573 },
  "id": "CardboardBoxes_01_M"
}
```

### Useful ideas to retain

- A narrow export boundary between Godot and the target engine.
- Flat world-space transforms rather than runtime scene-tree reconstruction.
- Stable IDs for cross-object references.
- Typed properties with validation and defaults.
- Separate static geometry, dynamic/gameplay objects, volumes, and paths.
- Export-time validation of unsupported or invalid content.
- An editor button that saves and exports the current level.

### Parts that do not fit Nuclide

Portal records refer to assets already present in Frostbite. They do not generally contain mesh vertices, materials, arbitrary collision, or general Godot light data. Nuclide authors will place their own project assets, so the FTE exporter must package those resources.

The public exporter implementation also uses a handwritten text parser for a controlled subset of `.tscn`. That is the failure mode this project must avoid. The project should copy the architecture, not the parser.

The inspected public SDK mirrors do not provide a clear repository-wide license for the converter and EA data. Do not copy the converter source. Implement the FTE exporter independently using Godot's public APIs.

Useful references:

- Official EA overview: <https://www.ea.com/games/battlefield/battlefield-6/news/portal-101-advanced-creations>
- Community PortalSDK mirror inspected during research: <https://github.com/battlefield-portal-community/PortalSDK>
- Additional non-official mirror identified during research: <https://github.com/JDWardle/BFPortalSDK>

Treat community mirrors as technical references only. EA's official material is authoritative about Portal behavior.

## Verified FTE foundation

The current FTE tree already contains most of the world-side primitives needed for a proof of concept.

### Runtime raw-map and heightmap world loader

`engine/gl/gl_model.c` registers text map formats with `Terr_LoadTerrainModel`, including:

- `FTE Heightmap Map (hmp)`
- `Quake Map Format (map)`

The raw `.map` path is loaded as `mod_heightmap`; it is not sent through QBSP first.

`engine/gl/gl_heightmap.c::Terr_LoadTerrainModel()`:

- Creates a `mod_heightmap` world.
- Reforms and stores an entity lump.
- Installs native trace, contents, lighting, cluster, and visibility callbacks.
- Supports explicit empty exterior contents.

`Terr_ParseEntityLump()` recognizes the worldspawn key:

```text
exterior empty
```

and sets `exteriorcontents` to `FTECONTENTS_EMPTY`. This provides the no-seal, no-void world behavior.

### Direct brush and patch parsing

`Terr_ReformEntitiesLump()` parses world and submodel brushes directly from raw `.map` text. The heightmap world trace tests those brushes without BSP compilation. It also has patch support.

This path may be useful for simple convex collision, triggers, or moving brush entities, but the first proof does not need to convert every Godot mesh into brushes.

### Sectioned static model instances

`engine/gl/gl_heightmap.c::Terr_AddMesh()` inserts a model instance into terrain sections using its bounds and transform. Section records retain:

- Model reference.
- Position.
- Orientation basis.
- Uniform scale.
- Section references used for drawing and tracing.

The section draw path renders alias/static models and brush models. The heightmap trace path calls each embedded model's `NativeTrace` callback.

### Static triangle collision

Static mesh models use FTE's mesh collision path. `engine/common/com_mesh.c::Mod_SetMeshModelFuncs()` installs trace and contents callbacks and calls `BIH_BuildAlias()` for static meshes. OBJ is already registered as a model format and is therefore a practical first interchange format for static geometry.

### JSON parsing

FTE already has a JSON implementation in `engine/common/json.c`. Existing engine code calls `JSON_Parse`, `JSON_FindChild`, `JSON_GetIndexed`, and related helpers. A JSON manifest does not require introducing a new JSON dependency.

### Server world-model acceptance

`engine/server/sv_init.c` accepts a loaded world model when it supplies `NativeTrace` or `PointContents` and has entity data. The server's map-extension lists currently include formats such as BSP, CM, HMP, and explicit raw MAP handling. A new extension would need to be added consistently to loading, map listing/completion, download/package handling, and client resolution.

### Visibility limitations

The heightmap backend is not a traditional BSP/PVS world:

- `Heightmap_ClusterPVS()` currently returns `NULL`.
- Static instance and terrain visibility rely on sections, bounds, frustum checks, and distance behavior.
- The current embedded-model draw path includes hard-coded distance/fade behavior that may need review for production maps.

This is acceptable for a proof but must be called out in any implementation plan.

## Authoring model

### Ordinary geometry

A `MeshInstance3D` should export without prior catalog registration.

For each unique evaluated mesh resource, the exporter either:

1. References an existing FTE-native asset when explicitly requested and already available in the Nuclide runtime tree, or
2. Converts the evaluated Godot `Mesh` into an FTE-compatible static mesh and writes it into the map's generated asset directory.

Each scene instance then writes a placement record containing the exported model path, world transform, flags, and collision policy.

This applies to:

- Imported GLTF, FBX, and Blender assets as exposed through Godot.
- `ArrayMesh`.
- `PrimitiveMesh` resources such as `BoxMesh` and `CylinderMesh`.
- Meshes generated by editor tools.
- Meshes produced from evaluated CSG.

### CSG

Godot must evaluate CSG. FTE should receive the final mesh, not the CSG operand tree.

The baseline path is:

```text
Godot CSG tree -> evaluated mesh -> static render mesh -> BIH mesh collision
```

Simple convex primitives may later export as raw FTE brushes for better swept-box collision or brush-entity behavior. That is an optimization and should not block the first implementation.

### Point entities

Authors need a lightweight way to mark a positioned node as an FTE/QC entity. There should be no requirement to create an asset-registry entry for every prop or classname.

The minimum convention can use `Marker3D`, `Node3D`, groups, or metadata:

```text
fte_classname = "info_player_start"
angle = "90"
```

A better editor experience may add one generic `FTEEntity3D` tool class with fields such as:

- `classname`
- `targetname`
- `spawnflags`
- arbitrary key/value properties
- optional existing FTE model path
- optional child mesh used as both preview and export source

The class is editor tooling only. Exported output must be normal entity data independent of the Godot class.

Example authoring tree:

```text
FTEEntity3D [classname = prop_static]
`-- MeshInstance3D [chair.glb]
```

The exporter converts the chair mesh, writes its runtime path into the entity's `model` property, and emits the entity transform and keys.

### Volume entities

Recommended authoring mappings:

| Godot node | Export meaning |
|---|---|
| `Marker3D` or plain `Node3D` with FTE metadata | Point entity |
| `Area3D` + `CollisionShape3D` | Trigger or contents volume |
| `StaticBody3D` | Collision-only or render-and-collision geometry |
| `AnimatableBody3D` | Candidate mover/door entity; deferred unless explicitly included |
| `MeshInstance3D` | Static world geometry or model-backed entity |

Box and convex trigger shapes should preferably become conventional FTE brush-model entities so existing QC trigger code works without a parallel trigger runtime. Concave trigger shapes require an explicit policy and should not be assumed safe.

### Lights

Godot light nodes should export directly rather than through an asset catalog:

- `OmniLight3D` -> FTE point/realtime light.
- `SpotLight3D` -> FTE projected/spot light.
- `DirectionalLight3D` -> world sunlight or environment settings.

Relevant fields include transform, color, energy, range, cone angle, shadow flag, and optional projector texture where supported.

Godot and FTE do not use identical light units. The exporter needs a documented calibration rule; copying numeric energy values directly is not expected to look correct.

The first pass should use realtime lights. Godot `LightmapGI` data is not directly compatible and should be deferred until the static mesh format carries UV2/lightmap information and FTE has a matching render path.

### Scripts and gameplay components

Scripts fall into three categories:

1. Editor-only scripts that generate or configure content before export. These run in Godot and need no FTE equivalent.
2. Authoring components that expose typed properties and map a node to a QC classname. Their exported values become entity keys.
3. Runtime gameplay scripts. These must be implemented in QC or another existing FTE-native runtime; GDScript is not translated or executed.

Automatic GDScript-to-QC translation is outside this project's identity.

### Existing FTE-native assets

The exporter should allow authors to reference an asset that is already in a Nuclide game path rather than converting it again. This is useful for IQM characters, animated props, existing OBJ/MD3 assets, sounds, and hand-authored shaders.

A node or component should be able to select an export policy such as:

- Convert and package.
- Reference existing FTE asset.
- Editor preview only.
- Collision only.
- Ignore.

For an existing IQM runtime model, Godot may use a GLTF preview child while the exported entity points to the IQM path. Native IQM import inside Godot would be optional editor tooling, not a prerequisite for the world pipeline.

IQM is appropriate for animated/skeletal runtime models. It should not be the mandatory interchange format for static world geometry.

## Asset conversion requirements

### First static mesh target

OBJ is the shortest path for a proof because FTE already loads static OBJ geometry and can build BIH collision for it.

The exporter must preserve at least:

- Vertex positions.
- Triangle indices.
- Normals.
- Primary UVs.
- Surface/material separation.

It must apply the project's coordinate conversion and unit scale consistently to vertices, transforms, entity origins, collision, lights, and paths.

Nonuniform and mirrored transforms need an explicit policy. The existing terrain instance representation has an orientation basis plus uniform scale. The safe baseline is to bake nonuniform or negative scale into exported vertices and correct winding/normals during export.

### Future static mesh format

OBJ is not the final answer if the project needs:

- Tangents.
- Vertex colors.
- Multiple UV sets.
- Baked lightmap coordinates.
- Compact binary loading.
- Per-surface collision and contents flags.
- Better material metadata.

A later FTE-owned binary static mesh format may carry those fields. The proof should not invent it prematurely.

### Materials

The initial converter may support a limited `StandardMaterial3D` subset:

- Albedo texture and color.
- Normal texture.
- Emission.
- Alpha test or blending mode.
- Cull mode.
- Basic roughness/specular approximation where FTE supports it.

It may copy textures already readable by FTE or export generated/image resources to a supported format.

Arbitrary Godot `ShaderMaterial` code cannot be translated generally. Such nodes need an explicit FTE shader/material override or a warning. Unsupported material behavior must not silently produce a plausible but wrong result.

### Deduplication and generated paths

The exporter should write each unique source mesh and texture once per content hash or stable resource identity, then emit multiple instance records. Generated names must be deterministic so unchanged content does not create noisy output or invalidate references.

## Collision policy

Every exported geometry node needs a clear policy:

- None.
- Visual only.
- Visual plus model collision.
- Collision only.
- Convex/brush collision.
- Trigger volume.

Decorative render detail should not automatically become expensive collision unless that is the selected default.

Suggested mappings:

| Godot source | Initial FTE representation |
|---|---|
| Static evaluated triangle mesh | OBJ/static model with BIH collision when enabled |
| `BoxShape3D` | Six-plane brush or simple convex volume |
| `ConvexPolygonShape3D` | Convex brush where valid; otherwise explicit fallback |
| `ConcavePolygonShape3D` | Triangle/BIH collision |
| `Area3D` box/convex shape | Trigger brush-model entity |
| CSG with collision enabled | Evaluated mesh plus BIH collision in the first pass |

Player hull, projectile, and point traces must all be included in verification. A model that renders and blocks only point traces is not sufficient.

## Proposed manifest shape

This example communicates the contract shape only. It is not a frozen schema.

```json
{
  "format": "fteworld",
  "version": 1,
  "world": {
    "exterior": "empty",
    "sectionSize": 2048,
    "sky": "skies/example"
  },
  "models": [
    {
      "id": "mesh:crate",
      "path": "models/maps/factory/crate.obj"
    }
  ],
  "instances": [
    {
      "id": "factory/crate_17",
      "model": "mesh:crate",
      "basis": [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
      "origin": [768, -256, 64],
      "collision": "model",
      "visible": true
    }
  ],
  "lights": [
    {
      "id": "factory/light_3",
      "kind": "point",
      "origin": [512, 128, 192],
      "color": [1.0, 0.72, 0.48],
      "range": 640,
      "intensity": 2.4,
      "shadows": true
    }
  ],
  "entities": [
    {
      "id": "factory/spawn_1",
      "classname": "info_player_start",
      "origin": [128, 256, 64],
      "properties": { "angle": "90" }
    }
  ]
}
```

The format should distinguish resource definitions from placements so repeated instances do not repeat model metadata. Entity and light records should use stable IDs. References between records should be IDs, never Godot `NodePath` strings.

## Export decision rules

The exporter should process nodes in roughly this semantic order:

```text
Editor-only or explicitly ignored?
    Ignore.

Explicit existing FTE asset reference?
    Preserve its runtime-relative path.

Static MeshInstance3D or evaluated CSG?
    Convert and package the evaluated mesh.

Light3D?
    Emit an FTE light record.

Node has an FTE classname/component?
    Emit entity data and package any attached model.

Area3D or collision body?
    Emit collision or trigger representation according to policy.

Otherwise?
    Report an unsupported-node warning with the scene path.
```

Unknown content must not disappear silently. The export report should separate errors, warnings, converted resources, reused resources, and ignored editor-only nodes.

## Runtime loader responsibilities

The FTE loader should only perform runtime-native work:

1. Parse and validate the manifest version.
2. Create or initialize an empty-exterior `mod_heightmap` world.
3. Derive or consume section bounds.
4. Resolve exported model paths.
5. Insert static placements into sections using the existing terrain instance path.
6. Preserve collision flags and avoid tracing visual-only instances.
7. Create FTE light data through the correct existing light path.
8. Build or expose an ordinary entity lump for QC spawning.
9. Install the existing heightmap trace, contents, and visibility callbacks.
10. Fail clearly on missing required assets or unsupported manifest versions.

It should not reconstruct a Godot node hierarchy, evaluate materials, bake CSG, import Godot resources, or interpret GDScript.

## Suggested source and output layout

The exact project root must be decided after inspecting the current repository and prototype layout. A clean separation would look like:

```text
nuclide/
|-- worldsrc/
|   |-- project.godot
|   |-- addons/fte_world_exporter/
|   `-- maps/factory/
|       |-- factory.tscn
|       `-- source_assets/
`-- base/
    |-- maps/factory.fteworld.json
    |-- models/maps/factory/
    |-- textures/maps/factory/
    `-- scripts/factory.shader
```

If the Godot project lives above or beside `nuclide`, generated output may still target `nuclide/base/`. Existing assets inside `base/` should be referenced by game-relative path rather than copied.

Generated content should be clearly marked and safe to replace. Source files and hand-authored runtime files must never share a directory where export cleanup could delete them accidentally.

## Scope recommendation

### Proof of concept

The smallest useful vertical slice contains:

- One unsealed map with empty exterior.
- One imported `MeshInstance3D` converted to OBJ.
- One Godot primitive or baked CSG object converted to OBJ.
- Model collision verified for player and projectile traces.
- One `OmniLight3D` converted to an FTE realtime light.
- One `Marker3D` exported as `info_player_start`.
- One `Area3D` box exported as a QC trigger entity.
- One editor component with typed properties exported to entity keys.
- A single editor/headless export command producing deterministic output.
- `map <name>` loading the new manifest without requiring its explicit extension, if extension registration is included in the proof.

### Follow-up work

- Material conversion beyond the basic subset.
- Better static mesh format.
- Lightmaps and UV2.
- LOD and instancing optimization.
- Occlusion, PVS, portals, or world partition.
- Navigation export.
- Animated/moving entity workflows.
- Godot IQM importer for editor preview.
- Hot reload.
- Collaborative editing.

### Explicit non-goals

- Parsing `.tscn` in FTE.
- Embedding Godot or running GDScript in FTE.
- Automatic GDScript-to-QC translation.
- Full compatibility with Battlefield `.spatial.json`.
- Requiring an asset registry before arbitrary local meshes can be placed.
- Replacing BSP support for existing maps.
- Solving production world streaming, PVS, and baked lighting in the first vertical slice.

## Requirements for the planning agent

The planning agent should convert this handoff into stable implementation units only after it performs the following checks.

### Repository and source-tree checks

There are multiple FTE trees in this environment and existing project rules have changed over time. Inspect the active `.cursor/rules/*.mdc`, git worktrees, build scripts, and current branches before naming authoritative edit paths.

Known locations seen during research include:

- `C:\Users\sokky\Documents\Godot\bulwark_proto_funny\workspace\fteqw\engine\`
- `C:\bld\fteqw_src2\engine\`
- Project rules referring to an `fteqw\engine\release\` tree

Do not assume the research copy is the current source of truth. Do not modify any engine tree during planning.

The engine build must use the project's existing ccache-enabled process. The planning agent should cite the current rule and build script rather than inventing a new build command.

### Existing-code inspection

Before designing new modules, inspect at least:

- Model format registration in `gl_model.c`.
- `Terr_LoadTerrainModel`, `Terr_ParseEntityLump`, `Terr_AddMesh`, section drawing, and `Heightmap_Trace` in `gl_heightmap.c`.
- Static mesh collision setup and OBJ loading in `com_mesh.c`.
- JSON API in `common/json.c` and its headers.
- World-model resolution and extension lists in `server/sv_init.c` and `server/sv_ccmds.c`.
- Filesystem map recognition and client download behavior.
- Existing QC spawn/entity parsing and light handling.
- The actual Godot prototype/project version and current addon conventions.

The plan should reuse these seams unless inspection proves they cannot satisfy the requirements.

### Decisions the plan must resolve

- Final manifest extension and version policy.
- Whether v1 uses a new loader or translates the manifest to an existing raw `.map`/HMP representation before runtime.
- How static instances distinguish visual-only, collision-only, and visual-plus-collision.
- How the loader calls or exposes `Terr_AddMesh`, which is currently internal to `gl_heightmap.c`.
- How world bounds and terrain sections are initialized when no heightfield exists.
- Whether the proof emits a minimal flat/default terrain section, holes, or no terrain surface at all.
- Which FTE-native light representation receives exported lights.
- Whether trigger volumes become raw-map brushes, generated submodels, or manifest-native collision volumes.
- Exact coordinate and unit conversion.
- Deterministic asset naming and deduplication.
- Godot version and API for retrieving evaluated CSG meshes.
- Material support boundary for v1.
- Packaging and cleanup safety for generated files.
- Rollback behavior when the new loader is disabled or an export is invalid.

## Acceptance scenarios for the eventual plan

A plan produced from this document should include concrete verification for at least these cases.

### Export success

- A Godot scene containing an imported mesh, primitive mesh, CSG object, point light, spawn marker, and box trigger exports without reading `.tscn` as text.
- Running export twice without source changes produces byte-identical or semantically stable generated output.
- Two instances of one source mesh produce one generated model and two placements.
- An existing Nuclide model reference remains a reference and is not duplicated.

### Geometry and transforms

- Parent transforms are flattened correctly.
- Rotated geometry has matching render and collision orientation.
- Nonuniform and mirrored transforms follow the documented bake/reject policy.
- CSG subtraction appears as the evaluated final mesh in FTE.
- The world remains playable without a sealed shell.

### Collision

- Player swept-box movement collides with exported static geometry.
- Point and projectile traces collide consistently.
- Visual-only geometry does not collide.
- Collision-only geometry is invisible and blocks correctly.
- A box trigger activates the existing QC entity and does not become solid world geometry.

### Entities and references

- `info_player_start` spawns the player at the exported transform.
- Arbitrary string, integer, float, boolean, and resource-path properties survive export with documented type conversion.
- Duplicate stable IDs fail export.
- A target/targetname-style reference resolves after Godot hierarchy flattening.
- A node with an unsupported runtime GDScript behavior produces a clear warning or error rather than silently omitting behavior.

### Lights and materials

- Exported point-light position, color, radius, and shadows are visibly correct after calibration.
- A basic albedo/normal/emissive material maps to the expected FTE shader behavior.
- Unsupported custom Godot shaders report the missing override.

### Loading and failure behavior

- `map` loads the generated world through the intended extension path.
- Missing mesh, malformed JSON, and unsupported version errors identify the map and failing record.
- Existing BSP maps still load unchanged.
- Dedicated server loading works without relying on client-only Godot or renderer code.
- A client receives or locates the manifest and all referenced generated assets using normal FTE packaging/download rules.

### Performance sanity

- Repeated instances are sectioned and culled independently.
- A map with enough placements to cross multiple sections does not trace every instance globally.
- The plan records the lack of traditional PVS and identifies a measurement threshold before production rollout.

## Risks

### Dedicated-server separation

`Terr_AddMesh()` and parts of terrain instance storage are guarded by client-related compilation in the inspected code. Collision for embedded instances must exist on the server as well as the client. The plan must verify the actual compile guards and may need to separate shared spatial/collision instance data from render-only entity data.

### Transform correctness

The inspected terrain trace code appears to scale local trace coordinates in a way that deserves verification, particularly for scales other than one. Do not assume arbitrary uniform scale has correct collision until tested. Baking scale into geometry may be safer for v1.

### Static-world rendering assumptions

The embedded model draw path currently has distance/fade calculations and only handles specific model types. Production behavior may require a small cleanup rather than treating it as a finished general-purpose static-mesh system.

### Materials and lighting scope creep

Geometry export is straightforward compared with matching Godot's renderer. Keep v1 to a documented material subset and realtime lights. Do not let full material parity or Godot lightmap compatibility block the world-loader proof.

### Generated-content safety

An exporter that removes stale output can destroy hand-authored files if paths are mixed. Generated directories, ownership markers, and cleanup rules are requirements, not polish.

### Format drift

The interchange schema is a runtime API. Version it, validate it, and keep a small fixture map under test. Do not infer missing fields differently across engine versions.

### Legal reuse

The Battlefield exporter and asset registry were inspected as prior art. Their licensing is unclear outside specifically licensed bundled components. Keep implementation independent and do not copy code or EA asset metadata.

## Research evidence summary

The following claims were verified in source during the conversation that produced this handoff:

- FTE registers raw `.map` and `.hmp` text model loaders through `Terr_LoadTerrainModel`.
- `mod_heightmap` supports `exterior empty`.
- Raw-map brushes and patches are parsed without QBSP.
- `Terr_AddMesh` stores transformed model instances in sections.
- Heightmap traces call embedded models' `NativeTrace` callbacks.
- Static OBJ/mesh models can receive BIH collision through `BIH_BuildAlias`.
- Heightmap PVS is currently effectively absent.
- FTE has an internal JSON parser suitable for a small manifest.
- Battlefield Portal exports flattened asset placements and properties, not arbitrary source geometry.
- The inspected Portal exporter manually parses a controlled subset of `.tscn`; this project explicitly rejects that approach.

These findings should be rechecked against the exact engine tree selected for implementation because this repository has multiple source and build copies.

## Planning handoff

A good implementation plan should preserve the following order of proof:

1. Confirm an empty-exterior world with no sealed shell.
2. Load one generated static mesh as sectioned render geometry.
3. Prove server and client collision against the same placement.
4. Add entity-lump generation and one spawn marker.
5. Add a conventional box trigger.
6. Add one realtime light.
7. Integrate the Godot editor/headless exporter and deterministic asset packaging.
8. Expand materials and authoring UX only after the vertical slice works.

The plan should stop and redesign if it starts requiring FTE to understand Godot resource serialization, scene inheritance, or GDScript. That is the architectural boundary this document exists to protect.
