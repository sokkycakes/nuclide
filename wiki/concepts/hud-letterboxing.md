---
title: HUD Letterboxing
created: 2026-07-17
updated: 2026-07-17
type: concept
tags: [hud, rmlui, preferences]
sources: [raw/articles/agents-md.md]
confidence: high
---

# HUD Letterboxing

When porting Stiletto/Godot HUD layouts into QC or RmlUI, place widgets that should track the safe HUD area in:

- `screen.HUDMins` / `screen.HUDSize`

Not always the full viewport `screen.Mins` / `screen.Size`.

See `base/src/hud/hud.qc`. RmlUI HUD is laid out in a **4:3** logical box; `#hurt-overlay` covers full viewport.

## Related

- [[godot-prototype]]
- [[webcore-ui]]
- [[user-preferences]]
