void Lobby_Init(void);
void Lobby_FrameStart(void);
void Lobby_OnPlayerConnect(entity pl);
void Lobby_OnPlayerSpawn(entity pl);
bool Lobby_OnPlayerRequestRespawn(entity pl);
void Lobby_OnPlayerDisconnect(entity pl);
void Lobby_OnPlayerKilled(entity v, entity a);
bool Lobby_OnClientCommand(entity pl, string cmd);

/* Nuclide looks these up by name (RULEMAP in src/server/GameRules.qc).
 * Under any other name they never run: no lobby state, and no player ever
 * spawns. */
void CodeCallback_StartGameType(void) { Lobby_Init(); }
void CodeCallback_FrameStart(void) { Lobby_FrameStart(); }
void CodeCallback_PlayerConnect(entity pl) { Lobby_OnPlayerConnect(pl); }
void CodeCallback_PlayerSpawn(entity pl) { Lobby_OnPlayerSpawn(pl); }
bool CodeCallback_PlayerRequestRespawn(entity pl) { return Lobby_OnPlayerRequestRespawn(pl); }
void CodeCallback_PlayerDisconnect(entity pl) { Lobby_OnPlayerDisconnect(pl); }
void CodeCallback_PlayerKilled(entity v, entity inflictor, entity a, string weapon) { Lobby_OnPlayerKilled(v, a); }
bool CodeCallback_ClientCommand(entity pl, string cmd) { return Lobby_OnClientCommand(pl, cmd); }
