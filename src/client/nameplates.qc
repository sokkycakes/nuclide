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

/* Teammates and friendly NPCs get two things:
   - overhead names and health bars (cg_nameplates)
   - a TF2-style target ID panel under the crosshair while you aim at
     one (cg_targetID)
   Both cvars: -1 follows the server's serverinfo key ("nameplates",
   "targetid"), 0 is off, 1 is on. */
var float autocvar_cg_nameplates = -1;
var float autocvar_cg_nameplatesRange = 1000;
var float autocvar_cg_targetID = -1;
var float autocvar_cg_targetIDRange = 2000;
/* seconds the panel stays up after the crosshair leaves its target */
var float autocvar_cg_targetIDLinger = 0.5;

#define NAMEPLATE_BARWIDTH 48
#define NAMEPLATE_BARHEIGHT 4

static bool
Nameplates_Setting(float cvarValue, string serverKey)
{
	if (cvarValue >= 0)
		return (cvarValue > 0) ? true : false;

	return (serverkeyfloat(serverKey) > 0) ? true : false;
}

/* what the target ID panel shows, kept while it lingers */
static entity g_targetIDEnt;
static string g_targetIDName;
static float g_targetIDHealth;
static float g_targetIDMaxHealth;
static float g_targetIDLastSeen;

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

/* distance along the camera ray to the target's box, or -1 on a miss */
static float
Nameplates_RayHit(entity target, vector camPos, vector camFwd)
{
	vector boxMin = target.origin + target.mins - [4, 4, 4];
	vector boxMax = target.origin + target.maxs + [4, 4, 4];
	float nearDist = 0;
	float farDist = autocvar_cg_targetIDRange;

	for (int i = 0i; i < 3i; i++) {
		if (fabs(camFwd[i]) < 0.0001) {
			if (camPos[i] < boxMin[i] || camPos[i] > boxMax[i])
				return (-1);
			continue;
		}

		float t1 = (boxMin[i] - camPos[i]) / camFwd[i];
		float t2 = (boxMax[i] - camPos[i]) / camFwd[i];

		nearDist = max(nearDist, min(t1, t2));
		farDist = min(farDist, max(t1, t2));

		if (nearDist > farDist)
			return (-1);
	}

	/* a wall in between */
	traceline(camPos, camPos + camFwd * nearDist, MOVE_NOMONSTERS, pSeat->m_ePlayer);

	if (trace_fraction < 0.99)
		return (-1);

	return (nearDist);
}

static void
Nameplates_DrawTargetID(void)
{
	float sinceSeen = time - g_targetIDLastSeen;
	float alpha;
	string healthText;
	vector panelSize = g_vec_null;
	vector panelPos;
	float healthFrac;

	if (!g_targetIDEnt || sinceSeen > autocvar_cg_targetIDLinger)
		return;

	alpha = (sinceSeen <= 0) ? 1.0 : bound(0.0, 1.0 - (sinceSeen / autocvar_cg_targetIDLinger), 1.0);
	healthText = sprintf("%d / %d", ceil(g_targetIDHealth), g_targetIDMaxHealth);
	healthFrac = bound(0.0, g_targetIDHealth / g_targetIDMaxHealth, 1.0);

	panelSize[0] = max(140, max(Font_StringWidth(g_targetIDName, true, FONT_20), Font_StringWidth(healthText, true, FONT_16)) + 24);
	panelSize[1] = FONT_20.iScaleY + FONT_16.iScaleY + 22;
	panelPos = g_hudmins + [(g_hudres[0] - panelSize[0]) / 2, (g_hudres[1] / 2) + 48];

	drawfill(panelPos, panelSize, [0, 0, 0], alpha * 0.55, DRAWFLAG_NORMAL);
	drawfill(panelPos, [3, panelSize[1]], [0.6, 0.85, 1.0], alpha, DRAWFLAG_NORMAL);

	Font_DrawText_RGBA(panelPos + [12, 6], g_targetIDName, [0.6, 0.85, 1.0], alpha, FONT_20);

	vector barPos = panelPos + [12, FONT_20.iScaleY + 10];
	float barWidth = panelSize[0] - 24;
	drawfill(barPos, [barWidth, FONT_16.iScaleY], [0.15, 0.15, 0.15], alpha * 0.8, DRAWFLAG_NORMAL);
	drawfill(barPos, [barWidth * healthFrac, FONT_16.iScaleY], [1.0 - healthFrac, healthFrac, 0.1] * 0.7, alpha, DRAWFLAG_NORMAL);
	Font_DrawText_RGBA(barPos + [(barWidth - Font_StringWidth(healthText, true, FONT_16)) / 2, 0], healthText, [1, 1, 1], alpha, FONT_16);
}

/* one teammate or friendly NPC: its overhead plate, and whether the
   crosshair is on it */
static void
Nameplates_Consider(entity target, string nameText, float health, float maxHealth, bool overhead, bool targetID, vector camPos, vector camFwd)
{
	if (overhead)
		Nameplates_DrawOne(target, nameText, health / maxHealth, camPos, camFwd);

	if (!targetID)
		return;

	float hitDist = Nameplates_RayHit(target, camPos, camFwd);

	if (hitDist < 0)
		return;

	/* nearest one under the crosshair wins */
	if (g_targetIDLastSeen == time && g_targetIDEnt != target) {
		if (vlen(g_targetIDEnt.origin - camPos) < hitDist)
			return;
	}

	g_targetIDEnt = target;
	g_targetIDName = nameText;
	g_targetIDHealth = health;
	g_targetIDMaxHealth = maxHealth;
	g_targetIDLastSeen = time;
}

/** Draws overhead nameplates and the crosshair target ID for living
teammates (same non-zero team) and friendly NPCs. Called from
CSQC_Update2D. */
void
Nameplates_Draw(void)
{
	entity localPlayer = pSeat->m_ePlayer;
	bool overhead = Nameplates_Setting(autocvar_cg_nameplates, "nameplates");
	bool targetID = Nameplates_Setting(autocvar_cg_targetID, "targetid");
	vector camPos;
	vector camFwd;
	string ourTeam;

	if (!localPlayer || (!overhead && !targetID))
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

			/* players don't network max_health */
			Nameplates_Consider(pl, getplayerkeyvalue(pl.entnum - 1, "name"), pl.health, max(100, pl.health), overhead, targetID, camPos, camFwd);
		}
	}

	/* friendly NPCs */
	for (entity npc = world; (npc = findflags(npc, ::flags, FL_MONSTER));) {
		ncMonster mon = (ncMonster)npc;

		if (mon.health <= 0 || mon.m_iAlliance != MAL_FRIEND)
			continue;

		float maxHealth = (mon.max_health > 0) ? mon.max_health : mon.health;
		Nameplates_Consider(mon, mon.netname, mon.health, maxHealth, overhead, targetID, camPos, camFwd);
	}

	/* the target died or left: drop it */
	if (g_targetIDEnt && (wasfreed(g_targetIDEnt) || g_targetIDEnt.health <= 0))
		g_targetIDEnt = world;

	if (targetID)
		Nameplates_DrawTargetID();
}
