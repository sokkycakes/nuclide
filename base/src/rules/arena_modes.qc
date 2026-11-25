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

/* Shared plumbing for the multi-seat arena modes (Freeze Tag, Archstiletto).
 *
 * - Client flow: the same hero-select / ready / spectate commands as Duel, so
 *   the arena menus (WebCore on FTE, Panorama on Bulwark) work unchanged.
 * - Seat sizing: seats fill to the mode's full size; when that many players
 *   never turn up, the match starts with whoever is ready after a short wait
 *   (Arena_SetRosterSize), so two people can always play.
 * - Bots: while a human is ready and the map has bot nodes, empty seats are
 *   filled with bots (cvar arena_bots, default on). Bots pick a random hero
 *   and ready up on their own; they leave when humans take their seats or the
 *   last human leaves.
 *
 * Include after arena.qc. */

var float autocvar_arena_bots = 1;			/* fill empty seats with bots for a waiting human;
											   2 = also with no human (server soak / tests) */
var float autocvar_arena_fillWait = 8.0f;	/* seconds to wait for a full roster before starting smaller */

var bool() g_amNodesAvailable;
var bool() g_amAddRandomBot;
var float g_amNextBotTick;
var float g_amNextHint;
var int g_amLastReady;
var float g_amReadySince;
var string g_amModeName;

void
ArenaModes_Init(string modeName)
{
	g_amModeName = modeName;
	/* botlib lives in the server progs; reach it by name (absent = no bots) */
	g_amNodesAvailable = externvalue(0, "Nodes_Available");
	g_amAddRandomBot = externvalue(0, "BotProfile_AddRandom");
	g_amNextBotTick = 0.0f;
	g_amLastReady = -1i;
	g_amReadySince = time;
}

bool
ArenaModes_IsBot(entity pl)
{
	return (clienttype(pl) == CLIENTTYPE_BOT);
}

bool
ArenaModes_BotsAvailable(void)
{
	if (autocvar_arena_bots == 0) {
		return (false);
	}
	if (!g_amNodesAvailable || !g_amAddRandomBot) {
		return (false);
	}
	return (g_amNodesAvailable());
}

/* a player who is queued or seated (counts toward filling seats) */
bool
ArenaModes_IsSeatedOrReady(entity pl)
{
	int st = Arena_GetPlayerState(pl);
	return (st == ARENASTATE_READY || st == ARENASTATE_COMPETITOR);
}

int
ArenaModes_CountHumans(void)
{
	int total = 0i;
	for (entity p = world; (p = next.Player(p));) {
		if (ArenaModes_IsBot(p) == false && ArenaModes_IsSeatedOrReady(p)) {
			total++;
		}
	}
	return (total);
}

int
ArenaModes_CountBots(void)
{
	int total = 0i;
	for (entity p = world; (p = next.Player(p));) {
		if (ArenaModes_IsBot(p)) {
			total++;
		}
	}
	return (total);
}

/* drop one bot, preferring one that holds no seat; seated bots only go
   between matches so a running match is never voided by the filler */
static bool
ArenaModes_KickOneBot(bool allowSeated)
{
	entity seated = __NULL__;

	for (entity p = world; (p = next.Player(p));) {
		if (ArenaModes_IsBot(p) == false) {
			continue;
		}
		if (Arena_IsCompetitor(p)) {
			seated = p;
			continue;
		}
		dropclient(p);
		return (true);
	}

	if (allowSeated && seated) {
		dropclient(seated);
		return (true);
	}
	return (false);
}

/* Keep (humans + bots) at `seats` while at least one human is playing. */
void
ArenaModes_BotTick(int seats)
{
	int humans;
	int bots;
	int state;
	bool betweenMatches;

	/* arena_bots 0: hands off (bots an admin adds with addBot stay) */
	if (autocvar_arena_bots == 0 || time < g_amNextBotTick) {
		return;
	}
	g_amNextBotTick = time + 1.0f;

	humans = ArenaModes_CountHumans();
	bots = ArenaModes_CountBots();
	state = Arena_GetState();
	betweenMatches = (state == ARENA_WARMUP || state == ARENA_MATCH_END);

	/* nobody to play with: never leave bots playing an empty server */
	if (humans == 0i && autocvar_arena_bots < 2) {
		if (bots > 0i) {
			ArenaModes_KickOneBot(true);
		}
		return;
	}

	if (bots + humans > seats) {
		ArenaModes_KickOneBot(betweenMatches);
		return;
	}

	if (bots + humans < seats && ArenaModes_BotsAvailable()) {
		/* new bots only join between matches; they would only wait otherwise */
		if (betweenMatches) {
			g_amAddRandomBot();
		}
	}
}

/* Bots never open the hero menu: give them a random hero from the team-1
   roster (the mode's playable list) and ready them up. */
void
ArenaModes_BotJoin(entity pl)
{
	int total;
	string heroID;

	if (teams.Valid((int)pl.team) == false) {
		ents.Input(pl, "SetTeam", "1", pl);
	}

	total = teams.TotalClasses(1);
	if (total > 0i) {
		heroID = teams.ClassForIndex(1, (int)floor(random() * (float)total) % total);
		userinfo.SetString(pl, "*hero", heroID);
	}
	userinfo.SetString(pl, "*duel_joining", "");
	Arena_SetReady(pl);
}

/* Size the roster from who is ready. `full` seats are wanted; `step` rounds
   a smaller roster down (2 keeps teams even). While bots can still fill the
   seats the director keeps waiting for the full roster; otherwise, once at
   least two players have been ready for arena_fillWait seconds, the match
   starts with what is there. roundLimit is passed through (0 = unchanged,
   -1 = one round per seat). */
void
ArenaModes_SizeRoster(int full, int step, int roundLimit)
{
	int ready;
	int seats;
	int state = Arena_GetState();

	if (state == ARENA_MATCH_END) {
		/* seat new arrivals in the next match */
		int present = Arena_ReadyCount() + Arena_CompetitorCount();
		seats = (present < full) ? present : full;
		if (step > 1i) {
			seats -= seats % step;
		}
		if (seats > Arena_CompetitorCount()) {
			Arena_SetRosterSize(seats, (roundLimit < 0i) ? seats : roundLimit);
		}
		return;
	}

	if (state != ARENA_WARMUP) {
		return;
	}

	ready = Arena_ReadyCount();
	if (ready != g_amLastReady) {
		g_amLastReady = ready;
		g_amReadySince = time;
	}

	seats = full;
	if (ready < full && ready >= 2i) {
		bool botsComing = ArenaModes_BotsAvailable() && ArenaModes_CountHumans() > 0i;
		if (botsComing == false && time - g_amReadySince >= autocvar_arena_fillWait) {
			seats = ready;
			if (step > 1i) {
				seats -= seats % step;
			}
		}
	}
	if (seats < 2i) {
		seats = 2i;
	}
	Arena_SetRosterSize(seats, (roundLimit < 0i) ? seats : roundLimit);
}

/* Periodic warmup hint for humans waiting on players. */
void
ArenaModes_WarmupHint(int full)
{
	int ready;
	string extra = "";

	if (Arena_GetState() != ARENA_WARMUP || time < g_amNextHint) {
		return;
	}
	g_amNextHint = time + 4.0f;

	ready = Arena_ReadyCount();
	if (ArenaModes_BotsAvailable()) {
		extra = "\nbots are joining";
	} else if (ready >= 2i) {
		extra = "\nstarting with who is here shortly";
	} else if (autocvar_arena_bots != 0) {
		extra = "\nno bot nodes on this map: invite a friend";
	}

	for (entity p = world; (p = next.Player(p));) {
		if (ArenaModes_IsBot(p)) {
			continue;
		}
		if (Arena_GetPlayerState(p) == ARENASTATE_READY) {
			centerprint(p, sprintf("%s\nwaiting for players (%i/%i)%s",
				g_amModeName, ready, full, extra));
		} else if (Arena_GetPlayerState(p) == ARENASTATE_NOTREADY
			&& STRING_SET(userinfo.GetString(p, "*hero"))) {
			centerprint(p, sprintf("%s\npick a hero, then READY UP (cmd ready)", g_amModeName));
		}
	}
}

/* =========================================================================
 * Client flow (mirrors duel.qc so the arena menus work unchanged)
 * ========================================================================= */
void
ArenaModes_PlayerConnect(entity pl)
{
	userinfo.SetString(pl, "*duel_joining", "");
	userinfo.SetString(pl, "*hero", "");
	Arena_OnPlayerConnect(pl);
}

void
ArenaModes_PlayerSpawn(entity pl)
{
	Arena_OnPlayerSpawn(pl);

	if (ArenaModes_IsBot(pl)) {
		return;
	}
	if (STRING_SET(userinfo.GetString(pl, "*duel_joining"))
		&& STRING_SET(userinfo.GetString(pl, "*hero")) == false) {
		stuffcmd(pl, "showClassSelectionMenu\n");
	}
}

bool
ArenaModes_PlayerRequestRespawn(entity pl)
{
	if (STRING_SET(userinfo.GetString(pl, "*hero")) == false) {
		return (false);
	}
	return (Arena_OnPlayerRequestRespawn(pl));
}

bool
ArenaModes_CallRequestTeam(entity pl, int teamNum)
{
	if (ArenaModes_IsBot(pl)) {
		ArenaModes_BotJoin(pl);
		return (true);
	}

	if (teamNum == TEAM_SPECTATOR) {
		Arena_SetSpectator(pl);
		return (true);
	}

	if (teams.Valid(teamNum) == false) {
		return (false);
	}

	if (Arena_IsCompetitor(pl)) {
		return (true);
	}

	ents.Input(pl, "SetTeam", itos(teamNum), pl);
	userinfo.SetString(pl, "*duel_joining", "1");
	userinfo.SetString(pl, "*hero", "");
	Arena_SetNotReady(pl);
	Arena_SpawnWaitingView(pl);
	stuffcmd(pl, "showClassSelectionMenu\n");
	return (true);
}

bool
ArenaModes_ClientCommand(entity pl, string command)
{
	tokenize(command);

	if (ArenaModes_IsBot(pl)) {
		/* botlib's "join <class>": the bot already picked in BotJoin */
		if (argv(0) == "join") {
			return (true);
		}
	}

	switch (argv(0)) {
	case "changehero": {
		/* A swap respawns the player at a spawn point with fresh weapons and
		 * HP. Mid-round that would thaw a statue or turn the boss into a
		 * normal hero, so seated competitors wait until the round is over. */
		int dirState = Arena_GetState();
		if (Arena_IsCompetitor(pl) && (dirState == ARENA_COUNTDOWN || dirState == ARENA_LIVE || dirState == ARENA_SUDDEN_DEATH || dirState == ARENA_ROUND_END)) {
			sprint(pl, PRINT_HIGH, "You can change hero between rounds.\n");
			return (true);
		}
		if (teams.Valid((int)pl.team) == false) {
			ents.Input(pl, "SetTeam", "1", pl);
		}
		Hero_TrySelectEx(pl, Hero_NormalizeID(argv(1)), true);
		return (true);
	}
	case "selecthero": {
		int arenaState = Arena_GetPlayerState(pl);
		bool joining = STRING_SET(userinfo.GetString(pl, "*duel_joining"));

		if (joining == false && arenaState < ARENASTATE_READY) {
			return (true);
		}

		string heroID = Hero_NormalizeID(argv(1));

		if (teams.Valid((int)pl.team) == false) {
			ents.Input(pl, "SetTeam", "1", pl);
		}

		/* record only while the selector is open; spawn on close / READY UP */
		if (Hero_TrySelectEx(pl, heroID, joining == false) && joining) {
			userinfo.SetString(pl, "*duel_joining", "");
			stuffcmd(pl, "showClassSelectionMenu\n");
		}
		return (true);
	}
	case "arena_enter":
		if (Arena_GetPlayerState(pl) == ARENASTATE_NOTREADY) {
			Arena_EnsureFreeplay(pl);
		}
		return (true);
	case "spectate":
		if (is.Player(pl)) {
			userinfo.SetString(pl, "*duel_joining", "");
			Arena_SetSpectator(pl);
			return (true);
		}
		return (false);
	case "play":
		userinfo.SetString(pl, "*duel_joining", "1");
		userinfo.SetString(pl, "*hero", "");
		Arena_SetNotReady(pl);
		Arena_SpawnWaitingView(pl);
		stuffcmd(pl, "showClassSelectionMenu\n");
		return (true);
	case "choosehero":
		if (Arena_GetPlayerState(pl) == ARENASTATE_SPECTATOR
			|| pl.team == TEAM_SPECTATOR) {
			return (true);
		}
		if (Arena_IsCompetitor(pl)
			|| Arena_GetPlayerState(pl) == ARENASTATE_READY) {
			stuffcmd(pl, "showClassSelectionMenu\n");
			return (true);
		}
		userinfo.SetString(pl, "*duel_joining", "1");
		stuffcmd(pl, "showClassSelectionMenu\n");
		return (true);
	default:
		break;
	}

	return (Arena_OnClientCommand(pl, command));
}

/* =========================================================================
 * Server console helpers (rcon / "sv <cmd>"):
 *   arena_status         director state, seats and every player's arena state
 *   arena_bring <a> <b>  move entity number a next to entity number b
 *   arena_lift <a> <h>   lift entity number a h units into the air
 * ========================================================================= */
static string
ArenaModes_StateName(int st)
{
	switch (st) {
	case ARENA_WARMUP: return ("WARMUP");
	case ARENA_COUNTDOWN: return ("COUNTDOWN");
	case ARENA_LIVE: return ("LIVE");
	case ARENA_SUDDEN_DEATH: return ("SUDDEN_DEATH");
	case ARENA_ROUND_END: return ("ROUND_END");
	case ARENA_MATCH_END: return ("MATCH_END");
	}
	return (itos(st));
}

bool
ArenaModes_ConsoleCommand(string command)
{
	tokenize(command);

	switch (argv(0)) {
	case "arena_status":
		print(sprintf("%s: %s, %i seated, %i ready, bots %s\n", g_amModeName,
			ArenaModes_StateName(Arena_GetState()), Arena_CompetitorCount(),
			Arena_ReadyCount(), ArenaModes_BotsAvailable() ? "available" : "unavailable"));
		for (entity p = world; (p = next.Player(p));) {
			print(sprintf("  #%d %s: team %d, arena %i, slot %i, %s, ",
				num_for_edict(p), p.netname, p.team, Arena_GetPlayerState(p),
				Arena_SlotForPlayer(p), p.classname));
			print(sprintf("hp %d, movetype %d, at %v\n", p.health, p.movetype, p.origin));
		}
		return (true);
	case "arena_bring": {
		entity a = edict_num(stof(argv(1)));
		entity b = edict_num(stof(argv(2)));
		if (a && b) {
			setorigin(a, b.origin + [40, 0, 0]);
			a.velocity = [0,0,0];
			print(sprintf("moved #%d next to #%d\n", num_for_edict(a), num_for_edict(b)));
		}
		return (true);
	}
	case "arena_lift": {
		entity e = edict_num(stof(argv(1)));
		if (e) {
			setorigin(e, e.origin + [0, 0, stof(argv(2))]);
			e.flags &= ~FL_ONGROUND;
			print(sprintf("lifted #%d to %v\n", num_for_edict(e), e.origin));
		}
		return (true);
	}
	}
	return (false);
}
