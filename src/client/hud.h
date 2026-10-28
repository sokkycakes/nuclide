void HUD_Init(void);
void HUD_Draw(void);
void HUD_DrawSpectator(void);
void HUD_SendStat(string, string);
float HUD_ClientInputFrame(float);
bool HUD_ConsoleCommand(string);
void HUD_Obituary(string, string, string, string);

void HUDProgs_Init(void);
void HUDProgs_Draw(void);
void HUDProgs_DrawSpectator(void);
void HUDProgs_DrawIntermission(void);
void HUDProgs_DrawScores(void);
void Scores_Draw(void); /* the game's own score board */
void HUDProgs_SetTime(void);
void HUDProgs_SendStat(string, string);
float HUDProgs_ClientInputFrame(float);
bool HUDProgs_ConsoleCommand(string);
bool HUDProgs_InputEvent(float, float, float, float);
bool HUDProgs_WantsCursor(void);
void HUDProgs_Obituary(string, string, string, string);
