---
title: WebCore UI
created: 2026-07-17
updated: 2026-09-12
type: concept
tags: [webcore, menu, hud, preferences]
sources: [raw/articles/agents-md.md]
confidence: high
---

# WebCore UI

## Layout

- Keep content **centered / letterboxed**
- Mock white backgrounds mean **transparent**
- Title-menu music is **engine-side** (not WebCore audio): playlist `music/menu_boot` then `music/menu1`, `music/menu2`, … looping back to `menu_boot`; advance even when classic Quake menus are on top

## Behavior (Slint parity)

- Pause **Leave game** / **Return to game** must close the pause UI
- Console stays usable while WebCore menus are visible

## Title-menu lobby UX

Replace Map Browser / Create Server with **Create Lobby** / **Join Lobby**. Join Lobby lists join methods (room code, address, LAN) — LAN live for now, others grayed. Visuals: basemod foundation (semi-transparent panels, Trade Gothic).

## Figma lobby implementation

`base/data/web/lobby-menu/` implements Figma frame `72:2` as reusable Preact
components. Edit `src/` and `style.css`, then run `npm run build`; `app.js` is
generated output. The runtime bundle is approximately 29 KB, runs in the existing
WebCore process, and requires no Node server. See that directory's `README.md` for
the component map and engine contract.

The 960 × 720 stage scales uniformly and stays centered. Inter is shipped with
its OFL license; Trade Gothic is reused from the HUD. The Windows plugin privately
registers loose TTF files through GDI so WebCore can enumerate them, avoiding
`@font-face`. Keep these fonts loose when packaging.

The engine exposes lobby chat and ruleset/time/frag settings. Host settings stay
authoritative, and selected match settings are applied before map load. Only
listen-server hosting is currently supported. Native DLL interaction checks live
in `Tools/test_webcore_lobby.py`; the three-client LAN/gameplay test is
`Tools/test_lobby_ui_engine.ps1`.

## Related

- [[webcore]]
- [[lobby-session]]
- [[hud-letterboxing]]
- [[webcore-vs-cef-slint]]
