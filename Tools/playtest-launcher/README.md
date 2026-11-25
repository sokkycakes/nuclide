# Playtest launcher

A small launcher and patcher that ships with each playtest build. Testers
download one zip, double-click one exe, and the launcher installs the game,
keeps it up to date, and starts it.

- **No runtimes.** The Windows build is a single 3 MB `.exe` that only uses
  DLLs every Windows has (WinHTTP for downloads, SDL2 linked in). The Linux
  build links SDL2 in too and only needs glibc 2.35+ and the system libcurl,
  which every desktop distro has.
- **Controller friendly.** D-pad or stick to move, A to choose, Start to play,
  B to quit. Xbox, PlayStation, Switch and generic pads work (SDL's controller
  database). Keyboard and mouse work too.
- **Fast.** Only changed files are downloaded. Files are fetched over 8
  parallel connections, big files in 8 MB chunks, small files batched into
  ranged requests. Compressible files travel zlib-compressed. An interrupted
  download picks up where it stopped. A first install of Stiletto (208 MB
  packed, 380 MB on disk) took 8 seconds from GitHub in testing.
- **Live updates from git.** A push to the `playtest` branch runs
  `.github/workflows/playtest.yml`, which publishes to the `playtest` GitHub
  release. Every launcher sees it the next time it starts.
- **Safe.** Every file is checked against its SHA-256 before it replaces the
  old one. Files the game writes itself (configs, saves) are never touched.
  The launcher updates itself the same way.

## Steam Deck, Steam Machine and other SteamOS devices

Add the launcher to Steam as a non-Steam game (Desktop Mode: Steam >
Games > Add a Non-Steam Game, pick `Stiletto Proto.exe`). For a Windows-only
game like Stiletto, open the shortcut's Properties > Compatibility and force
Proton; the launcher and the game then run in the same Proton prefix.

When Steam starts it (the `SteamGameId` variable is set, or it is running
under gamescope), the launcher:

- opens fullscreen with the mouse cursor hidden, sized for 1280x800;
- works with the built-in controls and any pad, no keyboard needed
  (nothing in the launcher asks for typing);
- hides Open Game Folder in Game Mode, where there is no file manager;
- starts the game so Steam keeps tracking it: the Linux build replaces itself
  with the game process, the Windows build (Proton) hides its window and
  waits for the game to exit. Steam's overlay, controller layout and the
  "playing" state stay on the whole time.

`--steam` forces this mode and `--fullscreen` gives fullscreen alone.

## How a build reaches testers

```
git push origin playtest
   -> GitHub Actions: build launcher, scan game files, pack what changed
   -> release "playtest": manifest.json + pack-*.bin + StilettoProto-Windows.zip
   -> tester starts "Stiletto Proto.exe": reads manifest.json, downloads only
      the changed byte ranges, verifies, swaps them in, Play
```

Testers get one link, once:
`https://github.com/sokkycakes/nuclide/releases/download/playtest/StilettoProto-Windows.zip`

## Files

| Path | What it is |
| --- | --- |
| `src/` | The launcher (C, SDL2). `update.c` is the patcher, `main.c` the UI. |
| `tools/publish.py` | Builds packs + manifest and uploads them (GitHub release or a folder). Python standard library only. |
| `tools/test_server.py` | Local stand-in for GitHub downloads (redirects + ranges) for tests. |
| `tests/e2e.sh` | End-to-end test, driven through a virtual controller. |
| `games/stiletto/` | Stiletto's publish rules and launcher config. |
| `docs/PLAYTESTERS.txt` | The README that goes in the tester zip. |

## Adding another game

1. Copy `games/stiletto/` to `games/<game>/` and edit:
   - `publish.json`: which files ship (`include`/`exclude` globs), which must
     exist (`require`), files to install only once and never overwrite
     (`keep`, for configs players edit), and the command line (`run`). The
     command line comes from the manifest, so you can change it with a push.
   - `launcher.json`: title, colours, optional `background_image`, `icon`,
     `font`, `font_bold` (paths next to the exe).
2. Copy the workflow and point it at the new folder and zip name.

## Publishing by hand

```sh
GITHUB_TOKEN=... python3 tools/publish.py --backend github --repo OWNER/REPO --tag playtest \
  --src /path/to/game --rules games/stiletto/publish.json --notes "Fix lunge hitbox"
# or into a folder you host anywhere:
python3 tools/publish.py --src /path/to/game --rules games/stiletto/publish.json --out ./site
```

## Building and testing

```sh
./build.sh linux      # out/linux/playtest-launcher
./build.sh windows    # out/windows/playtest-launcher.exe (mingw-w64)
tests/e2e.sh linux
tests/e2e.sh windows  # runs the .exe under Wine
```

The end-to-end test publishes a fake game, then checks: first install with
the controller, launch with the manifest's arguments, a delta update (60 MB
game, 64 KB download), removed files, kept configs, repair of a corrupted
file, launcher self-update, offline play, resume after an interrupted
download, and Steam mode (fullscreen, game started attached).

## Launcher options

| Option | Use |
| --- | --- |
| `--config FILE` | Use another `launcher.json`. |
| `--verify` | Re-hash every file on start (same as Repair). |
| `--steam` | Behave as if started by Steam (fullscreen, game keeps the launcher's process). |
| `--fullscreen` | Start fullscreen. |
| `--test-script FILE` | Drive the UI from a script with a virtual controller (tests). |

## Manifest format

```json
{
  "format": 1, "version": "2026.1125.1130-f038edb", "commit": "...", "notes": "- Fix lunge hitbox",
  "packs": [{"name": "pack-3f2a....bin", "size": 181459525}],
  "files": [{"path": "base/progs.dat", "sha256": "...", "size": 2100000,
             "pack": 0, "offset": 1048576, "length": 512000, "z": 1}],
  "run": {"windows": {"exe": "fteqw64.exe", "args": ["-basedir", ".", "-manifest", "base.fmf"]}},
  "launcher": {"windows": {"name": "launcher-windows-....exe", "sha256": "...", "size": 3331584}}
}
```

Pack and launcher assets are named by content, so a publish never overwrites
a file a tester may be downloading. `manifest.json` is replaced last, and the
previous build's packs are kept until the next publish.
