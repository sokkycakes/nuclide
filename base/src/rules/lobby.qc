#include "lobby.h"
var int g_lobbyState;
var float g_lobbyStateTime;
var float g_lobbyDeadline;
var int g_lobbyCountdownLast;
var float g_lobbyNextBroadcast;
var string g_lobbyRoomCode;
entity g_lobbyQueue[32];
var int g_lobbyQueueCount;
entity g_lobbyHost;
var autocvar float autocvar_lobby_countdownTime = 10.0f;
var autocvar int autocvar_lobby_minReady = 2;

string Lobby_StateName(void);
int Lobby_TotalPlayers(void);

static int     Lobby_PlayerState(entity pl) { return ((int)userinfo.GetFloat(pl, "*lobby_state")); }
static void    Lobby_SetPlayerState(entity pl, int s) { userinfo.SetFloat(pl, "*lobby_state", s); }

static string  Lobby_GenerateRoomCode(void) { return sprintf("%i", (int)(random() * 9000.0 + 1000.0)); }

static void    Lobby_SpawnFreeplay(entity pl) { if (teams.Valid((int)pl.team) == false) ents.Input(pl, "SetTeam", "1", pl); ents.ChangeToClass(pl, "player_mp"); game.TeleportToSpawnClass(pl, "info_player_deathmatch"); }

static void    Lobby_SpawnGame(entity pl) { if (teams.Valid((int)pl.team) == false) ents.Input(pl, "SetTeam", "1", pl); ents.ChangeToClass(pl, "player_mp"); game.TeleportToSpawnClass(pl, "info_player_deathmatch"); }

static void    Lobby_SpawnWaitingView(entity pl) { float st = pl.team; ents.Input(pl, "SetTeam", "0", pl); ents.ChangeToClass(pl, "spectator"); game.TeleportToSpawnClass(pl, "info_intermission"); ents.Input(pl, "SetTeam", ftos(st), pl); }

static void    Lobby_CenterprintAll(string msg) { for (entity p = world; (p = next.Player(p));) centerprint(p, msg); }

/* --- queue --- */
static bool Lobby_InQueue(entity pl) { for (int i = 0i; i < g_lobbyQueueCount; i++) { if (g_lobbyQueue[i] == pl) return (true); } return (false); }

static void Lobby_QueueRemove(entity pl) { int d = 0i; for (int i = 0i; i < g_lobbyQueueCount; i++) { if (g_lobbyQueue[i] != pl) { g_lobbyQueue[d] = g_lobbyQueue[i]; d++; } } g_lobbyQueueCount = d; }

static void Lobby_QueueAppend(entity pl) { if (Lobby_InQueue(pl) || g_lobbyQueueCount >= 32) return; g_lobbyQueue[g_lobbyQueueCount] = pl; g_lobbyQueueCount++; }

/* broadcast */
void Lobby_BroadcastState(void) {
	serverinfo.SetString("lobby_state", Lobby_StateName());
	serverinfo.SetInteger("lobby_ready", g_lobbyQueueCount);
	serverinfo.SetInteger("lobby_total", Lobby_TotalPlayers());
	serverinfo.SetString("lobby_roomcode", g_lobbyRoomCode);
	if (g_lobbyHost) serverinfo.SetString("lobby_host", g_lobbyHost.netname);
	else serverinfo.SetString("lobby_host", "");
	if (g_lobbyState == LOBBY_COUNTDOWN)
		serverinfo.SetInteger("lobby_countdown", (int)max(ceil(g_lobbyDeadline - time), 0));
	else serverinfo.SetInteger("lobby_countdown", 0);
}
static void Lobby_BroadcastThrottled(void) {
	if (g_lobbyNextBroadcast > time) return;
	g_lobbyNextBroadcast = time + 0.5f; Lobby_BroadcastState();
}
void Lobby_SetHost(entity pl) { g_lobbyHost = pl; }
bool Lobby_IsHost(entity pl) { return (pl == g_lobbyHost); }
/* transitions */
void Lobby_EnterWarmup(void) {
	g_lobbyState = LOBBY_WARMUP; g_lobbyStateTime = time; g_lobbyQueueCount = 0i;
	for (entity p = world; (p = next.Player(p));) {
		if (Lobby_PlayerState(p) == LOBBY_PLAYER_SPECTATOR || p.team == 3) continue;
		Lobby_SetPlayerState(p, LOBBY_PLAYER_JOINED); Lobby_SpawnFreeplay(p);
	}
	Lobby_BroadcastState();
}
void Lobby_EnterCountdown(void) {
	g_lobbyState = LOBBY_COUNTDOWN; g_lobbyStateTime = time;
	g_lobbyDeadline = time + autocvar_lobby_countdownTime; g_lobbyCountdownLast = -1i;
	Lobby_BroadcastState();
}
void Lobby_EnterLive(void) {
	g_lobbyState = LOBBY_LIVE; g_lobbyStateTime = time;
	for (int i = 0i; i < g_lobbyQueueCount; i++) { entity p = g_lobbyQueue[i];
		if (p && !(p.team == 3)) { Lobby_SetPlayerState(p, LOBBY_PLAYER_COMPETITOR); Lobby_SpawnGame(p); } }
	for (entity p = world; (p = next.Player(p));) { int st = Lobby_PlayerState(p);
		if (st != LOBBY_PLAYER_COMPETITOR && st != LOBBY_PLAYER_SPECTATOR && p.team != 3) Lobby_SpawnWaitingView(p); }
	Lobby_CenterprintAll("FIGHT!"); Lobby_BroadcastState();
}
void Lobby_EndMatch(void) {
	g_lobbyState = LOBBY_WARMUP; g_lobbyStateTime = time; g_lobbyQueueCount = 0i;
	for (entity p = world; (p = next.Player(p));) {
		if (Lobby_PlayerState(p) == LOBBY_PLAYER_SPECTATOR || p.team == 3) continue;
		Lobby_SetPlayerState(p, LOBBY_PLAYER_JOINED); Lobby_SpawnFreeplay(p); }
	Lobby_CenterprintAll("Match ended. Back to lobby."); Lobby_BroadcastState();
}
/* ticks */
static void Lobby_TickWarmup(void) { int mr = (int)autocvar_lobby_minReady; if (mr > 0i && g_lobbyQueueCount >= mr) Lobby_EnterCountdown(); }
static void Lobby_TickCountdown(void) {
	int r = (int)max(ceil(g_lobbyDeadline - time), 0);
	serverinfo.SetInteger("lobby_countdown", r);
	if (r != g_lobbyCountdownLast && r > 0i) { g_lobbyCountdownLast = r; Lobby_CenterprintAll(sprintf("%i", r)); }
	if (r == 1i && g_lobbyCountdownLast != -2i) { g_lobbyCountdownLast = -2i; sound(world, 4, "weapons/melee_swing", 1.0f, 0.4f); }
	if (time >= g_lobbyDeadline) Lobby_EnterLive();
}
static void Lobby_TickLive(void) { float tl = cvar("timelimit"); if (tl > 0i && time >= tl * 60.0f) Lobby_EndMatch(); }

/* queries */
int Lobby_ReadyCount(void) { return (g_lobbyQueueCount); }
int Lobby_TotalPlayers(void) { int c = 0i; for (entity p = world; (p = next.Player(p));) c++; return (c); }
bool Lobby_IsReady(entity pl) { return (Lobby_PlayerState(pl) == LOBBY_PLAYER_READY); }
string Lobby_StateName(void) { switch (g_lobbyState) { case LOBBY_WARMUP: return ("WARMUP"); case LOBBY_COUNTDOWN: return ("COUNTDOWN"); case LOBBY_LIVE: return ("LIVE"); } return ("?"); }
bool Lobby_IsActive(void) { return (g_lobbyState == LOBBY_WARMUP || g_lobbyState == LOBBY_COUNTDOWN); }
int Lobby_GetPlayerState(entity pl) { return (Lobby_PlayerState(pl)); }
/* API */
void Lobby_Init(void) { g_lobbyRoomCode = Lobby_GenerateRoomCode(); g_lobbyQueueCount = 0i; g_lobbyHost = __NULL__; teams.SetUp(1, "Players", [155, 205, 255], false); teams.SetSpawnPoint(1, "info_player_deathmatch"); Lobby_EnterWarmup(); }
void Lobby_FrameStart(void) { switch (g_lobbyState) { case LOBBY_WARMUP: Lobby_TickWarmup(); break; case LOBBY_COUNTDOWN: Lobby_TickCountdown(); break; case LOBBY_LIVE: Lobby_TickLive(); break; } Lobby_BroadcastThrottled(); }
void Lobby_OnPlayerConnect(entity pl) { Lobby_SetPlayerState(pl, LOBBY_PLAYER_JOINED); if (!g_lobbyHost) Lobby_SetHost(pl); }
void Lobby_OnPlayerSpawn(entity pl) { int st = Lobby_PlayerState(pl); if (st == LOBBY_PLAYER_SPECTATOR || pl.team == 3) return; if (g_lobbyState == LOBBY_WARMUP) Lobby_SpawnFreeplay(pl); else if (g_lobbyState == LOBBY_LIVE) { if (st == LOBBY_PLAYER_COMPETITOR) Lobby_SpawnGame(pl); else Lobby_SpawnWaitingView(pl); } else Lobby_SpawnWaitingView(pl); }
bool Lobby_OnPlayerRequestRespawn(entity pl) { int st = Lobby_PlayerState(pl); if (g_lobbyState == LOBBY_WARMUP && st != LOBBY_PLAYER_SPECTATOR && pl.team != 3) { Lobby_SpawnFreeplay(pl); return (true); } if (g_lobbyState == LOBBY_LIVE && st == LOBBY_PLAYER_COMPETITOR) { Lobby_SpawnGame(pl); return (true); } return (false); }
void Lobby_OnPlayerDisconnect(entity pl) { Lobby_QueueRemove(pl); if (pl == g_lobbyHost) { g_lobbyHost = __NULL__; for (entity p = world; (p = next.Player(p));) { if (p != pl) { g_lobbyHost = p; break; } } } Lobby_BroadcastState(); }
void Lobby_OnPlayerKilled(entity victim, entity attacker) { if (g_lobbyState != LOBBY_LIVE) return; if (is.Player(attacker)) { if (victim == attacker) attacker.frags--; else attacker.frags++; } victim.deaths++; }
/* UX */
void Lobby_SetReady(entity pl) { if (g_lobbyState != LOBBY_WARMUP) return; Lobby_SetPlayerState(pl, LOBBY_PLAYER_READY); Lobby_QueueAppend(pl); centerprint(pl, "You are READY"); }
void Lobby_SetNotReady(entity pl) { Lobby_QueueRemove(pl); Lobby_SetPlayerState(pl, LOBBY_PLAYER_JOINED); centerprint(pl, "You are NOT READY"); }
void Lobby_SetSpectator(entity pl) { Lobby_QueueRemove(pl); Lobby_SetPlayerState(pl, LOBBY_PLAYER_SPECTATOR); game.MakePureSpectator(pl); game.TeleportToSpawn(pl); centerprint(pl, "You are spectating"); }
void Lobby_StartGame(entity pl) { if (pl != g_lobbyHost) { centerprint(pl, "Only the host can start the game."); return; } if (g_lobbyState == LOBBY_WARMUP) { if (Lobby_PlayerState(pl) != LOBBY_PLAYER_READY) Lobby_SetReady(pl); Lobby_EnterCountdown(); } else if (g_lobbyState == LOBBY_COUNTDOWN) centerprint(pl, "Game already starting..."); }
bool Lobby_OnClientCommand(entity pl, string command) { tokenize(command); switch (argv(0)) { case "ready": Lobby_SetReady(pl); return (true); case "notready": Lobby_SetNotReady(pl); return (true); case "spectate": Lobby_SetSpectator(pl); return (true); case "startgame": Lobby_StartGame(pl); return (true); default: return (false); } return (false); }
