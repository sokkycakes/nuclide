/* Bulwark bot framework: following a path, and chasing a moving entity.
 * See docs/spec/bots.md, "Path following" and "Chasing". ISC licence. */

#define BW_REACH 16		/* close enough to a ground point */
#define BW_GIVEUP 3		/* seconds without progress before giving up */

float BWPathFollower::Compute(BWBot bot, vector goal, float forbid)
{
	float ok = super::Compute(bot, goal, forbid);
	m_goal_idx = 1;
	m_best = 999999999;
	m_progress_time = time;
	m_failed = FALSE;
	if (!ok) {
		Fail(bot, BWFAIL_NO_PATH);
		return FALSE;
	}
	if (m_partial) {
		/* the bot is told, but may still follow what there is */
		bw_ev_clear();
		bw_ev_e1 = this;
		bw_ev_f1 = BWFAIL_NO_PATH;
		bot.SendEvent(BWE_MOVE_FAIL);
	}
	return TRUE;
}

void BWPathFollower::Fail(BWBot bot, float reason)
{
	m_valid = FALSE;
	m_failed = TRUE;
	bw_log(bot, BWD_PATH, sprintf("path failed (%s)", reason == BWFAIL_STUCK ? "stuck" : reason == BWFAIL_FELL_OFF ? "fell off" : "no path"));
	bw_ev_clear();
	bw_ev_e1 = this;
	bw_ev_f1 = reason;
	bot.SendEvent(BWE_MOVE_FAIL);
}

vector BWPathFollower::CurrentGoal(void)
{
	if (m_goal_idx < m_count)
		return m_segs[m_goal_idx].pos;
	return GetEndPosition();
}

float BWPathFollower::IsReached(BWBot bot, float i)
{
	vector p = m_segs[i].pos, o = bot.origin;
	float onground = bot.m_loco.IsOnGround(), d2 = bw_dist2d(o, p), dz = o_z - p_z;
	switch (m_segs[i].type) {
	case BWSEG_DROP:
		return (onground && dz <= bot.m_loco.m_step) ? TRUE : FALSE;	/* landed below */
	case BWSEG_CLIMB:
		return (onground && dz >= -2) ? TRUE : FALSE;	/* got above it */
	case BWSEG_GAP:
		if (!onground || bot.m_loco.m_jumping || fabs(dz) > bot.m_loco.m_step)
			return FALSE;
		break;
	default:
		if (fabs(dz) > 40)
			return FALSE;
		break;
	}
	if (d2 < BW_REACH)
		return TRUE;
	/* someone is standing on it: close is close enough */
	if (i < m_count - 1 && m_segs[i].type == BWSEG_GROUND && d2 < 64 && bot.m_loco.IsBlockedByActor())
		return TRUE;
	/* passed it in the path's direction */
	if (i < m_count - 1 && d2 < 120 && bw_flat(o - p) * m_segs[i].fwd >= 0)
		return TRUE;
	return FALSE;
}

/* returns FALSE when following ended (success or failure) */
float BWPathFollower::CheckProgress(BWBot bot)
{
	BWLocomotion loco = bot.m_loco;
	float look = bw_cvar("bot_lookahead"), n = 0, d, before = m_goal_idx;
	vector p, o = bot.origin;

	/* skip ahead past ground points that are directly reachable */
	if (loco.IsOnGround())
		while (m_goal_idx + 1 < m_count && n++ < 8) {
			if (m_segs[m_goal_idx].type != BWSEG_GROUND || m_segs[m_goal_idx + 1].type != BWSEG_GROUND)
				break;
			p = m_segs[m_goal_idx + 1].pos;
			if (vlen(p - o) > look || p_z > o_z + loco.m_step)
				break;
			if (!bw_walkable(loco, o, p))
				break;
			m_goal_idx++;
		}

	while (m_goal_idx < m_count) {
		if (!IsReached(bot, m_goal_idx))
			break;
		m_goal_idx++;
	}
	if (m_goal_idx >= m_count) {
		m_valid = FALSE;
		bw_log(bot, BWD_PATH, "reached the end of the path");
		bw_ev_clear();
		bw_ev_e1 = this;
		bot.SendEvent(BWE_MOVE_SUCCESS);
		return FALSE;
	}
	if (m_goal_idx != before) {
		m_best = 999999999;
		m_progress_time = time;
	}

	/* progress towards the current point */
	/* waiting on another actor to move is not a reason to give up */
	d = vlen(m_segs[m_goal_idx].pos - o);
	if (d < m_best - 8 || loco.IsClimbingOrJumping() || loco.IsBlockedByActor()) {
		m_best = min(m_best, d);
		m_progress_time = time;
	} else if (time - m_progress_time > BW_GIVEUP) {
		Fail(bot, BWFAIL_STUCK);
		return FALSE;
	}
	/* stuck counts only once no actor has been in the way for a couple of seconds */
	if (loco.IsStuck() && time - max(loco.m_stuck_since, m_computed) > 1 && time - loco.m_actor_blocked > 2) {
		Fail(bot, BWFAIL_STUCK);
		return FALSE;
	}
	/* fell well below where the path goes */
	vector pa = m_segs[m_goal_idx - 1].pos, pb = m_segs[m_goal_idx].pos;
	if (loco.IsOnGround() && m_segs[m_goal_idx].type != BWSEG_DROP &&
	    o_z < min(pa_z, pb_z) - 2 * loco.m_step - 24) {
		Fail(bot, BWFAIL_FELL_OFF);
		return FALSE;
	}
	return TRUE;
}

/* left and right feelers; steer around whatever blocks */
vector BWPathFollower::Avoid(BWBot bot, vector goal)
{
	vector fwd = bw_flat(goal - bot.origin), left, base;
	float range, lf, rf;
	entity le, re;
	if (!bw_cvar("bot_allow_avoid") || vlen(fwd) < 1)
		return goal;
	fwd = normalize(fwd);
	left = [-fwd_y, fwd_x, 0];
	range = 40 + bot.m_loco.GetSpeed() * 0.4;
	base = bot.origin + [0, 0, bot.mins_z + bot.m_loco.m_step + 4];	/* just above a step */

	traceline(base + left * bot.maxs_x, base + left * bot.maxs_x + fwd * range, MOVE_NORMAL, bot);
	lf = trace_fraction;
	le = trace_ent;
	if (le == m_ignore)
		lf = 1;
	traceline(base - left * bot.maxs_x, base - left * bot.maxs_x + fwd * range, MOVE_NORMAL, bot);
	rf = trace_fraction;
	re = trace_ent;
	if (re == m_ignore)
		rf = 1;

	if (lf == 1 && rf == 1)
		return goal;
	if ((le.flags & (FL_CLIENT | FL_MONSTER)) || (re.flags & (FL_CLIENT | FL_MONSTER)))
		bot.m_loco.m_actor_blocked = time;
	if (lf < 1 && rf < 1) {
		/* both blocked: only actors are worth steering round */
		if (!(le.flags & (FL_CLIENT | FL_MONSTER)) && !(re.flags & (FL_CLIENT | FL_MONSTER)))
			return goal;
		if (lf > rf)
			return bot.origin + normalize(fwd + left) * range;
		return bot.origin + normalize(fwd - left) * range;
	}
	if (lf < 1)
		return bot.origin + normalize(fwd - left * (1 - lf)) * range;
	return bot.origin + normalize(fwd + left * (1 - rf)) * range;
}

/* moves a climb, drop or gap jump (both of its points) sideways, for when
 * another actor holds the spot; FALSE if neither side has room */
float BWPathFollower::Sidestep(BWBot bot)
{
	float i, side = (random() < 0.5) ? 1 : -1, g = m_goal_idx;
	vector fwd = m_segs[g].fwd, off, a, b, na, nb, up = '0 0 1' * bot.m_loco.m_max_jump;
	if (g < 2)
		return FALSE;	/* point 0 is where the bot started */
	a = m_segs[g - 1].pos;
	b = m_segs[g].pos;
	for (i = 0; i < 2; i++, side = -side) {
		off = [-fwd_y, fwd_x, 0] * side * 56;
		tracebox(a + off + '0 0 18', bot.mins, bot.maxs, a + off - '0 0 18', MOVE_NOMONSTERS, bot);
		if (trace_startsolid || trace_fraction == 1)
			continue;
		na = trace_endpos;
		tracebox(b + off + up, bot.mins, bot.maxs, b + off - '0 0 18', MOVE_NOMONSTERS, bot);
		if (trace_startsolid || trace_fraction == 1 || fabs(trace_endpos_z - b_z) > bot.m_loco.m_step)
			continue;
		nb = trace_endpos;
		m_segs[g - 1].pos = na;
		m_segs[g].pos = nb;
		bw_log(bot, BWD_PATH, sprintf("an actor holds the spot, moving over to %v", nb));
		return TRUE;
	}
	return FALSE;
}

void BWPathFollower::Follow(BWBot bot)
{
	BWLocomotion loco = bot.m_loco;
	vector goal, prev;
	float type, i, base, curv = 0;

	if (!m_valid || !m_count)
		return;
	if (time - m_last_follow > 0.5)
		m_progress_time = time;	/* following was paused */
	m_last_follow = time;

	if (!CheckProgress(bot))
		return;

	/* two bots wanting the same climb or drop: one of them moves over */
	if (!loco.IsBlockedByActor())
		m_block_since = 0;
	else if (!m_block_since)
		m_block_since = time;
	else if (time - m_block_since > 1.5) {
		/* held up by other actors: move a climb or drop over, or step aside */
		float moved = FALSE;	/* (QC's || doesn't short-circuit) */
		if (m_segs[m_goal_idx].type != BWSEG_GROUND)
			moved = Sidestep(bot);
		if (!moved) {
			vector f = normalize(bw_flat(m_segs[m_goal_idx].pos - bot.origin));
			m_dodge_dir = [-f_y, f_x, 0] * ((random() < 0.5) ? 1 : -1);
			m_dodge_until = time + 0.4 + random() * 0.4;
			bw_log(bot, BWD_PATH, "held up by actors, stepping aside");
		}
		m_block_since = time;
	}
	if (time < m_dodge_until && loco.IsOnGround()) {
		loco.Approach(bot.origin + m_dodge_dir * 64, 1);
		return;
	}

	/* slow down for sharp corners coming up */
	for (i = m_goal_idx; i < m_count; i++) {
		if (m_segs[i].dist - m_segs[m_goal_idx].dist > 150)
			break;
		curv = max(curv, m_segs[i].curv);
	}
	base = m_speed ? m_speed : loco.m_run_speed;
	loco.SetDesiredSpeed(max(loco.m_walk_speed * 0.75, base * (1 - 0.6 * curv)));

	goal = m_segs[m_goal_idx].pos;
	type = m_segs[m_goal_idx].type;
	prev = m_segs[m_goal_idx - 1].pos;

	/* climbs and gap jumps start from their foot or launch point */
	if ((type == BWSEG_CLIMB || type == BWSEG_GAP) && loco.IsOnGround() && !loco.IsClimbingOrJumping()) {
		if (bw_dist2d(bot.origin, prev) < 32 || bw_flat(bot.origin - prev) * m_segs[m_goal_idx].fwd > 0) {
			loco.FaceTowards(goal);
			if (type == BWSEG_CLIMB)
				loco.ClimbUpToLedge(goal, m_segs[m_goal_idx].fwd);
			else
				loco.JumpAcrossGap(goal, m_segs[m_goal_idx].fwd);
			return;
		}
		goal = prev;
	}

	if (type == BWSEG_GROUND)
		goal = Avoid(bot, goal);
	loco.Approach(goal, 1);
	loco.FaceTowards(goal);
}

/* --- chasing ------------------------------------------------------------------ */

vector BWChasePath::PredictSubjectPosition(BWBot bot, entity subject)
{
	vector d = subject.origin - bot.origin, pred, up = '0 0 1' * bot.m_loco.m_step;
	float dist = vlen(d), speed, t;
	if (!m_lead || dist > m_lead)
		return subject.origin;
	speed = max(bot.m_loco.GetSpeed(), bot.m_loco.m_desired_speed * 0.5, 1);
	t = dist / speed;
	pred = subject.origin + bw_flat(subject.velocity) * t;
	/* keep it somewhere the subject could actually get to */
	if (vlen(pred - subject.origin) > dist)
		pred = subject.origin + normalize(pred - subject.origin) * dist;
	tracebox(subject.origin + up, bot.mins, bot.maxs, pred + up, MOVE_NOMONSTERS, subject);
	pred = bw_snap_down(trace_endpos - up + '0 0 1', subject);
	return pred;
}

float BWChasePath::IsRepathNeeded(BWBot bot, entity subject)
{
	float tosubject, drift;
	if (time < m_next_repath)
		return FALSE;
	if (!m_valid)
		return TRUE;
	if (m_lifetime > 0 && time - m_computed > m_lifetime)
		return TRUE;
	if (m_direct && bot.m_loco.IsStuck() && bot.m_loco.GetStuckDuration() > 2)
		return TRUE;
	tosubject = vlen(subject.origin - bot.origin);
	drift = vlen(subject.origin - GetEndPosition());
	return (drift > max(16, tosubject / 3)) ? TRUE : FALSE;
}

void BWChasePath::Chase(BWBot bot, entity subject)
{
	BWLocomotion loco = bot.m_loco;
	vector target;
	if (!subject || wasfreed(subject))
		return;
	if (subject != m_subject) {
		m_subject = subject;
		Invalidate();
		m_next_repath = 0;
	}
	m_ignore = subject;

	if (m_direct && vlen(subject.origin - bot.origin) < 500 && bot.m_vision.IsAbleToSee(subject, FALSE) &&
	    bw_walkable(loco, bot.origin, subject.origin) &&
	    !(loco.IsStuck() && loco.GetStuckDuration() > 2)) {
		target = PredictSubjectPosition(bot, subject);
		loco.SetDesiredSpeed(m_speed ? m_speed : loco.m_run_speed);
		loco.Approach(Avoid(bot, target), 1);
		loco.FaceTowards(target);
		return;
	}
	if (IsRepathNeeded(bot, subject)) {
		Compute(bot, PredictSubjectPosition(bot, subject), 0);
		m_next_repath = time + 0.5;
	}
	Follow(bot);
}
