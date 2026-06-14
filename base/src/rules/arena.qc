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
 * ========================================================================= */

/* --- director state (mutable globals, mirroring shared.qc policy globals) --- */
var int g_arenaState;			/* current ARENA_* state */
var int g_arenaShape;			/* configured ARENASHAPE_* */
var int g_arenaPromo;			/* configured ARENAPROMO_* */
var int g_arenaRoundLimit;		/* best-of-N */
var int g_arenaSlotCount;		/* competitors per match (from shape) */
var int g_arenaMinReady;		/* ready players required to start (== slot count) */
var int g_arenaRound;			/* current round index (1-based) */
var float g_arenaStateTime;		/* timestamp the current state was entered */
var float g_arenaDeadline;		/* generic per-state deadline (countdown/pause) */
var float g_arenaRoundDeadline;	/* LIVE round timer -> sudden death */
var float g_arenaLiveSince;		/* when the current round went LIVE */
var float g_arenaNextBroadcast;	/* throttle for serverinfo publish */
var int g_arenaCountdownLast;	/* last whole-second printed during COUNTDOWN */
var bool g_arenaSuddenNoTimer;	/* tiebreaker: suppress the round timer (U6) */
var bool g_arenaTiebreaker;		/* current round is a tiebreaker (U6) */
var bool g_arenaMatchNoWinner;	/* current MATCH_END voided (disconnect abort) */
var int g_arenaWinnerSlot;		/* resolved winner slot (1-based), 0 = none/draw */

/* competitor slots + per-slot bookkeeping */
entity g_arenaCompetitor[ARENA_MAXSLOTS];
var int g_arenaPoints[ARENA_MAXSLOTS];
var float g_arenaReaperSince[ARENA_MAXSLOTS];	/* reaper below-threshold timestamp (U6) */
var int g_arenaSuddenHit[ARENA_MAXSLOTS];		/* took damage this sudden-death (U6) */

/* FIFO ready queue */
entity g_arenaQueue[ARENA_MAXQUEUE];
var int g_arenaQueueCount;

/* --- forward declarations for internal helpers --- */
void Arena_EnterWarmup(void);
void Arena_BeginMatch(void);
void Arena_EnterCountdown(void);
void Arena_BeginRound(void);
void Arena_ResolveRound(int result);
void Arena_EndMatch(int winnerSlot, bool noWinner);
void Arena_Promote(void);
void Arena_SpawnCompetitor(entity pl, int slot);
void Arena_SpawnFreeplay(entity pl);
void Arena_DemoteToFakeSpec(entity pl);
void Arena_EnterSuddenDeath(void);

/* =========================================================================
 * Configuration (called by the mode from CodeCallback_StartGameType)
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
		/* asymmetric 1-vs-many: designed-for, not exercised in v1. */
		g_arenaSlotCount = 2;
		break;
	case ARENASHAPE_1V1:
	default:
		g_arenaSlotCount = 2;
		break;
	}

	g_arenaMinReady = g_arenaSlotCount;

	/* reset all runtime state */
	g_arenaQueueCount = 0;
	g_arenaRound = 0;
	g_arenaSuddenNoTimer = false;
	g_arenaTiebreaker = false;
	g_arenaMatchNoWinner = false;
	g_arenaWinnerSlot = 0;

	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		g_arenaCompetitor[i] = __NULL__;
		g_arenaPoints[i] = 0i;
		g_arenaReaperSince[i] = 0.0f;
		g_arenaSuddenHit[i] = 0i;
	}

	Arena_EnterWarmup();
}

void
Arena_SetHooks(void() roundStart, void(entity, entity) playerDeath, int() roundWinTest, void() roundEnd, void() suddenDeath)
{
	g_arenaHook_RoundStart = roundStart;
	g_arenaHook_PlayerDeath = playerDeath;
	g_arenaHook_RoundWinTest = roundWinTest;
	g_arenaHook_RoundEnd = roundEnd;
	g_arenaHook_SuddenDeath = suddenDeath;
}

/* =========================================================================
 * FIFO ready-queue primitives
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
	if (Arena_InQueue(pl)) {
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
	if (Arena_InQueue(pl)) {
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

/* =========================================================================
 * Queries
 * ========================================================================= */
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
 * ========================================================================= */

/** Free-play body used in WARMUP. */
void
Arena_SpawnFreeplay(entity pl)
{
	ents.ChangeToClass(pl, "player_mp");
	game.TeleportToSpawn(pl);
}

/** Spawn a competitor for a live round on its assigned team. */
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
	ents.ChangeToClass(pl, Hero_ResolveSpawnHero(pl));
	game.TeleportToSpawn(pl);
}

/** Fake-spectator (chase-cam) - eliminated / between-round / non-competitor. */
void
Arena_DemoteToFakeSpec(entity pl)
{
	ents.Input(pl, "Spectate", "", world);
}

/** Pure spectator (real spec, opted out of the queue). */
static void
Arena_MakePureSpectator(entity pl)
{
	ents.Input(pl, "SetTeam", itos(TEAM_SPECTATOR), pl);
	ents.ChangeToClass(pl, "spectator");
	game.TeleportToSpawn(pl);
}

/* =========================================================================
 * State broadcast (U4): persistent serverinfo strings + transient centerprint
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
	}
	return ("?");
}

void
Arena_BroadcastState(void)
{
	serverinfo.SetString("arena_state", Arena_StateName());
	serverinfo.SetString("arena_round", sprintf("Round %i / %i", g_arenaRound, g_arenaRoundLimit));
	serverinfo.SetInteger("arena_ready", g_arenaQueueCount);

	/* publish competitor netnames + round points for the first two slots */
	for (int i = 0i; i < 2i; i++) {
		entity c = g_arenaCompetitor[i];
		string slotKey = sprintf("arena_p%i", i + 1i);

		if (c) {
			serverinfo.SetString(slotKey, sprintf("%s (%i)", c.netname, g_arenaPoints[i]));
		} else {
			serverinfo.SetString(slotKey, "");
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
 * State transitions
 * ========================================================================= */
void
Arena_EnterWarmup(void)
{
	g_arenaState = ARENA_WARMUP;
	g_arenaStateTime = time;
	g_arenaRound = 0;
	g_arenaTiebreaker = false;
	g_arenaSuddenNoTimer = false;

	/* return everyone who is not a pure spectator to free-play */
	for (entity p = world; (p = next.Player(p));) {
		if (p.arena_state == ARENASTATE_SPECTATOR) {
			continue;
		}
		if (p.team == TEAM_SPECTATOR) {
			continue;
		}
		Arena_SpawnFreeplay(p);
	}

	Arena_BroadcastState();
}

void
Arena_BeginMatch(void)
{
	/* clear slots + points, pull fresh competitors from the queue front */
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		g_arenaCompetitor[i] = __NULL__;
		g_arenaPoints[i] = 0i;
	}

	for (int slot = 0i; slot < g_arenaSlotCount; slot++) {
		entity pl = Arena_QueuePopFront();

		/* skip stale / spectator entries defensively */
		while (pl && (pl.team == TEAM_SPECTATOR || pl.arena_state == ARENASTATE_SPECTATOR)) {
			pl = Arena_QueuePopFront();
		}

		if (!pl) {
			/* not enough valid players - bail back to warmup */
			Arena_EnterWarmup();
			return;
		}

		g_arenaCompetitor[slot] = pl;
		pl.arena_state = ARENASTATE_COMPETITOR;
		userinfo.SetFloat(pl, "*arena_state", ARENASTATE_COMPETITOR);
	}

	g_arenaRound = 1;
	g_arenaMatchNoWinner = false;
	g_arenaWinnerSlot = 0;
	g_arenaTiebreaker = false;
	Arena_EnterCountdown();
}

void
Arena_EnterCountdown(void)
{
	g_arenaState = ARENA_COUNTDOWN;
	g_arenaStateTime = time;
	g_arenaDeadline = time + autocvar_arena_countdownTime;
	g_arenaCountdownLast = -1i;
	Arena_BroadcastState();
}

void
Arena_BeginRound(void)
{
	/* demote every non-competitor to a fake-spec watcher (R6) */
	for (entity p = world; (p = next.Player(p));) {
		if (Arena_IsCompetitor(p)) {
			continue;
		}
		if (p.arena_state == ARENASTATE_SPECTATOR || p.team == TEAM_SPECTATOR) {
			continue;
		}
		Arena_DemoteToFakeSpec(p);
	}

	/* (re)spawn competitors + clear per-round bookkeeping */
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		g_arenaReaperSince[i] = 0.0f;
		g_arenaSuddenHit[i] = 0i;

		if (g_arenaCompetitor[i]) {
			Arena_SpawnCompetitor(g_arenaCompetitor[i], i);
		}
	}

	g_arenaSuddenNoTimer = false;
	g_arenaLiveSince = time;
	g_arenaRoundDeadline = time + autocvar_arena_roundTime;

	if (g_arenaHook_RoundStart) {
		g_arenaHook_RoundStart();
	}

	/* a tiebreaker round starts directly in sudden death with no timer (U6) */
	if (g_arenaTiebreaker) {
		Arena_EnterSuddenDeath();
		g_arenaSuddenNoTimer = true;
	} else {
		g_arenaState = ARENA_LIVE;
		g_arenaStateTime = time;
		Arena_CenterprintAll("FIGHT!");
	}

	Arena_BroadcastState();
}

void
Arena_EnterSuddenDeath(void)
{
	g_arenaState = ARENA_SUDDEN_DEATH;
	g_arenaStateTime = time;

	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		g_arenaReaperSince[i] = 0.0f;
		g_arenaSuddenHit[i] = 0i;
	}

	if (g_arenaHook_SuddenDeath) {
		g_arenaHook_SuddenDeath();
	}

	Arena_CenterprintAll("SUDDEN DEATH");
	Arena_BroadcastState();
}

/** Default round-win test (1v1 elimination): 0 ongoing, -1 draw, else winner slot. */
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
		return (0i);	/* everyone still alive */
	}
	if (aliveCount == 1i) {
		return (aliveSlot);	/* one survivor */
	}
	if (aliveCount == 0i) {
		return (-1i);	/* mutual kill -> draw */
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

void
Arena_ResolveRound(int result)
{
	g_arenaWinnerSlot = result;

	if (result == -1i) {
		/* drawn round: award every occupied competitor a point (R29) */
		for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
			if (g_arenaCompetitor[i]) {
				g_arenaPoints[i]++;
			}
		}
		Arena_CenterprintAll("DRAW");
	} else if (result > 0i) {
		g_arenaPoints[result - 1i]++;
		entity winner = g_arenaCompetitor[result - 1i];
		if (winner) {
			Arena_CenterprintAll(sprintf("%s ^7wins the round", winner.netname));
		}
	}

	if (g_arenaHook_RoundEnd) {
		g_arenaHook_RoundEnd();
	}

	g_arenaState = ARENA_ROUND_END;
	g_arenaStateTime = time;
	g_arenaDeadline = time + autocvar_arena_roundEndTime;
	Arena_BroadcastState();
}

/** Returns winning slot (1-based) on points, or 0 if tied. */
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

void
Arena_EndMatch(int winnerSlot, bool noWinner)
{
	g_arenaState = ARENA_MATCH_END;
	g_arenaStateTime = time;
	g_arenaDeadline = time + autocvar_arena_matchEndTime;
	g_arenaMatchNoWinner = noWinner;
	g_arenaWinnerSlot = noWinner ? 0i : winnerSlot;

	if (noWinner) {
		Arena_CenterprintAll("MATCH ENDED - NO RESULT");
	} else if (winnerSlot > 0i && g_arenaCompetitor[winnerSlot - 1i]) {
		Arena_CenterprintAll(sprintf("%s ^7WINS THE MATCH", g_arenaCompetitor[winnerSlot - 1i].netname));
	}

	Arena_BroadcastState();
}

/* Rotation: winner stays (front), losers to the back; abort re-queues all
   survivors at the front with no winner credited. Then refill from the queue. */
void
Arena_Promote(void)
{
	int winnerSlot = g_arenaWinnerSlot;

	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		entity c = g_arenaCompetitor[i];
		g_arenaCompetitor[i] = __NULL__;
		g_arenaPoints[i] = 0i;

		if (!c) {
			continue;
		}

		/* a disconnected competitor was already cleared from the slot */
		c.arena_state = ARENASTATE_READY;
		userinfo.SetFloat(c, "*arena_state", ARENASTATE_READY);

		if (g_arenaMatchNoWinner) {
			/* voided match: survivors keep their place at the front, no win */
			Arena_QueuePushFront(c);
		} else if ((i + 1i) == winnerSlot) {
			/* winner stays - front of the queue so they are re-picked first */
			Arena_QueuePushFront(c);
		} else {
			/* loser rotates to the back */
			Arena_QueueAppend(c);
		}
	}

	g_arenaMatchNoWinner = false;
	g_arenaWinnerSlot = 0;

	if (Arena_ReadyCount() >= g_arenaMinReady) {
		Arena_BeginMatch();
	} else {
		Arena_EnterWarmup();
	}
}

/** Aborts an in-progress match with no winner (mid-match disconnect, R28). */
static void
Arena_AbortMatch(void)
{
	Arena_EndMatch(0i, true);
}

/* =========================================================================
 * Per-state ticks
 * ========================================================================= */
static void
Arena_TickWarmup(void)
{
	if (Arena_ReadyCount() >= g_arenaMinReady) {
		Arena_BeginMatch();
	}
}

static void
Arena_TickCountdown(void)
{
	/* a competitor dropped out (notready/disconnect) -> abort to warmup */
	if (Arena_CompetitorCount() < g_arenaSlotCount) {
		for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
			entity c = g_arenaCompetitor[i];
			g_arenaCompetitor[i] = __NULL__;
			if (c && c.arena_state == ARENASTATE_COMPETITOR) {
				c.arena_state = ARENASTATE_READY;
				userinfo.SetFloat(c, "*arena_state", ARENASTATE_READY);
				Arena_QueuePushFront(c);
			}
		}
		Arena_EnterWarmup();
		return;
	}

	int remaining = (int)ceil(g_arenaDeadline - time);
	if (remaining != g_arenaCountdownLast && remaining > 0i) {
		g_arenaCountdownLast = remaining;
		Arena_CenterprintAll(sprintf("%i", remaining));
	}

	if (time >= g_arenaDeadline) {
		Arena_BeginRound();
	}
}

static void
Arena_TickLive(void)
{
	/* brief grace so freshly-spawned competitors are not seen as dead */
	if (time < g_arenaLiveSince + 0.25f) {
		return;
	}

	int result = Arena_EvaluateRound();
	if (result != 0i) {
		Arena_ResolveRound(result);
		return;
	}

	if (!g_arenaSuddenNoTimer && time >= g_arenaRoundDeadline) {
		Arena_EnterSuddenDeath();
	}
}

/* SUDDEN_DEATH per-frame logic (one-hit kills + reaper) is completed in U6;
   for now it resolves a round once a competitor is eliminated. */
static void
Arena_TickSuddenDeath(void)
{
	if (time < g_arenaStateTime + 0.1f) {
		return;
	}

	/* one-hit kills (R18): a competitor flagged by the pain path this round
	   dies on the next safe tick - avoids re-entrancy inside the damage call */
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		entity c = g_arenaCompetitor[i];
		if (!c || !is.Alive(c)) {
			continue;
		}
		if (g_arenaSuddenHit[i]) {
			ents.Input(c, "Damage", "1000", world);
		}
	}

	/* reaper (R19): force-kill a competitor whose speed stays below the
	   threshold for reaperTime; the timer resets the moment they move */
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		entity c = g_arenaCompetitor[i];
		if (!c || !is.Alive(c)) {
			g_arenaReaperSince[i] = 0.0f;
			continue;
		}

		if (vlen(c.velocity) < autocvar_duel_reaperSpeed) {
			if (g_arenaReaperSince[i] == 0.0f) {
				g_arenaReaperSince[i] = time;
			} else if ((time - g_arenaReaperSince[i]) >= autocvar_duel_reaperTime) {
				centerprint(c, "REAPED");
				ents.Input(c, "Damage", "1000", world);
				g_arenaReaperSince[i] = 0.0f;
			}
		} else {
			g_arenaReaperSince[i] = 0.0f;
		}
	}

	int result = Arena_EvaluateRound();
	if (result != 0i) {
		Arena_ResolveRound(result);
	}
}

static void
Arena_TickRoundEnd(void)
{
	if (time < g_arenaDeadline) {
		return;
	}

	/* play all configured rounds, then resolve on points (+ tiebreaker) */
	if (g_arenaRound >= g_arenaRoundLimit) {
		int leader = Arena_LeaderSlot();

		if (leader > 0i) {
			Arena_EndMatch(leader, false);
			return;
		}

		/* tie on points -> play a tiebreaker round (R30) */
		g_arenaRound++;
		g_arenaTiebreaker = true;
		Arena_EnterCountdown();
		return;
	}

	/* next round of the same match - no queue rotation (R8) */
	g_arenaRound++;
	g_arenaTiebreaker = false;
	Arena_EnterCountdown();
}

static void
Arena_TickMatchEnd(void)
{
	if (time < g_arenaDeadline) {
		return;
	}
	Arena_Promote();
}

/* =========================================================================
 * Director tick - the single per-frame dispatcher
 * ========================================================================= */
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
	}

	Arena_BroadcastThrottled();
}

/* =========================================================================
 * Queue UX (U4)
 * ========================================================================= */
void
Arena_SetReady(entity pl)
{
	if (Arena_IsCompetitor(pl)) {
		return;
	}

	/* coming back from pure spectator - rejoin as a live free-play body */
	if (pl.team == TEAM_SPECTATOR || pl.arena_state == ARENASTATE_SPECTATOR) {
		if (g_arenaState == ARENA_WARMUP) {
			Arena_SpawnFreeplay(pl);
		} else {
			Arena_DemoteToFakeSpec(pl);
		}
	}

	pl.arena_state = ARENASTATE_READY;
	userinfo.SetFloat(pl, "*arena_state", ARENASTATE_READY);
	Arena_QueueAppend(pl);
	centerprint(pl, "You are READY");
}

void
Arena_SetNotReady(entity pl)
{
	if (Arena_IsCompetitor(pl)) {
		/* dropping out during COUNTDOWN is allowed; live matches ignore it */
		if (g_arenaState != ARENA_COUNTDOWN) {
			return;
		}
		int slot = Arena_SlotForPlayer(pl);
		if (slot != -1i) {
			g_arenaCompetitor[slot] = __NULL__;
		}
	}

	Arena_QueueRemove(pl);
	pl.arena_state = ARENASTATE_NOTREADY;
	userinfo.SetFloat(pl, "*arena_state", ARENASTATE_NOTREADY);
	centerprint(pl, "You are NOT READY");
}

void
Arena_SetSpectator(entity pl)
{
	if (Arena_IsCompetitor(pl)) {
		int slot = Arena_SlotForPlayer(pl);
		if (slot != -1i) {
			g_arenaCompetitor[slot] = __NULL__;
		}
	}

	Arena_QueueRemove(pl);
	pl.arena_state = ARENASTATE_SPECTATOR;
	userinfo.SetFloat(pl, "*arena_state", ARENASTATE_SPECTATOR);
	Arena_MakePureSpectator(pl);
}

/* =========================================================================
 * Mode -> director callback dispatchers
 * ========================================================================= */
void
Arena_OnPlayerConnect(entity pl)
{
	pl.arena_state = ARENASTATE_NOTREADY;
	userinfo.SetFloat(pl, "*arena_state", ARENASTATE_NOTREADY);
}

void
Arena_OnPlayerSpawn(entity pl)
{
	if (pl.arena_state == ARENASTATE_SPECTATOR) {
		Arena_MakePureSpectator(pl);
		return;
	}

	if (g_arenaState == ARENA_WARMUP) {
		Arena_SpawnFreeplay(pl);
	} else {
		/* joined mid-match -> watch as a fake-spectator until the next match */
		Arena_DemoteToFakeSpec(pl);
	}
}

bool
Arena_OnPlayerRequestRespawn(entity pl)
{
	/* free respawns only during warmup; the director owns match spawns */
	if (g_arenaState == ARENA_WARMUP && pl.arena_state != ARENASTATE_SPECTATOR) {
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

	/* an eliminated competitor becomes a fake-spec so they chase-cam the round;
	   the round result itself resolves in the tick, not here (handles draws) */
	if (Arena_IsCompetitor(victim)) {
		if (g_arenaState == ARENA_LIVE || g_arenaState == ARENA_SUDDEN_DEATH) {
			Arena_DemoteToFakeSpec(victim);
		}
	}
}

void
Arena_OnPlayerPain(entity victim)
{
	/* during sudden death, any non-lethal hit on a competitor is flagged so the
	   tick force-kills them (R18). Lethal hits resolve via PlayerKilled already. */
	if (g_arenaState != ARENA_SUDDEN_DEATH) {
		return;
	}
	if (!Arena_IsCompetitor(victim) || !is.Alive(victim)) {
		return;
	}

	int slot = Arena_SlotForPlayer(victim);
	if (slot != -1i) {
		g_arenaSuddenHit[slot] = 1i;
	}
}

void
Arena_OnPlayerDisconnect(entity pl)
{
	bool wasCompetitor = Arena_IsCompetitor(pl);

	/* always scrub them from the populations */
	Arena_QueueRemove(pl);

	int slot = Arena_SlotForPlayer(pl);
	if (slot != -1i) {
		g_arenaCompetitor[slot] = __NULL__;
	}

	/* a competitor leaving mid-match voids the match with no winner (R28) */
	if (wasCompetitor) {
		if (g_arenaState == ARENA_COUNTDOWN || g_arenaState == ARENA_LIVE
			|| g_arenaState == ARENA_SUDDEN_DEATH || g_arenaState == ARENA_ROUND_END) {
			Arena_AbortMatch();
		}
	}
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
	default:
		return (false);
	}
	return (false);
}
