/*
 * lobby_session.c — lobby state machine and session lifecycle
 */

#include "quakedef.h"
#include "lobby_session.h"
#include "netinc.h"

typedef struct
{
	lobby_event_fn	fn;
	void			*ctx;
} lobby_sink_t;

#define LOBBY_CHAT_HISTORY 10
#define LOBBY_CHAT_BYTES 240

typedef struct {
    unsigned id;
    int seat;
    char name[64];
    char text[LOBBY_CHAT_BYTES + 1];
} lobby_chat_t;

static struct
{
    lobby_chat_t chat[LOBBY_CHAT_HISTORY];
    unsigned chat_sequence;
    int chat_count;
	qboolean			active;
	lobby_state_t		state;
	lobby_network_t		network;
	qboolean			is_host;
	char				room_code[64];
	char				session_id[32];
	char				status[256];
	char				error[128];
	char				join_host[128];	/* address used to join (connect-target policy) */
	infobuf_t			settings;
	lobby_player_t		players[LOBBY_MAX_PLAYERS];
	int					local_seat;
	lobby_backend_t		*backend;
	lobby_sink_t		sinks[LOBBY_MAX_EVENT_SINKS];
	double				countdown_end;	/* realtime deadline; 0 = not counting */
	double				roster_stable_at;	/* earliest realtime to arm countdown */
	unsigned			revision;		/* authoritative state revision */
	unsigned			start_nonce;
	unsigned			start_published;	/* idempotent GAME_STARTING nonce */
	qboolean			start_pending;		/* STARTING: waiting for listen-ready */
	double				start_deadline;
	char				start_map[64];
	char				listen_endpoint[128];	/* host LAN/game listen URI once ready */
	int					start_spawncount;
	qboolean			game_registered;
	double				broker_deadline;
} lobby;

/* Room code for joiner ICE create (Lobby_Create memset runs before backend->create). */
static char lobby_create_room_code[64];

cvar_t lobby_maxplayers = CVARD("lobby_maxplayers", "16", "Maximum players in a pre-game lobby.");
cvar_t lobby_readytime = CVARD("lobby_readytime", "5", "Countdown seconds after all players ready before map load.");
cvar_t lobby_defaultmap = CVARD("lobby_defaultmap", "envtest", "Map loaded when the host starts the lobby game.");
cvar_t lobby_defaultruleset = CVARD("lobby_defaultruleset", "DUEL", "Default ruleset name shown in the lobby UI.");

/* Mirrored for WebCore getlobby — Cvar_SetNamed no-ops if unregistered. */
static cvar_t lobby_chat_cv = CVARF("lobby_chat_snapshot", "[]", CVAR_NOSAVE);
static cvar_t lobby_snapshot_cv = CVARF("lobby_snapshot", "", CVAR_NOSAVE);
static cvar_t lobby_active_cv = CVAR("lobby_active", "0");
static cvar_t lobby_player_count = CVAR("lobby_player_count", "0");
static cvar_t lobby_room_code_cv = CVAR("lobby_room_code", "");
static cvar_t lobby_host_name_cv = CVAR("lobby_host_name", "");
static cvar_t lobby_state_str_cv = CVAR("lobby_state_str", "");
static cvar_t lobby_max_players_cv = CVAR("lobby_max_players", "0");
static cvar_t lobby_player1_name = CVAR("lobby_player1_name", "");
static cvar_t lobby_player2_name = CVAR("lobby_player2_name", "");
static cvar_t lobby_player3_name = CVAR("lobby_player3_name", "");
static cvar_t lobby_player4_name = CVAR("lobby_player4_name", "");

#ifdef HAVE_CLIENT
extern cvar_t net_ice_broker;
#endif

static void Lobby_Emit(lobby_event_type_t type, int seat, const char *text);
static void Lobby_MarkRosterChanged(void);
static void Lobby_ClearAllReady(void);
static void Lobby_AbortCountdown(const char *reason);
static void Lobby_ArmCountdown(void);
static qboolean Lobby_AllReady(void);
static qboolean Lobby_CommitStart(void);

static const char *Lobby_PhaseName(lobby_state_t st)
{
	switch (st)
	{
	case LOBBY_STATE_IDLE: return "IDLE";
	case LOBBY_STATE_CREATING: return "CREATING";
	case LOBBY_STATE_JOINING: return "JOINING";
	case LOBBY_STATE_WAITING: return "WAITING";
	case LOBBY_STATE_CONFIG: return "CONFIG";
	case LOBBY_STATE_READY_CHECK: return "READY_CHECK";
	case LOBBY_STATE_COUNTDOWN: return "COUNTDOWN";
	case LOBBY_STATE_STARTING: return "STARTING";
	case LOBBY_STATE_INGAME: return "INGAME";
	case LOBBY_STATE_CLOSING: return "CLOSING";
	case LOBBY_STATE_POSTGAME: return "POSTGAME";
	default: return "UNKNOWN";
	}
}

static const char *Lobby_NetworkName(lobby_network_t net)
{
	switch (net)
	{
	case LOBBY_NET_OFFLINE: return "offline";
	case LOBBY_NET_LAN: return "lan";
	case LOBBY_NET_ONLINE: return "online";
	default: return "unknown";
	}
}

static size_t Lobby_JsonEscape(char *out, size_t outsz, const char *in)
{
	size_t used = 0;
	if (!out || outsz < 3)
		return 0;
	out[used++] = '"';
	if (in)
	{
		while (*in && used + 6 < outsz)
		{
			unsigned char c = (unsigned char)*in++;
			if (c == '"' || c == '\\')
			{
				out[used++] = '\\';
				out[used++] = (char)c;
			}
			else if (c >= 0x20)
				out[used++] = (char)c;
		}
	}
	if (used + 1 >= outsz)
		return 0;
	out[used++] = '"';
	out[used] = '\0';
	return used;
}

static void Lobby_PublishChat(void)
{
    char json[8192], name[256], text[1024];
    size_t used = 1;
    int i;
    json[0] = '[';
    json[1] = 0;
    for (i = 0; i < lobby.chat_count; i++) {
        lobby_chat_t *m = &lobby.chat[i];
        Lobby_JsonEscape(name, sizeof(name), m->name);
        Lobby_JsonEscape(text, sizeof(text), m->text);
        if (Q_snprintfz(json + used, sizeof(json) - used,
            "%s{\"id\":%u,\"seat\":%i,\"name\":%s,\"text\":%s}",
            i ? "," : "", m->id, m->seat, name, text))
            break;
        used = strlen(json);
    }
    Q_snprintfz(json + used, sizeof(json) - used, "]");
    Cvar_Set(&lobby_chat_cv, json);
}

static void Lobby_PublishSnapshot(void)
{
	char json[8192];
	char esc[256];
	size_t used = 0;
	int i, first = 1;
	qboolean can_ready, can_start, can_cancel, can_map, can_leave;
	const char *map;
	extern double realtime;

	if (!lobby.active)
	{
		Cvar_Set(&lobby_active_cv, "0");
        Cvar_Set(&lobby_chat_cv, "[]");
		Cvar_Set(&lobby_snapshot_cv,
			"{\"active\":false,\"revision\":0,\"players\":[],\"phase\":\"IDLE\"}");
		return;
	}

	can_leave = true;
	can_ready = lobby.state >= LOBBY_STATE_WAITING && lobby.state < LOBBY_STATE_STARTING && lobby.local_seat >= 0;
	can_start = lobby.is_host && can_ready;
	can_cancel = lobby.is_host && (lobby.state == LOBBY_STATE_COUNTDOWN || lobby.state == LOBBY_STATE_READY_CHECK);
	can_map = lobby.is_host && lobby.state < LOBBY_STATE_COUNTDOWN;
	map = Lobby_GetMap();

	/* Q_snprintfz returns qboolean — always measure with strlen. */
	json[0] = 0;
	Q_snprintfz(json, sizeof(json), "{\"active\":true,\"sessionId\":");
	used = strlen(json);
	Lobby_JsonEscape(esc, sizeof(esc), lobby.session_id);
	Q_snprintfz(json + used, sizeof(json) - used, "%s,\"revision\":%u,\"network\":", esc, lobby.revision);
	used = strlen(json);
	Lobby_JsonEscape(esc, sizeof(esc), Lobby_NetworkName(lobby.network));
	Q_snprintfz(json + used, sizeof(json) - used,
		"%s,\"isHost\":%s,\"localSeat\":%i,\"phase\":",
		esc, lobby.is_host ? "true" : "false", lobby.local_seat);
	used = strlen(json);
	Lobby_JsonEscape(esc, sizeof(esc), Lobby_PhaseName(lobby.state));
	Q_snprintfz(json + used, sizeof(json) - used, "%s,\"status\":", esc);
	used = strlen(json);
	Lobby_JsonEscape(esc, sizeof(esc), lobby.status);
	Q_snprintfz(json + used, sizeof(json) - used, "%s,\"error\":", esc);
	used = strlen(json);
	Lobby_JsonEscape(esc, sizeof(esc), lobby.error);
	Q_snprintfz(json + used, sizeof(json) - used, "%s,\"roomCode\":", esc);
	used = strlen(json);
	Lobby_JsonEscape(esc, sizeof(esc), lobby.state == LOBBY_STATE_CREATING ? "" : lobby.room_code);
	Q_snprintfz(json + used, sizeof(json) - used, "%s,\"uiVersion\":", esc);
	used = strlen(json);
    Q_snprintfz(json + used, sizeof(json) - used, "1,\"max\":%i,\"canChat\":%s,\"settings\":{",
        lobby.is_host ? Lobby_GetMaxPlayers() : atoi(InfoBuf_ValueForKey(&lobby.settings, "maxplayers")),
        can_ready ? "true" : "false");
    used = strlen(json);
    {
        const char *keys[] = { "ruleset", "servertype", "timelimit", "fraglimit" };
        int k;
        for (k = 0; k < 4; k++) {
            Lobby_JsonEscape(esc, sizeof(esc), InfoBuf_ValueForKey(&lobby.settings, keys[k]));
            Q_snprintfz(json + used, sizeof(json) - used, "%s\"%s\":%s", k ? "," : "", keys[k], esc);
            used = strlen(json);
        }
    }
    Q_snprintfz(json + used, sizeof(json) - used, "},\"map\":");
    used = strlen(json);
	Lobby_JsonEscape(esc, sizeof(esc), map ? map : "");
	Q_snprintfz(json + used, sizeof(json) - used,
		"%s,\"countdownEnd\":%.3f,\"serverTime\":%.3f,"
		"\"canReady\":%s,\"canStart\":%s,\"canCancel\":%s,\"canChangeMap\":%s,\"canLeave\":%s,\"players\":[",
		esc, lobby.countdown_end, realtime,
		can_ready ? "true" : "false",
		can_start ? "true" : "false",
		can_cancel ? "true" : "false",
		can_map ? "true" : "false",
		can_leave ? "true" : "false");
	used = strlen(json);

	for (i = 0; i < LOBBY_MAX_PLAYERS && used + 128 < sizeof(json); i++)
	{
		lobby_player_t *p = &lobby.players[i];
		if (!p->active)
			continue;
		if (!first)
		{
			json[used++] = ',';
			json[used] = 0;
		}
		first = 0;
		Lobby_JsonEscape(esc, sizeof(esc), p->name);
		Q_snprintfz(json + used, sizeof(json) - used,
			"{\"seat\":%i,\"name\":%s,\"host\":%s,\"ready\":%s,\"connected\":true}",
			p->seat, esc,
			p->is_host ? "true" : "false",
			p->ready ? "true" : "false");
		used = strlen(json);
	}
	if (used + 2 < sizeof(json))
	{
		json[used++] = ']';
		json[used++] = '}';
		json[used] = 0;
	}
	Cvar_Set(&lobby_active_cv, "1");
	Cvar_Set(&lobby_snapshot_cv, json);
    Lobby_PublishChat();
	/* ponytail: cwd-local mirror for U8 checks (avoid shared gamedir junction races). */
	{
		FILE *f = fopen("lobby_snapshot.json", "wb");
		if (f)
		{
			fwrite(json, 1, strlen(json), f);
			fclose(f);
		}
	}
}

/* Sync lobby state into cvars that menu QC / WebCore getlobby read. */
static void Lobby_SyncCvars(void)
{
	char buf[32];
	int i;
	lobby_player_t *p;
	static cvar_t *player_names[4];

	if (!player_names[0])
	{
		player_names[0] = &lobby_player1_name;
		player_names[1] = &lobby_player2_name;
		player_names[2] = &lobby_player3_name;
		player_names[3] = &lobby_player4_name;
	}

	Lobby_PublishSnapshot();

	if (!lobby.active)
	{
		Cvar_Set(&lobby_player_count, "0");
		Cvar_Set(&lobby_room_code_cv, "");
		Cvar_Set(&lobby_host_name_cv, "");
		Cvar_Set(&lobby_state_str_cv, "");
		Cvar_Set(&lobby_max_players_cv, "0");
		for (i = 0; i < 4; i++)
			Cvar_Set(player_names[i], "");
		return;
	}

	Q_snprintfz(buf, sizeof(buf), "%i", Lobby_GetPlayerCount());
	Cvar_Set(&lobby_player_count, buf);

	Cvar_Set(&lobby_room_code_cv, lobby.room_code[0] ? lobby.room_code : "");
	Cvar_Set(&lobby_host_name_cv, Lobby_GetHostName());
	Cvar_Set(&lobby_state_str_cv, Lobby_GetStatusText());

	Q_snprintfz(buf, sizeof(buf), "%i", Lobby_GetMaxPlayers());
	Cvar_Set(&lobby_max_players_cv, buf);

	/* Joiner with empty roster: keep legacy getlobby active until host pushes seats. */
	if (Lobby_GetPlayerCount() == 0 && !lobby.is_host)
	{
		Cvar_Set(&lobby_player_count, "1");
		Cvar_Set(player_names[0], "(joining…)");
		for (i = 1; i < 4; i++)
			Cvar_Set(player_names[i], "");
		return;
	}

	for (i = 0; i < 4; i++)
	{
		p = Lobby_GetPlayer(i);
		if (!p)
			Cvar_Set(player_names[i], "");
		else if (p->ready)
			Cvar_Set(player_names[i], va("%s [READY]", p->name));
		else
			Cvar_Set(player_names[i], p->name);
	}
}

static void Lobby_Emit(lobby_event_type_t type, int seat, const char *text)
{
	lobby_event_t ev;
	size_t i;

	memset(&ev, 0, sizeof(ev));
	ev.type = type;
	ev.seat = seat;
	if (text)
		Q_strncpyz(ev.text, text, sizeof(ev.text));

	for (i = 0; i < LOBBY_MAX_EVENT_SINKS; i++)
	{
		if (lobby.sinks[i].fn)
			lobby.sinks[i].fn(&ev, lobby.sinks[i].ctx);
	}

	Lobby_SyncCvars();
}

static lobby_backend_t *Lobby_PickBackend(lobby_network_t net)
{
	switch (net)
	{
	case LOBBY_NET_OFFLINE:
		return &lobby_backend_offline;
	case LOBBY_NET_LAN:
		return &lobby_backend_lan;
	case LOBBY_NET_ONLINE:
		return &lobby_backend_ice;
	default:
		return NULL;
	}
}

static void Lobby_ClearPlayers(void)
{
	size_t i;
	for (i = 0; i < LOBBY_MAX_PLAYERS; i++)
	{
		InfoBuf_Clear(&lobby.players[i].info, true);
		memset(&lobby.players[i], 0, sizeof(lobby.players[i]));
	}
}

static int Lobby_AddPlayerInternal(int seat, const char *name, qboolean is_host)
{
	size_t i;
	lobby_player_t *p = NULL;

	for (i = 0; i < LOBBY_MAX_PLAYERS; i++)
	{
		if (lobby.players[i].active && lobby.players[i].seat == seat)
		{
			p = &lobby.players[i];
			break;
		}
	}
	if (!p)
	{
		for (i = 0; i < LOBBY_MAX_PLAYERS; i++)
		{
			if (!lobby.players[i].active)
			{
				p = &lobby.players[i];
				break;
			}
		}
	}
	if (!p)
		return -1;

	p->active = true;
	p->is_host = is_host;
	p->ready = false;	/* host is a normal player — must Ready explicitly */
	p->seat = seat;
	if (name && *name)
		Q_strncpyz(p->name, name, sizeof(p->name));
	else
		Q_snprintfz(p->name, sizeof(p->name), "Player %i", seat + 1);
	InfoBuf_SetKey(&p->info, "name", p->name);
	if (is_host)
		InfoBuf_SetKey(&p->info, "host", "1");

	Lobby_Emit(LOBBY_EVT_PLAYER_JOINED, seat, p->name);
	Lobby_MarkRosterChanged();
	if (lobby.state == LOBBY_STATE_COUNTDOWN)
		Lobby_AbortCountdown("Player joined — ready cleared.");
	return seat;
}

static void Lobby_RemovePlayerInternal(int seat)
{
	size_t i;
	for (i = 0; i < LOBBY_MAX_PLAYERS; i++)
	{
		if (lobby.players[i].active && lobby.players[i].seat == seat)
		{
			char name[64];
			Q_strncpyz(name, lobby.players[i].name, sizeof(name));
			InfoBuf_Clear(&lobby.players[i].info, true);
			memset(&lobby.players[i], 0, sizeof(lobby.players[i]));
			Lobby_Emit(LOBBY_EVT_PLAYER_LEFT, seat, name);
			Lobby_MarkRosterChanged();
			if (lobby.state == LOBBY_STATE_COUNTDOWN)
				Lobby_AbortCountdown("Player left — ready cleared.");
			return;
		}
	}
}

static void Lobby_SetStateInternal(lobby_state_t state)
{
	char buf[32];
	if (lobby.state == state)
		return;
	lobby.state = state;
	lobby.revision++;
	Q_snprintfz(buf, sizeof(buf), "%i", (int)state);
	InfoBuf_SetKey(&lobby.settings, "lobby_state", buf);
	if (lobby.backend && lobby.backend->send_rule)
		lobby.backend->send_rule("lobby_state", buf);
	Lobby_SyncServerInfo();
	Lobby_Emit(LOBBY_EVT_STATE_CHANGED, -1, buf);
}

static void Lobby_MarkRosterChanged(void)
{
	/* Short settle so join/leave churn does not thrash countdown. */
	lobby.roster_stable_at = realtime + 0.35;
}

static void Lobby_ClearAllReady(void)
{
	size_t i;
	for (i = 0; i < LOBBY_MAX_PLAYERS; i++)
	{
		if (!lobby.players[i].active)
			continue;
		lobby.players[i].ready = false;
		InfoBuf_SetKey(&lobby.players[i].info, "ready", "0");
		if (lobby.backend && lobby.backend->send_player)
			lobby.backend->send_player(lobby.players[i].seat, &lobby.players[i].info);
	}
	lobby.countdown_end = 0;
	lobby.revision++;
	Lobby_Emit(LOBBY_EVT_READY_CHANGED, -1, "0");
}

static qboolean Lobby_AllReady(void)
{
	size_t i;
	int count = 0, ready = 0;
	for (i = 0; i < LOBBY_MAX_PLAYERS; i++)
	{
		if (!lobby.players[i].active)
			continue;
		count++;
		if (lobby.players[i].ready)
			ready++;
	}
	return count > 0 && ready >= count;
}

static void Lobby_ArmCountdown(void)
{
	float secs;
	if (!lobby.active || !lobby.is_host)
		return;
	if (lobby.state < LOBBY_STATE_WAITING || lobby.state == LOBBY_STATE_COUNTDOWN || lobby.state >= LOBBY_STATE_STARTING)
		return;
	if (realtime < lobby.roster_stable_at)
		return;
	if (!Lobby_AllReady())
		return;

	secs = lobby_readytime.value;
	if (secs < 1)
		secs = 1;
	lobby.countdown_end = realtime + secs;
	Lobby_SetStateInternal(LOBBY_STATE_COUNTDOWN);
	Q_snprintfz(lobby.status, sizeof(lobby.status), "Starting in %.0f...", secs);
	if (lobby.backend && lobby.backend->send_rule)
	{
		char buf[32];
		Q_snprintfz(buf, sizeof(buf), "%.0f", lobby.countdown_end);
		lobby.backend->send_rule("countdown_end", buf);
	}
}

static void Lobby_AbortCountdown(const char *reason)
{
	if (!lobby.active)
		return;
	if (lobby.state != LOBBY_STATE_COUNTDOWN && lobby.state != LOBBY_STATE_READY_CHECK)
		return;
	Lobby_ClearAllReady();
	Lobby_SetStateInternal(LOBBY_STATE_WAITING);
	Q_strncpyz(lobby.status, reason ? reason : "Countdown cancelled.", sizeof(lobby.status));
}

static void Lobby_DefaultSettings(void)
{
	InfoBuf_Clear(&lobby.settings, true);
	InfoBuf_SetKey(&lobby.settings, "lobby", "1");
	InfoBuf_SetKey(&lobby.settings, "ruleset", lobby_defaultruleset.string);
	InfoBuf_SetKey(&lobby.settings, "map", lobby_defaultmap.string);
	InfoBuf_SetKey(&lobby.settings, "network", "offline");
	InfoBuf_SetKey(&lobby.settings, "servertype", "LISTEN SERVER");
    InfoBuf_SetKey(&lobby.settings, "timelimit", "0");
    InfoBuf_SetKey(&lobby.settings, "fraglimit", "0");
    InfoBuf_SetKey(&lobby.settings, "maxplayers", va("%i", Lobby_GetMaxPlayers()));
}

void Lobby_Init(void)
{
	static qboolean inited;
	if (inited)
		return;
	inited = true;

	Cvar_Register(&lobby_maxplayers, "Lobby");
	Cvar_Register(&lobby_readytime, "Lobby");
	Cvar_Register(&lobby_defaultmap, "Lobby");
	Cvar_Register(&lobby_defaultruleset, "Lobby");
	Cvar_Register(&lobby_snapshot_cv, "Lobby");
    Cvar_Register(&lobby_chat_cv, "Lobby");
	Cvar_Register(&lobby_active_cv, "Lobby");
	Cvar_Register(&lobby_player_count, "Lobby");
	Cvar_Register(&lobby_room_code_cv, "Lobby");
	Cvar_Register(&lobby_host_name_cv, "Lobby");
	Cvar_Register(&lobby_state_str_cv, "Lobby");
	Cvar_Register(&lobby_max_players_cv, "Lobby");
	Cvar_Register(&lobby_player1_name, "Lobby");
	Cvar_Register(&lobby_player2_name, "Lobby");
	Cvar_Register(&lobby_player3_name, "Lobby");
	Cvar_Register(&lobby_player4_name, "Lobby");
	Lobby_Ice_InitCvars();
	Lobby_Transport_RegisterCvars();
	Lobby_RegisterCommands();
	memset(&lobby, 0, sizeof(lobby));
	InfoBuf_Clear(&lobby.settings, true);
	Lobby_SyncCvars();
}

void Lobby_Shutdown(void)
{
	Lobby_Close();
}

qboolean Lobby_IsActive(void)
{
	return lobby.active;
}

lobby_state_t Lobby_GetState(void)
{
	return lobby.state;
}

lobby_network_t Lobby_GetNetwork(void)
{
	return lobby.network;
}

qboolean Lobby_IsHost(void)
{
	return lobby.is_host;
}

const char *Lobby_GetRoomCode(void)
{
	return lobby.room_code;
}

const char *Lobby_GetHostName(void)
{
	size_t i;
	for (i = 0; i < LOBBY_MAX_PLAYERS; i++)
	{
		if (lobby.players[i].active && lobby.players[i].is_host)
			return lobby.players[i].name;
	}
	return "Host";
}

const char *Lobby_GetStatusText(void)
{
	if (*lobby.status)
		return lobby.status;

	switch (lobby.state)
	{
	case LOBBY_STATE_WAITING:
	case LOBBY_STATE_CONFIG:
		return lobby.is_host ? "Configure settings or start the game." : "Waiting for host to start game...";
	case LOBBY_STATE_READY_CHECK:
		return "Waiting for all players to ready up...";
	case LOBBY_STATE_COUNTDOWN:
		return lobby.status[0] ? lobby.status : "Countdown...";
	case LOBBY_STATE_STARTING:
		return "Starting game...";
	case LOBBY_STATE_CLOSING:
		return lobby.status[0] ? lobby.status : "Lobby closed.";
	case LOBBY_STATE_INGAME:
		return "In game.";
	case LOBBY_STATE_POSTGAME:
		return "Postgame lobby.";
	default:
		return "Ready";
	}
}

infobuf_t *Lobby_GetSettings(void)
{
	return &lobby.settings;
}

int Lobby_GetPlayerCount(void)
{
	size_t i, n = 0;
	for (i = 0; i < LOBBY_MAX_PLAYERS; i++)
		if (lobby.players[i].active)
			n++;
	return (int)n;
}

int Lobby_GetMaxPlayers(void)
{
	return bound(2, lobby_maxplayers.ival, LOBBY_MAX_PLAYERS);
}

lobby_player_t *Lobby_GetPlayer(int index)
{
	size_t i, n = 0;
	for (i = 0; i < LOBBY_MAX_PLAYERS; i++)
	{
		if (!lobby.players[i].active)
			continue;
		if ((int)n == index)
			return &lobby.players[i];
		n++;
	}
	return NULL;
}

lobby_player_t *Lobby_FindPlayerBySeat(int seat)
{
	size_t i;
	for (i = 0; i < LOBBY_MAX_PLAYERS; i++)
		if (lobby.players[i].active && lobby.players[i].seat == seat)
			return &lobby.players[i];
	return NULL;
}

int Lobby_GetLocalSeat(void)
{
	return lobby.local_seat;
}

float Lobby_GetCountdownRemaining(void)
{
	if (!lobby.active || lobby.countdown_end <= 0)
		return 0;
	if (realtime >= lobby.countdown_end)
		return 0;
	return (float)(lobby.countdown_end - realtime);
}

const char *Lobby_GetMap(void)
{
	const char *map;
	if (!lobby.active)
		return "";
	map = InfoBuf_ValueForKey(&lobby.settings, "map");
	if (map && *map)
		return map;
	return lobby_defaultmap.string;
}

qboolean Lobby_RejectsJoins(void)
{
	if (!lobby.active)
		return false;
	return lobby.state >= LOBBY_STATE_COUNTDOWN;
}

void Lobby_RememberJoinHost(const char *addrstr)
{
	if (!addrstr)
		return;
	Q_strncpyz(lobby.join_host, addrstr, sizeof(lobby.join_host));
}

qboolean Lobby_CancelCountdown(void)
{
	if (!lobby.active || !lobby.is_host)
		return false;
	if (lobby.state != LOBBY_STATE_COUNTDOWN && lobby.state != LOBBY_STATE_READY_CHECK)
		return false;
	Lobby_AbortCountdown("Countdown cancelled.");
	return true;
}

void Lobby_OnGameStartingMsg(const char *mapname, const char *connect_target)
{
#ifdef HAVE_CLIENT
	/* Idempotent: ignore duplicate G: commits. */
	if (lobby.state == LOBBY_STATE_INGAME && lobby.start_published)
		return;
	if (connect_target && *connect_target)
	{
		Con_Printf("Lobby: connecting to game %s (map %s)\n", connect_target, mapname ? mapname : "?");
		Cbuf_AddText(va("webcore_closemenu\nconnect %s\n", connect_target), RESTRICT_LOCAL);
	}
	else
		Con_Printf(CON_WARNING "Lobby: game starting without connect target (map %s)\n", mapname ? mapname : "?");
#else
	(void)mapname;
	(void)connect_target;
#endif
	if (lobby.active)
	{
		lobby.start_published = lobby.start_nonce ? lobby.start_nonce : 1;
		Lobby_SetStateInternal(LOBBY_STATE_INGAME);
	}
}

qboolean Lobby_Create(lobby_network_t net, qboolean as_host)
{
	const char *playername;
	lobby_backend_t *backend;

	if (lobby.active)
		Lobby_Close();

	backend = Lobby_PickBackend(net);
	if (!backend)
		return false;

	memset(&lobby, 0, sizeof(lobby));
	if (lobby_create_room_code[0])
	{
		Q_strncpyz(lobby.room_code, lobby_create_room_code, sizeof(lobby.room_code));
		lobby_create_room_code[0] = 0;
	}
	lobby.active = true;
	lobby.network = net;
	lobby.is_host = as_host;
	lobby.backend = backend;
	lobby.local_seat = as_host ? 0 : -1;
	{
		unsigned rnd[2];
		Sys_RandomBytes((void *)rnd, sizeof(rnd));
		Q_snprintfz(lobby.session_id, sizeof(lobby.session_id), "%08x%08x", rnd[0], rnd[1]);
	}
	Lobby_DefaultSettings();

	switch (net)
	{
	case LOBBY_NET_OFFLINE:
		InfoBuf_SetKey(&lobby.settings, "network", "offline");
		break;
	case LOBBY_NET_LAN:
		InfoBuf_SetKey(&lobby.settings, "network", "lan");
		break;
	case LOBBY_NET_ONLINE:
		InfoBuf_SetKey(&lobby.settings, "network", "online");
		break;
	}

	Lobby_SetStateInternal(LOBBY_STATE_CREATING);
	if (!backend->create || !backend->create(net, as_host))
	{
		Lobby_Close();
		return false;
	}

	/* Only the host owns seat 0 locally. Joiners wait for A:/P: from the host. */
	if (as_host)
	{
		playername = "Player 1";
#ifdef HAVE_CLIENT
		if (*InfoBuf_ValueForKey(&cls.userinfo[0], "name"))
			playername = InfoBuf_ValueForKey(&cls.userinfo[0], "name");
#endif
		Lobby_AddPlayerInternal(0, playername, true);
	}
	else
		Q_strncpyz(lobby.status, "Connecting to host...", sizeof(lobby.status));

	if (net == LOBBY_NET_ONLINE && as_host)
	{
		lobby.broker_deadline = realtime + 45;
		Q_strncpyz(lobby.status, "Creating online room...", sizeof(lobby.status));
		Lobby_SetStateInternal(LOBBY_STATE_CREATING);
	}
	else
		Lobby_SetStateInternal(as_host ? LOBBY_STATE_WAITING : LOBBY_STATE_JOINING);
	Lobby_SyncServerInfo();
	Lobby_Emit(LOBBY_EVT_SESSION_CREATED, as_host ? 0 : -1, NULL);
	return true;
}

void Lobby_Close(void)
{
	if (!lobby.active)
		return;

	if (!lobby.is_host && lobby.local_seat >= 0)
	{
		char msg[32];
		Q_snprintfz(msg, sizeof(msg), "D:%d", lobby.local_seat);
		Lobby_Transport_Broadcast(msg, strlen(msg));
	}

	if (lobby.backend && lobby.backend->destroy)
		lobby.backend->destroy();

	Lobby_Transport_Close();

#ifdef HAVE_SERVER
	if (lobby.is_host)
	{
		InfoBuf_RemoveKey(&svs.info, "lobby");
		InfoBuf_RemoveKey(&svs.info, "lobby_state");
		InfoBuf_RemoveKey(&svs.info, "lobby_map");
		InfoBuf_RemoveKey(&svs.info, "lobby_ruleset");
	}
#endif

	Lobby_Emit(LOBBY_EVT_SESSION_CLOSED, -1, NULL);
	Lobby_ClearPlayers();
	InfoBuf_Clear(&lobby.settings, true);
	memset(&lobby, 0, sizeof(lobby));
	InfoBuf_Clear(&lobby.settings, true);
}

qboolean Lobby_Join(const char *room_or_address)
{
	if (!room_or_address || !*room_or_address)
		return false;

	if (lobby.active)
		Lobby_Close();

	/* Online room codes route through the ICE backend; addresses use LAN lobby UDP. */
	if (strchr(room_or_address, '.') || strchr(room_or_address, ':'))
	{
		char name[64] = "Player";
#ifdef HAVE_CLIENT
		if (*InfoBuf_ValueForKey(&cls.userinfo[0], "name"))
			Q_strncpyz(name, InfoBuf_ValueForKey(&cls.userinfo[0], "name"), sizeof(name));
#endif
		if (!Lobby_Create(LOBBY_NET_LAN, false))
			return false;

		Lobby_RememberJoinHost(room_or_address);
		Lobby_Transport_SetPeerAddress(0, room_or_address);
		if (!*Lobby_Transport_GetPeerAddress(0))
		{
			Con_Printf(CON_ERROR "Lobby: could not resolve host \"%s\"\n", room_or_address);
			Lobby_Close();
			return false;
		}
		Lobby_Transport_BeginJoin(name);
		Lobby_Transport_Poll();
	}
	else
	{
		char name[64] = "Player";
#ifdef HAVE_CLIENT
		if (*InfoBuf_ValueForKey(&cls.userinfo[0], "name"))
			Q_strncpyz(name, InfoBuf_ValueForKey(&cls.userinfo[0], "name"), sizeof(name));
#endif
		Q_strncpyz(lobby_create_room_code, room_or_address, sizeof(lobby_create_room_code));
		if (!Lobby_Create(LOBBY_NET_ONLINE, false))
			return false;
		Lobby_SetRoomCode(room_or_address);
		Lobby_Transport_BeginJoin(name);
		Lobby_Transport_Poll();
	}
	return true;
}

void Lobby_Leave(void)
{
	Lobby_Close();
}

qboolean Lobby_SetSetting(const char *key, const char *value)
{
	if (!lobby.active || !lobby.is_host || !key || !value)
		return false;
    if (lobby.state >= LOBBY_STATE_COUNTDOWN)
        return false;
    if (!strcmp(key, "ruleset") && strcmp(value, "DUEL") && strcmp(value, "DEATHMATCH") && strcmp(value, "TEAMDM") && strcmp(value, "DOMINATION"))
        return false;
    if (!strcmp(key, "timelimit") || !strcmp(key, "fraglimit")) {
        const char *p;
        if (!*value || strlen(value) > 3) return false;
        for (p = value; *p; p++) if (*p < '0' || *p > '9') return false;
        if (!strcmp(key, "timelimit") && atoi(value) > 180) return false;
    }
    InfoBuf_SetKey(&lobby.settings, key, value);
	if (lobby.backend && lobby.backend->send_rule)
		lobby.backend->send_rule(key, value);
	lobby.revision++;
	Lobby_SyncServerInfo();
	Lobby_Emit(LOBBY_EVT_SETTINGS_CHANGED, -1, key);

	if (!strcmp(key, "map") || !strcmp(key, "ruleset") || !strcmp(key, "timelimit") || !strcmp(key, "fraglimit"))
	{
		if (lobby.state == LOBBY_STATE_COUNTDOWN || lobby.state == LOBBY_STATE_READY_CHECK)
			Lobby_AbortCountdown("Map changed — ready cleared.");
		else
			Lobby_ClearAllReady();
	}
	return true;
}

qboolean Lobby_SetReady(qboolean ready)
{
	lobby_player_t *p;
	if (!lobby.active)
		return false;
	if (lobby.state < LOBBY_STATE_WAITING || lobby.state >= LOBBY_STATE_STARTING || lobby.local_seat < 0)
		return false;

	p = Lobby_FindPlayerBySeat(lobby.local_seat >= 0 ? lobby.local_seat : 0);
	if (!p)
		return false;

	p->ready = ready;
	InfoBuf_SetKey(&p->info, "ready", ready ? "1" : "0");
	lobby.revision++;
	if (lobby.backend && lobby.backend->send_player)
		lobby.backend->send_player(p->seat, &p->info);

	Lobby_Emit(LOBBY_EVT_READY_CHANGED, p->seat, ready ? "1" : "0");

	if (!ready && lobby.state == LOBBY_STATE_COUNTDOWN)
	{
		Lobby_AbortCountdown("Player unreadied — ready cleared.");
		return true;
	}

	if (ready && lobby.is_host)
		Lobby_ArmCountdown();
	else if (ready && lobby.state == LOBBY_STATE_WAITING)
		Lobby_SetStateInternal(LOBBY_STATE_READY_CHECK);

	/* Host arms countdown when all ready; joiners only flip local ready. */
	if (lobby.is_host && Lobby_AllReady())
		Lobby_ArmCountdown();

	return true;
}

static qboolean Lobby_CaptureListenEndpoint(void)
{
#ifdef HAVE_SERVER
	struct ftenet_generic_connection_s *gcon[8];
	unsigned int flags[8];
	netadr_t addr[8];
	const char *params[8];
	int m, i;
	char buf[128];

	/* sv.active is unused in this tree — listen readiness is sv.state. */
	if (sv.state < ss_active || !svs.sockets)
		return false;

	m = NET_EnumerateAddresses(svs.sockets, gcon, flags, addr, params, 8);
	for (i = 0; i < m; i++)
	{
		if (addr[i].type != NA_IP && addr[i].type != NA_IPV6)
			continue;
		if (addr[i].type == NA_IP && addr[i].address.ip[0] == 127)
			continue;
		NET_AdrToString(buf, sizeof(buf), &addr[i]);
		Q_strncpyz(lobby.listen_endpoint, buf, sizeof(lobby.listen_endpoint));
		return true;
	}
	for (i = 0; i < m; i++)
	{
		if (addr[i].type != NA_IP && addr[i].type != NA_IPV6)
			continue;
		NET_AdrToString(buf, sizeof(buf), &addr[i]);
		Q_strncpyz(lobby.listen_endpoint, buf, sizeof(lobby.listen_endpoint));
		return true;
	}
	{
		extern cvar_t sv_port_ipv4;
		Q_snprintfz(lobby.listen_endpoint, sizeof(lobby.listen_endpoint),
			"127.0.0.1:%i", sv_port_ipv4.ival ? sv_port_ipv4.ival : 27500);
		return true;
	}
#else
	return false;
#endif
}

static const char *Lobby_ConnectTargetForPeer(int seat, void *ctx)
{
	static char target[160];
	(void)ctx;

	if (lobby.network == LOBBY_NET_ONLINE)
	{
		return lobby.listen_endpoint; /* Confirmed by the GAME broker, not the lobby room. */
	}

	if (Lobby_Transport_PeerIsLoopback(seat) || lobby.network == LOBBY_NET_OFFLINE)
	{
		unsigned short port = 27500;
#ifdef HAVE_SERVER
		extern cvar_t sv_port_ipv4;
		if (sv_port_ipv4.ival)
			port = (unsigned short)sv_port_ipv4.ival;
#endif
		if (lobby.listen_endpoint[0] && strchr(lobby.listen_endpoint, ':'))
		{
			/* Rebuild with loopback host, keep port from listen endpoint when possible. */
			const char *colon = strrchr(lobby.listen_endpoint, ':');
			Q_snprintfz(target, sizeof(target), "127.0.0.1%s", colon ? colon : va(":%u", port));
		}
		else
			Q_snprintfz(target, sizeof(target), "127.0.0.1:%u", port);
		return target;
	}

	if (lobby.listen_endpoint[0])
	{
		Q_strncpyz(target, lobby.listen_endpoint, sizeof(target));
		return target;
	}
	Q_strncpyz(target, "127.0.0.1:27500", sizeof(target));
	return target;
}

static void Lobby_PublishGameStarting(void)
{
	if (!lobby.is_host || lobby.start_published == lobby.start_nonce)
		return;
#ifdef HAVE_SERVER
	/* A title backdrop / previous map may already have a listener. Wait
	 * for THIS map command to finish before publishing its destination. */
	if (svs.spawncount == lobby.start_spawncount)
		return;
#endif
	if (!Lobby_CaptureListenEndpoint())
		return;
	if (lobby.network == LOBBY_NET_ONLINE)
	{
#if defined(HAVE_SERVER) && defined(SUPPORT_ICE)
		int status;
		if (!lobby.game_registered)
		{
			char path[128];
			/* Separate broker room: lobby packets and gameplay have different
			 * handlers. Keep the lobby alive to deliver/retry the start commit. */
			Q_snprintfz(path, sizeof(path), "/%s-game-%u", lobby.session_id, lobby.start_nonce);
			if (!FTENET_AddToCollection(svs.sockets, "lobby_game", path, NA_INVALID, NP_RTC_TLS))
			{
				Q_strncpyz(lobby.status, "Could not register the online game. Leave and try again.", sizeof(lobby.status));
				Lobby_SetStateInternal(LOBBY_STATE_CLOSING);
				Lobby_SyncCvars();
				return;
			}
			lobby.game_registered = true;
		}
		status = NET_ICE_BrokerStatus(svs.sockets, "lobby_game", lobby.listen_endpoint, sizeof(lobby.listen_endpoint));
		if (status != 1)
		{
			Q_strncpyz(lobby.status, status < 0 ? "Online game registration failed. Leave and try again." : "Waiting for online game connection...", sizeof(lobby.status));
			if (status < 0)
				Lobby_SetStateInternal(LOBBY_STATE_CLOSING);
			Lobby_SyncCvars();
			return;
		}
#else
		return;
#endif
	}

	Lobby_Transport_SendGameStartingToPeers(lobby.start_map, Lobby_ConnectTargetForPeer, NULL);
	lobby.start_published = lobby.start_nonce;
	lobby.start_pending = false;
	Lobby_SetStateInternal(LOBBY_STATE_INGAME);
	Q_strncpyz(lobby.status, "Game starting.", sizeof(lobby.status));
	Lobby_SyncCvars();
}

static qboolean Lobby_CommitStart(void)
{
	const char *mapname;
	if (!lobby.active || !lobby.is_host)
		return false;
	if (lobby.state == LOBBY_STATE_STARTING && lobby.start_pending)
		return true;

	mapname = Lobby_GetMap();
	if (!mapname || !*mapname)
		mapname = lobby_defaultmap.string;

	lobby.start_nonce++;
	lobby.start_pending = true;
	lobby.game_registered = false;
#ifdef HAVE_SERVER
	lobby.start_spawncount = svs.spawncount;
#endif
	lobby.start_deadline = realtime + 45.0;
	Q_strncpyz(lobby.start_map, mapname, sizeof(lobby.start_map));
	lobby.listen_endpoint[0] = 0;
	Lobby_SetStateInternal(LOBBY_STATE_STARTING);
	Q_strncpyz(lobby.status, "Starting game...", sizeof(lobby.status));

	if (lobby.backend && lobby.backend->send_rule)
		lobby.backend->send_rule("map", mapname);

#ifdef HAVE_SERVER
	/* Close WebCore/title menu so map is not deferred forever behind menu focus. */
#ifdef HAVE_CLIENT
	Cbuf_AddText("webcore_closemenu\n", RESTRICT_LOCAL);
	Key_Dest_Remove(kdm_menu);
#endif
	/*
	 * Client startup can leave fs_game empty (VFS sees no maps). Dedicated
	 * does not. Ensure gamedir + listen slots before map.
	 */
	{
		cvar_t *fg = Cvar_FindVar("fs_game");
		if (!fg || !fg->string[0])
			Cbuf_AddText("gamedir base\n", RESTRICT_LOCAL);
	}
    {
        const char *ruleset = InfoBuf_ValueForKey(&lobby.settings, "ruleset");
        const char *game = !Q_strcasecmp(ruleset, "DUEL") ? "duel" :
            !Q_strcasecmp(ruleset, "TEAMDM") ? "teamdm" :
            !Q_strcasecmp(ruleset, "DOMINATION") ? "domination" : "deathmatch";
        Cbuf_AddText(va("set g_gametype %s\n", game), RESTRICT_LOCAL);
        Cbuf_AddText(va("timelimit %i\n", bound(0, atoi(InfoBuf_ValueForKey(&lobby.settings, "timelimit")), 180)), RESTRICT_LOCAL);
        Cbuf_AddText(va("fraglimit %i\n", bound(0, atoi(InfoBuf_ValueForKey(&lobby.settings, "fraglimit")), 999)), RESTRICT_LOCAL);
    }
	Cbuf_AddText("deathmatch 1\n", RESTRICT_LOCAL);
	Cbuf_AddText(va("maxplayers %i\n", lobby_maxplayers.ival > 0 ? lobby_maxplayers.ival : 16), RESTRICT_LOCAL);
	Cbuf_AddText(va("map %s\n", mapname), RESTRICT_LOCAL);
#endif

	Lobby_Emit(LOBBY_EVT_GAME_STARTING, -1, mapname);
	/* Stay in STARTING until listen-ready; Lobby_RunFrame publishes G:. */
	return true;
}

qboolean Lobby_StartGame(void)
{
	if (!lobby.active || !lobby.is_host)
		return false;
	if (lobby.state < LOBBY_STATE_WAITING || lobby.state >= LOBBY_STATE_STARTING)
		return false;

	/* Explicit host Start is authoritative and bypasses ready-state gating. */
	return Lobby_CommitStart();
}

qboolean Lobby_SetState(lobby_state_t state)
{
	if (!lobby.active)
		return false;
	Lobby_SetStateInternal(state);
	return true;
}

void Lobby_RegisterEventSink(lobby_event_fn fn, void *ctx)
{
	size_t i;
	if (!fn)
		return;
	for (i = 0; i < LOBBY_MAX_EVENT_SINKS; i++)
	{
		if (lobby.sinks[i].fn == fn && lobby.sinks[i].ctx == ctx)
			return;
		if (!lobby.sinks[i].fn)
		{
			lobby.sinks[i].fn = fn;
			lobby.sinks[i].ctx = ctx;
			return;
		}
	}
}

void Lobby_UnregisterEventSink(lobby_event_fn fn, void *ctx)
{
	size_t i;
	for (i = 0; i < LOBBY_MAX_EVENT_SINKS; i++)
	{
		if (lobby.sinks[i].fn == fn && lobby.sinks[i].ctx == ctx)
		{
			lobby.sinks[i].fn = NULL;
			lobby.sinks[i].ctx = NULL;
		}
	}
}

void Lobby_RunFrame(void)
{
	Lobby_Transport_Poll();
	if (!lobby.active)
		return;

	if (lobby.is_host)
	{
		if (lobby.state == LOBBY_STATE_CREATING && lobby.network == LOBBY_NET_ONLINE)
		{
			int status = Lobby_Ice_BrokerStatus();
			if (status == 1)
			{
				Lobby_SetStateInternal(LOBBY_STATE_WAITING);
				Q_strncpyz(lobby.status, "Online room ready. Share the room code.", sizeof(lobby.status));
				Lobby_SyncCvars();
			}
			else if (status < 0 || realtime > lobby.broker_deadline)
			{
				Q_strncpyz(lobby.status, "Could not create online room. Check your connection and try again.", sizeof(lobby.status));
				Lobby_SetStateInternal(LOBBY_STATE_CLOSING);
				Lobby_SyncCvars();
			}
		}
		else if (lobby.state == LOBBY_STATE_WAITING || lobby.state == LOBBY_STATE_READY_CHECK
			|| lobby.state == LOBBY_STATE_CONFIG)
		{
			if (Lobby_AllReady())
				Lobby_ArmCountdown();
		}
		else if (lobby.state == LOBBY_STATE_COUNTDOWN)
		{
			float left = Lobby_GetCountdownRemaining();
			if (left > 0)
				Q_snprintfz(lobby.status, sizeof(lobby.status), "Starting in %.0f...", left + 0.999f);
			else
				Lobby_CommitStart();
		}
		else if (lobby.state == LOBBY_STATE_STARTING && lobby.start_pending)
		{
			if (realtime > lobby.start_deadline)
			{
				Q_strncpyz(lobby.status, "Game connection did not become ready. Leave and try again.", sizeof(lobby.status));
				lobby.start_pending = false;
				Lobby_SetStateInternal(LOBBY_STATE_CLOSING);
				Lobby_SyncCvars();
			}
			else
				Lobby_PublishGameStarting();
		}
	}

	if (lobby.backend && lobby.backend->poll)
		lobby.backend->poll();

	/* Keep WebCore snapshot clocks fresh during countdown/start/join. */
	if (lobby.state == LOBBY_STATE_COUNTDOWN || lobby.state == LOBBY_STATE_STARTING
		|| (!lobby.is_host && lobby.local_seat < 0))
		Lobby_PublishSnapshot();
}

void Lobby_SyncServerInfo(void)
{
#ifdef HAVE_SERVER
	const char *mapname;
	const char *ruleset;
	char statebuf[16];

	if (!lobby.active || !lobby.is_host || sv.state < ss_active)
		return;

	mapname = InfoBuf_ValueForKey(&lobby.settings, "map");
	ruleset = InfoBuf_ValueForKey(&lobby.settings, "ruleset");
	Q_snprintfz(statebuf, sizeof(statebuf), "%i", (int)lobby.state);

	InfoBuf_SetKey(&svs.info, "lobby", "1");
	InfoBuf_SetKey(&svs.info, "lobby_state", statebuf);
	if (*mapname)
		InfoBuf_SetKey(&svs.info, "lobby_map", mapname);
	if (*ruleset)
		InfoBuf_SetKey(&svs.info, "lobby_ruleset", ruleset);
#endif
}

qboolean Lobby_ServerAcceptsConnects(void)
{
	if (!lobby.active)
		return true;
	return lobby.state < LOBBY_STATE_STARTING;
}

void Lobby_Kex_OnConnection(qboolean established, qboolean dropped)
{
	if (dropped)
	{
		Lobby_Emit(LOBBY_EVT_KEX_DISCONNECTED, -1, NULL);
		if (!lobby.is_host)
			Lobby_Close();
		return;
	}
	if (established)
	{
		Lobby_Emit(LOBBY_EVT_KEX_CONNECTED, -1, NULL);
		if (lobby.state == LOBBY_STATE_CREATING)
			Lobby_SetStateInternal(LOBBY_STATE_WAITING);
	}
}

void Lobby_Kex_OnRule(const char *key, const char *value)
{
	if (!lobby.active || !key || !value)
		return;

	InfoBuf_SetKey(&lobby.settings, key, value);
	if (!strcmp(key, "ingame") && atoi(value))
		Lobby_SetStateInternal(LOBBY_STATE_INGAME);
	else if (!strcmp(key, "ingame") && !atoi(value))
		Lobby_SetStateInternal(LOBBY_STATE_WAITING);
	Lobby_Emit(LOBBY_EVT_SETTINGS_CHANGED, -1, key);
}

void Lobby_SetRoomCode(const char *code)
{
	if (!code)
		return;
	Q_strncpyz(lobby.room_code, code, sizeof(lobby.room_code));
	InfoBuf_SetKey(&lobby.settings, "room", code);
	Lobby_Emit(LOBBY_EVT_SETTINGS_CHANGED, -1, "room");
}

void Lobby_Kex_OnPlayer(int seat, const char *info, qboolean remove)
{
	const char *name;
	const char *readystr;
	if (remove)
	{
		Lobby_RemovePlayerInternal(seat);
		return;
	}
	if (!info)
		return;
	name = Info_ValueForKey(info, "playername");
	if (!*name)
		name = Info_ValueForKey(info, "name");
	if (Lobby_FindPlayerBySeat(seat))
	{
		lobby_player_t *p = Lobby_FindPlayerBySeat(seat);
		if (p)
		{
			if (*name)
				Q_strncpyz(p->name, name, sizeof(p->name));
			InfoBuf_FromString(&p->info, info, false);
			readystr = Info_ValueForKey(info, "ready");
			if (*readystr)
				p->ready = !!atoi(readystr);
			Lobby_Emit(LOBBY_EVT_PLAYER_UPDATED, seat, p->name);
			if (lobby.is_host)
			{
				if (!p->ready && lobby.state == LOBBY_STATE_COUNTDOWN)
					Lobby_AbortCountdown("Player unreadied — ready cleared.");
				else if (Lobby_AllReady())
					Lobby_ArmCountdown();
			}
		}
	}
	else
		Lobby_AddPlayerInternal(seat, name, seat == 0);
}

void Lobby_Kex_OnChat(int seat, const char *msg)
{
    lobby_chat_t *entry;
    lobby_player_t *player = Lobby_FindPlayerBySeat(seat);
    if (!lobby.active || !player || !msg || !*msg || strlen(msg) > LOBBY_CHAT_BYTES)
        return;
    if (lobby.chat_count == LOBBY_CHAT_HISTORY) {
        memmove(lobby.chat, lobby.chat + 1, sizeof(lobby.chat[0]) * (LOBBY_CHAT_HISTORY - 1));
        lobby.chat_count--;
    }
    entry = &lobby.chat[lobby.chat_count++];
    entry->id = ++lobby.chat_sequence;
    entry->seat = seat;
    Q_strncpyz(entry->name, player->name, sizeof(entry->name));
    Q_strncpyz(entry->text, msg, sizeof(entry->text));
    Lobby_Emit(LOBBY_EVT_CHAT, seat, msg);
}

static int Lobby_HexDigit(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

static void Lobby_ChatHex_f(void)
{
    char text[LOBBY_CHAT_BYTES + 1];
    const char *hex = Cmd_Argv(1);
    size_t i, n = strlen(hex);
    if (Cmd_Argc() != 2 || !lobby.active || lobby.local_seat < 0 ||
        lobby.state < LOBBY_STATE_WAITING || lobby.state >= LOBBY_STATE_STARTING ||
        !lobby.backend || !lobby.backend->send_chat || !n || (n & 1) || n > LOBBY_CHAT_BYTES * 2)
        return;
    for (i = 0; i < n; i += 2) {
        int a = Lobby_HexDigit(hex[i]), b = Lobby_HexDigit(hex[i + 1]);
        if (a < 0 || b < 0) return;
        text[i / 2] = (char)((a << 4) | b);
        if ((unsigned char)text[i / 2] < 0x20 || text[i / 2] == 0x7f) return;
    }
    text[n / 2] = 0;
    if (lobby.backend->send_chat(lobby.local_seat, text))
        Lobby_Kex_OnChat(lobby.local_seat, text);
}

static void Lobby_Limits_f(void)
{
    const char *minutes = Cmd_Argv(1), *frags = Cmd_Argv(2), *p;
    if (Cmd_Argc() != 3 || !*minutes || !*frags || strlen(minutes) > 3 || strlen(frags) > 3) return;
    for (p = minutes; *p; p++) if (*p < '0' || *p > '9') return;
    for (p = frags; *p; p++) if (*p < '0' || *p > '9') return;
    if (atoi(minutes) > 180) return;
    if (Lobby_SetSetting("timelimit", minutes)) Lobby_SetSetting("fraglimit", frags);
}

static void Lobby_Create_f(void)
{
	const char *net = (Cmd_Argc() > 1) ? Cmd_Argv(1) : "offline";
	qboolean host = (Cmd_Argc() <= 2) || atoi(Cmd_Argv(2));
	if (!Q_strcasecmp(net, "lan"))
		Lobby_Create(LOBBY_NET_LAN, host);
	else if (!Q_strcasecmp(net, "online") || !Q_strcasecmp(net, "ice"))
		Lobby_Create(LOBBY_NET_ONLINE, host);
	else
		Lobby_Create(LOBBY_NET_OFFLINE, host);
}

static void Lobby_Close_f(void)
{
	Lobby_Close();
}

static void Lobby_Start_f(void)
{
	Lobby_StartGame();
}

static void Lobby_Cancel_f(void)
{
	Lobby_CancelCountdown();
}

static void Lobby_Ready_f(void)
{
	Lobby_SetReady(Cmd_Argc() <= 1 || atoi(Cmd_Argv(1)));
}

static void Lobby_Join_f(void)
{
	char buf[256];
	if (Cmd_Argc() < 2)
		return;
	if (Cmd_Argc() == 2)
	{
		Lobby_Join(Cmd_Argv(1));
		return;
	}
	/* Command-line +lobby_join 127.0.0.1:27501 may split on ':'. */
	Q_snprintfz(buf, sizeof(buf), "%s:%s", Cmd_Argv(1), Cmd_Argv(2));
	Lobby_Join(buf);
}

static void Lobby_Set_f(void)
{
	if (Cmd_Argc() >= 3)
		Lobby_SetSetting(Cmd_Argv(1), Cmd_Argv(2));
}

static void Lobby_CreateOffline_f(void)
{
	Lobby_Create(LOBBY_NET_OFFLINE, true);
}

static void Lobby_CreateLan_f(void)
{
	Lobby_Create(LOBBY_NET_LAN, true);
}

static void Lobby_CreateOnline_f(void)
{
	Lobby_Create(LOBBY_NET_ONLINE, true);
}

void Lobby_RegisterCommands(void)
{
	Cmd_AddCommandD("lobby_create", Lobby_Create_f, "Create a lobby: lobby_create [offline|lan|online] [1=host]");
	Cmd_AddCommandD("lobby_create_offline", Lobby_CreateOffline_f, "Create an offline host lobby.");
	Cmd_AddCommandD("lobby_create_lan", Lobby_CreateLan_f, "Create a LAN host lobby.");
	Cmd_AddCommandD("lobby_create_online", Lobby_CreateOnline_f, "Create an online host lobby.");
	Cmd_AddCommandD("lobby_close", Lobby_Close_f, "Leave or destroy the active lobby.");
	Cmd_AddCommandD("lobby_start", Lobby_Start_f, "Host starts the game immediately.");
	Cmd_AddCommandD("lobby_ready", Lobby_Ready_f, "Toggle ready state: lobby_ready [0|1]");
	Cmd_AddCommandD("lobby_cancel", Lobby_Cancel_f, "Host cancels countdown and clears all ready.");
	Cmd_AddCommandD("lobby_join", Lobby_Join_f, "Join a lobby by address or room code.");
	Cmd_AddCommandD("lobby_set", Lobby_Set_f, "Host sets a lobby key/value pair.");
    Cmd_AddCommandD("lobby_chat_hex", Lobby_ChatHex_f, "Send UTF-8 hex text to the current lobby.");
    Cmd_AddCommandD("lobby_limits", Lobby_Limits_f, "Host sets time and frag limits.");
}

#ifdef HAVE_CLIENT
void Lobby_ClientSyncFromServerInfo(void)
{
	const char *val;
	if (!lobby.active || lobby.is_host)
		return;

	val = InfoBuf_ValueForKey(&cl.serverinfo, "lobby");
	if (!val || !*val || !strcmp(val, "0"))
		return;

	val = InfoBuf_ValueForKey(&cl.serverinfo, "lobby_map");
	if (*val)
		InfoBuf_SetKey(&lobby.settings, "map", val);
	val = InfoBuf_ValueForKey(&cl.serverinfo, "lobby_ruleset");
	if (*val)
		InfoBuf_SetKey(&lobby.settings, "ruleset", val);
	val = InfoBuf_ValueForKey(&cl.serverinfo, "lobby_state");
	if (*val)
		lobby.state = (lobby_state_t)atoi(val);
}
#else
void Lobby_ClientSyncFromServerInfo(void)
{
}
#endif

#include "lobby_transport.c"
