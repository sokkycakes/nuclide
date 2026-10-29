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

/** @file tf_pl.qc
Payload. The attackers (the team the cart's trigger_capture_area lets
capture, BLU on Team Fortress 2 maps) push a cart along a track; the
team_train_watcher turns pushers into speed (server/tf_payload.qc).
Checkpoints are the map's team_control_points: path_track OnPass outputs
hand them to the attackers as the cart rolls over them, and the map adds
time through its team_round_timer.

The attackers win when the cart reaches the goal, or own every point. The
defenders win when time runs out. If the attackers are at the cart then,
the round goes into overtime until nobody pushes.

Round and setup lengths come from the map's team_round_timer, or from
tf_pl_roundtime and tf_pl_setuptime when it has none. Every round starts
from a full map reset, as in TF2: doors close, the cart goes home. */

var float autocvar_tf_pl_roundtime = 600.0f;
var float autocvar_tf_pl_setuptime = 60.0f;

var void(void) TFServer_ResetMap;

float g_plAttackers;
bool g_plOvertime;

string
Mode_Name(void)
{
	return ("pl");
}

entity
PL_Watcher(void)
{
	for (entity e = world; (e = TFServer_NextObjective(e));) {
		if (e.tf_objective == TFOBJ_CART) {
			return (e);
		}
	}

	return (world);
}

entity
PL_Timer(void)
{
	return findfloat(world, ::tf_roundTimer, 1);
}

void
Mode_Init(void)
{
	TFServer_ResetMap = externvalue(0, "TF_ResetMap");
	g_plAttackers = TF_TEAM_BLU;

	if (!PL_Watcher()) {
		print("^1TF template PL: this map has no team_train_watcher.\n");
	}

	serverinfo.SetInteger("tf_overtime", 0);
}

void
Mode_RoundStart(void)
{
	if (TFServer_ResetMap) {
		TFServer_ResetMap();
	}

	g_plOvertime = false;
	serverinfo.SetInteger("tf_overtime", 0);
}

float
Mode_SetupTime(void)
{
	entity theTimer = PL_Timer();
	return (theTimer) ? theTimer.tf_setupLength : autocvar_tf_pl_setuptime;
}

float
Mode_RoundTime(void)
{
	entity theTimer = PL_Timer();
	return (theTimer) ? theTimer.tf_timerLength : autocvar_tf_pl_roundtime;
}

bool
PL_AttackersPushing(void)
{
	entity theWatcher = PL_Watcher();
	return (theWatcher && theWatcher.tf_cartPushers > 0) ? (true) : (false);
}

void
Mode_Frame(void)
{
	entity theWatcher = PL_Watcher();

	if (theWatcher && theWatcher.team != TF_TEAM_NONE) {
		g_plAttackers = theWatcher.team;
	}

	/* overtime ends the moment nobody pushes */
	if (g_plOvertime && PL_AttackersPushing() == false) {
		TF_RoundWin(TF_EnemyTeam(g_plAttackers), "The cart was stopped in overtime.");
	}
}

float
Mode_TimeUp(void)
{
	if (PL_AttackersPushing()) {
		if (g_plOvertime == false) {
			g_plOvertime = true;
			serverinfo.SetInteger("tf_overtime", 1);
			TF_Announce("Overtime!");
		}

		return (-1);
	}

	return TF_EnemyTeam(g_plAttackers);
}

/** The team owning every point, or 0. */
float
PL_OwnerOfAll(void)
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
Mode_Event(entity activator, string eventName, string eventData)
{
	switch (eventName) {
	case "TF_PointCaptured":
		tokenize_console(eventData);
		float newOwner = stof(argv(1));

		if (newOwner == g_plAttackers) {
			TF_Announce(sprintf("%s reached a checkpoint!", TF_TeamName(newOwner)));
		}

		if (PL_OwnerOfAll() == g_plAttackers && TF_ObjectivesLive()) {
			teams.AddScore((int)g_plAttackers, 1);
			TF_RoundWin(g_plAttackers, "The cart was delivered.");
		}
		break;
	case "TF_CartDelivered":
		if (TF_ObjectivesLive()) {
			teams.AddScore((int)g_plAttackers, 1);
			TF_RoundWin(g_plAttackers, "The cart was delivered.");
		}
		break;
	}
}

void
Mode_HUD(void)
{
}

/** Points on payload maps only change hands through the cart. */
float
TFRules_AllowPointCapture(entity pointEnt, float teamID)
{
	return (false);
}

/** The cart only moves while the round is live (not in setup). */
float
TFRules_AllowCartPush(entity watcherEnt, float teamID)
{
	return TF_ObjectivesLive() ? (true) : (false);
}
