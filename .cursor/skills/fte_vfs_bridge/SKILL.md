---
name: fte_vfs_bridge
description: Redirects FTEQW file I/O to Godot's FileAccess or DirAccess APIs. Bridges FS_Open, FS_Read, FS_ListFiles calls to Godot's file system while preserving Quake's search path priority. Use when overriding Sys_FileOpenRead, setting com_gamedir via GDExtension initialization, or bridging FTEQW file operations to Godot's virtual file system.
---

# FTE VFS Bridge

Redirects FTEQW file I/O operations to Godot's FileAccess and DirAccess APIs while preserving Quake's search path priority and allowing internal .pak/.pk3 loading.

## Core Objective

Bridge FTEQW's file system calls to Godot's virtual file system:
- Redirect `FS_Open`, `FS_Read`, `FS_ListFiles` to Godot FileAccess/DirAccess
- Preserve Quake's search path priority (id1 -> mod_folder)
- Allow FTE to load .pak/.pk3 files internally, but use Godot to locate files
- Override `Sys_FileOpenRead` to utilize Godot's path remapping
- Set `com_gamedir` correctly via GDExtension initialization

## Key Concepts

**Quake Search Path Priority:**
1. Base game directory (e.g., `id1/`)
2. Mod directory (e.g., `mod_folder/`)
3. User directory (e.g., `userdir/`)

**FTE File Functions:**
- `FS_Open` - Open file for reading
- `FS_Read` - Read data from file
- `FS_ListFiles` - List files in directory
- `Sys_FileOpenRead` - System-level file open (needs override)

**Godot File APIs:**
- `FileAccess::open()` - Open file
- `FileAccess::get_as_bytes()` - Read file contents
- `DirAccess::open()` - Open directory
- `DirAccess::list_dir_begin()` - List directory contents

## Critical Constraints

### 1. Preserve Quake's Search Path Priority

Search paths in order:
```
1. mod_folder/ (highest priority)
2. id1/ (base game)
3. userdir/ (user files, lowest priority)
```

**Implementation:**
```cpp
// Search order: mod_folder -> id1 -> userdir
const char* search_paths[] = {
    "mod_folder",
    "id1",
    "userdir"
};
```

### 2. Allow FTE to Load .pak/.pk3 Internally

FTE can parse .pak/.pk3 archives, but use Godot to locate the archive files:

```cpp
// Use Godot to find .pak/.pk3 files
String pak_path = find_file_in_godot_paths("pak0.pak");
if (pak_path.length() > 0) {
    // Pass path to FTE's internal .pak loader
    FS_LoadPakFile(pak_path.utf8().get_data());
}
```

### 3. Override Sys_FileOpenRead

Replace FTE's system file open with Godot-based implementation:

```cpp
// Override in bridge or wrapper
filehandle_t Sys_FileOpenRead_Godot(const char *path) {
    // Use Godot to locate file with search path priority
    String godot_path = resolve_quake_path(path);
    Ref<FileAccess> file = FileAccess::open(godot_path, FileAccess::READ);
    
    if (file.is_valid()) {
        // Return handle (wrap FileAccess in custom structure)
        return create_file_handle(file);
    }
    return NULL;
}
```

## Implementation Logic

### Step 1: Set com_gamedir via GDExtension Initialization

**In GDExtension initialization:**

```cpp
// In GDExtension _initialize() or similar
void initialize_quake_paths() {
    // Get Godot's project path or resource path
    String project_path = ProjectSettings::get_singleton()->globalize_path("res://");
    
    // Set com_gamedir to point to game data location
    String gamedir = project_path + "quake_data/";
    
    // Set FTE's com_gamedir variable
    Cvar_Set("com_gamedir", gamedir.utf8().get_data());
    
    // Also set search paths
    FS_AddGameDirectory(gamedir.utf8().get_data());
}
```

**Alternative: Use Godot's resource remapping:**

```cpp
void initialize_quake_paths() {
    // Use Godot's path remapping
    String base_path = "res://quake_data/";
    
    // Set com_gamedir
    Cvar_Set("com_gamedir", base_path.utf8().get_data());
    
    // Add search paths in priority order
    FS_AddGameDirectory((base_path + "mod_folder/").utf8().get_data());
    FS_AddGameDirectory((base_path + "id1/").utf8().get_data());
    FS_AddGameDirectory((base_path + "userdir/").utf8().get_data());
}
```

### Step 2: Override Sys_FileOpenRead

**Create wrapper function:**

```cpp
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>

using namespace godot;

// File handle wrapper
struct godot_file_handle_t {
    Ref<FileAccess> file;
    int64_t position;
};

// Resolve Quake path using search path priority
String resolve_quake_path(const char *quake_path) {
    // Search paths in priority order
    const char* search_dirs[] = {
        "mod_folder",
        "id1",
        "userdir"
    };
    
    String path_str = String(quake_path);
    
    // Try each search directory
    for (int i = 0; i < 3; i++) {
        String full_path = "res://quake_data/" + String(search_dirs[i]) + "/" + path_str;
        
        // Check if file exists using Godot
        if (FileAccess::file_exists(full_path)) {
            return full_path;
        }
        
        // Also check in .pak files (if FTE handles them)
        // This would be handled by FTE's internal .pak loader
    }
    
    // Fallback: try direct path
    String direct_path = "res://quake_data/" + path_str;
    if (FileAccess::file_exists(direct_path)) {
        return direct_path;
    }
    
    return String(); // Not found
}

// Override Sys_FileOpenRead
filehandle_t Sys_FileOpenRead_Godot(const char *path) {
    String godot_path = resolve_quake_path(path);
    
    if (godot_path.length() == 0) {
        return NULL; // File not found
    }
    
    Ref<FileAccess> file = FileAccess::open(godot_path, FileAccess::READ);
    
    if (!file.is_valid()) {
        return NULL;
    }
    
    // Create handle wrapper
    godot_file_handle_t *handle = new godot_file_handle_t;
    handle->file = file;
    handle->position = 0;
    
    return (filehandle_t)handle;
}
```

### Step 3: Bridge FS_Open to Godot

**FS_Open wrapper:**

```cpp
filehandle_t FS_Open_Godot(const char *path, const char *mode) {
    // Only support read mode for now
    if (strcmp(mode, "rb") != 0 && strcmp(mode, "r") != 0) {
        return NULL;
    }
    
    // Use Sys_FileOpenRead_Godot
    return Sys_FileOpenRead_Godot(path);
}
```

### Step 4: Bridge FS_Read to Godot

**FS_Read wrapper:**

```cpp
int FS_Read_Godot(void *buffer, int size, filehandle_t handle) {
    if (!handle) {
        return 0;
    }
    
    godot_file_handle_t *g_handle = (godot_file_handle_t *)handle;
    
    if (!g_handle->file.is_valid()) {
        return 0;
    }
    
    // Read data
    PackedByteArray data = g_handle->file->get_buffer(size);
    int bytes_read = data.size();
    
    if (bytes_read > 0) {
        memcpy(buffer, data.ptr(), bytes_read);
        g_handle->position += bytes_read;
    }
    
    return bytes_read;
}
```

### Step 5: Bridge FS_ListFiles to Godot

**FS_ListFiles wrapper:**

```cpp
#include <godot_cpp/classes/dir_access.hpp>

char **FS_ListFiles_Godot(const char *path, const char *extension, int *numfiles) {
    String dir_path = resolve_quake_path(path);
    
    if (dir_path.length() == 0) {
        *numfiles = 0;
        return NULL;
    }
    
    Ref<DirAccess> dir = DirAccess::open(dir_path);
    
    if (!dir.is_valid()) {
        *numfiles = 0;
        return NULL;
    }
    
    // Collect matching files
    List<String> files;
    dir->list_dir_begin();
    
    String file_name = dir->get_next();
    while (file_name.length() > 0) {
        if (dir->current_is_dir()) {
            file_name = dir->get_next();
            continue;
        }
        
        // Check extension if specified
        if (extension && extension[0] != '\0') {
            if (!file_name.ends_with(extension)) {
                file_name = dir->get_next();
                continue;
            }
        }
        
        files.push_back(file_name);
        file_name = dir->get_next();
    }
    
    dir->list_dir_end();
    
    // Allocate and populate result array
    *numfiles = files.size();
    if (*numfiles == 0) {
        return NULL;
    }
    
    char **result = (char **)malloc(sizeof(char *) * (*numfiles));
    int i = 0;
    for (const String &f : files) {
        result[i] = strdup(f.utf8().get_data());
        i++;
    }
    
    return result;
}
```

### Step 6: Handle .pak/.pk3 Files

**Locate archives with Godot, load with FTE:**

```cpp
void FS_LoadPakFiles_Godot() {
    // Search paths in priority order
    const char* search_dirs[] = {
        "mod_folder",
        "id1",
        "userdir"
    };
    
    for (int i = 0; i < 3; i++) {
        String dir_path = "res://quake_data/" + String(search_dirs[i]) + "/";
        Ref<DirAccess> dir = DirAccess::open(dir_path);
        
        if (!dir.is_valid()) {
            continue;
        }
        
        // Find .pak and .pk3 files
        dir->list_dir_begin();
        String file_name = dir->get_next();
        
        while (file_name.length() > 0) {
            if (dir->current_is_dir()) {
                file_name = dir->get_next();
                continue;
            }
            
            // Check for .pak or .pk3 extension
            if (file_name.ends_with(".pak") || file_name.ends_with(".pk3")) {
                String full_path = dir_path + file_name;
                
                // Get absolute path for FTE
                String abs_path = ProjectSettings::get_singleton()->globalize_path(full_path);
                
                // Let FTE load the .pak/.pk3 internally
                FS_LoadPakFile(abs_path.utf8().get_data());
            }
            
            file_name = dir->get_next();
        }
        
        dir->list_dir_end();
    }
}
```

## Implementation Workflow

### Step 1: Initialize Paths in GDExtension

```cpp
// In GDExtension initialization
void FTE_Initialize_Paths() {
    // Set com_gamedir
    String gamedir = "res://quake_data/";
    Cvar_Set("com_gamedir", gamedir.utf8().get_data());
    
    // Load .pak/.pk3 files (FTE handles internally)
    FS_LoadPakFiles_Godot();
}
```

### Step 2: Override File Functions

```cpp
// Override FTE's file functions
void FTE_Override_FileFunctions() {
    // Replace Sys_FileOpenRead
    // (implementation depends on FTE's function pointer system)
    
    // Or use function hooking/interception
    // Hook_Sys_FileOpenRead(Sys_FileOpenRead_Godot);
}
```

### Step 3: Bridge Functions

```cpp
// Bridge FTE calls to Godot
filehandle_t bridge_FS_Open(const char *path, const char *mode) {
    return FS_Open_Godot(path, mode);
}

int bridge_FS_Read(void *buffer, int size, filehandle_t handle) {
    return FS_Read_Godot(buffer, size, handle);
}

char **bridge_FS_ListFiles(const char *path, const char *ext, int *num) {
    return FS_ListFiles_Godot(path, ext, num);
}
```

## Implementation Checklist

When implementing VFS bridge:

- [ ] Set `com_gamedir` in GDExtension initialization
- [ ] Implement `resolve_quake_path()` with search path priority
- [ ] Override `Sys_FileOpenRead` to use Godot FileAccess
- [ ] Bridge `FS_Open` to Godot FileAccess::open()
- [ ] Bridge `FS_Read` to Godot FileAccess::get_buffer()
- [ ] Bridge `FS_ListFiles` to Godot DirAccess
- [ ] Implement search path priority: mod_folder -> id1 -> userdir
- [ ] Use Godot to locate .pak/.pk3 files
- [ ] Pass .pak/.pk3 paths to FTE's internal loader
- [ ] Handle file handle wrapping (FileAccess -> filehandle_t)
- [ ] Test file reading from different search paths
- [ ] Test .pak/.pk3 loading

## Common Patterns

### Pattern: Path Resolution with Priority

```cpp
String resolve_quake_path_with_priority(const char *quake_path) {
    // Priority order: mod_folder -> id1 -> userdir
    const char* search_dirs[] = { "mod_folder", "id1", "userdir" };
    
    for (int i = 0; i < 3; i++) {
        String test_path = "res://quake_data/" + String(search_dirs[i]) + "/" + String(quake_path);
        
        if (FileAccess::file_exists(test_path)) {
            return test_path;
        }
    }
    
    return String(); // Not found
}
```

### Pattern: File Handle Wrapper

```cpp
// Wrap Godot FileAccess in FTE-compatible handle
struct godot_file_handle_t {
    Ref<FileAccess> file;
    int64_t position;
    int64_t size;
};

filehandle_t create_godot_file_handle(Ref<FileAccess> file) {
    godot_file_handle_t *handle = new godot_file_handle_t;
    handle->file = file;
    handle->position = 0;
    handle->size = file->get_length();
    return (filehandle_t)handle;
}

void destroy_godot_file_handle(filehandle_t handle) {
    if (handle) {
        godot_file_handle_t *g_handle = (godot_file_handle_t *)handle;
        delete g_handle;
    }
}
```

### Pattern: Pak File Discovery

```cpp
void discover_pak_files(const char *base_dir, List<String> &pak_files) {
    Ref<DirAccess> dir = DirAccess::open(String(base_dir));
    
    if (!dir.is_valid()) {
        return;
    }
    
    dir->list_dir_begin();
    String file_name = dir->get_next();
    
    while (file_name.length() > 0) {
        if (!dir->current_is_dir()) {
            if (file_name.ends_with(".pak") || file_name.ends_with(".pk3")) {
                String full_path = String(base_dir) + "/" + file_name;
                pak_files.push_back(full_path);
            }
        }
        file_name = dir->get_next();
    }
    
    dir->list_dir_end();
}
```

## Integration with FTE

### Function Pointer Override

```cpp
// If FTE uses function pointers, override them
typedef filehandle_t (*Sys_FileOpenRead_t)(const char *path);

Sys_FileOpenRead_t original_Sys_FileOpenRead;

void FTE_Install_FileBridge() {
    // Save original
    original_Sys_FileOpenRead = FTE_Sys_FileOpenRead;
    
    // Replace with Godot version
    FTE_Sys_FileOpenRead = Sys_FileOpenRead_Godot;
}
```

### Bridge Interface Integration

```cpp
// In bridge_import_t structure
typedef struct bridge_import_s {
    // File system functions
    filehandle_t (*FileOpen)(const char *path, const char *mode);
    int (*FileRead)(void *buffer, int size, filehandle_t handle);
    void (*FileClose)(filehandle_t handle);
    char **(*ListFiles)(const char *path, const char *ext, int *num);
    // ... other functions
} bridge_import_t;

// Fill bridge with Godot implementations
void fill_bridge_import(bridge_import_t *import) {
    import->FileOpen = FS_Open_Godot;
    import->FileRead = FS_Read_Godot;
    import->FileClose = FS_Close_Godot;
    import->ListFiles = FS_ListFiles_Godot;
}
```

## Testing Considerations

After implementation, verify:
- Files are found in correct search path order
- mod_folder files override id1 files
- .pak/.pk3 files are located and loaded correctly
- File reading works through Godot FileAccess
- Directory listing works through Godot DirAccess
- `com_gamedir` is set correctly at initialization
- File handles are properly managed (no leaks)
- Path resolution handles relative and absolute paths
