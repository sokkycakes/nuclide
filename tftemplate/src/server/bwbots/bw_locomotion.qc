/* Bulwark bot framework: Locomotion for walking bots. Moves the bot's box
 * through the world itself (the engine's movetypes are bypassed through
 * .customphysics). See docs/spec/bots.md, "Locomotion". ISC licence. */

#define BW_SIDE_FRICTION 10	/* per second, against sliding sideways */
#define BW_AIR_ACCEL 1500

void BWLocomotion::Reset(void)
{
	if (!m_run_speed) m_run_speed = 150;
	if (!m_walk_speed) m_walk_speed = 75;
	if (!m_accel) m_accel = 500;
	if (!m_yaw_rate) m_yaw_rate = 250;
	if (!m_step) m_step = 18;
	if (!m_max_jump) m_max_jump = 180;
	if (!m_slope) m_slope = 0.7;
	if (!m_gravity_scale) m_gravity_scale = 1;
	m_desired_speed = m_run_speed;
	m_pend_weight = 0;
	m_move_until = 0;
	m_face_until = 0;
	m_jumping = m_climbing = 0;
	m_last_good = m_bot.origin;
	m_stuck_anchor = m_bot.origin;
	m_stuck_anchor_time = time;
	m_stuck = 0;
	m_still_since = time;
}

/* requests made at the think rate stay in force a little over one think */
float bw_request_hold(void)
{
	float rate = bw_cvar("bot_think_rate");
	if (rate <= 0)
		rate = 10;
	return max(0.15, 1.5 / rate);
}

void BWLocomotion::Approach(vector goal, float weight)
{
	vector d = bw_flat(goal - m_bot.origin);
	if (weight <= 0)
		weight = 1;
	if (vlen(d) < 0.5)
		return;
	m_pend_dir += normalize(d) * weight;
	m_pend_goal += goal * weight;
	m_pend_weight += weight;
	bw_log(m_bot, BWD_LOCOMOTION, sprintf("approach %v weight %g", goal, weight));
}

void BWLocomotion::FaceTowards(vector pos)
{
	m_face_goal = pos;
	m_face_until = time + bw_request_hold();
}

void BWLocomotion::Stop(void)
{
	m_pend_weight = 0;
	m_pend_dir = '0 0 0';
	m_pend_goal = '0 0 0';
	m_move_until = 0;
}

void BWLocomotion::SetDesiredSpeed(float s) { m_desired_speed = s; }
void BWLocomotion::Run(void) { m_desired_speed = m_run_speed; }
void BWLocomotion::Walk(void) { m_desired_speed = m_walk_speed; }
float BWLocomotion::GetSpeed(void) { return vlen(bw_flat(m_bot.velocity)); }
float BWLocomotion::IsOnGround(void) { return (m_bot.flags & FL_ONGROUND) ? TRUE : FALSE; }
float BWLocomotion::IsClimbingOrJumping(void) { return (m_jumping || m_climbing) ? TRUE : FALSE; }
float BWLocomotion::IsStuck(void) { return m_stuck; }
float BWLocomotion::GetStuckDuration(void) { return m_stuck ? time - m_stuck_since : 0; }
float BWLocomotion::GetStillDuration(void) { return time - m_still_since; }
/* bumped into a player or bot, or saw one in the way, in the last half second */
float BWLocomotion::IsBlockedByActor(void) { return (time - m_actor_blocked < 0.5) ? TRUE : FALSE; }
float BWLocomotion::DrivesInput(void) { return FALSE; }
float BWLocomotion::IsImmobile(void) { return (GetStillDuration() > 1) ? TRUE : FALSE; }

void BWLocomotion::ClearStuck(void)
{
	m_stuck_anchor = m_bot.origin;
	m_stuck_anchor_time = time;
	if (m_stuck) {
		m_stuck = 0;
		bw_ev_clear();
		m_bot.SendEvent(BWE_UNSTUCK);
	}
}

/* --- jumping --------------------------------------------------------------- */

float bw_gravity(BWLocomotion l)
{
	float g = cvar("sv_gravity");
	if (g <= 0)
		g = 800;
	return g * l.m_gravity_scale;
}

void BWLocomotion::Jump(float height)
{
	if (!IsOnGround())
		return;
	height = bound(1, height, m_max_jump);
	m_bot.velocity_z = sqrt(2 * bw_gravity(this) * height);
	m_bot.flags &= ~FL_ONGROUND;
	m_jumping = TRUE;
	bw_ev_clear();
	m_bot.SendEvent(BWE_LEAVE_GROUND);
}

/* a launch at a given velocity, such as a pounce */
void BWLocomotion::Leap(vector vel)
{
	m_bot.velocity = vel;
	m_jumping = TRUE;
	if (m_bot.flags & FL_ONGROUND) {
		m_bot.flags &= ~FL_ONGROUND;
		bw_ev_clear();
		m_bot.SendEvent(BWE_LEAVE_GROUND);
	}
}

/* a ballistic jump that comes down on the landing point */
float BWLocomotion::JumpAcrossGap(vector landing, vector fwd)
{
	float g = bw_gravity(this), apex, vz, t, d;
	vector v;
	if (!IsOnGround())
		return FALSE;
	apex = max(0, landing_z - m_bot.origin_z) + 24;
	if (apex > m_max_jump)
		return FALSE;
	vz = sqrt(2 * g * apex);
	t = vz / g + sqrt(2 * (apex - (landing_z - m_bot.origin_z)) / g);
	d = bw_dist2d(m_bot.origin, landing);
	v = normalize(bw_flat(landing - m_bot.origin)) * min(600, d / t + 16);
	v_z = vz;
	Leap(v);
	m_air_goal = landing;
	m_air_speed = 0;
	bw_log(m_bot, BWD_LOCOMOTION, sprintf("gap jump to %v", landing));
	return TRUE;
}

/* jump straight up with air control towards the ledge: from standing
 * against the face the bot rises past the lip and is pushed on top */
float BWLocomotion::ClimbUpToLedge(vector ledge, vector fwd)
{
	float dz = ledge_z - m_bot.origin_z;
	if (!IsOnGround() || dz > m_max_jump)
		return FALSE;
	m_bot.velocity = bw_flat(fwd) * 20;
	m_bot.velocity_z = sqrt(2 * bw_gravity(this) * (max(dz, 0) + 12));
	m_bot.flags &= ~FL_ONGROUND;
	m_jumping = TRUE;
	m_climbing = TRUE;
	m_air_goal = ledge;
	m_air_speed = max(m_walk_speed, m_run_speed * 0.6);
	m_air_accel = 0;
	bw_log(m_bot, BWD_LOCOMOTION, sprintf("climb to %v (%g up)", ledge, dz));
	bw_ev_clear();
	m_bot.SendEvent(BWE_LEAVE_GROUND);
	return TRUE;
}

/* --- traversability ------------------------------------------------------- */

float BWLocomotion::IsEntityTraversable(entity e, float eventually)
{
	if (!e)
		return FALSE;
	if (e.flags & (FL_CLIENT | FL_MONSTER))
		return TRUE;	/* actors get out of the way */
	if (!eventually)
		return FALSE;
	/* doors open and breakables break */
	if (substring(e.classname, 0, 9) == "func_door")
		return TRUE;
	if (e.takedamage && e.health > 0)
		return TRUE;
	return FALSE;
}

/* a box sweep raised by the step height, so steps don't count */
float BWLocomotion::IsPotentiallyTraversable(vector from, vector to, float eventually)
{
	vector up = '0 0 1' * m_step;
	if (to_z - from_z > m_step + 1)
		return FALSE;
	tracebox(from + up, m_bot.mins, m_bot.maxs, to + up, MOVE_NOMONSTERS, m_bot);
	if (trace_startsolid)
		return FALSE;
	if (trace_fraction < 1 && !IsEntityTraversable(trace_ent, eventually))
		return FALSE;
	return TRUE;
}

/* a drop deeper than a step anywhere along the way */
float BWLocomotion::HasGap(vector from, vector to)
{
	vector d = bw_flat(to - from), p;
	float len = vlen(d), s, ground = from_z + m_bot.mins_z;	/* the feet */
	if (len < 1)
		return FALSE;
	d = normalize(d);
	for (s = 16; s < len + 16; s += 16) {
		if (s > len)
			s = len;
		p = from + d * s;
		p_z = ground + m_step + 1;
		traceline(p, p - '0 0 1' * (2 * m_step + 2), MOVE_NOMONSTERS, m_bot);
		if (!trace_startsolid) {
			if (trace_fraction == 1)
				return TRUE;
			ground = trace_endpos_z;
		}
		if (s >= len)
			break;
	}
	return FALSE;
}

/* --- movement -------------------------------------------------------------- */

void bw_add_contact(BWLocomotion l, entity e)
{
	float i;
	if (!e || e == world)
		return;
	for (i = 0; i < l.m_ncontacts; i++)
		if (l.m_contacts[i] == e)
			return;
	if (l.m_ncontacts < 4)
		l.m_contacts[l.m_ncontacts++] = e;
}

/* sweeps the box, sliding along up to three surfaces; returns the end
 * position and leaves the clipped velocity in bw_slide_vel */
vector bw_slide_vel;
vector BWLocomotion::SlideMove(vector start, vector vel, float dt, float grounded)
{
	vector pos = start, end, n, orig = vel;
	float i, left = dt;
	for (i = 0; i < 3 && left > 0; i++) {
		end = pos + vel * left;
		tracebox(pos, m_bot.mins, m_bot.maxs, end, MOVE_NORMAL, m_bot);
		if (trace_allsolid || trace_startsolid)
			break;
		pos = trace_endpos;
		if (trace_fraction == 1)
			break;
		bw_add_contact(this, trace_ent);
		n = trace_plane_normal;
		left *= 1 - trace_fraction;
		vel = vel - n * (vel * n);
		if (grounded)
			vel_z = 0;
		else if (n_z < m_slope && vel_z < 0 && n_z > 0)
			vel_z = 0;	/* never slide down into the floor */
		if (vel * orig <= 0) {
			vel = '0 0 0';
			break;
		}
	}
	bw_slide_vel = vel;
	return pos;
}

void BWLocomotion::Move(float dt)
{
	vector org = m_bot.origin, vel = m_bot.velocity, up, end, flat;
	float raise;
	float onground = (m_bot.flags & FL_ONGROUND) ? TRUE : FALSE;

	tracebox(org, m_bot.mins, m_bot.maxs, org, MOVE_NORMAL, m_bot);
	if (trace_startsolid) {
		/* started inside something: back to the last good spot */
		setorigin(m_bot, m_last_good);
		bw_log(m_bot, BWD_LOCOMOTION, "inside solid, restored last good position");
		return;
	}
	m_last_good = org;

	if (onground && vel_z <= 0) {
		flat = bw_flat(vel);
		if (vlen(flat) < 0.01)
			return;
		/* step up, slide across, then settle back down */
		tracebox(org, m_bot.mins, m_bot.maxs, org + '0 0 1' * m_step, MOVE_NORMAL, m_bot);
		raise = trace_endpos_z - org_z;
		up = trace_endpos;
		end = SlideMove(up, flat, dt, TRUE);
		tracebox(end, m_bot.mins, m_bot.maxs, end - '0 0 1' * (raise + m_step), MOVE_NORMAL, m_bot);
		if (trace_fraction < 1 && !trace_startsolid && trace_plane_normal_z < m_slope && trace_endpos_z > org_z + 0.5) {
			/* too steep to stand on: treat as a wall */
			end = SlideMove(org, flat, dt, TRUE);
		} else if (trace_fraction == 1) {
			end_z -= raise;	/* walked off an edge */
		} else {
			end = trace_endpos;
		}
		vel_x = bw_slide_vel_x;
		vel_y = bw_slide_vel_y;
		setorigin(m_bot, end);
		m_bot.velocity = vel;
		return;
	}

	end = SlideMove(org, vel, dt, FALSE);
	setorigin(m_bot, end);
	m_bot.velocity = bw_slide_vel;
}

void BWLocomotion::CheckGround(float was)
{
	vector org = m_bot.origin;
	float now = FALSE;
	if (m_bot.velocity_z <= 0) {
		tracebox(org, m_bot.mins, m_bot.maxs, org - '0 0 2', MOVE_NORMAL, m_bot);
		if (trace_fraction < 1 && !trace_startsolid && trace_plane_normal_z >= m_slope) {
			now = TRUE;
			setorigin(m_bot, trace_endpos);
			m_bot.groundentity = trace_ent;
			m_bot.velocity_z = 0;
		}
	}
	if (now) {
		m_bot.flags |= FL_ONGROUND;
		if (!was) {
			m_jumping = m_climbing = FALSE;
			m_air_speed = m_air_accel = 0;
			bw_log(m_bot, BWD_LOCOMOTION, "landed");
			bw_ev_clear();
			bw_ev_e1 = m_bot.groundentity;
			m_bot.SendEvent(BWE_LAND);
		}
	} else {
		m_bot.flags &= ~FL_ONGROUND;
		if (was) {
			bw_ev_clear();
			bw_ev_e1 = m_bot.groundentity;
			m_bot.groundentity = world;
			m_bot.SendEvent(BWE_LEAVE_GROUND);
		}
	}
}

void BWLocomotion::UpdateStuck(void)
{
	float allowed;
	if (GetSpeed() > 30)
		m_still_since = time;

	if (!m_wants_move || m_jumping || m_desired_speed <= 0) {
		/* not trying to move: nothing can be stuck, start a fresh window */
		if (!m_stuck) {
			m_stuck_anchor = m_bot.origin;
			m_stuck_anchor_time = time;
		}
		return;
	}
	if (vlen(m_bot.origin - m_stuck_anchor) > 100) {
		m_stuck_anchor = m_bot.origin;
		m_stuck_anchor_time = time;
		if (m_stuck) {
			m_stuck = FALSE;
			bw_log(m_bot, BWD_LOCOMOTION, "unstuck");
			bw_ev_clear();
			m_bot.SendEvent(BWE_UNSTUCK);
		}
		return;
	}
	/* longer than 100 units would take at a tenth of the desired speed */
	allowed = 100 / (0.1 * m_desired_speed);
	if (!m_stuck) {
		if (time - m_stuck_anchor_time > allowed) {
			m_stuck = TRUE;
			m_stuck_since = time;
			m_stuck_next = time + 1;
			bw_log(m_bot, BWD_LOCOMOTION, sprintf("stuck at %v", m_bot.origin));
			bw_ev_clear();
			m_bot.SendEvent(BWE_STUCK);
		}
	} else if (time >= m_stuck_next) {
		m_stuck_next = time + 1;
		bw_ev_clear();
		m_bot.SendEvent(BWE_STUCK);
	}
}

void BWLocomotion::Turn(float dt)
{
	vector goal;
	float yaw, d, step;
	if (time < m_face_until)
		goal = m_face_goal - m_bot.origin;
	else if (m_wants_move)
		goal = m_move_dir;
	else
		return;
	if (vlen(bw_flat(goal)) < 0.5)
		return;
	yaw = vectoyaw(goal);
	d = bw_anglediff(m_bot.angles_y, yaw);
	step = m_yaw_rate * dt;
	if (d > step)
		d = step;
	else if (d < -step)
		d = -step;
	m_bot.angles_y = anglemod(m_bot.angles_y + d);
}

/* runs e's touch with other set to the bot (outside a method, where self
 * would mean the method's object) */
void bw_run_touch(entity e, entity toucher)
{
	entity oldself = self, oldother = other;
	if (!e.touch || e.solid == SOLID_NOT)
		return;
	self = e;
	other = toucher;
	e.touch();
	self = oldself;
	other = oldother;
}

void BWLocomotion::FrameUpdate(float dt)
{
	vector vel, wish = '0 0 0', lat;
	float was = (m_bot.flags & FL_ONGROUND) ? TRUE : FALSE;
	float fwd, speed, gov, i;

	if (m_pend_weight > 0) {
		if (vlen(m_pend_dir) > 0.001) {
			m_move_dir = normalize(bw_flat(m_pend_dir));
			m_move_goal = m_pend_goal * (1 / m_pend_weight);
			m_move_until = time + bw_request_hold();
		}
		m_pend_dir = '0 0 0';
		m_pend_goal = '0 0 0';
		m_pend_weight = 0;
	}
	m_wants_move = (time < m_move_until && m_bot.IsAlive() && !m_bot.m_bot_paused) ? TRUE : FALSE;
	if (m_wants_move)
		wish = m_move_dir;

	if (m_bot.IsAlive())
		Turn(dt);

	vel = m_bot.velocity;
	if (was && !m_jumping) {
		speed = m_desired_speed;
		if (m_wants_move && speed > 0) {
			fwd = vel * wish;
			lat = bw_flat(vel) - wish * fwd;
			lat *= max(0, 1 - BW_SIDE_FRICTION * dt);
			if (fwd < 0) {
				fwd = min(0, fwd + 2 * m_accel * dt);	/* brake when going backwards */
			} else {
				/* the governor tapers acceleration over the last quarter */
				gov = bound(0, (speed - fwd) / (speed * 0.25), 1);
				fwd += m_accel * gov * dt;
				if (fwd > speed)
					fwd = max(speed, fwd - m_accel * dt);
			}
			vel = wish * fwd + lat;
		} else {
			vel = '0 0 0';	/* no request: stop dead */
		}
		vel_z = 0;
	} else {
		vel_z -= bw_gravity(this) * dt;
		if (m_climbing || (m_jumping && m_air_speed > 0)) {
			/* air control towards the ledge or landing */
			vector want = normalize(bw_flat(m_air_goal - m_bot.origin)) * m_air_speed, have = bw_flat(vel), dv;
			if (bw_dist2d(m_bot.origin, m_air_goal) < 4)
				want = '0 0 0';
			float acc = m_air_accel ? m_air_accel : BW_AIR_ACCEL;
			dv = want - have;
			if (vlen(dv) > acc * dt)
				dv = normalize(dv) * acc * dt;
			vel += dv;
		}
	}
	m_bot.velocity = vel;

	m_ncontacts = 0;
	Move(dt);
	CheckGround(was);

	if (m_bot.solid != SOLID_NOT)
		touchtriggers(m_bot);

	/* contacts: the touched entity's touch runs, and the bot hears about it */
	for (i = 0; i < m_ncontacts; i++) {
		entity e = m_contacts[i];
		if (wasfreed(e))
			continue;
		bw_run_touch(e, m_bot);
		if (e.flags & (FL_CLIENT | FL_MONSTER))
			m_actor_blocked = time;
		bw_ev_clear();
		bw_ev_e1 = e;
		m_bot.SendEvent(BWE_CONTACT);
	}

	UpdateStuck();
}
