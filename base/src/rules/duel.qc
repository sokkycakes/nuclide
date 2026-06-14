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

	/* Q3-faithful: auto-join the queue (no manual "ready"); hero pick is via
	   the class menu (B / showClassSelectionMenu), not a team picker */
	Arena_SetAutoJoin(true);

	Arena_SetHooks(__NULL__, __NULL__, __NULL__, __NULL__, Duel_SuddenDeath);
}

void
CodeCallback_PlayerConnect(entity playerEntity)
{
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

	/* no team-select chain in duel; prompt hero pick on first queue spawn */
	if ((int)userinfo.GetFloat(playerEntity, "*arena_state") != ARENASTATE_SPECTATOR
		&& STRING_SET(userinfo.GetString(playerEntity, "*hero")) == false) {
		stuffcmd(playerEntity, "showClassSelectionMenu\n");
	}
}

bool
CodeCallback_PlayerRequestRespawn(entity playerEntity)
{
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

	ents.Input(playerEntity, "SetTeam", itos(teamNum), playerEntity);

	if (Arena_IsCompetitor(playerEntity)) {
		return (true);
	}

	if (g_arenaState == ARENA_WARMUP) {
		if (is.Alive(playerEntity)) {
			ents.Input(playerEntity, "Damage", "1000", playerEntity);
		}
		Arena_SpawnWaitingView(playerEntity);
	} else if (is.Alive(playerEntity)) {
		ents.Input(playerEntity, "Damage", "1000", playerEntity);
		Arena_DemoteToFakeSpec(playerEntity);
	}

	return (true);
}

bool
CodeCallback_ClientCommand(entity playerEntity, string command)
{
	tokenize(command);

	switch (argv(0)) {
	case "selecthero": {
		string heroID = argv(1);

		/* queue players have no duelist slot yet; anchor roster lookups on team 1 */
		if (teams.Valid((int)playerEntity.team) == false) {
			ents.Input(playerEntity, "SetTeam", "1", playerEntity);
		}

		Hero_TrySelect(playerEntity, heroID);
		return (true);
	}
	case "spectate":
		if (is.Player(playerEntity)) {
			Arena_SetSpectator(playerEntity);
			return (true);
		}
		return (false);
	case "play":
		/* intercept the generic spectator->play path (cmd_cl.qc) so rejoining
		   spectators are routed back through the queue, not PutClientInServer */
		Arena_SetReady(playerEntity);
		return (true);
	default:
		break;
	}

	return (Arena_OnClientCommand(playerEntity, command));
}
