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

/* Overhead names and health bars for teammates and friendly NPCs.
   cg_nameplates: -1 follows the server's "nameplates" serverinfo key,
   0 is off, 1 is on. */
var float autocvar_cg_nameplates = -1;
var float autocvar_cg_nameplatesRange = 1000;

#define NAMEPLATE_BARWIDTH 48
#define NAMEPLATE_BARHEIGHT 4

static bool
Nameplates_Enabled(void)
{
	if (autocvar_cg_nameplates >= 0)
		return (autocvar_cg_nameplates > 0) ? true : false;

	return (serverkeyfloat("nameplates") > 0) ? true : false;
}

static void
Nameplates_DrawOne(entity target, string nameText, float healthFrac, vector camPos, vector camFwd)
{
	vector headPos = target.origin + [0, 0, target.maxs[2] + 10];
	vector toHead = headPos - camPos;
	float dist = vlen(toHead);

	if (dist > autocvar_cg_nameplatesRange)
		return;

	/* behind the camera */
	if ((toHead * camFwd) <= 0)
		return;

	traceline(camPos, headPos, MOVE_NOMONSTERS, pSeat->m_ePlayer);

	if (trace_fraction < 1.0)
		return;

	vector screenPos = project(headPos);
	float alpha = bound(0.0, (autocvar_cg_nameplatesRange - dist) / (autocvar_cg_nameplatesRange * 0.25), 1.0);
	vector barPos = screenPos - [NAMEPLATE_BARWIDTH / 2, 0];

	if (nameText != "") {
		vector textPos = screenPos;
		textPos[0] -= Font_StringWidth(nameText, true, FONT_CON) / 2;
		textPos[1] -= FONT_CON.iScaleY + 2;
		Font_DrawText_RGBA(textPos, nameText, [0.6, 0.85, 1.0], alpha, FONT_CON);
	}

	healthFrac = bound(0.0, healthFrac, 1.0);
	drawfill(barPos - [1, 1], [NAMEPLATE_BARWIDTH + 2, NAMEPLATE_BARHEIGHT + 2], [0, 0, 0], alpha * 0.6, DRAWFLAG_NORMAL);
	drawfill(barPos, [NAMEPLATE_BARWIDTH * healthFrac, NAMEPLATE_BARHEIGHT], [1.0 - healthFrac, healthFrac, 0.1], alpha, DRAWFLAG_NORMAL);
}

/** Draws nameplates over living teammates (same non-zero team) and
friendly NPCs. Called from CSQC_Update2D. */
void
Nameplates_Draw(void)
{
	entity localPlayer = pSeat->m_ePlayer;
	vector camPos;
	vector camFwd;
	string ourTeam;

	if (!localPlayer || !Nameplates_Enabled())
		return;

	camPos = g_view.GetCameraOrigin();
	makevectors(g_view.GetCameraAngle());
	camFwd = v_forward;
	ourTeam = getplayerkeyvalue(localPlayer.entnum - 1, "*team");

	/* teammates */
	if (ourTeam != "" && ourTeam != "0") {
		for (entity pl = world; (pl = next.Player(pl));) {
			if (pl == localPlayer || pl.health <= 0)
				continue;
			if (getplayerkeyvalue(pl.entnum - 1, "*team") != ourTeam)
				continue;

			Nameplates_DrawOne(pl, getplayerkeyvalue(pl.entnum - 1, "name"), pl.health / 100, camPos, camFwd);
		}
	}

	/* friendly NPCs */
	for (entity npc = world; (npc = findflags(npc, ::flags, FL_MONSTER));) {
		ncMonster mon = (ncMonster)npc;

		if (mon.health <= 0 || mon.m_iAlliance != MAL_FRIEND)
			continue;

		float maxHealth = (mon.max_health > 0) ? mon.max_health : mon.health;
		Nameplates_DrawOne(mon, mon.netname, mon.health / maxHealth, camPos, camFwd);
	}
}
