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

/** @file tf_hud.qc
The objective strip at the top of the screen. Everything comes from
serverinfo keys the rules publish, so the HUD needs no networked entities:
- tf_mode: ctf, cp or koth
- tf_round: round state (TFROUND_*)
- tf_timer: seconds left on the round (or until the KOTH point unlocks), -1 for none
- tf_obj: objective summary, see TF_ObjectiveSummary() in server/tf_api.qc
- tf_caps: CTF captures "red blu"; tf_koth: KOTH clocks "red blu"; tf_wins: rounds won
*/

font_s FONT_TF;
bool g_tfHUDInit;

vector
TFHUD_TeamColor(float teamID)
{
	if (teamID == TF_TEAM_RED) {
		return [0.85, 0.2, 0.2];
	} else if (teamID == TF_TEAM_BLU) {
		return [0.25, 0.45, 0.9];
	}

	return [0.5, 0.5, 0.5];
}

string
TFHUD_Clock(float seconds)
{
	seconds = max(0, seconds);
	return sprintf("%d:%02d", floor(seconds / 60), floor(seconds) % 60);
}

void
TFHUD_CenteredText(vector centerPos, string text, vector textColor)
{
	float textWidth = font.StringWidth(text, true, FONT_TF);
	draw.Text_RGB(centerPos - [textWidth / 2, 0], text, textColor, FONT_TF);
}

void
TFHUD_DrawPoint(vector boxPos, float owner, float capTeam, float progress, float locked, float contested)
{
	vector boxSize = [40, 40];

	draw.Rect(boxPos, boxSize, TFHUD_TeamColor(owner), 0.8f);

	if (capTeam != TF_TEAM_NONE && progress > 0) {
		draw.Rect(boxPos + [0, boxSize[1] - 6], [boxSize[0] * (progress / 100), 6], TFHUD_TeamColor(capTeam), 1.0f);
	}

	draw.RectOutline(boxPos, boxSize, 1.0f, contested ? [1, 1, 0] : [0, 0, 0], 1.0f);

	if (locked) {
		TFHUD_CenteredText(boxPos + [boxSize[0] / 2, 12], "L", [1, 1, 1]);
	} else if (contested) {
		TFHUD_CenteredText(boxPos + [boxSize[0] / 2, 12], "!", [1, 1, 0]);
	}
}

void
TFHUD_DrawFlag(vector boxPos, float flagTeam, float flagState, float caps)
{
	vector boxSize = [72, 40];
	string stateText = "HOME";

	if (flagState == TFFLAG_CARRIED) {
		stateText = "TAKEN";
	} else if (flagState == TFFLAG_DROPPED) {
		stateText = "DROPPED";
	}

	draw.Rect(boxPos, boxSize, TFHUD_TeamColor(flagTeam), (flagState == TFFLAG_HOME) ? 0.8f : 0.35f);
	draw.RectOutline(boxPos, boxSize, 1.0f, [0, 0, 0], 1.0f);
	TFHUD_CenteredText(boxPos + [boxSize[0] / 2, 4], sprintf("%d", caps), [1, 1, 1]);
	TFHUD_CenteredText(boxPos + [boxSize[0] / 2, 22], stateText, [1, 1, 1]);
}

void
TFHUD_Draw(void)
{
	string modeName = serverinfo.GetString("tf_mode");

	if (!STRING_SET(modeName)) {
		return;
	}

	if (g_tfHUDInit == false) {
		font.Load("fonts/font16.font", FONT_TF);
		g_tfHUDInit = true;
	}

	vector hudMins = screen.HUDMins();
	vector hudSize = screen.HUDSize();
	vector topCenter = hudMins + [hudSize[0] / 2, 8];
	float roundState = serverinfo.GetFloat("tf_round");
	float timeLeft = serverinfo.GetFloat("tf_timer");
	string objectives = serverinfo.GetString("tf_obj");

	/* timer or round state */
	string headline = "";

	switch (roundState) {
	case TFROUND_WAITING:
		headline = "Waiting for players";
		break;
	case TFROUND_PREROUND:
		headline = "Get ready";
		break;
	case TFROUND_SETUP:
		headline = sprintf("Setup %s", TFHUD_Clock(timeLeft));
		break;
	case TFROUND_WIN:
		headline = "Round over";
		break;
	case TFROUND_STALEMATE:
		headline = "Stalemate";
		break;
	default:
		headline = (timeLeft >= 0) ? TFHUD_Clock(timeLeft) : "";
	}

	if (STRING_SET(headline)) {
		TFHUD_CenteredText(topCenter, headline, [1, 1, 1]);
	}

	/* objectives: count them first so the row is centred */
	int tokenCount = tokenize_console(objectives);
	float shown = 0;

	for (int i = 0; i < tokenCount; i++) {
		string kind = substring(argv(i), 0, 1);

		if (kind == "p" || kind == "f") {
			shown++;
		}
	}

	float itemWidth = (modeName == "ctf") ? 80 : 48;
	vector rowPos = topCenter + [-(shown * itemWidth) / 2, 24];
	string caps = serverinfo.GetString("tf_caps");

	for (int i = 0; i < tokenCount; i++) {
		tokenCount = tokenize_console(objectives);
		string token = argv(i);
		string kind = substring(token, 0, 1);

		if (kind == "f") {
			float flagTeam = stof(substring(token, 1, 1));
			float flagState = stof(substring(token, 2, 1));
			tokenize_console(caps);
			TFHUD_DrawFlag(rowPos, flagTeam, flagState, stof(argv(flagTeam - 1)));
			rowPos[0] += itemWidth;
		} else if (kind == "p") {
			tokenizebyseparator(substring(token, 1, -1), ":");
			TFHUD_DrawPoint(rowPos, stof(argv(1)), stof(argv(2)), stof(argv(3)), stof(argv(4)), stof(argv(5)));
			rowPos[0] += itemWidth;
		}
	}

	/* KOTH clocks either side of the point */
	if (modeName == "koth") {
		tokenize_console(serverinfo.GetString("tf_koth"));
		string redClock = TFHUD_Clock(stof(argv(0)));
		string bluClock = TFHUD_Clock(stof(argv(1)));
		draw.RText_RGB(topCenter + [-40, 36], redClock, TFHUD_TeamColor(TF_TEAM_RED), FONT_TF);
		draw.Text_RGB(topCenter + [40, 36], bluClock, TFHUD_TeamColor(TF_TEAM_BLU), FONT_TF);
	}
}

/* ---- nameplates and weapon meter ---------------------------------------- */

/** Team a disguised spy shows as, or 0 when they aren't disguised. */
float
TFHUD_DisguiseTeam(float playerSlot)
{
	string disguiseInfo = getplayerkeyvalue(playerSlot, "*tf_disguise");

	if (!STRING_SET(disguiseInfo)) {
		return (0);
	}

	tokenize_console(disguiseInfo);
	return stof(argv(0));
}

/** Nameplates callback: teammates, plus enemy spies disguised as our team,
so a disguise fools the plates too. */
bool
TFHUD_PlateIsFriendly(entity targetEnt)
{
	float playerSlot = Nameplates_PlayerSlot(targetEnt);

	if (Nameplates_DefaultIsFriendly(targetEnt)) {
		return (true);
	}

	if (playerSlot < 0 || targetEnt.entnum == player_localentnum) {
		return (false);
	}

	if (getplayerkeyfloat(playerSlot, "*dead") != 0) {
		return (false);
	}

	float ourTeam = getplayerkeyfloat(player_localnum, "*team");
	return (ourTeam > 0 && TFHUD_DisguiseTeam(playerSlot) == ourTeam);
}

/** Nameplates callback: a disguised enemy spy borrows the name of one of
our teammates, like TF2. */
string
TFHUD_PlateName(entity targetEnt)
{
	float playerSlot = Nameplates_PlayerSlot(targetEnt);
	float ourTeam = getplayerkeyfloat(player_localnum, "*team");

	if (playerSlot >= 0 && getplayerkeyfloat(playerSlot, "*team") != ourTeam) {
		for (float i = 0; i < maxclients; i++) {
			if (i != player_localnum && i != playerSlot && getplayerkeyfloat(i, "*team") == ourTeam) {
				string borrowedName = getplayerkeyvalue(i, "name");

				if (STRING_SET(borrowedName)) {
					return (borrowedName);
				}
			}
		}
	}

	return Nameplates_DefaultName(targetEnt);
}

/** The weapon or ability meter the server publishes in "*tf_meter"
(stickies, minigun spin, sniper charge, ubercharge, cloak, metal), drawn
above the ammo counter. */
void
TFHUD_DrawMeter(void)
{
	string meterText = getplayerkeyvalue(player_localnum, "*tf_meter");

	if (!STRING_SET(meterText) || getplayerkeyfloat(player_localnum, "*dead") != 0) {
		return;
	}

	if (g_tfHUDInit == false) {
		font.Load("fonts/font16.font", FONT_TF);
		g_tfHUDInit = true;
	}

	vector hudMins = screen.HUDMins();
	vector hudSize = screen.HUDSize();
	TFHUD_CenteredText(hudMins + [hudSize[0] / 2, hudSize[1] - 72], meterText, [1, 0.85, 0.4]);
}
