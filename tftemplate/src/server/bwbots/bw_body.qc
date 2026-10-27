/* Bulwark bot framework: Body. Posture and bounding box, activities, and
 * where the head is aimed. See docs/spec/bots.md, "Body". ISC licence. */

#define BW_HALF_WIDTH 13
#define BW_ON_TARGET 11		/* degrees */
#define BW_HEAD_RATE 540	/* degrees per second when far off target */
#define BW_HEAD_EASE 30		/* slow down inside this many degrees */
#define BW_HEAD_RAMP 0.15	/* seconds to reach full speed */

vector BWBody::PostureMaxs(float posture)
{
	switch (posture) {
	case BWPOSTURE_CROUCH: return [BW_HALF_WIDTH, BW_HALF_WIDTH, 32];
	case BWPOSTURE_SIT: return [BW_HALF_WIDTH, BW_HALF_WIDTH, 40];
	case BWPOSTURE_LIE: return [BW_HALF_WIDTH, BW_HALF_WIDTH, 16];
	}
	return [BW_HALF_WIDTH, BW_HALF_WIDTH, 68];
}

float BWBody::PostureEyeHeight(float posture)
{
	vector m = PostureMaxs(posture);
	return m_z - 8;
}

void BWBody::Reset(void)
{
	m_posture = BWPOSTURE_STAND;
	if (m_bot.m_loco.DrivesInput()) {
		/* a player's box and eyes belong to the game */
		if (!m_bot.view_ofs)
			m_bot.view_ofs = [0, 0, m_bot.maxs_z - 8];
	} else {
		setsize(m_bot, [-BW_HALF_WIDTH, -BW_HALF_WIDTH, 0], PostureMaxs(m_posture));
		m_bot.view_ofs = [0, 0, PostureEyeHeight(m_posture)];
	}
	m_look_prio = -1;
	m_look_until = 0;
	m_activity = BWACT_NONE;
	m_view = [0, m_bot.angles_y, 0];
	m_bot.v_angle = m_view;
}

/* the feet stay put (origin is at the feet); refuses if the new box would
 * not fit */
float BWBody::SetDesiredPosture(float posture)
{
	vector mx;
	if (posture == m_posture)
		return TRUE;
	if (m_bot.m_loco.DrivesInput()) {
		/* the crouch or prone button does it, through the game's physics */
		m_posture = posture;
		bw_ev_clear();
		m_bot.SendEvent(BWE_POSTURE);
		return TRUE;
	}
	mx = PostureMaxs(posture);
	if (mx_z > m_bot.maxs_z) {
		tracebox(m_bot.origin, m_bot.mins, mx, m_bot.origin, MOVE_NORMAL, m_bot);
		if (trace_startsolid)
			return FALSE;
	}
	m_posture = posture;
	setsize(m_bot, m_bot.mins, mx);
	m_bot.view_ofs = [0, 0, PostureEyeHeight(posture)];
	bw_log(m_bot, BWD_ANIMATION, sprintf("posture %g", posture));
	bw_ev_clear();
	m_bot.SendEvent(BWE_POSTURE);
	return TRUE;
}

float BWBody::GetPosture(void) { return m_posture; }
vector BWBody::GetEyePosition(void) { return m_bot.origin + m_bot.view_ofs; }

vector BWBody::GetViewVector(void)
{
	makevectors(m_view);
	return v_forward;
}

/* --- activities -------------------------------------------------------------- */

string BWBody::ActivitySequence(float act)
{
	switch (act) {
	case BWACT_IDLE: return "idle";
	case BWACT_WALK: return "walk";
	case BWACT_RUN: return "run";
	case BWACT_JUMP: return "jump";
	case BWACT_CLIMB: return "climb";
	case BWACT_CROUCH_IDLE: return "crouch_idle";
	case BWACT_CROUCH_WALK: return "crouch_walk";
	case BWACT_ATTACK: return "attack";
	case BWACT_DIE: return "die";
	case BWACT_LIE: return "lie";
	}
	return "";
}

/* plays the model sequence named for the activity; a model without that
 * sequence (or no model) completes the activity on the next frame */
float BWBody::StartActivity(float act, float flags)
{
	float fr = -1, dur = 0;
	if (act == m_activity && !m_act_done)
		return TRUE;
	if (m_activity != BWACT_NONE && !m_act_done && !(m_act_flags & BWACTF_LOOP)) {
		bw_ev_clear();
		bw_ev_f1 = m_activity;
		m_bot.SendEvent(BWE_ANIM_INTERRUPTED);
	}
	if (m_bot.modelindex)
		fr = frameforname(m_bot.modelindex, ActivitySequence(act));
	if (fr >= 0) {
		m_bot.frame = fr;
		m_bot.frame1time = 0;
		dur = frameduration(m_bot.modelindex, fr);
	}
	m_activity = act;
	m_act_flags = flags;
	m_act_end = time + dur;
	m_act_done = FALSE;
	bw_log(m_bot, BWD_ANIMATION, sprintf("activity %s (frame %g, %g s)", ActivitySequence(act), fr, dur));
	return (fr >= 0) ? TRUE : FALSE;
}

float BWBody::GetActivity(void) { return m_activity; }
float BWBody::IsActivityDone(void) { return m_act_done; }

/* --- head aiming ---------------------------------------------------------- */

void BWBody::EndAim(float reason)
{
	BWAimReply r = m_look_reply;
	m_look_reply = __NULL__;
	if (r && !m_look_done && !wasfreed(r))
		r.OnFail(m_bot, reason);
}

void BWBody::ClearAim(void)
{
	EndAim(BWAIM_PREEMPTED);
	m_look_prio = -1;
	m_look_until = 0;
	m_look_ent = world;
}

void BWBody::AimHeadTowards(vector pos, float prio, float duration, BWAimReply reply, string reason)
{
	if (time < m_look_until && prio < m_look_prio) {
		if (reply)
			reply.OnFail(m_bot, BWAIM_REJECTED);
		return;
	}
	if (m_look_reply != reply)
		EndAim(BWAIM_PREEMPTED);
	if (m_look_ent || vlen(pos - m_look_pos) > 32 || time >= m_look_until) {
		m_look_start = time;
		m_look_done = FALSE;
	}
	m_look_ent = world;
	m_look_pos = pos;
	m_look_prio = prio;
	m_look_until = time + max(duration, 0.1);
	m_look_reply = reply;
	m_look_reason = reason;
	bw_log(m_bot, BWD_LOOK, sprintf("aim at %v prio %g for %g s (%s)", pos, prio, duration, reason));
}

void BWBody::AimHeadTowardsEntity(entity subject, float prio, float duration, BWAimReply reply, string reason)
{
	if (!subject)
		return;
	if (time < m_look_until && prio < m_look_prio) {
		if (reply)
			reply.OnFail(m_bot, BWAIM_REJECTED);
		return;
	}
	if (m_look_reply != reply)
		EndAim(BWAIM_PREEMPTED);
	if (m_look_ent != subject || time >= m_look_until) {
		m_look_start = time;
		m_look_done = FALSE;
		m_track = m_bot.m_intention.SelectTargetPoint(subject);
	}
	m_look_ent = subject;
	m_look_prio = prio;
	m_look_until = time + max(duration, 0.1);
	m_look_reply = reply;
	m_look_reason = reason;
	bw_log(m_bot, BWD_LOOK, sprintf("aim at %s prio %g for %g s (%s)", etos(subject), prio, duration, reason));
}

float BWBody::IsHeadAimingOnTarget(void) { return (m_look_prio >= 0 && m_on_target) ? TRUE : FALSE; }

float BWBody::IsHeadSteady(void) { return m_on_target; }

/* the line of sight passes within radius of pos: for a game deciding to
 * shoot. Pass m_aim_pos to shoot where the bot believes the target is, so
 * its aiming error shows in the shot. */
float BWBody::IsAimingAt(vector pos, float radius)
{
	vector eye = GetEyePosition(), dir = GetViewVector();
	float along = (pos - eye) * dir;
	if (along <= 0)
		return FALSE;
	return (vlen(eye + dir * along - pos) <= radius) ? TRUE : FALSE;
}

void BWBody::FrameUpdate(float dt)
{
	vector eye = GetEyePosition(), target, want, ang = m_view;
	float dy, dp, err, rate, k;

	/* activities */
	if (m_activity != BWACT_NONE && !m_act_done && !(m_act_flags & BWACTF_LOOP) && time >= m_act_end) {
		m_act_done = TRUE;
		bw_ev_clear();
		bw_ev_f1 = m_activity;
		m_bot.SendEvent(BWE_ANIM_DONE);
	}

	if (!m_bot.IsAlive())
		return;

	if (m_look_prio >= 0 && time >= m_look_until) {
		EndAim(BWAIM_EXPIRED);
		m_look_prio = -1;
		m_look_ent = world;
	}
	if (m_look_prio >= 0 && m_look_ent && wasfreed(m_look_ent)) {
		EndAim(BWAIM_EXPIRED);
		m_look_prio = -1;
		m_look_ent = world;
	}

	if (m_look_prio < 0) {
		/* nothing to look at: ahead along the body */
		makevectors([0, m_bot.angles_y, 0]);
		target = eye + v_forward * 100;
	} else if (m_look_ent) {
		/* follow the subject with some lag, leading its motion */
		want = m_bot.m_intention.SelectTargetPoint(m_look_ent) + m_look_ent.velocity * 0.1;
		k = min(1, (m_track_rate ? m_track_rate : 8) * dt);
		m_track = m_track + (want - m_track) * k;
		target = m_track;
		if (m_aim_error > 0) {
			/* a wobble that moves on now and then, as wide as the error at that range */
			if (time >= m_err_next) {
				m_err_next = time + 0.4 + random() * 0.4;
				m_err_off = [random() * 2 - 1, random() * 2 - 1, (random() * 2 - 1) * 0.5];
			}
			target += m_err_off * (vlen(target - eye) * m_aim_error * (M_PI / 180));
		}
	} else {
		target = m_look_pos;
	}

	m_aim_pos = target;
	want = vectoangles(target - eye);
	want_x = -want_x;	/* v_angle pitch is positive looking down */
	if (want_x < -180)
		want_x += 360;
	if (want_x > 180)
		want_x -= 360;
	dy = bw_anglediff(ang_y, want_y);
	dp = bw_anglediff(ang_x, want_x);
	err = max(fabs(dy), fabs(dp));

	/* eased: fast when far off, slow near the target, ramping up at first */
	rate = (m_head_rate ? m_head_rate : BW_HEAD_RATE) * bound(0.15, err / BW_HEAD_EASE, 1);
	if (m_look_prio >= 0)
		rate *= bound(0.25, (time - m_look_start) / BW_HEAD_RAMP, 1);
	k = rate * dt;
	if (err > k) {
		dy *= k / err;
		dp *= k / err;
	}
	ang_y = anglemod(ang_y + dy);
	ang_x = bound(-89, ang_x + dp, 89);
	ang_z = 0;
	m_view = ang;
	m_bot.v_angle = ang;
	m_bot.angles_x = -ang_x / 3;	/* the model leans a third of the way */

	m_on_target = (err - min(err, k) < BW_ON_TARGET) ? TRUE : FALSE;
	if (m_on_target && m_look_prio >= 0 && !m_look_done) {
		BWAimReply r = m_look_reply;
		m_look_done = TRUE;
		bw_log(m_bot, BWD_LOOK, sprintf("on target (%s)", m_look_reason));
		if (r && !wasfreed(r))
			r.OnSuccess(m_bot);
	}
}
