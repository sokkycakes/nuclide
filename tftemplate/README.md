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

`g_gametype` picks the mode: `tf_ctf`, `tf_cp`, `tf_koth` or `tf_pl`. When
it isn't set, the map name decides, as in TF2: `ctf_*` maps run CTF, `cp_*`
maps run CP, `koth_*` maps run KOTH and `pl_*` maps run Payload. Anything
else falls back to CTF.

`lqdm1` from `base` comes with test layouts for all three modes (see
[Objective overlays](#objective-overlays)). Add bots with `addBot marco`,
`addBot gethyn` and so on (names from `base/scripts/bots.txt`).

## Building

The compiled progs are committed. To rebuild them after changing the QC:

```
make -C tftemplate/src QCC=/path/to/fteqcc
```

This builds `tftemplate/progs.dat` (server), `tftemplate/hud.dat` (HUD) and
`tftemplate/progs/tf_{ctf,cp,koth,pl}.dat` (rules). The client game
(`csprogs.dat`) and menu come from `base`.

## Layout

| Path | What it is |
| --- | --- |
| `src/shared/tf_api.h` | Team numbers, objective kinds and entity fields shared by the server and rules progs |
| `src/server/` | Server progs: `base`'s server plus the template's entities and helpers |
| `src/server/tf_api.qc` | Query helpers for bots and server code, and the bridge the rules call |
| `src/rules/tf_common.qc` | Teams, class choice, respawn waves, rounds, HUD state, test commands |
| `src/rules/tf_ctf.qc`, `tf_cp.qc`, `tf_koth.qc`, `tf_pl.qc` | One file per game mode |
| `src/hud/` | `base`'s HUD with an objective strip added (`tf_hud.qc`) |
| `decls/def/tf_classes.def` | The nine classes |
| `decls/def/tf_objectives.def` | TF2 entity names mapped to the template's classes |
| `decls/def/tf_pickups.def` | TF2 style health kits and ammo packs |
| `maps/*.add` | Objective overlays for `base` maps |

## Classes

Each class is an entityDef, `tfclass_<name>`, that inherits `tf_player_base`.
`tf_player_base` inherits `base`'s `player` def and spawns as `tfPlayer`.
Health and speed match TF2: for example, the Scout has 125 health and moves
at 400, and the Heavy has 300 health and moves at 230. Weapons are
placeholders from Quake's arsenal.

Template keys:

| Key | Meaning |
| --- | --- |
| `tf_classIndex` | Class menu slot, 1 to 9 |
| `tf_role` | `offense`, `defense`, `support` or `sniper`, a hint for bots |
| `tf_capRate` | How many players this class counts as on a capture area (the Scout counts as 2) |
| `tf_regen` | Health regenerated per second (the Medic has 3) |
| `tf_weaponRanges` | `"<weapon> <min> <max> ..."`, effective ranges with the best weapon first |

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
  minigun spin), and `tf_healTarget`. The template doesn't drive the last
  two yet, because its weapons are placeholders.
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
state, the KOTH clocks, and the payload cart's progress bar (with the
pusher count, BLOCKED, or `<<` while it rolls back). It reads the serverinfo keys `tf_mode`,
`tf_round`, `tf_timer`, `tf_obj`, `tf_caps`, `tf_koth` and `tf_wins`. Other
HUDs can read the same keys.

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
| `set tf_debug 1` | Logs round changes, spawns and objective events |

`bot_pause 1` stops Nuclide's bots from moving and shooting, which makes
pinned capture tests repeatable.

## Known gaps

- Weapons, models and sounds are `base` placeholders. There are no
  TF-specific weapons, buildings, uber or cloak yet.
- Players over 255 health show wrapped values on the client. `base`
  networks health as a byte. The fix is commit 238cce6 on the branch
  `claude/project-thread-upkyrb`.
- Arena mode isn't in yet. Payload has one cart per map (no payload race),
  carts don't turn, and teams don't swap sides between rounds.
- Nuclide's bots fight but don't play objectives. Objective-aware bots
  belong to the bot framework, which uses the interface above.
