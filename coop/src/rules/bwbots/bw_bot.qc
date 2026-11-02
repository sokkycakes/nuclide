/* Bulwark bot framework: the bot entity, its frame, and the functions the
 * game uses to report combat and sound. ISC licence, see LICENSE. */

/* --- factories and defaults ------------------------------------------------- */

/* a client (a fake one from spawnclient()) is a player bot */
BWLocomotion BWBot::CreateLocomotion(void)
{
	if (flags & FL_CLIENT)
		return spawn(BWPlayerLocomotion);
	return spawn(BWLocomotion);
}
BWBody BWBot::CreateBody(void) { return spawn(BWBody); }
BWVision BWBot::CreateVision(void) { return spawn(BWVision); }
BWIntention BWBot::CreateIntention(void) { return spawn(BWIntention); }
BWAction BWBot::InitialAction(void) { return __NULL__; }
BWAction BWBot::DeadAction(void) { return spawn(BWDead); }

float BWBot::IsEnemy(entity e)
{
	if (!e || e == this)
		return FALSE;
	return (e.team != team) ? TRUE : FALSE;
}

float BWBot::IsFriend(entity e)
{
	if (!e || e == this)
		return FALSE;
	return (e.team == team) ? TRUE : FALSE;
}

#ifndef BW_PAWN_BASE
float BWBot::IsAlive(void) { return (!m_bot_dead && health > 0) ? TRUE : FALSE; }
#endif

string BWBot::BotName(void)
{
	if (netname != "")
		return netname;
	return classname;
}

float BWBot::IsDebugging(float category)
{
	return ((bw_debug_flags & category) && bw_debug_matches(this)) ? TRUE : FALSE;
}

/* --- life cycle ------------------------------------------------------------------ */

/* call once the bot's origin, team, health and tuning are set */
void BWBot::BotStart(void)
{
	float rate = bw_cvar("bot_think_rate");
	if (rate <= 0)
		rate = 10;
	m_loco = CreateLocomotion();
	if (!m_loco.DrivesInput()) {
		solid = SOLID_SLIDEBOX;
		movetype = MOVETYPE_WALK;	/* only for code that looks; .customphysics moves it */
		flags |= FL_MONSTER;
		customphysics = bw_bot_physics;
		if (!bw_cvar("bot_actors_block"))
			hitcontentsmaski = CONTENTBIT_SOLID | CONTENTBIT_PLAYERCLIP | CONTENTBIT_MONSTERCLIP;
	}
	/* a player bot is a client: the game set up its box and physics, and
	 * runs it through bw_player_input each input frame */
	if (!health)
		health = 100;
	if (takedamage == DAMAGE_NO)
		takedamage = DAMAGE_AIM;

	m_body = CreateBody();
	m_vision = CreateVision();
	m_intention = CreateIntention();
	m_loco.m_bot = m_body.m_bot = m_vision.m_bot = m_intention.m_bot = this;
	m_body.Reset();
	m_loco.Reset();
	m_vision.Reset();
	m_intention.Reset();
	setorigin(this, origin);

	/* stagger the full thinks so bots don't all think on one frame */
	m_next_think = time + random() / rate;
	m_bot_next = bw_bots;
	bw_bots = this;
	bw_nbots++;
}

void BWBot::BotRemove(void)
{
	BWBot b, prev = __NULL__;
	float player = (m_loco && m_loco.DrivesInput()) ? TRUE : FALSE;
	for (b = bw_bots; b; prev = b, b = b.m_bot_next) {
		if (b != this)
			continue;
		if (prev)
			prev.m_bot_next = m_bot_next;
		else
			bw_bots = m_bot_next;
		bw_nbots--;
		break;
	}
	if (m_intention) {
		m_intention.Reset();
		remove(m_intention);
	}
	if (m_vision) {
		m_vision.ForgetAll();
		remove(m_vision);
	}
	if (m_body) {
		m_body.ClearAim();
		remove(m_body);
	}
	if (m_loco)
		remove(m_loco);
	m_loco = __NULL__;
	m_body = __NULL__;
	m_vision = __NULL__;
	m_intention = __NULL__;
	customphysics = __NULL__;
	if (!player)
		remove(this);	/* a client stays; the game drops it */
}

/* for player bots the game respawns: the bot starts over from its
 * initial action with a fresh memory */
void BWBot::BotRespawn(void)
{
	float i;
	m_bot_dead = FALSE;
	m_intention.Reset();
	m_vision.Reset();
	m_body.ClearAim();
	m_body.Reset();
	m_loco.Reset();
	for (i = 0; i < 8; i++)
		m_btn_until[i] = 0;
	m_btn_once = 0;
	m_impulse = 0;
	m_next_think = time;
}

/* to every component in turn; the Intention passes it to the actions */
void BWBot::SendEvent(float type)
{
	if (!m_loco)
		return;
	bw_ev_save();
	bw_log(this, BWD_EVENTS, sprintf("event %s %s", bw_event_name(type), bw_ev_e1 ? etos(bw_ev_e1) : ""));
	bw_ev_load();
	m_loco.HandleEvent(type);
	bw_ev_load();
	m_body.HandleEvent(type);
	bw_ev_load();
	m_vision.HandleEvent(type);
	bw_ev_load();
	m_intention.HandleEvent(type);
	bw_ev_drop();
}

void BWBot::BotFrame(void)
{
	float rate = bw_cvar("bot_think_rate"), interval;
	if (rate <= 0)
		rate = 10;
	if (time >= m_next_think && !bw_cvar("bot_stop")) {
		interval = m_last_think ? time - m_last_think : 1 / rate;
		m_last_think = time;
		m_next_think = time + 1 / rate;
		m_intention.EnsureBehavior();	/* so the first sightings have listeners */
		if (IsAlive())
			m_vision.Update(interval);
		m_intention.Update(interval);
	}
	if (bw_cvar("bot_stop"))
		m_loco.Stop();
	m_loco.FrameUpdate(frametime);
	m_body.FrameUpdate(frametime);
}

void bw_bot_physics(void)
{
	BWBot b = (BWBot)self;
	b.BotFrame();
	self = b;
}

/* --- deaths and notifications ------------------------------------------------- */

void BWBot::Killed(entity inflictor, entity attacker, float damage)
{
	if (m_bot_dead)
		return;
	m_bot_dead = TRUE;
	if (health > 0)
		health = 0;
	if (!m_loco.DrivesInput()) {
		/* the game looks after a dead player */
		solid = SOLID_NOT;
		takedamage = DAMAGE_NO;
		deadflag = 1;
	}
	m_loco.Stop();
	m_intention.ForceChange(DeadAction(), "killed");
}

/* the game reports damage it has already applied */
void bw_notify_injured(entity victim, entity inflictor, entity attacker, float damage)
{
	BWBot b;
	for (b = bw_bots; b; b = b.m_bot_next)
		if (b == victim) {
			bw_ev_clear();
			bw_ev_e1 = inflictor;
			bw_ev_e2 = attacker;
			bw_ev_f1 = damage;
			b.SendEvent(BWE_INJURED);
			return;
		}
}

/* the victim hears it was killed; every other bot hears someone was */
void bw_notify_killed(entity victim, entity inflictor, entity attacker, float damage)
{
	BWBot b, n;
	for (b = bw_bots; b; b = n) {
		n = b.m_bot_next;
		bw_ev_clear();
		if (b == victim) {
			b.Killed(inflictor, attacker, damage);
			bw_ev_e1 = inflictor;
			bw_ev_e2 = attacker;
			bw_ev_f1 = damage;
			b.SendEvent(BWE_KILLED);
		} else {
			bw_ev_e1 = victim;
			bw_ev_e2 = attacker;
			b.SendEvent(BWE_OTHER_KILLED);
		}
	}
}

/* volume is how far away the sound can be heard, in units */
void bw_notify_sound(entity source, vector pos, float volume)
{
	BWBot b;
	for (b = bw_bots; b; b = b.m_bot_next) {
		if (b == source || !b.IsAlive())
			continue;
		if (vlen(b.origin - pos) > volume)
			continue;
		bw_log(b, BWD_HEARING, sprintf("heard %s at %v", etos(source), pos));
		bw_ev_clear();
		bw_ev_e1 = source;
		bw_ev_v1 = pos;
		bw_ev_f1 = volume;
		b.SendEvent(BWE_SOUND);
	}
}

/* heard within 1500 units, or seen */
void bw_notify_weapon_fired(entity shooter, entity weapon)
{
	BWBot b;
	for (b = bw_bots; b; b = b.m_bot_next) {
		if (b == shooter || !b.IsAlive())
			continue;
		if (vlen(b.origin - shooter.origin) > 1500 && !b.m_vision.IsAbleToSee(shooter, TRUE))
			continue;
		bw_ev_clear();
		bw_ev_e1 = shooter;
		bw_ev_e2 = weapon;
		b.SendEvent(BWE_WEAPON_FIRED);
	}
}

/* applies damage to a bot and sends the notifications; for games that let
 * the framework keep score */
void bw_damage(entity victim, entity inflictor, entity attacker, float damage)
{
	BWBot b = (BWBot)victim;
	if (!victim || victim.takedamage == DAMAGE_NO || victim.health <= 0)
		return;
	victim.health -= damage;
	bw_notify_injured(victim, inflictor, attacker, damage);
	if (victim.health <= 0 && b.m_loco)
		bw_notify_killed(victim, inflictor, attacker, damage);
}

/* sends a command or custom event to one bot, or all with world */
void bw_send(entity who, float type)
{
	BWBot b, n;
	bw_ev_save();
	for (b = bw_bots; b; b = n) {
		n = b.m_bot_next;
		if (who && b != who)
			continue;
		bw_ev_load();
		b.SendEvent(type);
	}
	bw_ev_drop();
}

void bw_init(void)
{
	bw_cvars_register();
	bw_console_register();
}
