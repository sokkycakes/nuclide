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

/** @file tf_vguiobjectives.qc
The objective panels of a TF2 HUD (see tf_vguihud.qc): the control point
icons, the CTF flag and score panel and the payload cart's track, filled
from the rules' tf_obj, tf_caps and tf_mode serverinfo keys (see tf_hud.qc).
Where the HUD leans on TF2's own pictures, which aren't in the pack, the
HUD's octagon and icon art stands in.
*/

/** Loads the objective panels' files. */
void
TFVGui_LoadObjectives(void)
{
	VGui_LoadElement("ObjectiveStatusFlagPanel", "resource/ui/hudobjectiveflagpanel.res");
	VGui_LoadElement("ObjectiveStatusFlagPanel/BlueFlag", "resource/ui/flagstatus.res");
	VGui_LoadElement("ObjectiveStatusFlagPanel/RedFlag", "resource/ui/flagstatus.res");
	VGui_LoadElement("ObjectiveStatusEscort", "resource/ui/objectivestatusescort.res");
}

static string
TFVGui_TeamWord(float teamID)
{
	if (teamID == TF_TEAM_RED) {
		return ("red");
	} else if (teamID == TF_TEAM_BLU) {
		return ("blu");
	}

	return ("neutral");
}

/* one control point icon: the owner's octagon, the lock, and the
   capturing team's colour rising from the bottom */
static void
TFVGui_DrawPointIcon(vector iconPos, float iconSize, float owner, float capTeam, float progress, float locked, float contested)
{
	string iconName = strcat("replay/thumbnails/cp_icons/icon_obj_", TFVGui_TeamWord(owner));

	if (locked) {
		iconName = strcat(iconName, "_locked");
	}

	VGui_DrawImage(iconName, iconPos, [iconSize, iconSize], [1, 1, 1], 1.0f);

	if (capTeam == TF_TEAM_NONE || progress <= 0) {
		return;
	}

	/* the octagon's inside, under its outline */
	float insetSize = iconSize * 0.1f;
	vector innerPos = iconPos + [insetSize, insetSize];
	float innerSize = iconSize - insetSize * 2;
	float fillTop = innerPos[1] + innerSize * (1 - progress / 100);
	float fillAlpha = 0.85f;

	/* blocked: the bar flashes, as TF2's does */
	if (contested) {
		fillAlpha = 0.45f + 0.4f * fabs(sin(time * 6));
	}

	drawsetcliparea(innerPos[0], fillTop, innerSize, innerPos[1] + innerSize - fillTop);
	VGui_DrawImage(strcat("replay/thumbnails/cp_icons/icon_obj_cap_", TFVGui_TeamWord(capTeam)), innerPos, [innerSize, innerSize], [1, 1, 1], fillAlpha);
	drawresetcliparea();
}

/* the row of control point icons, centred, with its bottom at bottomY */
static void
TFVGui_DrawPointRow(string objectives, float bottomY, float iconUnits)
{
	int tokenCount = tokenize_console(objectives);
	int pointCount = 0;

	for (int i = 0; i < tokenCount; i++) {
		if (substring(argv(i), 0, 1) == "p") {
			pointCount++;
		}
	}

	if (pointCount == 0) {
		return;
	}

	float iconSize = iconUnits * g_vgScale;
	float gapSize = stof(VGui_Get("hudlayout/HudControlPointIcons/separator_width")) * g_vgScale;
	float rowWidth = pointCount * iconSize + (pointCount - 1) * gapSize;
	vector iconPos = g_vgScreenMins + [(g_vgScreenSize[0] - rowWidth) / 2, bottomY - iconSize];

	for (int i = 0; i < tokenCount; i++) {
		tokenCount = tokenize_console(objectives);
		string token = argv(i);

		if (substring(token, 0, 1) != "p") {
			continue;
		}

		/* index:owner:capTeam:progress:locked:contested */
		tokenizebyseparator(substring(token, 1, -1), ":");
		TFVGui_DrawPointIcon(iconPos, iconSize, stof(argv(1)), stof(argv(2)), stof(argv(3)), stof(argv(4)), stof(argv(5)));
		iconPos[0] += iconSize + gapSize;
	}
}

/* CTF: the scores either side, each flag's state in the middle */
static void
TFVGui_DrawFlagPanel(string objectives)
{
	string flagPanel = "ObjectiveStatusFlagPanel";
	tokenize_console(serverinfo.GetString("tf_caps"));
	VGui_SetVar(flagPanel, "redscore", argv(0));
	VGui_SetVar(flagPanel, "bluescore", argv(1));

	/* the rules don't publish a capture limit */
	VGui_Show(flagPanel, "PlayingToColoredLabel", false);
	VGui_DrawElement(flagPanel, 1.0f);

	vector elementSize;
	vector elementPos = VGui_ElementRect(flagPanel, elementSize);
	int tokenCount = tokenize_console(objectives);

	for (int i = 0; i < tokenCount; i++) {
		tokenCount = tokenize_console(objectives);
		string token = argv(i);

		if (substring(token, 0, 1) != "f") {
			continue;
		}

		float flagTeam = stof(substring(token, 1, 1));
		float flagState = stof(substring(token, 2, 1));
		string flagName = (flagTeam == TF_TEAM_BLU) ? "BlueFlag" : "RedFlag";
		vector flagSize;
		vector flagPos = VGui_PanelRect(flagPanel, flagName, elementPos, elementSize, flagSize);
		vector iconSize;
		vector iconPos = VGui_PanelRect(strcat(flagPanel, "/", flagName), "StatusIcon", flagPos, flagSize, iconSize);
		float iconAlpha = 1.0f;

		/* home: the team's octagon; taken: faded with the alert sign;
		   dropped: blinking */
		if (flagState == TFFLAG_CARRIED) {
			iconAlpha = 0.4f;
		} else if (flagState == TFFLAG_DROPPED) {
			iconAlpha = 0.4f + 0.6f * fabs(sin(time * 4));
		}

		VGui_DrawImage(strcat("replay/thumbnails/bgshapes/shapes_octagon_bg_", TFVGui_TeamWord(flagTeam)), iconPos, iconSize, [1, 1, 1], iconAlpha);

		if (flagState == TFFLAG_CARRIED) {
			VGui_DrawImage("replay/thumbnails/icons/alert", iconPos + iconSize * 0.15f, iconSize * 0.7f, [1, 1, 1], 1.0f);
		}
	}
}

/* payload: the track, how far the cart got, and who's pushing it */
static void
TFVGui_DrawEscort(string objectives)
{
	string escortPanel = "ObjectiveStatusEscort";
	string itemPanel = "ObjectiveStatusEscort/EscortItemPanel";
	int tokenCount = tokenize_console(objectives);
	string cartToken = "";

	for (int i = 0; i < tokenCount; i++) {
		if (substring(argv(i), 0, 1) == "c") {
			cartToken = argv(i);
			break;
		}
	}

	if (!STRING_SET(cartToken)) {
		return;
	}

	/* pushTeam:progress:pushers:state */
	tokenizebyseparator(substring(cartToken, 1, -1), ":");
	float pushTeam = stof(argv(0));
	float cartProgress = bound(0, stof(argv(1)) / 100, 1);
	float pusherCount = stof(argv(2));
	float cartState = stof(argv(3));

	/* the item panel's marker sits 220 units in, so move the panel to
	   put it over the cart's spot on the track */
	float trackStart = stof(VGui_Get("ObjectiveStatusEscort/SolarLevelBar/xpos"));
	float trackWidth = stof(VGui_Get("ObjectiveStatusEscort/SolarLevelBar/wide"));
	float markerOffset = stof(VGui_Get("ObjectiveStatusEscort/EscortItemPanel/SolarProgressBar/wide"));
	VGui_Override(escortPanel, "EscortItemPanel", "xpos", ftos(trackStart + trackWidth * cartProgress - markerOffset));

	/* the trail behind the cart is drawn here, clipped to the track */
	VGui_Show(itemPanel, "SolarProgressBar", false);
	VGui_Show(itemPanel, "RecedeTime", false);
	VGui_Show(itemPanel, "RecedeTime2", false);
	VGui_Show(itemPanel, "CapNumPlayers", true);
	VGui_Override(itemPanel, "CapNumPlayers", "labeltext", (cartState == TFCART_PUSHED) ? ftos(pusherCount) : " ");
	VGui_Show(itemPanel, "Blocked", cartState == TFCART_BLOCKED);
	VGui_Override(itemPanel, "Blocked", "image", "replay/thumbnails/icons/alert");
	VGui_Show(itemPanel, "Speed_Backwards", cartState == TFCART_RECEDING);

	vector elementSize;
	vector elementPos = VGui_ElementRect(escortPanel, elementSize);
	vector trackSize;
	vector trackPos = VGui_PanelRect(escortPanel, "SolarLevelBar", elementPos, elementSize, trackSize);
	float trailAlpha;
	vector trailColor = VGui_Color((pushTeam == TF_TEAM_RED) ? "SolarTeamRED" : "SolarTeamBLU", trailAlpha);

	VGui_DrawElement(escortPanel, 1.0f);
	drawfill(trackPos, [trackSize[0] * cartProgress, trackSize[1]], trailColor, trailAlpha, DRAWFLAG_NORMAL);
}

/** Draws the objective panels for the current mode. */
void
TFVGui_DrawObjectives(void)
{
	string modeName = serverinfo.GetString("tf_mode");
	string objectives = serverinfo.GetString("tf_obj");
	float iconUnits = 33;

	if (modeName == "ctf") {
		TFVGui_DrawFlagPanel(objectives);
	} else if (modeName == "pl") {
		/* the checkpoints, small, above the cart's track */
		TFVGui_DrawEscort(objectives);
		vector elementSize;
		vector elementPos = VGui_ElementRect("ObjectiveStatusEscort", elementSize);
		vector trackSize;
		vector trackPos = VGui_PanelRect("ObjectiveStatusEscort", "SolarLevelBar", elementPos, elementSize, trackSize);
		TFVGui_DrawPointRow(objectives, trackPos[1] - 28 * g_vgScale, 20);
	} else {
		/* control points and KOTH: along the bottom, like TF2 */
		TFVGui_DrawPointRow(objectives, g_vgScreenMins[1] + g_vgScreenSize[1] - (stof(VGui_Get("hudlayout/HudControlPointIcons/height_offset")) + 6) * g_vgScale, iconUnits);
	}
}
