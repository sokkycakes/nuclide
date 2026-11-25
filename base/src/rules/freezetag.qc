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

/* Freeze Tag (ruleset FREEZETAG, R25): 2v2 on the arena director.
 *
 * A fatal hit freezes the competitor in place instead of eliminating them:
 * they come back as a tinted statue that cannot move, shoot or be hurt. A
 * teammate standing within freezetag_thawRadius for freezetag_thawTime
 * seconds thaws them (progress shown to both; it drains back when the thawer
 * steps away) and they rejoin at full health where they stood. A round is won
 * when every enemy is frozen. Pacing is Duel's: countdown, best-of-N rounds
 * (freezetag_roundLimit), match end, winner team stays.
 *
 * When the round timer runs out (arena_roundTime) the round goes to sudden
 * death: thawing stops, and after freezetag_suddenDeathTime the team with
 * more players unfrozen takes it (equal = draw).
 *
 * Team size is freezetag_teamSize (default 2). Empty seats fill with bots for
 * a waiting human (arena_bots); without bots the match starts as 1v1 once two
 * players have been ready for arena_fillWait seconds.
 *
 * Seats: slots [0, n/2) are team 1 (Blue), [n/2, n) team 2 (Red); a team's
 * round points are kept on its first slot. */

var int autocvar_freezetag_teamSize = 2;
var int autocvar_freezetag_roundLimit = 5;
var float autocvar_freezetag_thawTime = 3.0f;		/* seconds a teammate must stay close */
var float autocvar_freezetag_thawRadius = 96.0f;	/* "next to": centre-to-centre distance */
var float autocvar_freezetag_thawDecay = 1.0f;		/* progress drain rate when nobody is close */
var float autocvar_freezetag_suddenDeathTime = 30.0f;
var float autocvar_freezetag_roundCountdown = 3.0f;
var float autocvar_freezetag_roundCountdownStep = 0.5f;

#define FT_NONE		0i
#define FT_PENDING	1i	/* froze this frame; statue built next frame */
#define FT_STATUE	2i

var int g_ftFrozen[ARENA_MAXSLOTS];
vector g_ftOrigin[ARENA_MAXSLOTS];
vector g_ftAngles[ARENA_MAXSLOTS];
string g_ftHero[ARENA_MAXSLOTS];
entity g_ftEnt[ARENA_MAXSLOTS];
var float g_ftThaw[ARENA_MAXSLOTS];
var float g_ftNextMsg[ARENA_MAXSLOTS];
var int g_ftScore[3];			/* round wins by team, this match */
var int g_ftLastResult;			/* last non-zero round test (for scoring) */
var float g_ftSuddenStart;
var bool g_ftSuddenOver;
var int g_ftPrevState;

/* =========================================================================
 * Helpers
 * ========================================================================= */
int
FT_Seats(void)
{
	int n = Arena_CompetitorCount();
	return (n < 2i) ? 2i : n;
}

int
FT_TeamOfSlot(int slot)
{
	return (slot < (FT_Seats() / 2i)) ? 1i : 2i;
}

int
FT_LeadSlot(int teamNum)
{
	return (teamNum == 1i) ? 0i : (FT_Seats() / 2i);
}

string
FT_TeamName(int teamNum)
{
	return (teamNum == 1i) ? "^4BLUE^7" : "^1RED^7";
}

string
FT_TeamMembers(int teamNum)
{
	string result = "";
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		entity c = Arena_CompetitorAt(i);
		if (!c || FT_TeamOfSlot(i) != teamNum) {
			continue;
		}
		result = STRING_SET(result) ? strcat(result, " & ", c.netname) : c.netname;
	}
	return (result);
}

bool
FT_IsFrozen(entity pl)
{
	int slot = Arena_SlotForPlayer(pl);
	return (slot != -1i && g_ftFrozen[slot] != FT_NONE && g_ftEnt[slot] == pl);
}

/* up = alive and not frozen */
bool
FT_IsUp(int slot)
{
	entity c = Arena_CompetitorAt(slot);
	return (c && is.Alive(c) && g_ftFrozen[slot] == FT_NONE);
}

void
FT_ClearLook(entity c)
{
	ents.Input(c, "SetRenderMode", "0", c);
	ents.Input(c, "Color", "255 255 255", c);
}

void
FT_ResetAll(void)
{
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		/* by entity, not slot: seats may already belong to the next match */
		entity c = g_ftEnt[i];
		if (c && g_ftFrozen[i] != FT_NONE) {
			FT_ClearLook(c);
			if (c.movetype == MOVETYPE_NONE) {
				c.movetype = MOVETYPE_WALK;
			}
		}
		g_ftFrozen[i] = FT_NONE;
		g_ftEnt[i] = __NULL__;
		g_ftThaw[i] = 0.0f;
		g_ftNextMsg[i] = 0.0f;
	}
	g_ftSuddenOver = false;
}

/* turn a frozen competitor into a statue on the spot they fell */
void
FT_BuildStatue(int slot)
{
	entity c = Arena_CompetitorAt(slot);

	if (!c || c != g_ftEnt[slot]) {
		g_ftFrozen[slot] = FT_NONE;
		g_ftEnt[slot] = __NULL__;
		return;
	}

	ents.ChangeToClass(c, g_ftHero[slot]);
	setorigin(c, g_ftOrigin[slot]);
	c.angles = g_ftAngles[slot];
	c.velocity = [0,0,0];
	c.movetype = MOVETYPE_NONE;

	/* a statue holds nothing it could use */
	for (int w = 0i; w < 8i; w++) {
		ents.Input(c, "RemoveActiveWeapon", "", c);
	}

	ents.Input(c, "SetRenderMode", "1", c);		/* RM_COLOR: tint the model */
	ents.Input(c, "Color", "90 170 255", c);
	g_ftFrozen[slot] = FT_STATUE;
	g_ftThaw[slot] = 0.0f;
	centerprint(c, "FROZEN\na teammate can thaw you");
}

void
FT_Thaw(int slot, entity thawer)
{
	entity c = Arena_CompetitorAt(slot);

	g_ftFrozen[slot] = FT_NONE;
	g_ftThaw[slot] = 0.0f;
	g_ftEnt[slot] = __NULL__;
	if (!c) {
		return;
	}

	FT_ClearLook(c);
	ents.ChangeToClass(c, g_ftHero[slot]);
	setorigin(c, g_ftOrigin[slot]);
	c.angles = g_ftAngles[slot];
	c.velocity = [0,0,0];
	if (c.movetype == MOVETYPE_NONE) {
		c.movetype = MOVETYPE_WALK;
	}

	centerprint(c, "THAWED!");
	if (thawer) {
		centerprint(thawer, sprintf("You thawed %s", c.netname));
		bprint(PRINT_HIGH, sprintf("%s ^7thawed %s\n", thawer.netname, c.netname));
	}
}

void
FT_ThawTick(void)
{
	float radius = autocvar_freezetag_thawRadius;
	float need = autocvar_freezetag_thawTime;

	if (need < 0.1f) {
		need = 0.1f;
	}

	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		entity c = Arena_CompetitorAt(i);
		entity thawer = __NULL__;
		int teamNum;

		if (!c || g_ftFrozen[i] != FT_STATUE) {
			continue;
		}

		teamNum = FT_TeamOfSlot(i);
		for (int j = 0i; j < ARENA_MAXSLOTS; j++) {
			if (j == i || FT_IsUp(j) == false || FT_TeamOfSlot(j) != teamNum) {
				continue;
			}
			entity t = Arena_CompetitorAt(j);
			if (vlen(t.origin - c.origin) <= radius) {
				thawer = t;
				break;
			}
		}

		if (thawer) {
			g_ftThaw[i] += frametime;
		} else {
			g_ftThaw[i] = max(0.0f, g_ftThaw[i] - frametime * autocvar_freezetag_thawDecay);
		}

		if (g_ftThaw[i] >= need) {
			FT_Thaw(i, thawer);
			continue;
		}

		if (time >= g_ftNextMsg[i]) {
			int pct = (int)floor((g_ftThaw[i] / need) * 100.0f);
			if (thawer) {
				g_ftNextMsg[i] = time + 0.2f;
				centerprint(c, sprintf("THAWING %i%%", pct));
				centerprint(thawer, sprintf("THAWING %s %i%%", c.netname, pct));
			} else {
				g_ftNextMsg[i] = time + 2.0f;
				if (pct > 0i) {
					centerprint(c, sprintf("FROZEN (%i%%)\na teammate can thaw you", pct));
				} else {
					centerprint(c, "FROZEN\na teammate can thaw you");
				}
			}
		}
	}
}

/* team scoreboard / HUD keys (the director publishes arena_p1/p2 per slot;
   overwrite them with team values whenever they differ) */
void
FT_SetInfo(string key, string value)
{
	if (serverinfo.GetString(key) != value) {
		serverinfo.SetString(key, value);
	}
}

void
FT_PublishInfo(void)
{
	string frozen = "";

	if (Arena_CompetitorCount() > 0i) {
		string names1 = FT_TeamMembers(1i);
		string names2 = FT_TeamMembers(2i);
		FT_SetInfo("arena_name1", sprintf("Blue: %s", names1));
		FT_SetInfo("arena_name2", sprintf("Red: %s", names2));
		FT_SetInfo("arena_p1", sprintf("Blue: %s (%i)", names1, g_ftScore[1]));
		FT_SetInfo("arena_p2", sprintf("Red: %s (%i)", names2, g_ftScore[2]));
		FT_SetInfo("arena_score1", itos(g_ftScore[1]));
		FT_SetInfo("arena_score2", itos(g_ftScore[2]));
		for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
			entity c = Arena_CompetitorAt(i);
			if (c) {
				c.frags = (float)g_ftScore[FT_TeamOfSlot(i)];
			}
		}
	}

	for (int k = 0i; k < ARENA_MAXSLOTS; k++) {
		entity f = g_ftEnt[k];
		if (f && g_ftFrozen[k] != FT_NONE) {
			frozen = STRING_SET(frozen) ? strcat(frozen, " ", f.netname) : f.netname;
		}
	}
	FT_SetInfo("ft_frozen", frozen);
}

/* =========================================================================
 * Director hooks
 * ========================================================================= */
void
FT_RoundStart(void)
{
	FT_ResetAll();
}

void
FT_PlayerDeath(entity victim, entity attacker)
{
	int slot;
	int state = Arena_GetState();

	if (state != ARENA_LIVE && state != ARENA_SUDDEN_DEATH) {
		return;
	}
	slot = Arena_SlotForPlayer(victim);
	if (slot == -1i || g_ftFrozen[slot] != FT_NONE) {
		return;
	}

	g_ftFrozen[slot] = FT_PENDING;
	g_ftEnt[slot] = victim;
	g_ftOrigin[slot] = victim.origin;
	g_ftAngles[slot] = [0, victim.angles[1], 0];
	g_ftHero[slot] = Hero_ResolveSpawnHero(victim);
	if (substring(victim.classname, 0, 5) == "hero_") {
		g_ftHero[slot] = victim.classname;
	}

	if (is.Player(attacker) && attacker != victim) {
		bprint(PRINT_HIGH, sprintf("%s ^7was frozen by %s\n", victim.netname, attacker.netname));
	} else {
		bprint(PRINT_HIGH, sprintf("%s ^7froze\n", victim.netname));
	}
}

int
FT_RoundWinTest(void)
{
	int up1 = 0i;
	int up2 = 0i;
	int result = 0i;

	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		if (!Arena_CompetitorAt(i) || FT_IsUp(i) == false) {
			continue;
		}
		if (FT_TeamOfSlot(i) == 1i) {
			up1++;
		} else {
			up2++;
		}
	}

	if (up1 == 0i && up2 == 0i) {
		result = -1i;
	} else if (up1 == 0i) {
		result = FT_LeadSlot(2i) + 1i;
	} else if (up2 == 0i) {
		result = FT_LeadSlot(1i) + 1i;
	} else if (g_ftSuddenOver) {
		if (up1 > up2) {
			result = FT_LeadSlot(1i) + 1i;
		} else if (up2 > up1) {
			result = FT_LeadSlot(2i) + 1i;
		} else {
			result = -1i;
		}
	}

	if (result != 0i) {
		g_ftLastResult = result;
	}
	return (result);
}

void
FT_RoundEnd(void)
{
	string msg;

	if (g_ftLastResult == -1i) {
		g_ftScore[1]++;
		g_ftScore[2]++;
		msg = "DRAW";
	} else {
		int winTeam = FT_TeamOfSlot(g_ftLastResult - 1i);
		g_ftScore[winTeam]++;
		msg = sprintf("%s TEAM wins the round\n%i - %i", FT_TeamName(winTeam),
			g_ftScore[1], g_ftScore[2]);
	}
	g_ftLastResult = 0i;

	for (entity p = world; (p = next.Player(p));) {
		centerprint(p, msg);
	}
	bprint(PRINT_HIGH, sprintf("%s\n", strreplace("\n", " ", msg)));
	FT_PublishInfo();
}

void
FT_SuddenDeath(void)
{
	g_ftSuddenStart = time;
	g_ftSuddenOver = false;
	for (entity p = world; (p = next.Player(p));) {
		centerprint(p, "SUDDEN DEATH\nno more thawing");
	}
}

void
FT_SuddenDeathTick(void)
{
	if (time - g_ftSuddenStart >= autocvar_freezetag_suddenDeathTime) {
		g_ftSuddenOver = true;
	}
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

int
FT_FullSeats(void)
{
	int teamSize = autocvar_freezetag_teamSize;
	if (teamSize < 1i) {
		teamSize = 1i;
	}
	if (teamSize > ARENA_MAXSLOTS / 2i) {
		teamSize = ARENA_MAXSLOTS / 2i;
	}
	return (teamSize * 2i);
}

void
CodeCallback_StartGameType(void)
{
	motd.LoadDefault();
	game.SetSpawnPoint("info_intermission");

	/* teams are closed in the picker: seats are assigned by the director */
	teams.SetUp(1, "Blue", [155, 205, 255], false);
	teams.SetUp(2, "Red", [255, 64, 64], false);
	teams.SetSpawnPoint(1, "info_player_deathmatch");
	teams.SetSpawnPoint(2, "info_player_deathmatch");

	Hero_RegisterRoster(1);
	Hero_RegisterRoster(2);
	Hero_SetPolicy(HEROSWAP_ATSPAWN, HEROCOMP_DUPLICATES);

	Util_RemoveAllMonsters();
	Util_SetItemRespawnTimers();

	Arena_Configure(ARENASHAPE_2V2, ARENAPROMO_WINNERSTAYS, autocvar_freezetag_roundLimit);
	Arena_SetRosterSize(FT_FullSeats(), 0i);
	Arena_SetRoundCountdown(autocvar_freezetag_roundCountdown, autocvar_freezetag_roundCountdownStep);
	Arena_SetAutoJoin(false);
	Arena_SetHooks(FT_RoundStart, FT_PlayerDeath, FT_RoundWinTest, FT_RoundEnd,
		FT_SuddenDeath, FT_SuddenDeathTick, __NULL__);

	ArenaModes_Init("FREEZE TAG");
	for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
		g_ftFrozen[i] = FT_NONE;
	}
	g_ftScore[1] = g_ftScore[2] = 0i;
	g_ftPrevState = ARENA_WARMUP;
}

void
CodeCallback_PlayerConnect(entity playerEntity)
{
	ArenaModes_PlayerConnect(playerEntity);
}

void
CodeCallback_PlayerDisconnect(entity playerEntity)
{
	int slot = Arena_SlotForPlayer(playerEntity);
	if (slot != -1i) {
		g_ftFrozen[slot] = FT_NONE;
		g_ftEnt[slot] = __NULL__;
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

/* statues take no damage */
bool
CodeCallback_PlayerCanAttack(entity playerEntity)
{
	return (FT_IsFrozen(playerEntity) == false);
}

void
CodeCallback_PlayerPreFrame(entity playerEntity)
{
	int slot = Arena_SlotForPlayer(playerEntity);

	if (slot != -1i && g_ftFrozen[slot] == FT_STATUE && g_ftEnt[slot] == playerEntity) {
		playerEntity.velocity = [0,0,0];
		playerEntity.movetype = MOVETYPE_NONE;
	}
}

void
CodeCallback_FrameStart(void)
{
	int state = Arena_GetState();
	int full = FT_FullSeats();

	/* new match: clear the team tally */
	if (state == ARENA_WARMUP || (g_ftPrevState == ARENA_MATCH_END && state != ARENA_MATCH_END)) {
		g_ftScore[1] = g_ftScore[2] = 0i;
	}

	if (state == ARENA_WARMUP) {
		/* nobody stays a statue outside a match */
		FT_ResetAll();
	} else {
		for (int i = 0i; i < ARENA_MAXSLOTS; i++) {
			if (g_ftFrozen[i] == FT_PENDING) {
				FT_BuildStatue(i);
			}
		}
		if (state == ARENA_LIVE) {
			FT_ThawTick();
		}
	}

	ArenaModes_SizeRoster(full, 2i, 0i);
	ArenaModes_BotTick(full);
	ArenaModes_WarmupHint(full);

	Arena_FrameStart();

	state = Arena_GetState();
	/* the match that froze these statues is over; their seats are reassigned */
	if (g_ftPrevState == ARENA_MATCH_END && state != ARENA_MATCH_END) {
		FT_ResetAll();
	}
	if (state == ARENA_MATCH_END && g_ftPrevState != ARENA_MATCH_END
		&& Arena_GetResult() == ARENARESULT_WIN && Arena_GetWinnerSlot() > 0i) {
		int winTeam = FT_TeamOfSlot(Arena_GetWinnerSlot() - 1i);
		string winMsg = sprintf("%s TEAM WINS THE MATCH\n%s", FT_TeamName(winTeam), FT_TeamMembers(winTeam));
		for (entity p = world; (p = next.Player(p));) {
			centerprint(p, winMsg);
		}
		bprint(PRINT_HIGH, sprintf("%s\n", strreplace("\n", " - ", winMsg)));
	}
	g_ftPrevState = state;

	FT_PublishInfo();
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
					print(sprintf("  slot %i %s: team %i, frozen %i, thaw %.1f\n", i,
						c.netname, FT_TeamOfSlot(i), g_ftFrozen[i], g_ftThaw[i]));
				}
			}
			print(sprintf("  score blue %i red %i\n", g_ftScore[1], g_ftScore[2]));
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
