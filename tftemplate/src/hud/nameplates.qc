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

/** @file nameplates.qc
Nameplates over friendly players and NPCs: a name and a health bar drawn
above the head, faded with distance and hidden behind walls.

This file has nothing game specific in it, so other mods can include it
as is. A mod plugs in through three optional callbacks, set before the
first frame (for example in its HUD init):

- Nameplates_IsFriendly(entity): true to draw a plate. The default draws
  for other players on the local player's team (userinfo "*team").
- Nameplates_Name(entity): the text. The default is the player's name.
- Nameplates_Health(entity): the bar as current and max health in a
  vector [health, max_health]. A max of 0 hides the bar. The default reads
  userinfo "*hp" and "*maxhp", which the server publishes for players.
  The HUD progs can't see the client's entity fields, so NPC health has to
  come from the mod's callback.

Plates sit at origin + maxs_z + 12, not on a bone, so they work with any
model format.

There is also a TF2-style target ID: put your crosshair on a friendly and
a panel under the crosshair shows their name and health, with the numbers.
It uses the same callbacks and stays up for a moment after you look away.

Cvars:
- cl_nameplates 1: 0 turns the floating plates off
- cl_nameplates_range 1200: units beyond which no plate is drawn
- cl_targetid 1: 0 turns the crosshair panel off
- cl_targetid_range 2000: how far the crosshair panel reaches
*/

var bool(entity) Nameplates_IsFriendly;
var string(entity) Nameplates_Name;
var vector(entity) Nameplates_Health;

var float autocvar_cl_nameplates = 1;
var float autocvar_cl_nameplates_range = 1200;
var float autocvar_cl_targetid = 1;
var float autocvar_cl_targetid_range = 2000;

font_s FONT_NAMEPLATE;
bool g_nameplatesInit;
entity g_targetIDEnt;
float g_targetIDUntil;

/** Player slot (0 based) for a networked player entity, or -1. */
float
Nameplates_PlayerSlot(entity targetEnt)
{
	if (targetEnt.entnum >= 1 && targetEnt.entnum <= maxclients) {
		return (targetEnt.entnum - 1);
	}

	return (-1);
}

bool
Nameplates_DefaultIsFriendly(entity targetEnt)
{
	float playerSlot = Nameplates_PlayerSlot(targetEnt);

	if (playerSlot < 0 || targetEnt.entnum == player_localentnum) {
		return (false);
	}

	float ourTeam = getplayerkeyfloat(player_localnum, "*team");
	float theirTeam = getplayerkeyfloat(playerSlot, "*team");

	/* no teams: nobody is a friend */
	if (ourTeam <= 0 || theirTeam != ourTeam) {
		return (false);
	}

	return (getplayerkeyfloat(playerSlot, "*dead") == 0);
}

string
Nameplates_DefaultName(entity targetEnt)
{
	float playerSlot = Nameplates_PlayerSlot(targetEnt);

	if (playerSlot < 0) {
		return ("");
	}

	return (getplayerkeyvalue(playerSlot, "name"));
}

vector
Nameplates_DefaultHealth(entity targetEnt)
{
	float playerSlot = Nameplates_PlayerSlot(targetEnt);

	if (playerSlot < 0) {
		return [0, 0, 0];
	}

	return [getplayerkeyfloat(playerSlot, "*hp"), getplayerkeyfloat(playerSlot, "*maxhp"), 0];
}

void
Nameplates_DrawOne(entity targetEnt, vector viewOrigin, vector viewForward)
{
	vector platePos = targetEnt.origin + [0, 0, targetEnt.maxs[2] + 12];
	vector toPlate = platePos - viewOrigin;
	float plateDistance = vlen(toPlate);

	if (plateDistance > autocvar_cl_nameplates_range) {
		return;
	}

	/* behind us */
	if ((toPlate * viewForward) <= 0) {
		return;
	}

	/* behind a wall */
	traceline(viewOrigin, platePos, MOVE_NOMONSTERS, targetEnt);

	if (trace_fraction < 1.0f) {
		return;
	}

	vector screenPos = project(platePos);
	float plateAlpha = bound(0.0f, 1.5f - (plateDistance / autocvar_cl_nameplates_range), 1.0f);
	string plateName = Nameplates_Name ? Nameplates_Name(targetEnt) : Nameplates_DefaultName(targetEnt);
	vector healthInfo = Nameplates_Health ? Nameplates_Health(targetEnt) : Nameplates_DefaultHealth(targetEnt);
	float nameWidth = font.StringWidth(plateName, true, FONT_NAMEPLATE);
	vector barSize = [64, 5];

	screenPos[2] = 0;
	draw.Text_RGBA(screenPos - [nameWidth / 2, 16], plateName, [1, 1, 1], plateAlpha, FONT_NAMEPLATE);

	if (healthInfo[1] <= 0) {
		return;
	}

	float healthFrac = bound(0.0f, healthInfo[0] / healthInfo[1], 1.5f);
	vector barPos = screenPos - [barSize[0] / 2, 0];
	vector barColor = [0.3, 0.9, 0.3];

	if (healthFrac > 1.0f) {
		barColor = [0.4, 0.8, 1.0]; /* overhealed */
	} else if (healthFrac < 0.5f) {
		barColor = [1.0, 0.3, 0.2];
	}

	draw.Rect(barPos, barSize, [0, 0, 0], 0.6f * plateAlpha);
	draw.Rect(barPos + [1, 1], [(barSize[0] - 2) * min(healthFrac, 1.0f), barSize[1] - 2], barColor, plateAlpha);
}

bool
Nameplates_CheckFriendly(entity targetEnt)
{
	return Nameplates_IsFriendly ? Nameplates_IsFriendly(targetEnt) : Nameplates_DefaultIsFriendly(targetEnt);
}

/** The crosshair target ID panel: name, health bar and "hp / max" under
the crosshair for the friendly you are looking at. */
void
Nameplates_DrawTargetID(vector viewOrigin, vector viewForward)
{
	if (autocvar_cl_targetid == 0) {
		return;
	}

	entity localPlayer = findfloat(world, ::entnum, player_localentnum);
	traceline(viewOrigin, viewOrigin + (viewForward * autocvar_cl_targetid_range), MOVE_NORMAL, localPlayer);

	if (trace_ent && trace_ent != world && trace_ent.modelindex != 0 && Nameplates_CheckFriendly(trace_ent)) {
		g_targetIDEnt = trace_ent;
		g_targetIDUntil = time + 0.5f;
	}

	if (!g_targetIDEnt || wasfreed(g_targetIDEnt) || time > g_targetIDUntil) {
		g_targetIDEnt = __NULL__;
		return;
	}

	/* they may have died or changed sides since */
	if (Nameplates_CheckFriendly(g_targetIDEnt) == false) {
		g_targetIDEnt = __NULL__;
		return;
	}

	string targetName = Nameplates_Name ? Nameplates_Name(g_targetIDEnt) : Nameplates_DefaultName(g_targetIDEnt);
	vector healthInfo = Nameplates_Health ? Nameplates_Health(g_targetIDEnt) : Nameplates_DefaultHealth(g_targetIDEnt);
	float panelAlpha = bound(0.0f, (g_targetIDUntil - time) * 4.0f, 1.0f);
	vector panelSize = [220, 44];
	vector panelPos = screen.HUDMins() + [(screen.HUDSize()[0] - panelSize[0]) / 2, (screen.HUDSize()[1] / 2) + 40];

	draw.Rect(panelPos, panelSize, [0, 0, 0], 0.55f * panelAlpha);
	draw.Text_RGBA(panelPos + [8, 6], targetName, [1, 1, 1], panelAlpha, FONT_NAMEPLATE);

	if (healthInfo[1] <= 0) {
		return;
	}

	float healthFrac = bound(0.0f, healthInfo[0] / healthInfo[1], 1.5f);
	vector barColor = [0.3, 0.9, 0.3];

	if (healthFrac > 1.0f) {
		barColor = [0.4, 0.8, 1.0];
	} else if (healthFrac < 0.5f) {
		barColor = [1.0, 0.3, 0.2];
	}

	string healthText = sprintf("%d / %d", healthInfo[0], healthInfo[1]);
	float healthWidth = font.StringWidth(healthText, true, FONT_NAMEPLATE);
	vector barPos = panelPos + [8, 28];
	vector barSize = [panelSize[0] - 24 - healthWidth, 8];

	draw.Rect(barPos, barSize, [0.15, 0.15, 0.15], panelAlpha);
	draw.Rect(barPos, [barSize[0] * min(healthFrac, 1.0f), barSize[1]], barColor, panelAlpha);
	draw.Text_RGBA(panelPos + [panelSize[0] - 8 - healthWidth, 24], healthText, barColor, panelAlpha, FONT_NAMEPLATE);
}

/** Draws every plate and the target ID. Call once per frame from the HUD. */
void
Nameplates_Draw(void)
{
	if (g_nameplatesInit == false) {
		font.Load("fonts/font16.font", FONT_NAMEPLATE);
		g_nameplatesInit = true;
	}

	vector viewOrigin = getproperty(VF_ORIGIN);
	makevectors(getproperty(VF_ANGLES));
	vector viewForward = v_forward;

	Nameplates_DrawTargetID(viewOrigin, viewForward);

	if (autocvar_cl_nameplates == 0) {
		return;
	}

	for (entity e = world; (e = nextent(e));) {
		if (e.modelindex == 0) {
			continue;
		}

		if (Nameplates_CheckFriendly(e)) {
			Nameplates_DrawOne(e, viewOrigin, viewForward);
		}
	}
}
