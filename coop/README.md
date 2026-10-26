# Co-op

A Sven Co-op style mod: Half-Life co-op for many players against waves of
monsters. It runs on Bulwark and layers on Rad-Therapy (`valve/`), so it
only adds game rules, decls, config and a test map.

## Running

Build the rules progs (and Rad-Therapy, which it depends on):

    make game GAME=coop

Half-Life's own models and sounds are needed; they aren't in the repo. Put
the game's `valve/models` and `valve/sound` in a game dir (say `hldata/`)
next to `valve/` and `coop/`, then:

    bulwark -game hldata -game valve -game coop +exec default_coop.cfg +map coop_arena

Headless test with bots (prints the wave and scores every 10 seconds):

    COOP_HLDATA=hldata coop/tests/run.sh path/to/bulwark-ded 8 120

## What the rules do (`src/rules/coop.qc`)

- One player team. With `sv_friendlyFire 0` players can't hurt each other.
- Dead players respawn after `coop_respawnDelay` seconds. Before that a
  teammate can revive them where they fell by holding USE next to the body
  for `coop_reviveTime` seconds (bots revive just by standing there).
- `coop_survival 1`: no respawning on your own. Clearing a wave brings
  everyone back; if the whole team is down the map restarts.
- Waves spawn at `info_monster_spawn` points (or deathmatch spawns).
  Size is `coop_waveBase + coop_wavePerPlayer * players + coop_wavePerWave * (wave - 1)`,
  with at most `coop_maxMonsters` alive at once. `coop_waveMonsters` lists
  monster tiers separated by `;`; later waves mix in higher tiers.
- Monster health scales by `1 + coop_healthPerPlayer * (players - 1)`, up to
  `coop_healthScaleMax`.
- Score is points: a monster kill is worth a tenth of its health, a revive
  `coop_revivePoints`, killing an ally costs `coop_allyKillPenalty`.
- Server commands: `sv coop_status`, `sv coop_nextwave`, `sv coop_killmonsters`.

## Test map

`tools/mkcoopmap.py` writes `maps/coop_arena.bsp` (GoldSrc BSP30, textures
inside) and `data/coop_arena.way` (bot and monster waypoints).
