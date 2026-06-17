# RmlUI Rendering Rules & Gotchas (Confirmed via rml_live Testing)

**Date:** 2026-05-27  
**Test environment:** `rml_live.exe` (custom build at `fteqw/libs/RmlUi/build_rml_live/bin/`)  
**Context:** 1280×720 window, Lua bindings enabled

---

## Critical Rule: `display` Defaults to `inline`

Unlike HTML where `<div>` defaults to `display: block`, **RmlUI defaults ALL elements to `display: inline`**. This means:

- `width` and `height` properties are **IGNORED** on elements without explicit `display: block` (or `flex`, `inline-block`, etc.)
- Elements stack **horizontally** instead of vertically
- This is the #1 cause of "nothing renders" on first load

**Fix:** Always declare display mode explicitly at the top of your stylesheet:

```css
body { display: block; }
div { display: block; }
p { display: block; }
img { display: block; }
ul { display: block; }
ol { display: block; }
h1, h2, h3, h4, h5, h6 { display: block; }
```

---

## Critical Rule: Empty Elements Don't Paint Backgrounds

An element with `background-color` will **NOT render its background** if it has:
- Zero content (no text, no in-flow children)
- Zero padding

Even explicit `width`/`height` won't force painting.

| width/height | padding | content | Paints background? |
|---|---|---|---|
| 300px/100px | 0 | none | **NO** |
| 300px/100px | 0 | text | YES |
| 300px/100px | 20px | none | YES |
| 300px/100px | 1px | none | YES |
| auto | 30px | text | YES |

**Fix:** Add `padding: 1px` to any container that needs a visible background but has no text content. Use `box-sizing: border-box` to prevent the padding from expanding the element.

---

## Critical Rule: `body` Background Never Paints

The `<body>` element does NOT render `background-color` or `background` in RmlUI. The viewport background is always controlled by the rendering backend (default: black/transparent).

**Fix:** Use a wrapper `<div>` as the visual root with `width: 100vw; height: 100vh; padding: 1px; box-sizing: border-box;`.

---

## Critical Rule: Viewport Units for Full-Screen Coverage

To fill the entire rml_live window, use viewport units:

```css
.stage {
  width: 100vw;
  height: 100vh;
  padding: 1px;
  box-sizing: border-box;
  background-color: #1a2c43;
  overflow: hidden;
}
```

Pixel dimensions (e.g., `width: 1280px; height: 720px`) may NOT fill the window due to DPI scaling or window resizing. Percentage dimensions (`width: 100%; height: 100%`) don't work because `body` has no intrinsic height.

---

## Critical Rule: `@font-face` Can Shadow Built-in Fonts

`Shell::LoadFonts()` in rml_live registers `LatoLatin` from the exe's assets directory. If your stylesheet declares:

```css
@font-face {
  font-family: LatoLatin;
  src: url("path/to/other-font.ttf");
}
```

...and the font file fails to load, this **shadows and breaks** the working built-in LatoLatin. All text using `font-family: LatoLatin` becomes invisible.

**Fix:** Either:
- Remove `@font-face` entirely (use the built-in LatoLatin)
- Use a DIFFERENT family name in @font-face (e.g., `font-family: ConduitITC;`)
- Ensure the font file is loadable from the document's directory

---

## CSS Property Compatibility Reference

### Supported (confirmed working)

| Property | Notes |
|---|---|
| `background-color` | Works on elements with content or padding |
| `background` | **Shorthand for `background-color` ONLY** — excludes images |
| `color` | Standard hex, `rgb()`, `rgba()` |
| `width`, `height` | Only on `display: block`/`flex`/`inline-block` elements |
| `padding`, `margin` | Standard |
| `border-width`, `border-color` | Individual longhand properties |
| `border` | Shorthand = `border-width` + `border-color` only. **NO `solid`/`none` keyword** |
| `border-top-width`, `border-top-color` etc. | Individual edge properties |
| `display` | `block`, `inline`, `inline-block`, `flex`, `inline-flex`, `none` |
| `position` | `static`, `relative`, `absolute`, `fixed` |
| `top`, `right`, `bottom`, `left` | For positioned elements |
| `overflow` | `visible`, `hidden`, `auto`, `scroll` |
| `opacity` | 0.0 to 1.0 |
| `box-sizing` | `content-box`, `border-box` |
| `box-shadow` | **Color FIRST**: `box-shadow: #000a 5px 5px 5px;` |
| `border-radius` | Supported (single value per corner, no percentages) |
| `font-family` | Single family name only |
| `font-size` | px, em, vh, vw, rem |
| `flex`, `flex-direction`, `flex-wrap` | Full flexbox support |
| `align-items`, `justify-content` | Standard flex values |
| `gap`, `column-gap`, `row-gap` | Flex containers |
| `text-align` | `left`, `right`, `center` |
| `text-transform` | `uppercase`, `lowercase`, `capitalize`, `none` |
| `white-space` | `normal`, `nowrap`, `pre`, `pre-wrap` |
| `letter-spacing` | Standard |
| `line-height` | Standard |
| `pointer-events` | `auto`, `none` |
| `decorator` | `image()`, `tiled-box()`, `gradient()` — see below |
| `filter` | Supported |
| `animation` | Supported (keyframes in RCSS) |
| `transition` | Supported |
| `transform` | Supported |
| Viewport units | `vw`, `vh` work correctly |

### NOT Supported / Different Syntax

| Property | Issue | Fix |
|---|---|---|
| `background: url(...)` | Images not in background shorthand | Use `decorator: image("file.png")` |
| `background: linear-gradient(...)` | Not supported | Use `decorator: gradient(...)` or solid color |
| `background: radial-gradient(...)` | Not supported | Use solid color or image asset |
| `border: 1px solid #color` | `solid` keyword invalid | Use `border-width: 1px; border-color: #color;` |
| `border-top: none` | `none` keyword invalid | Use `border-top-width: 0;` |
| `font-family: "Name", fallback` | Multiple families unreliable | Use single family |
| `color: inherit` | Not supported | Set color explicitly |
| `list-style` | Not supported | Remove |
| `isolation` | Not supported | Remove |
| `display: grid` | Not supported | Use `display: flex` |
| `place-items` | Not supported | Use `align-items` + `justify-content` |
| `aspect-ratio` | Not supported | Use explicit width/height |

### `rgba()` Alpha Format

RmlUI accepts alpha as **0–255 integer**, not 0.0–1.0 float:

```css
/* WRONG */
color: rgba(255, 255, 255, 0.5);

/* CORRECT */
color: rgba(255, 255, 255, 128);
```

### `box-shadow` Syntax

Color comes **FIRST**, not last:

```css
/* WRONG (CSS3 standard) */
box-shadow: 0 5px 10px rgba(0, 0, 0, 128);

/* CORRECT (RmlUI) */
box-shadow: rgba(0, 0, 0, 128) 0 5px 10px;
```

### Decorator Syntax

Background images use `decorator`, not `background`:

```css
/* For images */
decorator: image("assets/my-image.png" cover);
decorator: image("assets/my-image.png" repeat);

/* For gradients */
decorator: gradient(vertical #14222e #0f1a24);

/* NO commas between arguments — spaces only */
/* NO escaped quotes */
```

---

## rml_live Architecture (from source: Samples/basic/rml_live/src/main.cpp)

1. Creates 1280×720 window and RmlUI context
2. `Shell::Initialize()` installs `ShellFileInterface` that resolves paths relative to the Samples root
3. `Shell::LoadFonts()` registers LatoLatin from `<samples_root>/assets/`
4. `context->LoadDocument(path)` loads the .rml file passed on command line
5. `document->Show()` makes it visible
6. Hot-reload: monitors .rml file for changes every ~0.5s and reloads automatically
7. **NO Lua scripts execute automatically** — `main.lua` / `app.lua` are for FTE integration only

### File Resolution Order (ShellFileInterface::Open)

1. Try `<samples_root>/<path>` (relative to exe location)
2. Fall back to `<path>` relative to current working directory

### Running from a Custom Directory

```powershell
cd web/h3-main-menu-rml
& "path/to/rml_live.exe" "main.rml"
```

- `main.rml` resolves from CWD
- `style.rcss` (linked in head) resolves relative to `main.rml`
- `assets/*.png` in `<img src="...">` resolves relative to `main.rml`
- Font files in `@font-face url()` resolve relative to the `.rcss` file

---

## Minimal Working RmlUI Template

```xml
<rml>
<head>
<title>My Document</title>
<style>
/* REQUIRED: RmlUI defaults all elements to inline */
body { display: block; margin: 0; padding: 0; font-family: LatoLatin; color: #f6f6f6; }
div { display: block; }
p { display: block; }
img { display: block; }
ul, ol { display: block; }
li { display: block; }
h1, h2, h3 { display: block; }
span { display: inline; }

/* Full-viewport root (body bg doesn't paint) */
.root {
  width: 100vw;
  height: 100vh;
  padding: 1px;
  box-sizing: border-box;
  background-color: #1a2c43;
  overflow: hidden;
}
</style>
</head>
<body>
<div class="root">
  <!-- Your content here -->
</div>
</body>
</rml>
```

---

## Checklist Before Testing in rml_live

- [ ] All `<div>`, `<p>`, `<img>` have `display: block` (global rule)
- [ ] No `@font-face` shadowing `LatoLatin`
- [ ] Background colors on `body` moved to a child div
- [ ] Root div uses `width: 100vw; height: 100vh; padding: 1px; box-sizing: border-box`
- [ ] No `border: Xpx solid #color` — use `border-width` + `border-color` separately
- [ ] No `rgba()` with float alpha — use 0-255 integer
- [ ] No `background: url(...)` — use `decorator: image(...)` instead
- [ ] `box-shadow` has color FIRST
- [ ] No `linear-gradient()` or `radial-gradient()` in `background` — use `decorator: gradient()` or solid color
