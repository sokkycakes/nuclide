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

/** @file tf_koth.qc
King of the Hill. One control point starts locked and opens after
tf_koth_unlock seconds. While a team owns it, that team's clock counts down
from tf_koth_time; the first team whose clock reaches zero wins. If the
enemy is mid-capture when the clock runs out, the round goes into overtime
until they finish or give up. */

var float autocvar_tf_koth_unlock = 30.0f;
var float autocvar_tf_koth_time = 180.0f;

float g_kothClock[3];
float g_kothUnlockAt;
bool g_kothUnlocked;
bool g_kothOvertime;

string
Mode_Name(void)
{
	return ("koth");
}

entity
KOTH_Point(void)
{
	for (entity e = world; (e = TFServer_NextObjective(e));) {
		if (e.tf_objective == TFOBJ_POINT) {
			return (e);
		}
	}

	return (world);
}

void
Mode_Init(void)
{
	if (!KOTH_Point()) {
		print("^1TF template KOTH: this map has no team_control_point. Add one in maps/<map>_tf_koth.add.\n");
	}
}

void
Mode_RoundStart(void)
{
	g_kothClock[1] = g_kothClock[2] = autocvar_tf_koth_time;
	g_kothUnlocked = false;
	g_kothOvertime = false;
	g_kothUnlockAt = 0;
	TFServer_LockAllPoints(1);
}

float
Mode_SetupTime(void)
{
	return (0);
}

float
Mode_RoundTime(void)
{
	return (0);
}

void
Mode_Frame(void)
{
	entity thePoint = KOTH_Point();

	if (!thePoint) {
		return;
	}

	if (g_kothUnlocked == false) {
		if (g_kothUnlockAt == 0) {
			g_kothUnlockAt = time + autocvar_tf_koth_unlock;
		}

		if (time >= g_kothUnlockAt) {
			g_kothUnlocked = true;
			TFServer_LockAllPoints(0);
			TF_Announce("The control point is now unlocked!");
		}
		return;
	}

	float owner = thePoint.team;

	if (owner != TF_TEAM_RED && owner != TF_TEAM_BLU) {
		return;
	}

	g_kothClock[owner] = max(0, g_kothClock[owner] - frametime);

	if (g_kothClock[owner] > 0) {
		g_kothOvertime = false;
		return;
	}

	/* the enemy is taking it: overtime */
	if (thePoint.tf_cpCapTeam == TF_EnemyTeam(owner) && thePoint.tf_cpProgress > 0) {
		if (g_kothOvertime == false) {
			g_kothOvertime = true;
			TF_Announce("Overtime!");
		}
		return;
	}

	teams.AddScore((int)owner, 1);
	TF_RoundWin(owner, "They held the point.");
}

float
Mode_TimeUp(void)
{
	return (-1);
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
		TF_Announce(sprintf("%s captured the point!", TF_TeamName(stof(argv(1)))));
		break;
	}
}

void
Mode_HUD(void)
{
	string clocks = sprintf("%d %d", ceil(g_kothClock[1]), ceil(g_kothClock[2]));

	if (serverinfo.GetString("tf_koth") != clocks) {
		serverinfo.SetString("tf_koth", clocks);
	}

	if (g_kothUnlocked == false && g_kothUnlockAt > 0) {
		serverinfo.SetFloat("tf_timer", max(0, ceil(g_kothUnlockAt - time)));
	}
}

float
TFRules_AllowPointCapture(entity pointEnt, float teamID)
{
	return TF_ObjectivesLive();
}
