# L4D2 BaseMod UI Wireframe (hybrid)

Fork of the hand-wired **foundation** wireframe. **Behavior and layout UX** come from authored HTML/JS (Alien Swarm / BaseMod SDK patterns). **L4D2 `.res` files** are used offline only — converted to JSON manifests for command validation and an optional position overlay.

Sources:

- Behavior: `CBaseModPanel` window stack, `OnCommand` routing (foundation)
- Control IDs / commands: L4D2 `resource/ui/l4d360ui/*.res` (extracted to `res/`)

## Run

```bash
cd web/basemod-wireframes-l4d2
python -m http.server 8080
```

Open **http://localhost:8080** — a local server is required for `fetch('js/manifests/...')`.

## Re-extract / regenerate manifests

```bash
pip install vpk
python scripts/extract-l4d2-res.py
# optional: python scripts/extract-l4d2-res.py "D:/Steam/.../left4dead2/pak01_dir.vpk"
python scripts/res_to_manifest.py
```

## Architecture

| Layer | File | Role |
|---|---|---|
| State machine | `js/state-machine.js` | `CBaseModPanel` window stack (from foundation) |
| Views | `index.html` + `css/wireframe.css` | Hand-authored L4D2 screens, grids, flyouts |
| Commands | `js/app.js` | Routes `data-cmd` clicks (L4D2 commands included) |
| Rendering | `js/panels.js` | Show/hide views, lobby chat, loading sim |
| Manifests | `js/manifests/*.json` | Offline `.res` → JSON (positions, commands, visibility) |
| Hints | `js/manifest-hints.js` | Validates HTML vs manifest; optional overlay toggle |

**Removed** (old runtime `.res` approach): `res-parser.js`, `res-layout.js`, `res-layout.css`.

## Debug panel

- **Show .res position overlay** — maps manifest `xpos`/`ypos`/`wide`/`tall` onto authored controls; ghosts missing IDs
- **cmd drift** — warns when `data-cmd` on an `id` does not match the `.res` `command`

## vs foundation

| | Foundation | This fork |
|---|---|---|
| Game | Alien Swarm SDK reference | Left 4 Dead 2 `.res` IDs/commands |
| Layout | Hand-placed HTML | Same — hand-placed HTML |
| `.res` | Not used | Offline manifests + optional overlay |
| Revert target | `../basemod-wireframes-foundation/` | — |

See [MAPPING.md](./MAPPING.md) for window → `.res` mapping.
