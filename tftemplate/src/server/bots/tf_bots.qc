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


/** @file tf_bots.qc
Team Fortress bots on the Bulwark bot framework (bwbots/).

A bot is a fake client that joins like a player (`sv addBot`). The rules pick
its team and class and spawn it from the class's "_bot" def as tfBotPawn, which
is a tfPlayer whose input frame comes from the framework instead of a network
connection: ncPlayer::ServerInputFrame calls RunAI(), which runs the bot and
fills input_angles, input_movevalues and input_buttons like a player would,
then the template's own player physics, weapons and objectives take over.

What the bots do, in the framework's terms:
- TFBotMain looks for threats, picks a weapon for the range from the class's
  "tf_weaponRanges" and fires when its crosshair (aim error included) is on
  the target. Getting shot makes the attacker known even when unseen.
- TFBotTactical goes for health when low and for ammo when only melee is left.
- Under that, one job by the class's "tf_role":
  - offense and defense: TFBotObjective plays TF_ObjectiveFor(): stands on
    the point (spread around it when defending), takes and carries the enemy
    flag, escorts a carrier. Defenders in CTF guard their own flag instead.
  - sniper: TFBotSniper takes a waypoint that can see the objective from our
    side and watches it.
  - support: TFBotObjective in escort mode follows the teammate fighting
    closest to the objective.

Cvars: bot_skill 1-3 (aim error, reaction and turn speed), tfbot_report N
(prints every bot's state every N seconds). The framework's bot_* console
commands (bot_status, bot_debug ...) reach it through the rules. */

class
tfBotPawn:BWBot
{
public:
	void tfBotPawn(void);

	string m_role;
	string m_wname[4];		/* from tf_weaponRanges, best first */
	float m_wmin[4];
	float m_wmax[4];
	float m_wcount;
	float m_wchoice;		/* index of the weapon we want, -1 none */
	float m_nextSwitch;
	float m_nextFiredNote;
	float m_deadToggle;
	float m_nextOverlapCheck;
	vector m_home;			/* where we last spawned */
	entity m_lastAttacker;
	float m_lastHurt;

	virtual void RunAI(void);
	virtual float IsEnemy(entity);
	virtual float IsFriend(entity);
	virtual BWAction InitialAction(void);

	nonvirtual void ReadClass(void);
	nonvirtual void ChooseWeapon(float);
	nonvirtual float HasRangedAmmo(void);
	nonvirtual float WeaponReady(float);
	nonvirtual float IsProjectile(void);
	nonvirtual void Unstick(void);
};

var float autocvar_tfbot_report = 0;
float g_tfbotNextReport;
void TFBot_Report(void);
string TF_ObjectiveSummary(void);

void
tfBotPawn::tfBotPawn(void)
{
	/* runs again on every class change: keep the framework's state */
}

float
tfBotPawn::IsEnemy(entity e)
{
	if (!e || e == this) {
		return (FALSE);
	}

	if (e.takedamage == DAMAGE_NO || e.health <= 0) {
		return (FALSE);
	}

	return (e.team == TF_EnemyTeam(team)) ? (TRUE) : (FALSE);
}

float
tfBotPawn::IsFriend(entity e)
{
	if (!e || e == this) {
		return (FALSE);
	}

	return (e.team == team) ? (TRUE) : (FALSE);
}

/** The class def's keys the bot plays by. */
void
tfBotPawn::ReadClass(void)
{
	float n, i;

	m_role = entityDef.GetString(classname, "tf_role");
	n = tokenize_console(entityDef.GetString(classname, "tf_weaponRanges"));
	m_wcount = 0;

	for (i = 0; i + 2 < n && m_wcount < 4; i += 3) {
		m_wname[m_wcount] = argv(i);
		m_wmin[m_wcount] = stof(argv(i + 1));
		m_wmax[m_wcount] = stof(argv(i + 2));
		m_wcount++;
	}

	m_wchoice = -1;
}

/** The weapon in slot i is in the inventory with something to shoot. */
float
tfBotPawn::WeaponReady(float i)
{
	ncWeapon w;

	if (!HasItem(m_wname[i])) {
		return (FALSE);
	}

	w = (ncWeapon)GetItem(m_wname[i]);

	if (!w) {
		return (FALSE);
	}

	return (w.IsEmpty()) ? (FALSE) : (TRUE);
}

/** Something better than melee left to shoot. */
float
tfBotPawn::HasRangedAmmo(void)
{
	for (float i = 0; i < m_wcount; i++) {
		if (m_wmax[i] > 96 && WeaponReady(i)) {
			return (TRUE);
		}
	}

	return (FALSE);
}

/** Rockets and grenades: aim at the feet, with lead. */
float
tfBotPawn::IsProjectile(void)
{
	string w;

	if (m_wchoice < 0) {
		return (FALSE);
	}

	w = m_wname[m_wchoice];

	if (strstrofs(w, "rocket") >= 0 || strstrofs(w, "grenade") >= 0) {
		return (TRUE);
	}

	return (FALSE);
}

/** The first weapon, best first, whose range covers dist; failing that the
first one with ammo. Switches at most once a second. */
void
tfBotPawn::ChooseWeapon(float dist)
{
	float i, pick = -1, fallback = -1;

	if (time < m_nextSwitch) {
		return;
	}

	for (i = 0; i < m_wcount; i++) {
		if (!WeaponReady(i)) {
			continue;
		}

		if (fallback < 0) {
			fallback = i;
		}

		if (dist >= m_wmin[i] && dist <= m_wmax[i]) {
			pick = i;
			break;
		}
	}

	if (pick < 0) {
		pick = fallback;
	}

	if (pick < 0) {
		return;
	}

	m_wchoice = pick;

	if (GetCurrentWeapon() != m_wname[pick]) {
		SwitchToWeapon(m_wname[pick]);
		m_nextSwitch = time + 1.0f;
	}
}

/** Spawn points don't check who is standing on them, and the player physics
can't move a player out of another one. A bot that finds itself inside
another player steps to the nearest open spot. */
void
tfBotPawn::Unstick(void)
{
	vector spot;
	float a, r;

	if (time < m_nextOverlapCheck) {
		return;
	}

	m_nextOverlapCheck = time + 0.5f;
	tracebox(origin, mins, maxs, origin, MOVE_NORMAL, this);

	if (!trace_startsolid || !(trace_ent.flags & FL_CLIENT)) {
		return;
	}

	for (r = 40; r <= 120; r += 40) {
		for (a = 0; a < 360; a += 45) {
			spot = origin + [cos(a * (M_PI / 180)) * r, sin(a * (M_PI / 180)) * r, 0];
			tracebox(spot, mins, maxs, spot, MOVE_NORMAL, this);

			if (trace_startsolid) {
				continue;
			}

			/* somewhere we can walk back from */
			traceline(origin, spot, MOVE_NOMONSTERS, this);

			if (trace_fraction < 1) {
				continue;
			}

			setorigin(this, spot);
			bw_log(this, BWD_LOCOMOTION, sprintf("stepped out of another player to %v", spot));
			return;
		}
	}
}

/** The input frame: Nuclide calls this from ServerInputFrame, right before
the player physics. */
void
tfBotPawn::RunAI(void)
{
	input_buttons = 0;
	input_movevalues = [0, 0, 0];
	input_angles = v_angle;

	if (!m_loco) {
		return;
	}

	if (IsAlive()) {
		Unstick();
	}

	bw_player_input(this);

	if (IsAlive() == false) {
		/* tap fire to respawn, as players do */
		input_movevalues = [0, 0, 0];
		m_deadToggle = 1 - m_deadToggle;
		input_buttons = (m_deadToggle) ? INPUT_PRIMARY : 0;
	} else if (input_buttons & INPUT_PRIMARY) {
		if (time > m_nextFiredNote) {
			m_nextFiredNote = time + 0.5f;
			bw_notify_weapon_fired(this, m_activeWeapon);
		}
	}

	button0 = input_buttons & INPUT_PRIMARY;
	button2 = input_buttons & INPUT_JUMP;
	button3 = input_buttons & INPUT_PRONE;
	button4 = input_buttons & INPUT_RELOAD;
	button5 = input_buttons & INPUT_SECONDARY;
	button6 = input_buttons & INPUT_USE;
	button7 = input_buttons & INPUT_SPRINT;
	button8 = input_buttons & INPUT_CROUCH;
	movement = input_movevalues;

	if (autocvar_tfbot_report > 0 && this == bw_bots && time > g_tfbotNextReport) {
		g_tfbotNextReport = time + autocvar_tfbot_report;
		TFBot_Report();
	}
}

/** Prints every bot's state; tfbot_report N does this every N seconds. */
void
TFBot_Report(void)
{
	entity obj;

	print(sprintf("^3[tfbot %.1f]^7 objectives:%s\n", time, TF_ObjectiveSummary()));
	for (BWBot b = bw_bots; b; b = b.m_bot_next) {
		tfBotPawn p = (tfBotPawn)b;
		obj = TF_ObjectiveFor(p.team);
		print(sprintf("  %s %s %s hp %d at %v kills %d deaths %d obj %s: %s\n", p.netname, TF_TeamName(p.team),
			substring(p.classname, 8, -5), p.health, p.origin, p.frags, p.deaths,
			obj ? etos(obj) : "none", p.m_intention.StackString()));
	}
}

/* ---- respawning ---------------------------------------------------------- */

/** Rules bridge. Called after every bot spawn (TF_SpawnPlayer). The first
spawn starts the bot; later ones start its behaviour over. Speeds and jump
height come from the class. */
void
bw_bot_respawned(entity botEnt)
{
	tfBotPawn b;
	ncPlayer pl;
	float jumpVel, grav, sk;

	if (botEnt.spawnclass != "tfBotPawn") {
		return; /* not one of ours */
	}

	b = (tfBotPawn)botEnt;
	pl = (ncPlayer)botEnt;
	b.ReadClass();
	b.m_home = b.origin;

	if (!b.m_loco) {
		b.BotStart();
	} else {
		b.BotRespawn();
	}

	b.m_loco.m_run_speed = entityDef.GetFloat(b.classname, "pm_runspeed");

	if (b.m_loco.m_run_speed <= 0) {
		b.m_loco.m_run_speed = 320;
	}

	b.m_loco.m_walk_speed = b.m_loco.m_run_speed * 0.5f;
	b.m_loco.Run();

	jumpVel = g_pmoveVars.pm_jumpheight;
	grav = g_pmoveVars.pm_gravity;

	if (pl.m_pmoveVars) {
		if (pl.m_pmoveVars.pm_jumpheight > 0) {
			jumpVel = pl.m_pmoveVars.pm_jumpheight;
		}

		if (pl.m_pmoveVars.pm_gravity > 0) {
			grav = pl.m_pmoveVars.pm_gravity;
		}
	}

	if (jumpVel > 0 && grav > 0) {
		b.m_loco.m_max_jump = jumpVel * jumpVel / (2 * grav) - 2;
	}

	if (g_pmoveVars.pm_stepsize > 0) {
		b.m_loco.m_step = g_pmoveVars.pm_stepsize;
	}

	/* skill: aim error, how quickly the view tracks, reaction time */
	sk = bound(0, cvar("bot_skill"), 3);
	b.m_body.m_aim_error = (b.m_role == "sniper") ? (2.5 - 0.5 * sk) * 0.4 : (2.5 - 0.5 * sk) * 1.5;
	b.m_body.m_track_rate = 5 + 2 * sk;
	b.m_body.m_head_rate = 300 + 100 * sk;
	b.m_vision.m_reaction = ((b.m_role == "sniper") ? 0.25 : 0.1) + 0.3 - 0.1 * sk;
}

/* ---- helpers ------------------------------------------------------------- */

/** The middle of an objective (brush entities have their origin at 0 0 0). */
vector
TFBot_ObjectiveCenter(entity obj)
{
	if (obj.tf_objective == TFOBJ_POINT && obj.tf_cpArea) {
		return (obj.tf_cpArea.absmin + obj.tf_cpArea.absmax) * 0.5;
	}

	if (obj.tf_objective == TFOBJ_CAPZONE) {
		return (obj.absmin + obj.absmax) * 0.5;
	}

	return (obj.origin);
}

/** Somewhere open to stand: inside the point's capture area when radius is 0,
otherwise within radius of the objective. */
vector
TFBot_SpotNear(BWBot b, entity obj, float radius)
{
	vector ctr = TFBot_ObjectiveCenter(obj), lo, hi, p;
	float a, d;
	entity area = __NULL__;

	if (obj.tf_objective == TFOBJ_POINT) {
		area = obj.tf_cpArea;
	}

	if (radius <= 0 && area) {
		lo = area.absmin + [16, 16, 0];
		hi = area.absmax - [16, 16, 0];
		p = [lo[0] + random() * (hi[0] - lo[0]), lo[1] + random() * (hi[1] - lo[1]), ctr[2]];
	} else {
		if (radius <= 0) {
			radius = 64;
		}

		a = random() * 2 * M_PI;
		d = random() * radius;
		p = ctr + [cos(a) * d, sin(a) * d, 0];
	}

	tracebox(ctr, b.mins, b.maxs, p, MOVE_NOMONSTERS, b);
	return bw_stand_at(b, trace_endpos);
}

/** The teammate carrying a flag, if any. */
entity
TFBot_FlagCarrier(float teamID)
{
	for (entity e = world; (e = next.Player(e));) {
		if (e.team == teamID && e.tf_carriedFlag && e.health > 0) {
			return (e);
		}
	}

	return (world);
}

/** Our own flag in CTF. */
entity
TFBot_OwnFlag(float teamID)
{
	for (entity e = world; (e = TF_NextObjective(e));) {
		if (e.tf_objective == TFOBJ_FLAG && e.team == teamID) {
			return (e);
		}
	}

	return (world);
}

/** The nearest pickup of a kind ("health" or "ammo") that is there. */
entity
TFBot_NearestPickup(vector from, string kind)
{
	float d, bestDist = 999999;
	entity best = world;

	for (entity e = world; (e = TF_NextPickup(e));) {
		if (TF_PickupKind(e) != kind) {
			continue;
		}

		if (!TF_PickupAvailable(e)) {
			continue;
		}

		d = vlen(e.origin - from);

		if (d < bestDist) {
			bestDist = d;
			best = e;
		}
	}

	return (best);
}

/** Where to put the crosshair on a target for the weapon in hand. */
vector
TFBot_AimPoint(tfBotPawn b, entity t)
{
	float d = vlen(t.origin - b.origin);

	if (b.m_role == "sniper" && d > 400) {
		return t.origin + [0, 0, t.maxs[2] - 6];
	}

	if (b.IsProjectile()) {
		if (t.flags & FL_ONGROUND) {
			return t.origin + [0, 0, t.mins[2] + 4] + bw_flat(t.velocity) * (d / 1000);
		}

		return t.origin + t.velocity * (d / 1000);
	}

	return t.origin + [0, 0, t.maxs[2] * 0.4];
}

/** The crosshair is on where the bot believes p is (aim error included),
with nothing solid in the way. */
float
TFBot_OnTarget(tfBotPawn b, vector p, float radius)
{
	vector aim = b.m_body.m_aim_pos;

	if (vlen(aim - p) > 150) {
		return (FALSE); /* still swinging over from somewhere else */
	}

	if (!b.m_body.IsAimingAt(aim, radius)) {
		return (FALSE);
	}

	traceline(b.m_body.GetEyePosition(), p, MOVE_NOMONSTERS, b);
	return (trace_fraction == 1) ? (TRUE) : (FALSE);
}

/** Every think: look at and shoot the most dangerous visible enemy. */
void
TFBot_Combat(tfBotPawn b)
{
	BWKnown k = b.m_vision.GetPrimaryKnownThreat(TRUE);
	entity t;
	float d, radius;

	if (!k) {
		/* shot by someone out of view: turn to look */
		if (b.m_lastAttacker && time - b.m_lastHurt < 1) {
			if (b.m_lastAttacker.health > 0) {
				b.m_body.AimHeadTowards(b.m_lastAttacker.origin, BWLOOK_IMPORTANT, 0.5, __NULL__, "who shot me");
			}
		}

		b.ChooseWeapon(600);
		return;
	}

	t = k.m_subject;
	d = vlen(t.origin - b.origin);
	b.ChooseWeapon(d);
	b.m_body.AimHeadTowardsEntity(t, BWLOOK_IMPORTANT, 0.3, __NULL__, "combat");

	if (b.m_wchoice < 0) {
		return;
	}

	/* out of this weapon's reach, or too close for its splash */
	if (d > b.m_wmax[b.m_wchoice] * 1.25 || d < b.m_wmin[b.m_wchoice] * 0.5) {
		return;
	}

	radius = (b.m_wmax[b.m_wchoice] <= 96) ? 40 : 28;

	if (b.m_role == "sniper") {
		radius = 10;
	} else if (b.IsProjectile()) {
		radius = 48;
	}

	if (TFBot_OnTarget(b, b.m_intention.SelectTargetPoint(t), radius)) {
		b.PressButton(BWIN_ATTACK, 0.15);
	}
}

/* ---- behaviours ---------------------------------------------------------- */

class TFBotMain:BWAction
{
	virtual string GetName(void) { return "TFBotMain"; };
	virtual BWAction InitialChild(void);
	virtual float Update(float);
	virtual vector SelectTargetPoint(entity);
	virtual float OnInjured(entity, entity, float);
};

class TFBotTactical:BWAction
{
	virtual string GetName(void) { return "Tactical"; };
	virtual BWAction InitialChild(void);
	virtual float Update(float);
	virtual float OnStuck(void);
};

/** Plays the objective; with m_escort set it follows a fighting teammate
instead, while there is one. */
class TFBotObjective:BWAction
{
	BWPathFollower m_path;
	BWChasePath m_chase;
	float m_escort;
	entity m_obj;
	vector m_spot;
	vector m_spotFor;		/* the objective's position when the spot was picked */
	float m_spotOwner;
	float m_nextSpot;
	float m_nextRepath;
	float m_strafeUntil;
	vector m_strafe;

	virtual string GetName(void) { return m_escort ? "Escort" : "Objective"; };
	virtual float OnStart(BWAction);
	virtual float Update(float);
	virtual float OnMoveToFailure(BWPath, float);
	nonvirtual float GoTo(vector, float);
	nonvirtual void Hold(float);
	nonvirtual float Chase(entity, float);
	nonvirtual entity PickBuddy(void);
	nonvirtual void PickSpot(void);
};

class TFBotSniper:BWAction
{
	BWPathFollower m_path;
	vector m_spot;
	float m_nextRepath;
	float m_moveAt;
	virtual string GetName(void) { return "Sniper"; };
	virtual float OnStart(BWAction);
	virtual float Update(float);
	virtual float OnInjured(entity, entity, float);
	virtual float OnMoveToFailure(BWPath, float);
	nonvirtual void PickSpot(void);
};

/** Goes for a health or ammo pickup. */
class TFBotGetPickup:BWAction
{
	BWPathFollower m_path;
	entity m_pickup;
	string m_kind;
	float m_giveUp;
	virtual string GetName(void) { return strcat("Get ", m_kind); };
	virtual float OnStart(BWAction);
	virtual float Update(float);
	virtual float OnMoveToFailure(BWPath, float);
	nonvirtual float Satisfied(void);
};

BWAction
tfBotPawn::InitialAction(void)
{
	return spawn(TFBotMain);
}

BWAction
TFBotMain::InitialChild(void)
{
	return spawn(TFBotTactical);
}

float
TFBotMain::Update(float interval)
{
	TFBot_Combat((tfBotPawn)m_bot);
	return Continue();
}

vector
TFBotMain::SelectTargetPoint(entity subject)
{
	return TFBot_AimPoint((tfBotPawn)m_bot, subject);
}

/** Whoever shot us is someone to know about. */
float
TFBotMain::OnInjured(entity inflictor, entity attacker, float damage)
{
	tfBotPawn b = (tfBotPawn)m_bot;

	if (attacker && attacker != m_bot && (attacker.flags & FL_CLIENT)) {
		if (b.IsEnemy(attacker)) {
			b.m_vision.AddKnownEntity(attacker);
			b.m_lastAttacker = attacker;
			b.m_lastHurt = time;
		}
	}

	return (BWR_CONTINUE);
}

BWAction
TFBotTactical::InitialChild(void)
{
	tfBotPawn b = (tfBotPawn)m_bot;
	TFBotObjective o;

	if (b.m_role == "sniper") {
		return spawn(TFBotSniper);
	}

	o = spawn(TFBotObjective);
	o.m_escort = (b.m_role == "support") ? TRUE : FALSE;
	return (o);
}

float
TFBotTactical::Update(float interval)
{
	tfBotPawn b = (tfBotPawn)m_bot;
	TFBotGetPickup g;

	if (b.health < b.GetMaxHealth() * 0.4 && !b.tf_carriedFlag) {
		if (TFBot_NearestPickup(b.origin, "health")) {
			g = spawn(TFBotGetPickup, m_kind: "health");
			return SuspendFor(g, "low health");
		}
	}

	if (!b.HasRangedAmmo() && !b.tf_carriedFlag) {
		if (TFBot_NearestPickup(b.origin, "ammo")) {
			g = spawn(TFBotGetPickup, m_kind: "ammo");
			return SuspendFor(g, "out of ammo");
		}
	}

	return Continue();
}

/** A player who can't get anywhere jumps, as players do. */
float
TFBotTactical::OnStuck(void)
{
	m_bot.m_loco.Jump(0);
	return (BWR_CONTINUE);
}

/* ---- the objective ------------------------------------------------------- */

float
TFBotObjective::OnStart(BWAction prior)
{
	m_path = spawn(BWPathFollower);
	Own(m_path);
	m_chase = spawn(BWChasePath, m_lead: 0);
	Own(m_chase);
	m_spotOwner = -1;
	return Continue();
}

/** Walks the path to pos; true once there. */
float
TFBotObjective::GoTo(vector pos, float near)
{
	if (bw_dist2d(m_bot.origin, pos) <= near && fabs(m_bot.origin[2] - pos[2]) < 40) {
		return (TRUE);
	}

	if (!m_path.IsValid() || time > m_nextRepath) {
		m_path.Compute(m_bot, pos, 0);
		m_nextRepath = time + 3;
	}

	m_path.Follow(m_bot);
	return (FALSE);
}

/** Holds the spot; dodges about it while someone is shooting. */
void
TFBotObjective::Hold(float leash)
{
	BWKnown k = m_bot.m_vision.GetPrimaryKnownThreat(TRUE);
	vector f;

	if (!k) {
		m_bot.m_loco.Stop();

		if (m_obj) {
			m_bot.m_body.AimHeadTowards(m_spot + bw_flat(m_spot - TFBot_ObjectiveCenter(m_obj)) * 4 + [0, 0, 24],
				BWLOOK_INTERESTING, 1, __NULL__, "watching");
		}

		return;
	}

	if (time > m_strafeUntil) {
		f = normalize(bw_flat(k.m_subject.origin - m_bot.origin));
		m_strafe = [-f[1], f[0], 0] * ((random() < 0.5) ? 1 : -1);
		m_strafeUntil = time + 0.4 + random() * 0.6;

		if (((tfBotPawn)m_bot).m_role == "offense" && random() < 0.25) {
			m_bot.m_loco.Jump(0);
		}
	}

	if (bw_dist2d(m_bot.origin + m_strafe * 48, m_spot) > leash) {
		m_strafe = -m_strafe;
	}

	m_bot.m_loco.Approach(m_bot.origin + m_strafe * 64, 1);
	m_bot.m_loco.ClearStuck(); /* dodging about one spot isn't being stuck */
}

/** Keeps within dist of a moving teammate or enemy. */
float
TFBotObjective::Chase(entity who, float dist)
{
	if (vlen(who.origin - m_bot.origin) > dist) {
		m_chase.Chase(m_bot, who);
		return (FALSE);
	}

	return (TRUE);
}

/** The teammate fighting closest to the objective (not a support or sniper). */
entity
TFBotObjective::PickBuddy(void)
{
	entity best = world;
	float d, bestScore = 999999;
	vector goal = m_obj ? TFBot_ObjectiveCenter(m_obj) : m_bot.origin;

	for (entity e = world; (e = next.Player(e));) {
		if (e == m_bot || e.team != m_bot.team || e.health <= 0) {
			continue;
		}

		if (e.takedamage == DAMAGE_NO) {
			continue;
		}

		string role = entityDef.GetString(e.classname, "tf_role");

		if (role == "support" || role == "sniper") {
			continue;
		}

		d = vlen(e.origin - goal);

		if (e.tf_carriedFlag) {
			d -= 2000; /* a flag carrier needs company most */
		}

		if (d < bestScore) {
			bestScore = d;
			best = e;
		}
	}

	return (best);
}

/** Attackers stand in the capture area; defenders spread out around it. */
void
TFBotObjective::PickSpot(void)
{
	float radius = 0;

	if (m_obj.tf_objective == TFOBJ_POINT) {
		if (m_obj.team == m_bot.team) {
			radius = 250;
		}
	} else if (m_obj.tf_objective == TFOBJ_FLAG) {
		radius = 350;
	}

	m_spot = TFBot_SpotNear(m_bot, m_obj, radius);
	m_spotFor = TFBot_ObjectiveCenter(m_obj);
	m_spotOwner = m_obj.team;
	m_nextSpot = time + 8 + random() * 6;
	m_path.Invalidate();
	m_nextRepath = 0;
}

float
TFBotObjective::Update(float interval)
{
	tfBotPawn b = (tfBotPawn)m_bot;
	entity obj = TF_ObjectiveFor(b.team), carrier, buddy, own;

	/* CTF defenders guard their own flag, or go after whoever took it */
	if (b.m_role == "defense" && TF_Mode() == "ctf" && !b.tf_carriedFlag) {
		own = TFBot_OwnFlag(b.team);

		if (own) {
			if (own.tf_flagState == TFFLAG_CARRIED && own.tf_flagCarrier) {
				Chase(own.tf_flagCarrier, 64);
				return Continue();
			}

			obj = own;
		}
	}

	if (obj != m_obj) {
		m_obj = obj;
		m_spotOwner = -1;
	}

	if (!m_obj) {
		/* nothing to do: wander between waypoints */
		if (time > m_nextSpot && bw_wp_load()) {
			m_spot = bw_stand_at(b, bw_wps[floor(random() * bw_wp_count)].pos);
			m_nextSpot = time + 20;
			m_path.Invalidate();
		}

		if (GoTo(m_spot, 64)) {
			m_nextSpot = 0;
		}

		return Continue();
	}

	if (m_escort) {
		buddy = PickBuddy();

		if (buddy) {
			Chase(buddy, 220);
			return Continue();
		}
	}

	/* flags move: carry it home, follow the one carrying it, or go get it */
	if (m_obj.tf_objective == TFOBJ_CAPZONE) {
		if (b.tf_carriedFlag) {
			GoTo(TFBot_ObjectiveCenter(m_obj), 16);
			return Continue();
		}

		carrier = TFBot_FlagCarrier(b.team);

		if (carrier) {
			Chase(carrier, 180);
			return Continue();
		}
	}

	if (m_obj.tf_objective == TFOBJ_FLAG && m_obj.team != b.team) {
		if (vlen(m_obj.origin - m_spotFor) > 48) {
			m_spotFor = m_obj.origin;
			m_path.Invalidate();
		}

		GoTo(m_obj.origin, 8);
		return Continue();
	}

	/* our own flag lying about: touch it to send it home */
	if (m_obj.tf_objective == TFOBJ_FLAG && m_obj.tf_flagState == TFFLAG_DROPPED) {
		GoTo(m_obj.origin, 8);
		return Continue();
	}

	if (m_obj.team != m_spotOwner || vlen(TFBot_ObjectiveCenter(m_obj) - m_spotFor) > 64) {
		PickSpot();
	} else if (time > m_nextSpot && m_obj.team == b.team) {
		PickSpot(); /* defenders move about */
	}

	if (GoTo(m_spot, 40)) {
		Hold((m_obj.team == b.team) ? 160 : 80);
	}

	return Continue();
}

float
TFBotObjective::OnMoveToFailure(BWPath path, float reason)
{
	if (path == m_path) {
		m_spotOwner = -1; /* try another spot */
		m_nextSpot = 0;
		m_bot.m_loco.Jump(0);
	}

	return (BWR_CONTINUE);
}

/* ---- the sniper ---------------------------------------------------------- */

float
TFBotSniper::OnStart(BWAction prior)
{
	m_path = spawn(BWPathFollower);
	Own(m_path);
	PickSpot();
	return Continue();
}

/** A waypoint 600 to 1600 from the objective, on our side of it, that can
see it. */
void
TFBotSniper::PickSpot(void)
{
	tfBotPawn b = (tfBotPawn)m_bot;
	entity obj = TF_ObjectiveFor(b.team);
	vector goal, p, pick = b.origin;
	float i, d, n = 0;

	m_moveAt = time + 40 + random() * 20;
	m_path.Invalidate();
	m_nextRepath = 0;

	if (!obj || !bw_wp_load()) {
		m_spot = pick;
		return;
	}

	goal = TFBot_ObjectiveCenter(obj);

	for (i = 0; i < bw_wp_count; i++) {
		p = bw_stand_at(b, bw_wps[i].pos);
		d = vlen(p - goal);

		if (d < 600 || d > 1600) {
			continue;
		}

		if (vlen(p - b.m_home) > vlen(goal - b.m_home)) {
			continue; /* the far side */
		}

		traceline(p + b.view_ofs, goal, MOVE_NOMONSTERS, b);

		if (trace_fraction < 1) {
			continue;
		}

		n++;

		if (random() * n < 1) {
			pick = p;
		}
	}

	m_spot = (n > 0) ? pick : bw_stand_at(b, goal);
}

float
TFBotSniper::Update(float interval)
{
	tfBotPawn b = (tfBotPawn)m_bot;
	entity obj;

	if (time > m_moveAt) {
		PickSpot();
	}

	if (bw_dist2d(b.origin, m_spot) > 40) {
		if (!m_path.IsValid() || time > m_nextRepath) {
			m_path.Compute(b, m_spot, 0);
			m_nextRepath = time + 3;
		}

		m_path.Follow(b);
		return Continue();
	}

	b.m_loco.Stop();
	obj = TF_ObjectiveFor(b.team);

	if (obj && !b.m_vision.GetPrimaryKnownThreat(TRUE)) {
		b.m_body.AimHeadTowards(TFBot_ObjectiveCenter(obj), BWLOOK_INTERESTING, 1, __NULL__, "watching the objective");
	}

	return Continue();
}

/** Shot at while set up: find somewhere else. */
float
TFBotSniper::OnInjured(entity inflictor, entity attacker, float damage)
{
	if (m_bot.health < m_bot.GetMaxHealth() * 0.6) {
		m_moveAt = time;
	}

	return (BWR_CONTINUE);
}

float
TFBotSniper::OnMoveToFailure(BWPath path, float reason)
{
	if (path == m_path) {
		m_moveAt = time;
	}

	return (BWR_CONTINUE);
}

/* ---- pickups ------------------------------------------------------------- */

float
TFBotGetPickup::Satisfied(void)
{
	tfBotPawn b = (tfBotPawn)m_bot;

	if (m_kind == "health") {
		return (b.health >= b.GetMaxHealth() * 0.9) ? (TRUE) : (FALSE);
	}

	return b.HasRangedAmmo();
}

float
TFBotGetPickup::OnStart(BWAction prior)
{
	m_path = spawn(BWPathFollower);
	Own(m_path);
	m_pickup = TFBot_NearestPickup(m_bot.origin, m_kind);
	m_giveUp = time + 20;

	if (!m_pickup) {
		return Done("none about");
	}

	m_path.Compute(m_bot, m_pickup.origin, 0);
	return Continue();
}

float
TFBotGetPickup::Update(float interval)
{
	if (Satisfied()) {
		return Done("got it");
	}

	if (time > m_giveUp) {
		return Done("took too long");
	}

	if (!TF_PickupAvailable(m_pickup)) {
		m_pickup = TFBot_NearestPickup(m_bot.origin, m_kind);

		if (!m_pickup) {
			return Done("all taken");
		}

		m_path.Invalidate();
	}

	if (!m_path.IsValid()) {
		m_path.Compute(m_bot, m_pickup.origin, 0);
	}

	m_path.Follow(m_bot);
	return Continue();
}

float
TFBotGetPickup::OnMoveToFailure(BWPath path, float reason)
{
	if (path == m_path) {
		return TryDone(BWP_IMPORTANT, "can't reach it");
	}

	return (BWR_CONTINUE);
}
