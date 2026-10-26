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

/** @file tf_api.h
The Team Fortress template's shared vocabulary.

Included by the server progs and by every rules progs, so both sides agree
on team numbers, objective kinds and the entity fields that describe them.
Bots and other server code should only read objective state through these
fields and the TF_* helpers in server/tf_api.qc.

Teams are Nuclide teams: 1 is RED, 2 is BLU. Map keys that follow Team
Fortress 2's numbering (2 = RED, 3 = BLU) go through TF_TeamFromMapKey().
*/

#define TF_TEAM_NONE 0
#define TF_TEAM_RED 1
#define TF_TEAM_BLU 2

/* values of .tf_objective */
#define TFOBJ_NONE 0
#define TFOBJ_FLAG 1		/**< item_teamflag */
#define TFOBJ_CAPZONE 2		/**< func_capturezone */
#define TFOBJ_POINT 3		/**< team_control_point */

/* values of .tf_flagState */
#define TFFLAG_HOME 0
#define TFFLAG_CARRIED 1
#define TFFLAG_DROPPED 2

/* values of the tf_round serverinfo key */
#define TFROUND_WAITING 0	/**< waiting for both teams to have players */
#define TFROUND_PREROUND 1	/**< everyone spawned, frozen */
#define TFROUND_SETUP 2		/**< setup time, objectives locked */
#define TFROUND_ACTIVE 3
#define TFROUND_WIN 4		/**< bonus time after a team won */
#define TFROUND_STALEMATE 5

/* the HUD progs only want the constants: a CSQC add-on can't add entity
   fields once entities exist */
#ifndef TF_NO_FIELDS
/* objective fields. every objective has tf_isObjective set to 1 so it can be
   found with findfloat(). .team is the owning team (0 = neutral). */
.float tf_isObjective;
.float tf_objective;

/* control points */
.float tf_cpIndex;		/**< point_index key */
.float tf_cpLocked;		/**< 1 while it can't be captured by anyone */
.float tf_cpProgress;	/**< 0 to 1, capture progress of tf_cpCapTeam */
.float tf_cpCapTeam;	/**< team currently capturing, 0 if none */
.float tf_cpContested;	/**< 1 while both teams stand on it */
.entity tf_cpArea;		/**< the trigger_capture_area feeding this point */

/* flags */
.float tf_flagState;	/**< TFFLAG_* */
.entity tf_flagCarrier;

/* players */
.entity tf_carriedFlag;		/**< the item_teamflag this player carries */
.string tf_desiredClass;	/**< class def the player respawns as */
.float tf_classIndex;		/**< from the class def, 1 to 9 */
.float tf_capRate;			/**< how many cappers this player counts as */
.float tf_regenRate;		/**< health regenerated per second */
.float tf_deathTime;
.float tf_inRespawnRoom;	/**< time the player was last seen in their func_respawnroom */
.float tf_lastRegenTime;

/* test hooks (tf_test_pin). Every field the rules progs use must be declared
   here so the server progs allocate it: rules progs load after the entities
   exist and can't add fields of their own. */
.entity tf_testPin;
.vector tf_testPinPos;

/* per-class state for bots and HUDs. weapons that implement these
   behaviours should keep them up to date. */
.float tf_charge;			/**< sniper charge, medic uber, minigun spin: 0 to 1 */
.entity tf_healTarget;		/**< medic's current patient */
#endif

/** Converts a team number from a Team Fortress 2 map key (2 = RED, 3 = BLU)
to a Nuclide team. Anything else, including 0, means no team. Entities also
accept a native "team" key (1 = RED, 2 = BLU) for hand-written overlays. */
float
TF_TeamFromMapKey(float keyValue)
{
	if (keyValue == 2) {
		return (TF_TEAM_RED);
	} else if (keyValue == 3) {
		return (TF_TEAM_BLU);
	}

	return (TF_TEAM_NONE);
}

/** The other team, for two team games. */
float
TF_EnemyTeam(float teamID)
{
	if (teamID == TF_TEAM_RED) {
		return (TF_TEAM_BLU);
	} else if (teamID == TF_TEAM_BLU) {
		return (TF_TEAM_RED);
	}

	return (TF_TEAM_NONE);
}

string
TF_TeamName(float teamID)
{
	if (teamID == TF_TEAM_RED) {
		return ("RED");
	} else if (teamID == TF_TEAM_BLU) {
		return ("BLU");
	}

	return ("Nobody");
}
