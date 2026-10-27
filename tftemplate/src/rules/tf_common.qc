/*
 * Copyright (c) 2026 sokkycakes
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF MIND, USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/** @file tf_common.qc
Everything the template's game modes share: RED and BLU, class selection,
respawn waves, the round state machine, scoring and the HUD state.

A mode file (tf_ctf.qc, tf_cp.qc, tf_koth.qc) is compiled together with this
one and provides:

	string Mode_Name(void);            short name: "ctf", "cp", "koth"
	void Mode_Init(void);              once per map, after objectives spawned
	void Mode_RoundStart(void);        each round, after objectives reset
	float Mode_SetupTime(void);        seconds of setup before the round, 0 for none
	float Mode_RoundTime(void);        round length in seconds, 0 for no limit
	void Mode_Frame(void);             every frame while the round is active
	float Mode_TimeUp(void);           the round timer ran out: return the
	                                   winning team, 0 for a stalemate or -1
	                                   to keep playing (overtime)
	void Mode_Event(entity, string, string);  objective events, see below
	void Mode_HUD(void);               publish mode-specific serverinfo for the HUD

Objective events come from the server entities through CodeCallback_Input:
TF_FlagPickup, TF_FlagDropped, TF_FlagReturned, TF_FlagCaptured (data: the
flag's team), TF_PointCaptured (data: "<index> <team>"), TF_PlayerCapped
(data: point index, one per capper).

A mode can also define TFRules_AllowFlagCapture(entity carrier) and
TFRules_AllowPointCapture(entity point, float team) to veto captures.
*/

/* provided by the mode file */
string Mode_Name(void);
void Mode_Init(void);
void Mode_RoundStart(void);
float Mode_SetupTime(void);
float Mode_RoundTime(void);
void Mode_Frame(void);
float Mode_TimeUp(void);
void Mode_Event(entity, string, string);
void Mode_HUD(void);
void TF_PlayerFrames(void);

var string autocvar_tf_classes = "tfclass_scout tfclass_soldier tfclass_pyro tfclass_demoman tfclass_heavy tfclass_engineer tfclass_medic tfclass_sniper tfclass_spy";
var float autocvar_tf_respawnwave = 10.0f;
var float autocvar_tf_respawnmin = 2.0f;
var float autocvar_tf_preround = 5.0f;
var float autocvar_tf_bonustime = 10.0f;
var float autocvar_tf_winlimit = 3.0f;
var float autocvar_tf_waitforplayers = 1.0f;
var float autocvar_tf_autobalance = 1.0f;
var float autocvar_tf_debug = 0.0f;

/* server progs functions, linked in TFRules_Link() */
var bool(void) TFServer_LoadOverlay;
var void(void) TFServer_ResetObjectives;
var void(float) TFServer_LockAllPoints;
var string(void) TFServer_ObjectiveSummary;
var string(entity, string) TFServer_ClassDefFor;
var void(entity) TFServer_Resupply;
var void(entity) TFServer_PlayerThink;
var bool(string) TFServer_TestCommand;
var entity(entity) TFServer_NextObjective;

/* optional bot hooks, present when a bot framework is compiled into the
   server progs */
var void(entity, entity, entity, float) BWHook_NotifyInjured;
var void(entity, entity, entity, float) BWHook_NotifyKilled;
var void(entity) BWHook_BotRespawned;
var float(string) BWHook_ConsoleCommand;

float g_tfRoundState;
float g_tfStateStart;
float g_tfRoundEnds;		/* 0 when the round has no time limit */
float g_tfRoundWinner;
float g_tfRoundWins[3];
float g_tfNextWave[3];
float g_tfNextHUD;
bool g_tfStarted; /* the frame callback runs before StartGameType does */

void
TFRules_Link(void)
{
	TFServer_LoadOverlay = externvalue(0, "TF_LoadOverlay");
	TFServer_ResetObjectives = externvalue(0, "TF_ResetObjectives");
	TFServer_LockAllPoints = externvalue(0, "TF_LockAllPoints");
	TFServer_ObjectiveSummary = externvalue(0, "TF_ObjectiveSummary");
	TFServer_ClassDefFor = externvalue(0, "TF_ClassDefFor");
	TFServer_Resupply = externvalue(0, "TF_Resupply");
	TFServer_PlayerThink = externvalue(0, "TF_PlayerThink");
	TFServer_TestCommand = externvalue(0, "TF_TestCommand");
	TFServer_NextObjective = externvalue(0, "TF_NextObjective");

	BWHook_NotifyInjured = externvalue(0, "bw_notify_injured");
	BWHook_NotifyKilled = externvalue(0, "bw_notify_killed");
	BWHook_BotRespawned = externvalue(0, "bw_bot_respawned");
	BWHook_ConsoleCommand = externvalue(0, "bw_console_command");

	if (!TFServer_ResetObjectives) {
		error("The TF template rules need the template server progs (tftemplate/progs.dat).\n");
	}
}

void
TF_Debug(string message)
{
	if (autocvar_tf_debug) {
		print(sprintf("^3[tf %.1f]^7 %s\n", time, message));
	}
}

void
TF_Announce(string message)
{
	bprint(PRINT_HIGH, strcat(message, "\n"));
	TF_Debug(message);
}

entity
TF_FindPlayer(string playerName)
{
	for (entity e = world; (e = nextent(e));) {
		if ((e.flags & FL_CLIENT) && strtolower(e.netname) == strtolower(playerName)) {
			return (e);
		}
	}

	return (world);
}

/* ---- classes ----------------------------------------------------------- */

bool
TF_IsClass(string className)
{
	int classCount = tokenize_console(autocvar_tf_classes);

	for (int i = 0i; i < classCount; i++) {
		if (argv(i) == className) {
			return (true);
		}
	}

	return (false);
}

string
TF_ClassTitle(string className)
{
	/* "tfclass_heavy" -> "heavy" */
	if (substring(className, 0, 8) == "tfclass_") {
		return substring(className, 8, -1);
	}

	return (className);
}

/* ---- spawning ---------------------------------------------------------- */

bool
TF_HasTeam(entity playerEnt)
{
	return (playerEnt.team == TF_TEAM_RED || playerEnt.team == TF_TEAM_BLU) ? (true) : (false);
}

/** Puts a player into the world as their chosen class at a team spawn. */
void
TF_SpawnPlayer(entity playerEnt)
{
	if (TF_HasTeam(playerEnt) == false || !STRING_SET(playerEnt.tf_desiredClass)) {
		return;
	}

	string classDef = TFServer_ClassDefFor(playerEnt, playerEnt.tf_desiredClass);
	float playerTeam = playerEnt.team;

	ents.ChangeToClass(playerEnt, classDef);

	/* the class change re-runs the player's constructor; keep the team */
	if (playerEnt.team != playerTeam) {
		ents.Input(playerEnt, "SetTeam", ftos(playerTeam), playerEnt);
	}

	if (playerTeam == TF_TEAM_RED) {
		userinfo.SetString(playerEnt, "topcolor", "0xff1800");
		userinfo.SetString(playerEnt, "bottomcolor", "0xff1800");
	} else {
		userinfo.SetString(playerEnt, "topcolor", "0x9aff");
		userinfo.SetString(playerEnt, "bottomcolor", "0x9aff");
	}

	game.TeleportToSpawn(playerEnt);
	TFServer_Resupply(playerEnt);
	TF_Debug(sprintf("spawned %s as %s on %s", playerEnt.netname, classDef, TF_TeamName(playerTeam)));

	if (is.Bot(playerEnt) && BWHook_BotRespawned) {
		BWHook_BotRespawned(playerEnt);
	}
}

void
TF_MakeSpectator(entity playerEnt)
{
	ents.ChangeToClass(playerEnt, "spectator");
	game.TeleportToSpawn(playerEnt);
}

/** Respawns everyone on a team who has a class, alive or dead. */
void
TF_RespawnAll(void)
{
	for (entity e = world; (e = nextent(e));) {
		if (!(e.flags & FL_CLIENT)) {
			continue;
		}

		if (TF_HasTeam(e) && STRING_SET(e.tf_desiredClass)) {
			TF_SpawnPlayer(e);
		}
	}
}

/** Respawn waves: every tf_respawnwave seconds each team's dead players who
have been dead for at least tf_respawnmin come back. Outside an active round
they come back after tf_respawnmin. */
void
TF_RespawnWaves(void)
{
	bool waveDue[3];

	for (int t = 1; t <= 2; t++) {
		waveDue[t] = false;

		if (g_tfRoundState != TFROUND_ACTIVE && g_tfRoundState != TFROUND_SETUP) {
			waveDue[t] = true;
		} else if (time >= g_tfNextWave[t]) {
			waveDue[t] = true;
			g_tfNextWave[t] = time + autocvar_tf_respawnwave;
		}
	}

	/* nobody respawns while the winners hunt the losers */
	if (g_tfRoundState == TFROUND_WIN || g_tfRoundState == TFROUND_STALEMATE) {
		return;
	}

	for (entity e = world; (e = nextent(e));) {
		if (!(e.flags & FL_CLIENT)) {
			continue;
		}

		if (TF_HasTeam(e) == false) {
			continue;
		}

		/* bots that never managed to pick a class get a random one */
		if (!STRING_SET(e.tf_desiredClass)) {
			if (is.Bot(e) == false) {
				continue;
			}

			float classCount = tokenize_console(autocvar_tf_classes);
			e.tf_desiredClass = argv(floor(random(0, classCount)));
		}

		if (is.Alive(e)) {
			continue;
		}

		if (waveDue[e.team] && (time - e.tf_deathTime) >= autocvar_tf_respawnmin) {
			TF_SpawnPlayer(e);
		}
	}
}

/* ---- rounds ------------------------------------------------------------ */

string
TF_RoundStateName(float roundState)
{
	switch (roundState) {
	case TFROUND_WAITING:
		return ("waiting");
	case TFROUND_PREROUND:
		return ("preround");
	case TFROUND_SETUP:
		return ("setup");
	case TFROUND_ACTIVE:
		return ("active");
	case TFROUND_WIN:
		return ("win");
	case TFROUND_STALEMATE:
		return ("stalemate");
	}

	return ("unknown");
}

void
TF_SetRoundState(float newState)
{
	g_tfRoundState = newState;
	g_tfStateStart = time;
	serverinfo.SetInteger("tf_round", (int)newState);
	TF_Debug(sprintf("round state: %s", TF_RoundStateName(newState)));
}

void
TF_StartRound(void)
{
	g_tfRoundWinner = TF_TEAM_NONE;
	TFServer_ResetObjectives();
	Mode_RoundStart();
	TF_RespawnAll();
	g_tfRoundEnds = 0;
	g_tfNextWave[1] = g_tfNextWave[2] = 0;
	TF_SetRoundState(TFROUND_PREROUND);
	TF_Announce("Get ready!");
}

/** Ends the round. `winningTeam` 0 is a stalemate. */
void
TF_RoundWin(float winningTeam, string reason)
{
	if (g_tfRoundState == TFROUND_WIN || g_tfRoundState == TFROUND_STALEMATE) {
		return;
	}

	g_tfRoundWinner = winningTeam;
	g_tfRoundEnds = 0;

	if (winningTeam == TF_TEAM_NONE) {
		TF_Announce(sprintf("Stalemate! %s", reason));
		TF_SetRoundState(TFROUND_STALEMATE);
		return;
	}

	g_tfRoundWins[winningTeam] += 1;
	serverinfo.SetString("tf_wins", sprintf("%d %d", g_tfRoundWins[1], g_tfRoundWins[2]));
	TF_Announce(sprintf("%s wins the round! %s", TF_TeamName(winningTeam), reason));
	TF_SetRoundState(TFROUND_WIN);
}

void
TF_RoundFrame(void)
{
	float stateTime = time - g_tfStateStart;

	switch (g_tfRoundState) {
	case TFROUND_WAITING:
		if (autocvar_tf_waitforplayers == 0 || (teams.NumPlayers(1) > 0 && teams.NumPlayers(2) > 0)) {
			TF_StartRound();
		}
		break;
	case TFROUND_PREROUND:
		if (stateTime >= autocvar_tf_preround) {
			if (Mode_SetupTime() > 0) {
				TF_SetRoundState(TFROUND_SETUP);
				g_tfRoundEnds = time + Mode_SetupTime();
				TF_Announce("Setup time!");
			} else {
				TF_SetRoundState(TFROUND_ACTIVE);
				g_tfRoundEnds = (Mode_RoundTime() > 0) ? (time + Mode_RoundTime()) : 0;
				TF_Announce("Fight!");
			}
		}
		break;
	case TFROUND_SETUP:
		if (time >= g_tfRoundEnds) {
			TF_SetRoundState(TFROUND_ACTIVE);
			g_tfRoundEnds = (Mode_RoundTime() > 0) ? (time + Mode_RoundTime()) : 0;
			TF_Announce("Fight!");
		}
		break;
	case TFROUND_ACTIVE:
		Mode_Frame();

		if (g_tfRoundState == TFROUND_ACTIVE && g_tfRoundEnds > 0 && time >= g_tfRoundEnds) {
			float timeWinner = Mode_TimeUp();

			if (timeWinner >= 0) {
				TF_RoundWin(timeWinner, "Time ran out.");
			}
		}
		break;
	case TFROUND_WIN:
	case TFROUND_STALEMATE:
		if (stateTime >= autocvar_tf_bonustime) {
			if (autocvar_tf_winlimit > 0 && (g_tfRoundWins[1] >= autocvar_tf_winlimit || g_tfRoundWins[2] >= autocvar_tf_winlimit)) {
				TF_Announce("The match is over.");
				game.EndMap();
				TF_SetRoundState(TFROUND_WAITING);
				g_tfStateStart = time + 9999;
			} else {
				TF_StartRound();
			}
		}
		break;
	}
}

/** Adds seconds to the round timer, e.g. when attackers capture a point. */
void
TF_AddRoundTime(float extraSeconds)
{
	if (g_tfRoundEnds > 0) {
		g_tfRoundEnds += extraSeconds;
	}
}

/** Whether objectives may be played right now. */
bool
TF_ObjectivesLive(void)
{
	return (g_tfRoundState == TFROUND_ACTIVE) ? (true) : (false);
}

/* ---- HUD --------------------------------------------------------------- */

void
TF_UpdateHUD(void)
{
	if (time < g_tfNextHUD) {
		return;
	}

	g_tfNextHUD = time + 0.2f;

	float timeLeft = (g_tfRoundEnds > 0) ? max(0, ceil(g_tfRoundEnds - time)) : -1;
	string objectives = TFServer_ObjectiveSummary();

	if (serverinfo.GetString("tf_obj") != objectives) {
		serverinfo.SetString("tf_obj", objectives);
	}

	if (serverinfo.GetFloat("tf_timer") != timeLeft) {
		serverinfo.SetFloat("tf_timer", timeLeft);
	}

	Mode_HUD();
}

/* ---- Nuclide rules callbacks ------------------------------------------- */

void
CodeCallback_Precaches(void)
{
	Util_SharedPrecaches();
}

void
CodeCallback_StartGameType(void)
{
	TFRules_Link();
	motd.LoadDefault();
	game.SetSpawnPoint("info_player_deathmatch");

	teams.SetUp(TF_TEAM_RED, "RED", [255, 64, 64], true);
	teams.SetUp(TF_TEAM_BLU, "BLU", [100, 160, 255], true);

	/* team spawns, or the deathmatch spawns on maps without them */
	if (find(world, ::classname, "info_player_team1") && find(world, ::classname, "info_player_team2")) {
		teams.SetSpawnPoint(TF_TEAM_RED, "info_player_team1");
		teams.SetSpawnPoint(TF_TEAM_BLU, "info_player_team2");
	} else {
		teams.SetSpawnPoint(TF_TEAM_RED, "info_player_deathmatch");
		teams.SetSpawnPoint(TF_TEAM_BLU, "info_player_deathmatch");
	}

	int classCount = tokenize_console(autocvar_tf_classes);

	for (int i = 0i; i < classCount; i++) {
		string className = argv(i);
		teams.AddClass(TF_TEAM_RED, className);
		teams.AddClass(TF_TEAM_BLU, className);
		/* AddClass may tokenize, so read the list again */
		tokenize_console(autocvar_tf_classes);
	}

	Util_RemoveAllMonsters();
	Util_SetItemRespawnTimers();

	TFServer_LoadOverlay();
	serverinfo.SetString("tf_mode", Mode_Name());
	serverinfo.SetString("tf_wins", "0 0");
	g_tfRoundWins[1] = g_tfRoundWins[2] = 0;
	Mode_Init();
	TF_SetRoundState(TFROUND_WAITING);
	g_tfStarted = true;
}

void
CodeCallback_FrameStart(void)
{
	if (g_tfStarted == false) {
		return;
	}

	TF_RoundFrame();
	TF_RespawnWaves();
	TF_PlayerFrames();
	TF_UpdateHUD();
}

void
CodeCallback_PlayerSpawn(entity playerEntity)
{
	/* first connect: watch until a team and class are picked */
	TF_Debug(sprintf("%s connected", playerEntity.netname));
	playerEntity.tf_desiredClass = __NULL__;
	TF_MakeSpectator(playerEntity);
}

void
CodeCallback_PlayerDisconnect(entity playerEntity)
{
	playerEntity.tf_desiredClass = __NULL__;
}

bool
CodeCallback_PlayerRequestRespawn(entity playerEntity)
{
	/* respawning is handled by the waves; ask for a team/class if missing */
	if (TF_HasTeam(playerEntity) == false && is.Bot(playerEntity) == false) {
		stuffcmd(playerEntity, "showTeamSelectionMenu\n");
	} else if (!STRING_SET(playerEntity.tf_desiredClass) && is.Bot(playerEntity) == false) {
		stuffcmd(playerEntity, "showClassSelectionMenu\n");
	}

	return (true);
}

bool
CodeCallback_CallRequestTeam(entity playerEntity, int teamNum)
{
	/* the client asked before it was put into the game */
	if (!STRING_SET(playerEntity.classname)) {
		return (true);
	}

	if (teamNum == TEAM_SPECTATOR) {
		if (is.Alive(playerEntity)) {
			ents.Input(playerEntity, "Damage", "1000", playerEntity);
		}

		ents.Input(playerEntity, "SetTeam", itos(TEAM_SPECTATOR), playerEntity);
		playerEntity.tf_desiredClass = __NULL__;
		TF_MakeSpectator(playerEntity);
		return (true);
	}

	if (teamNum != TF_TEAM_RED && teamNum != TF_TEAM_BLU) {
		teamNum = teams.BestAutoJoinTeam();
	}

	if (playerEntity.team == teamNum) {
		return (true);
	}

	/* don't let a team get more than one player ahead */
	if (autocvar_tf_autobalance) {
		float ourCount = teams.NumPlayers(teamNum);
		float theirCount = teams.NumPlayers((int)TF_EnemyTeam(teamNum));

		if (TF_HasTeam(playerEntity)) {
			theirCount -= 1; /* we're leaving that team */
		}

		if (ourCount > theirCount) {
			sprint(playerEntity, PRINT_HIGH, sprintf("%s has too many players.\n", TF_TeamName(teamNum)));
			return (true);
		}
	}

	if (is.Alive(playerEntity)) {
		ents.Input(playerEntity, "Damage", "1000", playerEntity);
	}

	ents.Input(playerEntity, "SetTeam", itos(teamNum), playerEntity);
	playerEntity.tf_deathTime = time;
	TF_Debug(sprintf("%s joined %s", playerEntity.netname, TF_TeamName(teamNum)));
	return (true);
}

void
TF_ChooseClass(entity playerEntity, string className)
{
	if (TF_IsClass(className) == false) {
		/* the class list in serverinfo can be cut off at the engine's info
		   length limit, so a bot may ask for a partial name: give it any
		   valid class instead */
		if (is.Bot(playerEntity) == false) {
			sprint(playerEntity, PRINT_HIGH, sprintf("Unknown class %S.\n", className));
			return;
		}

		float classCount = tokenize_console(autocvar_tf_classes);
		className = argv(floor(random(0, classCount)));
	}

	if (TF_HasTeam(playerEntity) == false) {
		CodeCallback_CallRequestTeam(playerEntity, teams.BestAutoJoinTeam());

		if (TF_HasTeam(playerEntity) == false) {
			return;
		}
	}

	TF_Debug(sprintf("%s chose %s", playerEntity.netname, className));
	bool firstClass = STRING_SET(playerEntity.tf_desiredClass) ? false : true;
	playerEntity.tf_desiredClass = className;

	/* first pick, waiting for players, or standing in the respawn room:
	   change right away. otherwise on the next life, as in TF2. */
	if (is.Alive(playerEntity) == false) {
		if (firstClass || g_tfRoundState == TFROUND_WAITING || g_tfRoundState == TFROUND_PREROUND) {
			TF_SpawnPlayer(playerEntity);
		}
	} else if (g_tfRoundState == TFROUND_WAITING || g_tfRoundState == TFROUND_PREROUND || (time - playerEntity.tf_inRespawnRoom) < 0.5f) {
		TF_SpawnPlayer(playerEntity);
	} else {
		sprint(playerEntity, PRINT_HIGH, sprintf("You will respawn as %s.\n", TF_ClassTitle(className)));
	}
}

bool
CodeCallback_ClientCommand(entity playerEntity, string command)
{
	tokenize_console(command);

	switch (argv(0)) {
	case "join":
	case "joinclass":
		TF_ChooseClass(playerEntity, argv(1));
		break;
	case "tf_status":
		sprint(playerEntity, PRINT_HIGH, sprintf("mode %s, round %s, wins RED %d BLU %d, objectives:%s\n",
			Mode_Name(), TF_RoundStateName(g_tfRoundState), g_tfRoundWins[1], g_tfRoundWins[2],
			TFServer_ObjectiveSummary()));
		break;
	default:
		return (false);
	}

	return (true);
}

bool
CodeCallback_ConsoleCommand(entity playerEntity, string command)
{
	tokenize_console(command);

	if (g_tfStarted == false && substring(argv(0), 0, 3) == "tf_") {
		print("The TF template rules haven't started yet.\n");
		return (true);
	}

	switch (argv(0)) {
	case "tf_status":
		print(sprintf("mode %s, round %s, wins RED %d BLU %d, timer %d, objectives:%s\n",
			Mode_Name(), TF_RoundStateName(g_tfRoundState), g_tfRoundWins[1], g_tfRoundWins[2],
			serverinfo.GetFloat("tf_timer"), TFServer_ObjectiveSummary()));
		break;
	case "tf_restartround":
		TF_StartRound();
		break;
	case "tf_forcewin":
		TF_RoundWin(stof(argv(1)), "Forced from the console.");
		break;
	/* test hooks: tf_test_pin <player> <targetname> keeps a player standing
	   on an entity (a flag, zone or point) until unpinned with no target */
	case "tf_test_pin":
		entity pinPlayer = TF_FindPlayer(argv(1));
		entity pinTarget = STRING_SET(argv(2)) ? find(world, ::targetname, argv(2)) : world;

		if (!pinPlayer) {
			print(sprintf("tf_test_pin: no player %S\n", argv(1)));
		} else {
			pinPlayer.tf_testPin = pinTarget;
			pinPlayer.tf_testPinPos = pinTarget.origin;
			print(sprintf("tf_test_pin: %s -> %s\n", pinPlayer.netname, pinTarget ? pinTarget.targetname : "nothing"));
		}
		break;
	case "tf_test_kill":
		entity killPlayer = TF_FindPlayer(argv(1));

		if (killPlayer && is.Alive(killPlayer)) {
			ents.Input(killPlayer, "Damage", "1000", killPlayer);
		}
		break;
	case "tf_test_players":
		for (entity e = world; (e = nextent(e));) {
			if (e.flags & FL_CLIENT) {
				print(sprintf("%s: team %s class %s alive %d health %d origin %v flag %d\n", e.netname,
					TF_TeamName(e.team), e.classname, is.Alive(e), e.health, e.origin, e.tf_carriedFlag ? e.tf_carriedFlag.team : 0));
			}
		}
		break;
	default:
		/* the rest of the tf_test_* commands live in the server progs */
		if (TFServer_TestCommand && TFServer_TestCommand(command)) {
			break;
		}

		/* the bot framework's commands (bot_status, bot_debug ...) */
		if (BWHook_ConsoleCommand) {
			return BWHook_ConsoleCommand(command) ? (true) : (false);
		}

		return (false);
	}

	return (true);
}

/* per-player upkeep. Nuclide's PlayerPreFrame callback isn't reliably
   called for every player, so this runs from FrameStart instead. */
void
TF_PlayerFrames(void)
{
	for (entity e = world; (e = nextent(e));) {
		if (!(e.flags & FL_CLIENT)) {
			continue;
		}

		TFServer_PlayerThink(e);

		if (e.tf_testPin && is.Alive(e)) {
			setorigin(e, e.tf_testPinPos + [0, 0, 32]);
			e.velocity = [0, 0, 0];
		}
	}
}

void
CodeCallback_PlayerDamage(entity playerTarget, entity attacker, entity damageDecl)
{
	if (BWHook_NotifyInjured) {
		BWHook_NotifyInjured(playerTarget, attacker, attacker, 0);
	}
}

void
CodeCallback_PlayerKilled(entity playerTarget, entity inflictor, entity attacker, string weapon)
{
	combat.Obituary(playerTarget.netname, attacker.netname, weapon, "");
	playerTarget.deaths++;
	playerTarget.tf_deathTime = time;

	if (is.Player(attacker)) {
		if (playerTarget == attacker) {
			attacker.frags--;
		} else if (attacker.team != playerTarget.team) {
			attacker.frags++;
		}
	}

	if (BWHook_NotifyKilled) {
		BWHook_NotifyKilled(playerTarget, inflictor, attacker, 0);
	}
}

void
CodeCallback_Input(entity activator, string inputName, string dataString)
{
	TF_Debug(sprintf("event %s (%s) from %s", inputName, dataString, activator.netname));

	/* objective play only counts while the round is live */
	if (substring(inputName, 0, 3) == "TF_") {
		Mode_Event(activator, inputName, dataString);
	}
}
