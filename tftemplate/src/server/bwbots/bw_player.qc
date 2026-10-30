/* Bulwark bot framework: player bots. A player bot is a fake client made
 * with spawnclient(). Its Locomotion doesn't move the box: it turns the
 * bot's requests into the input a player would send (view angles, move
 * values, buttons), and the game's own player physics, weapons and rules
 * do the rest. See docs/spec/bots.md, "Player bots". ISC licence. */

float BWPlayerLocomotion::DrivesInput(void) { return TRUE; }

/* how high the player physics jumps */
float bw_player_jump_height(BWLocomotion l)
{
	float js = cvar("sv_jumpspeed");
	if (js <= 0)
		js = 268.3;
	return js * js / (2 * bw_gravity(l));
}

void BWPlayerLocomotion::Reset(void)
{
	float ms = cvar("sv_maxspeed");
	if (!m_run_speed)
		m_run_speed = (ms > 0) ? ms : 320;
	if (!m_walk_speed)
		m_walk_speed = m_run_speed * 0.5;
	if (!m_step)
		m_step = (cvar("sv_stepheight") > 0) ? cvar("sv_stepheight") : 18;
	if (!m_gravity_scale)
		m_gravity_scale = 1;
	if (!m_max_jump)
		m_max_jump = bw_player_jump_height(this) - 2;
	if (!m_yaw_rate)
		m_yaw_rate = 720;	/* the legs follow the view; Body sets how fast that turns */
	super::Reset();
	m_in_move = '0 0 0';
	m_jump_press = FALSE;
	m_air_steer = FALSE;
	m_crouch_air = FALSE;
	m_was_ground = (m_bot.flags & FL_ONGROUND) ? TRUE : FALSE;
}

/* the jump buttons go out on the next input frame; the physics does the rest */
void BWPlayerLocomotion::Jump(float height)
{
	if (!IsOnGround())
		return;
	m_jump_press = TRUE;
	m_jump_at = time;
	m_jumping = TRUE;
}

/* jump from where the bot is, at the speed it has, and keep pushing towards
 * the landing in the air */
float BWPlayerLocomotion::JumpAcrossGap(vector landing, vector fwd)
{
	if (!IsOnGround() || landing_z - m_bot.origin_z > m_max_jump)
		return FALSE;
	Jump(0);
	m_air_goal = landing;
	m_air_steer = TRUE;
	bw_log(m_bot, BWD_LOCOMOTION, sprintf("gap jump to %v", landing));
	return TRUE;
}

/* jump while pressing into the face: once the feet clear the lip the bot
 * moves on top. A ledge above a plain jump gets a crouch jump. */
float BWPlayerLocomotion::ClimbUpToLedge(vector ledge, vector fwd)
{
	if (!IsOnGround() || ledge_z - m_bot.origin_z > m_max_jump + m_crouch_gain)
		return FALSE;
	Jump(0);
	m_crouch_air = (ledge_z - m_bot.origin_z > m_max_jump) ? TRUE : FALSE;
	m_climbing = TRUE;
	m_air_goal = ledge + bw_flat(fwd) * 16;
	m_air_steer = TRUE;
	bw_log(m_bot, BWD_LOCOMOTION, sprintf("climb to %v (%g up)", ledge, ledge_z - m_bot.origin_z));
	return TRUE;
}

/* what the last physics frame did: leaving and landing on the ground */
void BWPlayerLocomotion::Observe(void)
{
	float now = (m_bot.flags & FL_ONGROUND) ? TRUE : FALSE;
	if (now && !m_was_ground) {
		m_jumping = m_climbing = FALSE;
		m_air_steer = FALSE;
		m_crouch_air = FALSE;
		bw_log(m_bot, BWD_LOCOMOTION, "landed");
		bw_ev_clear();
		bw_ev_e1 = m_bot.groundentity;
		m_bot.SendEvent(BWE_LAND);
	} else if (!now && m_was_ground) {
		bw_ev_clear();
		bw_ev_e1 = m_bot.groundentity;
		m_bot.SendEvent(BWE_LEAVE_GROUND);
	} else if (now && m_jumping && !m_jump_press && time - m_jump_at > 0.3) {
		/* the physics didn't take the jump (no room, say) */
		m_jumping = m_climbing = FALSE;
		m_air_steer = FALSE;
		m_crouch_air = FALSE;
	}
	m_was_ground = now;
}

/* the physics doesn't report what a player bumps into: a short sweep ahead
 * finds actors in the way */
void BWPlayerLocomotion::Feel(void)
{
	vector up = '0 0 1' * m_step, from = m_bot.origin + up;
	entity e;
	if (!m_wants_move)
		return;
	tracebox(from, m_bot.mins, m_bot.maxs, from + m_move_dir * (8 + GetSpeed() * 0.1), MOVE_NORMAL, m_bot);
	e = trace_ent;
	if (trace_fraction == 1 || !e || e == world)
		return;
	if (e.flags & (FL_CLIENT | FL_MONSTER))
		m_actor_blocked = time;
	bw_ev_clear();
	bw_ev_e1 = e;
	m_bot.SendEvent(BWE_CONTACT);
}

void BWPlayerLocomotion::FrameUpdate(float dt)
{
	vector to;
	Observe();

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

	if (m_bot.IsAlive())
		Turn(dt);

	/* world-space wish velocity; PlayerInput turns it into move values
	 * against the final view angles */
	m_in_move = '0 0 0';
	if (!IsOnGround() && m_air_steer) {
		to = bw_flat(m_air_goal - m_bot.origin);
		if (vlen(to) > 4)
			m_in_move = normalize(to) * m_run_speed;
	} else if (m_wants_move && m_desired_speed > 0) {
		/* players are quick: steer at the goal every frame, not just every
		 * think, and ease off close to it so as not to circle it */
		to = bw_flat(m_move_goal - m_bot.origin);
		if (vlen(to) > 1) {
			m_move_dir = normalize(to);
			m_in_move = m_move_dir * min(m_desired_speed, max(vlen(to) * 6, 40));
		}
	}

	Feel();
	UpdateStuck();
}

/* --- the input frame ---------------------------------------------------------- */

void BWBot::PressButton(float bits, float duration)
{
	float i, bit;
	if (duration <= 0) {
		m_btn_once |= bits;
		return;
	}
	for (i = 0, bit = 1; i < 8; i++, bit *= 2)
		if (bits & bit)
			m_btn_until[i] = max(m_btn_until[i], time + duration);
}

void BWBot::ReleaseButton(float bits)
{
	float i, bit;
	for (i = 0, bit = 1; i < 8; i++, bit *= 2)
		if (bits & bit)
			m_btn_until[i] = 0;
	m_btn_once &= ~bits;
}

float BWBot::IsButtonDown(float bits)
{
	float i, bit;
	if (m_btn_once & bits)
		return TRUE;
	for (i = 0, bit = 1; i < 8; i++, bit *= 2)
		if ((bits & bit) && time < m_btn_until[i])
			return TRUE;
	return FALSE;
}

/* the buttons for this input frame; one-frame presses are used up */
float BWBot::TakeButtons(void)
{
	float i, bit, b = m_btn_once;
	m_btn_once = 0;
	for (i = 0, bit = 1; i < 8; i++, bit *= 2)
		if (time < m_btn_until[i])
			b |= bit;
	return b;
}

void BWBot::SelectWeapon(float impulse) { m_impulse = impulse; }

/* runs the bot for one input frame and fills input_angles,
 * input_movevalues, input_buttons and input_impulse */
void BWBot::PlayerInput(void)
{
	BWPlayerLocomotion pl = (BWPlayerLocomotion)m_loco;
	vector wish;
	float b;
	BotFrame();
	wish = pl.m_in_move;
	if (IsAlive())
		angles_y = v_angle_y;	/* a player faces where it looks */
	makevectors([0, v_angle_y, 0]);
	input_angles = v_angle;
	input_movevalues = [wish * v_forward, wish * v_right, 0];
	b = TakeButtons();
	if (pl.m_jump_press) {
		b |= BWIN_JUMP;
		pl.m_jump_press = FALSE;
	}
	if (pl.m_crouch_air)
		b |= BWIN_CROUCH;
	switch (m_body.m_posture) {
	case BWPOSTURE_CROUCH:
	case BWPOSTURE_SIT:
		b |= BWIN_CROUCH;
		break;
	case BWPOSTURE_LIE:
		b |= BWIN_PRONE;
		break;
	}
	input_buttons = b;
	input_impulse = m_impulse;
	m_impulse = 0;
}

/* call from SV_RunClientCommand (or Nuclide's ncBot::RunAI) before the
 * player physics; does nothing for clients that aren't player bots */
void bw_player_input(entity pawn)
{
	BWBot b = (BWBot)pawn;
	entity oldself = self;
	if (!b.m_loco)
		return;	/* (QC's || doesn't short-circuit) */
	if (!b.m_loco.DrivesInput())
		return;
	b.PlayerInput();
	self = oldself;
}
