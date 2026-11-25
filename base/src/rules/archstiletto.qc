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

/* Archstiletto (ruleset ARCHSTILETTO, R26): one boss against everyone else.
 *
 * Each round one competitor is the Archstiletto boss (hero_archstiletto with
 * archstiletto_bossHealth HP, 100 by default: roster R-HP3). The boss takes
 * double damage while airborne and no tool punish (R-HP5 / R-STUN3); it also
 * gets no post-hit i-frames or out-of-combat heal-to-full, which would make a
 * 100 HP pool unkillable at one damage per hit. Those rules live in the server
 * progs (stiletto_combat.qc) and switch on with the userinfo key
 * *stiletto_boss, which this mode sets on the boss only.
 * Everyone else is a challenger on a normal hero (Archstiletto is not offered
 * to challengers). The boss wins the round when every challenger is dead; the
 * challengers win when the boss dies.
 *
 * Boss rotation: the boss seat moves one seat along every round, in seat order
 * (seat order = ready-queue order, so last match's winner bosses first). The
 * match is one round per competitor by default (archstiletto_roundLimit 0),
 * so everyone bosses once; a tie on points plays sudden-death rounds that
 * keep rotating.
 *
 * Scoring: a boss win scores for the boss. A challenger win scores for the
 * challenger who landed the killing blow on the boss, or, when the boss died
 * some other way, for the challenger who dealt it the most damage.
 *
 * Sudden death (round timer ran out): the boss bleeds
 * archstiletto_suddenDeathBleed HP per second until someone wins.
 *
 * Seats: one boss plus up to seven challengers. Empty seats fill with bots up
 * to archstiletto_players for a waiting human (arena_bots); otherwise the
 * match starts with whoever is ready (two or more) after arena_fillWait. */

var int autocvar_archstiletto_players = 4;			/* seats to fill (1 boss + challengers) */
var int autocvar_archstiletto_roundLimit = 0;		/* 0 = one round per competitor */
var float autocvar_archstiletto_bossHealth = 100.0f;
var float autocvar_archstiletto_suddenDeathBleed = 5.0f;
var float autocvar_archstiletto_roundCountdown = 3.0f;
var float autocvar_archstiletto_roundCountdownStep = 0.5f;

#define AS_TEAM_CHALLENGERS	1
#define AS_TEAM_BOSS		2

var int g_asBossSlot = -1;
var int g_asRotation;
entity g_asBoss;
var int g_asLastResult;
var int g_asKillerSlot = -1;
var float g_asDamage[ARENA_MAXSLOTS];
var float g_asBossHealth;
var float g_asNextBleed;
var int g_asPrevState;

/* =========================================================================
 * Helpers
 * ========================================================================= */
int
AS_FullSeats(void)
{
	int seats = autocvar_archstiletto_players;
	if (seats < 2i) {
		seats = 2i;
	}
	if (seats > ARENA_MAXSLOTS) {
		seats = ARENA_MAXSLOTS;
	}
	return (seats);
}

/* challengers play the normal roster; the boss hero is the mode's */
void
AS_RegisterChallengerRoster(int teamNum)
{
	teams.AddClass(teamNum, "hero_collier");
	teams.AddClass(teamNum, "hero_beaumont");
	teams.AddClass(teamNum, "hero_vagrant");
	teams.AddClass(teamNum, "hero_skipstream");
	teams.AddClass(teamNum, "hero_angel");
	teams.AddClass(teamNum, "hero_motionblue");
	teams.AddClass(teamNum, "hero_juliet");
}

bool
AS_IsBoss(entity pl)
{
	return (pl && pl == g_asBoss);
}

void
AS_ClearBossMark(entity pl)
{
	if (pl && STRING_SET(userinfo.GetString(pl, "*stiletto_boss"))) {
		userinfo.SetString(pl, "*stiletto_boss", "");
	}
}

void
AS_ClearBoss(void)
{
	AS_ClearBossMark(g_asBoss);
	g_asBoss = __NULL__;
	g_asBossSlot = -1i;
	serverinfo.SetString("arch_boss", "");
}

/* who takes a challenger win */
int
AS_ChallengerCredit(void)
{
	int best = -1i;
	float bestDamage = 0.0f;

	if (g_asKillerSlot >= 0i && g_asKillerSlot != g_asBossSlot
		&& Arena_CompetitorAt(g_asKillerSlot)) {
		return (g_asKillerSlot);
	}

	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		if (i == g_asBossSlot || !Arena_CompetitorAt(i)) {
			continue;
		}
		if (best == -1i || g_asDamage[i] > bestDamage) {
			best = i;
			bestDamage = g_asDamage[i];
		}
	}
	return (best);
}

/* =========================================================================
 * Director hooks
 * ========================================================================= */
void
AS_RoundStart(void)
{
	int seats = Arena_CompetitorCount();
	entity boss;
	string bossMsg;

	AS_ClearBoss();
	if (seats < 2i) {
		return;
	}

	g_asBossSlot = g_asRotation % seats;
	g_asRotation++;
	g_asKillerSlot = -1i;
	g_asNextBleed = 0.0f;
	for (int d = 0i; d < ARENA_MAXSLOTS; d++) {
		g_asDamage[d] = 0.0f;
	}

	boss = Arena_CompetitorAt(g_asBossSlot);
	g_asBoss = boss;

	/* challengers first (team 1 spawn), then the boss alone at team 2's */
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		entity c = Arena_CompetitorAt(i);
		if (!c || c == boss) {
			continue;
		}
		/* the director already spawned them on a challenger hero (both teams
		   carry the challenger roster); only the side changes */
		AS_ClearBossMark(c);
		ents.Input(c, "SetTeam", itos(AS_TEAM_CHALLENGERS), c);
		game.TeleportToSpawn(c);
		centerprint(c, sprintf("%s ^7is the ARCHSTILETTO\nbring it down", boss.netname));
	}

	userinfo.SetString(boss, "*stiletto_boss", "1");
	ents.Input(boss, "SetTeam", itos(AS_TEAM_BOSS), boss);
	ents.ChangeToClass(boss, "hero_archstiletto");
	ents.Input(boss, "SetMaxHealth", ftos(autocvar_archstiletto_bossHealth), boss);
	ents.Input(boss, "SetHealth", ftos(autocvar_archstiletto_bossHealth), boss);
	game.TeleportToSpawn(boss);
	g_asBossHealth = boss.health;

	bossMsg = sprintf("YOU ARE THE ARCHSTILETTO\n%d HP - mid-air hits hurt double", autocvar_archstiletto_bossHealth);
	centerprint(boss, bossMsg);
	serverinfo.SetString("arch_boss", boss.netname);
	bprint(PRINT_HIGH, sprintf("%s ^7is the Archstiletto (%i challengers)\n", boss.netname, seats - 1i));
}

void
AS_PlayerDeath(entity victim, entity attacker)
{
	if (AS_IsBoss(victim)) {
		g_asKillerSlot = is.Player(attacker) ? Arena_SlotForPlayer(attacker) : -1i;
		if (is.Player(attacker) && attacker != victim) {
			bprint(PRINT_HIGH, sprintf("%s ^7felled the Archstiletto\n", attacker.netname));
		}
	}
}

int
AS_RoundWinTest(void)
{
	entity boss = g_asBoss;
	bool bossUp;
	int challengersUp = 0i;
	int result = 0i;

	if (g_asBossSlot < 0i || !boss) {
		return (0i);
	}

	bossUp = is.Alive(boss) && Arena_SlotForPlayer(boss) == g_asBossSlot;
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		entity c = Arena_CompetitorAt(i);
		if (c && c != boss && is.Alive(c)) {
			challengersUp++;
		}
	}

	if (bossUp == false && challengersUp == 0i) {
		result = -1i;
	} else if (bossUp == false) {
		int credit = AS_ChallengerCredit();
		result = (credit >= 0i) ? credit + 1i : -1i;
	} else if (challengersUp == 0i) {
		result = g_asBossSlot + 1i;
	}

	if (result != 0i) {
		g_asLastResult = result;
	}
	return (result);
}

void
AS_RoundEnd(void)
{
	string msg;
	entity boss = g_asBoss;

	if (g_asLastResult == -1i) {
		msg = "DRAW";
	} else if (g_asLastResult - 1i == g_asBossSlot) {
		msg = sprintf("THE ARCHSTILETTO WINS\n%s", boss ? boss.netname : "");
	} else {
		entity credit = Arena_CompetitorAt(g_asLastResult - 1i);
		msg = sprintf("THE CHALLENGERS WIN\n%s takes the round", credit ? credit.netname : "");
	}
	g_asLastResult = 0i;

	for (entity p = world; (p = next.Player(p));) {
		centerprint(p, msg);
	}
	bprint(PRINT_HIGH, sprintf("%s\n", strreplace("\n", " - ", msg)));
}

void
AS_SuddenDeath(void)
{
	g_asNextBleed = time + 1.0f;
	for (entity p = world; (p = next.Player(p));) {
		centerprint(p, "SUDDEN DEATH\nthe Archstiletto is bleeding");
	}
}

void
AS_SuddenDeathTick(void)
{
	entity boss = g_asBoss;
	float hp;

	if (!boss || is.Alive(boss) == false || time < g_asNextBleed) {
		return;
	}
	g_asNextBleed = time + 1.0f;

	hp = boss.health - autocvar_archstiletto_suddenDeathBleed;
	if (hp > 0.0f) {
		ents.Input(boss, "SetHealth", ftos(hp), boss);
		g_asBossHealth = hp;
	} else {
		ents.Input(boss, "Damage", "1000", world);
	}
}

/* track damage dealt to the boss (for crediting a challenger win) */
void
AS_PlayerPain(entity victim)
{
	if (AS_IsBoss(victim) == false) {
		return;
	}
	g_asBossHealth = victim.health;
}

/* =========================================================================
 * RuleC entry points
 * ========================================================================= */
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

	teams.SetUp(AS_TEAM_CHALLENGERS, "Challengers", [155, 205, 255], false);
	teams.SetUp(AS_TEAM_BOSS, "Archstiletto", [255, 64, 64], false);
	teams.SetSpawnPoint(AS_TEAM_CHALLENGERS, "info_player_deathmatch");
	teams.SetSpawnPoint(AS_TEAM_BOSS, "info_player_deathmatch");

	AS_RegisterChallengerRoster(AS_TEAM_CHALLENGERS);
	AS_RegisterChallengerRoster(AS_TEAM_BOSS);
	Hero_SetPolicy(HEROSWAP_ATSPAWN, HEROCOMP_DUPLICATES);

	Util_RemoveAllMonsters();
	Util_SetItemRespawnTimers();

	Arena_Configure(ARENASHAPE_BOSS, ARENAPROMO_WINNERSTAYS, 1i);
	Arena_SetRosterSize(AS_FullSeats(), (autocvar_archstiletto_roundLimit > 0i)
		? autocvar_archstiletto_roundLimit : AS_FullSeats());
	Arena_SetRoundCountdown(autocvar_archstiletto_roundCountdown, autocvar_archstiletto_roundCountdownStep);
	Arena_SetAutoJoin(false);
	Arena_SetHooks(AS_RoundStart, AS_PlayerDeath, AS_RoundWinTest, AS_RoundEnd,
		AS_SuddenDeath, AS_SuddenDeathTick, AS_PlayerPain);

	ArenaModes_Init("ARCHSTILETTO");
	g_asBoss = __NULL__;
	g_asBossSlot = -1i;
	g_asRotation = 0i;
	g_asPrevState = ARENA_WARMUP;
}

void
CodeCallback_PlayerConnect(entity playerEntity)
{
	userinfo.SetString(playerEntity, "*stiletto_boss", "");
	ArenaModes_PlayerConnect(playerEntity);
}

void
CodeCallback_PlayerDisconnect(entity playerEntity)
{
	if (AS_IsBoss(playerEntity)) {
		g_asBoss = __NULL__;
	}
	Arena_OnPlayerDisconnect(playerEntity);
}

void
CodeCallback_PlayerSpawn(entity playerEntity)
{
	ArenaModes_PlayerSpawn(playerEntity);
}

bool
CodeCallback_PlayerRequestRespawn(entity playerEntity)
{
	return (ArenaModes_PlayerRequestRespawn(playerEntity));
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
	if (AS_IsBoss(playerTarget) && is.Player(attacker) && attacker != playerTarget) {
		int slot = Arena_SlotForPlayer(attacker);
		if (slot >= 0i) {
			g_asDamage[slot] += max(0.0f, g_asBossHealth - playerTarget.health);
		}
	}
	Arena_OnPlayerPain(playerTarget);
}

void
CodeCallback_FrameStart(void)
{
	int state = Arena_GetState();
	int full = AS_FullSeats();

	/* a new match restarts the rotation; outside a match nobody is the boss */
	if (state == ARENA_WARMUP) {
		if (g_asBoss) {
			AS_ClearBoss();
		}
		g_asRotation = 0i;
	}

	/* one round per seat unless archstiletto_roundLimit is set */
	ArenaModes_SizeRoster(full, 1i, (autocvar_archstiletto_roundLimit > 0i)
		? autocvar_archstiletto_roundLimit : -1i);
	ArenaModes_BotTick(full);
	ArenaModes_WarmupHint(full);

	Arena_FrameStart();

	state = Arena_GetState();
	if (state == ARENA_MATCH_END && g_asPrevState != ARENA_MATCH_END
		&& Arena_GetResult() == ARENARESULT_WIN && Arena_CompetitorAt(Arena_GetWinnerSlot() - 1i)) {
		bprint(PRINT_HIGH, sprintf("%s ^7wins the match\n", Arena_CompetitorAt(Arena_GetWinnerSlot() - 1i).netname));
	}
	if (g_asPrevState == ARENA_MATCH_END && state != ARENA_MATCH_END) {
		AS_ClearBoss();
		g_asRotation = 0i;
	}
	g_asPrevState = state;
}

bool
CodeCallback_CallRequestTeam(entity playerEntity, int teamNum)
{
	return (ArenaModes_CallRequestTeam(playerEntity, teamNum));
}

bool
CodeCallback_ConsoleCommand(entity playerEntity, string command)
{
	if (ArenaModes_ConsoleCommand(command)) {
		if (argv(0) == "arena_status") {
			for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
				entity c = Arena_CompetitorAt(i);
				if (c) {
					print(sprintf("  slot %i %s: %s, hp %d, boss-damage %d\n", i, c.netname,
						(i == g_asBossSlot) ? "BOSS" : "challenger", c.health, g_asDamage[i]));
				}
			}
		}
		return (true);
	}
	return (false);
}

bool
CodeCallback_ClientCommand(entity playerEntity, string command)
{
	return (ArenaModes_ClientCommand(playerEntity, command));
}
