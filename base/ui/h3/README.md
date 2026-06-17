# Halo 3 main menu — HTML5/CSS/JS mockup

A runnable approximation of the Halo 3 main menu, built entirely from data
exported out of the **Halo 3 Editing Kit** tag tree at:

`D:\Steam\steamapps\common\H3EK\tags\ui\halox\main_menu\` and
`D:\Steam\steamapps\common\H3EK\tags\ui\main_menu.user_interface_globals_definition`.

## Running it

The page uses `fetch("data.json")`, which `file://` blocks. Serve over HTTP:

```powershell
cd D:\Steam\steamapps\common\H3EK\web_menu
python -m http.server 8000
# then open http://localhost:8000 in a browser
```

Any static server works (`npx serve`, `live-server`, IIS, etc.).

## Controls

| Key | Action |
|-----|--------|
| Up / Down or W / S | Move list focus (with wrap, per H3 `list wraps` flag) |
| Enter / A / Space  | Confirm — opens stub submenu |
| Esc / B            | Back (main menu has `B-Back shouldn't dispose screen`, so a no-op at the top level) |
| X                  | Settings (offline + online prompt) |
| Y                  | Friends (online prompt only) |
| `                  | Toggle debug HUD; tick **online** to see `main_menu_online` prompt |

## Layout & behavior provenance

| Web piece | H3EK source tag |
|-----------|-----------------|
| 9 menu items + order | `tags\ui\halox\main_menu\main_menu_list.gui_datasource_definition` |
| English item labels | `tags\ui\halox\main_menu\strings.multilingual_unicode_string_list` (UTF-8 blob, decoded from binary) |
| Bottom prompt labels | `tags\ui\halox\main_menu\button_keys.multilingual_unicode_string_list` |
| Screen widget layout | `tags\ui\halox\main_menu\main_menu.gui_screen_widget_definition` |
| List row template | `tags\ui\halox\main_menu\mainmenu_list.gui_list_widget_definition` |
| Skin (text/bitmap rules per row) | `tags\ui\halox\main_menu\main_menu_list.gui_skin_definition` |
| `subtle_pulsate` 2 s loop on focused row | `tags\ui\halox\global_animations\animations\subtle_pulsate.gui_widget_color_animation_definition` |
| `slide_up` entry of channel/list (333 ms hold + 333 ms slide) | `tags\ui\halox\main_menu\animations\slide_up.gui_widget_position_animation_definition` |
| `fade_in_250`, `delayd_fade_in_250` | `tags\ui\halox\global_animations\animations\` |
| Unfocused row color `(0.698, 0.78, 1.0)` @ 0.25 alpha | `tags\ui\halox\common\standard_list\unfocused_listitem.gui_widget_color_animation_definition` |
| Submenu screen destinations | `tags\ui\main_menu.user_interface_globals_definition` (`halox screen widgets` block — 66 entries) |
| Title / Bungie logos | `tags\ui\halox\main_menu\halo3_logo_ui.bitmap`, `bungielogo.bitmap` |
| Channel strip / bottom gradient | `tags\ui\halox\main_menu\mainmenu_bkd.bitmap`, `bottom_gradient_ui.bitmap` |
| Black intro fade overlay | `tags\ui\halox\common\common_bitmaps\black_fade_ui.bitmap` + `ui\halox\global_animations\animation_collections\black_fade` |

## Knowingly absent (engine-side, not in tags)

1. **3D animated background** — `on load script name = "mainmenu_cam"` loads `tags\levels\ui\mainmenu\` (193 tags: BSP, scenery, weather, lighting). The mockup uses a flat gradient stand-in.
2. **Save-game / Live state filtering** — the H3 runtime hides `resume_campaign` with no save, gates `theater` and `locked` by online status, swaps `main_menu_offline` ↔ `main_menu_online` based on sign-in. Use the debug HUD `online` checkbox to toggle the offline/online prompt manually.
3. **Real fonts** — Halo 3 uses "Conduit ITC" (body) and a stylized terminal face (build text). Approximated with Bahnschrift / Consolas.
4. **UI sounds** — `tags\ui\default_sounds.user_interface_sounds_definition` not wired (focus move, confirm, back beeps).
5. **`black_25.bitmap`** — failed to export from H3EK (abgrfp16 decode error); substituted with a CSS `rgba(0,0,0,.25)` blur.

## Files

```
web_menu/
├── README.md          this file
├── index.html         the page
├── style.css          720p logical layout + tag-derived animation timings
├── app.js             list focus, online/offline state, navigation dispatch
├── data.json          datasource items + labels + nav table + animation keyframes
└── assets/            PNG conversions of the exported H3EK bitmaps
    ├── halo3_logo.png
    ├── bungielogo.png
    ├── mainmenu_bkd.png
    ├── bottom_gradient.png
    ├── black_bar.png
    └── black_fade.png
```

## Re-deriving data.json from the tags

If you re-export or modify a tag, refresh `data.json` by hand from the new
XML. The strings live in the `string data utf8` blob of the `.unic` tag —
the tag-XML exporter writes it as an opaque base64-ish field, so dump
ASCII runs directly:

```python
import re
data = open(r"D:\Steam\steamapps\common\H3EK\tags\ui\halox\main_menu\strings.multilingual_unicode_string_list", "rb").read()
for m in re.finditer(rb"[\x20-\x7e]{4,}", data):
    print(m.start(), m.group().decode("latin-1"))
```

The English text strings appear in the 3000-6300 byte range, one language
at a time, in the order declared by the `string references` block.
