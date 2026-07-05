void Lobby_Init(void);
void Lobby_FrameStart(void);
void Lobby_OnPlayerConnect(entity pl);
void Lobby_OnPlayerSpawn(entity pl);
bool Lobby_OnPlayerRequestRespawn(entity pl);
void Lobby_OnPlayerDisconnect(entity pl);
void Lobby_OnPlayerKilled(entity v, entity a);
bool Lobby_OnClientCommand(entity pl, string cmd);

void CodeCallback_MapStart(void) { Lobby_Init(); }
void CodeCallback_StartFrame(void) { Lobby_FrameStart(); }
bool CodeCallback_PlayerConnect(entity pl) { Lobby_OnPlayerConnect(pl); return true; }
bool CodeCallback_PutPlayerInServer(entity pl) { Lobby_OnPlayerSpawn(pl); return true; }
bool CodeCallback_PlayerCanRespawn(entity pl) { return Lobby_OnPlayerRequestRespawn(pl); }
void CodeCallback_PlayerDisconnect(entity pl) { Lobby_OnPlayerDisconnect(pl); }
void CodeCallback_PlayerKilled(entity v, entity a, string m) { Lobby_OnPlayerKilled(v, a); }
bool CodeCallback_ClientCommand(entity pl, string cmd) { return Lobby_OnClientCommand(pl, cmd); }