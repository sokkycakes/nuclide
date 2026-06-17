# Halo 3 Main Menu — RmlUI (native)

RmlUI-native port of [`../h3-main-menu/`](../h3-main-menu/) (browser mockup). Same tag-derived layout and navigation; logic is **Lua** instead of JavaScript.

## Run (LuaRmlUi)

From this directory:

```bash
luarmlui main.lua
```

`main.lua`:

1. Sets `package.path` for `app.lua`, `data.lua`, and `lib/*.lua`
2. Loads `assets/Conduit-ITC.ttf` (see fonts below)
3. Opens `main.rml` and calls `App.init`
4. Returns `function(dt)` — your host must call it **every frame** with elapsed seconds so timers and transition safety nets work

If your LuaRmlUi build uses a different context name or bootstrap API, adjust `main.lua` only; `app.lua` stays host-agnostic.

## Option B Full Compatibility Layer (ACTIVE)
- Lua polyfills (lib/css_polyfills.lua) emulate transitions/animations/filters via Timers + decorators
- RCSS pre-processor strips 60+ unsupported props (font-display, grid, border-radius, etc.)
- Image assets required for shadows/gradients (tools/generate_h3_assets.py)
- Source of truth: web/h3-main-menu/ + H3EK tag XML
- Reload: menu_restart (FTE) or rerun main.lua (rml_live)

## Files

| File | Role |
|------|------|
| `main.rml` | Markup (RML, not HTML) |
| `style.rcss` | Styles (RCSS); converted from `style.css` via `tools/css_to_rcss.py` |
| `app.lua` | Input, lists, page transitions, roster |
| `data.lua` | Tag-derived menu data (from `data.json`) |
| `lib/timers.lua` | `set_timeout` / `update(dt)` |
| `lib/listcontroller.lua` | Focused list rows |
| `assets/` | Bitmaps + font |

Regenerate derived artifacts after editing the web sources:

```bash
python tools/build_assets.py   # data.lua + baked PNGs
python tools/css_to_rcss.py    # style.rcss bulk port
```

## Controls

- **Up/Down** or **W/S** — move focus
- **Enter**, **Space**, **A** — confirm
- **Esc**, **B** — back
- **X** — Settings stub
- **Y** — Roster (lobby) or Friends (online main menu)
- **`** — toggle debug HUD

## Fonts

RmlUI reads **TTF/OTF** only. `assets/Conduit-ITC.ttf` is currently a copy of `base/fonts/IosevkaStiletto-ExtendedLight.ttf` as a stand-in. Replace with a real Conduit ITC TTF when available; RCSS still uses `font-family: "Conduit ITC"`.

## Visual gaps (best-effort vs web)

| Web feature | RmlUI port |
|-------------|------------|
| `backdrop-filter` blur on panels | Dropped; panel opacity raised (~92%) |
| CSS `mask` on roster strip | Pre-baked `assets/roster/roster_unfocused_tinted.png` |
| `::before` focus bars | Real `<img class="focus-bar">` per row |
| Lobby page tint `::before` | `<div class="lobby-tint">` |
| Three-stop `.lobby-list` gradient | `assets/lobby_list_gradient.png` |
| `container-type` / `cqh` | `vh`/`vw`; `#screen` sized by host letterbox |
| `buttonhover.svg` | `assets/buttonhover.png` (baked gradient bar) |
| `?slow` URL param | `SLOWMO_FACTOR` constant at top of `app.lua` |

## Data

`data.lua` is generated from [`../h3-main-menu/data.json`](../h3-main-menu/data.json). Edit JSON in the web tree, then run `python tools/build_assets.py`.

## Not FTE RmlUI

This tree targets **standalone RmlUI** (LuaRmlUi). It is separate from Nuclide `base/ui/rml/` used by FTEQW.
