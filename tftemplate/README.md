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

`g_gametype` picks the mode: `tf_ctf`, `tf_cp` or `tf_koth`. When it isn't
set, the map name decides, as in TF2: `ctf_*` maps run CTF, `cp_*` maps run
CP, and `koth_*` maps run KOTH. Anything else falls back to CTF.

`lqdm1` from `base` comes with test layouts for all three modes (see
[Objective overlays](#objective-overlays)). Add bots with `addBot marco`,
`addBot gethyn` and so on (names from `base/scripts/bots.txt`).

## Building

The compiled progs are committed. To rebuild them after changing the QC:

```
make -C tftemplate/src QCC=/path/to/fteqcc
```

This builds `tftemplate/csprogs.dat` (client), `tftemplate/progs.dat`
(server), `tftemplate/hud.dat` (HUD) and `tftemplate/progs/tf_{ctf,cp,koth}.dat`
(rules). The client is `base`'s, rebuilt with the template's shared header so
its entity fields line up with the server's. The menu comes from `base`.

## Layout

| Path | What it is |
| --- | --- |
| `src/shared/tf_api.h` | Team numbers, objective kinds and entity fields shared by the server and rules progs |
| `src/server/` | Server progs: `base`'s server plus the template's entities and helpers |
| `src/server/tf_api.qc` | Query helpers for bots and server code, and the bridge the rules call |
| `src/rules/tf_common.qc` | Teams, class choice, respawn waves, rounds, HUD state, test commands |
| `src/rules/tf_ctf.qc`, `tf_cp.qc`, `tf_koth.qc` | One file per game mode |
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
| setup | Optional, CP attack/defend only. Points are locked |
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
captures by defining `TFRules_AllowFlagPickup`, `TFRules_AllowFlagCapture`
or `TFRules_AllowPointCapture`.

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
| `team_control_point_master`, `team_round_timer`, `tf_gamerules`, `tf_logic_koth` | Accepted and ignored. The rules do their jobs |

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
  - `TF_ObjectiveFor(team)` returns where a team should go now: its
    capture zone if it carries a flag, otherwise the enemy flag, otherwise
    the lowest point it can capture, otherwise a point it has to defend.
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
state, and the KOTH clocks. It reads the serverinfo keys `tf_mode`,
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
| `tf_test_kill <player>` | Kills a player |
| `tf_test_class <player> <tfclass_name>` | Respawns a player as a class |
| `tf_test_put <player> <x> <y> <z> [yaw]` | Moves a player and pins them there with bot AI off |
| `tf_test_hold <player> <buttons> <seconds> [target]` | Pins a player and holds `primary`, `secondary`, `reload`, `jump` or `use` (join with `+`), aiming at a player or `@classname` |
| `tf_test_release <player>` | Unpins a player |
| `tf_test_use <player> <weapon>` | Switches weapon |
| `tf_test_hurt <player> <amount>` | Takes health away |
| `tf_test_uber <player>` | Fills a Medic's Ubercharge |
| `tf_test_report` | Health, weapon, ammo, meter and state of every player and building |
| `set tf_debug 1` | Logs round changes, spawns and objective events |

`bot_pause 1` stops Nuclide's bots from moving and shooting, which makes
pinned capture tests repeatable.

## Known gaps

- Models and sounds are Quake's. Buildings use stand-in models.
- The wrench didn't upgrade a sentry in the headless tests, where the bot
  couldn't land the swing. It needs a check in the game client.
- A bot holding the construction PDA can destroy its own building, since
  bots press reload. Bot code should keep bots off the PDA.
- Players over 255 health show wrapped values on the client. `base`
  networks health as a byte. The fix is commit 238cce6 on the branch
  `claude/project-thread-upkyrb`.
- Payload (`team_train_watcher`) and arena modes aren't in yet.
- Nuclide's bots fight but don't play objectives. Objective-aware bots
  belong to the bot framework, which uses the interface above.
