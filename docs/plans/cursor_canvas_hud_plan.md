# FTEQW WebCore Canvas HUD — Implementation Plan

## Project Summary

Adapt the Figma HUD design into a production-ready **Canvas 2D HUD renderer** running inside the game's embedded **Ultralight WebCore** view.

The source design is the Figma node:

- File: `TwV4BjYuoh7tbV28O6NP2I`
- Node: `116:278`
- Name: `ss_player_collier HUD (v3, left meter flat)`
- Source frame size: `1440 × 1080`
- Intended game reference noted in Figma: `1920 × 1080`

The implementation must not stretch the 4:3 Figma frame to 16:9. It should reinterpret the design as independently anchored HUD clusters using a shared 1080-pixel logical height.

---

## Primary Goals

- Reproduce the visible Figma HUD closely in Canvas 2D.
- Support 4:3, 16:9, ultrawide, and lower-resolution displays.
- Keep the crosshair exactly centered and independently scalable.
- Keep the match header centered at the top.
- Anchor the resource panel to the bottom-left safe area.
- Anchor telemetry and cooldown indicators near the bottom center.
- Preserve the large circular decoration without horizontal distortion.
- Support live game-state updates without rebuilding DOM elements.
- Keep the renderer efficient enough for continuous gameplay.
- Provide a narrow, predictable bridge between FTEQW and JavaScript.

---

## Non-Goals

- Do not reproduce the HUD as a single full-screen bitmap.
- Do not stretch the original 1440 × 1080 layout to fill 1920 × 1080.
- Do not reproduce every Figma layer as an individual Canvas draw call.
- Do not use React, Tailwind, or another UI framework.
- Do not depend on modern browser APIs without verifying WebCore support.
- Do not implement final animations before static layout accuracy is established.
- Do not expose arbitrary engine internals directly to JavaScript.

---

## Technical Stack

- HTML
- CSS
- TypeScript or plain JavaScript, depending on the existing WebCore project
- Canvas 2D
- Embedded Ultralight WebCore
- FTEQW-to-JavaScript bridge
- Transparent WebCore surface composited over the game

---

## Source HUD Breakdown

The inspected Figma node contains these production-relevant clusters:

1. **Decorative ring**
   - Large circular image centered on the viewport.
   - Approximately `1386 × 1386` logical pixels.
   - Drawn at partial opacity.
   - Must remain circular.

2. **Top match display**
   - Figma node: `116:394`
   - Local size: approximately `756 × 317`
   - Contains:
     - Left score
     - Left player nameplate
     - Left mini gauge
     - Timer frame
     - Timer text
     - Right score
     - Right player nameplate
     - Right mini gauge

3. **Center status display**
   - Figma node: `116:435`
   - Local size: approximately `400 × 360`
   - Contains:
     - Ammo display
     - Ability charge pips
     - Health-state artwork
     - Reload timer

4. **Crosshair**
   - Separate centered star element.
   - Approximately `50 × 50`.
   - Must be independent from HUD scale where practical.

5. **Bottom-left resource panel**
   - Currently split across:
     - `116:733`
     - `116:313`
   - Must become one logical component.
   - Contains:
     - Character or class icon
     - Long yellow resource meter
     - Resource count
     - Decorative white shape
     - `MAX` state
     - EX or Drive label

6. **Bottom-center telemetry**
   - Speedometer
   - Three cooldown indicators
   - Dynamic cooldown numbers

7. **Hidden or alternate design states**
   - Older objective HUD
   - Alternate Drive and EX gauges
   - Hidden ammo pips
   - Alternate health graphics
   - Hidden player ranks
   - Prototype source vectors

Only visible production elements should be implemented initially.

---

# Architecture

## Logical Coordinate System

Use `1080` as the canonical logical HUD height.

```ts
const DESIGN_HEIGHT = 1080;
const hudScale = viewportHeight / DESIGN_HEIGHT;
```

Examples:

```text
1920 × 1080  → scale 1.0
1280 × 720   → scale 0.6667
2560 × 1440  → scale 1.3333
3440 × 1440  → scale 1.3333
```

The viewport width remains independent. This prevents 4:3 source artwork from being horizontally stretched.

---

## Anchor Model

Each top-level component must use one semantic anchor.

### Supported anchors

```ts
type HorizontalAnchor = "left" | "center" | "right";
type VerticalAnchor = "top" | "center" | "bottom";
```

### Component anchors

| Component | Horizontal Anchor | Vertical Anchor |
|---|---|---|
| Decorative ring | center | center |
| Match header | center | top |
| Center status | center | center |
| Crosshair | center | center |
| Resource panel | left | bottom |
| Telemetry | center | bottom |

The renderer must calculate screen placement before entering each component's local coordinate space.

---

## Recommended File Structure

```text
hud/
├── index.html
├── styles.css
├── main.ts
├── HudRenderer.ts
├── HudState.ts
├── HudLayout.ts
├── HudSettings.ts
├── AssetLoader.ts
├── CanvasUtils.ts
├── FontLoader.ts
├── EngineBridge.ts
├── caches/
│   ├── HudCacheManager.ts
│   ├── MatchHeaderCache.ts
│   ├── ResourcePanelCache.ts
│   └── TelemetryCache.ts
├── renderers/
│   ├── drawDecorativeRing.ts
│   ├── drawMatchHeader.ts
│   ├── drawCenterStatus.ts
│   ├── drawCrosshair.ts
│   ├── drawResourcePanel.ts
│   └── drawTelemetry.ts
├── primitives/
│   ├── drawAnchored.ts
│   ├── drawPips.ts
│   ├── drawMeter.ts
│   ├── drawMaskedFill.ts
│   ├── drawText.ts
│   └── fitText.ts
└── assets/
    ├── ring/
    ├── match/
    ├── center/
    ├── resource/
    ├── telemetry/
    └── fonts/
```

If the existing HUD project uses a different structure, preserve its conventions while maintaining the same conceptual separation.

---

# Core Data Model

## HUD State

```ts
export type GaugeType = "drive" | "ex";
export type HealthVisualState = "normal" | "low" | "dead";

export interface PlayerHudState {
  name: string;
  score: number;
  teamColor: string;

  gaugeType: GaugeType;
  gaugeValue: number;
  gaugeMaximum: number;

  connected: boolean;
}

export interface CooldownState {
  id: string;
  value: number;
  maximum: number;
  ready: boolean;
  visible: boolean;
}

export interface HudState {
  visible: boolean;

  matchTimeSeconds: number;

  playerOne: PlayerHudState;
  playerTwo: PlayerHudState;

  ammoCurrent: number;
  ammoMaximum: number;

  health: number;
  healthMaximum: number;
  healthVisualState: HealthVisualState;

  resource: number;
  resourceMaximum: number;
  resourceCount: number;
  resourceAtMaximum: boolean;
  resourceType: GaugeType;

  abilityCharges: number;
  abilityChargeMaximum: number;

  reloadSeconds: number;
  speed: number;

  cooldowns: CooldownState[];
}
```

---

## HUD Settings

```ts
export interface HudSettings {
  hudScale: number;

  safeAreaLeft: number;
  safeAreaRight: number;
  safeAreaTop: number;
  safeAreaBottom: number;

  crosshairScale: number;
  crosshairOpacity: number;
  showCrosshair: boolean;

  showDecorativeRing: boolean;
  showTelemetry: boolean;
  showCenterStatus: boolean;

  pixelSnap: boolean;
}
```

`hudScale` is a user preference multiplier applied after resolution scaling.

```ts
const finalScale =
  (viewportHeight / DESIGN_HEIGHT) *
  settings.hudScale;
```

---

# Layout Definitions

Create a central layout file rather than scattering coordinates across renderers.

```ts
export const HUD_LAYOUT = {
  ring: {
    anchorX: "center",
    anchorY: "center",
    width: 1386,
    height: 1386,
    offsetX: 0,
    offsetY: 0,
    opacity: 0.6
  },

  matchHeader: {
    anchorX: "center",
    anchorY: "top",
    width: 756,
    height: 317,
    offsetX: 0,
    offsetY: 0
  },

  centerStatus: {
    anchorX: "center",
    anchorY: "center",
    width: 400,
    height: 360,
    offsetX: 0,
    offsetY: 0
  },

  crosshair: {
    anchorX: "center",
    anchorY: "center",
    width: 50,
    height: 50,
    offsetX: 0,
    offsetY: 0
  },

  resourcePanel: {
    anchorX: "left",
    anchorY: "bottom",
    width: 546,
    height: 261,
    offsetX: 0,
    offsetY: -93
  },

  telemetry: {
    anchorX: "center",
    anchorY: "bottom",
    width: 413,
    height: 118,
    offsetX: 0,
    offsetY: -54
  }
} as const;
```

These values are initial approximations derived from the Figma composition and must be refined through screenshot comparison.

---

# Canvas Setup

## Required HTML

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta
      name="viewport"
      content="width=device-width, initial-scale=1"
    />
    <link rel="stylesheet" href="./styles.css" />
  </head>

  <body>
    <canvas id="game-hud"></canvas>
    <script type="module" src="./main.js"></script>
  </body>
</html>
```

## Required CSS

```css
html,
body {
  width: 100%;
  height: 100%;
  margin: 0;
  overflow: hidden;
  background: transparent;
}

body {
  user-select: none;
  pointer-events: none;
}

#game-hud {
  display: block;
  width: 100%;
  height: 100%;
  background: transparent;
}
```

---

## Canvas Resize Strategy

```ts
export function resizeCanvas(
  canvas: HTMLCanvasElement,
  ctx: CanvasRenderingContext2D,
  cssWidth: number,
  cssHeight: number
): number {
  const reportedDpr = window.devicePixelRatio || 1;
  const dpr = Math.min(reportedDpr, 2);

  canvas.style.width = `${cssWidth}px`;
  canvas.style.height = `${cssHeight}px`;

  canvas.width = Math.round(cssWidth * dpr);
  canvas.height = Math.round(cssHeight * dpr);

  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

  return dpr;
}
```

### WebCore compatibility requirement

Verify how WebCore maps CSS pixels to the render surface.

If WebCore already renders one CSS pixel per physical target pixel, a higher device pixel ratio may waste memory. Add a setting or platform override if needed.

---

# Anchor Helper

Implement one reusable transform helper.

```ts
export interface AnchorTransform {
  horizontal: HorizontalAnchor;
  vertical: VerticalAnchor;
  offsetX?: number;
  offsetY?: number;
  scale?: number;
}

export function beginAnchoredDraw(
  ctx: CanvasRenderingContext2D,
  viewportWidth: number,
  viewportHeight: number,
  transform: AnchorTransform
): void {
  let anchorX = 0;
  let anchorY = 0;

  switch (transform.horizontal) {
    case "left":
      anchorX = 0;
      break;

    case "center":
      anchorX = viewportWidth / 2;
      break;

    case "right":
      anchorX = viewportWidth;
      break;
  }

  switch (transform.vertical) {
    case "top":
      anchorY = 0;
      break;

    case "center":
      anchorY = viewportHeight / 2;
      break;

    case "bottom":
      anchorY = viewportHeight;
      break;
  }

  const scale = transform.scale ?? 1;

  ctx.save();
  ctx.translate(
    anchorX + (transform.offsetX ?? 0) * scale,
    anchorY + (transform.offsetY ?? 0) * scale
  );
  ctx.scale(scale, scale);
}
```

Every use must be paired with:

```ts
ctx.restore();
```

---

# Asset Strategy

## Export as image assets

Export the following from Figma rather than manually reconstructing them:

- Decorative circular ring
- Timer frame
- Crosshair star
- Ability pip
- EX indicator
- Health icons
- Character or class icon
- Large white resource decoration
- Complex resource meter frame
- Cooldown glyphs
- Any irregular masked or boolean-operation artwork

## Draw dynamically

Use Canvas drawing for:

- Timer text
- Player scores
- Player names
- Gauge segments
- Resource fill
- Ammo count
- Ability charge state
- Reload timer
- Speed
- Cooldown values
- Team-color fills
- Visibility and opacity states

## Asset formats

Preferred order:

1. SVG where WebCore decodes and renders it correctly.
2. Transparent PNG at 2× resolution for smooth scalable art.
3. Native-resolution PNG for pixel-art assets.
4. Alpha-mask images for dynamically tinted shapes.

Do not depend on Figma MCP URLs in committed code. Those URLs expire. Download and store the real exported files in the project.

---

# Static Caching Strategy

Use ordinary hidden canvas elements as caches.

Do not require `OffscreenCanvas` until WebCore support has been verified.

Suggested caches:

```ts
export interface HudCaches {
  matchHeaderFrame: HTMLCanvasElement;
  resourcePanelFrame: HTMLCanvasElement;
  telemetryIcons: HTMLCanvasElement;
  coloredPlayerOneNameplate: HTMLCanvasElement;
  coloredPlayerTwoNameplate: HTMLCanvasElement;
  maskedResourceFill: HTMLCanvasElement;
}
```

Rebuild caches only when their dependencies change.

Examples:

- Team-colored nameplate cache:
  - Rebuild when team color changes.
- Resource fill mask cache:
  - Rebuild when fill value changes.
- Static frame cache:
  - Build once after assets load.
- Telemetry icon cache:
  - Build once unless icon loadout changes.

---

# Renderer Responsibilities

## `drawDecorativeRing`

Responsibilities:

- Draw the large ring centered on the viewport.
- Scale using logical viewport height.
- Preserve circular aspect ratio.
- Apply configured opacity.
- Avoid horizontal stretching.
- Allow the ring to be disabled.

Initial behavior:

```ts
ctx.save();
ctx.translate(viewportWidth / 2, viewportHeight / 2);
ctx.scale(finalScale, finalScale);
ctx.globalAlpha = HUD_LAYOUT.ring.opacity;

ctx.drawImage(
  assets.hudRing,
  -HUD_LAYOUT.ring.width / 2,
  -HUD_LAYOUT.ring.height / 2,
  HUD_LAYOUT.ring.width,
  HUD_LAYOUT.ring.height
);

ctx.restore();
```

---

## `drawMatchHeader`

Responsibilities:

- Draw the static timer frame.
- Draw left and right player nameplates.
- Draw team colors.
- Draw scores.
- Draw player names.
- Draw timer.
- Draw mini Drive or EX gauges.
- Handle disconnected players.
- Handle double-digit scores.
- Handle long names.

### Timer formatting

```ts
export function formatMatchTime(seconds: number): string {
  const safeSeconds = Math.max(0, Math.floor(seconds));
  const minutes = Math.floor(safeSeconds / 60);
  const remainder = safeSeconds % 60;

  return `${minutes}:${remainder.toString().padStart(2, "0")}`;
}
```

### Name behavior

- Use the intended condensed font.
- Fit within the allocated width.
- Prefer truncation with an ellipsis over shrinking below legibility.
- Support right alignment for Player 2.

### Score behavior

- Verify score layout with `0`, `8`, `10`, `88`, and `99`.
- Use fixed score anchors rather than relying on text width alone.

---

## `drawCenterStatus`

Responsibilities:

- Draw ammo.
- Draw ability pips.
- Draw the correct health state.
- Draw reload time.
- Keep the center readout separate from the crosshair.
- Allow the entire center status group to be disabled.

### Health states

```ts
switch (state.healthVisualState) {
  case "normal":
    drawNormalHealthIcon();
    break;

  case "low":
    drawLowHealthIcon();
    break;

  case "dead":
    drawDeadHealthIcon();
    break;
}
```

The three Figma health graphics must not be permanently overlaid.

### Ability charges

Use one reusable pip renderer.

```ts
const CENTER_CHARGE_POSITIONS = [
  [137, 224],
  [132, 243],
  [151, 236]
] as const;
```

Refine positions during visual validation.

### Reload display

- Display one decimal place when active.
- Hide or show `0.0` based on the desired final behavior.
- Avoid layout changes when the string width changes.

---

## `drawCrosshair`

Responsibilities:

- Draw the star at exact screen center.
- Support crosshair scale independently from HUD scale.
- Support opacity settings.
- Support visibility settings.
- Optionally snap to integer pixels.

Suggested scale:

```ts
const crosshairScale =
  (viewportHeight / DESIGN_HEIGHT) *
  settings.crosshairScale;
```

A later option may keep the crosshair at a constant CSS size rather than scaling with resolution.

---

## `drawResourcePanel`

Responsibilities:

- Combine Figma nodes `116:733` and `116:313` into one logical renderer.
- Draw the class or character icon.
- Draw the resource frame.
- Draw resource fill.
- Draw the large count.
- Draw EX or Drive label.
- Draw `MAX` state.
- Draw character-specific artwork.
- Position relative to the bottom-left safe area.

### Fill logic

Do not export separate assets for every fill amount.

Use either:

- Rectangular clipping for a simple horizontal fill.
- Alpha-mask compositing for an irregular meter.

Simple clipping example:

```ts
export function drawHorizontalMeter(
  ctx: CanvasRenderingContext2D,
  fillImage: CanvasImageSource,
  x: number,
  y: number,
  width: number,
  height: number,
  ratio: number
): void {
  const clamped = Math.max(0, Math.min(1, ratio));

  ctx.save();
  ctx.beginPath();
  ctx.rect(x, y, width * clamped, height);
  ctx.clip();

  ctx.drawImage(fillImage, x, y, width, height);
  ctx.restore();
}
```

### Irregular fill behavior

For the triangular yellow meter:

1. Draw the full yellow meter artwork into a cache canvas.
2. Clip the cache horizontally based on resource ratio.
3. Apply the meter alpha mask with `destination-in`.
4. Draw the result to the main canvas.
5. Rebuild only when the resource ratio changes.

---

## `drawTelemetry`

Responsibilities:

- Draw the speedometer.
- Draw three cooldown icons.
- Draw cooldown values.
- Show readiness.
- Handle missing or disabled cooldown entries.
- Avoid rebuilding icon art every frame.

### Speed format

```ts
const speedText = Math.max(0, Math.floor(state.speed))
  .toString()
  .padStart(3, "0");
```

### Cooldown values

Suggested display rules:

```text
Ready                 → blank, icon glow, or "0"
Above 10 seconds      → integer
Between 1 and 10      → one decimal place
Below 1 second        → one decimal place
Unavailable           → "--"
Hidden                → do not draw
```

Exact rules should match the game's design intent.

---

# Text and Font Plan

The Figma design uses:

- Helvetica Neue 97 Black Condensed
- Helvetica Neue 97 Black Condensed Oblique
- Trade Gothic Next LT Pro Bold Condensed
- Iosevka Charon Mono
- 04b09

## Requirements

- Verify game-distribution and web-embedding rights for commercial fonts.
- Load fonts before drawing text.
- Do not allow the first visible frame to use fallback fonts.
- Verify pixel-font behavior at fractional scales.
- Consider a bitmap glyph atlas for `04b09`.

## Font loading

```ts
await Promise.all([
  document.fonts.load('48px "Trade Gothic Next"'),
  document.fonts.load('76px "Helvetica Neue Condensed"'),
  document.fonts.load('20px "Iosevka Charon Mono"'),
  document.fonts.load('16px "04b09"')
]);
```

## Text fitting helper

```ts
export function fitText(
  ctx: CanvasRenderingContext2D,
  value: string,
  maxWidth: number
): string {
  if (ctx.measureText(value).width <= maxWidth) {
    return value;
  }

  let result = value;

  while (
    result.length > 0 &&
    ctx.measureText(`${result}…`).width > maxWidth
  ) {
    result = result.slice(0, -1);
  }

  return `${result}…`;
}
```

---

# Engine Bridge

Expose one narrow API.

```ts
declare global {
  interface Window {
    gameHud: {
      setState(next: Partial<HudState>): void;
      setSettings(next: Partial<HudSettings>): void;
      triggerEvent(name: string, data?: unknown): void;
      resize(width: number, height: number): void;
    };
  }
}
```

## State updates

Use for persistent values:

```ts
window.gameHud.setState({
  ammoCurrent: 5,
  reloadSeconds: 0.6,
  speed: 416
});
```

## Events

Use for one-shot feedback:

```ts
window.gameHud.triggerEvent("damageTaken", {
  direction: 0.35,
  amount: 1
});

window.gameHud.triggerEvent("resourceMaxed");

window.gameHud.triggerEvent("cooldownReady", {
  id: "deblur"
});
```

Do not encode short-lived effects as permanent state flags unless the engine owns their full lifetime.

---

# Rendering Loop

## Dirty rendering

The HUD should redraw when:

- State changes.
- Settings change.
- Viewport size changes.
- An animation is active.
- Assets finish loading.
- Fonts finish loading.

```ts
export class HudRenderer {
  private dirty = true;
  private animationActive = false;

  public invalidate(): void {
    this.dirty = true;
  }

  public frame(timeMs: number): void {
    if (this.dirty || this.animationActive) {
      this.render(timeMs);
      this.dirty = false;
    }

    requestAnimationFrame((nextTime) => {
      this.frame(nextTime);
    });
  }
}
```

Continuous 60 Hz redraw is acceptable initially if the HUD remains inexpensive. Add dirty rendering once the first accurate version works.

---

# Main Renderer Skeleton

```ts
export class HudRenderer {
  private readonly canvas: HTMLCanvasElement;
  private readonly ctx: CanvasRenderingContext2D;

  private state: HudState;
  private settings: HudSettings;
  private assets: HudAssets;
  private caches: HudCaches;

  private viewportWidth = 0;
  private viewportHeight = 0;
  private finalScale = 1;

  public constructor(
    canvas: HTMLCanvasElement,
    assets: HudAssets,
    caches: HudCaches,
    initialState: HudState,
    initialSettings: HudSettings
  ) {
    const ctx = canvas.getContext("2d");

    if (!ctx) {
      throw new Error("Canvas 2D is unavailable.");
    }

    this.canvas = canvas;
    this.ctx = ctx;
    this.assets = assets;
    this.caches = caches;
    this.state = initialState;
    this.settings = initialSettings;
  }

  public resize(width: number, height: number): void {
    this.viewportWidth = width;
    this.viewportHeight = height;

    this.finalScale =
      (height / DESIGN_HEIGHT) *
      this.settings.hudScale;

    resizeCanvas(this.canvas, this.ctx, width, height);
  }

  public setState(next: Partial<HudState>): void {
    this.state = {
      ...this.state,
      ...next
    };
  }

  public setSettings(next: Partial<HudSettings>): void {
    this.settings = {
      ...this.settings,
      ...next
    };

    this.finalScale =
      (this.viewportHeight / DESIGN_HEIGHT) *
      this.settings.hudScale;
  }

  public render(timeMs: number): void {
    const ctx = this.ctx;

    ctx.clearRect(
      0,
      0,
      this.viewportWidth,
      this.viewportHeight
    );

    if (!this.state.visible) {
      return;
    }

    if (this.settings.showDecorativeRing) {
      drawDecorativeRing({
        ctx,
        assets: this.assets,
        layout: HUD_LAYOUT.ring,
        viewportWidth: this.viewportWidth,
        viewportHeight: this.viewportHeight,
        scale: this.finalScale
      });
    }

    drawMatchHeader({
      ctx,
      assets: this.assets,
      caches: this.caches,
      state: this.state,
      layout: HUD_LAYOUT.matchHeader,
      viewportWidth: this.viewportWidth,
      viewportHeight: this.viewportHeight,
      scale: this.finalScale
    });

    drawResourcePanel({
      ctx,
      assets: this.assets,
      caches: this.caches,
      state: this.state,
      settings: this.settings,
      layout: HUD_LAYOUT.resourcePanel,
      viewportWidth: this.viewportWidth,
      viewportHeight: this.viewportHeight,
      scale: this.finalScale,
      timeMs
    });

    if (this.settings.showTelemetry) {
      drawTelemetry({
        ctx,
        assets: this.assets,
        caches: this.caches,
        state: this.state,
        layout: HUD_LAYOUT.telemetry,
        viewportWidth: this.viewportWidth,
        viewportHeight: this.viewportHeight,
        scale: this.finalScale,
        timeMs
      });
    }

    if (this.settings.showCenterStatus) {
      drawCenterStatus({
        ctx,
        assets: this.assets,
        state: this.state,
        layout: HUD_LAYOUT.centerStatus,
        viewportWidth: this.viewportWidth,
        viewportHeight: this.viewportHeight,
        scale: this.finalScale,
        timeMs
      });
    }

    if (this.settings.showCrosshair) {
      drawCrosshair({
        ctx,
        assets: this.assets,
        settings: this.settings,
        layout: HUD_LAYOUT.crosshair,
        viewportWidth: this.viewportWidth,
        viewportHeight: this.viewportHeight
      });
    }
  }
}
```

---

# Implementation Phases

## Phase 0 — Repository Inspection

- [ ] Identify the existing WebCore HUD entry point.
- [ ] Identify whether the project uses TypeScript or JavaScript.
- [ ] Identify existing asset-loading utilities.
- [ ] Identify existing FTEQW-to-JavaScript bridge code.
- [ ] Identify how WebCore receives resize events.
- [ ] Identify the current transparent-compositing setup.
- [ ] Identify the build system.
- [ ] Identify font-loading conventions.
- [ ] Avoid adding new dependencies unless required.

### Deliverable

A short implementation note documenting the existing project conventions that this HUD must follow.

---

## Phase 1 — Canvas Foundation

- [ ] Add a full-screen transparent canvas.
- [ ] Disable scrolling, pointer events, and selection.
- [ ] Implement canvas resize handling.
- [ ] Implement the 1080-height logical scale.
- [ ] Implement safe-area settings.
- [ ] Implement the anchor helper.
- [ ] Implement state and settings containers.
- [ ] Render temporary debug rectangles for every top-level HUD cluster.

### Debug view

Each cluster should render a labeled translucent rectangle showing:

- Anchor point
- Local bounds
- Final position
- Final scale

### Acceptance criteria

- [ ] Debug bounds are correct at 1440 × 1080.
- [ ] Debug bounds are correct at 1920 × 1080.
- [ ] Debug bounds remain stable at 3440 × 1440.
- [ ] No component is horizontally stretched.
- [ ] The crosshair debug marker stays exactly centered.

---

## Phase 2 — Asset Pipeline

- [ ] Export the visible production assets from Figma.
- [ ] Store all assets locally.
- [ ] Create a typed asset manifest.
- [ ] Add loading and error handling.
- [ ] Add a visible development fallback for missing assets.
- [ ] Verify SVG support in WebCore.
- [ ] Select SVG or PNG fallback per asset.
- [ ] Verify alpha and transparency behavior.
- [ ] Verify color accuracy.

### Required initial assets

- [ ] HUD ring
- [ ] Timer frame
- [ ] Crosshair star
- [ ] Ability pip
- [ ] EX indicator
- [ ] Normal HP icon
- [ ] Low HP icon
- [ ] Dead HP icon
- [ ] Resource panel frame art
- [ ] Resource fill art or mask
- [ ] Character/class icon
- [ ] Cooldown glyphs

### Acceptance criteria

- [ ] No committed source references temporary Figma asset URLs.
- [ ] Every missing asset produces a useful error.
- [ ] Assets render with correct alpha in WebCore.

---

## Phase 3 — Decorative Ring

- [ ] Draw the ring at viewport center.
- [ ] Preserve circular aspect ratio.
- [ ] Apply opacity.
- [ ] Add visibility setting.
- [ ] Confirm clipping behavior at small resolutions.
- [ ] Confirm behavior on ultrawide screens.

### Acceptance criteria

- [ ] The ring is circular at all tested aspect ratios.
- [ ] The ring's apparent size tracks viewport height.
- [ ] The ring never stretches horizontally.
- [ ] The ring can be disabled without affecting other elements.

---

## Phase 4 — Match Header

- [ ] Build the static header cache.
- [ ] Draw timer frame.
- [ ] Draw scores.
- [ ] Draw timer text.
- [ ] Draw player names.
- [ ] Add team-colored nameplate caches.
- [ ] Draw mini Drive gauge.
- [ ] Draw mini EX pips.
- [ ] Add long-name truncation.
- [ ] Add disconnected-player state.
- [ ] Validate double-digit scores.

### Test values

```text
Names:
- A
- Player1
- VeryLongPlayerName
- Unicode test name

Scores:
- 0
- 5
- 9
- 10
- 88
- 99

Timers:
- 0:00
- 0:09
- 9:59
- 10:00
- 99:59
```

### Acceptance criteria

- [ ] Header remains centered at all aspect ratios.
- [ ] Player names stay within nameplate bounds.
- [ ] Scores do not overlap the timer.
- [ ] Timer remains visually centered.
- [ ] Drive and EX mini gauges use the correct visual form.

---

## Phase 5 — Crosshair

- [ ] Draw crosshair at exact viewport center.
- [ ] Add crosshair scale setting.
- [ ] Add crosshair opacity setting.
- [ ] Add visibility setting.
- [ ] Add optional integer pixel snapping.
- [ ] Verify center alignment at odd and even resolutions.

### Acceptance criteria

- [ ] Crosshair center matches viewport center within one physical pixel.
- [ ] Crosshair can scale independently from the rest of the HUD.
- [ ] Crosshair can be hidden independently.

---

## Phase 6 — Center Status

- [ ] Draw ammo values.
- [ ] Draw ability charge pips.
- [ ] Draw reload timer.
- [ ] Implement normal, low, and dead health states.
- [ ] Add optional low-health pulse.
- [ ] Prevent health-state assets from overlaying incorrectly.
- [ ] Keep the component separate from the crosshair.

### Test values

```text
Ammo:
- 0 / 0
- 0 / 6
- 1 / 6
- 6 / 6
- 99 / 99

Charges:
- 0
- 1
- 2
- 3

Reload:
- hidden
- 0.0
- 0.1
- 0.6
- 4.0
```

### Acceptance criteria

- [ ] All health states are mutually exclusive.
- [ ] Ammo text remains aligned as values change.
- [ ] Ability pips clearly distinguish filled and empty states.
- [ ] Center status can be disabled without hiding the crosshair.

---

## Phase 7 — Resource Panel

- [ ] Combine the split Figma groups into one renderer.
- [ ] Build static resource-panel cache.
- [ ] Draw class/character icon.
- [ ] Draw resource meter frame.
- [ ] Implement dynamic fill.
- [ ] Draw resource count.
- [ ] Draw resource type label.
- [ ] Draw `MAX` state.
- [ ] Add safe-area positioning.
- [ ] Support EX and Drive variants.
- [ ] Verify fill direction and clipping.
- [ ] Verify visibility at 720p.

### Test values

```text
Resource:
- 0%
- 1%
- 25%
- 50%
- 75%
- 99%
- 100%

Count:
- 0
- 1
- 3
- 9
- 10

States:
- EX
- Drive
- MAX
- not MAX
```

### Acceptance criteria

- [ ] Panel moves as one component.
- [ ] Panel remains anchored to the bottom-left safe area.
- [ ] The meter fill does not spill outside its intended shape.
- [ ] `MAX` appears only in the correct state.
- [ ] Resource count remains visually aligned with two digits.

---

## Phase 8 — Telemetry and Cooldowns

- [ ] Draw speedometer.
- [ ] Draw cooldown glyphs.
- [ ] Draw cooldown values.
- [ ] Add ready state.
- [ ] Add disabled state.
- [ ] Add hidden state.
- [ ] Build icon cache.
- [ ] Define formatting behavior.
- [ ] Confirm bottom-center anchor.

### Acceptance criteria

- [ ] Telemetry remains centered on wide displays.
- [ ] Cooldown values update without visible jitter.
- [ ] Ready, active, disabled, and hidden states are distinct.
- [ ] Telemetry can be disabled independently.

---

## Phase 9 — Engine Integration

- [ ] Implement `window.gameHud`.
- [ ] Connect FTEQW state values.
- [ ] Connect viewport resize.
- [ ] Connect player data.
- [ ] Connect scores and timer.
- [ ] Connect health and ammo.
- [ ] Connect resource state.
- [ ] Connect cooldowns.
- [ ] Connect speed.
- [ ] Add validation for malformed engine data.
- [ ] Add defaults for missing fields.
- [ ] Avoid allocating new large objects every frame if the bridge updates continuously.

### Acceptance criteria

- [ ] HUD can be fully driven from engine state.
- [ ] Missing fields do not crash the renderer.
- [ ] Invalid numeric values are clamped or rejected safely.
- [ ] Rapid updates do not create visible lag or garbage-collection spikes.

---

## Phase 10 — Static Visual Matching

- [ ] Capture the Figma reference at 1440 × 1080.
- [ ] Capture the WebCore output at 1440 × 1080.
- [ ] Overlay images at 50% opacity.
- [ ] Correct major bounding-box differences.
- [ ] Correct font size and baseline differences.
- [ ] Correct icon scale.
- [ ] Correct opacity.
- [ ] Correct local offsets.
- [ ] Correct stroke or border widths.
- [ ] Repeat until major clusters align.

### Comparison order

1. Top match header
2. Crosshair
3. Center status
4. Resource panel
5. Telemetry
6. Decorative ring

### Acceptance criteria

- [ ] No major component differs by more than four logical pixels.
- [ ] Text baselines visually match.
- [ ] Asset scale and opacity are consistent with the reference.
- [ ] Differences that are intentional are documented.

---

## Phase 11 — Responsive Validation

Test all of these:

```text
1440 × 1080
1920 × 1080
1280 × 720
1600 × 900
2560 × 1440
3440 × 1440
3840 × 2160
```

- [ ] Test HUD scale at 75%.
- [ ] Test HUD scale at 100%.
- [ ] Test HUD scale at 125%.
- [ ] Test nonzero safe areas.
- [ ] Test very long names.
- [ ] Test double-digit values.
- [ ] Test all hidden/visible settings.
- [ ] Test pixel snapping.
- [ ] Test with the decorative ring disabled.

### Acceptance criteria

- [ ] No HUD cluster overlaps another unexpectedly.
- [ ] No element stretches nonuniformly.
- [ ] Text remains legible at 720p.
- [ ] Bottom-left and bottom-center clusters remain in safe areas.
- [ ] Crosshair remains centered.
- [ ] Header remains top-center.
- [ ] Ultrawide adds lateral space rather than stretching the HUD.

---

## Phase 12 — Animation and Feedback

Only begin after the static layout matches.

Suggested effects:

- [ ] Low-health pulse
- [ ] Damage flash
- [ ] Ammo expenditure tick
- [ ] Meter gain tween
- [ ] Meter loss trailing value
- [ ] Resource-max flash
- [ ] Cooldown-ready flash
- [ ] Reload-complete response
- [ ] Score-change animation
- [ ] Timer warning state

### Animation constraints

- Prefer opacity, scale, and simple drawing interpolation.
- Avoid expensive Canvas filters during gameplay.
- Avoid recreating large caches every animation frame.
- Keep one-shot events separate from persistent state.
- Make animation durations configurable.
- Ensure animations do not shift core HUD layout.

---

## Phase 13 — Optimization

- [ ] Profile Canvas render time.
- [ ] Profile asset decode and loading.
- [ ] Profile cache rebuilding.
- [ ] Avoid temporary arrays in hot paths.
- [ ] Avoid repeated font-string construction.
- [ ] Avoid repeated gradient creation.
- [ ] Avoid repeated text measurement for unchanged strings.
- [ ] Add dirty flags to individual caches.
- [ ] Add full dirty rendering if useful.
- [ ] Verify no WebCore memory growth over extended play.

### Performance targets

- HUD draw time should remain comfortably below the game's frame budget.
- Static frames should require minimal work.
- Frequently updating numbers should not rebuild decorative caches.
- The bridge should avoid excessive serialization overhead.

---

# Compatibility Risks

## Canvas and WebCore

Verify:

- `document.fonts`
- SVG image decoding
- `globalCompositeOperation`
- `destination-in`
- `requestAnimationFrame`
- device pixel ratio behavior
- transparent canvas compositing
- image smoothing control
- font rendering consistency
- Unicode text behavior

## Masking

The Figma cooldown indicators use mask-like compositions. Prefer pre-exported icon art plus dynamic text over reproducing complex Figma mask operations literally.

## Blend modes

The Figma nameplate uses a gradient plus a color blend layer. Prefer alpha-mask recoloring into a cache instead of relying on exact browser blend-mode equivalence.

## Pixel fonts

The `04b09` font may blur at fractional scale. Evaluate:

- Native Canvas text
- Integer-scale rendering
- Bitmap glyph atlas
- Pixel-snapped placement

## Commercial fonts

Verify licensing before bundling Helvetica Neue or Trade Gothic. Substitute only after testing metrics and visual impact.

---

# Error Handling Requirements

- Asset load failures must identify the missing path.
- Canvas context acquisition failure must throw a clear startup error.
- State setters must reject or normalize `NaN` and infinite values.
- Ratios must be clamped to `[0, 1]`.
- Negative timers must clamp to zero.
- Missing players must render a defined disconnected state.
- Unknown gauge types must fall back safely.
- Unknown cooldown IDs must not crash telemetry rendering.

Example helper:

```ts
export function clamp01(value: number): number {
  if (!Number.isFinite(value)) {
    return 0;
  }

  return Math.max(0, Math.min(1, value));
}
```

---

# Testing Plan

## Unit tests

Test pure helpers:

- [ ] `formatMatchTime`
- [ ] `fitText`
- [ ] `clamp01`
- [ ] anchor calculations
- [ ] resource-ratio calculation
- [ ] cooldown formatting
- [ ] health-state selection
- [ ] score formatting
- [ ] safe-area positioning

## Visual tests

Capture deterministic HUD states:

- [ ] Default
- [ ] Full resource
- [ ] Empty resource
- [ ] Low health
- [ ] Dead
- [ ] Zero ammo
- [ ] Full ability charges
- [ ] All cooldowns active
- [ ] All cooldowns ready
- [ ] Long player names
- [ ] Double-digit scores
- [ ] Ultrawide
- [ ] 720p

## Integration tests

- [ ] Engine can initialize HUD.
- [ ] Engine can update one value.
- [ ] Engine can update full state.
- [ ] Engine can trigger an event.
- [ ] Resize is handled.
- [ ] HUD can hide and show.
- [ ] Reloading WebCore does not leave stale engine state.

---

# Definition of Done

The Canvas HUD adaptation is complete when:

- [ ] It runs in the existing WebCore HUD environment.
- [ ] It uses locally stored production assets.
- [ ] It visually matches the inspected Figma layout at 1440 × 1080.
- [ ] It adapts correctly to 1920 × 1080 without stretching.
- [ ] It works at 1280 × 720.
- [ ] It works at 3440 × 1440.
- [ ] The crosshair stays centered.
- [ ] The header stays top-center.
- [ ] The resource panel stays bottom-left.
- [ ] Telemetry stays bottom-center.
- [ ] Dynamic game state updates correctly.
- [ ] Health states are mutually exclusive.
- [ ] EX and Drive variants are supported.
- [ ] Long names and double-digit values are handled.
- [ ] Fonts load before the first visible frame.
- [ ] No temporary Figma URLs remain.
- [ ] No unnecessary framework or dependency is introduced.
- [ ] The renderer performs reliably during extended gameplay.
- [ ] Intentional deviations from the Figma source are documented.

---

# Cursor Execution Instructions

When implementing this plan:

1. Inspect the current repository before writing code.
2. Follow existing language, naming, build, and directory conventions.
3. Do not introduce React or Tailwind.
4. Do not install dependencies without a demonstrated need.
5. Implement one phase at a time.
6. Keep each renderer responsible for one HUD cluster.
7. Keep all root placement in `HudLayout`.
8. Keep dynamic data in `HudState`.
9. Keep user options in `HudSettings`.
10. Keep FTEQW integration isolated in `EngineBridge`.
11. Prefer exported artwork for complex Figma shapes.
12. Prefer Canvas drawing for changing text and fill values.
13. Add development debug bounds before fine visual work.
14. Validate each phase at both 1440 × 1080 and 1920 × 1080.
15. Do not begin animation work until the static HUD matches.
16. Summarize changed files and unresolved issues after every phase.
17. Stop and report compatibility problems rather than silently replacing behavior.

---

# Recommended First Cursor Task

```text
Inspect the existing WebCore HUD project and implement Phase 1 of
FTEQW WebCore Canvas HUD — Implementation Plan.

Requirements:
- Reuse the current project structure and build system.
- Create one transparent full-screen Canvas 2D HUD surface.
- Implement viewport resize handling.
- Use a canonical logical height of 1080.
- Implement semantic left/center/right and top/center/bottom anchors.
- Add layout definitions for the ring, match header, center status,
  crosshair, bottom-left resource panel, and bottom-center telemetry.
- Draw labeled debug rectangles for all six clusters.
- Do not add final assets yet.
- Do not add React, Tailwind, or external dependencies.
- Test the layout at 1440×1080, 1920×1080, and 3440×1440.
- At completion, report all files changed, the resulting coordinate
  behavior, and any WebCore compatibility issues found.
```

---

# Recommended Second Cursor Task

```text
Implement Phase 2 and Phase 3 of the FTEQW WebCore Canvas HUD plan.

Requirements:
- Add a typed local asset loader with useful error messages.
- Do not reference temporary Figma MCP asset URLs.
- Load and render the decorative HUD ring.
- Keep the ring circular.
- Scale the ring according to viewport height.
- Center it on all aspect ratios.
- Apply configurable opacity.
- Add a setting to hide it.
- Preserve all existing Phase 1 debug tools behind a development flag.
- Test at 1440×1080, 1920×1080, 1280×720, and 3440×1440.
- Report changed files, asset format choices, and compatibility results.
```

---

# Recommended Third Cursor Task

```text
Implement the top match header from Figma node 116:394 as the first
complete Canvas HUD component.

Requirements:
- Use the existing Canvas HUD foundation and anchor system.
- Keep the header anchored top-center.
- Render the exported timer frame asset.
- Draw left and right scores.
- Draw the formatted match timer.
- Draw left and right player names.
- Add team-colored nameplate caches using alpha masks or exported
  recolorable assets.
- Support Drive mini segments and EX mini pips.
- Handle long names with ellipsis.
- Validate scores from 0 through 99.
- Validate timers from 0:00 through 99:59.
- Do not implement other HUD clusters in this task.
- Compare output against the 1440×1080 Figma reference and document
  remaining visual differences.
```
