
var bool autocvar_g_showHud = true;
var float g_flHUDProgs;
var void(void) g_hudMain;
var void(void) g_hudInit;
var void(void) g_hudDraw;
var void(void) g_hudDrawSpectator;
var void(void) g_hudDrawIntermission;
var void(void) g_hudDrawScores;
var void(string, string) g_hudSendStat;
var void(string) g_hudSwitchedWeapon;
var void(string) g_hudPickedUpItem;
var float(float) g_hudInputFrame;
var bool(string) g_hudConsoleCommand;
var bool(float, float, float, float, vector) g_hudInputEvent;
var bool(void) g_hudWantsCursor;
var void(string, string, string, string) g_hudObituary;
var void(void) g_hudReloadVideoResources;
var void(vector, int, int) g_hudDamageReceived;
var void(int, int, int) g_hudAmmoChanged;

void
HUDProgs_Init(void)
{
	/* already loaded */
	if (g_flHUDProgs > 0) {
		return;
	}

	g_flHUDProgs = addprogs("hud.dat");

	if (g_flHUDProgs > 0) {
		g_hudMain = externvalue(g_flHUDProgs, "main");
		g_hudInit = externvalue(g_flHUDProgs, "HUD_Init");
		g_hudDraw = externvalue(g_flHUDProgs, "HUD_Draw");
		g_hudDrawSpectator = externvalue(g_flHUDProgs, "HUD_DrawSpectator");
		g_hudDrawIntermission = externvalue(g_flHUDProgs, "HUD_DrawIntermission");
		g_hudDrawScores = externvalue(g_flHUDProgs, "HUD_DrawScores");
		g_hudSendStat = externvalue(g_flHUDProgs, "HUD_SendStat");
		g_hudSwitchedWeapon = externvalue(g_flHUDProgs, "HUD_WeaponSwitched");
		g_hudInputFrame = externvalue(g_flHUDProgs, "HUD_InputFrame");
		g_hudConsoleCommand = externvalue(g_flHUDProgs, "HUD_ConsoleCommand");
		g_hudInputEvent = externvalue(g_flHUDProgs, "HUD_InputEvent");
		g_hudWantsCursor = externvalue(g_flHUDProgs, "HUD_WantsCursor");
		g_hudReloadVideoResources = externvalue(g_flHUDProgs, "HUD_ReloadVideoResources");
		g_hudPickedUpItem = externvalue(g_flHUDProgs, "HUD_PickedUpItem");
		g_hudDamageReceived = externvalue(g_flHUDProgs, "HUD_DamageReceived");
		g_hudAmmoChanged = externvalue(g_flHUDProgs, "HUD_AmmoChanged");
		g_hudObituary = externvalue(g_flHUDProgs, "HUD_Obituary");

		if (g_hudMain) {
			g_hudMain();
		} else {
			ncError("HUD progs does not have a main function.");
			return;
		}

		if (g_hudInit) {
			g_hudInit();
		}
	}
}

void
HUDProgs_ReloadVideoResources(void)
{
	if (g_flHUDProgs > 0) {
		if (g_hudReloadVideoResources) {
			g_hudReloadVideoResources();
		}
	}
}

void
HUDProgs_Draw(void)
{
	if (g_clientInitialized == false) {
		return;
	}

	if (autocvar_g_showHud == false) {
		return;
	}

	if (g_flHUDProgs > 0) {
		if (g_hudDraw) {
			HUDProgs_SetTime();
			g_hudDraw();
		}
	}
}

/* the HUD progs has its own copies of the time globals */
void
HUDProgs_SetTime(void)
{
	externset(g_flHUDProgs, clframetime, "clframetime");
	externset(g_flHUDProgs, frametime, "frametime");
	externset(g_flHUDProgs, time, "time");
	externset(g_flHUDProgs, cltime, "cltime");
}

void
HUDProgs_DrawSpectator(void)
{
	if (autocvar_g_showHud == false) {
		return;
	}

	if (g_flHUDProgs > 0) {
		if (g_hudDrawSpectator) {
			HUDProgs_SetTime();
			g_hudDrawSpectator();
		}
	}
}

void
HUDProgs_DrawIntermission(void)
{
	if (autocvar_g_showHud == false) {
		return;
	}

	if (g_flHUDProgs > 0) {
		if (g_hudDrawIntermission) {
			HUDProgs_SetTime();
			g_hudDrawIntermission();
		}
	}
}

/* the score board: the HUD progs' HUD_DrawScores when it has one, else the
   game's Scores_Draw */
void
HUDProgs_DrawScores(void)
{
	if (g_flHUDProgs > 0 && g_hudDrawScores) {
		HUDProgs_SetTime();
		g_hudDrawScores();
		return;
	}

	Scores_Draw();
}

void
HUDProgs_SendStat(string statName, string statValue)
{
	if (g_flHUDProgs > 0) {
		if (g_hudSendStat) {
			g_hudSendStat(statName, statValue);
		}
	}
}

void
HUDProgs_SwitchedToWeapon(string weaponName)
{
	if (g_flHUDProgs > 0) {
		if (g_hudSwitchedWeapon) {
			g_hudSwitchedWeapon(weaponName);
		}
	}
}

void
HUDProgs_PickedUpItem(string itemName)
{
	if (g_flHUDProgs > 0) {
		if (g_hudPickedUpItem) {
			g_hudPickedUpItem(itemName);
		}
	}
}

float
HUDProgs_ClientInputFrame(float inputFrame)
{
	if (g_flHUDProgs > 0) {
		if (g_hudInputFrame) {
			return g_hudInputFrame(inputFrame);
		}
	}

	return (0.0f);
}

bool
HUDProgs_ConsoleCommand(string commandString)
{
	if (g_flHUDProgs > 0) {
		if (g_hudConsoleCommand) {
			return g_hudConsoleCommand(commandString);
		}
	}

	return (false);
}

/* input for the HUD progs' own menus: the event plus the client's mouse
   position. true when the HUD progs used the event. */
bool
HUDProgs_InputEvent(float eventType, float key, float character, float deviceID)
{
	if (g_flHUDProgs > 0) {
		if (g_hudInputEvent) {
			HUDProgs_SetTime();
			return g_hudInputEvent(eventType, key, character, deviceID, g_vecMousePos);
		}
	}

	return (false);
}

/* true while the HUD progs shows something that needs the mouse */
bool
HUDProgs_WantsCursor(void)
{
	if (g_flHUDProgs > 0) {
		if (g_hudWantsCursor) {
			return g_hudWantsCursor();
		}
	}

	return (false);
}

void
HUDProgs_DamageReceived(vector damagePos, int damagePoints, int damageFlags)
{
	if (g_flHUDProgs > 0) {
		if (g_hudDamageReceived) {
			g_hudDamageReceived(damagePos, damagePoints, damageFlags);
		}
	}
}

__weak void
HUDProgs_Obituary(string targetName, string attackerName, string weaponDef, string meansOfDeath)
{
	if (g_flHUDProgs > 0) {
		if (g_hudObituary) {
			g_hudObituary(targetName, attackerName, weaponDef, meansOfDeath);
		}
	}
}

void
HUDProgs_AmmoChanged(int ammoType, int absoluteValue, int deltaValue)
{
	if (g_flHUDProgs > 0) {
		if (g_hudAmmoChanged) {
			g_hudAmmoChanged(ammoType, absoluteValue, deltaValue);
		}
	}
}

__weak void
HUD_Init(void)
{
	HUDProgs_Init();
}

__weak void
HUD_ReloadVideoResources(void)
{
	HUDProgs_ReloadVideoResources();
}

__weak void
HUD_Draw(void)
{
	if (autocvar_g_showHud == false) {
		return;
	}

	HUDProgs_Draw();
}

__weak void
HUD_DrawSpectator(void)
{
	if (autocvar_g_showHud == false) {
		return;
	}

	HUDProgs_DrawSpectator();
}

__weak void
HUD_DrawIntermission(void)
{
	if (autocvar_g_showHud == false) {
		return;
	}

	HUDProgs_DrawIntermission();
}

__weak void
HUD_SendStat(string statName, string statValue)
{
	HUDProgs_SendStat(statName, statValue);
}

__weak void
HUD_SwitchedToWeapon(string weaponName)
{
	HUDProgs_SwitchedToWeapon(weaponName);
}

__weak void
HUD_PickedUpItem(string itemName)
{
	HUDProgs_PickedUpItem(itemName);
}

__weak void
HUD_AmmoChanged(int ammoType, int absoluteValue, int deltaValue)
{
	HUDProgs_AmmoChanged(ammoType, absoluteValue, deltaValue);
}

__weak float
HUD_ClientInputFrame(float inputButtons)
{
	return HUDProgs_ClientInputFrame(inputButtons);
}

__weak bool
HUD_ConsoleCommand(string commandString)
{
	return HUDProgs_ConsoleCommand(commandString);
}

__weak void
HUD_DamageReceived(vector damagePos, int damagePoints, int damageFlags)
{
	HUDProgs_DamageReceived(damagePos, damagePoints, damageFlags);
}

__weak void
HUD_Obituary(string targetName, string attackerName, string weaponDef, string meansOfDeath)
{
	HUDProgs_Obituary(targetName, attackerName, weaponDef, meansOfDeath);
}
