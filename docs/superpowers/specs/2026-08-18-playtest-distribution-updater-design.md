# Playtest Distribution Updater Design

## Goal

Testers receive a playable `game/` folder (engine, plugins, ICU, compiled progs, decls, web UI, default cfgs) through the existing copyparty updater, not only engine + web assets. The local playtest drop stays the copy you run. One publish command syncs nuclide into that drop, then uploads changed loose files. The updater can replace its own exe and QML.

Join-download still covers maps/sounds/models testers do not already have. This updater covers files join does not reliably replace, plus the engine/plugin/ICU set needed to boot.

## Actors

- **You:** develop in nuclide, run the local drop, publish when you want testers to catch up.
- **Tester:** opens `NuclideLauncher.exe`, clicks Update, then launches the game under `game/`.

## Pipeline

```
nuclide (dev + rebuilds)
    → allowlist copy → stiletto-proto (local playable drop)
    → hash vs previous manifest
    → PUT changed loose files to copyparty staging
    → PUT manifest.json last
tester updater
    → GET manifest.json
    → download changed files (sha256)
    → game/<path> or launcher-root for launcher/* paths
```

Testers are not on a watcher or 30s poll. You run the publish command; they open the updater (or click Check) and Update.

## Source of truth

- **Develop/build:** nuclide repo root.
- **Local play:** `stiletto-proto` (sibling of nuclide). Sync never deletes extra files already in the drop unless they are known junk (`conhistory.txt` at drop root is not copied; `identity.pfx` is never copied).
- **Remote playtesters:** copyparty staging volume already configured in `app/config.json` (`.../stilettoplaytestbuilds/staging/manifest.json`). Keep that URL. Files remain loose (one remote path per local relative path), not a zip.

The engine binary testers already receive is `game/fteqw64.exe`. Keep that name in the manifest. When syncing the local drop, also copy those same bytes onto `stiletto.exe` so the existing local shortcut still launches.

## Allowlist (nuclide → drop → upload)

**Drop root (and `game/` on the tester):**

- `fteqw64.exe` (from nuclide `fteqw64.exe`; also copied to `stiletto.exe` in the local drop only)
- `fteplug_webcore_x64.dll`, `ftewebcore.dll`, `fteplug_cef_x64.dll` when present
- WebCore/cairo runtime DLLs already beside the drop exe: `brotlicommon.dll`, `brotlidec.dll`, `bz2.dll`, `cairo-2.dll`, `d3dcompiler_47.dll`, `dxcompiler.dll`, `dxil.dll`, `fontconfig-1.dll`, `freetype.dll`, `libexpat.dll`, `libpng16.dll`, `pixman-1-0.dll`, `vk_swiftshader.dll`, `vorbisfile.dll`, `vulkan-1.dll`, `z.dll`
- `resources/icudt67l.dat` (required when WebCore is present; publish still throws if WebCore is present and ICU is missing)

**`base/`:**

- `progs.dat`, `csprogs.dat`, `menu.dat`, `hud.dat`
- `progs/*.dat` (rule modules, including `duel.dat`)
- `decls/`
- `data/web/`
- `default_*.cfg`, `autoexec.cfg`, `quake.rc`, `liblist.gam`, `motd.txt`, `mapcycle.txt`

**Launcher self-update (tester install root, not under `game/`):**

- `launcher/NuclideLauncher.exe`
- `launcher/app/main.qml`
- `launcher/app/MainForm.ui.qml`
- `launcher/app/config.json`

Do **not** ship the Qt `runtime/` tree unless a later change proves those files must move. They are large and almost never change.

## Exclusions

Never copy or upload:

- `identity.pfx`
- `conhistory.txt`, `installed.lst`, `lobby_snapshot.json`, `fte.cfg`
- logs, autosaves, `mapsrc/`, editor junk
- `.qc` sources (testers run compiled dats)
- maps, models, sound, textures, music (join-download or already on disk from the first full drop)

## Manifest and apply

Keep the current manifest shape: `version`, `notes`, `files[]` with `path`, `url`, `sha256`, `size`. Version remains a date token from the publish script.

Path rule:

- Default `path` installs to `<launcher>/game/<path>` (today’s behavior).
- If `path` starts with `launcher/`, strip that prefix and install to `<launcher>/<rest>`.
- Reject `..`, backslashes, and absolute paths as today.

Previous-manifest diff stays: unchanged sha256 is not re-uploaded and is omitted from the new file list. Testers who are behind more than one version still work because each publish’s manifest lists every file that changed *in that publish*, and `version.txt` inequality triggers a full apply of that file list. First-time testers with an empty `game/` only receive files listed in the latest manifest (changed since the previous publish). That is already true today (engine + web only). A first-time tester still needs either one full (no previous-manifest) publish or an existing drop. The first publish after this change should run **without** `-PreviousManifest` so the allowlist is a complete baseline.

Upload wrapper stays: payload first, `manifest.json` last, fail-fast, credential not printed, `Replace: 1`.

## Self-update

Apply is a second `NuclideLauncher.exe` instance, so it cannot overwrite its own image in place.

For `launcher/NuclideLauncher.exe`:

1. Download to `NuclideLauncher.exe.partial`.
2. Rename the running image to `NuclideLauncher.exe.old` (allowed on Windows while the process is running).
3. Move `.partial` to `NuclideLauncher.exe`.
4. Leave `.old` for this session; next successful launch may delete `.old` if the new exe started.

If rename or replace fails, abort apply, keep the current exe, surface an error. QML and `config.json` replace in place after download+hash (they are not the apply process image). Do not replace files while the game (`game/fteqw64.exe`) is running; keep the existing “is the game running?” failure.

After a launcher-exe swap, the QML UI is still the old process. That is acceptable: the next Check/launch uses the new exe. Do not auto-relaunch the UI in this pass.

## Scripts

Retarget `Tools/qml-runtime-launcher/scripts/publish-staging.ps1`:

- Default payload root is the playtest drop, not nuclide `base/data/web/` alone.
- Parameter for drop path (default: sibling `stiletto-proto` next to the nuclide repo root).
- Sync allowlist from nuclide → drop first, then hash/copy into `staging-drop/` as today.
- Include `launcher/*` files from `Tools/qml-runtime-launcher/` (built `NuclideLauncher.exe` + `app/` QML/config).
- Keep ICU-missing-with-WebCore as a hard throw.

`publish-staging-upload.ps1` keeps forwarding options and uploading. One command remains the tester-facing publish path.

## Errors

- Sync: missing required source (engine exe, `progs.dat`, ICU when WebCore present) throws before any upload.
- Upload: first failed PUT stops; old remote `manifest.json` remains the testers’ view.
- Apply: SHA256 mismatch deletes/ignores `.partial` and errors. Invalid paths error. Locked game files error with the existing message. Failed exe rename errors without deleting the current launcher.

## Non-goals

- Copyparty directory scraping without a manifest
- File watcher / auto-upload on save
- Updater window polling for new versions
- Shipping `.qc` sources or the full asset tree
- Replacing the Qt `runtime/` tree
- Changing the copyparty staging URL
- Live patching a running game session

## Verification

- PowerShell: parser check; fake copyparty listener already used for upload tests — assert `launcher/` paths, `base/progs.dat`, `fteqw64.exe`, ICU, manifest-last, and that `identity.pfx` is absent.
- Sync dry-run or temp dir: allowlisted files appear; exclusions do not; `stiletto.exe` in the drop matches `fteqw64.exe` bytes.
- `apply.c`: `launcher/` dest is install root; `base/progs.dat` dest is `game/base/progs.dat`; `..` still rejected.
- Running-exe swap: after apply, `NuclideLauncher.exe` is the new file and `.old` exists or was cleaned on next start.

## Docs

Update `Tools/qml-runtime-launcher/docs/updater.md` and `README.txt` for: drop path, allowlist, `launcher/` paths, baseline publish without previous manifest, self-update rename trick, “run publish then testers click Update.”
