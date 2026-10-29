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
- tf_mode: ctf, cp, koth or pl
- tf_round: round state (TFROUND_*)
- tf_timer: seconds left on the round (or until the KOTH point unlocks), -1 for none
- tf_obj: objective summary, see TF_ObjectiveSummary() in server/tf_api.qc
- tf_caps: CTF captures "red blu"; tf_koth: KOTH clocks "red blu"; tf_wins: rounds won
*/

font_s FONT_TF;
bool g_tfHUDInit;
bool TFVGui_Active(void);

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

/** The cart's progress bar: filled to `progress` percent in the pushing
team's colour, with the pusher count, a stop sign when the defenders block
it and an arrow back while it rolls back. */
void
TFHUD_DrawCart(vector barPos, float pushTeam, float progress, float pushers, float cartState)
{
	vector barSize = [240, 12];
	string stateText = "";

	draw.Rect(barPos, barSize, [0.15, 0.15, 0.15], 0.8f);
	draw.Rect(barPos, [barSize[0] * (progress / 100), barSize[1]], TFHUD_TeamColor(pushTeam), 1.0f);
	draw.RectOutline(barPos, barSize, 1.0f, [0, 0, 0], 1.0f);

	if (cartState == TFCART_PUSHED) {
		stateText = sprintf("x%d", pushers);
	} else if (cartState == TFCART_BLOCKED) {
		stateText = "BLOCKED";
	} else if (cartState == TFCART_RECEDING) {
		stateText = "<<";
	}

	if (STRING_SET(stateText)) {
		TFHUD_CenteredText(barPos + [barSize[0] / 2, barSize[1] + 4], stateText, [1, 1, 1]);
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

	/* a TF2 HUD draws the clocks itself (tf_vguihud.qc) */
	bool clocksDrawn = TFVGui_Active();

	if (clocksDrawn) {
		topCenter[1] += hudSize[1] / 480 * 36;

		/* it has no panel for these */
		if (roundState == TFROUND_PREROUND || roundState == TFROUND_WIN || roundState == TFROUND_STALEMATE) {
			TFHUD_CenteredText(topCenter, headline, [1, 1, 1]);
		}
	} else if (STRING_SET(headline)) {
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

	/* payload: the cart's way to the goal, under the checkpoints */
	for (int i = 0; i < tokenize_console(objectives); i++) {
		string cartToken = argv(i);

		if (substring(cartToken, 0, 1) == "c") {
			tokenizebyseparator(substring(cartToken, 1, -1), ":");
			TFHUD_DrawCart(topCenter + [-120, 70], stof(argv(0)), stof(argv(1)), stof(argv(2)), stof(argv(3)));
			break;
		}
	}

	/* KOTH clocks either side of the point */
	if (modeName == "koth" && !clocksDrawn) {
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

/** Reload timer bar above the crosshair (the target ID panel is below it), in place of reload animations.
A shotgun-style reload shows the round going in ("3/4"), a magazine reload
the whole magazine. Progress comes from the predicted weapon state. */
void
TFHUD_DrawReload(void)
{
	float progress = weapon.GetReloadProgress();

	if (progress < 0.0f) {
		return;
	}

	if (g_tfHUDInit == false) {
		font.Load("fonts/font16.font", FONT_TF);
		g_tfHUDInit = true;
	}

	vector hudMins = screen.HUDMins();
	vector hudSize = screen.HUDSize();
	vector barSize = [128, 8];
	vector barPos = hudMins + [(hudSize[0] - barSize[0]) / 2, (hudSize[1] / 2) - 40];
	int reloadRound = weapon.GetReloadRound();
	string label;

	/* a round at a time adds to the clip after each step, a magazine fills at the end */
	if (reloadRound > 0i) {
		label = sprintf("%i/%i", reloadRound, weapon.GetClipSize());
	} else {
		label = "Reloading";
	}

	draw.Rect(barPos, barSize, [0, 0, 0], 0.5f);
	draw.RectOutline(barPos - [1, 1], barSize + [2, 2], 1.0f, [0.6, 0.5, 0.25], 1.0f);
	draw.Rect(barPos, [barSize[0] * progress, barSize[1]], [1, 0.85, 0.4], 0.9f);
	TFHUD_CenteredText(barPos + [barSize[0] / 2, -20], label, [1, 0.85, 0.4]);
}

var float autocvar_crosshair = 1;
var float autocvar_cl_crosshair_red = 200;
var float autocvar_cl_crosshair_green = 200;
var float autocvar_cl_crosshair_blue = 200;
var float autocvar_cl_crosshair_alpha = 200;
var float autocvar_cl_crosshair_scale = 32;

/** Crosshair: a plus with a gap and a centre dot, in the colour TF2's
cl_crosshair_red/green/blue/alpha cvars give (0-255). cl_crosshair_scale is
the size in pixels at 32 by default, and `crosshair 0` hides it. Nuclide turns
the engine's own crosshair off, so the HUD has to draw one. */
void
TFHUD_DrawCrosshair(void)
{
	if (autocvar_crosshair == 0) {
		return;
	}

	vector crossColor = [autocvar_cl_crosshair_red, autocvar_cl_crosshair_green, autocvar_cl_crosshair_blue] / 255;
	float crossAlpha = bound(0, autocvar_cl_crosshair_alpha / 255, 1);
	float armLength = rint(max(2, autocvar_cl_crosshair_scale / 6));
	float armGap = rint(max(1, autocvar_cl_crosshair_scale / 10));
	vector crossCenter = screen.HUDMins() + screen.HUDSize() / 2;
	crossCenter[0] = rint(crossCenter[0]);
	crossCenter[1] = rint(crossCenter[1]);

	/* dark outline first so the lines read on bright walls */
	drawfill(crossCenter + [-armGap - armLength - 1, -1], [armLength + 2, 3], [0, 0, 0], crossAlpha * 0.5f, DRAWFLAG_NORMAL);
	drawfill(crossCenter + [armGap, -1], [armLength + 2, 3], [0, 0, 0], crossAlpha * 0.5f, DRAWFLAG_NORMAL);
	drawfill(crossCenter + [-1, -armGap - armLength - 1], [3, armLength + 2], [0, 0, 0], crossAlpha * 0.5f, DRAWFLAG_NORMAL);
	drawfill(crossCenter + [-1, armGap], [3, armLength + 2], [0, 0, 0], crossAlpha * 0.5f, DRAWFLAG_NORMAL);
	drawfill(crossCenter - [1, 1], [3, 3], [0, 0, 0], crossAlpha * 0.5f, DRAWFLAG_NORMAL);

	drawfill(crossCenter + [-armGap - armLength, 0], [armLength, 1], crossColor, crossAlpha, DRAWFLAG_NORMAL);
	drawfill(crossCenter + [armGap + 1, 0], [armLength, 1], crossColor, crossAlpha, DRAWFLAG_NORMAL);
	drawfill(crossCenter + [0, -armGap - armLength], [1, armLength], crossColor, crossAlpha, DRAWFLAG_NORMAL);
	drawfill(crossCenter + [0, armGap + 1], [1, armLength], crossColor, crossAlpha, DRAWFLAG_NORMAL);
	drawfill(crossCenter, [1, 1], crossColor, crossAlpha, DRAWFLAG_NORMAL);
}

/** Number keys switch straight to the weapon in that slot, as in TF2:
slot1 primary, slot2 secondary, slot3 melee, slot4 and slot5 the PDAs.
Pressing the key of the slot in hand again steps to the next weapon in it. */
bool
HUD_ConsoleCommand(string commandString)
{
	tokenize_console(commandString);

	if (substring(argv(0), 0, 4) != "slot") {
		return (false);
	}

	int wantedSlot = stoi(substring(argv(0), 4, -1)) - 1i;
	entity activeWeapon = weapon.GetActiveWeapon();
	entity firstInSlot = __NULL__;
	entity nextInSlot = __NULL__;
	bool pastActive = false;

	if (wantedSlot < 0i || !activeWeapon) {
		return (true);
	}

	for (entity w = weapon.GetFirstWeaponInInventory(); w; w = weapon.GetNextWeaponRelativeTo(w)) {
		if (w == activeWeapon) {
			pastActive = true;
			continue;
		}

		if (weapon.IsValid(w) == false || weapon.GetSlot(w) != wantedSlot) {
			continue;
		}

		if (!firstInSlot) {
			firstInSlot = w;
		}

		if (pastActive && !nextInSlot) {
			nextInSlot = w;
		}
	}

	if (weapon.GetSlot(activeWeapon) == wantedSlot && nextInSlot) {
		weapon.SelectWeapon(nextInSlot);
	} else if (firstInSlot) {
		weapon.SelectWeapon(firstInSlot);
	}

	return (true);
}
