/*
 * Copyright (c) 2024 Marco Cawthorne <marco@icculus.org>
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

/* Basic Deathmatch

   Whoever reaches the designated score-limit, wins.

   Free-for-all, but hero-enabled: every player picks from the shared Stiletto
   roster and spawns as that hero. The roster is registered on a single notional
   team (team 1) whose NAME serverinfo is set directly rather than via
   teams.SetUp() -- that keeps the global "teams" count at 0, so IsTeamplay()
   stays false and FFA damage is never gated by the friendly-fire check. Players
   are anchored to team 1 only so the team-keyed roster lookups resolve. */
void
DM_PlayerSpawn(entity playerTarget)
{
	/* anchor on team 1 so Hero_ResolveSpawnHero / Hero_TrySelect resolve the
	   roster; this does NOT enable teamplay (see CodeCallback_StartGameType). */
	if (teams.Valid((int)playerTarget.team) == false) {
		ents.Input(playerTarget, "SetTeam", "1", playerTarget);
	}

	/* spawn as the player's chosen hero, else the team default (shared.qc) */
	string heroID = Hero_ResolveSpawnHero(playerTarget);
	ents.ChangeToClass(playerTarget, heroID);
	game.TeleportToSpawn(playerTarget);

	/* first spawn without a pick: prompt the hero menu */
	if (STRING_SET(userinfo.GetString(playerTarget, "*hero")) == false) {
		stuffcmd(playerTarget, "showClassSelectionMenu\n");
	}
}

/* rule callbacks, called by Nuclide if present */
void
CodeCallback_Precaches(void)
{
	Util_SharedPrecaches();
}

void
CodeCallback_StartGameType(void)
{
	motd.LoadDefault();
	game.SetSpawnPoint("info_player_deathmatch");

	/* Name team 1 directly (no teams.SetUp -> no "teams" count -> not
	   teamplay) so the shared hero roster + selection menu work in FFA. */
	serverinfo.SetString("team_1", "Stiletto");
	Hero_RegisterRoster(1);
	Hero_SetPolicy(HEROSWAP_ATSPAWN, HEROCOMP_DUPLICATES);

	/* from shared.qc */
	Util_RemoveAllMonsters();
	Util_SetItemRespawnTimers();
}

void
CodeCallback_PlayerSpawn(entity playerTarget)
{
	DM_PlayerSpawn(playerTarget);
}

bool
CodeCallback_PlayerRequestRespawn(entity playerTarget)
{
	DM_PlayerSpawn(playerTarget);
	return (true);
}

bool
CodeCallback_CallRequestTeam(entity playerEntity, int teamNum)
{
	/* they want to spectate */
	if (teamNum == TEAM_SPECTATOR) {
		if (is.Alive(playerEntity) == true) {
			ents.Input(playerEntity, "Damage", "1000", playerEntity);
		}

		ents.Input(playerEntity, "SetTeam", itos(TEAM_SPECTATOR), playerEntity);
		ents.ChangeToClass(playerEntity, "spectator");
		userinfo.SetString(playerEntity, "topcolor", "0xffffff");
		userinfo.SetString(playerEntity, "bottomcolor", "0xffffff");
		game.TeleportToSpawn(playerEntity);
		return (true);
	}

	/* join FFA play (team 1 is the notional Stiletto roster team) */
	if (teamNum != 1) {
		return (false);
	}

	ents.Input(playerEntity, "SetTeam", "1", playerEntity);

	if (is.Alive(playerEntity) == false) {
		DM_PlayerSpawn(playerEntity);
	} else {
		ents.Input(playerEntity, "Damage", "1000", playerEntity);
	}

	return (true);
}

bool
CodeCallback_ClientCommand(entity playerEntity, string command)
{
	tokenize(command);

	switch (argv(0)) {
	case "selecthero": {
		/* capture the id before any helper re-tokenizes (shared.qc) */
		string heroID = argv(1);

		/* anchor roster lookups on team 1 if not assigned yet */
		if (teams.Valid((int)playerEntity.team) == false) {
			ents.Input(playerEntity, "SetTeam", "1", playerEntity);
		}

		Hero_TrySelect(playerEntity, heroID);
		return (true);
	}
	default:
		return (false);
	}

	return (true);
}

void
CodeCallback_PlayerKilled(entity playerTarget, entity inflictor, entity attacker, string weapon)
{
	if (playerTarget == attacker)
		combat.Obituary(playerTarget.netname, attacker.netname, weapon, "self");
	else
		combat.Obituary(playerTarget.netname, attacker.netname, weapon, "");

	/* death-counter */
	playerTarget.deaths++;

	/* update score-counter */
	if (is.Player(attacker)) {
		/* self harm won't be rewarded */
		if (playerTarget == attacker) {
			attacker.frags--;
		} else {
			attacker.frags++;
		}
	}
}
