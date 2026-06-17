---
name: fte_lifecycle_control
description: Converts FTEQW from a standalone executable to a passive library by wrapping initialization and frame logic into library functions. Use when modifying sys_main.c, host.c, or common.c to extract Host_Init into FTE_Library_Init, extract Host_Frame into FTE_Library_Step, replace exit()/abort() calls, force realtime/frametime from Godot arguments, or stub out VID_/S_/IN_ prefix functions.
---

# FTE Lifecycle Control

Converts FTEQW from a standalone executable to a passive library controlled by external callers (e.g., Godot GDExtension).

## Core Objective

Transform FTEQW's initialization and main loop into library-accessible functions:
- `FTE_Library_Init(argc, argv)` - Wraps `Host_Init`
- `FTE_Library_Step(double delta)` - Extracts core of `Host_Frame`
- No `exit()` or `abort()` calls
- Frame timing controlled by caller arguments
- OS-dependent subsystems (Video, Sound, Input) stubbed out

## Key Files

Primary context files:
- `sys_main.c` - Main entry point, contains `main()` and initialization
- `host.c` - Contains `Host_Init()` and `Host_Frame()` logic
- `common.c` - Common utilities and shared code

## Critical Constraints

### 1. No exit() or abort() Calls

**Find all `exit()` and `abort()` calls** and replace with:
```c
// Instead of: exit(1); or abort();
GDExtension::print_error("FTE: [descriptive error message]", __FUNCTION__, __FILE__, __LINE__);
return; // Early return from function
```

**Common locations:**
- Initialization failures in `Host_Init`
- Fatal errors in `Host_Frame`
- Assertion failures
- Error paths in `sys_main.c`

### 2. Force realtime and frametime from Arguments

**Replace time calculations** with parameter-driven values:

```c
// Instead of calculating internally:
// realtime = Sys_Milliseconds() / 1000.0;
// host_frametime = ... (system time calculation)

// Accept from caller:
void FTE_Library_Step(double delta, double realtime) {
    host_frametime = delta;
    // Use realtime parameter if needed for game logic
    // ... rest of frame logic
}
```

**In Host_Frame extraction:**
- Remove `Sys_Milliseconds()` calls for timing
- Use `delta` parameter for `host_frametime`
- Use `realtime` parameter if game logic requires absolute time

### 3. Stub Out VID_, S_, and IN_ Functions

**Video functions (VID_ prefix):**
```c
void VID_Restart(void) {
    // Stub - Godot handles windowing
}

void VID_Init(void) {
    // Stub - Godot handles windowing
}

// Stub all other VID_* functions similarly
```

**Sound functions (S_ prefix):**
```c
void S_Startup(void) {
    // Stub - Godot handles audio
}

void S_Init(void) {
    // Stub - Godot handles audio
}

// Stub all other S_* functions similarly
```

**Input functions (IN_ prefix):**
```c
void IN_Init(void) {
    // Stub - Godot handles input
}

void IN_Frame(void) {
    // Stub - Godot handles input
}

// Stub all other IN_* functions similarly
```

## Implementation Logic

### Wrap Host_Init into FTE_Library_Init

**Before:**
```c
// In sys_main.c or host.c
int main(int argc, char **argv) {
    Host_Init(argc, argv);
    // ... main loop ...
}
```

**After:**
```c
// In host.c or new library interface file
int FTE_Library_Init(int argc, char **argv) {
    // Call Host_Init but catch any exit() calls
    Host_Init(argc, argv);
    
    // Return success/failure instead of exiting
    return 0; // 0 = success, non-zero = failure
}

// Expose in header:
// int FTE_Library_Init(int argc, char **argv);
```

**Key changes:**
- Remove `main()` function or make it call `FTE_Library_Init`
- Ensure `Host_Init` doesn't call `exit()` (replace with error returns)
- Return status code instead of terminating process

### Extract Host_Frame into FTE_Library_Step

**Before:**
```c
// In host.c
void Host_Frame(void) {
    realtime = Sys_Milliseconds() / 1000.0;
    host_frametime = realtime - oldrealtime;
    oldrealtime = realtime;
    
    // ... frame logic ...
    VID_Frame();  // Video updates
    S_Update();   // Sound updates
    IN_Frame();   // Input updates
    // ... game logic ...
}
```

**After:**
```c
// In host.c or new library interface file
void FTE_Library_Step(double delta, double realtime) {
    // Set timing from arguments
    host_frametime = delta;
    // Use realtime if needed for game logic
    
    // Extract core frame logic from Host_Frame:
    // - Network updates
    // - Physics simulation
    // - Entity updates
    // - Game state management
    
    // DO NOT include:
    // - VID_Frame() (stubbed)
    // - S_Update() (stubbed)
    // - IN_Frame() (stubbed)
    // - Sys_Milliseconds() calls
    // - exit() calls
}

// Expose in header:
// void FTE_Library_Step(double delta, double realtime);
```

**Key changes:**
- Remove time calculation logic
- Remove calls to stubbed VID_/S_/IN_ functions
- Keep only game logic and simulation
- Accept timing as parameters

## Implementation Workflow

### Step 1: Create Library Interface Header

Create `fte_library.h` or update existing header:

```c
#ifndef FTE_LIBRARY_H
#define FTE_LIBRARY_H

#ifdef __cplusplus
extern "C" {
#endif

// Initialize FTE library (replaces main() initialization)
// Returns: 0 on success, non-zero on failure
int FTE_Library_Init(int argc, char **argv);

// Step FTE one frame (replaces Host_Frame in main loop)
// delta: Frame time in seconds (from Godot's delta)
// realtime: Absolute time in seconds (from Godot's time)
void FTE_Library_Step(double delta, double realtime);

// Cleanup FTE library (optional, for shutdown)
void FTE_Library_Shutdown(void);

#ifdef __cplusplus
}
#endif

#endif // FTE_LIBRARY_H
```

### Step 2: Refactor sys_main.c

**Option A: Remove main() entirely**
```c
// sys_main.c - main() removed, initialization moved to FTE_Library_Init
```

**Option B: Convert main() to test harness**
```c
// sys_main.c - Keep main() only for standalone testing
#ifdef FTE_STANDALONE
int main(int argc, char **argv) {
    if (FTE_Library_Init(argc, argv) != 0) {
        return 1;
    }
    // ... test loop if needed ...
    return 0;
}
#endif
```

### Step 3: Refactor host.c

**Extract Host_Init wrapper:**
```c
int FTE_Library_Init(int argc, char **argv) {
    // Wrap Host_Init, ensuring no exit() calls
    Host_Init(argc, argv);
    return 0; // Or return error code if Host_Init fails
}
```

**Extract Host_Frame core:**
```c
void FTE_Library_Step(double delta, double realtime) {
    host_frametime = delta;
    
    // Core game logic from Host_Frame:
    // - SV_Frame() for server simulation
    // - CL_Frame() for client simulation
    // - Network packet processing
    // - Entity updates
    
    // Removed:
    // - VID_Frame()
    // - S_Update()
    // - IN_Frame()
    // - Time calculations
}
```

### Step 4: Stub OS-Dependent Functions

**Create stubs file or add to existing files:**

```c
// vid_common.c or new stubs file
void VID_Restart(void) { /* Stub */ }
void VID_Init(void) { /* Stub */ }
void VID_Frame(void) { /* Stub */ }
// ... all other VID_* functions

// snd_*.c or new stubs file
void S_Startup(void) { /* Stub */ }
void S_Init(void) { /* Stub */ }
void S_Update(void) { /* Stub */ }
// ... all other S_* functions

// in_*.c or new stubs file
void IN_Init(void) { /* Stub */ }
void IN_Frame(void) { /* Stub */ }
// ... all other IN_* functions
```

### Step 5: Replace exit() and abort() Calls

**Search and replace pattern:**
```c
// Find: exit(1);
// Replace with:
GDExtension::print_error("FTE: [context-specific error]", __FUNCTION__, __FILE__, __LINE__);
return; // Or return error code

// Find: abort();
// Replace with:
GDExtension::print_error("FTE: [context-specific error]", __FUNCTION__, __FILE__, __LINE__);
return; // Or return error code
```

## Implementation Checklist

When refactoring:

- [ ] Create `fte_library.h` with `FTE_Library_Init` and `FTE_Library_Step` declarations
- [ ] Wrap `Host_Init` into `FTE_Library_Init(int argc, char **argv)`
- [ ] Extract core of `Host_Frame` into `FTE_Library_Step(double delta, double realtime)`
- [ ] Replace all `exit()` calls with `GDExtension::print_error` + return
- [ ] Replace all `abort()` calls with `GDExtension::print_error` + return
- [ ] Remove time calculation logic (use `delta` and `realtime` parameters)
- [ ] Stub all `VID_*` functions (Video subsystem)
- [ ] Stub all `S_*` functions (Sound subsystem)
- [ ] Stub all `IN_*` functions (Input subsystem)
- [ ] Remove or convert `main()` function in `sys_main.c`
- [ ] Ensure `FTE_Library_Init` returns status code instead of exiting
- [ ] Ensure `FTE_Library_Step` accepts timing parameters instead of calculating

## Common Patterns

### Pattern: Converting Initialization

**Before:**
```c
int main(int argc, char **argv) {
    Host_Init(argc, argv);
    if (error) {
        exit(1);
    }
}
```

**After:**
```c
int FTE_Library_Init(int argc, char **argv) {
    Host_Init(argc, argv);
    if (error) {
        GDExtension::print_error("FTE: Initialization failed", __FUNCTION__, __FILE__, __LINE__);
        return 1; // Error code
    }
    return 0; // Success
}
```

### Pattern: Converting Frame Logic

**Before:**
```c
void Host_Frame(void) {
    realtime = Sys_Milliseconds() / 1000.0;
    host_frametime = realtime - oldrealtime;
    oldrealtime = realtime;
    
    VID_Frame();
    S_Update();
    IN_Frame();
    SV_Frame();
}
```

**After:**
```c
void FTE_Library_Step(double delta, double realtime) {
    host_frametime = delta;
    // oldrealtime tracking removed - use realtime parameter if needed
    
    // VID_Frame(); // Removed - stubbed
    // S_Update();  // Removed - stubbed
    // IN_Frame();  // Removed - stubbed
    SV_Frame(); // Keep game logic
}
```

### Pattern: Stubbing Functions

**Before:**
```c
void VID_Restart(void) {
    // Complex window creation code
    // OpenGL context setup
    // ...
}
```

**After:**
```c
void VID_Restart(void) {
    // Stub - Godot handles windowing
    // Optionally log: printf("FTE: VID_Restart called (stubbed)\n");
}
```

## Integration with Godot GDExtension

From GDExtension:

```cpp
// In GDExtension code
extern "C" {
    int FTE_Library_Init(int argc, char **argv);
    void FTE_Library_Step(double delta, double realtime);
}

void FTE::_ready() {
    char *argv[] = {"fte", nullptr};
    int result = FTE_Library_Init(1, argv);
    if (result != 0) {
        Utility::print_error("FTE initialization failed", __FUNCTION__, __FILE__, __LINE__);
    }
}

void FTE::_process(double delta) {
    double realtime = Time::get_singleton()->get_ticks_msec() / 1000.0;
    FTE_Library_Step(delta, realtime);
}
```

## Testing Considerations

After refactoring, verify:
- `FTE_Library_Init` can be called without creating windows/audio devices
- `FTE_Library_Step` can be called repeatedly with different delta values
- No `exit()` or `abort()` calls occur during normal operation
- Frame timing is controlled by caller arguments
- Stubbed functions don't cause crashes or undefined behavior
- Error conditions return error codes instead of terminating process
