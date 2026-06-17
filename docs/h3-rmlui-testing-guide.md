# H3 RmlUI Testing Guide

## Important: Standalone vs FTEQW

**The H3 menu (`base/ui/rml/h3/`) is currently for standalone RmlUI (LuaRmlUi), NOT FTEQW integration.**

Per `base/ui/rml/h3/README.md`:
> This tree targets **standalone RmlUI** (LuaRmlUi). It is separate from Nuclide `base/ui/rml/` used by FTEQW.

## Testing Options

### Option 1: RML Live with Lua Support (Recommended)

**Requirements:**
- `rml_live.exe` with Lua support

**Steps:**
1. From the Nuclide root directory, run:
   ```bash
   rml_live.exe base/ui/rml/h3/main.rml
   ```
   
   Or navigate to the H3 directory first:
   ```bash
   cd base/ui/rml/h3/
   rml_live.exe main.rml
   ```

2. The viewer should open with the H3 menu loaded

3. Test controls:
   - **Up/Down** or **W/S** — move focus
   - **Enter**, **Space**, **A** — confirm
   - **Esc**, **B** — back
   - **X** — Settings stub
   - **Y** — Roster (lobby) or Friends (online main menu)
   - **`** (backtick) — toggle debug HUD

4. Verify against reference screenshots in `web/h3-main-menu/reference-screenshots/`

### Option 2: FTEQW In-Game HUD (Different System)

**For the in-game HUD** (`base/ui/rml/hud.rml`, NOT the H3 menu):

1. Launch FTEQW with the base game:
   ```bash
   fteqw64.exe +game base
   ```

2. Load a map:
   ```
   devmap <mapname>
   ```

3. Reload RmlUI after edits:
   ```
   menu_restart
   ```

**Note:** The in-game HUD system is separate from the H3 main menu system.

## What Was Fixed

The fixes applied to `base/ui/rml/h3/style.rcss` are for the **standalone H3 menu**, which runs in LuaRmlUi, not FTEQW.

### Syntax Errors Fixed
- 13 locations with concatenated properties
- 3 locations with `0px` borders changed to `none`
- Malformed comment closures
- Orphaned keyframe definitions

### CSS Incompatibilities Addressed
- Container queries → `vh`/`vw` units
- `backdrop-filter` → Removed (opacity increased)
- `will-change` → Removed (not meaningful in RmlUI)
- `@keyframes` → Moved to Lua timers
- CSS `mask` → Pre-baked assets
- Complex gradients → Pre-baked images
- WebKit prefixes → Removed

## Visual Verification Checklist

When testing in LuaRmlUi, verify:

✅ **Layout**
- [ ] Main menu panel positioned correctly (left side)
- [ ] HALO 3 logo positioned correctly (right side, ~62% from top)
- [ ] Bungie logo positioned correctly (bottom right)
- [ ] Lobby panel positioned correctly (left side, full height)
- [ ] Roster sidebar positioned correctly (right side)

✅ **Styling**
- [ ] Panel backgrounds render (dark blue gradient)
- [ ] Borders render correctly (no `0px` artifacts)
- [ ] Text colors correct (ice blue #adc4df unfocused, hilite #eaeef8 focused)
- [ ] Font loads correctly (Conduit ITC or fallback)

✅ **Interactive States**
- [ ] Focus navigation works (up/down arrows)
- [ ] Focused items highlight correctly
- [ ] Hover states work (if mouse enabled)
- [ ] Disabled items appear dimmed

✅ **Animations** (if Lua timers implemented)
- [ ] Panel slide animations (666ms)
- [ ] Fade animations (333ms)
- [ ] Logo fade-in on first load

✅ **Roster** (lobby page)
- [ ] 16 roster slots render
- [ ] Player names display
- [ ] Focus states work
- [ ] Empty slots render correctly

## Known Limitations

Per `base/ui/rml/h3/README.md`, these web features are not available in RmlUI:

| Web Feature | RmlUI Workaround |
|-------------|------------------|
| `backdrop-filter` blur | Panel opacity raised to ~92% |
| CSS `mask` | Pre-baked `roster_unfocused_tinted.png` |
| `::before` focus bars | Real `<img class="focus-bar">` elements |
| Three-stop gradients | Pre-baked `lobby_list_gradient.png` |
| Container queries | `vh`/`vw` units + Lua letterbox |
| `buttonhover.svg` | Pre-baked `buttonhover.png` |

## Troubleshooting

### "Cannot find luarmlui"
- LuaRmlUi is not installed or not in PATH
- Build LuaRmlUi from source or obtain prebuilt binary

### "Cannot load font"
- Ensure `assets/Conduit-ITC.ttf` exists
- Currently uses `IosevkaStiletto-ExtendedLight.ttf` as stand-in

### "Styles not loading"
- Check console for RCSS parse errors
- Verify all syntax fixes were applied
- Ensure `style.rcss` is in same directory as `main.rml`

### "Animations not working"
- Animations require Lua timer implementation in `app.lua`
- Check `lib/timers.lua` is present and loaded

## FTEQW Integration (Future)

To integrate the H3 menu into FTEQW:

1. Port Lua logic to QuakeC or FTE's menu system
2. Adapt RML/RCSS for FTE's RmlUI implementation
3. Wire up to FTE's menu commands
4. Test with `menu_restart` in FTE console

**Current Status:** H3 menu is standalone only. FTEQW uses separate menu system in `base/ui/rml/basemodui.rml`.

## Reference Files

- **Source of Truth:** `web/h3-main-menu/` (HTML5 prototype)
- **Reference Screenshots:** `web/h3-main-menu/reference-screenshots/`
- **Production Files:** `base/ui/rml/h3/`
- **Audit Documentation:** `docs/h3-css-rmlui-audit.md`
- **Fix Report:** `docs/h3-rmlui-incompatibility-fixes.md`

---

**Last Updated:** 2026-05-27  
**Status:** Syntax fixes complete, ready for standalone LuaRmlUi testing