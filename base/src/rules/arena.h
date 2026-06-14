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

#ifndef ARENA_H
#define ARENA_H

/* =========================================================================
 * Arena match director (shared RuleC include)
 *
 * A mode-agnostic round/match state machine for arena gamemodes. Each arena
 * gamemode is a thin rules progs that #includes this file (alongside
 * shared.qc) and configures it from CodeCallback_StartGameType:
 *
 *     Arena_Configure(ARENASHAPE_1V1, ARENAPROMO_WINNERSTAYS, roundLimit);
 *     Arena_SetHooks(Hook_RoundStart, Hook_PlayerDeath, Hook_RoundWinTest,
 *                    Hook_RoundEnd, Hook_SuddenDeath);
 *
 * The mode's CodeCallback_* entry points delegate up to the director's
 * Arena_* dispatchers; the director owns the state machine, the three player
 * populations (ready queue / not-ready / pure spectator), promotion
 * (winner stays, loser rotates), spectator transitions and state broadcast.
 *
 * The director never ends the map between matches (no game.EndMap*); it runs
 * multiple matches per map load.
 *
 * --- Hook contract -------------------------------------------------------
 *  void()                          Hook_RoundStart   - LIVE entry, per round
 *  void(entity victim, entity atk) Hook_PlayerDeath  - a competitor died
 *  int()                           Hook_RoundWinTest - 0 ongoing, -1 draw,
 *                                                      else winning slot (1based)
 *  void()                          Hook_RoundEnd     - round resolved
 *  void()                          Hook_SuddenDeath  - SUDDEN_DEATH entry
 * Every hook is optional; the director null-guards each call. A mode that
 * registers no Hook_RoundWinTest falls back to a generic alive-count test.
 * ========================================================================= */

/* director states */
#define ARENA_WARMUP		0
#define ARENA_COUNTDOWN		1
#define ARENA_LIVE			2
#define ARENA_SUDDEN_DEATH	3
#define ARENA_ROUND_END		4
#define ARENA_MATCH_END		5

/* team shapes (drive minimum-ready + promotion fill counts) */
#define ARENASHAPE_1V1		0
#define ARENASHAPE_2V2		1
#define ARENASHAPE_BOSS		2	/* 1-vs-many (designed-for, not v1) */

/* promotion policies */
#define ARENAPROMO_WINNERSTAYS	0

/* per-player queue state, stored in userinfo *arena_state (no entity .field -
   rules progs load after main progs init and cannot allocate new fields) */
#define ARENASTATE_NOTREADY		0	/* present, not queued (default) */
#define ARENASTATE_READY		1	/* in FIFO ready queue */
#define ARENASTATE_SPECTATOR	2	/* pure spectator, opted out */
#define ARENASTATE_COMPETITOR	3	/* currently competing */

/* sizing */
#define ARENA_MAXSLOTS		8	/* max competitors (asymmetric-capable) */
#define ARENA_MAXQUEUE		32	/* FIFO ready queue capacity */

/* tunable director constants (mode-specific tuning lives in the mode progs) */
var float autocvar_arena_countdownTime = 5.0f;	/* COUNTDOWN duration */
var float autocvar_arena_roundTime = 60.0f;		/* LIVE timer before sudden death */
var float autocvar_arena_roundEndTime = 3.0f;	/* ROUND_END pause */
var float autocvar_arena_matchEndTime = 5.0f;	/* MATCH_END pause before rotation */

/* sudden-death reaper anti-stall (U6). duel_-named per plan, but read by the
   shared director since the per-frame tick lives here. */
var float autocvar_duel_reaperSpeed = 100.0f;	/* below this speed = "stalled" */
var float autocvar_duel_reaperTime = 3.0f;		/* stalled grace before elimination */

/* mode hook table (set by the mode via Arena_SetHooks) */
var void() g_arenaHook_RoundStart;
var void(entity victim, entity attacker) g_arenaHook_PlayerDeath;
var int() g_arenaHook_RoundWinTest;
var void() g_arenaHook_RoundEnd;
var void() g_arenaHook_SuddenDeath;

/* --- public director API (called by the mode progs) --- */
void Arena_Configure(int teamShape, int promotionPolicy, int roundLimit);
void Arena_SetHooks(void() roundStart, void(entity, entity) playerDeath, int() roundWinTest, void() roundEnd, void() suddenDeath);
void Arena_FrameStart(void);
void Arena_OnPlayerConnect(entity pl);
void Arena_OnPlayerSpawn(entity pl);
bool Arena_OnPlayerRequestRespawn(entity pl);
void Arena_OnPlayerKilled(entity victim, entity attacker);
void Arena_OnPlayerPain(entity victim);
void Arena_OnPlayerDisconnect(entity pl);
bool Arena_OnClientCommand(entity pl, string command);

/* --- queue UX (U4) --- */
void Arena_SetReady(entity pl);
void Arena_SetNotReady(entity pl);
void Arena_SetSpectator(entity pl);
void Arena_BroadcastState(void);

/* --- queries --- */
int Arena_ReadyCount(void);
int Arena_CompetitorCount(void);
bool Arena_IsCompetitor(entity pl);
int Arena_SlotForPlayer(entity pl);

#endif
