/*
 * Copyright (c) 2026 Vera Visions LLC.
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

/* Framework always-on spectator HUD chrome.

   Drawn for every ncSpectator from src/client/hud.qc HUD_DrawSpectator()
   (before the game's hud.dat extension), so every game inherits it.

   Layout follows Counter-Strike spectator conventions: a thin dark top bar
   (match timer + team scores, right-aligned) and a thin dark bottom bar
   (compact key hints on the left, the watched player's name centered,
   camera mode label on the right). A free-roam-only crosshair sits in the
   middle.

   Typography uses Trade Gothic (Franklin Gothic Medium stand-in per the
   project's CEF menu convention) via FONT_SPEC / FONT_SPEC_HINT.

   This is a pure draw module: it reads existing client-side state via the
   CLPF_spectating_* accessors, serverkeys and Util_GetTime(), and never
   mutates spectator state or handles input. Everything is anchored to the
   letterboxed HUD rect (g_hudmins/g_hudres) so it tracks the safe HUD area
   on non-4:3 windows, mirroring HUD_Draw(). */

#define SPECHUD_BAR_COLOR	[0.0f, 0.0f, 0.0f]
#define SPECHUD_BAR_ALPHA	0.5f
#define SPECHUD_FG_COLOR	[1.0f, 1.0f, 1.0f]
#define SPECHUD_ACCENT_COLOR	[1.0f, 0.8f, 0.2f]	/* CS-style gold for timer/scores */
#define SPECHUD_NAME_COLOR	[1.0f, 0.8f, 0.2f]	/* watched player name */
#define SPECHUD_DIM_COLOR	[0.62f, 0.62f, 0.62f]	/* subtle key hints */

#define SPECHUD_PAD_X		12	/* horizontal text inset from the bar edges */
#define SPECHUD_BAR_VPAD	6	/* vertical text inset, sets the bar height */

/** Vertical text position that centers a glyph of fontHeight in a bar. */
static float
Spectator_BarTextY(float barY, float barHeight, float fontHeight)
{
	return barY + ((barHeight - fontHeight) / 2);
}

/** Top bar: match timer + team scores (right-aligned). */
static void
Spectator_DrawTopBar(vector hudMins, vector hudSize)
{
	float lineHeight = Font_GetHeight(FONT_SPEC);
	float barHeight = lineHeight + (SPECHUD_BAR_VPAD * 2);
	float barY = hudMins[1];
	float textY = Spectator_BarTextY(barY, barHeight, lineHeight);

	/* the bar chrome itself */
	drawfill([hudMins[0], barY], [hudSize[0], barHeight], SPECHUD_BAR_COLOR, SPECHUD_BAR_ALPHA, DRAWFLAG_NORMAL);

	/* timer, right-aligned */
	string timeStr = Util_GetTime();
	float timeWidth = Font_StringWidth(timeStr, true, FONT_SPEC);
	float timeX = hudMins[0] + hudSize[0] - SPECHUD_PAD_X - timeWidth;
	Font_DrawText_RGBA([timeX, textY], timeStr, SPECHUD_ACCENT_COLOR, 1.0f, FONT_SPEC);

	/* per-team scores, sitting to the left of the timer (teams only) */
	int teamCount = (int)serverkeyfloat("teams");

	if (teamCount > 0) {
		string scoreLine = "";

		for (int t = 1; t <= teamCount; t++) {
			string teamName = serverkey(sprintf("team_%i", t));
			int teamScore = (int)serverkeyfloat(sprintf("teamscore_%i", t));
			string entry;

			if (STRING_SET(teamName)) {
				entry = sprintf("%s %i", teamName, teamScore);
			} else {
				entry = sprintf("T%i %i", t, teamScore);
			}

			scoreLine = STRING_SET(scoreLine) ? sprintf("%s   %s", scoreLine, entry) : entry;
		}

		float scoreWidth = Font_StringWidth(scoreLine, true, FONT_SPEC);
		float scoreX = timeX - 24 - scoreWidth;
		Font_DrawText_RGBA([scoreX, textY], scoreLine, SPECHUD_ACCENT_COLOR, 1.0f, FONT_SPEC);
	}
}

/** Bottom bar: compact key hints (left), watched name (center), mode (right). */
static void
Spectator_DrawBottomBar(vector hudMins, vector hudSize)
{
	ncSpectatorMode_t specMode = CLPF_spectating_Mode();
	string modeLabel = CLPF_spectating_LocalizedMode();

	float lineHeight = Font_GetHeight(FONT_SPEC);
	float hintHeight = Font_GetHeight(FONT_SPEC_HINT);
	float barHeight = lineHeight + (SPECHUD_BAR_VPAD * 2);
	float barY = hudMins[1] + hudSize[1] - barHeight;
	float textY = Spectator_BarTextY(barY, barHeight, lineHeight);

	/* the bar chrome itself */
	drawfill([hudMins[0], barY], [hudSize[0], barHeight], SPECHUD_BAR_COLOR, SPECHUD_BAR_ALPHA, DRAWFLAG_NORMAL);

	/* compact key hints, left-aligned in the smaller hint font */
	string hintLine = "LMB Mode+   RMB Mode-   Wheel Target";
	float hintY = Spectator_BarTextY(barY, barHeight, hintHeight);
	Font_DrawText_RGBA([hudMins[0] + SPECHUD_PAD_X, hintY], hintLine, SPECHUD_DIM_COLOR, 1.0f, FONT_SPEC_HINT);

	/* watched player name, centered (free-roam isn't tracking anyone) */
	if (specMode != SPECMODE_FREE) {
		string nameStr = CLPF_spectating_Name();
		float nameWidth = Font_StringWidth(nameStr, true, FONT_SPEC);
		float nameX = hudMins[0] + (hudSize[0] / 2) - (nameWidth / 2);
		Font_DrawText_RGBA([nameX, textY], nameStr, SPECHUD_NAME_COLOR, 1.0f, FONT_SPEC);
	}

	/* camera mode label, right-aligned */
	float modeWidth = Font_StringWidth(modeLabel, true, FONT_SPEC);
	float modeX = hudMins[0] + hudSize[0] - SPECHUD_PAD_X - modeWidth;
	Font_DrawText_RGBA([modeX, textY], modeLabel, SPECHUD_FG_COLOR, 1.0f, FONT_SPEC);
}

/** Observer crosshair, only in free-roam (SPECMODE_FREE). */
static void
Spectator_DrawCrosshair(vector hudMins, vector hudSize)
{
	if (CLPF_spectating_Mode() != SPECMODE_FREE) {
		return;
	}

	vector crossPos = hudMins + (hudSize / 2);
	crossPos[0] -= Font_StringWidth("+", false, FONT_SPEC) / 2;
	crossPos[1] -= Font_GetHeight(FONT_SPEC) / 2;
	Font_DrawText_RGBA(crossPos, "+", SPECHUD_FG_COLOR, 1.0f, FONT_SPEC);
}

/** Entry point: draws the framework spectator chrome for the local observer. */
void
Spectator_DrawHUD(void)
{
	vector hudMins = g_hudmins;
	vector hudSize = g_hudres;

	Spectator_DrawTopBar(hudMins, hudSize);
	Spectator_DrawBottomBar(hudMins, hudSize);
	Spectator_DrawCrosshair(hudMins, hudSize);
}
