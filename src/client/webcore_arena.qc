/*
 * Optional WebCore arena selector adapter.
 *
 * This is intentionally client-only: it mirrors the arena director's already
 * replicated serverinfo/userinfo into cvars consumed by the WebCore plugin.
 * Game actions remain normal server commands and are still validated by the
 * Duel/Arena rules code.
 */

var bool autocvar_cl_webcore_arena_ui = false;
var string g_webcoreArenaSnapshot;
var bool g_webcoreArenaSelectorOpen;
var int g_webcoreArenaLastLocalState;

static string
WebCoreArena_JSONString(string raw)
{
	/* Values from server/user info are untrusted JSON text. */
	raw = strreplace("\\", "\\\\", raw);
	raw = strreplace("\"", "\\\"", raw);
	raw = strreplace("\n", "", raw);
	raw = strreplace("\r", "", raw);
	return (strcat("\"", raw, "\""));
}

bool
WebCoreArenaUI_IsAvailable(void)
{
	/* A fullscreen menu cannot represent more than one local player. */
	return (autocvar_cl_webcore_arena_ui && numclientseats == 1.0f
		&& STRING_SET(serverinfo.GetString("arena_state")));
}

static string
WebCoreArena_HeroesJSON(string heroIDs)
{
	string result = "[";
	int total = tokenizebyseparator(heroIDs, " ");

	for (int i = 0i; i < total; i++) {
		string heroID = argv(i);

		if (i > 0i) {
			result = strcat(result, ",");
		}
		result = strcat(result, "{\"id\":", WebCoreArena_JSONString(heroID),
			",\"name\":", WebCoreArena_JSONString(heroID), "}");
	}

	return (strcat(result, "]"));
}

void
WebCoreArenaUI_Close(void)
{
	if (g_webcoreArenaSelectorOpen) {
		localcmd("webcore_closemenu\n");
		g_webcoreArenaSelectorOpen = false;
	}
}

/* Mark snapshot inactive without closing an already-open menu.
 * Transient seat/player gaps must not wipe the page mid-load. */
static void
WebCoreArenaUI_SetInactive(void)
{
	if (g_webcoreArenaSnapshot != "{\"active\":false}") {
		g_webcoreArenaSnapshot = "{\"active\":false}";
		cvar_set("webcore_arena_snapshot", g_webcoreArenaSnapshot);
		cvar_set("webcore_arena_hero_ids", "");
	}
}

void
WebCoreArenaUI_Clear(void)
{
	WebCoreArenaUI_Close();
	WebCoreArenaUI_SetInactive();
}

static entity
WebCoreArena_LocalPlayer(void)
{
	return findfloat(world, ::entnum, player_localentnum);
}

void
WebCoreArenaUI_Publish(void)
{
	string arenaState;
	string localHero;
	string localPhase;
	string snapshot;
	string heroIDs;
	int localArenaState;
	bool joining;
	bool needsHero;
	entity localPlayer;

	if (WebCoreArenaUI_IsAvailable() == false) {
		/* Don't close a menu that is mid-open on a one-frame availability blip. */
		WebCoreArenaUI_SetInactive();
		return;
	}

	arenaState = serverinfo.GetString("arena_state");
	/* The selector is only applicable in warmup; countdown/live own gameplay input. */
	if (arenaState != "WARMUP") {
		WebCoreArenaUI_Close();
	}

	/* Server-wide fields publish even before the local CSQC player entity exists.
	 * Needing pSeat->m_ePlayer was wiping active:true during join/waiting-view. */
	localPlayer = WebCoreArena_LocalPlayer();
	localHero = "";
	localArenaState = 0;
	joining = false;
	needsHero = false;

	if (localPlayer) {
		localHero = userinfo.GetString(localPlayer, "*hero");
		localArenaState = userinfo.GetInteger(localPlayer, "*arena_state");
		joining = STRING_SET(userinfo.GetString(localPlayer, "*duel_joining"));
		needsHero = joining && STRING_SET(localHero) == false;
	}

	/* Spectate / leave-queue: drop the selector once so the player gets
	 * gameplay input back. Re-opening as a spectator (JOIN QUEUE) is fine —
	 * we only close on the transition into SPECTATOR (ARENASTATE_SPECTATOR=2). */
	if (g_webcoreArenaSelectorOpen
		&& localArenaState == 2
		&& g_webcoreArenaLastLocalState != 2) {
		WebCoreArenaUI_Close();
	}
	g_webcoreArenaLastLocalState = localArenaState;

	localPhase = serverinfo.GetString("arena_round");
	heroIDs = serverinfo.GetString("arena_heroes");

	snapshot = "{\"active\":true";
	snapshot = strcat(snapshot, ",\"phase\":", WebCoreArena_JSONString(arenaState));
	snapshot = strcat(snapshot, ",\"round\":", WebCoreArena_JSONString(localPhase));
	snapshot = strcat(snapshot, ",\"map\":", WebCoreArena_JSONString(serverinfo.GetString("mapname")));
	snapshot = strcat(snapshot, ",\"readyCount\":", ftos(serverinfo.GetInteger("arena_ready")));
	snapshot = strcat(snapshot, ",\"players\":[", WebCoreArena_JSONString(serverinfo.GetString("arena_p1")), ",",
		WebCoreArena_JSONString(serverinfo.GetString("arena_p2")), "]");
	snapshot = strcat(snapshot, ",\"local\":{\"state\":", ftos(localArenaState),
		",\"hero\":", WebCoreArena_JSONString(localHero));
	snapshot = strcat(snapshot, ",\"needsHero\":", needsHero ? "true" : "false",
		",\"joining\":", joining ? "true" : "false", "}");
	snapshot = strcat(snapshot, ",\"heroes\":", WebCoreArena_HeroesJSON(heroIDs), "}");

	if (snapshot != g_webcoreArenaSnapshot) {
		g_webcoreArenaSnapshot = snapshot;
		cvar_set("webcore_arena_snapshot", snapshot);
		cvar_set("webcore_arena_hero_ids", heroIDs);
	}
}

bool
WebCoreArenaUI_OpenSelector(string selector)
{
	if (WebCoreArenaUI_IsAvailable() == false) {
		return (false);
	}

	/* Mark open before Publish so a transient SetInactive cannot race Close. */
	g_webcoreArenaSelectorOpen = true;
	WebCoreArenaUI_Publish();
	/* The engine replays the original selector with "vgui" if media open fails. */
	localcmd(sprintf("menu_webcore arena %s\n", selector));
	return (true);
}
