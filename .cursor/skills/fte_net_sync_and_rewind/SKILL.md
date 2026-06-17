---
name: fte_net_sync_and_rewind
description: Manages timing, state history, and authority of entities across the network. Handles lag compensation, client prediction, and server correction using circular buffers and rewind procedures. Use when processing NET_GetPacket or SV_SendClientDatagram, implementing lag compensation, rewinding entity states for hit detection, or synchronizing deterministic ticks with Godot's physics tick.
---

# FTE Net Sync and Rewind

Manages network synchronization, lag compensation, and state rewinding for FTEQW entities with deterministic ticking aligned to Godot's physics.

## Core Objective

Synchronize entity state across network with lag compensation:
- Archive entity states in circular buffers for rewind
- Rewind entities to timestamped positions for hit detection
- Handle client prediction and server correction
- Align network snapshots with Godot's physics tick
- Use FTE's bit-packing for efficient bandwidth usage

## Key Concepts

**Network Structures:**
- `usercmd_t` - User input command packet
- `sizebuf_t` - Network message buffer
- `edict_t` - Entity state structure

**Triggers:**
- `NET_GetPacket` - Ingress (receiving packets)
- `SV_SendClientDatagram` - Egress (sending packets)

**State History:**
- Circular buffer of entity states (origin, mins, maxs)
- Timestamped snapshots for lag compensation
- Memory-efficient storage without leaks

## Critical Constraints

### 1. Deterministic Ticking: Align with Godot Physics Tick

**Network snapshot must align with Godot's physics tick:**

```cpp
// Sync FTE tick with Godot physics tick
void sync_network_tick(double godot_physics_delta) {
    // Ensure FTE tick matches Godot physics tick exactly
    double fte_delta = godot_physics_delta;
    
    // Call FTE step with synchronized delta
    FTE_Library_Step(fte_delta, get_current_time());
    
    // Network snapshot happens at same rate as physics
    if (should_send_snapshot()) {
        SV_SendClientDatagram();
    }
}
```

**Godot integration:**

```gdscript
# In Godot _physics_process
func _physics_process(delta: float):
    # FTE tick aligned with physics tick
    sync_network_tick(delta)
    
    # Process network packets
    process_network_packets()
```

### 2. Memory Efficiency: Circular Buffer for State History

**Maintain circular buffer without memory leaks:**

```cpp
// Entity state snapshot
struct entity_state_snapshot_t {
    double timestamp;
    vec3_t origin;
    vec3_t mins;
    vec3_t maxs;
    vec3_t angles;
};

// Circular buffer for entity history
class EntityStateBuffer {
private:
    static const int BUFFER_SIZE = 128;  // 128 ticks of history (~2 seconds at 60fps)
    entity_state_snapshot_t buffer[BUFFER_SIZE];
    int write_index;
    int count;  // Number of valid entries
    
public:
    EntityStateBuffer() : write_index(0), count(0) {
        memset(buffer, 0, sizeof(buffer));
    }
    
    void archive_state(double timestamp, const vec3_t origin, 
                      const vec3_t mins, const vec3_t maxs) {
        int index = write_index % BUFFER_SIZE;
        
        buffer[index].timestamp = timestamp;
        VectorCopy(origin, buffer[index].origin);
        VectorCopy(mins, buffer[index].mins);
        VectorCopy(maxs, buffer[index].maxs);
        
        write_index++;
        if (count < BUFFER_SIZE) {
            count++;
        }
    }
    
    bool get_state_at_time(double target_time, entity_state_snapshot_t *out) {
        // Find closest state at or before target_time
        for (int i = 0; i < count; i++) {
            int index = (write_index - count + i + BUFFER_SIZE) % BUFFER_SIZE;
            
            if (buffer[index].timestamp <= target_time) {
                *out = buffer[index];
                return true;
            }
        }
        return false;
    }
};

// Per-entity state buffers
std::unordered_map<int, EntityStateBuffer*> entity_state_buffers;
```

**Memory management:**

```cpp
// Cleanup old buffers
void cleanup_entity_buffers() {
    // Remove buffers for entities that no longer exist
    for (auto it = entity_state_buffers.begin(); it != entity_state_buffers.end();) {
        int entnum = it->first;
        if (ge->edicts[entnum].free) {
            delete it->second;
            it = entity_state_buffers.erase(it);
        } else {
            ++it;
        }
    }
}
```

### 3. Bandwidth Integrity: Use FTE's Bit-Packing

**Prefer FTE's delta-bits over Godot-native transforms:**

```cpp
// Use FTE's efficient delta compression
void send_entity_update(sizebuf_t *msg, edict_t *ent, entity_state_t *baseline) {
    // FTE's delta compression is more efficient than sending full transforms
    MSG_WriteDeltaEntity(msg, ent, baseline, true, protocol_version);
    
    // Don't send redundant Godot transforms if FTE delta is sufficient
    // Only send if FTE delta doesn't cover the change
}
```

**Avoid redundant data:**

```cpp
// Check if FTE delta covers the change before sending Godot transform
bool needs_godot_transform_update(edict_t *ent, entity_state_t *baseline) {
    // If FTE delta compression covers origin/angles, don't send Godot transform
    if (ent->s.origin[0] == baseline->origin[0] &&
        ent->s.origin[1] == baseline->origin[1] &&
        ent->s.origin[2] == baseline->origin[2]) {
        return false;  // No change, FTE delta handles it
    }
    return true;  // Only send if significant change
}
```

## Implementation Logic

### Step 1: State Archiving - Archive Every Tick

**Archive entity states into timed buffer:**

```cpp
void archive_entity_states(double current_time) {
    // Archive all lag-compensated entities
    for (int entnum = 0; entnum < ge->max_edicts; entnum++) {
        edict_t *ent = &ge->edicts[entnum];
        
        if (ent->free) {
            continue;
        }
        
        // Only archive entities that need lag compensation
        if (!(ent->svflags & SVF_LAGCOMPENSATE)) {
            continue;
        }
        
        // Get or create state buffer
        if (entity_state_buffers.find(entnum) == entity_state_buffers.end()) {
            entity_state_buffers[entnum] = new EntityStateBuffer();
        }
        
        EntityStateBuffer *buffer = entity_state_buffers[entnum];
        
        // Archive current state
        buffer->archive_state(current_time, ent->s.origin, 
                              ent->mins, ent->maxs);
    }
}

// Call every tick
void FTE_Network_Tick(double delta, double current_time) {
    // Step FTE
    FTE_Library_Step(delta, current_time);
    
    // Archive states after step
    archive_entity_states(current_time);
    
    // Process network packets
    process_network_packets();
}
```

### Step 2: Rewind Procedure - Move Edicts Back for Hit Detection

**Rewind entities to timestamped position:**

```cpp
// Store original positions for restoration
struct rewind_context_t {
    std::unordered_map<int, vec3_t> original_origins;
    std::unordered_map<int, vec3_t> original_mins;
    std::unordered_map<int, vec3_t> original_maxs;
    double rewind_time;
};

rewind_context_t* rewind_entities_to_time(double target_time) {
    rewind_context_t *ctx = new rewind_context_t();
    ctx->rewind_time = target_time;
    
    // Save current positions
    for (auto &pair : entity_state_buffers) {
        int entnum = pair.first;
        edict_t *ent = &ge->edicts[entnum];
        
        if (ent->free) {
            continue;
        }
        
        // Save original state
        VectorCopy(ent->s.origin, ctx->original_origins[entnum]);
        VectorCopy(ent->mins, ctx->original_mins[entnum]);
        VectorCopy(ent->maxs, ctx->original_maxs[entnum]);
        
        // Get state at target time
        entity_state_snapshot_t snapshot;
        if (pair.second->get_state_at_time(target_time, &snapshot)) {
            // Restore to rewind position
            VectorCopy(snapshot.origin, ent->s.origin);
            VectorCopy(snapshot.mins, ent->mins);
            VectorCopy(snapshot.maxs, ent->maxs);
            
            // Update Godot node position (if synced)
            update_godot_node_position(entnum, snapshot.origin);
        }
    }
    
    return ctx;
}

void restore_entities_from_rewind(rewind_context_t *ctx) {
    // Restore all entities to original positions
    for (auto &pair : ctx->original_origins) {
        int entnum = pair.first;
        edict_t *ent = &ge->edicts[entnum];
        
        if (ent->free) {
            continue;
        }
        
        // Restore original state
        VectorCopy(ctx->original_origins[entnum], ent->s.origin);
        VectorCopy(ctx->original_mins[entnum], ent->mins);
        VectorCopy(ctx->original_maxs[entnum], ent->maxs);
        
        // Update Godot node position
        update_godot_node_position(entnum, ent->s.origin);
    }
    
    delete ctx;
}

// Perform raycast with rewind
trace_t perform_rewind_raycast(vec3_t start, vec3_t end, double fire_time) {
    // Rewind entities to fire time
    rewind_context_t *ctx = rewind_entities_to_time(fire_time);
    
    // Perform raycast in rewound state
    trace_t trace = SV_Trace(start, vec3_origin, vec3_origin, end, NULL, MASK_SHOT);
    
    // Restore entities
    restore_entities_from_rewind(ctx);
    
    return trace;
}
```

**Handle "fire" command with timestamp:**

```cpp
void handle_fire_command(usercmd_t *cmd, double fire_timestamp) {
    // Extract fire command data
    vec3_t start, end;
    // ... extract from cmd ...
    
    // Perform rewind raycast
    trace_t trace = perform_rewind_raycast(start, end, fire_timestamp);
    
    // Process hit result
    if (trace.fraction < 1.0) {
        process_hit(trace.ent, trace.endpos);
    }
}
```

### Step 3: Correction Handling - Smooth Interpolation

**Calculate delta and smooth interpolation:**

```cpp
// Client prediction state
struct client_prediction_t {
    vec3_t predicted_origin;
    vec3_t server_origin;
    double correction_time;
    bool needs_correction;
};

std::unordered_map<int, client_prediction_t> client_predictions;

void handle_server_correction(int entnum, const vec3_t server_origin, double server_time) {
    edict_t *ent = &ge->edicts[entnum];
    
    if (client_predictions.find(entnum) == client_predictions.end()) {
        client_predictions[entnum] = client_prediction_t();
    }
    
    client_prediction_t *pred = &client_predictions[entnum];
    
    // Calculate delta
    float delta[3];
    VectorSubtract(server_origin, pred->predicted_origin, delta);
    float delta_distance = VectorLength(delta);
    
    // Threshold for correction (avoid micro-corrections)
    const float CORRECTION_THRESHOLD = 1.0f;
    
    if (delta_distance > CORRECTION_THRESHOLD) {
        pred->needs_correction = true;
        VectorCopy(server_origin, pred->server_origin);
        pred->correction_time = server_time;
        
        // Start smooth interpolation
        start_correction_interpolation(entnum, pred->predicted_origin, server_origin);
    }
}

// Smooth interpolation back to correct path
void update_correction_interpolation(int entnum, double current_time, double delta) {
    if (client_predictions.find(entnum) == client_predictions.end()) {
        return;
    }
    
    client_prediction_t *pred = &client_predictions[entnum];
    
    if (!pred->needs_correction) {
        return;
    }
    
    edict_t *ent = &ge->edicts[entnum];
    
    // Interpolation duration (e.g., 100ms)
    const double INTERPOLATION_DURATION = 0.1;
    double elapsed = current_time - pred->correction_time;
    double t = elapsed / INTERPOLATION_DURATION;
    
    if (t >= 1.0) {
        // Interpolation complete
        VectorCopy(pred->server_origin, ent->s.origin);
        pred->needs_correction = false;
    } else {
        // Smooth interpolation (ease-out)
        float ease_t = 1.0f - (1.0f - t) * (1.0f - t);  // Quadratic ease-out
        
        vec3_t interpolated;
        VectorLerp(pred->predicted_origin, pred->server_origin, ease_t, interpolated);
        VectorCopy(interpolated, ent->s.origin);
    }
    
    // Update Godot node with interpolated position
    update_godot_node_position(entnum, ent->s.origin);
}
```

## Implementation Workflow

### Step 1: Hook Network Packet Processing

**Ingress (NET_GetPacket):**

```cpp
void NET_GetPacket_Hook() {
    // Call original
    qboolean result = NET_GetPacket();
    
    if (result) {
        // Process packet with state archiving
        process_ingress_packet();
    }
    
    return result;
}

void process_ingress_packet() {
    // Extract timestamp from packet
    double packet_time = MSG_ReadFloat();
    
    // Process user commands
    usercmd_t cmd;
    while (read_usercmd(&cmd)) {
        // Handle fire commands with rewind
        if (cmd.buttons & IN_ATTACK) {
            handle_fire_command(&cmd, packet_time);
        }
        
        // Process other commands
        process_usercmd(&cmd);
    }
    
    // Handle server corrections
    while (has_server_corrections()) {
        int entnum = read_entnum();
        vec3_t server_origin;
        read_origin(server_origin);
        double server_time = read_timestamp();
        
        handle_server_correction(entnum, server_origin, server_time);
    }
}
```

**Egress (SV_SendClientDatagram):**

```cpp
void SV_SendClientDatagram_Hook() {
    // Archive states before sending
    double current_time = get_current_time();
    archive_entity_states(current_time);
    
    // Call original to send datagram
    SV_SendClientDatagram();
}
```

### Step 2: Integrate with Godot Physics Tick

```gdscript
# In Godot _physics_process
func _physics_process(delta: float):
    var current_time = Time.get_ticks_msec() / 1000.0
    
    # Sync network tick with physics tick
    FTE_Network_Tick(delta, current_time)
    
    # Update correction interpolations
    for entnum in client_predictions:
        update_correction_interpolation(entnum, current_time, delta)
```

## Implementation Checklist

When implementing net sync and rewind:

- [ ] Create circular buffer structure for entity state history
- [ ] Archive entity states every tick (origin, mins, maxs)
- [ ] Implement rewind procedure to restore entities to timestamped positions
- [ ] Hook `NET_GetPacket` for ingress packet processing
- [ ] Hook `SV_SendClientDatagram` for egress packet sending
- [ ] Align network snapshots with Godot physics tick
- [ ] Implement fire command handling with rewind
- [ ] Perform raycast in rewound state
- [ ] Restore entities after raycast
- [ ] Handle server corrections with delta calculation
- [ ] Implement smooth interpolation for corrections
- [ ] Use FTE's bit-packing for bandwidth efficiency
- [ ] Avoid redundant Godot transform updates
- [ ] Clean up entity state buffers for freed entities
- [ ] Test memory efficiency (no leaks during rewind)

## Common Patterns

### Pattern: Circular Buffer Implementation

```cpp
template<typename T, int SIZE>
class CircularBuffer {
    T buffer[SIZE];
    int write_index;
    int count;
    
public:
    CircularBuffer() : write_index(0), count(0) {}
    
    void push(const T &item) {
        buffer[write_index % SIZE] = item;
        write_index++;
        if (count < SIZE) count++;
    }
    
    bool get_at_index(int index, T *out) {
        if (index >= count) return false;
        int actual_index = (write_index - count + index + SIZE) % SIZE;
        *out = buffer[actual_index];
        return true;
    }
};
```

### Pattern: Timestamp-Based State Lookup

```cpp
bool find_state_at_time(EntityStateBuffer *buffer, double target_time, 
                        entity_state_snapshot_t *out) {
    // Binary search for closest state (if sorted)
    // Or linear search for simplicity
    double closest_time = -1.0;
    int closest_index = -1;
    
    for (int i = 0; i < buffer->count; i++) {
        entity_state_snapshot_t snapshot;
        if (buffer->get_at_index(i, &snapshot)) {
            if (snapshot.timestamp <= target_time) {
                if (closest_time < snapshot.timestamp) {
                    closest_time = snapshot.timestamp;
                    closest_index = i;
                }
            }
        }
    }
    
    if (closest_index >= 0) {
        return buffer->get_at_index(closest_index, out);
    }
    
    return false;
}
```

### Pattern: Smooth Correction Interpolation

```cpp
// Ease-out interpolation for smooth correction
float ease_out_quad(float t) {
    return 1.0f - (1.0f - t) * (1.0f - t);
}

void interpolate_correction(vec3_t start, vec3_t end, float t, vec3_t out) {
    float eased_t = ease_out_quad(t);
    VectorLerp(start, end, eased_t, out);
}
```

## Performance Considerations

- **Circular buffer size**: Balance memory vs history depth (128 ticks ≈ 2 seconds at 60fps)
- **Rewind frequency**: Only rewind when processing fire commands
- **Correction threshold**: Avoid micro-corrections that cause jitter
- **Interpolation duration**: 50-100ms for smooth but responsive correction
- **State archiving**: Only archive lag-compensated entities (SVF_LAGCOMPENSATE flag)

## Testing Considerations

After implementation, verify:
- Entity states are archived correctly every tick
- Rewind restores entities to correct timestamped positions
- Entities are restored after rewind
- Raycasts work correctly in rewound state
- Server corrections trigger interpolation
- Interpolation smoothly moves entities to correct position
- Memory doesn't leak during rewind operations
- Network snapshots align with Godot physics ticks
- Bandwidth usage is efficient (FTE bit-packing used)
