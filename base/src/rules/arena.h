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
 *                    Hook_RoundEnd, Hook_SuddenDeath, Hook_SuddenDeathTick,
 *                    Hook_PlayerPain);
 *
 * The mode's CodeCallback_* entry points delegate up to the director's
 * Arena_* dispatchers. Arena owns the lifecycle, participation, roster,
 * results, and broadcast. Mode policy (one-hit sudden death, reaper, boss
 * pick, asymmetric win tests) lives in hooks — never by writing g_arenaState
 * or *arena_state from the mode.
 *
 * The director never ends the map between matches (no game.EndMap*); it runs
 * multiple matches per map load.
 *
 * --- Hook contract -------------------------------------------------------
 *  void()                          Hook_RoundStart        - LIVE/tiebreaker
 *                                                         round setup
 *  void(entity victim, entity atk) Hook_PlayerDeath       - a competitor died
 *  int()                           Hook_RoundWinTest      - 0 ongoing, -1 draw,
 *                                                         else winning slot (1based)
 *  void()                          Hook_RoundEnd          - round resolved
 *  void()                          Hook_SuddenDeath       - SUDDEN_DEATH entry
 *  void()                          Hook_SuddenDeathTick   - SUDDEN_DEATH per-frame
 *  void(entity victim)             Hook_PlayerPain        - competitor pain/damage
 * Every hook is optional; the director null-guards each call. A mode that
 * registers no Hook_RoundWinTest falls back to a generic alive-count test.
 *
 * Hypothetical boss/VSH mode using only this public API:
 *   Arena_Configure(ARENASHAPE_BOSS, ARENAPROMO_WINNERSTAYS, roundLimit);
 *   Arena_SetHooks(VSH_RoundStart, VSH_PlayerDeath, VSH_RoundWinTest,
 *                  VSH_RoundEnd, VSH_SuddenDeath, VSH_SuddenDeathTick,
 *                  VSH_PlayerPain);
 * Boss pick belongs in VSH_RoundStart; asymmetric win in VSH_RoundWinTest;
 * specialized sudden death in the SD entry/tick hooks. None of that requires
 * editing Arena_Transition or Arena_ChangeParticipation.
 * ========================================================================= */

/* director states */
#define ARENA_WARMUP		0
#define ARENA_COUNTDOWN		1
#define ARENA_LIVE			2
#define ARENA_SUDDEN_DEATH	3
#define ARENA_ROUND_END		4
#define ARENA_MATCH_END		5
#define ARENA_SELECT		6	/* set play: both sides pick a hero (blind) */
#define ARENA_SET_END		7	/* set play: results, rematch vote */

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

/* match/round result — independent of lifecycle state */
#define ARENARESULT_NONE		0
#define ARENARESULT_WIN			1
#define ARENARESULT_DRAW		2
#define ARENARESULT_VOID		3

/* transition / participation reasons */
#define ARENAREASON_NORMAL			0
#define ARENAREASON_ROUND_RESOLVED	1
#define ARENAREASON_TIME_EXPIRED	2
#define ARENAREASON_PARTICIPANT_LEFT	3
#define ARENAREASON_NOT_READY		4
#define ARENAREASON_SPECTATE		5
#define ARENAREASON_DISCONNECT		6
#define ARENAREASON_INVALID_ROSTER	7
#define ARENAREASON_MATCH_COMPLETE	8
#define ARENAREASON_SET_CLOSED		9

/* =========================================================================
 * Set play (fighting-game style; on when arena_setFirstTo > 0)
 *
 * A set is first-to-N games between the same competitors; each game is the
 * director's usual best-of-roundLimit rounds, ending as soon as one side has
 * a majority. Before each game the competitors pick a hero blind (SELECT);
 * between games only the loser of the last game may change (counterpick).
 * At the end of a set (SET_END) each competitor votes "set_rematch",
 * "set_rematch_hero" (rematch, but pick again) or "set_leave". Everyone
 * rematching starts a new set (a runback); a leave or the timer closes the
 * set: its competitors become non-ready waiting players and serverinfo
 * arena_set_serial goes up, which tells clients to leave. A competitor who
 * leaves while a set runs forfeits it. Finished sets are reported to the
 * engine with "live_set_seat" / "live_set_report" (Bulwark Live records),
 * which an engine without them ignores.
 *
 * Serverinfo for menus (all set keys empty without set play):
 *   arena_set        "firstTo game wins1 wins2 runbacks result winnerSide counterSide"
 *                    result: 0 running, 1 complete, 2 forfeit
 *   arena_set_serial number of sets closed on this map (a close tells clients to leave)
 *   arena_set_closed why the last set closed: "rematch declined", "time", "left", "void"
 *   arena_set_log    each finished game's rounds, e.g. "2-1 0-2"
 *   arena_set_left   name of the player who left the set, and "behind" or "even"
 *   arena_deadline   whole seconds left in SELECT / MATCH END / SET END, else ""
 *   arena_lock       per slot: 1 hero locked, 0 not ("1 0")
 *   arena_vote       per slot: 0 none, 1 rematch, 2 rematch + new hero, 3 leave
 *   arena_heroN      slot N's hero, "" while picks are hidden
 * ========================================================================= */
#define SETRESULT_NONE		0
#define SETRESULT_COMPLETE	1
#define SETRESULT_FORFEIT	2

#define SETVOTE_NONE		0
#define SETVOTE_REMATCH		1
#define SETVOTE_REMATCH_HERO	2
#define SETVOTE_LEAVE		3

var float autocvar_arena_setFirstTo = 0;		/* games to win a set; 0 = no sets (winner stays) */
var float autocvar_arena_selectTime = 20.0f;	/* blind hero pick before a set's first game */
var float autocvar_arena_counterpickTime = 10.0f;	/* loser's hero change between games */
var float autocvar_arena_revealTime = 2.5f;		/* both locked: heroes shown before the countdown */
var float autocvar_arena_gameEndTime = 4.0f;	/* results between games */
var float autocvar_arena_voteTime = 15.0f;		/* rematch vote */
var float autocvar_arena_forfeitTime = 6.0f;	/* results after a forfeit */

/* sizing */
#define ARENA_MAXSLOTS		8	/* max competitors (asymmetric-capable) */
#define ARENA_MAXQUEUE		32	/* FIFO ready queue capacity */

/* tunable director constants (mode-specific tuning lives in the mode progs) */
var float autocvar_arena_countdownTime = 5.0f;	/* COUNTDOWN duration */
var float autocvar_arena_roundTime = 60.0f;		/* LIVE timer before sudden death */
var float autocvar_arena_roundEndTime = 3.0f;	/* ROUND_END pause */
var float autocvar_arena_matchEndTime = 5.0f;	/* MATCH_END pause before rotation */
var float autocvar_arena_invariants = 1.0f;		/* print roster/queue invariant failures */

/* mode hook table (set by the mode via Arena_SetHooks) */
var void() g_arenaHook_RoundStart;
var void(entity victim, entity attacker) g_arenaHook_PlayerDeath;
var int() g_arenaHook_RoundWinTest;
var void() g_arenaHook_RoundEnd;
var void() g_arenaHook_SuddenDeath;
var void() g_arenaHook_SuddenDeathTick;
var void(entity victim) g_arenaHook_PlayerPain;

/* --- public director API (called by the mode progs) --- */
void Arena_Configure(int teamShape, int promotionPolicy, int roundLimit);
void Arena_SetHooks(void() roundStart, void(entity, entity) playerDeath, int() roundWinTest, void() roundEnd, void() suddenDeath, void() suddenDeathTick, void(entity) playerPain);

/* Q3-style auto-join: when enabled, connecting players are auto-readied into
   the queue during warmup instead of being parked on the waiting camera.
   Default OFF (manual "ready") so 2v2/Boss modes are untouched. */
void Arena_SetAutoJoin(bool enabled);

/* Fixed competitor spawn class (Q3-faithful loadout, no hero/class pick).
   When unset (""), competitors spawn via the hero roster as before. */
void Arena_SetSpawnClass(string className);

/* Inter-round COUNTDOWN (after the match has gone live). Prints count..1
   at `step` seconds per number (e.g. 3 at 0.5s → "3","2","1" over 1.5s).
   Match-start still uses autocvar_arena_countdownTime at 1s ticks.
   count <= 0 keeps the match-start countdown; step <= 0 keeps 1s ticks. */
void Arena_SetRoundCountdown(float count, float step);
void Arena_FrameStart(void);
void Arena_OnPlayerConnect(entity pl);
void Arena_OnPlayerSpawn(entity pl);
bool Arena_OnPlayerRequestRespawn(entity pl);
void Arena_OnPlayerKilled(entity victim, entity attacker);
void Arena_OnPlayerPain(entity victim);
void Arena_OnPlayerDisconnect(entity pl);
bool Arena_OnClientCommand(entity pl, string command);

/* --- queue UX (U4) --- */
void Arena_ChangeParticipation(entity pl, int newState, int reason);
void Arena_SetReady(entity pl);
void Arena_SetNotReady(entity pl);
void Arena_SetSpectator(entity pl);
void Arena_SpawnWaitingView(entity pl);
void Arena_DemoteToFakeSpec(entity pl);
void Arena_BroadcastState(void);
void Arena_EnsureFreeplay(entity pl);

/* --- queries (modes must use these instead of reading *arena_state) --- */
int Arena_GetState(void);
int Arena_GetPlayerState(entity pl);
int Arena_GetResult(void);
int Arena_GetWinnerSlot(void);
entity Arena_CompetitorAt(int slot);
int Arena_ReadyCount(void);
int Arena_CompetitorCount(void);
bool Arena_IsCompetitor(entity pl);
int Arena_SlotForPlayer(entity pl);

/* set play */
bool Arena_SetPlay(void);
bool Arena_HeroLocked(entity pl);

#endif
