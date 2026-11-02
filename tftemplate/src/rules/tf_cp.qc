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

/** @file tf_cp.qc
Control Points, both flavours:
- Symmetric (tf_cp_attackers 0, like 5CP): own every point to win. When the
  round timer runs out it's a stalemate.
- Attack/Defend (tf_cp_attackers 1 for RED or 2 for BLU): only the attackers
  can capture; they win by owning every point, the defenders win when time
  runs out. Each capture adds tf_cp_timeadd seconds. Maps usually lock the
  order with team_previouspoint_* keys and give the defenders the points
  with point_default_owner.

Maps can set the attackers per map in their overlay with a
"tf_cp_attackers" key on any team_control_point, which beats the cvar. */

var float autocvar_tf_cp_roundtime = 600.0f;
var float autocvar_tf_cp_setuptime = 0.0f;
var float autocvar_tf_cp_timeadd = 0.0f;
var float autocvar_tf_cp_attackers = 0.0f;

float g_cpAttackers;
float g_cpPointCount;

string
Mode_Name(void)
{
	return ("cp");
}

void
Mode_Init(void)
{
	g_cpAttackers = autocvar_tf_cp_attackers;
	g_cpPointCount = 0;

	for (entity e = world; (e = TFServer_NextObjective(e));) {
		if (e.tf_objective == TFOBJ_POINT) {
			g_cpPointCount++;
		}
	}

	if (g_cpPointCount == 0) {
		print("^1TF template CP: this map has no team_control_point. Add some in maps/<map>_tf_cp.add.\n");
	}

	serverinfo.SetInteger("tf_cp_attackers", (int)g_cpAttackers);
}

void
Mode_RoundStart(void)
{
}

float
Mode_SetupTime(void)
{
	/* setup only makes sense when someone defends */
	return (g_cpAttackers != 0) ? autocvar_tf_cp_setuptime : 0;
}

float
Mode_RoundTime(void)
{
	return (autocvar_tf_cp_roundtime);
}

/** The team owning every point, or 0. */
float
CP_OwnerOfAll(void)
{
	float owner = -1;

	for (entity e = world; (e = TFServer_NextObjective(e));) {
		if (e.tf_objective != TFOBJ_POINT) {
			continue;
		}

		if (owner == -1) {
			owner = e.team;
		} else if (owner != e.team) {
			return (TF_TEAM_NONE);
		}
	}

	return (owner > 0) ? owner : TF_TEAM_NONE;
}

void
Mode_Frame(void)
{
}

float
Mode_TimeUp(void)
{
	if (g_cpAttackers != 0) {
		return TF_EnemyTeam(g_cpAttackers);
	}

	return (TF_TEAM_NONE);
}

void
Mode_Event(entity activator, string eventName, string eventData)
{
	switch (eventName) {
	case "TF_PlayerCapped":
		activator.frags += 2;
		break;
	case "TF_PointCaptured":
		tokenize_console(eventData);
		float pointIndex = stof(argv(0));
		float newOwner = stof(argv(1));

		TF_Announce(sprintf("%s captured point %d!", TF_TeamName(newOwner), pointIndex + 1));
		TF_AddRoundTime(autocvar_tf_cp_timeadd);

		float allOwner = CP_OwnerOfAll();

		if (allOwner != TF_TEAM_NONE) {
			if (g_cpAttackers == 0 || allOwner == g_cpAttackers) {
				teams.AddScore((int)allOwner, 1);
				TF_RoundWin(allOwner, "All points captured.");
			}
		}
		break;
	}
}

void
Mode_HUD(void)
{
}

float
TFRules_AllowPointCapture(entity pointEnt, float teamID)
{
	if (TF_ObjectivesLive() == false) {
		return (false);
	}

	if (g_cpAttackers != 0 && teamID != g_cpAttackers) {
		return (false);
	}

	return (true);
}
