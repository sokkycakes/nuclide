# Stiletto Updater — System Overview

**Location:** `Tools/qml-runtime-launcher/`
**Stack:** QML UI (Qt Quick) + native C apply (WinHTTP, BCrypt)
**Distribution:** Single `NuclideLauncher.exe` that either boots the QML UI or runs `--apply` mode.

---

## Architecture

```
NuclideLauncher.exe
├── Normal mode (no --apply flag):
│     → reads its own location
│     → launches runtime\qml.exe app\main.qml
│     → QML updater window appears
│     → user sees progress, presses Update
│
└── Apply mode (--apply flag OR apply.request file present):
      → same binary, different entry point
      → downloads manifest.json from server
      → Phase 1: downloads each file in manifest to game/<path>.partial
      → SHA256-verifies each
      → Phase 2: atomically renames all .partial → final path
      → writes game/version.txt
      → writes apply-status.json for QML to poll
      → exits

The QML UI polls apply-status.json every 250ms to show progress.
```

## File Layout (installed client)

```
NuclideLauncher.exe
runtime/
└── qml.exe          # Qt QML interpreter (bundled)
app/
├── main.qml         # updater logic (controller)
├── MainForm.ui.qml  # updater layout (Design Studio form)
├── config.json      # manifest URL + local version path
├── fonts/
├── images/
└── imports/
game/                # ← the actual game install (default manifest dest)
├── fteqw64.exe      # the engine binary
├── version.txt      # version string, e.g. "2026.0727.0452"
├── fteplug_cef_x64.dll       # CEF plugin (when changed)
├── fteplug_webcore_x64.dll   # WebCore plugin (when changed)
├── resources/icudt67l.dat    # WebCore ICU (required with WebCore)
├── base/progs.dat            # compiled game progs (when changed)
├── base/decls/               # entity defs (when changed)
└── base/data/web/            # web UI assets (when changed)
NuclideLauncher.exe.old       # previous launcher exe; deleted on next UI launch

apply.request        # trigger file: QML writes "1" to launch --apply
apply-status.json    # progress file: apply process writes, QML polls
```

The QML uses XMLHttpRequest to read/write local files (enabled via
`QML_XHR_ALLOW_FILE_READ` and `QML_XHR_ALLOW_FILE_WRITE` env vars).

## Version Comparison

### Rule

Version strings are **opaque tokens**. The updater does:

```javascript
if (localVersion === remoteVersion) → "up to date"
if (localVersion !== remoteVersion) → "update available"
if (localVersion is empty)          → "nightly" (first install)
```

### Where versions live

- **Client:** `game/version.txt` — plain text, one line, just the string.
- **Server:** `manifest.json` key `"version"` — same string.
- **Publish script:** both are generated from a single `-Version` argument.

### Convention

`publish-staging.ps1` generates date-based versions by default:

```
2026.0727.0452   # July 27, 4:52 AM
2026.0727.1615   # July 27, 4:16 PM
```

You can pass any string with `-Version`. There is no semver — the
comparison is a straight string equality check.

---

## Publishing a Build (Developer)

### Quick (sync + publish + upload)

```powershell
# From Tools/qml-runtime-launcher/
.\scripts\publish-staging-upload.ps1
```

By default this:

1. **Syncs** the nuclide repo into the sibling playtest drop folder
   (`../stiletto-proto` next to the nuclide root) using the allowlist in
   `sync-playtest-drop.ps1`.
2. **Scans** that drop plus launcher files (`NuclideLauncher.exe`,
   `app/main.qml`, `app/MainForm.ui.qml`, `app/config.json`) into
   `staging-drop/manifest.json`.
3. **Uploads** only files whose SHA256 changed since the previous manifest
   (if supplied) to copyparty.

The publish step **throws** if WebCore is present and ICU data is missing —
omitting it AVs in `ftewebcore.dll` on HUD `@font-face` a few seconds after
map load.

### First publish after the allowlist change (full baseline)

Omit `-PreviousManifest` so every allowlisted file is included (including
`base/progs.dat`):

```powershell
.\scripts\publish-staging-upload.ps1
```

### Later publishes (skip unchanged files)

```powershell
.\scripts\publish-staging-upload.ps1 -PreviousManifest .\staging-drop\manifest.json
```

The publish script diffs each tracked file against the previous manifest's
SHA256. Files whose hash **didn't change** are left out of the new manifest
and are not re-uploaded.

### Custom version / notes

```powershell
.\scripts\publish-staging-upload.ps1 `
    -Version 2026.07.27.2 `
    -Notes "Fix lunge hitbox"
```

You can also call `publish-staging.ps1` directly (generate only, no upload)
with the same parameters.

### What it produces

```
staging-drop/
├── manifest.json              # version + file list with sha256 + url
├── version.txt                # same version string the client stores locally
├── fteqw64.exe                # engine (from playtest drop)
├── fteplug_*.dll              # plugins (only if changed)
├── resources/icudt67l.dat     # WebCore ICU; required when WebCore is present
├── base/progs.dat             # compiled game progs (baseline publish)
├── base/decls/...             # entity defs (only if changed)
├── base/data/web/...          # web UI assets (only if changed)
└── launcher/                  # updater self-patch files (only if changed)
    ├── NuclideLauncher.exe
    └── app/...
```

Maps, sounds, models, and the Qt `runtime/` bundle are **not** published.
Testers keep those from the itch archive or host download on join.

### Playtest drop allowlist

`sync-playtest-drop.ps1` copies nuclide → sibling `stiletto-proto` (or
`-DropRoot`). The publish script scans the same paths into the manifest.

**Engine / plugins (repo root):**

| Source | Manifest path |
|--------|--------------|
| `fteqw64.exe` | `fteqw64.exe` |
| `fteplug_cef_x64.dll` | `fteplug_cef_x64.dll` |
| `fteplug_webcore_x64.dll` | `fteplug_webcore_x64.dll` |
| `ftewebcore.dll` | `ftewebcore.dll` |
| WebCore dependency DLLs (`brotlicommon.dll`, `cairo-2.dll`, …) | same leaf name at repo root |
| `resources/icudt67l.dat` (`Resources/` or `resources/` under nuclide) | `resources/icudt67l.dat` |

WebCore ICU is mandatory when `fteplug_webcore_x64.dll` or `ftewebcore.dll`
is present. Manifest path is always lowercase `resources/icudt67l.dat` because
`ftewebcore.dll` calls `u_setDataDirectory(<exe>\resources)`.

The sync step also writes `stiletto.exe` (alias of `fteqw64.exe`) into the
drop folder for local playtest layout; only `fteqw64.exe` is published.

**Compiled game / configs (`base/`):**

| Source | Manifest path |
|--------|--------------|
| `progs.dat`, `csprogs.dat`, `menu.dat`, `hud.dat` | `base/<name>` |
| `autoexec.cfg`, `quake.rc`, `liblist.gam`, `motd.txt`, `mapcycle.txt` | `base/<name>` |
| `default_*.cfg` | `base/default_*.cfg` |

**Recursive directories:**

| Source | Manifest path |
|--------|--------------|
| `base/decls/` | `base/decls/<relpath>` |
| `base/data/web/` | `base/data/web/<relpath>` |
| `base/progs/` | `base/progs/<relpath>` |

**Launcher self-patch (from `Tools/qml-runtime-launcher/`):**

| Source | Manifest path |
|--------|--------------|
| `NuclideLauncher.exe` | `launcher/NuclideLauncher.exe` |
| `app/main.qml` | `launcher/app/main.qml` |
| `app/MainForm.ui.qml` | `launcher/app/MainForm.ui.qml` |
| `app/config.json` | `launcher/app/config.json` |

**Excluded:** `identity.pfx`, `conhistory.txt`, `installed.lst`,
`lobby_snapshot.json`, `fte.cfg`, all `.qc` sources, and paths under
`logs/`, `autosave/`, `autosaves/`, or `mapsrc/`.

You can add repo-root extras with `-AdditionalFiles` (same exclusion rules).

### Install layout on the client

Manifest `path` values resolve relative to the updater install root:

| Manifest prefix | Installed to |
|-----------------|--------------|
| `launcher/...` | Next to `NuclideLauncher.exe` (install root), e.g. `launcher/app/main.qml` → `app/main.qml` |
| everything else | Under `game/`, e.g. `fteqw64.exe` → `game/fteqw64.exe` |

**Self-update:** when apply replaces the running `NuclideLauncher.exe`, it
renames the live exe to `NuclideLauncher.exe.old` then moves the downloaded
`.partial` into place. The old file cannot be deleted while the process is
running. On the **next normal UI launch** (not apply mode), the launcher
deletes `NuclideLauncher.exe.old` before starting QML.

There is no background watcher or auto-poll — testers open the updater and
click **Update** when they want a new build.

### Upload to copyparty

Edit `scripts/publish-staging-upload.ps1` once and set
`$CopypartyCredential` near the top of the script.

The wrapper generates `staging-drop/`, streams each changed file to
copyparty using authenticated HTTP PUT, and overwrites matching remote paths.
Payload files and `version.txt` upload first; `manifest.json` uploads last
so clients never receive a manifest for an incomplete build. The script
stops on the first failed upload and does not publish the new manifest when
a payload upload fails.

The credential is stored as a local literal; the upload script must not
print the credential. Do not commit or share the credential-bearing script.

### Manual upload to server

Upload the entire `staging-drop/` to copyparty:

```
https://yhost.heartheartheart.xyz/copyparty/stilettoplaytestbuilds/staging/
```

So these URLs resolve:

| File | URL |
|------|-----|
| manifest.json | `.../staging/manifest.json` |
| fteqw64.exe | `.../staging/fteqw64.exe` |
| fteplug_webcore_x64.dll | `.../staging/fteplug_webcore_x64.dll` |
| resources/icudt67l.dat | `.../staging/resources/icudt67l.dat` |
| base/data/web/hud/index.html | `.../staging/base/data/web/hud/index.html` |

### Client sees the update

`app/config.json` ships pointing at that manifest URL. Next time
the updater runs it fetches it, compares versions, and offers Update.

---

## Manifest Format (`manifest.json`)

```json
{
  "version": "2026.0727.0452",
  "notes": "Fix lunge hitbox",
  "files": [
    {
      "path": "fteqw64.exe",
      "url": "https://yhost.heartheartheart.xyz/copyparty/stilettoplaytestbuilds/staging/fteqw64.exe",
      "sha256": "a1b2c3d4e5f6...",
      "size": 12345678
    },
    {
      "path": "fteplug_webcore_x64.dll",
      "url": "https://yhost.heartheartheart.xyz/copyparty/stilettoplaytestbuilds/staging/fteplug_webcore_x64.dll",
      "sha256": "b2c3d4e5f6a7...",
      "size": 987654
    },
    {
      "path": "base/data/web/title-menu/index.html",
      "url": "https://yhost.heartheartheart.xyz/copyparty/stilettoplaytestbuilds/staging/base/data/web/title-menu/index.html",
      "sha256": "...",
      "size": 1234
    }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `version` | yes | Opaque version string compared against local |
| `notes` | no | Human-readable release notes |
| `files[].path` | yes | Forward-slash path; `launcher/...` installs beside the exe, all other paths under `game/`; `\` and `..` rejected |
| `files[].url` | yes | Full URL to download |
| `files[].sha256` | no | Hex SHA-256; if present, verified after download |
| `files[].size` | no | File size in bytes (informational) |

The `path` field supports forward-slash subdirectories (e.g.
`base/data/web/hud/index.html`) which are converted to backslashes
for the Windows filesystem.  The C code creates parent directories
automatically.

---

## Config Format (`app/config.json`)

```json
{
  "manifestURL": "https://yhost.heartheartheart.xyz/copyparty/stilettoplaytestbuilds/staging/manifest.json",
  "localVersionFile": "game/version.txt",
  "windowTitle": "stiletto updater"
}
```

| Field | Description |
|-------|-------------|
| `manifestURL` | URL to fetch the remote manifest |
| `localVersionFile` | Path relative to launcher for local version |
| `windowTitle` | Window title override |

---

## Update Flow (step by step)

1. **Launcher starts** → sees no `--apply` flag → spawns `qml.exe app\main.qml`
2. **QML reads** `config.json` (local XMLHttpRequest to `app/config.json`)
3. **QML reads** local version from `game/version.txt`
4. **QML fetches** remote `manifest.json` from `manifestURL`
5. **Compares** `localVersion === remoteVersion`?
   - Yes → "Build is up to date", button shows "Check"
   - No → "New build available: X", button shows "Update"
6. **User clicks Update** →
   a. QML writes `"1"` to `apply.request`
   b. QML launches same `NuclideLauncher.exe` again via `Qt.openUrlExternally`
7. **Second launcher instance** → sees `apply.request` file → enters `--apply` mode
8. **Apply downloads** manifest.json from server to temp file
9. **Phase 1 — Download + verify:**
   a. For each entry in `files[]`:
      - Resolves dest: `launcher/...` → install root, else `game/<path>`
      - Creates parent directories
      - Downloads to `<dest>.partial`
      - SHA256-verifies (if manifest includes sha256)
      - On failure: writes error status, exits (leaves .partial for debugging)
10. **Phase 2 — Atomic rename:**
    a. For each entry in `files[]`:
       - Replaces `<dest>` from `<dest>.partial` (self-exe → rename live exe to `.old` first)
       - On failure: writes error status, exits
11. **Apply writes** new version to `game/version.txt`
12. **Apply writes** `apply-status.json` with `phase: "done"` and exits
13. **First launcher's QML** polls `apply-status.json` → sees `"done"` → updates UI

If anything fails, status is written with `phase: "error"` and a
human-readable message.

---

## Configuring for a Different Server

Change `manifestURL` in `app/config.json`. The manifest must be at
that exact URL and must serve JSON with the format above.

---

## Security Notes

- **SHA256**: verified after download if the manifest includes a
  sha256 field. The publish script always generates it.
- **Path traversal**: the C code rejects any file path containing
  `..`, `\`, or leading `/` before writing. Forward slashes `/`
  are converted to backslashes for valid subdirectory paths.
- **Atomic replace**: each file is downloaded to `<path>.partial`
  then `MoveFileExW` renames atomically. Version.txt is written
  last so a partial update is never mistaken for complete.
- **HTTPS**: WinHTTP handles HTTPS URLs; the server should serve
  over TLS.
- **No elevation**: the updater runs at the same privilege level as
  the launcher. Files in `game/` must be writable by the user.

---

## Building the Launcher

```powershell
# From Tools/qml-runtime-launcher/

# Using MSVC (from VS Developer Command Prompt)
cl /nologo /O2 /utf-8 /DUNICODE /D_UNICODE /DWIN32_LEAN_AND_MEAN `
    src\launcher.c src\apply.c `
    /Fe:NuclideLauncher.exe `
    /link user32.lib winhttp.lib bcrypt.lib /SUBSYSTEM:WINDOWS

# Using CMake (requires Windows SDK)
cmake -B build
cmake --build build
# Output: build/NuclideLauncher.exe
```

Run `scripts/package-runtime.ps1` to bundle the Qt runtime next to it
into `dist/` for distribution.
