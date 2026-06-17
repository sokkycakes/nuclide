---
name: fte_integrity_check
description: Audits code changes against architectural constraints to prevent technical debt. Checks for circular dependencies, namespace isolation, error propagation, memory safety, and passive library compliance. Use when reviewing code diffs, adding new files, or when the user asks for architectural validation.
---

# FTE Integrity Check

Audits code changes against architectural constraints to prevent technical debt and maintain the passive library architecture.

## Core Objective

Validate that code changes maintain architectural integrity:
- No circular dependencies between layers
- Proper namespace isolation
- Safe error handling
- Memory safety
- Passive library compliance (no control-taking)

## Audit Workflow

When reviewing code changes:

1. **Dependency Scan** - Check `#include` statements
2. **State Audit** - Search for static/global variables
3. **Pattern Match** - Verify passive library compliance
4. **Error Handling** - Verify error propagation
5. **Memory Safety** - Check pointer handling

## Constraint 1: No Circularity

**Rule:** C++ files can call C-FTE code, but C-FTE code should never include Godot headers directly.

### Dependency Scan

**Check all `#include` statements:**

```c
// ✅ ALLOWED: C-FTE including C-FTE headers
#include "common.h"
#include "host.h"
#include "sys.h"

// ✅ ALLOWED: C++ bridge including Godot headers
#include <godot_cpp/classes/...>
#include <godot_cpp/core/...>

// ❌ FORBIDDEN: C-FTE including Godot headers
#include <godot_cpp/classes/...>  // ERROR: Circular dependency
#include "godot_headers.h"        // ERROR: Circular dependency
```

**If C-FTE needs Godot functionality:**
- Use function pointers/callbacks passed from C++ layer
- Use opaque handles/void pointers
- Define callback interfaces in C headers

**Example - Correct pattern:**
```c
// In C-FTE header (fte_callback.h)
typedef void (*FTE_ErrorCallback)(const char *message);
void FTE_SetErrorCallback(FTE_ErrorCallback cb);

// In C-FTE code
static FTE_ErrorCallback error_cb = NULL;
void Sys_Error(const char *error) {
    if (error_cb) {
        error_cb(error);
    }
}
```

## Constraint 2: Namespace Isolation

**Rule:** All bridge code must be wrapped in a dedicated namespace (e.g., `FTE::`) to avoid naming collisions.

### Namespace Check

**Search for new functions/classes without namespace:**

```cpp
// ❌ FORBIDDEN: Global namespace pollution
void BridgeFunction() { }
class BridgeClass { };

// ✅ REQUIRED: Namespace isolation
namespace FTE {
    void BridgeFunction() { }
    class BridgeClass { };
}
```

**Exception:** C functions exposed via `extern "C"` can be in global namespace if prefixed:
```c
// ✅ ALLOWED: C linkage with prefix
extern "C" {
    int FTE_Library_Init(int argc, char **argv);
    void FTE_Library_Step(double delta, double realtime);
}
```

## Constraint 3: Error Propagation

**Rule:** FTE `Sys_Error` must not crash the whole Godot process; it must be caught and routed to Godot's console.

### Error Handling Audit

**Check for direct error calls:**

```c
// ❌ FORBIDDEN: Direct abort/exit
Sys_Error("Fatal error");
exit(1);
abort();

// ✅ REQUIRED: Routed through callback
Sys_Error("Fatal error");  // Should call registered callback
```

**Verify error routing:**

```cpp
// In C++ bridge layer
namespace FTE {
    void error_callback(const char *msg) {
        Utility::print_error(msg, __FUNCTION__, __FILE__, __LINE__);
        // Do NOT call abort() or exit()
    }
    
    void init() {
        FTE_SetErrorCallback(error_callback);
    }
}
```

**Check for unhandled exceptions:**
- C++ code calling FTE must catch C++ exceptions
- C code errors must route through callbacks, not abort()

## Constraint 4: Memory Safety

**Rule:** Pointers passed from FTE to Godot must be handled via `MemAlloc` or `MemFree` appropriately to avoid leaks.

### Memory Audit

**Check pointer transfers:**

```cpp
// ❌ FORBIDDEN: Raw malloc/free across boundaries
char *data = (char*)malloc(size);
// Pass to Godot...
free(data);  // ERROR: Who owns this?

// ✅ REQUIRED: Use Godot memory management
char *data = (char*)memalloc(size);
// Pass to Godot...
memfree(data);  // Or let Godot manage lifetime
```

**Verify ownership:**
- FTE-allocated memory passed to Godot: Use `memalloc`/`memfree` or transfer ownership
- Godot-allocated memory passed to FTE: Document lifetime expectations
- Temporary buffers: Clear ownership model

**Check for leaks:**
- Every `malloc`/`memalloc` should have matching `free`/`memfree`
- Exception paths must clean up
- Callback contexts must not leak

## Constraint 5: Passive Library Compliance

**Rule:** Code must not "take control" of the loop or initialization. FTE is a passive library.

### Pattern Match Check

**Forbidden patterns:**

```c
// ❌ FORBIDDEN: Taking control of main loop
void FTE_Init() {
    while (running) {  // ERROR: Library shouldn't own loop
        // ...
    }
}

// ❌ FORBIDDEN: Blocking operations
void FTE_Step() {
    sleep(1000);  // ERROR: Blocks caller's thread
    wait_for_event();  // ERROR: Blocks caller
}

// ❌ FORBIDDEN: Creating threads
void FTE_Init() {
    pthread_create(...);  // ERROR: Library shouldn't spawn threads
    std::thread(...);     // ERROR: Library shouldn't spawn threads
}
```

**Required patterns:**

```c
// ✅ REQUIRED: Passive, non-blocking
void FTE_Library_Step(double delta, double realtime) {
    // Process one frame, return immediately
    // No loops, no blocking, no thread creation
}

// ✅ REQUIRED: Caller controls timing
// Godot calls FTE_Library_Step(delta, realtime) each frame
```

**Check for control-taking:**
- No `while`/`for` loops that run indefinitely
- No blocking I/O operations
- No thread creation
- No event loops
- No `sleep`/`usleep` calls
- Functions should return promptly

## Constraint 6: The "Sentinel" Guard (Deterministic Geometry)

**Rule:** Geometry generation must be deterministic and independent of asset availability. **Missing assets must result in placeholders, never in the culling of spatial data.**

### What to Reject

Reject changes where:
- Geometry/surfaces/faces are skipped, dropped, or early-returned because a texture/material/mesh/asset load failed
- The number of generated vertices/indices/surfaces depends on whether an external asset exists on disk
- “Optimization” logic culls geometry when a material lookup fails (e.g., `if (!mat) continue;`)

### Required Pattern

Require changes where:
- Geometry is always built/committed first (or at least always committed regardless of material availability)
- Missing assets produce a loud placeholder (e.g., hot pink “Debug/Missing”, checkerboard), so spatial data remains visible and debuggable

## Implementation Logic

### Dependency Scan

**Steps:**
1. Extract all `#include` statements from changed files
2. Categorize includes:
   - C-FTE headers (`common.h`, `host.h`, `sys.h`, etc.)
   - Godot headers (`godot_cpp/...`)
   - Standard library (`stdio.h`, `stdlib.h`, etc.)
3. Check C-FTE files for Godot includes
4. Flag violations with file and line number

**Command to scan:**
```bash
# Find C-FTE files including Godot headers
grep -r "#include.*godot" libquake/ fteqw/
```

### State Audit

**Steps:**
1. Search for new `static` variables in changed files
2. Search for new global variables (file-scope)
3. Assess thread-safety:
   - Is variable protected by mutex?
   - Is it read-only after initialization?
   - Could concurrent calls cause issues?
4. Assess re-entrancy:
   - Can function be called recursively?
   - Does it rely on global state?

**Patterns to flag:**
```c
// ⚠️ FLAG: Unprotected global state
static int counter = 0;
void FTE_Step() {
    counter++;  // Not thread-safe if called concurrently
}

// ✅ BETTER: Thread-local or parameter-based
void FTE_Step(int *counter) {
    (*counter)++;
}
```

### Pattern Match

**Steps:**
1. Search for control-taking keywords: `while`, `for`, `pthread_create`, `std::thread`, `sleep`
2. Check function return patterns - do they return promptly?
3. Verify no blocking operations in step/init functions
4. Compare against "Passive Library" goal

**Rejection criteria:**
- Function contains infinite loop
- Function blocks waiting for external event
- Function creates threads
- Function calls `sleep`/`usleep`/`nanosleep`
- Function doesn't return within reasonable time

## Audit Checklist

When reviewing code changes:

- [ ] **Dependency Scan**
  - [ ] No C-FTE files include Godot headers
  - [ ] C++ bridge files properly include Godot headers
  - [ ] Callbacks used instead of direct includes where needed

- [ ] **Namespace Isolation**
  - [ ] All C++ bridge code in `FTE::` namespace
  - [ ] C functions prefixed with `FTE_` if global
  - [ ] No naming collisions with Godot classes

- [ ] **Error Propagation**
  - [ ] No `exit()` or `abort()` calls
  - [ ] `Sys_Error` routes through callback
  - [ ] C++ exceptions caught and handled
  - [ ] Errors logged to Godot console

- [ ] **Memory Safety**
  - [ ] Cross-boundary pointers use `memalloc`/`memfree`
  - [ ] No memory leaks in error paths
  - [ ] Ownership clearly documented
  - [ ] No double-free or use-after-free

- [ ] **Passive Library Compliance**
  - [ ] No infinite loops in library functions
  - [ ] No blocking operations
  - [ ] No thread creation
  - [ ] Functions return promptly
  - [ ] Caller controls timing and flow

- [ ] **Deterministic Geometry (Sentinel Guard)**
  - [ ] Geometry generation does not depend on assets existing on disk
  - [ ] Missing assets produce placeholders (Debug/Missing), not culled/omitted surfaces
  - [ ] No early-returns/continues that skip spatial data due to material/texture lookup failure

## Common Violations

### Violation: C-FTE Including Godot Headers

**Found:**
```c
// In libquake/common.c
#include <godot_cpp/classes/node.hpp>
```

**Fix:**
```c
// Remove direct include, use callback instead
// In libquake/common.h
typedef void (*FTE_NodeCallback)(void *node_data);
void FTE_SetNodeCallback(FTE_NodeCallback cb);
```

### Violation: Missing Namespace

**Found:**
```cpp
// In bridge_interface.cpp
void ProcessEntity(edict_t *ent) { }
```

**Fix:**
```cpp
// In bridge_interface.cpp
namespace FTE {
    void ProcessEntity(edict_t *ent) { }
}
```

### Violation: Direct Sys_Error Crash

**Found:**
```c
void Sys_Error(const char *error) {
    printf("Fatal: %s\n", error);
    abort();  // Crashes Godot process
}
```

**Fix:**
```c
static FTE_ErrorCallback error_cb = NULL;
void Sys_Error(const char *error) {
    if (error_cb) {
        error_cb(error);
    }
    // Return instead of aborting
}
```

### Violation: Control-Taking Loop

**Found:**
```c
void FTE_Library_Step(double delta, double realtime) {
    while (processing) {  // Takes control of execution
        // ...
    }
}
```

**Fix:**
```c
void FTE_Library_Step(double delta, double realtime) {
    // Process one frame's worth of work
    ProcessFrame(delta);
    // Return immediately
}
```

## Integration with Code Review

Run integrity check before:
- Merging pull requests
- Committing architectural changes
- Adding new bridge code
- Modifying FTE core files

Report violations as:
- 🔴 **Critical**: Blocks merge (circular deps, crashes, control-taking)
- 🟡 **Warning**: Should fix (namespace, memory safety)
- 🟢 **Info**: Best practice (documentation, style)
