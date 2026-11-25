/*
 * Copyright (c) 2026 Marco Cawthorne <marco@icculus.org>
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

#include "arena.h"

/* =========================================================================
 * Arena match director implementation.
 * See arena.h for the public contract and hook documentation.
 *
 * g_arenaState / g_arenaStateTime change only inside Arena_Transition.
 * Participation changes go through Arena_ChangeParticipation.
 * ========================================================================= */

/* --- director state --- */
var int g_arenaState;
var int g_arenaShape;
var int g_arenaPromo;
var int g_arenaRoundLimit;
var int g_arenaSlotCount;
var int g_arenaMinReady;
var int g_arenaRound;
var float g_arenaStateTime;
var float g_arenaDeadline;
var float g_arenaRoundDeadline;
var float g_arenaLiveSince;
var float g_arenaNextBroadcast;
var int g_arenaCountdownLast;
var float g_arenaRoundCountdownTime;	/* 0 = same duration as match-start */
var float g_arenaRoundCountdownStep;	/* 1s ticks unless a mode sets otherwise */
var bool g_arenaSuddenNoTimer;
var bool g_arenaTiebreaker;
var bool g_arenaMatchHasGoneLive;
var bool g_arenaAutoJoin;
var string g_arenaSpawnClass;
var int g_arenaResult;
var int g_arenaWinnerSlot;
var int g_arenaRoundResult;
var int g_arenaRoundWinnerSlot;
var int g_arenaLastReason;
var int g_arenaTransitionFrom;

entity g_arenaCompetitor[ARENA_MAXSLOTS];
var int g_arenaPoints[ARENA_MAXSLOTS];

entity g_arenaQueue[ARENA_MAXQUEUE];
var int g_arenaQueueCount;

/* --- set play state (see arena.h) --- */
var int g_setFirstTo;			/* 0 = no set play */
var int g_setWins[3];			/* by side, 1 and 2 */
var int g_setGame;				/* 1-based game of the current set, 0 = no set */
var int g_setRunbacks;			/* rematches in a row between these competitors */
var int g_setResult;
var int g_setWinnerSide;
var int g_setCounterSide;		/* SELECT: only this side may change hero (0 = both) */
var string g_setLog;
var int g_setSerial;
var string g_setClosed;
var string g_setLeft;
var int g_setLock[ARENA_MAXSLOTS];
var int g_setVote[ARENA_MAXSLOTS];
var int g_setGamesWon[ARENA_MAXSLOTS];
entity g_setSeat[ARENA_MAXSLOTS];		/* who sat in each slot this set (survives a departure) */
var int g_arenaDepartSlot = -1;

static int
Arena_PlayerState(entity pl)
{
	return ((int)userinfo.GetFloat(pl, "*arena_state"));
}

static void
Arena_SetPlayerState(entity pl, int state)
{
	userinfo.SetFloat(pl, "*arena_state", state);
}

void Arena_SpawnCompetitor(entity pl, int slot);
void Arena_SpawnFreeplay(entity pl);
void Arena_EnsureFreeplay(entity pl);
void Arena_DemoteToFakeSpec(entity pl);
void Arena_SpawnWaitingView(entity pl);
static void Arena_MakePureSpectator(entity pl);
static void Arena_Transition(int newState, int reason);
static void Arena_ValidateInvariants(void);
static void Arena_CancelPendingMatchup(int reason);
static void Arena_VoidMatch(int reason);
static void Arena_SetupRound(void);
static void Arena_AssignSlot(entity pl, int slot);
static void Arena_ReleaseSlot(entity pl);
static void Arena_ClearMatchBookkeeping(void);
static void Arena_SetForfeit(int departSlot);
static void Arena_SetClose(string why);
static void Arena_SetReport(void);
static void Arena_BeginGame(void);

/* =========================================================================
 * Configuration
 * ========================================================================= */
void
Arena_Configure(int teamShape, int promotionPolicy, int roundLimit)
{
	g_arenaShape = teamShape;
	g_arenaPromo = promotionPolicy;
	g_arenaRoundLimit = (roundLimit > 0) ? roundLimit : 1;

	switch (teamShape) {
	case ARENASHAPE_2V2:
		g_arenaSlotCount = 4;
		break;
	case ARENASHAPE_BOSS:
		g_arenaSlotCount = 2;
		break;
	case ARENASHAPE_1V1:
	default:
		g_arenaSlotCount = 2;
		break;
	}

	g_arenaMinReady = g_arenaSlotCount;
	g_arenaAutoJoin = false;

	g_setFirstTo = (int)autocvar_arena_setFirstTo;
	if (g_setFirstTo < 0i) {
		g_setFirstTo = 0i;
	}
	g_setGame = 0i;
	g_setRunbacks = 0i;
	g_setResult = SETRESULT_NONE;
	g_setSerial = 0i;
	g_setClosed = "";
	g_setLeft = "";
	g_setLog = "";
	g_arenaSpawnClass = "";
	g_arenaRoundCountdownTime = 0.0f;
	g_arenaRoundCountdownStep = 1.0f;

	precache_sound("common/countdown.ogg");
	precache_sound("common/countdown-end.ogg");
	precache_sound("common/countdown-mini.ogg");
	precache_sound("common/countdown-end-mini.ogg");

	g_arenaQueueCount = 0;
	g_arenaRound = 0;
	g_arenaSuddenNoTimer = false;
	g_arenaTiebreaker = false;
	g_arenaMatchHasGoneLive = false;
	g_arenaResult = ARENARESULT_NONE;
	g_arenaWinnerSlot = 0;
	g_arenaRoundResult = ARENARESULT_NONE;
	g_arenaRoundWinnerSlot = 0;
	g_arenaLastReason = ARENAREASON_NORMAL;

	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		g_arenaCompetitor[i] = __NULL__;
		g_arenaPoints[i] = 0i;
	}

	Arena_Transition(ARENA_WARMUP, ARENAREASON_NORMAL);
}

void
Arena_SetHooks(void() roundStart, void(entity, entity) playerDeath, int() roundWinTest, void() roundEnd, void() suddenDeath, void() suddenDeathTick, void(entity) playerPain)
{
	g_arenaHook_RoundStart = roundStart;
	g_arenaHook_PlayerDeath = playerDeath;
	g_arenaHook_RoundWinTest = roundWinTest;
	g_arenaHook_RoundEnd = roundEnd;
	g_arenaHook_SuddenDeath = suddenDeath;
	g_arenaHook_SuddenDeathTick = suddenDeathTick;
	g_arenaHook_PlayerPain = playerPain;
}

void
Arena_SetAutoJoin(bool enabled)
{
	/* set play is always matchmade: whoever connects is there to play */
	g_arenaAutoJoin = enabled || (g_setFirstTo > 0i);
}

bool
Arena_SetPlay(void)
{
	return (g_setFirstTo > 0i);
}

static int
Arena_SideForSlot(int slot)
{
	if (g_arenaShape == ARENASHAPE_2V2) {
		return ((slot < (g_arenaSlotCount / 2i)) ? 1i : 2i);
	}
	return ((slot == 0i) ? 1i : 2i);
}

void
Arena_SetRoundCountdown(float count, float step)
{
	if (step <= 0.0f) {
		step = 1.0f;
	}
	g_arenaRoundCountdownStep = step;
	if (count > 0.0f) {
		g_arenaRoundCountdownTime = count * step;
	} else {
		g_arenaRoundCountdownTime = 0.0f;
	}
}

void
Arena_SetSpawnClass(string className)
{
	g_arenaSpawnClass = className;
}

/* =========================================================================
 * FIFO ready-queue primitives (single insert/remove path)
 * ========================================================================= */
static bool
Arena_InQueue(entity pl)
{
	for (int i = 0i; i < g_arenaQueueCount; i++) {
		if (g_arenaQueue[i] == pl) {
			return (true);
		}
	}
	return (false);
}

static void
Arena_QueueRemove(entity pl)
{
	int dst = 0i;
	for (int i = 0i; i < g_arenaQueueCount; i++) {
		if (g_arenaQueue[i] != pl) {
			g_arenaQueue[dst] = g_arenaQueue[i];
			dst++;
		}
	}
	g_arenaQueueCount = dst;
}

static void
Arena_QueueAppend(entity pl)
{
	if (!pl || Arena_InQueue(pl)) {
		return;
	}
	if (g_arenaQueueCount >= ARENA_MAXQUEUE) {
		return;
	}
	g_arenaQueue[g_arenaQueueCount] = pl;
	g_arenaQueueCount++;
}

static void
Arena_QueuePushFront(entity pl)
{
	if (!pl || Arena_InQueue(pl)) {
		return;
	}
	if (g_arenaQueueCount >= ARENA_MAXQUEUE) {
		return;
	}
	for (int i = g_arenaQueueCount; i > 0i; i--) {
		g_arenaQueue[i] = g_arenaQueue[i - 1i];
	}
	g_arenaQueue[0] = pl;
	g_arenaQueueCount++;
}

static entity
Arena_QueuePopFront(void)
{
	if (g_arenaQueueCount <= 0i) {
		return (__NULL__);
	}
	entity result = g_arenaQueue[0];
	for (int i = 1i; i < g_arenaQueueCount; i++) {
		g_arenaQueue[i - 1i] = g_arenaQueue[i];
	}
	g_arenaQueueCount--;
	g_arenaQueue[g_arenaQueueCount] = __NULL__;
	return (result);
}

static void
Arena_AssignSlot(entity pl, int slot)
{
	Arena_QueueRemove(pl);
	g_arenaCompetitor[slot] = pl;
	Arena_SetPlayerState(pl, ARENASTATE_COMPETITOR);
}

static void
Arena_ReleaseSlot(entity pl)
{
	int slot = Arena_SlotForPlayer(pl);
	if (slot >= 0i) {
		g_arenaCompetitor[slot] = __NULL__;
	}
}

static void
Arena_ClearMatchBookkeeping(void)
{
	g_arenaRound = 0;
	g_arenaTiebreaker = false;
	g_arenaSuddenNoTimer = false;
	g_arenaMatchHasGoneLive = false;
	g_arenaResult = ARENARESULT_NONE;
	g_arenaWinnerSlot = 0;
	g_arenaRoundResult = ARENARESULT_NONE;
	g_arenaRoundWinnerSlot = 0;
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		g_arenaPoints[i] = 0i;
	}
}

/* =========================================================================
 * Queries
 * ========================================================================= */
int
Arena_GetState(void)
{
	return (g_arenaState);
}

int
Arena_GetPlayerState(entity pl)
{
	return (Arena_PlayerState(pl));
}

int
Arena_GetResult(void)
{
	return (g_arenaResult);
}

int
Arena_GetWinnerSlot(void)
{
	return (g_arenaWinnerSlot);
}

entity
Arena_CompetitorAt(int slot)
{
	if (slot < 0i || slot >= ARENA_MAXSLOTS) {
		return (__NULL__);
	}
	return (g_arenaCompetitor[slot]);
}

int
Arena_ReadyCount(void)
{
	return (g_arenaQueueCount);
}

int
Arena_CompetitorCount(void)
{
	int total = 0i;
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		if (g_arenaCompetitor[i]) {
			total++;
		}
	}
	return (total);
}

int
Arena_SlotForPlayer(entity pl)
{
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		if (g_arenaCompetitor[i] == pl) {
			return (i);
		}
	}
	return (-1i);
}

bool
Arena_IsCompetitor(entity pl)
{
	return (Arena_SlotForPlayer(pl) != -1i);
}

/* =========================================================================
 * Player-state transitions (spawning / spectating)
 * Nuclide owns the player shell. Waiting/queued players never ChangeToClass
 * spectator — that give/destroy cycle leaves CSQC with half-built weapons.
 * ========================================================================= */

void
Arena_SpawnFreeplay(entity pl)
{
	/* anchor on team 1 so TeleportToSpawn uses DM points, not intermission cam */
	if (teams.Valid((int)pl.team) == false) {
		ents.Input(pl, "SetTeam", "1", pl);
	}

	/* Same class policy as Arena_SpawnCompetitor — do not clobber a hero pick
	 * with player_mp (that made every selection look like the team default). */
	if (STRING_SET(g_arenaSpawnClass)) {
		ents.ChangeToClass(pl, g_arenaSpawnClass);
	} else {
		ents.ChangeToClass(pl, Hero_ResolveSpawnHero(pl));
	}

	game.TeleportToSpawnClass(pl, "info_player_deathmatch");
}

void
Arena_EnsureFreeplay(entity pl)
{
	string heroID;

	if (g_arenaState != ARENA_WARMUP) {
		return;
	}
	if (Arena_PlayerState(pl) == ARENASTATE_SPECTATOR || pl.team == TEAM_SPECTATOR) {
		return;
	}
	if (STRING_SET(userinfo.GetString(pl, "*hero")) == false) {
		return;
	}

	heroID = Hero_ResolveSpawnHero(pl);
	if (is.Alive(pl) && pl.classname == heroID) {
		return;
	}

	Arena_SpawnFreeplay(pl);
}

void
Arena_SpawnCompetitor(entity pl, int slot)
{
	int teamNum;

	if (g_arenaShape == ARENASHAPE_1V1) {
		teamNum = slot + 1i;
	} else {
		teamNum = (slot < (g_arenaSlotCount / 2i)) ? 1i : 2i;
	}

	ents.Input(pl, "SetTeam", itos(teamNum), pl);

	if (STRING_SET(g_arenaSpawnClass)) {
		ents.ChangeToClass(pl, g_arenaSpawnClass);
	} else {
		ents.ChangeToClass(pl, Hero_ResolveSpawnHero(pl));
	}

	game.TeleportToSpawn(pl);
}

void
Arena_SpawnWaitingView(entity pl)
{
	float savedTeam = pl.team;

	/* Never ChangeToClass("spectator") for waiting. That helper is:
	 *   changeClass → "player" Spawn (Actor::Spawned GiveItem weapons)
	 *   then MakeTempSpectator (Destroy those weapons).
	 * Repeating that give/destroy cycle leaves CSQC with half-constructed
	 * weapon edicts (truthy m_activeWeapon, NULL ClientFX / missing VM).
	 *
	 * If we are already a player/hero shell, only MakeTempSpectator.
	 * ChangeToClass("player") is a last resort for a raw connect edict. */
	if (pl.classname != "player" && substring(pl.classname, 0, 5) != "hero_") {
		ents.ChangeToClass(pl, "player");
	}

	ents.Input(pl, "Spectate", "", pl);

	if (teams.Valid((int)savedTeam) == false) {
		savedTeam = 1;
	}
	ents.Input(pl, "SetTeam", itos((int)savedTeam), pl);
	game.TeleportToSpawnClass(pl, "info_intermission");
}

void
Arena_DemoteToFakeSpec(entity pl)
{
	ents.Input(pl, "Spectate", "", world);
}

static void
Arena_MakePureSpectator(entity pl)
{
	game.MakePureSpectator(pl);
	game.TeleportToSpawn(pl);
}

/* =========================================================================
 * Broadcast — after completed semantic mutations, plus throttled refresh
 * ========================================================================= */
static void
Arena_CenterprintAll(string msg)
{
	for (entity p = world; (p = next.Player(p));) {
		centerprint(p, msg);
	}
}

static string
Arena_StateName(void)
{
	switch (g_arenaState) {
	case ARENA_WARMUP:
		return ("WARMUP");
	case ARENA_COUNTDOWN:
		return ("COUNTDOWN");
	case ARENA_LIVE:
		return ("LIVE");
	case ARENA_SUDDEN_DEATH:
		return ("SUDDEN DEATH");
	case ARENA_ROUND_END:
		return ("ROUND END");
	case ARENA_MATCH_END:
		return ("MATCH END");
	case ARENA_SELECT:
		return ("SELECT");
	case ARENA_SET_END:
		return ("SET END");
	}
	return ("?");
}

static string
Arena_ResultName(int result)
{
	switch (result) {
	case ARENARESULT_WIN:
		return ("WIN");
	case ARENARESULT_DRAW:
		return ("DRAW");
	case ARENARESULT_VOID:
		return ("VOID");
	}
	return ("NONE");
}

static string
Arena_HeroIDs(void)
{
	string result = "";
	int total = teams.TotalClasses(1);

	for (int i = 0i; i < total; i++) {
		if (i > 0i) {
			result = strcat(result, " ");
		}
		result = strcat(result, teams.ClassForIndex(1, i));
	}

	return (result);
}

void
Arena_BroadcastState(void)
{
	serverinfo.SetString("arena_state", Arena_StateName());
	serverinfo.SetString("arena_round", sprintf("Round %i / %i", g_arenaRound, g_arenaRoundLimit));
	serverinfo.SetInteger("arena_ready", g_arenaQueueCount);
	serverinfo.SetString("arena_heroes", Arena_HeroIDs());
	serverinfo.SetInteger("arena_score1", g_arenaPoints[0]);
	serverinfo.SetInteger("arena_score2", g_arenaPoints[1]);
	serverinfo.SetString("arena_result", Arena_ResultName(g_arenaResult));
	serverinfo.SetInteger("arena_winner", g_arenaWinnerSlot);

	if (g_setFirstTo > 0i) {
		string locks = "";
		string votes = "";
		bool hidden = false;
		for (int s = 0i; s < g_arenaSlotCount; s++) {
			locks = strcat(locks, (s > 0i) ? " " : "", itos(g_setLock[s]));
			votes = strcat(votes, (s > 0i) ? " " : "", itos(g_setVote[s]));
		}
		/* picks stay hidden until every competitor has locked */
		if (g_arenaState == ARENA_SELECT) {
			hidden = false;
			for (int s2 = 0i; s2 < g_arenaSlotCount; s2++) {
				if (g_setLock[s2] == 0i) {
					hidden = true;
				}
			}
		}
		serverinfo.SetString("arena_set", strcat(
			sprintf("%i %i %i %i ", g_setFirstTo, g_setGame, g_setWins[1], g_setWins[2]),
			sprintf("%i %i %i %i", g_setRunbacks, g_setResult, g_setWinnerSide, g_setCounterSide)));
		serverinfo.SetInteger("arena_set_serial", g_setSerial);
		serverinfo.SetString("arena_set_closed", g_setClosed);
		serverinfo.SetString("arena_set_log", g_setLog);
		serverinfo.SetString("arena_set_left", g_setLeft);
		string ents = "";
		for (int e = 0i; e < g_arenaSlotCount; e++) {
			ents = strcat(ents, (e > 0i) ? " " : "", g_arenaCompetitor[e] ? itos((int)num_for_edict(g_arenaCompetitor[e])) : "0");
		}
		serverinfo.SetString("arena_ents", ents);
		serverinfo.SetString("arena_lock", locks);
		serverinfo.SetString("arena_vote", votes);
		if (g_arenaState == ARENA_SELECT || g_arenaState == ARENA_MATCH_END || g_arenaState == ARENA_SET_END) {
			serverinfo.SetInteger("arena_deadline", (int)ceil(max(0, g_arenaDeadline - time)));
		} else {
			serverinfo.SetString("arena_deadline", "");
		}
		for (int h = 0i; h < g_arenaSlotCount; h++) {
			entity hc = g_arenaCompetitor[h];
			string heroKey = sprintf("arena_hero%i", h + 1i);
			if (hc && hidden == false) {
				serverinfo.SetString(heroKey, userinfo.GetString(hc, "*hero"));
			} else {
				serverinfo.SetString(heroKey, "");
			}
		}
	}

	for (int i = 0i; i < 2i; i++) {
		entity c = g_arenaCompetitor[i];
		string slotKey = sprintf("arena_p%i", i + 1i);
		string nameKey = sprintf("arena_name%i", i + 1i);

		if (c) {
			serverinfo.SetString(slotKey, sprintf("%s (%i)", c.netname, g_arenaPoints[i]));
			serverinfo.SetString(nameKey, c.netname);
			c.frags = (float)g_arenaPoints[i];
		} else {
			serverinfo.SetString(slotKey, "");
			serverinfo.SetString(nameKey, "");
		}
	}
}

static void
Arena_BroadcastThrottled(void)
{
	if (g_arenaNextBroadcast > time) {
		return;
	}
	g_arenaNextBroadcast = time + 0.5f;
	Arena_BroadcastState();
}

/* =========================================================================
 * Invariants
 * ========================================================================= */
static void
Arena_InvariantFail(string msg)
{
	print(sprintf("Arena invariant: %s\n", msg));
}

static void
Arena_ValidateInvariants(void)
{
	int i;
	int j;
	int occupied;
	int slotsForPlayer;
	entity pl;
	int st;
	bool inQ;
	bool needsRoster;

	if (autocvar_arena_invariants == 0) {
		return;
	}

	for (i = 0i; i < g_arenaQueueCount; i++) {
		if (!g_arenaQueue[i]) {
			Arena_InvariantFail("null queue entry");
			continue;
		}
		for (j = i + 1i; j < g_arenaQueueCount; j++) {
			if (g_arenaQueue[i] == g_arenaQueue[j]) {
				Arena_InvariantFail("duplicate queue entry");
			}
		}
		if (Arena_SlotForPlayer(g_arenaQueue[i]) >= 0i) {
			Arena_InvariantFail("queued player is also competing");
		}
		if (Arena_PlayerState(g_arenaQueue[i]) != ARENASTATE_READY) {
			Arena_InvariantFail("queue/player-state disagreement");
		}
	}

	for (pl = world; (pl = next.Player(pl));) {
		st = Arena_PlayerState(pl);
		inQ = Arena_InQueue(pl);
		slotsForPlayer = 0i;
		for (i = 0i; i < ARENA_MAXSLOTS; i++) {
			if (g_arenaCompetitor[i] == pl) {
				slotsForPlayer++;
			}
		}

		if (st == ARENASTATE_READY) {
			if (inQ == false) {
				Arena_InvariantFail("READY player not in queue");
			}
			if (slotsForPlayer != 0i) {
				Arena_InvariantFail("READY player occupies a competitor slot");
			}
		} else if (st == ARENASTATE_COMPETITOR) {
			if (inQ) {
				Arena_InvariantFail("COMPETITOR is also queued");
			}
			if (slotsForPlayer != 1i) {
				Arena_InvariantFail("COMPETITOR without exactly one slot");
			}
		} else {
			if (inQ) {
				Arena_InvariantFail("non-READY player is queued");
			}
			if (slotsForPlayer != 0i) {
				Arena_InvariantFail("non-competitor occupying a slot");
			}
		}
	}

	occupied = 0i;
	for (i = 0i; i < ARENA_MAXSLOTS; i++) {
		if (!g_arenaCompetitor[i]) {
			continue;
		}
		occupied++;
		if (Arena_PlayerState(g_arenaCompetitor[i]) != ARENASTATE_COMPETITOR) {
			Arena_InvariantFail("non-competitor occupying a slot");
		}
	}

	needsRoster = (g_arenaState == ARENA_COUNTDOWN || g_arenaState == ARENA_LIVE
		|| g_arenaState == ARENA_SUDDEN_DEATH || g_arenaState == ARENA_ROUND_END);
	if (needsRoster) {
		if (occupied != g_arenaSlotCount) {
			Arena_InvariantFail("invalid competitor roster during active match");
		}
		for (i = 0i; i < g_arenaSlotCount; i++) {
			if (!g_arenaCompetitor[i]) {
				Arena_InvariantFail("null competitor in required roster");
			}
		}
	}
}

/* =========================================================================
 * State machine — Arena_Transition is the only writer of g_arenaState /
 * g_arenaStateTime.
 * ========================================================================= */
static bool
Arena_TransitionAllowed(int from, int to)
{
	if (from == to && to == ARENA_WARMUP) {
		return (true);
	}

	/* a forfeit ends a set from any point of it */
	if (to == ARENA_SET_END && from != ARENA_WARMUP && from != ARENA_SET_END) {
		return (g_setFirstTo > 0i);
	}

	switch (from) {
	case ARENA_WARMUP:
		return (to == ARENA_COUNTDOWN || to == ARENA_SELECT);
	case ARENA_SELECT:
		return (to == ARENA_COUNTDOWN || to == ARENA_WARMUP);
	case ARENA_COUNTDOWN:
		return (to == ARENA_LIVE || to == ARENA_SUDDEN_DEATH
			|| to == ARENA_WARMUP || to == ARENA_MATCH_END);
	case ARENA_LIVE:
		return (to == ARENA_ROUND_END || to == ARENA_SUDDEN_DEATH
			|| to == ARENA_MATCH_END);
	case ARENA_SUDDEN_DEATH:
		return (to == ARENA_ROUND_END || to == ARENA_MATCH_END);
	case ARENA_ROUND_END:
		return (to == ARENA_COUNTDOWN || to == ARENA_MATCH_END);
	case ARENA_MATCH_END:
		return (to == ARENA_COUNTDOWN || to == ARENA_WARMUP || to == ARENA_SELECT);
	case ARENA_SET_END:
		return (to == ARENA_SELECT || to == ARENA_WARMUP);
	}
	return (false);
}

static void
Arena_ExitState(int oldState)
{
	switch (oldState) {
	case ARENA_COUNTDOWN:
		g_arenaCountdownLast = -1i;
		break;
	}
}

static void
Arena_SetupRound(void)
{
	for (entity p = world; (p = next.Player(p));) {
		if (Arena_IsCompetitor(p)) {
			continue;
		}
		if (Arena_PlayerState(p) == ARENASTATE_SPECTATOR || p.team == TEAM_SPECTATOR) {
			continue;
		}
		Arena_DemoteToFakeSpec(p);
	}

	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		if (g_arenaCompetitor[i]) {
			Arena_SpawnCompetitor(g_arenaCompetitor[i], i);
		}
	}

	g_arenaSuddenNoTimer = false;
	g_arenaLiveSince = time;
	g_arenaRoundDeadline = time + autocvar_arena_roundTime;
}

static float
Arena_CountdownDuration(void)
{
	if (g_arenaMatchHasGoneLive && g_arenaRoundCountdownTime > 0.0f) {
		return (g_arenaRoundCountdownTime);
	}
	return (autocvar_arena_countdownTime);
}

static float
Arena_CountdownStep(void)
{
	if (g_arenaMatchHasGoneLive && g_arenaRoundCountdownStep > 0.0f) {
		return (g_arenaRoundCountdownStep);
	}
	return (1.0f);
}

static void
Arena_EnterState(int newState, int oldState)
{
	bool wasLive;

	switch (newState) {
	case ARENA_WARMUP:
		Arena_ClearMatchBookkeeping();
		for (entity p = world; (p = next.Player(p));) {
			if (Arena_PlayerState(p) == ARENASTATE_SPECTATOR) {
				continue;
			}
			if (p.team == TEAM_SPECTATOR) {
				continue;
			}
			if (Arena_PlayerState(p) == ARENASTATE_READY) {
				Arena_SpawnFreeplay(p);
			} else {
				Arena_SpawnWaitingView(p);
			}
		}
		break;

	case ARENA_COUNTDOWN:
		g_arenaDeadline = time + Arena_CountdownDuration();
		g_arenaCountdownLast = -1i;
		break;

	case ARENA_LIVE:
		wasLive = g_arenaMatchHasGoneLive;
		g_arenaMatchHasGoneLive = true;
		Arena_SetupRound();
		if (g_arenaHook_RoundStart) {
			g_arenaHook_RoundStart();
		}
		Arena_CenterprintAll("FIGHT!");
		if (wasLive) {
			sound(world, 4, "common/countdown-end-mini.ogg", 0.7f, 0.0f);
		} else {
			sound(world, 4, "common/countdown-end.ogg", 0.7f, 0.0f);
		}
		break;

	case ARENA_SUDDEN_DEATH:
		if (oldState == ARENA_COUNTDOWN) {
			g_arenaMatchHasGoneLive = true;
			Arena_SetupRound();
			g_arenaSuddenNoTimer = true;
			if (g_arenaHook_RoundStart) {
				g_arenaHook_RoundStart();
			}
		}
		if (g_arenaHook_SuddenDeath) {
			g_arenaHook_SuddenDeath();
		}
		Arena_CenterprintAll("SUDDEN DEATH");
		break;

	case ARENA_ROUND_END:
		g_arenaDeadline = time + autocvar_arena_roundEndTime;
		break;

	case ARENA_SELECT:
		/* the caller set g_setLock[] and g_setCounterSide */
		{
			bool allLocked = true;
			for (int ls = 0i; ls < g_arenaSlotCount; ls++) {
				if (g_setLock[ls] == 0i) {
					allLocked = false;
				}
				g_setVote[ls] = SETVOTE_NONE;
				if (g_arenaCompetitor[ls]) {
					Arena_SpawnWaitingView(g_arenaCompetitor[ls]);
				}
			}
			if (allLocked) {
				g_arenaDeadline = time + autocvar_arena_revealTime;
			} else if (g_setCounterSide > 0i) {
				g_arenaDeadline = time + autocvar_arena_counterpickTime;
				Arena_CenterprintAll("CHANGE HERO?");
			} else {
				g_arenaDeadline = time + autocvar_arena_selectTime;
				Arena_CenterprintAll("CHOOSE YOUR HERO");
			}
		}
		break;

	case ARENA_SET_END:
		for (int vs = 0i; vs < ARENA_MAXSLOTS; vs++) {
			g_setVote[vs] = SETVOTE_NONE;
		}
		if (g_setResult == SETRESULT_FORFEIT) {
			g_arenaDeadline = time + autocvar_arena_forfeitTime;
		} else {
			g_arenaDeadline = time + autocvar_arena_voteTime;
		}
		break;

	case ARENA_MATCH_END:
		if (g_setFirstTo > 0i) {
			g_arenaDeadline = time + autocvar_arena_gameEndTime;
			if (g_arenaResult == ARENARESULT_WIN && g_arenaWinnerSlot > 0i) {
				int gside = Arena_SideForSlot(g_arenaWinnerSlot - 1i);
				int lead = 0i;
				int trail = 0i;
				for (int ps = 0i; ps < g_arenaSlotCount; ps++) {
					if (Arena_SideForSlot(ps) == gside) {
						if (g_arenaPoints[ps] > lead) { lead = g_arenaPoints[ps]; }
						g_setGamesWon[ps]++;
					} else {
						if (g_arenaPoints[ps] > trail) { trail = g_arenaPoints[ps]; }
					}
				}
				g_setWins[gside]++;
				g_setLog = strcat(g_setLog, STRING_SET(g_setLog) ? " " : "",
					(gside == 1i) ? sprintf("%i-%i", lead, trail) : sprintf("%i-%i", trail, lead));
				if (g_setWins[gside] >= g_setFirstTo) {
					g_setResult = SETRESULT_COMPLETE;
					g_setWinnerSide = gside;
					Arena_CenterprintAll(sprintf("%s ^7WINS THE SET %i-%i",
						g_arenaCompetitor[g_arenaWinnerSlot - 1i].netname,
						g_setWins[gside], g_setWins[3i - gside]));
					Arena_SetReport();
				} else {
					Arena_CenterprintAll(sprintf("%s ^7WINS GAME %i",
						g_arenaCompetitor[g_arenaWinnerSlot - 1i].netname, g_setGame));
				}
			} else if (g_arenaResult == ARENARESULT_DRAW) {
				g_setLog = strcat(g_setLog, STRING_SET(g_setLog) ? " " : "", "draw");
				Arena_CenterprintAll("GAME DRAWN");
			}
			break;
		}
		g_arenaDeadline = time + autocvar_arena_matchEndTime;
		if (g_arenaResult == ARENARESULT_VOID) {
			Arena_CenterprintAll("MATCH ENDED - NO RESULT");
		} else if (g_arenaResult == ARENARESULT_DRAW) {
			Arena_CenterprintAll("MATCH DRAW");
		} else if (g_arenaWinnerSlot > 0i && g_arenaCompetitor[g_arenaWinnerSlot - 1i]) {
			Arena_CenterprintAll(sprintf("%s ^7WINS THE MATCH",
				g_arenaCompetitor[g_arenaWinnerSlot - 1i].netname));
		}
		break;
	}
}

static void
Arena_Transition(int newState, int reason)
{
	int oldState = g_arenaState;

	if (Arena_TransitionAllowed(oldState, newState) == false) {
		print(sprintf("Arena: illegal transition %i -> %i (reason %i)\n",
			oldState, newState, reason));
		return;
	}

	Arena_ExitState(oldState);

	g_arenaTransitionFrom = oldState;
	g_arenaState = newState;
	g_arenaStateTime = time;
	g_arenaLastReason = reason;

	Arena_EnterState(newState, oldState);
	Arena_ValidateInvariants();
	Arena_BroadcastState();
}

static void
Arena_CancelPendingMatchup(int reason)
{
	int i;
	entity c;

	for (i = g_arenaSlotCount - 1i; i >= 0i; i--) {
		c = g_arenaCompetitor[i];
		g_arenaCompetitor[i] = __NULL__;
		if (c) {
			Arena_SetPlayerState(c, ARENASTATE_READY);
			Arena_QueuePushFront(c);
		}
	}

	Arena_ClearMatchBookkeeping();
	Arena_Transition(ARENA_WARMUP, reason);
}

static void
Arena_VoidMatch(int reason)
{
	g_arenaResult = ARENARESULT_VOID;
	g_arenaWinnerSlot = 0;
	Arena_Transition(ARENA_MATCH_END, reason);
}

static void
Arena_HandleCompetitorDeparture(int reason)
{
	if (g_setFirstTo > 0i && g_setGame > 0i) {
		if (g_arenaState == ARENA_SET_END) {
			if (g_arenaDepartSlot >= 0i) {
				g_setVote[g_arenaDepartSlot] = SETVOTE_LEAVE;
			}
			return;
		}
		if (g_setResult == SETRESULT_NONE && g_arenaState != ARENA_WARMUP) {
			Arena_SetForfeit(g_arenaDepartSlot);
			return;
		}
		if (g_arenaState == ARENA_MATCH_END) {
			/* the set was decided; the leaver just skips the vote */
			return;
		}
	}

	switch (g_arenaState) {
	case ARENA_WARMUP:
		break;
	case ARENA_COUNTDOWN:
		if (g_arenaMatchHasGoneLive == false) {
			Arena_CancelPendingMatchup(reason);
		} else {
			Arena_VoidMatch(reason);
		}
		break;
	case ARENA_LIVE:
	case ARENA_SUDDEN_DEATH:
	case ARENA_ROUND_END:
		Arena_VoidMatch(reason);
		break;
	case ARENA_MATCH_END:
		break;
	}
}

static void
Arena_ApplyParticipationShell(entity pl, int oldState, int newState)
{
	if (newState == ARENASTATE_READY) {
		if (pl.team == TEAM_SPECTATOR || oldState == ARENASTATE_SPECTATOR) {
			if (g_arenaState == ARENA_WARMUP) {
				Arena_SpawnFreeplay(pl);
			} else {
				Arena_DemoteToFakeSpec(pl);
			}
		} else {
			Arena_EnsureFreeplay(pl);
		}
	} else if (newState == ARENASTATE_SPECTATOR) {
		Arena_MakePureSpectator(pl);
	}
}

void
Arena_ChangeParticipation(entity pl, int newState, int reason)
{
	int oldState;
	int savedLife;
	bool wasCompetitor;
	bool skipShell;
	bool transitioned;

	if (!pl) {
		return;
	}

	oldState = Arena_PlayerState(pl);
	wasCompetitor = (oldState == ARENASTATE_COMPETITOR) || Arena_IsCompetitor(pl);
	skipShell = (reason == ARENAREASON_DISCONNECT);

	/* competitors keep their slot until a real departure, not a ready-up */
	if (wasCompetitor && newState == ARENASTATE_READY) {
		return;
	}

	Arena_QueueRemove(pl);
	g_arenaDepartSlot = Arena_SlotForPlayer(pl);
	if (wasCompetitor && newState != ARENASTATE_COMPETITOR) {
		Arena_ReleaseSlot(pl);
	}

	Arena_SetPlayerState(pl, newState);

	if (newState == ARENASTATE_READY) {
		Arena_QueueAppend(pl);
	}

	/* Spectate must own the pure-spec shell before a cancel transition:
	 * WARMUP entry skips SPECTATOR players and would otherwise leave them
	 * on a competitor/freeplay body. */
	if (skipShell == false && newState == ARENASTATE_SPECTATOR) {
		Arena_MakePureSpectator(pl);
	}

	savedLife = g_arenaState;
	if (wasCompetitor && newState != ARENASTATE_COMPETITOR) {
		Arena_HandleCompetitorDeparture(reason);
	}
	transitioned = (g_arenaState != savedLife);

	if (skipShell == false && transitioned == false && newState != ARENASTATE_SPECTATOR) {
		Arena_ApplyParticipationShell(pl, oldState, newState);
	}

	Arena_ValidateInvariants();
	Arena_BroadcastState();
}

/* =========================================================================
 * Semantic match operations
 * ========================================================================= */
static int
Arena_DefaultRoundTest(void)
{
	int occupied = 0i;
	int aliveCount = 0i;
	int aliveSlot = 0i;

	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		entity c = g_arenaCompetitor[i];
		if (!c) {
			continue;
		}
		occupied++;
		if (is.Alive(c)) {
			aliveCount++;
			aliveSlot = i + 1i;
		}
	}

	if (occupied < 1i) {
		return (0i);
	}
	if (aliveCount == occupied) {
		return (0i);
	}
	if (aliveCount == 1i) {
		return (aliveSlot);
	}
	if (aliveCount == 0i) {
		return (-1i);
	}
	return (0i);
}

static int
Arena_EvaluateRound(void)
{
	if (g_arenaHook_RoundWinTest) {
		return (g_arenaHook_RoundWinTest());
	}
	return (Arena_DefaultRoundTest());
}

static void
Arena_ResolveRound(int winTest)
{
	if (winTest == -1i) {
		g_arenaRoundResult = ARENARESULT_DRAW;
		g_arenaRoundWinnerSlot = 0;
		for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
			if (g_arenaCompetitor[i]) {
				g_arenaPoints[i]++;
			}
		}
		Arena_CenterprintAll("DRAW");
	} else if (winTest > 0i) {
		g_arenaRoundResult = ARENARESULT_WIN;
		g_arenaRoundWinnerSlot = winTest;
		g_arenaPoints[winTest - 1i]++;
		entity winner = g_arenaCompetitor[winTest - 1i];
		if (winner) {
			Arena_CenterprintAll(sprintf("%s ^7wins the round", winner.netname));
		}
	} else {
		return;
	}

	if (g_arenaHook_RoundEnd) {
		g_arenaHook_RoundEnd();
	}

	Arena_Transition(ARENA_ROUND_END, ARENAREASON_ROUND_RESOLVED);
}

static int
Arena_LeaderSlot(void)
{
	int best = -1i;
	int bestSlot = 0i;
	bool tie = false;

	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		if (!g_arenaCompetitor[i]) {
			continue;
		}
		if (g_arenaPoints[i] > best) {
			best = g_arenaPoints[i];
			bestSlot = i + 1i;
			tie = false;
		} else if (g_arenaPoints[i] == best) {
			tie = true;
		}
	}

	return (tie ? 0i : bestSlot);
}

static void
Arena_ResolveMatch(int resultType, int winnerSlot, int reason)
{
	g_arenaResult = resultType;
	g_arenaWinnerSlot = winnerSlot;
	Arena_Transition(ARENA_MATCH_END, reason);
}

static void
Arena_BeginMatch(void)
{
	int slot;
	int assigned;
	entity pl;

	for (slot = 0i; slot < ARENA_MAXSLOTS; slot++) {
		g_arenaCompetitor[slot] = __NULL__;
		g_arenaPoints[slot] = 0i;
	}

	assigned = 0i;
	for (slot = 0i; slot < g_arenaSlotCount; slot++) {
		pl = Arena_QueuePopFront();
		while (pl && (pl.team == TEAM_SPECTATOR || Arena_PlayerState(pl) == ARENASTATE_SPECTATOR)) {
			pl = Arena_QueuePopFront();
		}
		if (!pl) {
			break;
		}
		Arena_AssignSlot(pl, slot);
		assigned++;
	}

	if (assigned < g_arenaSlotCount) {
		for (slot = assigned - 1i; slot >= 0i; slot--) {
			pl = g_arenaCompetitor[slot];
			g_arenaCompetitor[slot] = __NULL__;
			if (pl) {
				Arena_SetPlayerState(pl, ARENASTATE_READY);
				Arena_QueuePushFront(pl);
			}
		}
		if (g_arenaState != ARENA_WARMUP) {
			Arena_Transition(ARENA_WARMUP, ARENAREASON_INVALID_ROSTER);
		}
		return;
	}

	g_arenaRound = 1;
	g_arenaMatchHasGoneLive = false;
	g_arenaResult = ARENARESULT_NONE;
	g_arenaWinnerSlot = 0;
	g_arenaRoundResult = ARENARESULT_NONE;
	g_arenaRoundWinnerSlot = 0;
	g_arenaTiebreaker = false;
	g_arenaSuddenNoTimer = false;

	if (g_setFirstTo > 0i) {
		/* a new set between whoever was seated */
		g_setGame = 1i;
		g_setWins[1] = 0i;
		g_setWins[2] = 0i;
		g_setRunbacks = 0i;
		g_setResult = SETRESULT_NONE;
		g_setWinnerSide = 0i;
		g_setCounterSide = 0i;
		g_setLog = "";
		g_setLeft = "";
		for (slot = 0i; slot < ARENA_MAXSLOTS; slot++) {
			g_setLock[slot] = 0i;
			g_setVote[slot] = SETVOTE_NONE;
			g_setGamesWon[slot] = 0i;
			g_setSeat[slot] = g_arenaCompetitor[slot];
		}
		Arena_Transition(ARENA_SELECT, ARENAREASON_NORMAL);
		return;
	}

	Arena_Transition(ARENA_COUNTDOWN, ARENAREASON_NORMAL);
}

/* next game of a set, or the first game of a rematch: same competitors */
static void
Arena_BeginGame(void)
{
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		g_arenaPoints[i] = 0i;
	}
	g_arenaRound = 1;
	g_arenaMatchHasGoneLive = false;
	g_arenaResult = ARENARESULT_NONE;
	g_arenaWinnerSlot = 0;
	g_arenaRoundResult = ARENARESULT_NONE;
	g_arenaRoundWinnerSlot = 0;
	g_arenaTiebreaker = false;
	g_arenaSuddenNoTimer = false;
	Arena_Transition(ARENA_SELECT, ARENAREASON_NORMAL);
}

static string
Arena_RandomHero(void)
{
	int total = teams.TotalClasses(1);
	if (total <= 0i) {
		return ("");
	}
	return (teams.ClassForIndex(1, (int)floor(random() * total) % total));
}

static void
Arena_TickSelect(void)
{
	bool allLocked = true;
	int i;
	entity c;

	for (i = 0i; i < g_arenaSlotCount; i++) {
		if (g_setLock[i] == 0i) {
			allLocked = false;
		}
	}

	/* everyone locked: show both picks for a moment, then fight */
	if (allLocked && g_arenaDeadline > time + autocvar_arena_revealTime) {
		g_arenaDeadline = time + autocvar_arena_revealTime;
		Arena_BroadcastState();
	}

	if (time < g_arenaDeadline) {
		return;
	}

	for (i = 0i; i < g_arenaSlotCount; i++) {
		c = g_arenaCompetitor[i];
		if (!c) {
			continue;
		}
		if (STRING_SET(userinfo.GetString(c, "*hero")) == false) {
			Hero_TrySelectEx(c, Arena_RandomHero(), false);
		}
		g_setLock[i] = 1i;
	}

	Arena_Transition(ARENA_COUNTDOWN, ARENAREASON_NORMAL);
}

bool
Arena_HeroLocked(entity pl)
{
	int slot;

	if (g_setFirstTo <= 0i) {
		return (false);
	}
	slot = Arena_SlotForPlayer(pl);
	if (slot < 0i) {
		return (false);
	}
	/* heroes change only during SELECT, and only while unlocked */
	if (g_arenaState != ARENA_SELECT) {
		return (true);
	}
	return (g_setLock[slot] != 0i);
}

static void
Arena_LockHero(entity pl)
{
	int slot = Arena_SlotForPlayer(pl);

	if (g_arenaState != ARENA_SELECT || slot < 0i) {
		return;
	}
	if (STRING_SET(userinfo.GetString(pl, "*hero")) == false) {
		centerprint(pl, "Pick a hero first");
		return;
	}
	g_setLock[slot] = 1i;
	Arena_BroadcastState();
}

static bool
Arena_SideBehind(int side)
{
	int mine = g_setWins[side];
	int theirs = g_setWins[3i - side];
	int myPts = 0i;
	int theirPts = 0i;

	if (mine != theirs) {
		return (mine < theirs);
	}
	for (int i = 0i; i < g_arenaSlotCount; i++) {
		if (Arena_SideForSlot(i) == side) {
			if (g_arenaPoints[i] > myPts) { myPts = g_arenaPoints[i]; }
		} else {
			if (g_arenaPoints[i] > theirPts) { theirPts = g_arenaPoints[i]; }
		}
	}
	return (myPts < theirPts);
}

static void
Arena_SetForfeit(int departSlot)
{
	int side;
	entity leaver;

	if (departSlot < 0i) {
		/* not a seated competitor after all: the roster is broken */
		Arena_SetClose("void");
		return;
	}

	side = Arena_SideForSlot(departSlot);
	leaver = g_setSeat[departSlot];
	g_setResult = SETRESULT_FORFEIT;
	g_setWinnerSide = 3i - side;
	g_setLeft = sprintf("%s %s", leaver ? leaver.netname : "?",
		Arena_SideBehind(side) ? "behind" : "even");
	g_setVote[departSlot] = SETVOTE_LEAVE;
	Arena_SetReport();
	Arena_CenterprintAll(sprintf("%s ^7LEFT THE SET", leaver ? leaver.netname : "?"));
	Arena_Transition(ARENA_SET_END, ARENAREASON_PARTICIPANT_LEFT);
}

/* tells the engine about a finished set (Bulwark Live fighter records) */
static void
Arena_SetReport(void)
{
	int outcome;
	int side;
	entity c;

	for (int i = 0i; i < g_arenaSlotCount; i++) {
		c = g_setSeat[i];
		if (!c) {
			continue;
		}
		side = Arena_SideForSlot(i);
		if (g_setResult == SETRESULT_FORFEIT && g_setVote[i] == SETVOTE_LEAVE) {
			outcome = 2i;	/* left; the engine knows whether it was a quit or a drop */
		} else if (side == g_setWinnerSide) {
			outcome = 0i;
		} else {
			outcome = 1i;
		}
		localcmd(sprintf("live_set_seat %i %i %i %i %i %s\n", (int)num_for_edict(c), side, outcome,
			(outcome == 2i && Arena_SideBehind(side)) ? 1i : 0i, g_setGamesWon[i],
			userinfo.GetString(c, "*hero")));
	}
	localcmd(sprintf("live_set_report %i %i %i\n", (g_setResult == SETRESULT_FORFEIT) ? 1i : 0i,
		g_setFirstTo, (g_setRunbacks > 0i) ? 1i : 0i));
}

static void
Arena_SetClose(string why)
{
	entity c;

	g_setSerial++;
	g_setClosed = why;
	g_setGame = 0i;
	g_setResult = SETRESULT_NONE;
	g_setCounterSide = 0i;

	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		c = g_arenaCompetitor[i];
		g_arenaCompetitor[i] = __NULL__;
		g_arenaPoints[i] = 0i;
		g_setLock[i] = 0i;
		g_setVote[i] = SETVOTE_NONE;
		g_setSeat[i] = __NULL__;
		if (c) {
			/* never auto-join them again: they are on their way out */
			userinfo.SetString(c, "*arena_setdone", "1");
			Arena_SetPlayerState(c, ARENASTATE_NOTREADY);
		}
	}
	Arena_CenterprintAll((why == "time" || why == "rematch declined") ? "SET OVER" : "");
	Arena_Transition(ARENA_WARMUP, ARENAREASON_SET_CLOSED);
}

static void
Arena_SetVote(entity pl, int vote)
{
	int slot = Arena_SlotForPlayer(pl);

	if (g_arenaState != ARENA_SET_END || slot < 0i) {
		return;
	}
	if (g_setResult == SETRESULT_FORFEIT && vote != SETVOTE_LEAVE) {
		return;	/* nobody to rematch */
	}
	g_setVote[slot] = vote;
	Arena_BroadcastState();
}

static void
Arena_TickSetEnd(void)
{
	bool everyone = true;
	bool anyLeave = false;
	int i;

	if (g_setResult == SETRESULT_FORFEIT) {
		if (time >= g_arenaDeadline) {
			Arena_SetClose("left");
		}
		return;
	}

	for (i = 0i; i < g_arenaSlotCount; i++) {
		if (!g_arenaCompetitor[i] || g_setVote[i] == SETVOTE_LEAVE) {
			anyLeave = true;
		} else if (g_setVote[i] == SETVOTE_NONE) {
			everyone = false;
		}
	}

	if (anyLeave) {
		Arena_SetClose("rematch declined");
		return;
	}

	if (everyone) {
		/* runback: same competitors, a fresh set */
		g_setRunbacks++;
		g_setGame = 1i;
		g_setWins[1] = 0i;
		g_setWins[2] = 0i;
		g_setResult = SETRESULT_NONE;
		g_setWinnerSide = 0i;
		g_setCounterSide = 0i;
		g_setLog = "";
		g_setLeft = "";
		for (i = 0i; i < ARENA_MAXSLOTS; i++) {
			g_setLock[i] = (g_setVote[i] == SETVOTE_REMATCH) ? 1i : 0i;
			g_setGamesWon[i] = 0i;
		}
		Arena_CenterprintAll("REMATCH!");
		Arena_BeginGame();
		return;
	}

	if (time >= g_arenaDeadline) {
		Arena_SetClose("time");
	}
}

static void
Arena_Promote(void)
{
	int winnerSlot = g_arenaWinnerSlot;
	int result = g_arenaResult;
	entity winner;
	entity c;
	int i;

	if (result == ARENARESULT_VOID || result == ARENARESULT_NONE) {
		for (i = g_arenaSlotCount - 1i; i >= 0i; i--) {
			c = g_arenaCompetitor[i];
			g_arenaCompetitor[i] = __NULL__;
			g_arenaPoints[i] = 0i;
			if (!c) {
				continue;
			}
			Arena_SetPlayerState(c, ARENASTATE_READY);
			Arena_QueuePushFront(c);
		}
		for (i = g_arenaSlotCount; i < ARENA_MAXSLOTS; i++) {
			g_arenaCompetitor[i] = __NULL__;
			g_arenaPoints[i] = 0i;
		}
	} else {
		winner = __NULL__;
		if (result == ARENARESULT_WIN && winnerSlot > 0i) {
			winner = g_arenaCompetitor[winnerSlot - 1i];
		}
		for (i = 0i; i < ARENA_MAXSLOTS; i++) {
			c = g_arenaCompetitor[i];
			g_arenaCompetitor[i] = __NULL__;
			g_arenaPoints[i] = 0i;
			if (!c) {
				continue;
			}
			Arena_SetPlayerState(c, ARENASTATE_READY);
			if (c == winner) {
				Arena_QueuePushFront(c);
			} else {
				Arena_QueueAppend(c);
			}
		}
	}

	g_arenaResult = ARENARESULT_NONE;
	g_arenaWinnerSlot = 0;
	g_arenaMatchHasGoneLive = false;
	g_arenaRound = 0;
	g_arenaTiebreaker = false;

	if (Arena_ReadyCount() >= g_arenaMinReady) {
		Arena_BeginMatch();
	} else {
		Arena_Transition(ARENA_WARMUP, ARENAREASON_MATCH_COMPLETE);
	}
}

/* =========================================================================
 * Per-state ticks — only decide when to leave
 * ========================================================================= */
static void
Arena_TickWarmup(void)
{
	/* set play is matchmade: everyone who came in is there to play, except
	   those whose set just closed (they are on their way out) */
	if (g_setFirstTo > 0i) {
		for (entity p = world; (p = next.Player(p));) {
			if (Arena_PlayerState(p) != ARENASTATE_NOTREADY) {
				continue;
			}
			if (STRING_SET(userinfo.GetString(p, "*arena_setdone"))) {
				continue;
			}
			Arena_ChangeParticipation(p, ARENASTATE_READY, ARENAREASON_NORMAL);
		}
	}

	if (Arena_ReadyCount() >= g_arenaMinReady) {
		Arena_BeginMatch();
	}
}

static void
Arena_TickCountdown(void)
{
	float step;
	int ticksLeft;

	if (Arena_CompetitorCount() < g_arenaSlotCount) {
		if (g_arenaMatchHasGoneLive == false) {
			Arena_CancelPendingMatchup(ARENAREASON_INVALID_ROSTER);
		} else {
			Arena_VoidMatch(ARENAREASON_INVALID_ROSTER);
		}
		return;
	}

	step = Arena_CountdownStep();
	if (step < 0.05f) {
		step = 0.05f;
	}
	ticksLeft = (int)ceil((g_arenaDeadline - time) / step);
	if (ticksLeft != g_arenaCountdownLast && ticksLeft > 0i) {
		g_arenaCountdownLast = ticksLeft;
		Arena_CenterprintAll(sprintf("%i", ticksLeft));
		if (g_arenaMatchHasGoneLive) {
			sound(world, 4, "common/countdown-mini.ogg", 0.7f, 0.0f);
		} else {
			sound(world, 4, "common/countdown.ogg", 0.7f, 0.0f);
		}
	}

	if (time >= g_arenaDeadline) {
		if (g_arenaTiebreaker) {
			Arena_Transition(ARENA_SUDDEN_DEATH, ARENAREASON_NORMAL);
		} else {
			Arena_Transition(ARENA_LIVE, ARENAREASON_NORMAL);
		}
	}
}

static void
Arena_TickLive(void)
{
	int result;

	if (time < g_arenaLiveSince + 0.25f) {
		return;
	}

	result = Arena_EvaluateRound();
	if (result != 0i) {
		Arena_ResolveRound(result);
		return;
	}

	if (g_arenaSuddenNoTimer == false && time >= g_arenaRoundDeadline) {
		Arena_Transition(ARENA_SUDDEN_DEATH, ARENAREASON_TIME_EXPIRED);
	}
}

static void
Arena_TickSuddenDeath(void)
{
	int result;

	if (time < g_arenaStateTime + 0.1f) {
		return;
	}

	if (g_arenaHook_SuddenDeathTick) {
		g_arenaHook_SuddenDeathTick();
	}

	result = Arena_EvaluateRound();
	if (result != 0i) {
		Arena_ResolveRound(result);
	}
}

static void
Arena_TickRoundEnd(void)
{
	int leader;

	if (time < g_arenaDeadline) {
		return;
	}

	/* set play: a game is first to a majority of its rounds */
	if (g_setFirstTo > 0i && g_arenaTiebreaker == false) {
		leader = Arena_LeaderSlot();
		if (leader > 0i && g_arenaPoints[leader - 1i] * 2i > g_arenaRoundLimit) {
			Arena_ResolveMatch(ARENARESULT_WIN, leader, ARENAREASON_MATCH_COMPLETE);
			return;
		}
	}

	if (g_arenaRound >= g_arenaRoundLimit) {
		leader = Arena_LeaderSlot();
		if (leader > 0i) {
			Arena_ResolveMatch(ARENARESULT_WIN, leader, ARENAREASON_MATCH_COMPLETE);
			return;
		}
		g_arenaRound++;
		g_arenaTiebreaker = true;
		Arena_Transition(ARENA_COUNTDOWN, ARENAREASON_NORMAL);
		return;
	}

	g_arenaRound++;
	g_arenaTiebreaker = false;
	Arena_Transition(ARENA_COUNTDOWN, ARENAREASON_NORMAL);
}

static void
Arena_TickMatchEnd(void)
{
	if (time < g_arenaDeadline) {
		return;
	}
	if (g_setFirstTo > 0i && g_setGame > 0i) {
		if (g_arenaResult == ARENARESULT_VOID) {
			Arena_SetClose("void");
		} else if (g_setResult != SETRESULT_NONE) {
			Arena_Transition(ARENA_SET_END, ARENAREASON_MATCH_COMPLETE);
		} else {
			int loser = 0i;
			if (g_arenaResult == ARENARESULT_WIN && g_arenaWinnerSlot > 0i) {
				loser = 3i - Arena_SideForSlot(g_arenaWinnerSlot - 1i);
			}
			g_setGame++;
			g_setCounterSide = loser;
			for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
				g_setLock[i] = (loser == 0i || Arena_SideForSlot(i) == loser) ? 0i : 1i;
			}
			Arena_BeginGame();
		}
		return;
	}
	Arena_Promote();
}

void
Arena_FrameStart(void)
{
	switch (g_arenaState) {
	case ARENA_WARMUP:
		Arena_TickWarmup();
		break;
	case ARENA_COUNTDOWN:
		Arena_TickCountdown();
		break;
	case ARENA_LIVE:
		Arena_TickLive();
		break;
	case ARENA_SUDDEN_DEATH:
		Arena_TickSuddenDeath();
		break;
	case ARENA_ROUND_END:
		Arena_TickRoundEnd();
		break;
	case ARENA_MATCH_END:
		Arena_TickMatchEnd();
		break;
	case ARENA_SELECT:
		Arena_TickSelect();
		break;
	case ARENA_SET_END:
		Arena_TickSetEnd();
		break;
	}

	Arena_BroadcastThrottled();
}

/* =========================================================================
 * Queue UX wrappers
 * ========================================================================= */
void
Arena_SetReady(entity pl)
{
	Arena_ChangeParticipation(pl, ARENASTATE_READY, ARENAREASON_NORMAL);
	if (Arena_PlayerState(pl) == ARENASTATE_READY) {
		centerprint(pl, "You are READY");
	}
}

void
Arena_SetNotReady(entity pl)
{
	Arena_ChangeParticipation(pl, ARENASTATE_NOTREADY, ARENAREASON_NOT_READY);
	if (Arena_PlayerState(pl) == ARENASTATE_NOTREADY) {
		centerprint(pl, "You are NOT READY");
	}
}

void
Arena_SetSpectator(entity pl)
{
	Arena_ChangeParticipation(pl, ARENASTATE_SPECTATOR, ARENAREASON_SPECTATE);
}

/* =========================================================================
 * Mode -> director callback dispatchers
 * ========================================================================= */
void
Arena_OnPlayerConnect(entity pl)
{
	Arena_SetPlayerState(pl, ARENASTATE_NOTREADY);
}

void
Arena_OnPlayerSpawn(entity pl)
{
	if (Arena_PlayerState(pl) == ARENASTATE_SPECTATOR) {
		Arena_MakePureSpectator(pl);
		return;
	}

	if (g_arenaState == ARENA_WARMUP) {
		if (Arena_PlayerState(pl) == ARENASTATE_READY) {
			if (STRING_SET(userinfo.GetString(pl, "*hero"))) {
				Arena_SpawnFreeplay(pl);
			} else {
				Arena_SpawnWaitingView(pl);
			}
		} else if (g_arenaAutoJoin && Arena_PlayerState(pl) == ARENASTATE_NOTREADY
			&& STRING_SET(userinfo.GetString(pl, "*arena_setdone")) == false) {
			Arena_SetReady(pl);
			if (STRING_SET(userinfo.GetString(pl, "*hero"))) {
				Arena_SpawnFreeplay(pl);
			} else {
				Arena_SpawnWaitingView(pl);
			}
		} else {
			Arena_SpawnWaitingView(pl);
		}
	} else {
		Arena_DemoteToFakeSpec(pl);
	}
}

bool
Arena_OnPlayerRequestRespawn(entity pl)
{
	if (g_arenaState == ARENA_WARMUP && Arena_PlayerState(pl) != ARENASTATE_SPECTATOR) {
		Arena_SpawnFreeplay(pl);
		return (true);
	}
	return (false);
}

void
Arena_OnPlayerKilled(entity victim, entity attacker)
{
	if (g_arenaHook_PlayerDeath) {
		g_arenaHook_PlayerDeath(victim, attacker);
	}

	if (Arena_IsCompetitor(victim)) {
		if (g_arenaState == ARENA_LIVE || g_arenaState == ARENA_SUDDEN_DEATH) {
			Arena_DemoteToFakeSpec(victim);
		}
	}
}

void
Arena_OnPlayerPain(entity victim)
{
	if (g_arenaHook_PlayerPain) {
		g_arenaHook_PlayerPain(victim);
	}
}

void
Arena_OnPlayerDisconnect(entity pl)
{
	Arena_ChangeParticipation(pl, ARENASTATE_NOTREADY, ARENAREASON_DISCONNECT);
}

bool
Arena_OnClientCommand(entity pl, string command)
{
	switch (argv(0)) {
	case "ready":
		Arena_SetReady(pl);
		return (true);
	case "notready":
		Arena_SetNotReady(pl);
		return (true);
	case "lockhero":
		Arena_LockHero(pl);
		return (true);
	case "set_rematch":
		Arena_SetVote(pl, SETVOTE_REMATCH);
		return (true);
	case "set_rematch_hero":
		Arena_SetVote(pl, SETVOTE_REMATCH_HERO);
		return (true);
	case "set_leave":
		Arena_SetVote(pl, SETVOTE_LEAVE);
		return (true);
	default:
		return (false);
	}
	return (false);
}
