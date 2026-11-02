/* Bulwark bot framework: small helpers, cvars, debug output and the event
 * dispatcher shared by components and actions. ISC licence, see LICENSE. */

float bw_cvar(string name) { return cvar(name); }

/* signed difference b - a, in -180..180 */
float bw_anglediff(float a, float b)
{
	float d = b - a;
	d = d - 360 * floor((d + 180) / 360);
	return d;
}

vector bw_flat(vector v) { v_z = 0; return v; }

float bw_dist2d(vector a, vector b) { return vlen(bw_flat(b - a)); }

void bw_cvars_register(void)
{
	registercvar("bot_think_rate", "10");
	registercvar("bot_stop", "0");
	registercvar("bot_blind", "0");
	registercvar("bot_allow_climb", "1");
	registercvar("bot_allow_gap_jump", "1");
	registercvar("bot_allow_avoid", "1");
	registercvar("bot_lookahead", "300");
	registercvar("bot_actors_block", "1");
	registercvar("bot_debug_draw", "0");
}

/* --- debug output ---------------------------------------------------------- */

float bw_debug_matches(BWBot bot)
{
	float i;
	if (!bw_debug_nfilter)
		return TRUE;
	for (i = 0; i < bw_debug_nfilter; i++) {
		if (bw_debug_filter[i] == ftos(num_for_edict(bot)))
			return TRUE;
		if (strtolower(bw_debug_filter[i]) == strtolower(bot.BotName()))
			return TRUE;
	}
	return FALSE;
}

void bw_log(BWBot bot, float cat, string msg)
{
	if (!(bw_debug_flags & cat))
		return;
	if (bot)
		if (!bw_debug_matches(bot))
			return;
	if (bot)
		print(sprintf("%.2f %s(%d): %s\n", time, bot.BotName(), num_for_edict(bot), msg));
	else
		print(sprintf("%.2f bots: %s\n", time, msg));
}

string bw_event_name(float type)
{
	switch (type) {
	case BWE_LEAVE_GROUND: return "LeaveGround";
	case BWE_LAND: return "LandOnGround";
	case BWE_CONTACT: return "Contact";
	case BWE_MOVE_SUCCESS: return "MoveToSuccess";
	case BWE_MOVE_FAIL: return "MoveToFailure";
	case BWE_STUCK: return "Stuck";
	case BWE_UNSTUCK: return "UnStuck";
	case BWE_POSTURE: return "PostureChanged";
	case BWE_ANIM_DONE: return "AnimationActivityComplete";
	case BWE_ANIM_INTERRUPTED: return "AnimationActivityInterrupted";
	case BWE_ANIM_EVENT: return "AnimationEvent";
	case BWE_INJURED: return "Injured";
	case BWE_KILLED: return "Killed";
	case BWE_OTHER_KILLED: return "OtherKilled";
	case BWE_SIGHT: return "Sight";
	case BWE_LOST_SIGHT: return "LostSight";
	case BWE_SOUND: return "Sound";
	case BWE_WEAPON_FIRED: return "WeaponFired";
	case BWE_CMD_ATTACK: return "CommandAttack";
	case BWE_CMD_APPROACH_POS: return "CommandApproach";
	case BWE_CMD_APPROACH_ENT: return "CommandApproachEntity";
	case BWE_CMD_RETREAT: return "CommandRetreat";
	case BWE_CMD_PAUSE: return "CommandPause";
	case BWE_CMD_RESUME: return "CommandResume";
	case BWE_CMD_STRING: return "CommandString";
	case BWE_MODEL_CHANGED: return "ModelChanged";
	case BWE_PICKUP: return "PickUp";
	case BWE_DROP: return "Drop";
	case BWE_SHOVED: return "Shoved";
	case BWE_BLINDED: return "Blinded";
	case BWE_WIN: return "Win";
	case BWE_LOSE: return "Lose";
	case BWE_CUSTOM: return "CustomEvent";
	}
	return "?";
}

string bw_result_name(float r)
{
	switch (r) {
	case BWR_CONTINUE: return "CONTINUE";
	case BWR_CHANGE: return "CHANGE_TO";
	case BWR_SUSPEND: return "SUSPEND_FOR";
	case BWR_DONE: return "DONE";
	case BWR_SUSTAIN: return "SUSTAIN";
	}
	return "?";
}

/* --- event payload stack ----------------------------------------------------
 * An event handler may send another event; each nesting level keeps its own
 * copy of the payload so later listeners of the outer event still see it. */

#define BW_EVDEPTH 8
entity bw_evs_e1[BW_EVDEPTH], bw_evs_e2[BW_EVDEPTH];
vector bw_evs_v1[BW_EVDEPTH];
float bw_evs_f1[BW_EVDEPTH];
string bw_evs_s1[BW_EVDEPTH], bw_evs_s2[BW_EVDEPTH];
float bw_ev_sp;

void bw_ev_save(void)
{
	float i = bw_ev_sp;
	if (i >= BW_EVDEPTH)
		error("bots: events nested too deep\n");
	bw_evs_e1[i] = bw_ev_e1;
	bw_evs_e2[i] = bw_ev_e2;
	bw_evs_v1[i] = bw_ev_v1;
	bw_evs_f1[i] = bw_ev_f1;
	bw_evs_s1[i] = bw_ev_s1;
	bw_evs_s2[i] = bw_ev_s2;
	bw_ev_sp = i + 1;
}

void bw_ev_load(void)
{
	float i = bw_ev_sp - 1;
	if (i < 0)
		return;
	bw_ev_e1 = bw_evs_e1[i];
	bw_ev_e2 = bw_evs_e2[i];
	bw_ev_v1 = bw_evs_v1[i];
	bw_ev_f1 = bw_evs_f1[i];
	bw_ev_s1 = bw_evs_s1[i];
	bw_ev_s2 = bw_evs_s2[i];
}

void bw_ev_drop(void)
{
	if (bw_ev_sp > 0)
		bw_ev_sp--;
}

/* clears the payload before a new event is filled in */
void bw_ev_clear(void)
{
	bw_ev_e1 = bw_ev_e2 = world;
	bw_ev_v1 = '0 0 0';
	bw_ev_f1 = 0;
	bw_ev_s1 = bw_ev_s2 = "";
}

/* --- default event handlers ----------------------------------------------- */

float BWEvents::OnLeaveGround(entity ground) { return BWR_CONTINUE; }
float BWEvents::OnLandOnGround(entity ground) { return BWR_CONTINUE; }
float BWEvents::OnContact(entity touched) { return BWR_CONTINUE; }
float BWEvents::OnMoveToSuccess(BWPath path) { return BWR_CONTINUE; }
float BWEvents::OnMoveToFailure(BWPath path, float reason) { return BWR_CONTINUE; }
float BWEvents::OnStuck(void) { return BWR_CONTINUE; }
float BWEvents::OnUnStuck(void) { return BWR_CONTINUE; }
float BWEvents::OnPostureChanged(void) { return BWR_CONTINUE; }
float BWEvents::OnAnimationActivityComplete(float activity) { return BWR_CONTINUE; }
float BWEvents::OnAnimationActivityInterrupted(float activity) { return BWR_CONTINUE; }
float BWEvents::OnAnimationEvent(float id, string options) { return BWR_CONTINUE; }
float BWEvents::OnInjured(entity inflictor, entity attacker, float damage) { return BWR_CONTINUE; }
float BWEvents::OnKilled(entity inflictor, entity attacker, float damage) { return BWR_CONTINUE; }
float BWEvents::OnOtherKilled(entity victim, entity attacker) { return BWR_CONTINUE; }
float BWEvents::OnSight(entity subject) { return BWR_CONTINUE; }
float BWEvents::OnLostSight(entity subject) { return BWR_CONTINUE; }
float BWEvents::OnSound(entity source, vector pos, float volume) { return BWR_CONTINUE; }
float BWEvents::OnWeaponFired(entity shooter, entity weapon) { return BWR_CONTINUE; }
float BWEvents::OnCommandAttack(entity victim) { return BWR_CONTINUE; }
float BWEvents::OnCommandApproach(vector pos, float tolerance) { return BWR_CONTINUE; }
float BWEvents::OnCommandApproachEntity(entity goal) { return BWR_CONTINUE; }
float BWEvents::OnCommandRetreat(entity threat, float range) { return BWR_CONTINUE; }
float BWEvents::OnCommandPause(float duration) { return BWR_CONTINUE; }
float BWEvents::OnCommandResume(void) { return BWR_CONTINUE; }
float BWEvents::OnCommandString(string cmd) { return BWR_CONTINUE; }
float BWEvents::OnModelChanged(void) { return BWR_CONTINUE; }
float BWEvents::OnPickUp(entity item, entity giver) { return BWR_CONTINUE; }
float BWEvents::OnDrop(entity item) { return BWR_CONTINUE; }
float BWEvents::OnShoved(entity pusher) { return BWR_CONTINUE; }
float BWEvents::OnBlinded(entity blinder) { return BWR_CONTINUE; }
float BWEvents::OnWin(void) { return BWR_CONTINUE; }
float BWEvents::OnLose(void) { return BWR_CONTINUE; }
float BWEvents::OnCustomEvent(string name, string text) { return BWR_CONTINUE; }

/* calls the handler for one event with the current payload */
float BWEvents::HandleEvent(float type)
{
	switch (type) {
	case BWE_LEAVE_GROUND: return OnLeaveGround(bw_ev_e1);
	case BWE_LAND: return OnLandOnGround(bw_ev_e1);
	case BWE_CONTACT: return OnContact(bw_ev_e1);
	case BWE_MOVE_SUCCESS: return OnMoveToSuccess((BWPath)bw_ev_e1);
	case BWE_MOVE_FAIL: return OnMoveToFailure((BWPath)bw_ev_e1, bw_ev_f1);
	case BWE_STUCK: return OnStuck();
	case BWE_UNSTUCK: return OnUnStuck();
	case BWE_POSTURE: return OnPostureChanged();
	case BWE_ANIM_DONE: return OnAnimationActivityComplete(bw_ev_f1);
	case BWE_ANIM_INTERRUPTED: return OnAnimationActivityInterrupted(bw_ev_f1);
	case BWE_ANIM_EVENT: return OnAnimationEvent(bw_ev_f1, bw_ev_s1);
	case BWE_INJURED: return OnInjured(bw_ev_e1, bw_ev_e2, bw_ev_f1);
	case BWE_KILLED: return OnKilled(bw_ev_e1, bw_ev_e2, bw_ev_f1);
	case BWE_OTHER_KILLED: return OnOtherKilled(bw_ev_e1, bw_ev_e2);
	case BWE_SIGHT: return OnSight(bw_ev_e1);
	case BWE_LOST_SIGHT: return OnLostSight(bw_ev_e1);
	case BWE_SOUND: return OnSound(bw_ev_e1, bw_ev_v1, bw_ev_f1);
	case BWE_WEAPON_FIRED: return OnWeaponFired(bw_ev_e1, bw_ev_e2);
	case BWE_CMD_ATTACK: return OnCommandAttack(bw_ev_e1);
	case BWE_CMD_APPROACH_POS: return OnCommandApproach(bw_ev_v1, bw_ev_f1);
	case BWE_CMD_APPROACH_ENT: return OnCommandApproachEntity(bw_ev_e1);
	case BWE_CMD_RETREAT: return OnCommandRetreat(bw_ev_e1, bw_ev_f1);
	case BWE_CMD_PAUSE: return OnCommandPause(bw_ev_f1);
	case BWE_CMD_RESUME: return OnCommandResume();
	case BWE_CMD_STRING: return OnCommandString(bw_ev_s1);
	case BWE_MODEL_CHANGED: return OnModelChanged();
	case BWE_PICKUP: return OnPickUp(bw_ev_e1, bw_ev_e2);
	case BWE_DROP: return OnDrop(bw_ev_e1);
	case BWE_SHOVED: return OnShoved(bw_ev_e1);
	case BWE_BLINDED: return OnBlinded(bw_ev_e1);
	case BWE_WIN: return OnWin();
	case BWE_LOSE: return OnLose();
	case BWE_CUSTOM: return OnCustomEvent(bw_ev_s1, bw_ev_s2);
	}
	return BWR_CONTINUE;
}

void BWComponent::Reset(void) { }
void BWComponent::Update(float interval) { }
void BWComponent::FrameUpdate(float dt) { }

void BWAimReply::OnSuccess(BWBot bot) { }
void BWAimReply::OnFail(BWBot bot, float reason) { }
