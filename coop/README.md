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
  for `coop_reviveTime` seconds. Bots walk to downed teammates within
  `coop_botReviveRange` and revive them by standing there, and respawn on
  their own once the delay is over.
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
- `callvote skill 1|2|3` changes the skill for monsters spawned after the
  vote passes (`mp_allowvote 1`).
- Server commands: `sv coop_status`, `sv coop_nextwave`, `sv coop_killmonsters`.
  `coop_statusInterval N` prints the status every N seconds. For tests,
  `sv coop_botvote skill 3` has a bot call a vote and
  `sv coop_botvoteyes [skipfirst]` has the bots vote yes.
- Teammates and friendly NPCs get a name and health bar overhead (the
  rules set serverinfo `nameplates 1`). The drawing is shared client code in
  `src/client/nameplates.qc`; `cg_nameplates 0|1` overrides it per player and
  `cg_nameplatesRange` sets the distance (1000).

## Tested on Bulwark

With Half-Life's assets: zombies and headcrabs hit players, players go
down and get revived, survival mode restarts the map after a wipe, and a
skill vote passes and applies. 32 bots against 40 monsters run faster than
real time on one core. At that size the 4x health cap makes waves slow to
clear with starting weapons; `coop_healthPerPlayer` is the knob.

## Weapon test

`coop_weapontest 1` has the first bot try every Half-Life weapon against a
pinned 50000 hp zombie, primary then secondary fire, and prints the damage
each one did. `coop_weapontestList crowbar,gauss` limits it to some weapons
(comma separated, no spaces). Run it with `coop_waveDelay 9999` and
`bot_pause 1` so nothing else is fighting. The bot's firing comes from the
`bot_forceAttack` developer cvar (1/2 tap primary/secondary, 3/4 hold).
All weapons deal damage except snarks (they don't reach the target yet) and
the chumtoad, which is a decoy.

## Test map

`tools/mkcoopmap.py` writes `maps/coop_arena.bsp` (GoldSrc BSP30, textures
inside) and `data/coop_arena.way` (bot and monster waypoints).
