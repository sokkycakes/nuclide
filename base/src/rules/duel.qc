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

/* Duel: the v1 arena proving mode.
   1v1, winner-stays, best-of-N single-elimination rounds with sudden death
   and an anti-stall reaper. Queue / state-machine / promotion live in the
   shared arena director (arena.qc). This module configures the director and
   implements Duel-only sudden-death policy through Arena hooks. */

var int autocvar_duel_roundLimit = 3;
var float autocvar_duel_reaperSpeed = 100.0f;	/* below this speed = "stalled" */
var float autocvar_duel_reaperTime = 3.0f;		/* stalled grace before elimination */
var float autocvar_duel_roundCountdown = 3.0f;		/* inter-round start number (3, 2, 1) */
var float autocvar_duel_roundCountdownStep = 0.5f;	/* seconds per number */

var float g_duelReaperSince[ARENA_MAXSLOTS];
var int g_duelSuddenHit[ARENA_MAXSLOTS];

/* --- mode round hooks (see arena.h for the contract) --- */

void
Duel_SuddenDeath(void)
{
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		g_duelReaperSince[i] = 0.0f;
		g_duelSuddenHit[i] = 0i;
	}
}

void
Duel_SuddenDeathTick(void)
{
	/* one-hit kills: a competitor flagged by the pain path this round dies
	   on the next safe tick — avoids re-entrancy inside the damage call */
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		entity c = Arena_CompetitorAt(i);
		if (!c || !is.Alive(c)) {
			continue;
		}
		if (g_duelSuddenHit[i]) {
			ents.Input(c, "Damage", "1000", world);
		}
	}

	/* reaper: force-kill a competitor whose speed stays below the threshold
	   for reaperTime; the timer resets the moment they move */
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		entity c = Arena_CompetitorAt(i);
		if (!c || !is.Alive(c)) {
			g_duelReaperSince[i] = 0.0f;
			continue;
		}

		if (vlen(c.velocity) < autocvar_duel_reaperSpeed) {
			if (g_duelReaperSince[i] == 0.0f) {
				g_duelReaperSince[i] = time;
			} else if ((time - g_duelReaperSince[i]) >= autocvar_duel_reaperTime) {
				centerprint(c, "REAPED");
				ents.Input(c, "Damage", "1000", world);
				g_duelReaperSince[i] = 0.0f;
			}
		} else {
			g_duelReaperSince[i] = 0.0f;
		}
	}
}

void
Duel_PlayerPain(entity victim)
{
	int slot;

	if (Arena_GetState() != ARENA_SUDDEN_DEATH) {
		return;
	}
	if (!Arena_IsCompetitor(victim) || !is.Alive(victim)) {
		return;
	}

	slot = Arena_SlotForPlayer(victim);
	if (slot != -1i) {
		g_duelSuddenHit[slot] = 1i;
	}
}

void
CodeCallback_Precaches(void)
{
	Util_SharedPrecaches();
	precache_sound("common/countdown.ogg");
	precache_sound("common/countdown-end.ogg");
	precache_sound("common/countdown-mini.ogg");
	precache_sound("common/countdown-end-mini.ogg");
}

void
CodeCallback_StartGameType(void)
{
	motd.LoadDefault();
	game.SetSpawnPoint("info_intermission");

	/* both duelist slots are marked closed so the client team picker hides
	   them; players enter the queue via auto-join, not a manual team pick.
	   TEAM_1/TEAM_2 are still used internally for spawnpoints + colors. */
	teams.SetUp(1, "Duelist 1", [155, 205, 255], false);
	teams.SetUp(2, "Duelist 2", [255, 64, 64], false);
	teams.SetSpawnPoint(1, "info_player_deathmatch");
	teams.SetSpawnPoint(2, "info_player_deathmatch");

	/* shared hero roster for both duel slots (team pick is suppressed) */
	Hero_RegisterRoster(1);
	Hero_RegisterRoster(2);
	Hero_SetPolicy(HEROSWAP_ATSPAWN, HEROCOMP_DUPLICATES);

	Util_RemoveAllMonsters();
	Util_SetItemRespawnTimers();

	Arena_Configure(ARENASHAPE_1V1, ARENAPROMO_WINNERSTAYS, autocvar_duel_roundLimit);
	Arena_SetRoundCountdown(autocvar_duel_roundCountdown, autocvar_duel_roundCountdownStep);
	Arena_SetAutoJoin(false);
	Arena_SetHooks(__NULL__, __NULL__, __NULL__, __NULL__,
		Duel_SuddenDeath, Duel_SuddenDeathTick, Duel_PlayerPain);
}

void
CodeCallback_PlayerConnect(entity playerEntity)
{
	userinfo.SetString(playerEntity, "*duel_joining", "");
	userinfo.SetString(playerEntity, "*hero", "");
	Arena_OnPlayerConnect(playerEntity);
}

void
CodeCallback_PlayerDisconnect(entity playerEntity)
{
	Arena_OnPlayerDisconnect(playerEntity);
}

void
CodeCallback_PlayerSpawn(entity playerEntity)
{
	Arena_OnPlayerSpawn(playerEntity);

	if (STRING_SET(userinfo.GetString(playerEntity, "*duel_joining"))
		&& STRING_SET(userinfo.GetString(playerEntity, "*hero")) == false) {
		stuffcmd(playerEntity, "showClassSelectionMenu\n");
	}
}

bool
CodeCallback_PlayerRequestRespawn(entity playerEntity)
{
	if (STRING_SET(userinfo.GetString(playerEntity, "*hero")) == false) {
		return (false);
	}
	return (Arena_OnPlayerRequestRespawn(playerEntity));
}

void
CodeCallback_PlayerKilled(entity playerTarget, entity inflictor, entity attacker, string weapon)
{
	combat.Obituary(playerTarget.netname, attacker.netname, weapon, "");
	playerTarget.deaths++;
	Arena_OnPlayerKilled(playerTarget, attacker);
}

void
CodeCallback_PlayerDamage(entity playerTarget, entity attacker, entity damageDecl)
{
	Arena_OnPlayerPain(playerTarget);
}

void
CodeCallback_FrameStart(void)
{
	Arena_FrameStart();
}

bool
CodeCallback_CallRequestTeam(entity playerEntity, int teamNum)
{
	if (teamNum == TEAM_SPECTATOR) {
		Arena_SetSpectator(playerEntity);
		return (true);
	}

	if (teams.Valid(teamNum) == false) {
		return (false);
	}

	if (Arena_IsCompetitor(playerEntity)) {
		return (true);
	}

	ents.Input(playerEntity, "SetTeam", itos(teamNum), playerEntity);

	userinfo.SetString(playerEntity, "*duel_joining", "1");
	userinfo.SetString(playerEntity, "*hero", "");
	Arena_SetNotReady(playerEntity);

	Arena_SpawnWaitingView(playerEntity);

	if (STRING_SET(userinfo.GetString(playerEntity, "*hero")) == false) {
		stuffcmd(playerEntity, "showClassSelectionMenu\n");
	}

	return (true);
}

bool
CodeCallback_ClientCommand(entity playerEntity, string command)
{
	tokenize(command);

	switch (argv(0)) {
	case "changehero": {
		if (teams.Valid((int)playerEntity.team) == false) {
			ents.Input(playerEntity, "SetTeam", "1", playerEntity);
		}
		Hero_TrySelectEx(playerEntity, Hero_NormalizeID(argv(1)), true);
		return (true);
	}
	case "selecthero": {
			int arenaState = Arena_GetPlayerState(playerEntity);
			bool joining = STRING_SET(userinfo.GetString(playerEntity, "*duel_joining"));

			if (joining == false && arenaState < ARENASTATE_READY) {
				return (true);
			}

			string heroID = Hero_NormalizeID(argv(1));

			if (teams.Valid((int)playerEntity.team) == false) {
				ents.Input(playerEntity, "SetTeam", "1", playerEntity);
			}

			/* While the selector is open, only record the pick — applying the
			 * class here double-spawns (ChangeToClass + freeplay) and breaks
			 * the viewmodel. Spawn happens on menu close / READY UP. */
			if (Hero_TrySelectEx(playerEntity, heroID, joining == false) && joining) {
				userinfo.SetString(playerEntity, "*duel_joining", "");
				stuffcmd(playerEntity, "showClassSelectionMenu\n");
			}
			return (true);
		}
	case "arena_enter":
		if (Arena_GetPlayerState(playerEntity) == ARENASTATE_NOTREADY) {
			Arena_EnsureFreeplay(playerEntity);
		}
		return (true);
	case "spectate":
		if (is.Player(playerEntity)) {
			userinfo.SetString(playerEntity, "*duel_joining", "");
			Arena_SetSpectator(playerEntity);
			return (true);
		}
		return (false);
	case "play":
		userinfo.SetString(playerEntity, "*duel_joining", "1");
		userinfo.SetString(playerEntity, "*hero", "");
		Arena_SetNotReady(playerEntity);
		Arena_SpawnWaitingView(playerEntity);
		stuffcmd(playerEntity, "showClassSelectionMenu\n");
		return (true);
	case "choosehero":
		if (Arena_GetPlayerState(playerEntity) == ARENASTATE_SPECTATOR
			|| playerEntity.team == TEAM_SPECTATOR) {
			return (true);
		}
		if (Arena_IsCompetitor(playerEntity)
			|| Arena_GetPlayerState(playerEntity) == ARENASTATE_READY) {
			stuffcmd(playerEntity, "showClassSelectionMenu\n");
			return (true);
		}
		userinfo.SetString(playerEntity, "*duel_joining", "1");
		stuffcmd(playerEntity, "showClassSelectionMenu\n");
		return (true);
	default:
		break;
	}

	return (Arena_OnClientCommand(playerEntity, command));
}
