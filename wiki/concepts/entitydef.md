---
title: EntityDef
created: 2026-07-17
updated: 2026-07-24
type: concept
tags: [entitydef, progs]
sources: [raw/articles/agents-md.md]
confidence: high
---

# EntityDef

`.def` files load at **runtime** — no recompilation for def changes; restart the game.

- `GetDefString()` walks parent entityDef inheritance
- Melee: `ncWeaponBaseMelee` + `weapon_melee_base.def`; swing sound key is `snd_swing` (not hit/miss)
- `snd_failed` is dead — engine reads `snd_fireFailed` from sub-defs
- Avoid empty `""` values as “clear this key” — tokenization can desync pairs, and empty `act_*` falls through to `activities.decl` / `frameforaction` (bad for IQM). Omit the key or use a real sentinel.

`+game base` runs Nuclide progs (entityDef, ncMonster, MapC/RuleC), not retail/LibreQuake.

## Related

- [[nuclide]]
- [[rebuild-flow]]
- [[player-iqm-animation]]
- [[user-preferences]]
