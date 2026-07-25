---
title: WebCore UI
created: 2026-07-17
updated: 2026-07-17
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

## Related

- [[webcore]]
- [[lobby-session]]
- [[hud-letterboxing]]
- [[webcore-vs-cef-slint]]
