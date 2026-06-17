---
name: fte_edict_sync
description: Manages the lifecycle of Godot nodes based on Quake engine entities. Syncs edict state to Node3D transforms, handles entity spawning/removal, and manages visibility based on EF_NODRAW. Use after FTE_Library_Step to sync entity state, when iterating ge->edicts, or when managing entnum to ObjectID mappings.
---

# FTE Edict Sync

Manages the lifecycle of Godot nodes based on Quake engine entities, synchronizing entity state to Godot Node3D transforms and visibility.

## Core Objective

After each `FTE_Library_Step()` call, synchronize Quake entity state (`edict_t`) to corresponding Godot Node3D nodes:
- Spawn new nodes for entities that don't exist
- Update transforms for entities with changed origin/angles/model
- Handle visibility based on `EF_NODRAW` flag
- Track entity-to-node mappings efficiently

## Key Concepts

**edict_t**: Quake engine entity structure containing:
- `free`: Whether entity slot is free/unused
- `origin`: Position (vec3_t)
- `angles`: Rotation (vec3_t)
- `model`: Model index/name
- `effects`: Effect flags (including `EF_NODRAW`)

**entnum**: Entity number/index in `ge->edicts` array

**ObjectID**: Godot's unique identifier for a node instance

## Critical Constraints

### 1. Use Dictionary or std::unordered_map for Mappings

**GDScript (Dictionary):**
```gdscript
var entnum_to_node_id: Dictionary = {}  # entnum -> ObjectID
```

**C++ (std::unordered_map):**
```cpp
#include <unordered_map>
std::unordered_map<int, ObjectID> entnum_to_node_id;
```

**Purpose**: Fast lookup of existing nodes by entity number.

### 2. Only Sync "Dirty" Entities

Track which entities have changed to avoid unnecessary updates:

```gdscript
# Track last known state
var last_origin: Dictionary = {}  # entnum -> Vector3
var last_angles: Dictionary = {}  # entnum -> Vector3
var last_model: Dictionary = {}    # entnum -> String/int

func is_entity_dirty(entnum: int, edict: Dictionary) -> bool:
    var origin = quake_to_godot_vec3(edict.origin)
    var angles = quake_to_godot_vec3(edict.angles)
    var model = edict.model
    
    if entnum not in last_origin:
        return true  # New entity
    
    return (last_origin[entnum] != origin or
            last_angles[entnum] != angles or
            last_model[entnum] != model)
```

**Update tracking after sync:**
```gdscript
last_origin[entnum] = origin
last_angles[entnum] = angles
last_model[entnum] = model
```

### 3. Handle EF_NODRAW by Toggling Visible Property

```gdscript
const EF_NODRAW = 0x00000080  # Quake effect flag

func update_visibility(node: Node3D, edict: Dictionary):
    var has_nodraw = (edict.effects & EF_NODRAW) != 0
    node.visible = not has_nodraw
```

## Implementation Logic

### Step 1: Iterate ge->edicts

**GDScript pattern:**
```gdscript
func sync_edicts_to_nodes():
    var edicts = get_edicts()  # Get ge->edicts array
    var max_edicts = get_max_edicts()
    
    for entnum in range(max_edicts):
        var edict = edicts[entnum]
        if edict == null:
            continue
            
        process_edict(entnum, edict)
```

**C++ pattern:**
```cpp
void sync_edicts_to_nodes() {
    for (int entnum = 0; entnum < ge->max_edicts; entnum++) {
        edict_t *edict = &ge->edicts[entnum];
        if (edict == nullptr) {
            continue;
        }
        process_edict(entnum, edict);
    }
}
```

### Step 2: Check for New Entities

**If edict->free is false and no mapping exists: emit_signal("spawn_entity")**

```gdscript
func process_edict(entnum: int, edict: Dictionary):
    # Skip free entities
    if edict.free:
        # Clean up mapping if exists
        if entnum in entnum_to_node_id:
            remove_entity_node(entnum)
        return
    
    # Check if entity needs spawning
    if entnum not in entnum_to_node_id:
        emit_signal("spawn_entity", entnum, edict)
        return  # Spawn handler will create node and add mapping
    
    # Entity exists, check if dirty
    if is_entity_dirty(entnum, edict):
        update_entity_node(entnum, edict)
```

**Signal handler:**
```gdscript
func _on_spawn_entity(entnum: int, edict: Dictionary):
    # Create Node3D
    var node = Node3D.new()
    node.name = "Entity_%d" % entnum
    
    # Add to scene tree
    add_child(node)
    
    # Store mapping
    entnum_to_node_id[entnum] = node.get_instance_id()
    
    # Initial sync
    update_entity_node(entnum, edict)
```

### Step 3: Update Node3D.transform Using fte_math_distill

**Convert Quake coordinates to Godot transform:**

```gdscript
func update_entity_node(entnum: int, edict: Dictionary):
    var node_id = entnum_to_node_id[entnum]
    var node = instance_from_id(node_id) as Node3D
    if node == null:
        # Node was removed, clean up mapping
        entnum_to_node_id.erase(entnum)
        return
    
    # Convert origin (vec3_t -> Vector3)
    var origin = quake_to_godot_vec3(edict.origin)
    
    # Convert angles (vec3_t -> Basis)
    # Quake angles are pitch/yaw/roll in degrees
    var angles_rad = Vector3(
        deg_to_rad(edict.angles[0]),  # pitch
        deg_to_rad(edict.angles[1]),  # yaw
        deg_to_rad(edict.angles[2])   # roll
    )
    var basis = Basis.from_euler(angles_rad)
    
    # Apply coordinate system conversion (Z-up -> Y-up)
    # See fte_distill_math skill for details
    var converted_basis = Basis(
        basis.x,           # X stays X
        basis.z,           # Y becomes Z
        -basis.y          # Z becomes -Y
    )
    
    # Set transform
    node.transform = Transform3D(converted_basis, origin)
    
    # Update visibility
    update_visibility(node, edict)
    
    # Update tracking
    last_origin[entnum] = origin
    last_angles[entnum] = angles_rad
    last_model[entnum] = edict.model
```

**Using fte_distill_math conversion:**
```gdscript
# Reference fte_distill_math skill for coordinate conversion
func quake_to_godot_vec3(quake_vec: Array) -> Vector3:
    # Quake: Z-up, Godot: Y-up
    # Y=Z, X=X, Z=-Y
    return Vector3(quake_vec[0], quake_vec[2], -quake_vec[1])
```

## Implementation Workflow

### Step 1: Set Up Data Structures

```gdscript
extends Node

signal spawn_entity(entnum: int, edict: Dictionary)

var entnum_to_node_id: Dictionary = {}
var last_origin: Dictionary = {}
var last_angles: Dictionary = {}
var last_model: Dictionary = {}
```

### Step 2: Create Sync Function

```gdscript
func sync_edicts_to_nodes():
    var edicts = get_edicts()  # Bridge to ge->edicts
    var max_edicts = get_max_edicts()
    
    for entnum in range(max_edicts):
        var edict = edicts[entnum]
        if edict == null:
            continue
        
        process_edict(entnum, edict)
```

### Step 3: Connect to FTE_Library_Step

```gdscript
func _process(delta: float):
    # Call FTE step
    FTE_Library_Step(delta, Time.get_ticks_msec() / 1000.0)
    
    # Sync entities after FTE step
    sync_edicts_to_nodes()
```

### Step 4: Handle Entity Lifecycle

```gdscript
func process_edict(entnum: int, edict: Dictionary):
    # Free entities: remove node if exists
    if edict.free:
        if entnum in entnum_to_node_id:
            remove_entity_node(entnum)
        return
    
    # New entities: spawn signal
    if entnum not in entnum_to_node_id:
        emit_signal("spawn_entity", entnum, edict)
        return
    
    # Existing entities: update if dirty
    if is_entity_dirty(entnum, edict):
        update_entity_node(entnum, edict)
    else:
        # Still update visibility (may change without position change)
        var node_id = entnum_to_node_id[entnum]
        var node = instance_from_id(node_id) as Node3D
        if node:
            update_visibility(node, edict)
```

## Implementation Checklist

When implementing edict sync:

- [ ] Create `entnum_to_node_id` Dictionary/unordered_map for mappings
- [ ] Create tracking dictionaries for `last_origin`, `last_angles`, `last_model`
- [ ] Implement `is_entity_dirty()` to check for changes
- [ ] Iterate `ge->edicts` array
- [ ] Check `edict->free` to skip free entities
- [ ] Emit `spawn_entity` signal for new entities (free=false, no mapping)
- [ ] Implement `update_entity_node()` to sync transform
- [ ] Use `quake_to_godot_vec3()` for origin conversion
- [ ] Convert angles to Basis using coordinate system transformation
- [ ] Handle `EF_NODRAW` flag by setting `node.visible = false`
- [ ] Call `sync_edicts_to_nodes()` after each `FTE_Library_Step()`
- [ ] Clean up mappings when entities become free

## Common Patterns

### Pattern: Coordinate Conversion

**Quake to Godot transform:**
```gdscript
func quake_to_godot_transform(origin: Array, angles: Array) -> Transform3D:
    var pos = quake_to_godot_vec3(origin)
    
    # Convert angles to radians
    var pitch = deg_to_rad(angles[0])
    var yaw = deg_to_rad(angles[1])
    var roll = deg_to_rad(angles[2])
    
    # Create basis from Euler angles
    var basis = Basis.from_euler(Vector3(pitch, yaw, roll))
    
    # Apply coordinate system conversion (Z-up -> Y-up)
    var converted_basis = Basis(
        basis.x,      # X stays X
        basis.z,      # Y becomes Z
        -basis.y      # Z becomes -Y
    )
    
    return Transform3D(converted_basis, pos)
```

### Pattern: Dirty Checking

**Efficient dirty detection:**
```gdscript
func is_entity_dirty(entnum: int, edict: Dictionary) -> bool:
    if entnum not in last_origin:
        return true
    
    var origin = quake_to_godot_vec3(edict.origin)
    var angles = quake_to_godot_vec3(edict.angles)
    
    # Use approximate equality for floating point
    if not last_origin[entnum].is_equal_approx(origin):
        return true
    if not last_angles[entnum].is_equal_approx(angles):
        return true
    if last_model[entnum] != edict.model:
        return true
    
    return false
```

### Pattern: Cleanup on Entity Removal

```gdscript
func remove_entity_node(entnum: int):
    if entnum not in entnum_to_node_id:
        return
    
    var node_id = entnum_to_node_id[entnum]
    var node = instance_from_id(node_id) as Node3D
    if node:
        node.queue_free()
    
    # Clean up mappings
    entnum_to_node_id.erase(entnum)
    last_origin.erase(entnum)
    last_angles.erase(entnum)
    last_model.erase(entnum)
```

## Integration Points

### After FTE_Library_Step

```gdscript
func _process(delta: float):
    # 1. Step FTE engine
    var realtime = Time.get_ticks_msec() / 1000.0
    FTE_Library_Step(delta, realtime)
    
    # 2. Sync entities to nodes
    sync_edicts_to_nodes()
```

### Signal Connection

```gdscript
func _ready():
    # Connect spawn signal
    connect("spawn_entity", _on_spawn_entity)
```

## Performance Considerations

- **Dirty checking**: Only update nodes when origin/angles/model change
- **Batch updates**: Consider batching multiple entity updates if needed
- **Lazy cleanup**: Clean up mappings when entities become free, not proactively
- **Cache lookups**: Store node references if frequently accessed

## Testing Considerations

After implementation, verify:
- New entities spawn correctly when `edict->free` is false
- Transform updates only occur for dirty entities
- `EF_NODRAW` correctly hides/shows nodes
- Free entities have their nodes removed
- Mappings are cleaned up properly
- Coordinate conversion matches expected positions/orientations
