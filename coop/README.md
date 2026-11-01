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

Without `+map` the co-op title menu comes up; its Play page runs
`default_coop.cfg` itself before starting the map.

Headless test with bots (prints the wave and scores every 10 seconds):

    COOP_HLDATA=hldata coop/tests/run.sh path/to/bulwark-ded 8 120

## What the rules do (`src/rules/coop.qc`)

- One player team. With `sv_friendlyFire 0` players can't hurt each other.
- Dead players respawn after `coop_respawnDelay` seconds. Before that a
  teammate can revive them where they fell by holding USE next to the body
  for `coop_reviveTime` seconds. Bots walk to downed teammates within
  `coop_botReviveRange` and revive them by standing there, and respawn on
  their own once the delay is over.
- Survivor bots (`src/rules/survivors.qc`), like Left 4 Dead's: the server
  keeps `coop_survivorBots` (1) bots in while a human plays, using the
  `coop_survivorProfiles` bot profiles in turn. With no one to revive, a
  bot sticks with the nearest human through Nuclide's bot follow mode: it
  keeps within `bot_followDist` (180), just behind and to one side, looks
  where the human looks, shoots the foe nearest the team from where it
  stands, and only leaves with a melee weapon, for a foe within
  `bot_followLeash` (600) of the human. It steps aside when the human walks
  into it. One further than `coop_survivorWarp` (2000) that no human can
  see is moved behind them. Hero bots engage when three
  or more foes are within 512 units. `sv coop_survivors` lists them.
- Nobody stays stuck inside a teammate (`coop_unstick`, on): two living
  players whose boxes overlap can't move, so five times a second they're
  pulled apart, the bot (or else the second player) moving to the nearest
  free spot. Revives also put the revived player beside the reviver rather
  than inside them. `sv coop_survivors stack` puts the bots inside the
  first human, to test it.
- Corpses fade out like gibs: a dead monster lies for `coop_corpseTime`
  (15) seconds, fades over about 3.6 s and goes (wave monsters are
  removed, map monsters with a targetname only hidden). 0 keeps them.
  Players' bodies stay, for reviving. Bullets go through corpses (Nuclide
  core): the corpse takes the hit and the shot carries on to what's behind.
- `coop_survival 1`: no respawning on your own. Clearing a wave brings
  everyone back; if the whole team is down the map restarts.
- Waves spawn at `info_monster_spawn` points (or deathmatch spawns). A map
  that places hostile monsters or monster makers of its own and has no
  `info_monster_spawn` gets no waves unless `coop_mapWaves 1`; allies
  (Barney, `monster_hecu_ally`, scientists) don't count.
  Size is `coop_waveBase + coop_wavePerPlayer * players + coop_wavePerWave * (wave - 1)`,
  with at most `coop_maxMonsters` alive at once. `coop_waveMonsters` lists
  monster tiers separated by `;`; later waves mix in higher tiers.
- Monster health scales by `1 + coop_healthPerPlayer * (players - 1)`, up to
  `coop_healthScaleMax`.
- Score is points: a monster kill is worth a tenth of its health, a revive
  `coop_revivePoints`, killing an ally costs `coop_allyKillPenalty`. The
  same points can be spent in the shop (below).
- `callvote skill 1|2|3` changes the skill for monsters spawned after the
  vote passes (`mp_allowvote 1`).
- Server commands: `sv coop_status`, `sv coop_nextwave`, `sv coop_killmonsters`.
  `coop_statusInterval N` prints the status every N seconds. For tests,
  `sv coop_botvote skill 3` has a bot call a vote and
  `sv coop_botvoteyes [skipfirst]` has the bots vote yes.
- Teammates and friendly NPCs get a name and health bar overhead (the
  rules set serverinfo `nameplates 1`). The drawing is shared client code in
  `src/client/nameplates.qc`; `cg_nameplates 0|1` overrides it per player and
  `cg_nameplatesRange` sets the distance (1000). Aiming at one also shows a
  TF2-style target ID panel (name, health) under the crosshair: serverinfo
  `targetid 1`, `cg_targetID 0|1`, `cg_targetIDRange` (2000).

While down or waiting to respawn the view stays on the death camera
instead of the scoreboard (`cg_scoresWhenDead 0`, set in
`default_coop.cfg`; Tab still shows the scores).

## Points shop (`src/rules/shop.qc`)

- Points are earned with the score but kept apart from it, so buying
  doesn't lower anyone's score. They start at 0 on each map.
- `coop_shop 0` turns the shop off, `1` (default) opens it at any time,
  `2` only between waves. Players who are down or waiting to respawn can
  buy too; they get what they bought when they spawn or are revived.
- The list is `scripts/shop.txt` (`coop_shopFile`): category, what to
  give (a weapon, `ammo_<type> <count>`, `health <n>` or `armor <n>`),
  price and the name shown. It's read when a map starts. Health and
  armour stop at `coop_shopMaxHealth` and `coop_shopMaxArmor` (100),
  or at the player's own maximum health when that is higher.
- `cmd shop` opens the shop menu (B, when B is free, or Shop and skills
  in the pause menu). It has a Shop tab and, with the XP mod, a Skills
  tab; Tab switches between them. The server sends its own list, so clients always see the
  server's prices. Keys work like Counter-Strike's buy menu: a number picks
  a category, a number buys, 8 and 9 turn the page, 0 goes back.
- `cmd buy <n>` buys item n. `sv coop_givepoints <n>` gives every player
  points, for tests.

## Heroes (`src/rules/heroes.qc`)

- `coop_heroes 1` (default) turns heroes on. `coop_heroes 0` is plain
  co-op: everyone spawns as the same `player_mp`, with their own player
  model as a skin, and only the XP mod sets players apart. It's read when
  a map starts. The title menu's Hero page lists the heroes of
  `heroes.def` and `heroes_roster.def`.
- Heroes have no melee slot: a melee weapon (HUD slot 0) from a kit, the
  shop or the floor is taken away, and every hero spawns with its static
  weapon out.
- Players pick a hero and one of its kits (its subclasses) on the Hero tab
  of the shop menu, which opens by itself on a player's first spawn. A
  pick takes effect at the next spawn, so it never respawns anyone or
  takes away what they bought. `cmd heroes` sends the list and
  `cmd hero <kit>` picks.
- Heroes can be picked before joining too, on the title menu's Hero page.
  That pick is the `hero` cvar, saved in the config and sent to servers as
  the `hero` userinfo key, so a player spawns as it on any server with
  heroes on and isn't asked. A pick in a game saves it too. A game
  started with `+map` on the command line spawns the player before the
  menu sends it; the rules respawn them as it a second later.
- Both menus show the picked kit's hero in 3D, turning. Panorama can't
  draw models, so the menu progs renders it under the view
  (`Preview_Draw` in `src/menu/main.qc`) and the view leaves that part
  see-through.
- Heroes and kits are defs in `decls/def/heroes.def`: a hero sets the
  model, health and speed, and each kit inherits its hero and sets the
  starting weapons. Players spawn as the kit. `coop_heroList` names the
  heroes on offer, in menu order; `coop_heroLimit` (2) is how many players
  may play one hero, 0 for any number.
- The placeholder heroes use Quake Live player models baked to .md2 (Tank
  tankjr sport, Support grunt, Pointman crash sport). They come in
  `zz_coopheroes.pk3`, which isn't in git: put it in `coop/`. Without it
  heroes fall back to `models/player.mdl`. The models need Bulwark's .md2
  support.
- Support's Medic kit (`hero_logic "medic"`, `src/rules/hero_kits.qc`): the
  Cyclone is a single-shot medigun pistol. A shot that hits a teammate (a
  player or an allied NPC) heals them by `coop_medigunHeal` (15); one that
  hits a foe hurts it (22). Shield (C) gives the teammate under the
  crosshair `coop_medicShield` (40) Barrier, or the Medic half that, every
  6 s; Barrier Field (G) gives everyone within 400 units `coop_medicField`
  (25), every 20 s; Barrier stops at each hero's cap. No engage form yet,
  so Z says so. `sv coop_survivors hurt` puts the bots, at 30 health, in
  front of you, to test it.
- Each hero has two weapon slots, like Left 4 Dead's sidearm and primary
  (`decls/def/hero_weapons.def`, `src/rules/heroes.qc`). The static weapon
  is the hero's own ("hero_weapon": Tank BALROG-VII, Support Cyclone,
  Pointman SKULL-1): given at every spawn, never dropped, and its reserve
  (`ammo_hero`) refills, so only the clip needs reloading. The dynamic slot
  holds one other gun. Walking over a gun doesn't take it: look at it
  (within about 96 units, "[Use] Take <gun>" shows) and press Use, and it
  replaces the dynamic gun, which drops in front of you (it can't be taken
  again for 1.5 s), and switches to it. Survivor bots still take a gun by
  walking over it when their dynamic slot is empty. Q (`weaplast`, the
  last weapon) swaps between the static and the dynamic gun, since a hero
  carries nothing else.
  `cmd heroguns` lists the floor guns and what you hold (`take` takes the
  nearest one), for tests.
  Melee and throwables are outside both. The static weapons are Counter-
  Strike Online's, from the CSNZ install, in `zz_coopweapons.pk3`, which
  isn't in git either: put it in `coop/`. Their view models have the arms
  emptied (`tools/cso_hide_arms.py`) and are mirrored to the right hand
  ("model_viewMirror"; needs Bulwark's RF_MIRROR). Their stats are
  stand-ins, and BALROG-VII's explosive round isn't in yet.
- Ten prototype heroes, two per genre, from the example roster: Dispatch
  and Choir (Commander), Bulkhead and Kettle (Wall), Vector and Stray
  (Runner), Ledger and Tripwire (Planner), Longhand and Mantis (Hunter).
  Defs in `decls/def/heroes_roster.def`, their primaries in
  `hero_primaries.def` (Half-Life weapon logic with Counter-Strike Online
  models and sounds: MP7A1, KSG-12, Anaconda, Laser Fist, KRISS, Dual UZI,
  SCAR, M4A1, Railgun, Dual Sword, from `zz_coopguns.pk3`, which is built
  from the CSNZ install and isn't in git: put it in `coop/`), and what their placed things look
  like in `hero_visuals.def`. They're first in `coop_heroList`.
- Abilities (`src/rules/hero_abilities.qc`, the shared parts, and
  `hero_kits.qc`, the ten kits): C the tool, G and X the two abilities,
  Z engage, V the form's exclusive move (impulses 21 to 25). The menu
  binds them once the saved config has run, only for a command with no
  key yet: if C/G/X/Z/V are taken (radio, drop) it falls back to
  H/J/K/L/O, then MOUSE4/MOUSE5/N/M/P, then keypad keys, and prints a
  warning if all are taken. `coop_herokeys` forces C G X Z V; Options >
  Keys lists them. The HUD shows Energy, Barrier and each ability's state.
- Energy (0 to 100) is the shared pool and only pays for engage: it needs
  `coop_engageCost` (50) and drains `coop_engageDrain` (2.5) a second.
  In hero mode armour is Energy: any armour a hero gets turns into Energy
  one for one (`coop_energyPerKill` adds some per kill, 0 by default).
- Barrier is the armour stat now and takes all damage before health, up to
  75, 50 or 25 by weight. Only Commanders, engage and Planner emitters
  give it.
- Swap at checkpoints: between waves a new pick applies at once, on the
  spot. Everything a player placed goes when they change hero; Energy
  stays.
- Test helpers, with `sv_cheats 1`: `cmd energy [n]`, `cmd places` (lists
  placed things), and `coop_heroAimTest 1` (the server aims human players
  at the nearest foe).

## Menus (`src/menu/`, `panorama/`)

The menus carry the name Justice Task Force. The title menu, the pause
menu and the shop menu (shop and XP skills) are Panorama views drawn by
Bulwark (`panorama/layout/coop/`, `styles/coop/`, `scripts/coop/`). The
menu progs (`menu.dat`) only opens and closes them and answers what a
script can't find out itself: the map list, LAN servers and key bindings
(`Menu_UIAction`, see Bulwark's `docs/spec/ui.md`). Scripts read cvars
and run commands themselves.

- Title menu: Play (map, server name, max players, difficulty, survival,
  waves, respawn delay, XP mod, votes), Find servers (LAN and by address),
  Options, Quit.
- Pause menu (Escape in a game): Resume, Points shop, Vote, Options,
  Disconnect, Quit.
- Options: Player, Video, Audio, Mouse and Keys tabs. Changes wait for OK
  or Apply, which write them with `seta` and save the config. In Keys,
  click an action and press a key; Escape cancels, Backspace clears.
- The menu uses Tahoma when the game has `fonts/tahoma.ttf` and
  Rad-Therapy's Nimbus Sans otherwise.

## XP mod (`src/plugins/xpm.qc`)

A server plugin in the style of the Sven Co-op XP mod (SCXPM), written
fresh from a description of how that mod plays. The rules load the plugins
named in `coop_plugins` (default `xpm`) on every map; `sv addon load xpm`
also works.

- Each point of score is worth `5 * xpm_xpgain` XP. Reaching the next level
  from level L takes `70L + 3.5L² + 30` XP, up to level 1800, and each level
  is a skill point. Rank names go with level bands.
- Nine skills: Strength (+1 health each), Superior Armor (+1 armour),
  Health Regeneration, Nano Armor, Ammo Reincarnation, Anti Gravity (lower
  gravity while you hold jump after a jump), Awareness (boosts the others),
  Team Power (heals and armours teammates within 650 units) and Block
  Attack (a chance each half second to take no damage).
- Medals (0 to 15, three to start) add a little to most skills.
- A level-up shows a short notice on the HUD. Points are spent in the
  Skills tab of the shop menu (B, or `selectskills` to open it on that
  tab): keys 1 to 9 (or a click) spend a point, 0 closes it. The plugin
  sends the skills to the co-op menu progs as `menu_coop skills_*` lines
  and they're drawn with Panorama (`panorama/layout/coop/loadout.xml`);
  choices come back as `menuselect`. `xpm_textmenu 1` uses the plain text menu (`svmenu`)
  instead, for clients without the co-op menu.
- Commands, in the console or in chat with or without `/`: `selectskills`,
  `resetskills`, `playerskills`, `skillsinfo`, `xpminfo`. Admin: `setlvl
  <name> <level>`, `addmedal <name>`, `removemedal <name>`, `godmode
  <name>`, `noclipmode <name>`. Admins are the listen server host, anyone
  with `sv_cheats 1`, or the names in `xpm_admins`.
- The HUD shows XP, level, rank and medals on the left (`xpm_hud 0` hides
  it). Progress is saved to `data/xpm/` by GUID, certificate or name, on
  level-up, every 30 seconds and on disconnect. Bots aren't saved.

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
inside) and `data/coop_arena.way` (bot and monster waypoints). Two friendly
HECU grunts (`monster_hecu_ally`, `decls/def/allies.def`) guard the start.

## HUD

The in-game HUD is sokky's Figma HUD (Design System page, "Example · HUD"),
built as a Panorama view: `panorama/layout/coop/hud.xml`, `styles/coop/hud.css`
and `scripts/coop/hud.js`. The co-op HUD progs (`src/hud`, built to `hud.dat`)
opens it embedded and draws it with `ui_draw`, posting the health, ammo, hero,
teammates, wave, kill feed and notices to it. It shows the squad top left, the
wave counter top centre, the kill feed top right, the hero's abilities, health,
Barrier and Energy bottom left, and ammo with the two weapon slots bottom right.
Weapon selection, pickup notices, damage arrows and the crosshair are still
Half-Life's.

- `cg_hudPanorama 0` draws the Half-Life HUD instead (and FTE, which has no
  Panorama, always does). The client's `phud` userinfo tells the server which
  HUD it draws, so the hero text line and wave centerprints only go to clients
  on the old one.
- The server side is `src/rules/hud_info.qc` (teammates `*mate`, the Use
  prompt `*prompt`, serverinfo `coop_left`) and `Hero_HudInfo` in
  `hero_abilities.qc` (`*herohud`); `Coop_Announce` also sets serverinfo
  `coop_notice`.

