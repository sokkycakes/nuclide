/* Bulwark bot framework: paths built from waypoint routes, with special
 * segments (drop down, gap jump, climb) found by probing the world.
 * See docs/spec/bots.md, "Paths". ISC licence, see LICENSE. */

#define BW_MAX_GAP 200		/* widest gap to jump */
#define BW_PROBE_STEP 16

void BWPath::Free(void)
{
	if (m_segs)
		memfree(m_segs);
	m_segs = __NULL__;
	m_count = 0;
	m_valid = FALSE;
}

void BWPath::Invalidate(void)
{
	m_count = 0;
	m_valid = FALSE;
	m_partial = FALSE;
	m_length = 0;
}

float BWPath::IsValid(void) { return m_valid; }
float BWPath::GetLength(void) { return m_length; }

vector BWPath::GetEndPosition(void)
{
	if (!m_count)
		return m_goal;
	return m_segs[m_count - 1].pos;
}

float BWPath::AddPoint(vector pos, float type)
{
	if (!m_segs) {
		m_segs = memalloc(sizeof(bw_seg_t) * BWPATH_MAXSEGS);
		bw_ispath = TRUE;
	}
	if (m_count >= BWPATH_MAXSEGS)
		return FALSE;
	/* zero-length segments are dropped (a special point replaces the type) */
	if (m_count && vlen(pos - m_segs[m_count - 1].pos) < 1) {
		if (type != BWSEG_GROUND)
			m_segs[m_count - 1].type = type;
		return TRUE;
	}
	m_segs[m_count].pos = pos;
	m_segs[m_count].type = type;
	m_count++;
	return TRUE;
}

/* fills in directions, lengths, distances and curvature */
void BWPath::Finish(void)
{
	float i;
	vector d, prevfwd = '1 0 0';
	m_length = 0;
	for (i = 0; i < m_count; i++) {
		if (i == 0) {
			m_segs[i].len = 0;
			m_segs[i].dist = 0;
			if (m_count > 1) {
				d = bw_flat(m_segs[1].pos - m_segs[0].pos);
				if (vlen(d) > 0.01)
					prevfwd = normalize(d);
			}
			m_segs[i].fwd = prevfwd;
			continue;
		}
		d = m_segs[i].pos - m_segs[i - 1].pos;
		m_segs[i].len = vlen(d);
		m_length += m_segs[i].len;
		m_segs[i].dist = m_length;
		d = bw_flat(d);
		if (vlen(d) > 0.01)
			prevfwd = normalize(d);
		m_segs[i].fwd = prevfwd;
	}
	for (i = 0; i < m_count; i++) {
		if (i == 0 || i == m_count - 1)
			m_segs[i].curv = 0;
		else
			m_segs[i].curv = (1 - (m_segs[i].fwd * m_segs[i + 1].fwd)) * 0.5;
	}
	m_valid = (m_count >= 2) ? TRUE : FALSE;
	m_computed = time;
}

/* the ground under a waypoint (waypoints sit at standing origin height) */
vector bw_snap_down(vector pos, entity ignore)
{
	traceline(pos + '0 0 8', pos - '0 0 256', MOVE_NOMONSTERS, ignore);
	if (trace_fraction == 1 || trace_startsolid)
		return pos;
	return trace_endpos;
}

/* where the bot's origin is when it stands on the ground under pos: the
 * same as the ground for a bot whose origin is at its feet, higher for a
 * player whose origin is in the middle of its box */
vector bw_stand_at(BWBot bot, vector pos)
{
	traceline(pos + '0 0 8', pos - '0 0 256', MOVE_NOMONSTERS, bot);
	if (trace_fraction == 1 || trace_startsolid)
		return pos;
	return trace_endpos - [0, 0, bot.mins_z];
}

/* walks the bot's box from a to b and adds the points needed to get
 * there: plain ground, a climb at the foot of a ledge, a jump over a gap or
 * a drop off an edge. b is added last. */
void BWPath::Probe(BWBot bot, vector a, vector b)
{
	BWLocomotion loco = bot.m_loco;
	vector dir = bw_flat(b - a), pos = a, nxt, up = '0 0 1', foot, top, q, land;
	float total = vlen(dir), s = 0, adv, d, guard = 0, found;
	float step = loco.m_step;

	if (total < 1) {
		AddPoint(b, BWSEG_GROUND);
		return;
	}
	dir = normalize(dir);
	while (s < total && guard++ < 256) {
		adv = min(BW_PROBE_STEP, total - s);
		nxt = pos + dir * adv;
		tracebox(pos + up * step, bot.mins, bot.maxs, nxt + up * step, MOVE_NOMONSTERS, bot);
		if (trace_startsolid)
			break;
		if (trace_fraction < 1) {
			/* blocked by something taller than a step: a ledge to climb? */
			foot = trace_endpos - up * step;
			q = foot + dir * (bot.maxs_x * 2 + 4);
			q_z = pos_z + loco.m_max_jump + step;
			tracebox(q, bot.mins, bot.maxs, q - up * (loco.m_max_jump + step), MOVE_NOMONSTERS, bot);
			if (!trace_startsolid && trace_fraction < 1 && trace_plane_normal_z >= loco.m_slope) {
				top = trace_endpos;
				if (top_z - pos_z > step && top_z - pos_z <= loco.m_max_jump && bw_cvar("bot_allow_climb")) {
					AddPoint(foot, BWSEG_GROUND);
					AddPoint(top, BWSEG_CLIMB);
					pos = top;
					s = (pos - a) * dir;
					continue;
				}
			}
			break;	/* can't get past; following will report it */
		}
		/* settle onto the ground within a step below */
		q = trace_endpos;
		tracebox(q, bot.mins, bot.maxs, q - up * (2 * step + 1), MOVE_NOMONSTERS, bot);
		if (trace_fraction < 1 && !trace_startsolid) {
			pos = trace_endpos;
			s += adv;
			continue;
		}
		/* the ground falls away: a gap with a far side at this height? */
		found = FALSE;
		if (bw_cvar("bot_allow_gap_jump")) {
			for (d = BW_PROBE_STEP; d <= BW_MAX_GAP && s + d <= total + BW_PROBE_STEP; d += BW_PROBE_STEP) {
				q = pos + dir * d;
				tracebox(q + up * step, bot.mins, bot.maxs, q - up * step, MOVE_NOMONSTERS, bot);
				if (trace_startsolid || trace_fraction == 1)
					continue;
				land = trace_endpos;
				tracebox(pos + up * 24, bot.mins, bot.maxs, land + up * 24, MOVE_NOMONSTERS, bot);
				if (trace_fraction < 1)
					break;
				AddPoint(pos, BWSEG_GROUND);
				AddPoint(land, BWSEG_GAP);
				pos = land;
				s = (pos - a) * dir;
				found = TRUE;
				break;
			}
		}
		if (found)
			continue;
		/* drop down: walk off the edge to the ground below */
		q = pos + dir * (bot.maxs_x * 2 + 8);
		tracebox(pos + up * step, bot.mins, bot.maxs, q + up * step, MOVE_NOMONSTERS, bot);
		q = trace_endpos;
		tracebox(q, bot.mins, bot.maxs, q - up * 2048, MOVE_NOMONSTERS, bot);
		if (trace_fraction == 1 || trace_startsolid)
			break;
		land = trace_endpos;
		AddPoint(pos, BWSEG_GROUND);
		AddPoint(land, BWSEG_DROP);
		pos = land;
		s = (pos - a) * dir;
	}
	AddPoint(b, BWSEG_GROUND);
}

float bw_walkable(BWLocomotion loco, vector from, vector to)
{
	if (fabs(to_z - from_z) > loco.m_step)
		return FALSE;
	if (!loco.IsPotentiallyTraversable(from, to, FALSE))
		return FALSE;
	return !loco.HasGap(from, to);
}

vector *bw_pts;
float bw_npts;

void bw_pts_remove(float i)
{
	float j;
	for (j = i; j < bw_npts - 1; j++)
		bw_pts[j] = bw_pts[j + 1];
	bw_npts--;
}

float BWPath::Compute(BWBot bot, vector goal, float forbid)
{
	BWLocomotion loco = bot.m_loco;
	vector start = bot.origin;
	float s, g, i, n;

	Invalidate();
	goal = bw_stand_at(bot, goal);
	m_goal = goal;

	/* trivial path: close enough in height and directly walkable */
	if (bw_walkable(loco, start, goal)) {
		AddPoint(start, BWSEG_GROUND);
		AddPoint(goal, BWSEG_GROUND);
		Finish();
		bw_log(bot, BWD_PATH, sprintf("direct path to %v", goal));
		return TRUE;
	}

	s = bw_wp_nearest(start + '0 0 24', TRUE);
	g = bw_wp_nearest(goal + '0 0 24', TRUE);
	if (s < 0 || g < 0 || !bw_route(s, g, forbid)) {
		bw_log(bot, BWD_PATH | BWD_ERRORS, sprintf("no route to %v", goal));
		return FALSE;
	}
	m_partial = bw_route_partial;

	if (!bw_pts)
		bw_pts = memalloc(sizeof(vector) * (BWPATH_MAXSEGS + 2));
	bw_npts = 0;
	bw_pts[bw_npts++] = start;
	for (i = 0; i < bw_route_len && bw_npts < BWPATH_MAXSEGS; i++)
		bw_pts[bw_npts++] = bw_stand_at(bot, bw_wps[bw_route_nodes[i]].pos);
	if (!m_partial)
		bw_pts[bw_npts++] = goal;

	/* don't double back: waypoints at either end that can be walked past */
	for (n = 0; n < 2 && bw_npts >= 3 && bw_walkable(loco, bw_pts[0], bw_pts[2]); n++)
		bw_pts_remove(1);
	if (!m_partial)
		for (n = 0; n < 2 && bw_npts >= 3 && bw_walkable(loco, bw_pts[bw_npts - 3], bw_pts[bw_npts - 1]); n++)
			bw_pts_remove(bw_npts - 2);

	AddPoint(bw_pts[0], BWSEG_GROUND);
	for (i = 1; i < bw_npts; i++)
		Probe(bot, m_segs[m_count - 1].pos, bw_pts[i]);
	Finish();
	bw_log(bot, BWD_PATH, sprintf("path to %v: %g points, %g long%s", goal, m_count, m_length, m_partial ? ", partial" : ""));
	if (bot.IsDebugging(BWD_PATH) && bw_cvar("bot_debug_draw"))
		Draw();
	return m_valid;
}

/* --- queries ------------------------------------------------------------- */

/* the point d along the path; sets bw_cursor_fwd, _curv and _seg */
vector BWPath::PointAt(float d)
{
	float i, f;
	if (m_count < 1)
		return m_goal;
	if (d <= 0) {
		bw_cursor_fwd = m_segs[0].fwd;
		bw_cursor_curv = 0;
		bw_cursor_seg = 0;
		return m_segs[0].pos;
	}
	for (i = 1; i < m_count; i++) {
		if (m_segs[i].dist >= d) {
			f = (m_segs[i].len > 0) ? (d - m_segs[i - 1].dist) / m_segs[i].len : 1;
			bw_cursor_fwd = m_segs[i].fwd;
			bw_cursor_curv = m_segs[i].curv * f;
			bw_cursor_seg = i;
			return m_segs[i - 1].pos + (m_segs[i].pos - m_segs[i - 1].pos) * f;
		}
	}
	bw_cursor_fwd = m_segs[m_count - 1].fwd;
	bw_cursor_curv = 0;
	bw_cursor_seg = m_count - 1;
	return m_segs[m_count - 1].pos;
}

/* distance along the path of the point closest to pos */
float BWPath::ClosestDistance(vector pos)
{
	float i, f, d, best = 999999999, bestd = 0;
	vector a, b, p;
	for (i = 1; i < m_count; i++) {
		a = m_segs[i - 1].pos;
		b = m_segs[i].pos;
		if (m_segs[i].len < 0.01)
			continue;
		f = bound(0, ((pos - a) * (b - a)) / (m_segs[i].len * m_segs[i].len), 1);
		p = a + (b - a) * f;
		d = vlen(pos - p);
		if (d < best) {
			best = d;
			bestd = m_segs[i - 1].dist + m_segs[i].len * f;
		}
	}
	return bestd;
}

vector BWPath::ClosestPoint(vector pos) { return PointAt(ClosestDistance(pos)); }

void BWPath::Draw(void)
{
	float i;
	for (i = 0; i < m_count; i++)
		print(sprintf("  path %g: %v type %g dist %g curv %.2f\n", i, m_segs[i].pos, m_segs[i].type, m_segs[i].dist, m_segs[i].curv));
}
