/* Bulwark bot framework: ready-made actions. ISC licence, see LICENSE. */

/* --- MoveTo(goal, onSuccess, onFail) ------------------------------------------- */
class BWMoveTo : BWAction {
	vector m_goal;
	BWAction m_on_success, m_on_fail;
	BWPathFollower m_path;
	float m_result;		/* 0 running, 1 reached, -1 failed */

	virtual string GetName(void) { return "MoveTo"; };
	virtual float OnStart(BWAction prior);
	virtual float Update(float interval);
	virtual void OnEnd(BWAction next);
	virtual float OnMoveToSuccess(BWPath path);
	virtual float OnMoveToFailure(BWPath path, float reason);
	nonvirtual float Finish(float ok);
};

BWMoveTo bw_moveto(vector goal, BWAction on_success, BWAction on_fail)
{
	return spawn(BWMoveTo, m_goal: goal, m_on_success: on_success, m_on_fail: on_fail);
}

float BWMoveTo::OnStart(BWAction prior)
{
	m_path = spawn(BWPathFollower);
	Own(m_path);
	m_bot.m_loco.Run();
	if (!m_path.Compute(m_bot, m_goal, 0))
		return Finish(FALSE);
	return Continue();
}

float BWMoveTo::Finish(float ok)
{
	BWAction next = ok ? m_on_success : m_on_fail;
	m_result = ok ? 1 : -1;
	if (ok)
		m_on_success = __NULL__;
	else
		m_on_fail = __NULL__;
	if (next)
		return ChangeTo(next, ok ? "reached the goal" : "can't reach the goal");
	return Done(ok ? "reached the goal" : "can't reach the goal");
}

float BWMoveTo::Update(float interval)
{
	if (m_result)
		return Finish(m_result > 0);
	if (!m_path.IsValid())
		return Finish(FALSE);
	m_path.Follow(m_bot);
	return Continue();
}

float BWMoveTo::OnMoveToSuccess(BWPath path)
{
	if (path != m_path)
		return BWR_CONTINUE;
	m_result = 1;
	return TryToSustain(BWP_TRY, "path done");
}

float BWMoveTo::OnMoveToFailure(BWPath path, float reason)
{
	if (path != m_path)
		return BWR_CONTINUE;
	if (reason == BWFAIL_NO_PATH && path.IsValid())
		return BWR_CONTINUE;	/* partial path: keep going as far as it gets */
	m_result = -1;
	return TryToSustain(BWP_TRY, "path failed");
}

void BWMoveTo::OnEnd(BWAction next)
{
	/* the follow-up actions that were never handed over */
	if (m_on_success && m_on_success != next)
		remove(m_on_success);
	if (m_on_fail && m_on_fail != next)
		remove(m_on_fail);
	m_on_success = m_on_fail = __NULL__;
}

/* --- BackUp(from) ---------------------------------------------------------------- */
class BWBackUp : BWAction {
	vector m_from;
	float m_back_until, m_fwd_until;

	virtual string GetName(void) { return "BackUp"; };
	virtual float OnStart(BWAction prior);
	virtual float Update(float interval);
};

BWBackUp bw_backup(vector from)
{
	return spawn(BWBackUp, m_from: from);
}

float BWBackUp::OnStart(BWAction prior)
{
	float t = 0.3 + random() * 0.2;
	m_back_until = time + t;
	m_fwd_until = m_back_until + t;
	m_bot.m_loco.ClearStuck();
	return Continue();
}

float BWBackUp::Update(float interval)
{
	vector away = bw_flat(m_bot.origin - m_from);
	if (vlen(away) < 1) {
		makevectors([0, m_bot.angles_y, 0]);
		away = -v_forward;
	}
	away = normalize(away);
	if (time < m_back_until) {
		m_bot.m_loco.Approach(m_bot.origin + away * 100, 1);
		m_bot.m_loco.FaceTowards(m_from);
		return Continue();
	}
	if (time < m_fwd_until) {
		m_bot.m_loco.Approach(m_from, 1);
		m_bot.m_loco.FaceTowards(m_from);
		return Continue();
	}
	return Done("backed up");
}

/* --- Dead ------------------------------------------------------------------------ */
class BWDead : BWAction {
	virtual string GetName(void) { return "Dead"; };
	virtual float OnStart(BWAction prior);
	virtual float Update(float interval);
	virtual float HandleEvent(float type);
};

float BWDead::OnStart(BWAction prior)
{
	m_bot.m_loco.Stop();
	m_bot.m_body.ClearAim();
	m_bot.m_body.SetDesiredPosture(BWPOSTURE_LIE);
	m_bot.m_body.StartActivity(BWACT_DIE, 0);
	return Continue();
}

float BWDead::Update(float interval) { return Continue(); }

/* the dead ignore everything */
float BWDead::HandleEvent(float type) { return TryToSustain(BWP_CRITICAL, "dead"); }
