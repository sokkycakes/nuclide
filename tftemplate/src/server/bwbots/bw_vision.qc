/* Bulwark bot framework: Vision. Keeps a record of every actor the bot
 * knows about and sends sighting events. See docs/spec/bots.md, "Vision".
 * ISC licence, see LICENSE. */

#define BW_FORGET_TIME 10

void BWVision::Reset(void)
{
	ForgetAll();
	if (!m_fov)
		SetFieldOfView(90);
	m_last_update = 0;
}

void BWVision::SetFieldOfView(float degrees)
{
	m_fov = degrees;
	m_cos_half_fov = cos(degrees * 0.5 * (M_PI / 180));
}

entity bw_next_actor(entity e) { return findflags(e, flags, FL_CLIENT | FL_MONSTER); }

/* players and bots */
float BWVision::IsActor(entity e)
{
	if (!e || e == m_bot || wasfreed(e))
		return FALSE;
	return (e.flags & (FL_CLIENT | FL_MONSTER)) ? TRUE : FALSE;
}

BWKnown BWVision::FindRecord(entity e)
{
	BWKnown k;
	for (k = m_known; k; k = k.m_next)
		if (k.m_subject == e)
			return k;
	return __NULL__;
}

BWKnown BWVision::GetKnown(entity e) { return FindRecord(e); }

/* the game can tell a bot about an actor it hasn't seen */
BWKnown BWVision::AddKnownEntity(entity e)
{
	BWKnown k = FindRecord(e);
	if (!e)
		return __NULL__;
	if (!k) {
		k = spawn(BWKnown);
		k.m_subject = e;
		k.m_known_since = time;
		k.m_next = m_known;
		m_known = k;
	}
	if (!k.m_visible)
		k.m_lastpos = e.origin;
	k.m_scan = time;	/* told just now: stays fresh for the forget time */
	return k;
}

void BWVision::Forget(entity e)
{
	BWKnown k, prev = __NULL__;
	for (k = m_known; k; prev = k, k = k.m_next) {
		if (k.m_subject != e)
			continue;
		if (prev)
			prev.m_next = k.m_next;
		else
			m_known = k.m_next;
		remove(k);
		return;
	}
}

void BWVision::ForgetAll(void)
{
	BWKnown k, n;
	for (k = m_known; k; k = n) {
		n = k.m_next;
		remove(k);
	}
	m_known = __NULL__;
}

/* --- sight tests ----------------------------------------------------------- */

float BWVision::IsInFieldOfView(vector pos)
{
	vector d = pos - m_bot.m_body.GetEyePosition();
	if (m_fov >= 360)
		return TRUE;
	if (vlen(d) < 1)
		return TRUE;
	return (normalize(d) * m_bot.m_body.GetViewVector() >= m_cos_half_fov) ? TRUE : FALSE;
}

/* sight lines stop at the world and brush entities only */
float BWVision::IsLineOfSightClear(vector pos)
{
	traceline(m_bot.m_body.GetEyePosition(), pos, MOVE_NOMONSTERS, m_bot);
	return (trace_fraction == 1) ? TRUE : FALSE;
}

vector bw_actor_center(entity e) { return e.origin + (e.mins + e.maxs) * 0.5; }
vector bw_actor_eye(entity e)
{
	if (e.view_ofs != '0 0 0')
		return e.origin + e.view_ofs;
	return bw_actor_center(e);
}

float BWVision::IsAbleToSee(entity e, float check_fov)
{
	vector c;
	if (!e || wasfreed(e))
		return FALSE;
	if (bw_cvar("bot_blind"))
		return FALSE;
	if (!checkpvs(m_bot.m_body.GetEyePosition(), e))
		return FALSE;
	c = bw_actor_center(e);
	if (check_fov && !IsInFieldOfView(c) && !IsInFieldOfView(bw_actor_eye(e)))
		return FALSE;
	if (IsLineOfSightClear(c))
		return TRUE;
	if (IsLineOfSightClear(bw_actor_eye(e)))
		return TRUE;
	return FALSE;
}

float BWVision::IsAbleToSeePosition(vector pos, float check_fov)
{
	if (bw_cvar("bot_blind"))
		return FALSE;
	if (check_fov && !IsInFieldOfView(pos))
		return FALSE;
	return IsLineOfSightClear(pos);
}

float BWVision::IsLookingAt(vector pos, float cos_tolerance)
{
	vector d = normalize(pos - m_bot.m_body.GetEyePosition());
	return (d * m_bot.m_body.GetViewVector() >= cos_tolerance) ? TRUE : FALSE;
}

/* --- update ------------------------------------------------------------------- */

void BWVision::Update(float interval)
{
	entity e;
	BWKnown k, prev, next;
	float tm;

	m_last_update = time;

	/* who is visible now */
	if (!bw_cvar("bot_blind")) {
		for (e = bw_next_actor(world); e; e = bw_next_actor(e)) {
			if (!IsActor(e) || e.health <= 0)
				continue;
			if (m_range > 0 && vlen(e.origin - m_bot.origin) > m_range)
				continue;
			if (!IsAbleToSee(e, TRUE))
				continue;
			k = FindRecord(e);
			if (!k) {
				k = spawn(BWKnown);
				k.m_subject = e;
				k.m_known_since = time;
				k.m_next = m_known;
				m_known = k;
			}
			if (!k.m_visible) {
				k.m_visible = TRUE;
				k.m_visible_since = time;
			}
			k.m_lastseen = time;
			k.m_lastpos = e.origin;
			k.m_scan = time;
			tm = e.team;
			if (tm >= 0 && tm < 8)
				m_team_last_seen[tm] = time;
		}
	}

	/* sightings, lost sight and forgetting */
	prev = __NULL__;
	for (k = m_known; k; k = next) {
		next = k.m_next;
		e = k.m_subject;
		if (k.m_visible && k.m_lastseen != time) {
			k.m_visible = FALSE;
			if (k.m_sighted) {
				k.m_sighted = FALSE;
				bw_log(m_bot, BWD_VISION, sprintf("lost sight of %s", etos(e)));
				bw_ev_clear();
				bw_ev_e1 = e;
				m_bot.SendEvent(BWE_LOST_SIGHT);
			}
		}
		if (k.m_visible && !k.m_sighted && time - k.m_visible_since >= m_reaction) {
			k.m_sighted = TRUE;
			bw_log(m_bot, BWD_VISION, sprintf("saw %s", etos(e)));
			bw_ev_clear();
			bw_ev_e1 = e;
			m_bot.SendEvent(BWE_SIGHT);
		}
		/* obsolete: gone, dead, or not seen nor heard of for a while */
		if (wasfreed(e) || e.health <= 0 || (!k.m_visible && time - k.m_scan > BW_FORGET_TIME)) {
			if (prev)
				prev.m_next = next;
			else
				m_known = next;
			remove(k);
			continue;
		}
		prev = k;
	}
	if (bw_cvar("bot_debug_draw") && m_bot.IsDebugging(BWD_VISION))
		DebugDraw();
}

/* aware: seen for at least the reaction time, or told about */
float BWVision::IsAware(BWKnown k)
{
	if (k.m_visible)
		return k.m_sighted;
	return TRUE;
}

BWKnown BWVision::GetPrimaryKnownThreat(float only_visible)
{
	BWKnown k, best = __NULL__;
	entity t;
	for (k = m_known; k; k = k.m_next) {
		if (!IsAware(k) || (only_visible && !k.m_visible))
			continue;
		if (!m_bot.IsEnemy(k.m_subject) || k.m_subject.health <= 0)
			continue;
		if (!best) {
			best = k;
			continue;
		}
		t = m_bot.m_intention.SelectMoreDangerousThreat(best.m_subject, k.m_subject);
		if (t == k.m_subject)
			best = k;
	}
	m_last_threat = best ? best.m_subject : world;
	return best;
}

/* team -1 is any team */
BWKnown BWVision::GetClosestKnown(float tm)
{
	BWKnown k, best = __NULL__;
	float d, bd = 999999999;
	for (k = m_known; k; k = k.m_next) {
		if (tm >= 0 && k.m_subject.team != tm)
			continue;
		if (!IsAware(k))
			continue;
		d = vlen(k.m_lastpos - m_bot.origin);
		if (d < bd) {
			bd = d;
			best = k;
		}
	}
	return best;
}

float BWVision::GetKnownCount(float tm, float only_visible, float range)
{
	BWKnown k;
	float n = 0;
	for (k = m_known; k; k = k.m_next) {
		if (tm >= 0 && k.m_subject.team != tm)
			continue;
		if (only_visible && !k.m_visible)
			continue;
		if (range > 0 && vlen(k.m_lastpos - m_bot.origin) > range)
			continue;
		if (IsAware(k))
			n++;
	}
	return n;
}

/* seconds since anyone of the team was visible; a large number if never */
float BWVision::GetTimeSinceVisible(float tm)
{
	float i, t = 0;
	if (tm >= 0 && tm < 8)
		t = m_team_last_seen[tm];
	else
		for (i = 0; i < 8; i++)
			t = max(t, m_team_last_seen[i]);
	if (!t)
		return 99999;
	return time - t;
}

/* debug: a line to every known entity in the server console */
void BWVision::DebugDraw(void)
{
	BWKnown k;
	for (k = m_known; k; k = k.m_next)
		bw_log(m_bot, BWD_VISION, sprintf("  knows %s at %v%s%s", etos(k.m_subject), k.m_lastpos,
		       k.m_visible ? " visible" : "", k.m_sighted ? " sighted" : ""));
}
