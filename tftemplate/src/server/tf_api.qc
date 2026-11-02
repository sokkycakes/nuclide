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

/** @file tf_api.qc
Server-side helpers for the Team Fortress template.

Two audiences:
- Server code such as bots, which reads the game through the TF_* query
  functions below.
- The rules progs, which can't see server classes and call the functions
  marked "rules bridge" by name through externvalue().
*/

/* ---- objectives -------------------------------------------------------- */

/** Iterates every objective entity (flags, capture zones, control points).
Start with world, stop when it returns world. */
entity
TF_NextObjective(entity previousObjective)
{
	return findfloat(previousObjective, ::tf_isObjective, 1);
}

/** Whether `teamID` may capture `pointEnt` right now (unlocked, not already
theirs, previous points owned, not vetoed by the rules). Says nothing about
who is standing on it. */
bool
TF_CanCapture(entity pointEnt, float teamID)
{
	if (pointEnt.tf_objective != TFOBJ_POINT) {
		return (false);
	}

	tfControlPoint thePoint = (tfControlPoint)pointEnt;
	return thePoint.CanBeCappedBy(teamID);
}

/** Returns the objective `teamID` should be working on now:
- CTF: the capture zone if one of us carries a flag, otherwise the enemy flag
  (wherever it is; check tf_flagState and tf_flagCarrier).
- CP/KOTH: the lowest-index point we can capture. If there is none, the
  point the enemy can capture that we own, so we defend it.
- Payload: the cart's team_train_watcher, for both teams: one pushes it, the
  other stops it. Its origin is the middle of the cart's push zone, and its
  team is the attacking team.
Returns world when the map has nothing to do. */
entity
TF_ObjectiveFor(float teamID)
{
	entity bestEnt = world;
	entity e;

	/* payload: everyone plays the cart (checkpoints only fall to it) */
	for (e = world; (e = TF_NextObjective(e));) {
		if (e.tf_objective == TFOBJ_CART) {
			return (e);
		}
	}

	/* flag carriers go home */
	for (e = world; (e = next.Player(e));) {
		if (e.team == teamID && e.tf_carriedFlag) {
			for (entity zone = world; (zone = TF_NextObjective(zone));) {
				if (zone.tf_objective == TFOBJ_CAPZONE) {
					if (zone.team == TF_TEAM_NONE || zone.team == teamID) {
						return (zone);
					}
				}
			}
		}
	}

	/* enemy (or neutral) flags */
	for (e = world; (e = TF_NextObjective(e));) {
		if (e.tf_objective == TFOBJ_FLAG && e.team != teamID) {
			if (e.tf_flagCarrier.team != teamID) {
				return (e);
			}
		}
	}

	/* attack the lowest index point we can take */
	for (e = world; (e = TF_NextObjective(e));) {
		if (TF_CanCapture(e, teamID)) {
			if (bestEnt == world || e.tf_cpIndex < bestEnt.tf_cpIndex) {
				bestEnt = e;
			}
		}
	}

	if (bestEnt != world) {
		return (bestEnt);
	}

	/* nothing to attack: defend what the enemy can take */
	for (e = world; (e = TF_NextObjective(e));) {
		if (e.team == teamID && TF_CanCapture(e, TF_EnemyTeam(teamID))) {
			return (e);
		}
	}

	return (world);
}

/** Seconds left on `teamID`'s King of the Hill clock, or -1 outside KOTH. */
float
TF_KothTimeLeft(float teamID)
{
	string clocks = serverinfo.GetString("tf_koth");

	if (!STRING_SET(clocks)) {
		return (-1);
	}

	tokenize_console(clocks);

	if (teamID == TF_TEAM_RED) {
		return stof(argv(0));
	} else if (teamID == TF_TEAM_BLU) {
		return stof(argv(1));
	}

	return (-1);
}

/** The current game mode: "ctf", "cp", "koth" or "" outside the template's modes. */
string
TF_Mode(void)
{
	return serverinfo.GetString("tf_mode");
}

/* ---- pickups ----------------------------------------------------------- */

/** Iterates health and ammo pickups. Start with world. */
entity
TF_NextPickup(entity previousPickup)
{
	for (entity e = previousPickup; (e = next.Item(e));) {
		if (e.owner) {
			continue; /* in someone's inventory */
		}

		if (TF_PickupKind(e) != "") {
			return (e);
		}
	}

	return (world);
}

/** "health", "ammo" or "" */
string
TF_PickupKind(entity pickupEnt)
{
	if (entityDef.GetFloat(pickupEnt.classname, "inv_health") > 0.0f || entityDef.GetFloat(pickupEnt.classname, "inv_bonushealth") > 0.0f) {
		return ("health");
	}

	if (entityDef.GetFloat(pickupEnt.classname, "tf_ammoFraction") > 0.0f) {
		return ("ammo");
	}

	if (entityDef.GetFloat(pickupEnt.classname, "inv_ammo_shells") > 0.0f) {
		return ("ammo");
	}

	return ("");
}

/** How much the pickup gives. Health kits return hit points; ammo packs
return the fraction of a full load they refill (0 to 1). */
float
TF_PickupAmount(entity pickupEnt)
{
	if (TF_PickupKind(pickupEnt) == "health") {
		return entityDef.GetFloat(pickupEnt.classname, "inv_health");
	}

	return entityDef.GetFloat(pickupEnt.classname, "tf_ammoFraction");
}

/** Whether the pickup is there to be taken (not waiting to respawn). */
bool
TF_PickupAvailable(entity pickupEnt)
{
	if (pickupEnt.solid == SOLID_NOT) {
		return (false);
	}

	if (pickupEnt.effects & EF_NODRAW) {
		return (false);
	}

	return (pickupEnt.modelindex != 0) ? (true) : (false);
}

/* ---- players ----------------------------------------------------------- */

/** Fills a player's health, armour and every ammo type. */
void
TF_Resupply(entity targetEnt)
{
	ncPlayer thePlayer = (ncPlayer)targetEnt;
	float classHealth = stof(EntityDef_GetKeyValue(thePlayer.classname, "max_health"));

	/* respawning as the same class skips the def's keys, and Nuclide
	   resets a dead player's max health to 100, so restore it from the def */
	if (classHealth > 0) {
		thePlayer.SetMaxHealth(classHealth);
	}

	if (thePlayer.GetHealth() < thePlayer.GetMaxHealth()) {
		thePlayer.SetHealth(thePlayer.GetMaxHealth());
	}

	for (int ammoID = 1i; ammoID < 16i; ammoID++) { /* Nuclide has 16 ammo slots */
		int maxAmmo = ammo.MaxForNum(ammoID);

		if (maxAmmo > 0i) {
			thePlayer.GiveAmmo(ammoID, maxAmmo);
		}
	}
}

/** Rules bridge. The def a player should spawn as for `classDef`: bots use
the "<classDef>_bot" variant when it exists, so they keep their bot class. */
string
TF_ClassDefFor(entity targetEnt, string classDef)
{
	string botDef = strcat(classDef, "_bot");

	/* "spawnclass" is reserved and not readable through entityDef.GetString */
	if (is.Bot(targetEnt) && EntityDef_HasSpawnClass(botDef)) {
		return (botDef);
	}

	return (classDef);
}

/** Rules bridge. Health regeneration for classes with "tf_regen", called
from the rules every player frame. */
void
TF_PlayerThink(entity targetEnt)
{
	ncPlayer thePlayer = (ncPlayer)targetEnt;
	float deltaTime = time - thePlayer.tf_lastRegenTime;

	/* team-only walls (func_respawnroomvisualizer) block by dimension */
	thePlayer.dimension_hit = 255 | TF_DimensionBlocking(thePlayer.team);

	if (deltaTime < 1.0f) {
		return;
	}

	thePlayer.tf_lastRegenTime = time;

	if (thePlayer.tf_regenRate > 0.0f && is.Alive(thePlayer)) {
		float newHealth = thePlayer.GetHealth() + (thePlayer.tf_regenRate * deltaTime);
		thePlayer.SetHealth(min(newHealth, thePlayer.GetMaxHealth()));
	}
}

/* ---- rules bridge ------------------------------------------------------ */

/** Tells the rules progs about an objective event. They receive it through
CodeCallback_Input(activator, eventName, data). */
void
TF_RulesEvent(string eventName, entity activatorEnt, string eventData)
{
	ncRuleDelegate activeRules = ncRuleDelegate::ActiveInstance();

	if (activeRules) {
		activeRules.Input(activatorEnt, eventName, eventData);
	}
}

/** Asks the rules progs whether something may happen. The rules allow it
unless they define a function called `checkName` taking (entity, float) and
it returns false. The template's checks are:
- TFRules_AllowFlagPickup(player, flag team)
- TFRules_AllowFlagCapture(carrier, carried flag's team)
- TFRules_AllowPointCapture(point, capturing team) */
bool
TF_RulesAllow(string checkName, entity targetEnt, float checkValue)
{
	if (g_ruleCProgs) {
		float(entity, float) ruleCheck = externvalue(g_ruleCProgs, checkName);

		if (ruleCheck) {
			return ruleCheck(targetEnt, checkValue) ? (true) : (false);
		}
	}

	return (true);
}

/** Rules bridge. Loads maps/<map>_<g_gametype>.add if it exists, so one map
can carry different objective overlays per mode. maps/<map>.add is already
loaded by Nuclide for every mode. Returns true when a file was loaded. */
bool
TF_LoadOverlay(void)
{
	string overlayFile = sprintf("maps/%s_%s.add", mapname, cvars.GetString("g_gametype"));

	if (fileExists(overlayFile) == false) {
		return (false);
	}

	ncLog("Loading %s objectives from %S", cvars.GetString("g_gametype"), overlayFile);
	return ncMapDelegate::AppendEntitiesFromFile(overlayFile);
}

/** Rules bridge. Puts every objective back in its start state for a new round. */
void
TF_ResetObjectives(void)
{
	for (entity e = world; (e = TF_NextObjective(e));) {
		ncEntity theObjective = (ncEntity)e;
		theObjective.Respawn();
	}

	for (entity p = world; (p = next.Player(p));) {
		p.tf_carriedFlag = __NULL__;
	}
}

/** Rules bridge. Puts the whole map back as it spawned, like Team
Fortress 2's full map reset: doors close, paths re-enable, carts go home. */
void
TF_ResetMap(void)
{
	/* only what the map placed: carried weapons and players stay */
	for (entity e = world; (e = findfloat(e, ::_mapspawned, true));) {
		if (is.Player(e) || e.owner) {
			continue;
		}

		ncEntity mapEnt = (ncEntity)e;
		mapEnt.Respawn();
	}

	/* outputs that fire a limited number of times count again */
	for (entity o = world; (o = find(o, ::classname, "triggerminion"));) {
		ncOutput theOutput = (ncOutput)o;
		theOutput.Respawn();
	}
}

/** Rules bridge. Locks or unlocks every control point. */
void
TF_LockAllPoints(float lockState)
{
	for (entity e = world; (e = TF_NextObjective(e));) {
		if (e.tf_objective == TFOBJ_POINT) {
			tfControlPoint thePoint = (tfControlPoint)e;
			thePoint.SetLocked(lockState ? true : false);
		}
	}
}

/** Rules bridge. A compact description of every objective for the HUD:
space separated tokens, one per objective.
- flags: f<team><state>, e.g. "f10" is RED's flag at home
- points: p<index>:<owner>:<capteam>:<progress 0-100>:<locked>:<contested>
- payload carts: c<team>:<progress 0-100>:<pushers>:<state>
Capture zones are left out. */
string
TF_ObjectiveSummary(void)
{
	string summary = "";

	for (entity e = world; (e = TF_NextObjective(e));) {
		if (e.tf_objective == TFOBJ_FLAG) {
			summary = sprintf("%s f%d%d", summary, e.team, e.tf_flagState);
		} else if (e.tf_objective == TFOBJ_POINT) {
			summary = sprintf("%s p%d:%d:%d:%d:%d:%d", summary, e.tf_cpIndex, e.team,
				e.tf_cpCapTeam, rint(e.tf_cpProgress * 100), e.tf_cpLocked, e.tf_cpContested);
		} else if (e.tf_objective == TFOBJ_CART) {
			summary = sprintf("%s c%d:%d:%d:%d", summary, e.team, floor(e.tf_cartProgress * 100),
				e.tf_cartPushers, e.tf_cartState);
		}
	}

	return (summary);
}
