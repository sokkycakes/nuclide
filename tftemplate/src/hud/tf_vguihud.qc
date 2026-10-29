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
			TFVGui_LoadObjectives();
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

/* ---- kill feed ---------------------------------------------------------- */

#define TFVGUI_NOTICES 8
#define TFVGUI_NOTICE_TIME 6.0f

string g_tfvgNoticeKiller[TFVGUI_NOTICES];
string g_tfvgNoticeVictim[TFVGUI_NOTICES];
string g_tfvgNoticeWeapon[TFVGUI_NOTICES];
float g_tfvgNoticeKillerTeam[TFVGUI_NOTICES];
float g_tfvgNoticeVictimTeam[TFVGUI_NOTICES];
float g_tfvgNoticeTime[TFVGUI_NOTICES];
int g_tfvgNoticeCount;

/* a player's team by name, 0 when nobody has that name */
static float
TFVGui_TeamOfName(string playerName)
{
	for (int i = 0; i < maxclients; i++) {
		if (getplayerkeyvalue(i, "name") == playerName) {
			return getplayerkeyfloat(i, "*team");
		}
	}

	return (0);
}

/** Adds a kill to the feed, as TF2's HudDeathNotice lists them. */
void
TFVGui_AddDeathNotice(string victimName, string killerName, string weaponDef, string meansOfDeath)
{
	/* oldest out when it's full */
	if (g_tfvgNoticeCount >= TFVGUI_NOTICES) {
		for (int i = 0; i < TFVGUI_NOTICES - 1; i++) {
			g_tfvgNoticeKiller[i] = g_tfvgNoticeKiller[i + 1];
			g_tfvgNoticeVictim[i] = g_tfvgNoticeVictim[i + 1];
			g_tfvgNoticeWeapon[i] = g_tfvgNoticeWeapon[i + 1];
			g_tfvgNoticeKillerTeam[i] = g_tfvgNoticeKillerTeam[i + 1];
			g_tfvgNoticeVictimTeam[i] = g_tfvgNoticeVictimTeam[i + 1];
			g_tfvgNoticeTime[i] = g_tfvgNoticeTime[i + 1];
		}

		g_tfvgNoticeCount = TFVGUI_NOTICES - 1;
	}

	int newIndex = g_tfvgNoticeCount;
	bool isSuicide = (wordInString(meansOfDeath, "self") || !STRING_SET(killerName) || killerName == victimName);

	/* TF2 shows a kill icon between the names; the weapon's name stands in */
	string weaponName = STRING_SET(weaponDef) ? entityDef.GetString(weaponDef, "inv_name") : "";

	if (!STRING_SET(weaponName)) {
		weaponName = isSuicide ? "died" : "killed";
	}

	g_tfvgNoticeKiller[newIndex] = isSuicide ? "" : strzone(killerName);
	g_tfvgNoticeVictim[newIndex] = strzone(victimName);
	g_tfvgNoticeWeapon[newIndex] = strzone(weaponName);
	g_tfvgNoticeKillerTeam[newIndex] = TFVGui_TeamOfName(killerName);
	g_tfvgNoticeVictimTeam[newIndex] = TFVGui_TeamOfName(victimName);
	g_tfvgNoticeTime[newIndex] = time + TFVGUI_NOTICE_TIME;
	g_tfvgNoticeCount++;
}

static vector
TFVGui_NoticeTeamColor(float teamID, __out float colorAlpha)
{
	string colorKey = "hudlayout/HudDeathNotice/TeamRed";

	if (teamID == TF_TEAM_BLU) {
		colorKey = "hudlayout/HudDeathNotice/TeamBlue";
	} else if (teamID != TF_TEAM_RED) {
		return VGui_Color(VGui_Get("hudlayout/HudDeathNotice/IconColor"), colorAlpha);
	}

	return VGui_Color(VGui_Get(colorKey), colorAlpha);
}

/* the feed, newest at the bottom, right-aligned at the top right */
static void
TFVGui_DrawDeathNotices(void)
{
	/* drop the expired ones from the top */
	while (g_tfvgNoticeCount > 0 && g_tfvgNoticeTime[0] < time) {
		for (int i = 0; i < g_tfvgNoticeCount - 1; i++) {
			g_tfvgNoticeKiller[i] = g_tfvgNoticeKiller[i + 1];
			g_tfvgNoticeVictim[i] = g_tfvgNoticeVictim[i + 1];
			g_tfvgNoticeWeapon[i] = g_tfvgNoticeWeapon[i + 1];
			g_tfvgNoticeKillerTeam[i] = g_tfvgNoticeKillerTeam[i + 1];
			g_tfvgNoticeVictimTeam[i] = g_tfvgNoticeVictimTeam[i + 1];
			g_tfvgNoticeTime[i] = g_tfvgNoticeTime[i + 1];
		}

		g_tfvgNoticeCount--;
	}

	if (g_tfvgNoticeCount <= 0) {
		return;
	}

	string settings = "hudlayout/HudDeathNotice/";
	string textFont = VGui_Get(strcat(settings, "TextFont"));
	float lineHeight = stof(VGui_Get(strcat(settings, "LineHeight"))) * g_vgScale;
	float lineSpacing = stof(VGui_Get(strcat(settings, "LineSpacing"))) * g_vgScale;
	int maxNotices = (int)stof(VGui_Get(strcat(settings, "MaxDeathNotices")));
	bool rightJustify = (stof(VGui_Get(strcat(settings, "RightJustify"))) != 0);
	float baseAlpha, localAlpha, iconAlpha, localTextAlpha;
	vector baseColor = VGui_Color(VGui_Get(strcat(settings, "BaseBackgroundColor")), baseAlpha);
	vector localColor = VGui_Color(VGui_Get(strcat(settings, "LocalBackgroundColor")), localAlpha);
	vector iconColor = VGui_Color(VGui_Get(strcat(settings, "IconColor")), iconAlpha);
	vector localTextColor = VGui_Color(VGui_Get(strcat(settings, "LocalPlayerColor")), localTextAlpha);
	string localName = getplayerkeyvalue(player_localnum, "name");
	float textHeight = VGui_FontHeight(textFont);
	float padSize = 4 * g_vgScale;
	vector elementSize;
	vector elementPos = VGui_ElementRect("HudDeathNotice", elementSize);
	int firstNotice = 0;

	if (maxNotices <= 0) {
		maxNotices = 4;
	}

	if (g_tfvgNoticeCount > maxNotices) {
		firstNotice = g_tfvgNoticeCount - maxNotices;
	}

	vector linePos = elementPos;

	for (int i = firstNotice; i < g_tfvgNoticeCount; i++) {
		string killerName = g_tfvgNoticeKiller[i];
		string victimName = g_tfvgNoticeVictim[i];
		string weaponName = g_tfvgNoticeWeapon[i];
		float killerWidth = STRING_SET(killerName) ? VGui_TextWidth(textFont, killerName) + padSize : 0;
		float weaponWidth = VGui_TextWidth(textFont, weaponName);
		float victimWidth = VGui_TextWidth(textFont, victimName);
		float lineWidth = padSize + killerWidth + weaponWidth + padSize + victimWidth + padSize;
		bool isLocal = (killerName == localName || victimName == localName);
		float textY = linePos[1] + (lineHeight - textHeight) / 2;
		float x = rightJustify ? elementPos[0] + elementSize[0] - lineWidth : elementPos[0];
		float killerAlpha, victimAlpha;
		vector killerColor = TFVGui_NoticeTeamColor(g_tfvgNoticeKillerTeam[i], killerAlpha);
		vector victimColor = TFVGui_NoticeTeamColor(g_tfvgNoticeVictimTeam[i], victimAlpha);

		/* lines with the local player in them stand out, as in TF2 */
		if (isLocal) {
			drawfill([x, linePos[1]], [lineWidth, lineHeight], localColor, localAlpha, DRAWFLAG_NORMAL);
		} else {
			drawfill([x, linePos[1]], [lineWidth, lineHeight], baseColor, baseAlpha, DRAWFLAG_NORMAL);
		}

		x += padSize;

		if (STRING_SET(killerName)) {
			VGui_DrawText(textFont, [x, textY], killerName, killerColor, 1.0f);
			x += killerWidth;
		}

		VGui_DrawText(textFont, [x, textY], weaponName, isLocal ? localTextColor : iconColor, 1.0f);
		x += weaponWidth + padSize;
		VGui_DrawText(textFont, [x, textY], victimName, victimColor, 1.0f);
		linePos[1] += lineHeight + lineSpacing;
	}
}

/* ---- the whole HUD ------------------------------------------------------- */

/** Draws what everyone sees, alive, dead or spectating: the clock, the
objectives and the kill feed. */
void
TFVGui_DrawShared(void)
{
	VGui_BeginFrame();

	float localTeam = getplayerkeyfloat(player_localnum, "*team");
	g_vgTeam = (localTeam == TF_TEAM_BLU) ? 3 : 2;

	TFVGui_DrawTimer();
	TFVGui_DrawObjectives();
	TFVGui_DrawDeathNotices();
}

/** Draws the whole HUD for a playing client. */
void
TFVGui_Draw(void)
{
	TFVGui_DrawShared();

	if (getplayerkeyfloat(player_localnum, "*dead") != 0) {
		return;
	}

	TFVGui_DrawClass();
	TFVGui_DrawHealth();
	TFVGui_DrawAmmo();
}
