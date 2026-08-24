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
   and an anti-stall reaper. All queue / state-machine / promotion logic lives
   in the shared arena director (arena.qc); this module only configures the
   director and supplies the per-mode round hooks. */

var int autocvar_duel_roundLimit = 3;

/* --- mode round hooks (see arena.h for the contract) --- */

/* Sudden-death entry. One-hit-kill enforcement is applied through the pain
   path (CodeCallback_PlayerDamage -> Arena_OnPlayerPain); the reaper runs in
   the director. See U6. */
void
Duel_SuddenDeath(void)
{
}

void
CodeCallback_Precaches(void)
{
	Util_SharedPrecaches();
	precache_sound("common/countdown.ogg");
	precache_sound("common/countdown-end.ogg");
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

	/* from shared.qc */
	Util_RemoveAllMonsters();
	Util_SetItemRespawnTimers();

	/* configure the arena director: 1v1, winner stays, best-of-N */
	Arena_Configure(ARENASHAPE_1V1, ARENAPROMO_WINNERSTAYS, autocvar_duel_roundLimit);

	/* Auto Assign opens hero selection first. Queue entry is explicit:
	   pick a hero, then cmd ready (READY UP). */
	Arena_SetAutoJoin(false);

	Arena_SetHooks(__NULL__, __NULL__, __NULL__, __NULL__, Duel_SuddenDeath);
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

	/* A pending Auto Assign stays on the waiting camera until hero selection. */
	if (STRING_SET(userinfo.GetString(playerEntity, "*duel_joining"))
		&& STRING_SET(userinfo.GetString(playerEntity, "*hero")) == false) {
		stuffcmd(playerEntity, "showClassSelectionMenu\n");
	}
}

bool
CodeCallback_PlayerRequestRespawn(entity playerEntity)
{
	/* Don't let queued players respawn until they've chosen a hero */
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
	/* sudden-death one-hit kills are applied by the director (U6) */
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

	/* Assign the duelist team before parking on the waiting cam. */
	ents.Input(playerEntity, "SetTeam", itos(teamNum), playerEntity);

	/* Auto Assign begins hero selection, but does not enter the queue yet. */
	userinfo.SetString(playerEntity, "*duel_joining", "1");
	userinfo.SetString(playerEntity, "*hero", "");
	Arena_SetNotReady(playerEntity);

	/* Intermission waiting cam (MakeTempSpectator — not ChangeToClass spectator). */
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
	case "selecthero": {
			int arenaState = (int)userinfo.GetFloat(playerEntity, "*arena_state");
			bool joining = STRING_SET(userinfo.GetString(playerEntity, "*duel_joining"));

			if (joining == false && arenaState < ARENASTATE_READY) {
				return (true);
			}

			string heroID = argv(1);

			/* queue players have no duelist slot yet; anchor roster lookups on team 1 */
			if (teams.Valid((int)playerEntity.team) == false) {
				ents.Input(playerEntity, "SetTeam", "1", playerEntity);
			}

			/* While the selector is open, only record the pick — applying the
			 * class here double-spawns (ChangeToClass + freeplay) and breaks
			 * the viewmodel. Spawn happens on menu close / READY UP. */
			if (Hero_TrySelectEx(playerEntity, heroID, joining == false) && joining) {
				userinfo.SetString(playerEntity, "*duel_joining", "");
				/* Re-open selector so READY UP is on screen after the pick. */
				stuffcmd(playerEntity, "showClassSelectionMenu\n");
			}
			return (true);
		}
	case "arena_enter":
		/* READY UP already entered freeplay. Only an armed/not-ready player
		 * needs the close action to spawn, otherwise this can rebuild the same
		 * hero inventory while the client is resolving its active weapon. */
		if ((int)userinfo.GetFloat(playerEntity, "*arena_state") == ARENASTATE_NOTREADY) {
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
		/* Rejoining spectators must choose a hero before entering the queue. */
		userinfo.SetString(playerEntity, "*duel_joining", "1");
		userinfo.SetString(playerEntity, "*hero", "");
		Arena_SetNotReady(playerEntity);
		Arena_SpawnWaitingView(playerEntity);
		stuffcmd(playerEntity, "showClassSelectionMenu\n");
		return (true);
	case "choosehero":
		/* Spectators re-enter via JOIN QUEUE, not hero pick. */
		if ((int)userinfo.GetFloat(playerEntity, "*arena_state") == ARENASTATE_SPECTATOR
			|| playerEntity.team == TEAM_SPECTATOR) {
			return (true);
		}
		/* Competitors keep their match slot; selecthero applies or queues the
		 * pick via Hero_TrySelectEx / heroswap policy (no *duel_joining). */
		if (Arena_IsCompetitor(playerEntity)
			|| (int)userinfo.GetFloat(playerEntity, "*arena_state") == ARENASTATE_READY) {
			stuffcmd(playerEntity, "showClassSelectionMenu\n");
			return (true);
		}
		/* Armed / not-ready: reopen picker without leaving freeplay. */
		userinfo.SetString(playerEntity, "*duel_joining", "1");
		stuffcmd(playerEntity, "showClassSelectionMenu\n");
		return (true);
	default:
		break;
	}

	return (Arena_OnClientCommand(playerEntity, command));
}
