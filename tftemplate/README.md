# Team Fortress template

A starting point for Team Fortress style games on Nuclide. It gives you the
game structure (RED and BLU, nine classes, respawn waves, rounds, and the
CTF, Control Point and King of the Hill modes) without being a finished
game. Weapons, models and sounds are placeholders taken from Nuclide's
`base` game.

It runs on FTEQW and on any engine that runs Nuclide, such as Bulwark.

## Licensing and origins

Everything here is ISC licensed, like Nuclide. It was written fresh against
Nuclide's own APIs. No code was taken from FortressOne, MegaTF, the original
QuakeWorld Team Fortress, or Valve's Source / Team Fortress 2 code.

Team Fortress 2 was used only as a design reference. The template reuses
TF2's entity class names, key names, team numbers and output names, so maps
built for that entity set work here. It also follows TF2's published game
rules where it implements them: class health and speeds, harmonic capture
speed, respawn waves, and KOTH clocks.

## Running it

The template mounts on top of `base`. Use the manifest in the repository
root:

```
fteqw -manifest tftemplate.fmf +set g_gametype tf_ctf +map lqdm1
fteqw-sv -manifest tftemplate.fmf +set g_gametype tf_koth +map lqdm1
```

The map name picks the mode, as in TF2: `ctf_*` maps run CTF, `cp_*` maps
run CP, `koth_*` maps run KOTH and `pl_*` maps run Payload, whatever
`g_gametype` says (it keeps the last map's mode across `map` and
`changelevel`). Other maps run `g_gametype` (`tf_ctf`, `tf_cp`, `tf_koth`
or `tf_pl`), or CTF when it isn't set.

`lqdm1` from `base` comes with test layouts for all three modes (see
[Objective overlays](#objective-overlays)). Add bots with `addBot marco`,
`addBot gethyn` and so on (names from `base/scripts/bots.txt`).

## Building

The compiled progs are committed. To rebuild them after changing the QC:

```
make -C tftemplate/src QCC=/path/to/fteqcc
```

This builds `tftemplate/csprogs.dat` (client), `tftemplate/progs.dat`
(server), `tftemplate/hud.dat` (HUD) and `tftemplate/progs/tf_{ctf,cp,koth,pl}.dat`
(rules). The client is `base`'s, rebuilt with the template's shared header so
its entity fields line up with the server's. The menu comes from `base`.

## Layout

| Path | What it is |
| --- | --- |
| `src/shared/tf_api.h` | Team numbers, objective kinds and entity fields shared by the server and rules progs |
| `src/server/` | Server progs: `base`'s server plus the template's entities and helpers |
| `src/server/tf_api.qc` | Query helpers for bots and server code, and the bridge the rules call |
| `src/server/bots/` | The template's bots, on the Bulwark bot framework (see [Bots](#bots)) |
| `src/server/bwbots/` | A copy of the Bulwark bot framework (`qc/bots` in bulwark-engine, ISC) |
| `src/rules/tf_common.qc` | Teams, class choice, respawn waves, rounds, HUD state, test commands |
| `src/rules/tf_ctf.qc`, `tf_cp.qc`, `tf_koth.qc`, `tf_pl.qc` | One file per game mode |
| `src/server/tf_player.qc` | `tfPlayer`: knockback, afterburn, uber, cloak, disguise, the weapon meter |
| `src/server/tf_weapons.qc` | Weapons that need code: stickybombs, minigun, flamethrower airblast, medigun, sniper rifle, knife, wrench, PDAs, sapper |
| `src/server/tf_buildings.qc` | Sentry gun, dispenser and teleporters |
| `src/server/tf_test.qc` | `tf_test_*` commands for driving players and bots from the console |
| `src/client/` | Build files for the template's client progs |
| `src/hud/` | `base`'s HUD with an objective strip (`tf_hud.qc`), nameplates and target ID (`nameplates.qc`) |
| `decls/def/tf_classes.def` | The nine classes |
| `decls/def/tf_weapons.def`, `tfweapons/` | Every class's stock weapons |
| `decls/def/tf_buildings.def` | Engineer buildings |
| `decls/def/ammo.def`, `weapons.def` | TF ammo types; Quake map weapons and ammo turned into ammo packs |
| `decls/def/tf_objectives.def` | TF2 entity names mapped to the template's classes |
| `decls/def/tf_pickups.def` | TF2 style health kits and ammo packs |
| `maps/*.add` | Objective overlays for `base` maps |

## Classes

Each class is an entityDef, `tfclass_<name>`, that inherits `tf_player_base`.
`tf_player_base` inherits `base`'s `player` def and spawns as `tfPlayer`.
Health and speed match TF2: for example, the Scout has 125 health and moves
at 400, and the Heavy has 300 health and moves at 230. As in TF2, crouching
moves at a third of the class's speed (`pm_crouchspeed`), backing up at 90%
(`pm_backspeed`), a spun-up Heavy at 110 and a zoomed Sniper at 80, and the
server sets TF2's acceleration and stopping (`pm_accelerate 10`,
`pm_stopspeed 100`) on every map. A Medic healing a faster patient keeps up
with them, and a disguised Spy moves no faster than the disguise's class
(the server sets Nuclide's predicted `m_pmoveSpeedTarget`). Each class carries
its TF2 stock loadout with TF2's damage, clip sizes and fire rates, drawn
with Quake models.

Template keys:

| Key | Meaning |
| --- | --- |
| `tf_classIndex` | Class menu slot, 1 to 9 |
| `tf_role` | `offense`, `defense`, `support` or `sniper`, a hint for bots |
| `tf_capRate` | How many players this class counts as on a capture area (the Scout counts as 2) |
| `tf_regen` | Health regenerated per second (the Medic has 3) |
| `tf_weaponRanges` | `"<weapon> <min> <max> ..."`, effective ranges with the best weapon first |
| `tf_noAfterburn` | 1 if flames don't set this class on fire (the Pyro) |
| `tf_cloak` | 1 if secondary fire cloaks this class (the Spy) |
| `pm_airjumps` | Extra jumps in the air (the Scout's double jump). A Nuclide key, predicted on the client |

### Weapons and abilities

| Class | Weapons and what's special |
| --- | --- |
| Scout | Scattergun, pistol, bat. Double jump |
| Soldier | Rocket launcher (rocket jumping through self knockback), shotgun, shovel |
| Pyro | Flamethrower with afterburn; secondary fire is an airblast that pushes enemies, reflects projectiles and puts out teammates. Shotgun, fire axe |
| Demoman | Grenade launcher; stickybomb launcher: hold to charge, release to fire, secondary detonates armed stickies, at most 8 out. Bottle |
| Heavy | Minigun: spins up before firing, secondary spins without firing, slows you while firing. Shotgun, fists |
| Engineer | Shotgun, pistol, wrench, construction PDA (primary builds, secondary cycles the building, reload destroys it). Wrench hits on your buildings repair, refill, upgrade to level 3 and remove sappers, using metal |
| Medic | Syringe gun; medigun: hold on a teammate to heal (faster when they haven't been hurt for 10 s), overheal to 150%, builds Ubercharge; secondary deploys it. Bonesaw |
| Sniper | Sniper rifle: secondary zooms, damage charges from 50 to 150 while zoomed, headshots triple it. SMG, kukri |
| Spy | Revolver, knife (backstabs kill), sapper (disables and damages enemy buildings), disguise kit (primary cycles disguises, reload drops it). Secondary fire cloaks |

Buildings: the sentry (three levels, rockets at level 3, ignores cloaked
Spies and Spies disguised as its team), the dispenser (health, ammo, and
metal for Engineers) and the teleporter entrance and exit. Damage applies
TF2 knockback (cvars `tf_knockback`, `tf_selfknockback`,
`tf_knockback_max`), and the HUD shows the active weapon's meter (charge,
stickies, spin, uber, cloak, metal) above the ammo.

When you die, the view works like TF2's. A death cam pulls back from where
you fell and looks at your killer (a building's kill counts as its
Engineer's). After 2 seconds (`cl_freezecam_delay`) a freeze cam moves in
on the killer and holds. Then you spectate a living teammate in a chase
cam until you respawn, 6.4 seconds after dying (`tf_deathcam_time`, or
`tf_deathcam_time_suicide` 2 when nobody else killed you). Bots skip all
of this. The HUD shows "Killed by" and "Spectating".

Reloads follow TF2's rules and times (from the TF2 wiki). Rocket and
grenade launchers, the stickybomb launcher, scattergun and shotguns load one
round at a time: the first round takes longer (`reloadStartTime`), each
round goes in at the end of its step (`reloadTime`), and firing stops the
reload once a round is in. Pistols, the SMG, syringe gun and revolver
reload the whole magazine in one go and can't fire meanwhile. An empty
weapon reloads by itself, even with the trigger held. These weapons set
Nuclide's `reloadTimed` key, so reloads run on def times instead of the
placeholder view model animations and the client predicts them. Without
reload animations, the HUD draws a timer bar above the crosshair for the
round going in ("3/4") or the magazine, and the ammo counter shows the clip
and the reserve.

Weapon mechanics that need prediction are Nuclide def keys, so the client
predicts them: `pm_airjumps` and `pm_backspeed` on the player, and `speed_mod_firing` and
`speed_mod_zoomed` on weapons. The rest runs on the server only, because
the client always predicts plain `ncPlayer`/`ncWeapon`; charging and spin-up
can look slightly off on a laggy client.

To add or change a class, edit the def and list it in the `tf_classes` cvar.
The cvar sets which classes exist and their order on the class menu. New
class mechanics belong in `tfPlayer` (`src/server/tf_player.qc`) or a
subclass of it, so they work in every mode.

Players pick a team and a class through Nuclide's team and class menus, or
with `cmd joinTeam <1|2>` and `cmd join tfclass_<name>`. The first pick
spawns you right away. Later picks take effect on your next life, or right
away if you are standing in your team's `func_respawnroom`.

## Rounds

| State | What happens |
| --- | --- |
| waiting | Until both teams have a player (`tf_waitforplayers 0` skips this) |
| preround | Everyone respawns and objectives reset, for `tf_preround` seconds |
| setup | Optional, CP attack/defend and Payload only. Points are locked and the cart doesn't move |
| active | Objectives are live and the round timer runs |
| win / stalemate | Bonus time of `tf_bonustime` seconds, with no respawns |

After `tf_winlimit` round wins the map ends. Dead players respawn in waves
every `tf_respawnwave` seconds, once they have been dead for at least
`tf_respawnmin` seconds.

## Game modes

**CTF** (`tf_ctf`): bring the enemy's `item_teamflag` to your
`func_capturezone`. The first team to `tf_ctf_capturelimit` captures wins
the round. When `tf_ctf_roundtime` runs out, the team with more captures
wins. Set `tf_ctf_flaghome 1` to require your own flag to be at home before
you can score. Dropped flags go home after `tf_flag_returntime` seconds, or
after the flag's own `ReturnTime` key.

**CP** (`tf_cp`): with `tf_cp_attackers 0` the mode is symmetric, like 5CP:
own every point to win, and the timer running out is a stalemate. With
`tf_cp_attackers 1` or `2` it is attack/defend: only that team captures,
defenders win on time, each capture adds `tf_cp_timeadd` seconds, and
`tf_cp_setuptime` sets the length of setup. Capture order comes from the
points' `team_previouspoint_*` keys.

**KOTH** (`tf_koth`): one point. It unlocks after `tf_koth_unlock` seconds.
The owning team's clock (`tf_koth_time`) counts down, and when it reaches
zero that team wins. If the enemy is capturing at that moment, the round
goes to overtime.

**Payload** (`tf_pl`): the attackers (the team the cart's
`trigger_capture_area` lets capture, BLU on TF2 maps) push a cart along a
`path_track` chain. A `team_train_watcher` turns the players at the cart
into speed: one pusher moves it at 55% of the train's `startspeed`, two at
77%, three or more at full speed (`tf_pl_speed1/2/3`), and Scouts count as
two. Defenders at the cart block it. After 30 seconds without a push (or
the watcher's `train_recede_time`) it rolls back at `tf_pl_recedespeed` of
its top speed, but never past a checkpoint the map has closed behind it.
Checkpoints are the map's own logic: its `path_track` OnPass outputs give
the points to the attackers and add time through `team_round_timer`. The
attackers win when the cart reaches the watcher's `goal_node` (or they own
every point); the defenders win when time runs out. If the attackers are
at the cart then, the round goes to overtime until nobody pushes. Round and
setup lengths come from the map's `team_round_timer` (`tf_pl_roundtime`
and `tf_pl_setuptime` without one), and every round starts from a full map
reset: doors close, paths re-enable and the cart goes home.

Capture areas use TF2's rules:
- n players capture 1 + 1/2 + ... + 1/n times as fast as one player, up to
  `team_numcap`.
- If both teams stand on the point, the point is blocked.
- Defenders standing on the point push the progress back.
- An empty point decays over `tf_cp_decaytime` seconds.

### Adding a mode

Copy one of the mode files and its `.src`, and add it to
`src/rules/Makefile`. A mode implements the `Mode_*` functions listed at
the top of `tf_common.qc`. It receives objective events (`TF_FlagCaptured`,
`TF_PointCaptured` and others) in `Mode_Event`. It can veto pickups and
captures by defining `TFRules_AllowFlagPickup`, `TFRules_AllowFlagCapture`,
`TFRules_AllowPointCapture` or `TFRules_AllowCartPush`.

## Map entities

These work in compiled maps and in overlays. Team keys use TF2's numbers:
`TeamNum` 2 is RED, 3 is BLU and 0 is any team. Hand-written overlays can
use a native `team` key instead (1 is RED, 2 is BLU).

| Classname | Notes |
| --- | --- |
| `info_player_teamspawn` | `TeamNum`, `StartDisabled`. Inputs: Enable, Disable, SetTeam |
| `item_teamflag` | `TeamNum`, `ReturnTime`, `flag_model`, `tf_returnOnTouch`. Outputs: OnPickUp, OnPickupTeam1/2, OnDrop, OnReturn, OnCapture, OnCapTeam1/2. Inputs: ForceDrop, ForceReset, SetTeam |
| `func_capturezone` | `TeamNum`. Outputs: OnCapture, OnCapTeam1/2 |
| `team_control_point` | `point_index`, `point_printname`, `point_default_owner`, `point_start_locked`, `team_previouspoint_{2,3}_{0,1,2}`. Inputs: SetOwner, SetLocked, ShowModel, HideModel. Outputs: OnOwnerChangedToTeam1/2, OnCapTeam1/2, OnCapReset, OnUnlocked |
| `trigger_capture_area` | `area_cap_point`, `area_time_to_cap`, `team_cancap_{2,3}`, `team_startcap_{2,3}`, `team_numcap_{2,3}`. Inputs: SetTeamCanCap, SetControlPoint, CaptureCurrentCP. Outputs: OnStartCap, OnBreakCap, OnEndCap, OnCapTeam1/2 |
| `func_respawnroom` | `TeamNum`. Players inside can change class immediately |
| `func_regenerate` | `TeamNum`, `tf_cooldown`. Refills health, armour and ammo |
| `item_healthkit_small/medium/full`, `item_ammopack_small/medium/full` | TF2 style pickups |
| `team_round_timer` | `timer_length`, `setup_length`, `max_length` give the rules the map's round lengths. Inputs: AddTime, AddTeamTime, SetTime, SetSetupTime, SetMaxTime. Outputs: OnSetupStart, OnSetupFinished, OnRoundStart, OnFinished, On5MinRemain, On1MinRemain, On30SecRemain, On10SecRemain |
| `game_round_win` | `TeamNum`. Input RoundWin ends the round for that team |
| `game_forcerespawn` | Inputs: ForceRespawn, ForceTeamRespawn (TF2 team number) |
| `func_tracktrain` | `target`, `startspeed`, `speed`, `height`, `dmg`. Slides along `path_track`s without turning. Inputs: StartForward, StartBackward, Stop, Resume, SetSpeed, SetSpeedDir, SetSpeedReal, TeleportToPathTrack. Kill hides it until the next round. Entities with its name as `parentname`, and props tied to it by a `phys_constraint`, ride along; a prop whose model is missing is drawn as `tf_pl_cartmodel` |
| `team_train_watcher` | `train`, `start_node`, `goal_node`, `train_can_recede`, `train_recede_time`, `handle_train_movement`, `speed_forward_modifier`. Inputs: Enable, Disable, SetTrainCanRecede, SetTrainRecedeTime. Outputs: OnTrainStartRecede, OnTrainStopRecede |
| `mapobj_cart_dispenser`, `dispenser_touch_trigger` | `TeamNum`, `touch_trigger`. Heals 10 health per second and gives a fifth of each ammo type per second in the touch volume |
| `func_respawnroomvisualizer` | `respawnroomname`, `solid_to_enemies`. Solid only to the enemies of the named room's team, through collision dimensions (see `TF_DimensionBlocking`) |
| `filter_activator_tfteam`, `filter_activator_name`, `filter_activator_class` | `TeamNum`, `filtername`, `filterclass` ("player" matches every class), `Negated` |
| `trigger_multiple`, `trigger_once` | TF2 style: `filtername`, `wait`, spawnflags 1 (players) and 64 (everything). Outputs: OnStartTouch, OnStartTouchAll, OnEndTouch, OnEndTouchAll, OnTrigger. They poll what's inside, so OnEndTouch is reliable. Quake style `target`s still fire |
| `trigger_hurt` | Nuclide's, plus `filtername` |
| `team_control_point_master`, `tf_gamerules`, `tf_logic_koth`, `func_nobuild`, `env_tonemap_controller` | Accepted and ignored. The rules do their jobs |

Volumes (`func_capturezone`, `trigger_capture_area`, `func_respawnroom` and
`func_regenerate`) use their brush in compiled maps. In overlays, where
there is no brush, they use `mins` and `maxs` relative to `origin`.

## Objective overlays

Nuclide appends `maps/<map>.add` to every map. On top of that, the template
loads `maps/<map>_<g_gametype>.add` (for example `lqdm1_tf_koth.add`). With
these files you can add spawns, flags and points to any existing map without
recompiling it. Each file holds entity blocks like a `.map` file's entity
lump, one key per line:

```
{
"classname" "team_control_point"
"targetname" "koth_point"
"origin" "672 -512 -32"
"point_start_locked" "1"
}
```

## Interface for bots and other server code

Bots should read the game only through this interface. It is declared in
`src/shared/tf_api.h` and `src/server/tf_api.qc`.

- **Teams**: 1 is RED and 2 is BLU. Helpers: `TF_EnemyTeam()`,
  `TF_TeamName()`.
- **Objective fields**: every objective has `tf_isObjective` set to 1 and a
  `tf_objective` kind: `TFOBJ_FLAG`, `TFOBJ_CAPZONE` or `TFOBJ_POINT`. Its
  `.team` field is the owner.
  - Points also have `tf_cpIndex`, `tf_cpLocked`, `tf_cpProgress` (0 to 1),
    `tf_cpCapTeam`, `tf_cpContested`, and `tf_cpArea`, the capture volume.
    Use the volume's `absmin`/`absmax` to find where to stand.
  - Flags also have `tf_flagState` (`TFFLAG_HOME`, `TFFLAG_CARRIED` or
    `TFFLAG_DROPPED`) and `tf_flagCarrier`.
- **Player fields**: `tf_carriedFlag`, `tf_desiredClass`, `tf_classIndex`,
  `tf_capRate`, `tf_regenRate`, `tf_charge` (0 to 1: sniper charge, uber,
  minigun spin, sticky charge), `tf_healTarget`, `tf_uberUntil`,
  `tf_cloaked`, `tf_disguiseTeam`, `tf_disguiseClass` and `tf_burnUntil`.
  Buildings have `tf_isBuilding`, `tf_builder`, `tf_buildingLevel` and
  `tf_sapped`.
- **Functions**:
  - `TF_NextObjective(prev)` steps through the objectives.
  - `TF_CanCapture(point, team)` says whether a team can capture a point.
  - `TF_ObjectiveFor(team)` returns where a team should go now. On payload
    maps that is the cart's `team_train_watcher` (`TFOBJ_CART`) for both
    teams: its origin follows the cart's push zone and its `.team` is the
    attacking team. Otherwise it is the team's capture zone if it carries a
    flag, then the enemy flag, then the lowest point it can capture, then
    a point it has to defend.
  - `TF_KothTimeLeft(team)` and `TF_Mode()` report the KOTH clock and the
    current mode.
  - Pickups: `TF_NextPickup(prev)`, `TF_PickupKind(e)` (`"health"` or
    `"ammo"`), `TF_PickupAmount(e)`, `TF_PickupAvailable(e)`.
  - Class data comes from the defs, for example
    `entityDef.GetString(player.classname, "tf_weaponRanges")`.
- **Joining**: bots use the same commands as players, `joinTeam N` and then
  `join tfclass_<name>`. A bot that never picks a class gets a random one.
- **Bot class**: bots spawn from `tfclass_<name>_bot` defs, which spawn as
  `tfBotPawn`. A bot framework keeps its own class across class changes by
  defining `TF_BOT_PAWN` and declaring `class tfBotPawn:<its bot class>`
  before `tf_player.qc` is compiled.
- **Hooks**: if the server progs define these functions, the rules call
  them:
  - `bw_notify_injured(victim, inflictor, attacker, damage)`
  - `bw_notify_killed(victim, inflictor, attacker, damage)` (damage is 0 for now)
  - `bw_bot_respawned(bot)`, after every bot spawn

## HUD

`hud.dat` draws a strip at the top of the screen. It shows the timer or the
round state, a box per control point (owner colour, capture progress bar,
`L` when locked, `!` when contested), each flag with its capture count and
state, the KOTH clocks, and the payload cart's progress bar (with the
pusher count, BLOCKED, or `<<` while it rolls back). It reads the serverinfo keys `tf_mode`,
`tf_round`, `tf_timer`, `tf_obj`, `tf_caps`, `tf_koth` and `tf_wins`. Other
HUDs can read the same keys.

`nameplates.qc` adds two things over friendly players:

- a name and health bar floating over each teammate's head (`cl_nameplates`,
  `cl_nameplates_range`), and
- a TF2-style target ID: a panel under the crosshair with the name, a
  health bar and the numbers of the teammate you are aiming at
  (`cl_targetid`, `cl_targetid_range`).

Both use three optional callbacks, `Nameplates_IsFriendly`,
`Nameplates_Name` and `Nameplates_Health`. The TF HUD sets the first two
so enemy Spies disguised as your team get a plate and a borrowed teammate's
name. Health comes from the `*hp` and `*maxhp` userinfo keys the server
publishes, since the HUD progs can't read entity health.

## Test and debug commands (server console)

| Command | What it does |
| --- | --- |
| `tf_status` | Prints the mode, round state, wins, timer and objective summary |
| `tf_restartround` | Starts a fresh round |
| `tf_forcewin <team>` | Ends the round with a win for that team (0 is a stalemate) |
| `tf_test_players` | Lists every player's team, class, health, position and carried flag |
| `tf_test_pin <player> <targetname>` | Keeps a player standing on an entity. Run it with no target to release them |
| `tf_test_follow <player> <targetname> <x> <y> <z>` | Keeps a player at that offset from an entity as it moves, e.g. beside a payload cart |
| `tf_test_kill <player>` | Kills a player |
| `tf_test_class <player> <tfclass_name>` | Respawns a player as a class |
| `tf_test_put <player> <x> <y> <z> [yaw]` | Moves a player and pins them there with bot AI off |
| `tf_test_hold <player> <buttons> <seconds> [target]` | Pins a player and holds `primary`, `secondary`, `reload`, `jump` or `use` (join with `+`), aiming at a player or `@classname` |
| `tf_test_release <player>` | Unpins a player |
| `tf_test_use <player> <weapon>` | Switches weapon |
| `tf_test_hurt <player> <amount>` | Takes health away |
| `tf_test_uber <player>` | Fills a Medic's Ubercharge |
| `tf_test_report` | Health, weapon, ammo, meter and state of every player and building |
| `tf_test_settime <seconds>` | Sets the round or setup clock (the map's `team_round_timer` when there is one) |
| `tf_nav_generate [spacing]` | Builds bot waypoints for the map and saves them as `data/<map>.way` (see below) |
| `set tf_debug 1` | Logs round changes, spawns and objective events |

`bot_pause 1` stops Nuclide's bots from moving and shooting, which makes
pinned capture tests repeatable.

## Bots

`addBot` bots run on the Bulwark bot framework (`src/server/bwbots/`, a copy
of `qc/bots` from bulwark-engine) instead of Nuclide's botlib. A bot is a
fake client that joins, picks a class and respawns like a player. The
framework only fills in its input each frame (view angles, movement,
buttons), so the template's own player physics, weapons and objectives
apply to bots exactly as they do to players.

`src/server/bots/tf_bots_pre.h` turns them on: it defines `TF_BOT_PAWN` and
makes the framework's `BWBot` derive from `tfPlayer`. `src/server/bots/tf_bots.qc`
declares `class tfBotPawn:BWBot` and the behaviours:

- **Combat**, always running: picks the weapon for the range from the class's
  `tf_weaponRanges`, aims at the chest (the head for snipers, the feet with
  lead for rockets and grenades) and fires when its crosshair, aim error
  included, is on the target. Being shot makes the attacker known. With no
  player in sight it shoots enemy buildings it can see. Cloaked Spies, and
  Spies disguised as the bot's team, go unnoticed until they hurt it.
- **Weapons with their own handling**: the Minigun spins while a target is
  near and for a couple of seconds after. The Sniper Rifle zooms at its spot
  and for far targets, waits for 60% charge unless the target is close or
  shooting back, and unzooms to move. Spies switch to the knife behind a
  target. Demomen plant up to four stickybombs around the objective while
  holding it, and set them off when an enemy is on them.
- **Tactical**: below 40% health it goes for the nearest health pickup, and
  with only melee left it goes for ammo.
- **Job**, from the class's `tf_role`:
  - `offense` and `defense` play `TF_ObjectiveFor()`. They stand in the
    capture area (spread around it when defending), take the enemy flag and
    carry it home, and escort a teammate who has it. In CTF, defenders guard
    their own flag and go after whoever took it.
  - `sniper` takes a waypoint on its own side that can see the objective, 600
    to 1600 units away, and watches it. It moves on after being hurt.
  - `support` follows the teammate fighting nearest the objective.
  - Medics (any class with `tf_weapon_medigun`) keep the Medi Gun on a
    patient instead: hurt, nearby and near the objective first, the flag
    carrier above all, snipers and other Medics last. They uber when charged
    and either of them is in trouble, and fight back only when someone is
    in their face and the patient is healthy.
  - Engineers (any class with `tf_weapon_pda_engineer_build`) build a sentry
    gun near the objective, wrench it while it is going up, damaged, sapped
    or not yet level 3, and stand behind it. They fetch metal when low. When
    the objective moves far from the gun they blow it up with the PDA's
    reload once they get there and build again; that is the only time a bot
    presses reload with the PDA out.

The framework's button bits are Bulwark's, where secondary fire is 16 and use
is 32. Nuclide has them the other way round, so `tfBotPawn::RunAI` swaps them
(`TFBot_NuclideButtons`).

Bots navigate on Nuclide's waypoint files (`data/<map>.way`). Without one
they still fight but walk straight at their goals.

| Command | What it does |
| --- | --- |
| `set bot_minClients N` | Keeps the server at N players, adding or kicking bots (Nuclide's; 24 is 12 a side, which needs `maxplayers 24` or more) |
| `set tf_bot_mixclasses 0/1` | Joining bots take the class fewest teammates play (default 1); 0 picks at random |
| `set bot_skill 1-3` | Aim error, reaction time and turn speed (default 2, from `base`) |
| `set tfbot_report N` | Prints every bot's class, health, score and behaviour every N seconds |
| `bot_status` | Lists the bots with their behaviour stacks |
| `bot_debug <category>...` | Framework debug output: `behavior`, `look`, `path`, `locomotion`, `vision`, `events` ... |
| `bot_debug_filter <name or entnum>...` | Limits `bot_debug` to some bots |

To build the template without the bots, drop `bots/tf_bots_pre.h`,
`bwbots/bots.qc` and `bots/tf_bots.qc` from `src/server/progs.src`; bots then
fall back to Nuclide's botlib.
### Bot waypoints

Both Nuclide's botlib and the Bulwark bot framework navigate on
`data/<map>.way`, and refuse to add bots ("No nodes") without one. TF2 maps
ship a `.nav` file instead, which neither reads, so `tf_nav_generate`
builds the graph (`src/server/tf_navgen.qc`):

- It floods out from every spawn point, `path_track` and objective in
  64-unit steps (or the spacing given), with the player's box.
- It walks up stairs and slopes (including onto the raised foot of a
  ramp, which the physics slides up), and links jumps up ledges a jump
  clears.
  Higher ledges that a crouch jump clears get `LF_JUMP` and `LF_CROUCH`.
  Drops of up to 250 units are one-way links.
- Doors, trains and spawn room walls are left out of the traces, so the
  graph goes through them. Spots inside a `trigger_hurt` are skipped, and
  waypoints balanced on the edge of a ramp or ledge are moved onto it.
  Waypoints near a wall or a drop are moved up to 12 units away from it,
  so on narrow ramps the path runs down the middle.

Run it once on a server with the map loaded. The file is written to
`tftemplate/data/`, where the bots read it on the next map load.
`data/pl_circle_a9a.way` was made this way (1565 waypoints).

Classes jump at TF2's 289 units/s (`pm_jumpheight` on `tf_player_base`),
so ledges in Source maps are as reachable as they are in TF2.

## Known gaps

- Models and sounds are Quake's. Buildings use stand-in models.
- The wrench didn't upgrade a sentry in the headless tests, where the bot
  couldn't land the swing. It needs a check in the game client.
- A bot holding the construction PDA can destroy its own building, since
  bots press reload. Bot code should keep bots off the PDA.
- Players over 255 health show wrapped values on the client. `base`
  networks health as a byte. The fix is commit 238cce6 on the branch
  `claude/project-thread-upkyrb`.
- Arena mode isn't in yet. Payload has one cart per map (no payload race),
  carts don't turn, and teams don't swap sides between rounds.
- Nuclide's bots fight but only play payload objectives, through a
  `GOALITEM` hint that rides on the cart. Other objective-aware bots
  belong to the bot framework, which uses the interface above.
- Bots don\'t use class abilities yet (no sticky traps, uber, sentries or
  disguises), because the classes don\'t have them either.
