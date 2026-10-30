# Co-op XP mod: behaviour spec

This describes the gameplay of the SCXPM 17.0 AMX Mod X plugin (Sven Co-op XP Mod), written from reading it in sokky's Downloads. It covers behaviour and numbers only. The co-op mod's version (`coop/src/plugins/xpm.qc`, ISC) is written from this spec and takes no code from the plugin.

## Experience and levels
- Kills (frags) earn XP: each new frag is worth `5 * xpgain` XP. `xpgain` is a server setting, default 1.
- The XP needed to reach the next level from level L is `round(70*L + 3.5*L² + 30)`.
- The level cap is 1800. Each level gained gives 1 skill point and opens the skill menu.
- Rank names come from level bands:
  - 0–4 Frightened Civilian, 5–19 Civilian, 20–49 Fighter, 50–99 Private Third Class
  - 100–199 Private Second Class, 200–299 Private First Class, 300–399 Free Agent, 400–499 Professional Free Agent
  - 500–599 Professional Force Member, 600–699 Professional Force Leader, 700–799 Special Force Member, 800–899 Special Force Leader
  - 900–999 United Forces Member, 1000–1099 United Forces Leader, 1100–1199 Hidden Operations Member, 1200–1299 Hidden Operations Scheduler
  - 1300–1399 Hidden Operations Leader, 1400–1499 General, 1500–1599 Top 30 of most famous Leaders, 1600–1699 Top 15 of most famous Leaders
  - 1700–1799 Highest Force Member, 1800 Highest Force Leader
- Progress is saved per player when they leave and loaded when they join: XP, level, unspent points, medals and every skill level.
- A new player starts with level 0, 30 XP needed and 3 medals. The plugin stores medals off by one, so the stored value is 4.

## Skills (one point per level, with caps)
| # | Skill | Cap | Effect |
|---|---|---|---|
| 1 | Strength | 450 | +1 max/spawn health per level |
| 2 | Superior Armor | 450 | +1 spawn armour per level |
| 3 | Health Regeneration | 300 | +1 HP when a countdown of `300 - level` half-second ticks runs out, plus on each tick a chance of `level+medals+aw/2` in `200+level+medals+aw/2` for +1 HP. Capped at the player's full health. |
| 4 | Nano Armor | 300 | The same as regeneration, for armour |
| 5 | Ammo Reincarnation | 30 | Every `179 - 5*level - aw/18` ticks, ammo for the held weapon. If that ammo is already full, a random ammo type instead. |
| 6 | Anti Gravity | 40 | While jump is held, gravity is `1 - 0.015*level - 0.001*medals` |
| 7 | Awareness ("aw") | 80 | Boosts the other skills. Half of it adds to the health and armour caps. |
| 8 | Team Power | 60 | Teammates within 650 units randomly gain HP and armour, up to their cap + 60 + level. At level 40 and up there's an extra chance each tick. |
| 9 | Block Attack | 90 | On each tick there's a chance of `level+medals+aw/7` in `185+level+medals+aw/7` to be invulnerable until the next tick |

"Full health" means spawn health + Strength + medals + aw/2. On spawn, health is set to base + Strength + medals and armour to base + Superior Armor + medals. One tick is 0.5 s.

## Commands
Each one works in chat (with or without `/`) or the console:
- `selectskills`: the skill menu (keys 1–9 spend a point, 0 closes it)
- `resetskills`: refunds every point
- `playerskills`: every player's level and medals
- `skillsinfo`: what each skill does
- `scxpminfo`: the mod's version and the XP rate

Admin commands: `setlvl <player> <level>`, `addmedal <player>` (up to 15), `removemedal <player>`, `godmode <player>`, `noclipmode <player>`.

## HUD
Top right: XP / needed (+remaining), level / 1800, rank, and medals / 15.

## Co-op changes
- XP also comes from co-op points (monster kills, revives), since co-op scores in points rather than frags. A point is worth one frag.
- Saved data is keyed by the player's GUID, or by name if there isn't one, and stored under `data/xpm/`.
- The menu uses a server-driven text menu that's new in Nuclide's client.
