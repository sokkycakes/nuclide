/*
 * Copyright (c) 2026 sokkycakes
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

/** @file tf_vguihud.qc
The HUD elements laid out by a Team Fortress 2 HUD's .res files (see
vgui.qc), doing what TF2's C++ panels do: setting the label variables and
showing the right panels. The HUD files come from a pk3 (zz_solarlight.pk3
holds SolarLightHUD REDUX); without them, HUD_Draw falls back to the plain
HUD. cg_tfhud 0 also turns this HUD off.
*/

var float autocvar_cg_tfhud = 1;
var bool g_tfvgLoaded;
var bool g_tfvgAvailable;

/** Whether a TF2 HUD is installed and in use. */
bool
TFVGui_Active(void)
{
	if (autocvar_cg_tfhud == 0) {
		return (false);
	}

	if (g_tfvgLoaded == false) {
		g_tfvgLoaded = true;
		g_tfvgAvailable = (fopen("scripts/hudlayout.res", FILE_READ) >= 0);

		if (g_tfvgAvailable) {
			VGui_Init();
			VGui_LoadElement("HudPlayerClass", "resource/ui/hudplayerclass.res");
			VGui_LoadElement("HudPlayerHealth", "resource/ui/hudplayerhealth.res");
			VGui_LoadElement("HudWeaponAmmo", "resource/ui/hudammoweapons.res");
			VGui_LoadElement("HudMatchStatus", "resource/ui/hudmatchstatus.res");
			/* TF2's time panel fills itself from its own file */
			VGui_LoadElement("HudMatchStatus/ObjectiveStatusTimePanel", "resource/ui/hudobjectivetimepanel.res");
			VGui_LoadElement("HudKothTimeStatus", "resource/ui/hudobjectivekothtimepanel.res");
		}
	}

	return (g_tfvgAvailable);
}

/** The local player's class, as "soldier". */
static string
TFVGui_ClassName(void)
{
	return getplayerkeyvalue(player_localnum, "*tf_class");
}

/* the health cross, filled from the bottom as health drops */
static void
TFVGui_DrawHealthCross(vector crossPos, vector crossSize, vector crossColor, float fillFraction)
{
	float armWidth = crossSize[0] / 3;
	vector barPos = crossPos + [0, armWidth];
	vector barSize = [crossSize[0], armWidth];
	vector postPos = crossPos + [armWidth, 0];
	vector postSize = [armWidth, crossSize[1]];
	float clipTop = crossPos[1] + crossSize[1] * (1 - bound(0, fillFraction, 1));

	drawsetcliparea(crossPos[0], clipTop, crossSize[0], crossSize[1]);
	drawfill(barPos, barSize, crossColor, 1, DRAWFLAG_NORMAL);
	drawfill(postPos, postSize, crossColor, 1, DRAWFLAG_NORMAL);
	drawresetcliparea();
}

static void
TFVGui_DrawClass(void)
{
	string className = TFVGui_ClassName();

	/* TF2 draws the class's 3D model here; REDUX's class art stands in */
	VGui_Show("HudPlayerClass", "PlayerStatusSpyImage", false);

	if (STRING_SET(className)) {
		VGui_Show("HudPlayerClass", "PlayerStatusClassImage", true);
		VGui_Override("HudPlayerClass", "PlayerStatusClassImage", "image", sprintf("replay/thumbnails/characters/%s_sepia", className));
		VGui_Override("HudPlayerClass", "PlayerStatusClassImage", "wide", "70");
		VGui_Override("HudPlayerClass", "PlayerStatusClassImage", "tall", "100");
		VGui_Override("HudPlayerClass", "PlayerStatusClassImage", "ypos", "r100");
	} else {
		VGui_Show("HudPlayerClass", "PlayerStatusClassImage", false);
	}

	VGui_DrawElement("HudPlayerClass", 1.0f);
}

static void
TFVGui_DrawHealth(void)
{
	float healthValue = max(0, player.GetHealth());
	float maxHealth = getplayerkeyfloat(player_localnum, "*maxhp");

	if (maxHealth <= 0) {
		maxHealth = 100;
	}

	VGui_SetVar("HudPlayerHealth", "Health", ftos(healthValue));
	VGui_SetVar("HudPlayerHealth", "MaxHealth", ftos(maxHealth));

	/* TF2 shows the maximum only while hurt, and the status icons only
	   with their conditions */
	bool isHurt = (healthValue < maxHealth);
	VGui_Show("HudPlayerHealth", "PlayerStatusMaxHealthValue", isHurt);
	VGui_Show("HudPlayerHealth", "PlayerStatusMaxHealthValueShadow", isHurt);
	VGui_Show("HudPlayerHealth", "PlayerStatusHealthImage", false);
	VGui_Show("HudPlayerHealth", "PlayerStatusHealthImageBG", false);
	VGui_Show("HudPlayerHealth", "PlayerStatusHealthBonusImage", false);
	VGui_Show("HudPlayerHealth", "PlayerStatusHealthValueTextFill", healthValue >= 1000);

	int panelCount = VGui_ChildCount("HudPlayerHealth");

	for (int i = 0; i < panelCount; i++) {
		string panelName = VGui_Child("HudPlayerHealth", i);
		string lowerName = strtolower(panelName);

		/* bleeding, milk, jarate, buffs, ...: none of them are tracked yet */
		if (substring(lowerName, 0, 12) == "playerstatus" && strstrofs(lowerName, "health") < 0 && strstrofs(lowerName, "anchor") < 0) {
			VGui_Show("HudPlayerHealth", panelName, false);
		}
	}

	VGui_DrawElement("HudPlayerHealth", 1.0f);

	/* the cross, where TF2's health image panels sit */
	vector elementSize;
	vector elementPos = VGui_ElementRect("HudPlayerHealth", elementSize);
	vector crossSize;
	vector crossPos = VGui_PanelRect("HudPlayerHealth", "PlayerStatusHealthImageBG", elementPos, elementSize, crossSize);
	float warnAlpha = 1;
	float bgAlpha;
	vector darkColor = VGui_Color("TanDarker", bgAlpha);
	vector lightColor = VGui_Color("TanLight", warnAlpha);

	TFVGui_DrawHealthCross(crossPos, crossSize, darkColor, 1.0f);
	crossPos = VGui_PanelRect("HudPlayerHealth", "PlayerStatusHealthImage", elementPos, elementSize, crossSize);

	/* the cross flashes red near death, like HUDDeathWarning */
	if (healthValue < maxHealth * 0.49) {
		float pulse = 0.5 + 0.5 * sin(time * 8);
		lightColor = lightColor * (1 - pulse) + [1, 0.2, 0.2] * pulse;
	}

	TFVGui_DrawHealthCross(crossPos, crossSize, lightColor, healthValue / maxHealth);
}

static void
TFVGui_DrawAmmo(void)
{
	if (weapon.AmmoRequired() == false) {
		return;
	}

	int clipSize = weapon.GetClipSize();
	bool usesClip = (clipSize > 0i);

	if (usesClip) {
		VGui_SetVar("HudWeaponAmmo", "Ammo", itos(weapon.GetClip()));
		VGui_SetVar("HudWeaponAmmo", "AmmoInReserve", itos(weapon.GetAmmo1()));
	} else {
		VGui_SetVar("HudWeaponAmmo", "Ammo", itos(weapon.GetAmmo1()));
	}

	VGui_Show("HudWeaponAmmo", "AmmoInClip", usesClip);
	VGui_Show("HudWeaponAmmo", "AmmoInClipShadow", usesClip);
	VGui_Show("HudWeaponAmmo", "AmmoInReserve", usesClip);
	VGui_Show("HudWeaponAmmo", "AmmoInReserveShadow", usesClip);
	VGui_Show("HudWeaponAmmo", "AmmoNoClip", !usesClip);
	VGui_Show("HudWeaponAmmo", "AmmoNoClipShadow", !usesClip);
	VGui_DrawElement("HudWeaponAmmo", 1.0f);
}

/* draws one panel of an element and what's in it */
static void
TFVGui_DrawPanel(string elementName, string panelName)
{
	vector elementSize;
	vector elementPos = VGui_ElementRect(elementName, elementSize);
	vector panelSize;
	vector panelPos = VGui_PanelRect(elementName, panelName, elementPos, elementSize, panelSize);
	VGui_DrawChildren(sprintf("%s/%s", elementName, panelName), panelPos, panelSize, 1.0f);
}

/* the round clock, its setup and waiting notes, and KOTH's two clocks */
static void
TFVGui_DrawTimer(void)
{
	string modeName = serverinfo.GetString("tf_mode");

	if (!STRING_SET(modeName)) {
		return;
	}

	float roundState = serverinfo.GetFloat("tf_round");
	float timeLeft = serverinfo.GetFloat("tf_timer");

	/* KOTH's team clocks take the round clock's place once the point
	   unlocks (the round clock stays at 0 after) */
	if (modeName == "koth" && timeLeft <= 0) {
		tokenize_console(serverinfo.GetString("tf_koth"));
		VGui_Override("HudKothTimeStatus", "RedTimer/TimePanelValue", "labeltext", TFHUD_Clock(stof(argv(0))));
		VGui_Override("HudKothTimeStatus", "BlueTimer/TimePanelValue", "labeltext", TFHUD_Clock(stof(argv(1))));
		VGui_DrawElement("HudKothTimeStatus", 1.0f);
	}

	string timePanel = "HudMatchStatus/ObjectiveStatusTimePanel";
	bool isSetup = (roundState == TFROUND_SETUP);
	bool isWaiting = (roundState == TFROUND_WAITING);
	bool showClock = (modeName == "koth") ? (timeLeft > 0) : (timeLeft >= 0);

	if (!showClock && !isWaiting) {
		return;
	}

	VGui_Show(timePanel, "TimerBox", showClock);
	VGui_Show(timePanel, "TimePanelProgressBar", showClock);
	VGui_Show(timePanel, "TimePanelValue", showClock);
	VGui_Override("HudMatchStatus", "ObjectiveStatusTimePanel/TimePanelValue", "labeltext", TFHUD_Clock(timeLeft));
	VGui_Show(timePanel, "SetupLabel", isSetup);
	VGui_Show(timePanel, "SetupBG", isSetup);
	VGui_Override(timePanel, "SetupLabel", "labeltext", "Setup");
	VGui_Show(timePanel, "WaitingForPlayersLabel", isWaiting);
	VGui_Show(timePanel, "WaitingForPlayersBG", isWaiting);
	VGui_Override(timePanel, "WaitingForPlayersLabel", "labeltext", "Waiting for Players");
	VGui_Show(timePanel, "OvertimeLabel", false);
	VGui_Show(timePanel, "SuddenDeathLabel", false);
	VGui_Show(timePanel, "SuddenDeathBG", false);
	VGui_Show(timePanel, "ServerTimeLimitLabel", false);
	VGui_Show(timePanel, "ServerTimeLimitLabelBG", false);
	TFVGui_DrawPanel("HudMatchStatus", "ObjectiveStatusTimePanel");
}

/** Draws the player's status elements. */
void
TFVGui_Draw(void)
{
	VGui_BeginFrame();
	TFVGui_DrawTimer();

	float localTeam = getplayerkeyfloat(player_localnum, "*team");
	g_vgTeam = (localTeam == TF_TEAM_BLU) ? 3 : 2;

	if (getplayerkeyfloat(player_localnum, "*dead") != 0) {
		return;
	}

	TFVGui_DrawClass();
	TFVGui_DrawHealth();
	TFVGui_DrawAmmo();
}
