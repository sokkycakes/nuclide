---
title: WebCore vs CEF vs Slint
created: 2026-07-17
updated: 2026-07-17
type: comparison
tags: [webcore, cef, slint, comparison, preferences]
sources: [raw/articles/agents-md.md]
confidence: high
---

# WebCore vs CEF vs Slint

| Option | Role today | Preference |
|--------|------------|------------|
| **WebCore** | In-process HTML/CSS menus + HUD | **Preferred** for menus and HUD |
| **CEF** | Multiprocess plugin path still present | Avoid as primary UI; heavier |
| **Slint** | Prior menu/HUD (`engine/ui/*.slint`) | Being ported away; keep parity behavior |

Goal: fullscreen `menu_t`, auto plugin load, in-game HUD — not UltralightCore.

## Related

- [[webcore]]
- [[webcore-ui]]
- [[user-preferences]]
