---
title: WebCore
created: 2026-07-17
updated: 2026-07-17
type: entity
tags: [webcore, menu, hud, engine]
sources: [raw/articles/agents-md.md]
confidence: high
---

# WebCore

In-process HTML/CSS UI path preferred over UltralightCore and heavy CEF multiprocess.

## Runtime pieces

- FTE plugin: `webcore`
- Host DLL: `ftewebcore.dll`
- Host build tree often: `workspace/webcore-fte` (MSVC dir `C:\w\wc-fte`)

## Content roots (under nuclide `base/`)

| Surface | Path |
|---------|------|
| Default fullscreen menu | `base/data/web/title-menu/` (`webcore_menu_url` → `fte://data/web/title-menu/index.html`) |
| Lobby menu | `base/data/web/lobby-menu/` |
| In-game HUD | `base/data/web/hud/` |
| H3 mockup | `base/data/web/h3-main-menu/` |
| Smoke pages | `base/data/web/webcore-test/` |

Slint sources being ported live under engine `engine/ui/` (`title_menu.slint`, `hud.slint`).

## Related

- [[webcore-ui]] — layout / behavior conventions
- [[webcore-vs-cef-slint]] — stack choice
- [[fteqw-workspace]] — engine integration
- [[lobby-session]] — Create/Join Lobby UX
