/* Bulwark bot framework: actions and the behaviour stack, and the
 * Intention component that owns it. See docs/spec/bots.md, "Actions".
 * ISC licence, see LICENSE.
 *
 * Each level of behaviour is a stack linked through m_under/m_over; the top
 * one is active and the rest are suspended. An active action may hold a
 * child stack of its own (m_child points at that stack's top). */

#define BW_MAXDEPTH 16

/* --- defaults ----------------------------------------------------------------- */

string BWAction::GetName(void) { return "Action"; }
float BWAction::OnStart(BWAction prior) { return BWR_CONTINUE; }
float BWAction::Update(float interval) { return BWR_CONTINUE; }
void BWAction::OnEnd(BWAction next) { }
float BWAction::OnSuspend(BWAction by) { return BWR_CONTINUE; }
float BWAction::OnResume(BWAction from) { return BWR_CONTINUE; }
BWAction BWAction::InitialChild(void) { return __NULL__; }

float BWAction::ShouldPickUp(entity item) { return BWQ_DONTCARE; }
float BWAction::ShouldHurry(void) { return BWQ_DONTCARE; }
float BWAction::ShouldRetreat(void) { return BWQ_DONTCARE; }
float BWAction::IsPositionAllowed(vector pos) { return BWQ_DONTCARE; }
entity BWAction::SelectMoreDangerousThreat(entity a, entity b) { return world; }
vector BWAction::SelectTargetPoint(entity subject) { bw_q_defined = FALSE; return '0 0 0'; }

float BWAction::HandleEvent(float type) { return super::HandleEvent(type); }

/* --- results --------------------------------------------------------------- */

float BWAction::Continue(void) { return BWR_CONTINUE; }

float BWAction::ChangeTo(BWAction a, string why)
{
	bw_res_action = a;
	bw_res_why = why;
	bw_res_prio = BWP_TRY;
	return BWR_CHANGE;
}

float BWAction::SuspendFor(BWAction a, string why)
{
	bw_res_action = a;
	bw_res_why = why;
	bw_res_prio = BWP_TRY;
	return BWR_SUSPEND;
}

float BWAction::Done(string why)
{
	bw_res_action = world;
	bw_res_why = why;
	bw_res_prio = BWP_TRY;
	return BWR_DONE;
}

float BWAction::TryChangeTo(BWAction a, float prio, string why)
{
	ChangeTo(a, why);
	bw_res_prio = prio;
	return BWR_CHANGE;
}

float BWAction::TrySuspendFor(BWAction a, float prio, string why)
{
	SuspendFor(a, why);
	bw_res_prio = prio;
	return BWR_SUSPEND;
}

float BWAction::TryDone(float prio, string why)
{
	Done(why);
	bw_res_prio = prio;
	return BWR_DONE;
}

float BWAction::TryToSustain(float prio, string why)
{
	bw_res_action = world;
	bw_res_why = why;
	bw_res_prio = prio;
	return BWR_SUSTAIN;
}

/* objects (paths, helper entities) removed when the action ends */
void BWAction::Own(entity obj)
{
	if (!obj)
		return;
	obj.bw_ownnext = m_owned;
	m_owned = obj;
}

BWAction BWAction::GetActiveChild(void) { return m_child; }

/* --- stack machinery ----------------------------------------------------- */

void bw_free_owned(entity e)
{
	entity n;
	while (e) {
		n = e.bw_ownnext;
		if (!wasfreed(e)) {
			if (e.bw_ispath)
				((BWPath)e).Free();
			remove(e);
		}
		e = n;
	}
}

/* ends one action and everything above or inside it is NOT touched here:
 * callers end what is above first. Children end before the action itself. */
void bw_action_end(BWAction a, BWAction next)
{
	if (!a || a.m_ended)
		return;
	bw_stack_end(a.m_child, __NULL__);
	a.m_child = __NULL__;
	a.m_ended = TRUE;
	bw_log(a.m_bot, BWD_BEHAVIOR, sprintf("%s ENDED%s", a.GetName(), next ? strcat(" for ", next.GetName()) : ""));
	a.OnEnd(next);
	bw_free_owned(a.m_owned);
	a.m_owned = world;
	if (a.m_under && a.m_under.m_over == a)
		a.m_under.m_over = __NULL__;
	if (a.m_req_action && !a.m_req_action.m_started)
		remove(a.m_req_action);	/* a queued action that never ran */
	a.m_req_action = __NULL__;
}

void bw_action_free(BWAction a)
{
	if (a && !wasfreed(a))
		remove(a);
}

/* ends a whole stack, top first */
void bw_stack_end(BWAction top, BWAction next)
{
	BWAction u;
	while (top) {
		u = top.m_under;
		bw_action_end(top, next);
		bw_action_free(top);
		top = u;
	}
}

/* sends OnSuspend/OnResume down the active chain inside an action */
void bw_children_suspend(BWAction a, BWAction by)
{
	for (a = a.m_child; a; a = a.m_child) {
		a.m_suspended = TRUE;
		a.OnSuspend(by);
	}
}

void bw_children_resume(BWAction a, BWAction from)
{
	for (a = a.m_child; a; a = a.m_child) {
		a.m_suspended = FALSE;
		a.OnResume(from);
	}
}

/* starts action a at a level; returns the action active at that level
 * afterwards (a, or whatever OnStart asked for) */
BWAction bw_action_begin(BWAction a, BWBot bot, BWAction parent, BWAction under, BWAction prior, float depth)
{
	float r;
	if (!a)
		return under;
	a.m_bot = bot;
	a.m_parent = parent;
	a.m_under = under;
	a.m_over = __NULL__;
	a.m_started = TRUE;
	if (under)
		under.m_over = a;
	bw_log(bot, BWD_BEHAVIOR, sprintf("%s STARTED%s", a.GetName(), prior ? strcat(" from ", prior.GetName()) : ""));
	bw_res_action = world;
	bw_res_why = "";
	r = a.OnStart(prior);
	if (r == BWR_CONTINUE || r == BWR_SUSTAIN)
		return a;
	return bw_apply(a, r, (BWAction)bw_res_action, bw_res_why, depth + 1);
}

/* applies a result to the top action of a level; returns the new top */
BWAction bw_apply(BWAction cur, float r, BWAction target, string why, float depth)
{
	BWAction under, parent;
	BWBot bot = cur.m_bot;
	float r2;

	if (depth > BW_MAXDEPTH) {
		bw_log(bot, BWD_ERRORS, sprintf("%s: too many changes in one step, ignoring %s", cur.GetName(), bw_result_name(r)));
		if (target && !target.m_started)
			remove(target);
		return cur;
	}
	switch (r) {
	case BWR_CHANGE:
		if (!target || target == cur)
			return cur;
		bw_log(bot, BWD_BEHAVIOR, sprintf("%s CHANGE_TO %s (%s)", cur.GetName(), target.GetName(), why));
		under = cur.m_under;
		parent = cur.m_parent;
		bw_action_end(cur, target);
		under = bw_action_begin(target, bot, parent, under, cur, depth);
		bw_action_free(cur);
		return under;
	case BWR_SUSPEND:
		if (!target || target == cur)
			return cur;
		bw_log(bot, BWD_BEHAVIOR, sprintf("%s SUSPEND_FOR %s (%s)", cur.GetName(), target.GetName(), why));
		parent = cur.m_parent;
		bw_res_action = world;
		r2 = cur.OnSuspend(target);
		if (r2 == BWR_DONE) {
			/* the action would rather end than wait */
			under = cur.m_under;
			bw_action_end(cur, target);
			bw_action_free(cur);
			return bw_action_begin(target, bot, parent, under, cur, depth);
		}
		cur.m_suspended = TRUE;
		bw_children_suspend(cur, target);
		return bw_action_begin(target, bot, parent, cur, cur, depth);
	case BWR_DONE:
		under = cur.m_under;
		bw_log(bot, BWD_BEHAVIOR, sprintf("%s DONE (%s)%s", cur.GetName(), why, under ? strcat(", resuming ", under.GetName()) : ""));
		bw_action_end(cur, under);
		if (!under) {
			bw_action_free(cur);
			return __NULL__;
		}
		under.m_over = __NULL__;
		under.m_suspended = FALSE;
		bw_children_resume(under, cur);
		bw_log(bot, BWD_BEHAVIOR, sprintf("%s RESUMED", under.GetName()));
		bw_res_action = world;
		bw_res_why = "";
		r2 = under.OnResume(cur);
		bw_action_free(cur);
		if (r2 == BWR_CONTINUE || r2 == BWR_SUSTAIN)
			return under;
		return bw_apply(under, r2, (BWAction)bw_res_action, bw_res_why, depth + 1);
	}
	return cur;
}

/* runs one level: queued requests, the top's Update, then its children */
BWAction bw_stack_update(BWAction top, float interval)
{
	BWAction a, best;
	BWAction t;
	float rt;
	string why;

	if (!top)
		return __NULL__;

	/* the strongest queued request wins; on a tie the higher action wins */
	best = __NULL__;
	for (a = top; a; a = a.m_under)
		if (a.m_req_type && (!best || a.m_req_prio > best.m_req_prio))
			best = a;
	if (best) {
		rt = best.m_req_type;
		t = best.m_req_action;
		why = best.m_req_why;
		for (a = top; a; a = a.m_under) {
			if (a != best && a.m_req_action && !a.m_req_action.m_started)
				remove(a.m_req_action);
			a.m_req_type = 0;
			a.m_req_action = __NULL__;
		}
		/* a request from a suspended action applies to it: what is above goes */
		while (top != best) {
			a = top.m_under;
			bw_action_end(top, best);
			bw_action_free(top);
			top = a;
		}
		if (top.m_suspended) {
			top.m_suspended = FALSE;
			if (rt == BWR_SUSPEND) {
				bw_children_resume(top, __NULL__);
				top.OnResume(__NULL__);
			}
		}
		top = bw_apply(top, rt, t, why, 0);
		if (!top)
			return __NULL__;
	}

	bw_res_action = world;
	bw_res_why = "";
	rt = top.Update(interval);
	if (rt == BWR_CHANGE || rt == BWR_SUSPEND || rt == BWR_DONE)
		return bw_apply(top, rt, (BWAction)bw_res_action, bw_res_why, 0);

	if (!top.m_childinit) {
		top.m_childinit = TRUE;
		a = top.InitialChild();
		if (a)
			top.m_child = bw_action_begin(a, top.m_bot, top, __NULL__, __NULL__, 0);
	}
	if (top.m_child)
		top.m_child = bw_stack_update(top.m_child, interval);
	return top;
}

/* delivers the current event: innermost active action first, then down
 * through what it is suspended over, then out to the parents */
float bw_stack_event(BWAction top, float type)
{
	BWAction a;
	float r;
	if (!top)
		return FALSE;
	if (top.m_child && bw_stack_event(top.m_child, type))
		return TRUE;
	for (a = top; a; a = a.m_under) {
		bw_ev_load();
		bw_res_action = world;
		bw_res_why = "";
		bw_res_prio = BWP_TRY;
		r = a.HandleEvent(type);
		if (r == BWR_CONTINUE)
			continue;
		bw_log(a.m_bot, BWD_EVENTS, sprintf("%s responded to %s: %s%s (%s)", a.GetName(), bw_event_name(type),
		       bw_result_name(r), bw_res_action ? strcat(" ", ((BWAction)bw_res_action).GetName()) : "", bw_res_why));
		if (r == BWR_SUSTAIN)
			return TRUE;
		if (!a.m_req_type || bw_res_prio >= a.m_req_prio) {
			if (a.m_req_action && a.m_req_action != bw_res_action && !a.m_req_action.m_started)
				remove(a.m_req_action);
			a.m_req_type = r;
			a.m_req_prio = bw_res_prio;
			a.m_req_action = (BWAction)bw_res_action;
			a.m_req_why = bw_res_why;
		} else if (bw_res_action && !((BWAction)bw_res_action).m_started) {
			remove(bw_res_action);	/* outranked by a request already queued */
		}
		return TRUE;
	}
	return FALSE;
}

/* "Pounce<<HunterAttack in HunterBehavior": innermost level first */
string bw_level_string(BWAction top)
{
	string s = "";
	BWAction a;
	for (a = top; a; a = a.m_under)
		s = (s == "") ? a.GetName() : strcat(s, "<<", a.GetName());
	return s;
}

string bw_stack_string(BWAction top)
{
	if (!top)
		return "(none)";
	if (top.m_child)
		return strcat(bw_stack_string(top.m_child), " in ", bw_level_string(top));
	return bw_level_string(top);
}

/* --- Intention ------------------------------------------------------------------ */

void BWIntention::Reset(void)
{
	bw_stack_end(m_root, __NULL__);
	m_root = __NULL__;
	if (m_forced && !m_forced.m_started)
		remove(m_forced);
	m_forced = __NULL__;
}

void BWIntention::ForceChange(BWAction a, string why)
{
	if (m_forced && m_forced != a && !m_forced.m_started)
		remove(m_forced);
	m_forced = a;
	bw_log(m_bot, BWD_BEHAVIOR, sprintf("forced change to %s (%s)", a ? a.GetName() : "nothing", why));
}

/* builds the behaviour from the bot's initial action when there is none */
void BWIntention::EnsureBehavior(void)
{
	BWAction a;
	if (m_root)
		return;
	a = m_bot.InitialAction();
	if (a)
		m_root = bw_action_begin(a, m_bot, __NULL__, __NULL__, __NULL__, 0);
}

void BWIntention::Update(float interval)
{
	if (m_forced) {
		BWAction f = m_forced;
		m_forced = __NULL__;
		bw_stack_end(m_root, f);
		m_root = bw_action_begin(f, m_bot, __NULL__, __NULL__, __NULL__, 0);
	}
	EnsureBehavior();	/* empty behaviour is rebuilt from the initial action */
	m_root = bw_stack_update(m_root, interval);
}

float BWIntention::HandleEvent(float type)
{
	bw_stack_event(m_root, type);
	return BWR_CONTINUE;
}

string BWIntention::StackString(void) { return bw_stack_string(m_root); }

/* the active actions from the innermost out, for queries */
BWAction bw_q_chain[BW_MAXDEPTH];
float bw_q_count;
void bw_query_chain(BWIntention in)
{
	BWAction a;
	bw_q_count = 0;
	for (a = in.m_root; a && bw_q_count < BW_MAXDEPTH; a = a.m_child)
		bw_q_chain[bw_q_count++] = a;
}

float BWIntention::ShouldPickUp(entity item)
{
	float i, r;
	bw_query_chain(this);
	for (i = bw_q_count - 1; i >= 0; i--) {
		r = bw_q_chain[i].ShouldPickUp(item);
		if (r != BWQ_DONTCARE)
			return r;
	}
	return BWQ_DONTCARE;
}

float BWIntention::ShouldHurry(void)
{
	float i, r;
	bw_query_chain(this);
	for (i = bw_q_count - 1; i >= 0; i--) {
		r = bw_q_chain[i].ShouldHurry();
		if (r != BWQ_DONTCARE)
			return r;
	}
	return BWQ_DONTCARE;
}

float BWIntention::ShouldRetreat(void)
{
	float i, r;
	bw_query_chain(this);
	for (i = bw_q_count - 1; i >= 0; i--) {
		r = bw_q_chain[i].ShouldRetreat();
		if (r != BWQ_DONTCARE)
			return r;
	}
	return BWQ_DONTCARE;
}

float BWIntention::IsPositionAllowed(vector pos)
{
	float i, r;
	bw_query_chain(this);
	for (i = bw_q_count - 1; i >= 0; i--) {
		r = bw_q_chain[i].IsPositionAllowed(pos);
		if (r != BWQ_DONTCARE)
			return r;
	}
	return BWQ_DONTCARE;
}

/* the default answer is the closer one */
entity BWIntention::SelectMoreDangerousThreat(entity a, entity b)
{
	float i;
	entity r;
	if (!a)
		return b;
	if (!b)
		return a;
	bw_query_chain(this);
	for (i = bw_q_count - 1; i >= 0; i--) {
		r = bw_q_chain[i].SelectMoreDangerousThreat(a, b);
		if (r)
			return r;
	}
	/* the closer one; the current threat keeps its place unless the other
	 * is clearly closer, so two at about the same range don't alternate */
	float da = vlen(a.origin - m_bot.origin), db = vlen(b.origin - m_bot.origin);
	if (a == m_bot.m_vision.m_last_threat)
		da *= 0.85;
	else if (b == m_bot.m_vision.m_last_threat)
		db *= 0.85;
	if (da <= db)
		return a;
	return b;
}

/* default: the middle of the subject's box */
vector BWIntention::SelectTargetPoint(entity subject)
{
	float i;
	vector p;
	bw_query_chain(this);
	for (i = bw_q_count - 1; i >= 0; i--) {
		bw_q_defined = TRUE;
		p = bw_q_chain[i].SelectTargetPoint(subject);
		if (bw_q_defined)
			return p;
	}
	bw_q_defined = TRUE;
	return subject.origin + (subject.mins + subject.maxs) * 0.5;
}
