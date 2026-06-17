# H3 Web Menu CSS to RmlUI Audit

Source: `web/h3-main-menu/style.css` (HTML5/CSS reference implementation)
Target: RmlUI / RCSS (`base/ui/rml/h3/style.rcss` and `main.rml`)

This document audits CSS Level 3/4+ features used in the H3 menu web prototype against RmlUI's supported subset (based on RmlUi 5.x/6.x capabilities, FTEQW integration, and known RCSS parser limits). Goal: identify gaps and document workarounds or replacements to achieve visual/functional parity.

## Supported / Directly Compatible

- `@font-face` + `font-family`, `src`, `font-display: block` → Supported (RmlUI loads WOFF via VFS). Workaround: ensure asset path maps correctly under `ui/rml/h3/assets/`.
- CSS Custom Properties (`:root { --var: val }`, `var(--var)`) → Fully supported.
- `calc()`, `min()`, `max()` → Supported in RCSS.
- `display: flex`, `flex-direction`, `flex: 0 0 auto / 1 1 auto`, `justify-content`, `align-items` → Core layout supported.
- `display: grid`, `place-items` → Supported in recent RmlUI (grid layout engine present).
- `position: absolute/relative`, `inset`, `top/right/bottom/left`, `width/height` (%, vw/vh/cqh) → Supported. Note: use `screen.HUD*` safe area per AGENTS.md for letterboxing.
- Background `linear-gradient()`, `radial-gradient()` (with rgba, deg, %) → Supported (RmlUI gradient parser covers these).
- `aspect-ratio` → Supported via RCSS (maps to layout constraint).
- `opacity`, `color`, `background`, `border`, `padding`, `margin` → Full parity.
- `overflow: hidden`, `white-space: nowrap`, `text-align`, `letter-spacing`, `font-size` (with cqh units) → Supported.
- Attribute selectors (e.g. `.page[hidden]`) → Supported.
- `pointer-events: auto/none` → Supported.
- Basic `filter: drop-shadow()` → Supported (RmlUI filter subset includes drop-shadow).

## Partially Supported / Needs Workarounds

- `container-type: size; container-name: screen;` + `cqh` / `cqi` units
  - **Status**: Container queries NOT supported in RmlUI.
  - **Workaround**: Replace with viewport-relative units (`vh`/`vw`) + JS/Lua-driven resize listener that injects dynamic `--screen-cqh` variables. Or hardcode 16:9 letterbox scaling in `.screen` using `aspect-ratio` + fixed `%` fallbacks. The `.screen` container is the primary driver for list scaling.

- `backdrop-filter: blur(7px); -webkit-backdrop-filter`
  - **Status**: Not supported (RmlUI does not implement backdrop filters or WebKit prefixes).
  - **Workaround**: Approximate with a semi-transparent background layer + pre-blurred PNG asset (e.g. `black_25.bitmap` referenced in comments). Or use engine-level "render as screen blur" pass before RmlUI draw. Documented in source comments as mapping to FTE `render as screen blur`.

- `will-change: transform`
  - **Status**: Ignored / not meaningful in RmlUI (no compositor hints exposed).
  - **Workaround**: Remove; RmlUI batches transforms internally. Keep for web reference only.

- `font-display: block`
  - **Status**: Supported but RmlUI may not honor the exact swap timing.
  - **Workaround**: Preload font via Lua `Rml.LoadFont` or ensure WOFF is in VFS before document load.

- Complex multi-layer `background:` with multiple `radial-gradient` + `linear-gradient`
  - **Status**: Supported but may require splitting into pseudo-elements or multiple background layers if parser limit hit.
  - **Workaround**: Use `background-image` + multiple `background-` properties if single declaration fails.

- `image-rendering: -webkit-optimize-contrast`
  - **Status**: WebKit prefix ignored.
  - **Workaround**: RmlUI uses nearest-neighbor or bilinear based on texture flags; set via asset import or ignore for logos.

## Not Supported / Requires Replacement

- `min(100vw, calc(100vh * 16 / 9))` combined with container queries for responsive letterboxing
  - **Replacement**: Implement stage/screen letterbox model in Lua (see AGENTS.md: `#hud-root` 4:3/16:9 pattern using `vw`/`vh` + aspect media queries if available, or fixed aspect container). Use `screen` class + JS resize → Lua prop injection.

- Advanced keyframe animations / timing functions beyond basic `transition` (source mentions 666ms slide_up, 2s subtle_pulsate, 333ms holds)
  - **Status**: RmlUI supports `@keyframes` + `animation` but limited easing and no Web Animations API.
  - **Workaround**: Port to RCSS `@keyframes` with `animation: name 666ms ease-in-out`. Validate parity vs reference screenshots in `web/h3-main-menu/reference-screenshots/`. Use `data.lua` + `app.lua` for state-driven class toggles (`enter`, `leave`).

- `filter: drop-shadow` on images + complex `rgba()` in gradients under certain blend modes
  - **Workaround**: Pre-render shadow into PNG assets or use RmlUI `<img>` with native drop-shadow decorator if available.

## Recommendations for Parity

1. Run `css_to_rcss.py` (or equivalent) on `style.css` → `style.rcss`, then manually patch the items above.
2. Maintain `web/h3-main-menu/` as source-of-truth; diffs logged in this audit.
3. Validate with `menu_restart` + visual diff against reference screenshots.
4. For container-query dependent sizing, prefer Lua-driven dynamic properties over pure CSS.
5. Backdrop blur: coordinate with FTE `RMLUI_DrawHud()` / engine blur pass.

## References
- AGENTS.md (H3 Menu RmlUI section)
- `web/h3-main-menu/README.md`
- `base/ui/rml/h3/README.md`
- RmlUI RCSS spec (subset of CSS2.1 + selected CSS3 modules)

_Last updated: 2026-05-27_
