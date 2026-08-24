# Playtest Distribution Updater Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One publish command syncs nuclide into the local `stiletto-proto` drop, uploads changed loose files (engine, plugins, ICU, progs, decls, web, default cfgs, launcher exe/QML) to the existing copyparty staging folder, and the tester updater installs `game/` paths as today plus `launcher/` paths next to `NuclideLauncher.exe`, including a running-exe rename swap.

**Architecture:** Extract dest-path + file-replace helpers from `apply.c` so they can be unit-tested. Add `sync-playtest-drop.ps1` as the allowlist copier (nuclide → drop). Retarget `publish-staging.ps1` to sync, then scan the drop + launcher files into the existing hash/manifest/staging-drop flow. Upload wrapper only forwards new parameters. First real publish after this must omit `-PreviousManifest`.

**Tech Stack:** C11 / MSVC or MinGW (`NuclideLauncher` CMake), Windows PowerShell 5.1, existing WinHTTP apply path, copyparty HTTP PUT wrapper.

**Origin:** [docs/superpowers/specs/2026-08-18-playtest-distribution-updater-design.md](../specs/2026-08-18-playtest-distribution-updater-design.md)

## Global Constraints

- Keep copyparty staging URL `https://yhost.heartheartheart.xyz/copyparty/stilettoplaytestbuilds/staging`.
- Files stay loose (one remote path per relative path), not a zip.
- Never copy or upload `identity.pfx`, `conhistory.txt`, `installed.lst`, `lobby_snapshot.json`, `fte.cfg`, logs, autosaves, `mapsrc/`, `.qc` sources.
- Do not ship Qt `runtime/`, maps, models, sound, textures, or music.
- WebCore present + missing `resources/icudt67l.dat` is a hard throw before upload.
- Upload payload first, `manifest.json` last; fail-fast; never print the copyparty credential.
- Default install dest remains `<launcher>/game/<path>`. Paths starting with `launcher/` install to `<launcher>/<rest>`.
- Reject `..`, backslashes, and absolute paths in manifest paths.
- Testers click Update; no watcher, no 30s poll, no live game patch.
- Local drop engine alias: copy `fteqw64.exe` bytes onto `stiletto.exe` in the drop only (manifest still uses `fteqw64.exe`).
- PowerShell 5.1: no `&&`, no ternary, no `??`.

---

## File map

| File | Responsibility |
|------|----------------|
| `Tools/qml-runtime-launcher/src/apply_path.h` | Dest resolve + replace declarations |
| `Tools/qml-runtime-launcher/src/apply_path.c` | `launcher/` vs `game/` dest; self-exe rename-to-`.old` replace |
| `Tools/qml-runtime-launcher/src/apply_path_test.c` | Console asserts for dest + replace |
| `Tools/qml-runtime-launcher/src/apply.c` | Call helpers; keep download/hash/status |
| `Tools/qml-runtime-launcher/src/launcher.c` | Delete `NuclideLauncher.exe.old` on UI launch |
| `Tools/qml-runtime-launcher/CMakeLists.txt` | Add `apply_path.c` to launcher; add `apply_path_test` target |
| `Tools/qml-runtime-launcher/scripts/sync-playtest-drop.ps1` | Allowlist copy nuclide → drop |
| `Tools/qml-runtime-launcher/scripts/test-sync-playtest-drop.ps1` | Temp-dir sync tests |
| `Tools/qml-runtime-launcher/scripts/publish-staging.ps1` | Sync, then hash drop + launcher files into staging-drop |
| `Tools/qml-runtime-launcher/scripts/test-publish-staging-allowlist.ps1` | Temp-tree publish tests |
| `Tools/qml-runtime-launcher/scripts/publish-staging-upload.ps1` | Forward `DropRoot` / `SkipSync` |
| `Tools/qml-runtime-launcher/docs/updater.md` | Publish/sync/self-update docs |
| `Tools/qml-runtime-launcher/README.txt` | Tester-facing: Update now also pulls progs |

---

### Task 1: Dest path and replace helpers

**Files:**
- Create: `Tools/qml-runtime-launcher/src/apply_path.h`
- Create: `Tools/qml-runtime-launcher/src/apply_path.c`
- Create: `Tools/qml-runtime-launcher/src/apply_path_test.c`
- Modify: `Tools/qml-runtime-launcher/CMakeLists.txt`

**Interfaces:**
- Consumes: none
- Produces:
  - `int updater_validate_file_path(char *path, size_t path_cap);` — 1 if ok; converts `/` to `\`; 0 if `..`, `\`, absolute, or empty
  - `int updater_resolve_dest(const wchar_t *install_root, const wchar_t *game_dir, const wchar_t *file_path_w, wchar_t *dest, size_t dest_cap);` — `launcher\` prefix → `install_root\rest`, else `game_dir\path`
  - `int updater_replace_file(const wchar_t *partial, const wchar_t *dest, const wchar_t *self_exe);` — if dest equals self_exe (case-insensitive), rename dest to `dest.old` then move partial onto dest; else delete dest and move partial

- [ ] **Step 1: Write the failing test**

Create `apply_path_test.c`:

```c
#include <stdio.h>
#include <string.h>
#include <wchar.h>
#include <windows.h>
#include "apply_path.h"

static int fail(const char *msg)
{
    fprintf(stderr, "FAIL: %s\n", msg);
    return 1;
}

static int write_bytes(const wchar_t *path, const char *bytes)
{
    HANDLE f = CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL, NULL);
    DWORD written = 0;
    if (f == INVALID_HANDLE_VALUE)
        return 0;
    WriteFile(f, bytes, (DWORD)strlen(bytes), &written, NULL);
    CloseHandle(f);
    return 1;
}

static int read_bytes(const wchar_t *path, char *buf, size_t cap)
{
    HANDLE f = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL,
        OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL);
    DWORD n = 0;
    if (f == INVALID_HANDLE_VALUE)
        return 0;
    if (!ReadFile(f, buf, (DWORD)(cap - 1), &n, NULL)) {
        CloseHandle(f);
        return 0;
    }
    CloseHandle(f);
    buf[n] = '\0';
    return 1;
}

int main(void)
{
    char path[260];
    wchar_t dest[MAX_PATH];
    wchar_t tmp[MAX_PATH];
    wchar_t dest_file[MAX_PATH];
    wchar_t partial_file[MAX_PATH];
    wchar_t old_file[MAX_PATH];
    char buf[32];

    strcpy_s(path, sizeof(path), "base/progs.dat");
    if (!updater_validate_file_path(path, sizeof(path)))
        return fail("progs path should be valid");
    if (strcmp(path, "base\\progs.dat") != 0)
        return fail("slashes should become backslashes");

    strcpy_s(path, sizeof(path), "../secret");
    if (updater_validate_file_path(path, sizeof(path)))
        return fail(".. must be rejected");

    strcpy_s(path, sizeof(path), "launcher/NuclideLauncher.exe");
    if (!updater_validate_file_path(path, sizeof(path)))
        return fail("launcher path should be valid");
    if (!updater_resolve_dest(L"C:\\install", L"C:\\install\\game",
            L"launcher\\NuclideLauncher.exe", dest, MAX_PATH))
        return fail("launcher dest resolve");
    if (wcscmp(dest, L"C:\\install\\NuclideLauncher.exe") != 0)
        return fail("launcher dest should strip prefix onto install root");

    if (!updater_resolve_dest(L"C:\\install", L"C:\\install\\game",
            L"base\\progs.dat", dest, MAX_PATH))
        return fail("game dest resolve");
    if (wcscmp(dest, L"C:\\install\\game\\base\\progs.dat") != 0)
        return fail("game dest should stay under game\\");

    GetTempPathW(MAX_PATH, tmp);
    _snwprintf_s(dest_file, MAX_PATH, _TRUNCATE, L"%sapply_dest.bin", tmp);
    _snwprintf_s(partial_file, MAX_PATH, _TRUNCATE, L"%sapply_partial.bin", tmp);
    _snwprintf_s(old_file, MAX_PATH, _TRUNCATE, L"%s.old", dest_file);
    DeleteFileW(old_file);
    if (!write_bytes(dest_file, "old-exe") || !write_bytes(partial_file, "new-exe"))
        return fail("temp write");
    if (!updater_replace_file(partial_file, dest_file, dest_file))
        return fail("self replace");
    if (!read_bytes(dest_file, buf, sizeof(buf)) || strcmp(buf, "new-exe") != 0)
        return fail("dest should be new-exe");
    if (!read_bytes(old_file, buf, sizeof(buf)) || strcmp(buf, "old-exe") != 0)
        return fail(".old should be old-exe");
    DeleteFileW(dest_file);
    DeleteFileW(old_file);
    DeleteFileW(partial_file);

    printf("apply_path_test ok\n");
    return 0;
}
```

Create stub `apply_path.c` that always returns 0 so the test fails for the right reason, plus the header with the three declarations.

Add to `CMakeLists.txt`:

```cmake
add_executable(NuclideLauncher WIN32 src/launcher.c src/apply.c src/apply_path.c)
# existing compile defs / link libs stay on NuclideLauncher

add_executable(apply_path_test src/apply_path.c src/apply_path_test.c)
target_compile_definitions(apply_path_test PRIVATE UNICODE _UNICODE WIN32_LEAN_AND_MEAN)
target_link_libraries(apply_path_test PRIVATE user32)
```

- [ ] **Step 2: Run test to verify it fails**

From `Tools/qml-runtime-launcher/`:

```powershell
cmake -S . -B build-test -G "Ninja"
cmake --build build-test --target apply_path_test
.\build-test\apply_path_test.exe
```

Expected: FAIL (`progs path should be valid` or link error until stubs exist; after stubs, first assert fails).

If Ninja is missing, `-G "MinGW Makefiles"` or Visual Studio generator is fine. The test exe must run and fail an assertion, not fail to compile the test file.

- [ ] **Step 3: Write minimal implementation**

`apply_path.h`:

```c
#ifndef APPLY_PATH_H
#define APPLY_PATH_H

#include <stddef.h>
#include <wchar.h>

int updater_validate_file_path(char *path, size_t path_cap);
int updater_resolve_dest(const wchar_t *install_root, const wchar_t *game_dir,
    const wchar_t *file_path_w, wchar_t *dest, size_t dest_cap);
int updater_replace_file(const wchar_t *partial, const wchar_t *dest,
    const wchar_t *self_exe);

#endif
```

`apply_path.c`: move the current `validate_file_path` body into `updater_validate_file_path`. `updater_resolve_dest` uses `_wcsnicmp(file_path_w, L"launcher\\", 9) == 0` then `install_root\\rest` (reject empty rest). Else `game_dir\\file_path_w`. `updater_replace_file`: if `_wcsicmp(dest, self_exe) == 0`, `DeleteFileW(dest.old)`, `MoveFileExW(dest, dest.old, MOVEFILE_REPLACE_EXISTING)`, then `MoveFileExW(partial, dest, MOVEFILE_REPLACE_EXISTING)`. Else `DeleteFileW(dest)` then the same move. Return 1 only if the final move succeeds. If the self rename fails, do not delete dest; return 0.

- [ ] **Step 4: Run tests and make sure they pass**

```powershell
cmake --build build-test --target apply_path_test
.\build-test\apply_path_test.exe
```

Expected: `apply_path_test ok` and exit 0.

- [ ] **Step 5: Commit**

```powershell
git add Tools/qml-runtime-launcher/src/apply_path.h Tools/qml-runtime-launcher/src/apply_path.c Tools/qml-runtime-launcher/src/apply_path_test.c Tools/qml-runtime-launcher/CMakeLists.txt
git commit -m "feat(updater): resolve launcher/ dest paths and self-exe replace"
```

---

### Task 2: Wire apply and delete .old on UI launch

**Files:**
- Modify: `Tools/qml-runtime-launcher/src/apply.c`
- Modify: `Tools/qml-runtime-launcher/src/launcher.c`

**Interfaces:**
- Consumes: `updater_validate_file_path`, `updater_resolve_dest`, `updater_replace_file`
- Produces: apply writes `launcher/*` next to the exe; self-replace uses rename-to-`.old`; UI launch deletes `NuclideLauncher.exe.old`

- [ ] **Step 1: Write the failing characterization**

Keep `apply_path_test` from Task 1 green. Add one launcher-side check you can run after wiring: build `NuclideLauncher` and confirm it still links `apply_path.c`.

No new test file. The failing moment is compile/link if `validate_file_path` is removed from `apply.c` before switching call sites.

- [ ] **Step 2: Confirm current apply still compiles**

```powershell
cmake --build build-test --target NuclideLauncher
```

Expected: PASS on current tree before edits (or after Task 1 cmake change).

- [ ] **Step 3: Wire apply.c**

1. `#include "apply_path.h"`
2. Delete the local `validate_file_path` function.
3. Replace both `validate_file_path(file_path, ...)` calls with `updater_validate_file_path`.
4. In both dest-path blocks (download phase and rename phase), after converting to `file_path_w`, call:

```c
if (!updater_resolve_dest(root, game_dir, file_path_w, dest_path, MAX_PATH)) {
    status_write(status_path, "error", 0.0, "Invalid launcher path in manifest", NULL);
    free(manifest);
    return 7;
}
_snwprintf_s(partial_path, MAX_PATH, _TRUNCATE, L"%s.partial", dest_path);
```

Pass `exe_path` (from `GetModuleFileNameW`) into the rename phase instead of `DeleteFileW(dest_path)` + `MoveFileExW(partial, dest)`:

```c
if (GetFileAttributesW(partial_path) != INVALID_FILE_ATTRIBUTES) {
    if (!updater_replace_file(partial_path, dest_path, exe_path)) {
        char msg[200];
        _snprintf_s(msg, sizeof(msg), _TRUNCATE,
            "Couldn't replace %s (is the game running?)", file_path);
        status_write(status_path, "error", 0.0, msg, NULL);
        free(manifest);
        return 10;
    }
}
```

Keep SHA256 mismatch behavior: delete the `.partial`, error, do not replace.

- [ ] **Step 4: Delete .old on UI launch**

In `launcher.c`, after `wants_apply_mode` returns false and before `CreateProcessW`, delete the sibling `.old` of the current image:

```c
{
    wchar_t old_exe[MAX_PATH];
    _snwprintf_s(old_exe, MAX_PATH, _TRUNCATE, L"%s.old", executable_path);
    DeleteFileW(old_exe);
}
```

`DeleteFileW` failing (file absent) is fine.

- [ ] **Step 5: Rebuild tests and launcher**

```powershell
cmake --build build-test --target apply_path_test
.\build-test\apply_path_test.exe
cmake --build build-test --target NuclideLauncher
```

Expected: test ok; `NuclideLauncher.exe` links.

- [ ] **Step 6: Commit**

```powershell
git add Tools/qml-runtime-launcher/src/apply.c Tools/qml-runtime-launcher/src/launcher.c Tools/qml-runtime-launcher/CMakeLists.txt
git commit -m "feat(updater): install launcher/ files beside the exe"
```

---

### Task 3: Sync allowlist nuclide → stiletto-proto

**Files:**
- Create: `Tools/qml-runtime-launcher/scripts/sync-playtest-drop.ps1`
- Create: `Tools/qml-runtime-launcher/scripts/test-sync-playtest-drop.ps1`

**Interfaces:**
- Consumes: none
- Produces: `Copy-PlaytestAllowlist -RepoRoot <string> -DropRoot <string>` copies allowlisted files; throws if `fteqw64.exe` or `base/progs.dat` missing; throws if WebCore dll exists in repo or drop and ICU file is missing; copies engine bytes to `stiletto.exe` in the drop; never copies exclusion names

- [ ] **Step 1: Write the failing test**

`test-sync-playtest-drop.ps1`:

```powershell
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here "sync-playtest-drop.ps1")

$repo = Join-Path $env:TEMP ("sync-repo-" + [guid]::NewGuid().ToString("n"))
$drop = Join-Path $env:TEMP ("sync-drop-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Path (Join-Path $repo "base\progs") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $repo "base\decls") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $repo "base\data\web") | Out-Null
New-Item -ItemType Directory -Path (Join-Path $repo "Resources") | Out-Null
New-Item -ItemType Directory -Path $drop | Out-Null
Set-Content -Path (Join-Path $repo "fteqw64.exe") -Value "engine-bytes" -Encoding ascii
Set-Content -Path (Join-Path $repo "base\progs.dat") -Value "progs-bytes" -Encoding ascii
Set-Content -Path (Join-Path $repo "base\progs\duel.dat") -Value "duel-bytes" -Encoding ascii
Set-Content -Path (Join-Path $repo "base\decls\hero.def") -Value "def-bytes" -Encoding ascii
Set-Content -Path (Join-Path $repo "base\data\web\hud\index.html") -Value "hud" -Encoding ascii
Set-Content -Path (Join-Path $repo "base\autoexec.cfg") -Value "ae" -Encoding ascii
Set-Content -Path (Join-Path $repo "identity.pfx") -Value "secret" -Encoding ascii
Set-Content -Path (Join-Path $repo "base\fte.cfg") -Value "user" -Encoding ascii
Set-Content -Path (Join-Path $repo "fteplug_webcore_x64.dll") -Value "plug" -Encoding ascii
Set-Content -Path (Join-Path $repo "Resources\icudt67l.dat") -Value "icu" -Encoding ascii

Copy-PlaytestAllowlist -RepoRoot $repo -DropRoot $drop

function Assert-File($rel, $expect) {
    $p = Join-Path $drop $rel
    if (-not (Test-Path $p)) { throw "missing $rel" }
    $got = [IO.File]::ReadAllText($p)
    if ($got -ne $expect) { throw "$rel content mismatch" }
}

Assert-File "fteqw64.exe" "engine-bytes"
Assert-File "stiletto.exe" "engine-bytes"
Assert-File "base\progs.dat" "progs-bytes"
Assert-File "base\progs\duel.dat" "duel-bytes"
Assert-File "base\decls\hero.def" "def-bytes"
Assert-File "base\data\web\hud\index.html" "hud"
Assert-File "base\autoexec.cfg" "ae"
Assert-File "fteplug_webcore_x64.dll" "plug"
Assert-File "resources\icudt67l.dat" "icu"
if (Test-Path (Join-Path $drop "identity.pfx")) { throw "identity.pfx must not sync" }
if (Test-Path (Join-Path $drop "base\fte.cfg")) { throw "fte.cfg must not sync" }

$engineHash = (Get-FileHash (Join-Path $drop "fteqw64.exe") -Algorithm SHA256).Hash
$aliasHash = (Get-FileHash (Join-Path $drop "stiletto.exe") -Algorithm SHA256).Hash
if ($engineHash -ne $aliasHash) { throw "stiletto.exe must match fteqw64.exe" }

Remove-Item -Recurse -Force $repo, $drop
Write-Host "test-sync-playtest-drop ok"
```

- [ ] **Step 2: Run test to verify it fails**

```powershell
powershell -NoProfile -File Tools\qml-runtime-launcher\scripts\test-sync-playtest-drop.ps1
```

Expected: FAIL (cannot dot-source missing `Copy-PlaytestAllowlist`).

- [ ] **Step 3: Write minimal implementation**

`sync-playtest-drop.ps1` (dot-sourceable; also runnable). Exact allowlist:

Root files from repo (copy if present): `fteqw64.exe`, `fteplug_webcore_x64.dll`, `ftewebcore.dll`, `fteplug_cef_x64.dll`, and

`brotlicommon.dll`, `brotlidec.dll`, `bz2.dll`, `cairo-2.dll`, `d3dcompiler_47.dll`, `dxcompiler.dll`, `dxil.dll`, `fontconfig-1.dll`, `freetype.dll`, `libexpat.dll`, `libpng16.dll`, `pixman-1-0.dll`, `vk_swiftshader.dll`, `vorbisfile.dll`, `vulkan-1.dll`, `z.dll`

`base/` files: `progs.dat`, `csprogs.dat`, `menu.dat`, `hud.dat`, `autoexec.cfg`, `quake.rc`, `liblist.gam`, `motd.txt`, `mapcycle.txt`, plus every `base/default_*.cfg`.

Recursive dirs: `base/decls`, `base/data/web`, `base/progs` (files only; skip directories named autosave).

ICU: copy `Resources/icudt67l.dat` or `resources/icudt67l.dat` from repo to `drop/resources/icudt67l.dat`.

After copies: `Copy-Item` engine onto `Join-Path $DropRoot "stiletto.exe"`.

Throws:

```powershell
if (-not (Test-Path (Join-Path $RepoRoot "fteqw64.exe"))) { throw "missing fteqw64.exe" }
if (-not (Test-Path (Join-Path $RepoRoot "base\progs.dat"))) { throw "missing base/progs.dat" }
$webcore = (Test-Path (Join-Path $RepoRoot "fteplug_webcore_x64.dll")) -or
           (Test-Path (Join-Path $RepoRoot "ftewebcore.dll")) -or
           (Test-Path (Join-Path $DropRoot "fteplug_webcore_x64.dll")) -or
           (Test-Path (Join-Path $DropRoot "ftewebcore.dll"))
if ($webcore -and -not (Test-Path (Join-Path $DropRoot "resources\icudt67l.dat"))) {
    throw "WebCore is present but resources/icudt67l.dat was not found..."
}
```

Never copy a relative path whose leaf is `identity.pfx`, `conhistory.txt`, `installed.lst`, `lobby_snapshot.json`, or `fte.cfg`.

Use `Copy-Item -Force` and `New-Item -ItemType Directory -Force` for parents. Do not delete extra files already in the drop.

If the script is invoked directly (`$MyInvocation.InvocationName -ne '.'`), parse `-RepoRoot` / `-DropRoot` and call `Copy-PlaytestAllowlist`. Default `RepoRoot` = nuclide root (`Split-Path` four levels up from the script is wrong: script lives at `Tools/qml-runtime-launcher/scripts`, so repo root is `Join-Path $PSScriptRoot "..\..\.."` resolved). Default `DropRoot` = `Join-Path (Split-Path $repoRoot -Parent) "stiletto-proto"`.

- [ ] **Step 4: Run test to verify it passes**

```powershell
powershell -NoProfile -File Tools\qml-runtime-launcher\scripts\test-sync-playtest-drop.ps1
```

Expected: `test-sync-playtest-drop ok`

Add a second assertion in the same test file (or a second invocation) that missing `progs.dat` throws. Keep it in the same script after the happy path, using a fresh temp repo without `progs.dat`.

- [ ] **Step 5: Commit**

```powershell
git add Tools/qml-runtime-launcher/scripts/sync-playtest-drop.ps1 Tools/qml-runtime-launcher/scripts/test-sync-playtest-drop.ps1
git commit -m "feat(updater): sync playtest drop allowlist from nuclide"
```

---

### Task 4: Publish from the drop plus launcher files

**Files:**
- Modify: `Tools/qml-runtime-launcher/scripts/publish-staging.ps1`
- Modify: `Tools/qml-runtime-launcher/scripts/publish-staging-upload.ps1`
- Create: `Tools/qml-runtime-launcher/scripts/test-publish-staging-allowlist.ps1`

**Interfaces:**
- Consumes: `Copy-PlaytestAllowlist`
- Produces: `publish-staging.ps1` parameters `-DropRoot`, `-SkipSync`, `-LauncherRoot` (in addition to existing). Candidates come from the drop allowlist paths plus `launcher/NuclideLauncher.exe`, `launcher/app/main.qml`, `launcher/app/MainForm.ui.qml`, `launcher/app/config.json`. Manifest `path` uses forward slashes. Unchanged sha vs `-PreviousManifest` still skipped.

- [ ] **Step 1: Write the failing test**

`test-publish-staging-allowlist.ps1` builds a fake nuclide-shaped tree:

```
$root/
  fteqw64.exe
  fteplug_webcore_x64.dll
  Resources/icudt67l.dat
  base/progs.dat
  base/data/web/hud/index.html
  identity.pfx
  Tools/qml-runtime-launcher/scripts/publish-staging.ps1  (copy the real script)
  Tools/qml-runtime-launcher/scripts/sync-playtest-drop.ps1
  Tools/qml-runtime-launcher/NuclideLauncher.exe   (tiny file "launcher")
  Tools/qml-runtime-launcher/app/main.qml
  Tools/qml-runtime-launcher/app/MainForm.ui.qml
  Tools/qml-runtime-launcher/app/config.json
$drop/   (empty)
```

Easier: point `-RepoRoot` is not a param today. Don't duplicate the whole repo. Invoke the real `publish-staging.ps1` with:

```powershell
-DropRoot $drop
-SkipSync
-LauncherRoot $launcherFake
-EngineExe (Join-Path $drop "fteqw64.exe")
-OutputDirectory $out
-Version "test.1"
```

Pre-populate `$drop` as Task 3 would, plus `$launcherFake\NuclideLauncher.exe` and `app\*.qml` / `config.json`.

Assert `$out\manifest.json` files paths contain `fteqw64.exe`, `base/progs.dat`, `resources/icudt67l.dat`, `launcher/NuclideLauncher.exe`, `launcher/app/main.qml` and do **not** contain `identity.pfx`. Assert `$out\launcher\NuclideLauncher.exe` exists. Assert no `identity.pfx` under `$out`.

Until publish is retargeted, the test fails because `base/progs.dat` is absent from the manifest (today only engine + web from nuclide).

- [ ] **Step 2: Run test to verify it fails**

```powershell
powershell -NoProfile -File Tools\qml-runtime-launcher\scripts\test-publish-staging-allowlist.ps1
```

Expected: FAIL (`base/progs.dat` missing from manifest).

- [ ] **Step 3: Retarget publish-staging.ps1**

Add params:

```powershell
[string]$DropRoot,
[switch]$SkipSync,
[string]$LauncherRoot
```

Defaults:

```powershell
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
if ([string]::IsNullOrWhiteSpace($DropRoot)) {
    $DropRoot = Join-Path (Split-Path $repoRoot -Parent) "stiletto-proto"
}
if ([string]::IsNullOrWhiteSpace($LauncherRoot)) {
    $LauncherRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}
```

If `-not $SkipSync`, `& (Join-Path $PSScriptRoot "sync-playtest-drop.ps1") -RepoRoot $repoRoot -DropRoot $DropRoot`.

Replace the candidate builder (engine-from-nuclide + web-from-nuclide) with:

1. After sync, `$EngineExe` default = `Join-Path $DropRoot "fteqw64.exe"` (keep explicit `-EngineExe` override).
2. Scan `$DropRoot` for the same allowlist relative paths the sync script uses (root dlls/exe, `resources/icudt67l.dat`, listed `base/` files, recursive `decls`, `data/web`, `progs/*.dat`). Candidate `path` is the drop-relative path with `/` separators (`base/progs.dat`).
3. Launcher files (must exist or throw for exe + `app/main.qml`):

```powershell
$candidates += [PSCustomObject]@{
    source = Join-Path $LauncherRoot "NuclideLauncher.exe"
    path   = "launcher/NuclideLauncher.exe"
}
foreach ($rel in @("app/main.qml", "app/MainForm.ui.qml", "app/config.json")) {
    $candidates += [PSCustomObject]@{
        source = Join-Path $LauncherRoot ($rel -replace "/", "\")
        path   = "launcher/$rel"
    }
}
```

If `NuclideLauncher.exe` is missing under `$LauncherRoot`, also try `Join-Path $LauncherRoot "actual final dist\NuclideLauncher.exe"` for the exe only; QML still comes from `$LauncherRoot\app`.

Keep previous-manifest skip, ICU throw (WebCore in drop), staging-drop copy, `version.txt`, existing `return` when nothing changed.

Keep `-AdditionalFiles` appended after the allowlist.

In `publish-staging-upload.ps1`, add `$DropRoot` and `$SkipSync` to the forwarded name list (`Get-Variable`). Do not print `$CopypartyCredential`.

- [ ] **Step 4: Run test to verify it passes**

```powershell
powershell -NoProfile -File Tools\qml-runtime-launcher\scripts\test-publish-staging-allowlist.ps1
powershell -NoProfile -File Tools\qml-runtime-launcher\scripts\test-sync-playtest-drop.ps1
```

Expected: both print `ok`.

- [ ] **Step 5: Commit**

```powershell
git add Tools/qml-runtime-launcher/scripts/publish-staging.ps1 Tools/qml-runtime-launcher/scripts/publish-staging-upload.ps1 Tools/qml-runtime-launcher/scripts/test-publish-staging-allowlist.ps1
git commit -m "feat(updater): publish playtest drop and launcher files"
```

---

### Task 5: Docs

**Files:**
- Modify: `Tools/qml-runtime-launcher/docs/updater.md`
- Modify: `Tools/qml-runtime-launcher/README.txt`

**Interfaces:**
- Consumes: the publish command and path rules from Tasks 2–4
- Produces: docs a developer can follow without this plan

- [ ] **Step 1: Update updater.md**

Replace “What's tracked automatically” with the spec allowlist. Document:

```powershell
.\scripts\publish-staging-upload.ps1
```

Default: sync nuclide → sibling `stiletto-proto`, then upload changed files.

First publish after this change: **omit** `-PreviousManifest` so testers get a full baseline (`progs.dat` included).

Later publishes:

```powershell
.\scripts\publish-staging-upload.ps1 -PreviousManifest .\staging-drop\manifest.json
```

Document `launcher/` install root vs default `game/`. Document self-update: rename running `NuclideLauncher.exe` to `.old`, next UI launch deletes `.old`. Document that testers click Update; no watcher.

Keep ICU throw and credential-not-printed notes.

- [ ] **Step 2: Update README.txt**

Change the line that says the updater only fetches exe/dll/ICU so it also fetches compiled game progs, decls, web UI, and updater self-patches. Maps/sounds/models still come from the host on join.

- [ ] **Step 3: Commit**

```powershell
git add Tools/qml-runtime-launcher/docs/updater.md Tools/qml-runtime-launcher/README.txt
git commit -m "docs(updater): publish from playtest drop and self-update"
```

---

## Self-review

**Spec coverage**

| Spec item | Task |
|-----------|------|
| Sync nuclide → stiletto-proto allowlist | 3 |
| Engine alias `stiletto.exe` in drop only | 3 |
| ICU throw | 3, 4 |
| Exclusions including `identity.pfx` | 3, 4 tests |
| Scan drop + launcher files into manifest | 4 |
| Previous-manifest skip | 4 (existing flow) |
| Baseline publish without previous manifest | 5 docs |
| `launcher/` dest vs `game/` | 1, 2 |
| Self-exe rename to `.old` | 1, 2 |
| Delete `.old` on next UI launch | 2 |
| Upload wrapper still last-manifest | 4 (unchanged upload body) |
| No watcher / poll / runtime/ / maps | 5 + allowlist |
| Same staging URL | 4 defaults |

**Placeholders:** none.

**Type consistency:** `Copy-PlaytestAllowlist -RepoRoot -DropRoot`; publish `-DropRoot -SkipSync -LauncherRoot`; C `updater_validate_file_path` / `updater_resolve_dest` / `updater_replace_file`.
