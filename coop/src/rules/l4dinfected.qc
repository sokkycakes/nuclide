/* Left 4 Dead's Hunter and Tank with AI from the Bulwark bot framework
 * (bwbots/, vendored from bulwark-engine qc/bots). For testing: the models
 * are game files kept out of git, drawn as one box per bone (l4dtest.qc).
 *
 *   coop_l4dbot hunter|tank   one 320 units in front of you, hunting players
 *   coop_l4dbotclear          removes them
 *   coop_l4dDebug 1           prints each animation change
 *   bot_status, bot_debug ... the framework's own commands (README.md)
 *
 * Each one is two entities. The brain is a BWBot made here: invisible and
 * non-solid, moved by the framework's locomotion (.customphysics). The body
 * is a Nuclide prop_dynamic (l4d_hunter_ai, l4d_tank_ai) that follows it
 * every frame: it is networked, animated, solid, and takes the players'
 * damage, which is read back from its health and taken off the brain's.
 * The body's owner is the brain, so the brain's movement passes through it.
 *
 * Behaviour follows the framework's own L4D test (tests/bots/bottest.qc):
 * the Hunter chases, crouches, leaps at where its target will be, and pins
 * it (the player can't move) clawing until one of them dies; the Tank
 * chases and punches, knocking the player away. */

#define L4DI_MAX	16
#define L4DI_HUNTER	1
#define L4DI_TANK	2
#define L4DI_BODYHEALTH	100000

var float autocvar_coop_l4dHunterHealth = 250;
var float autocvar_coop_l4dTankHealth = 1500;
var float autocvar_coop_l4dHunterPinDamage = 5;	/* each half second */
var float autocvar_coop_l4dTankPunchDamage = 24;

class L4DInfected : BWBot {
	float m_kind;
	entity m_prop;
	float m_hp;
	float m_cooldown;
	entity m_pinned;	/* the player a Hunter holds down */
	string m_anim;		/* sequence an action asked for... */
	float m_anim_until;	/* ...and until when */
	float m_remove_at;
	virtual BWAction InitialAction(void);
	virtual float IsEnemy(entity e);
	virtual float IsFriend(entity e);
};

L4DInfected g_l4dInfected[L4DI_MAX];
bool g_l4dBotsReady;

/* --- helpers ------------------------------------------------------------------ */

static bool
L4DI_Valid(entity e)
{
	return (e && !wasfreed(e) && e.health > 0 && e.solid != SOLID_NOT && e.takedamage != DAMAGE_NO) ? true : false;
}

/* the Hunter holding this player down, if any */
static L4DInfected
L4DI_PinnedBy(entity victim)
{
	for (int i = 0i; i < L4DI_MAX; i++) {
		L4DInfected b = g_l4dInfected[i];

		if (b && !wasfreed(b) && b.m_pinned == victim) {
			return (b);
		}
	}

	return (__NULL__);
}

static void
L4DI_Release(L4DInfected b)
{
	entity v = b.m_pinned;

	b.m_pinned = world;

	if (v && !wasfreed(v) && v.movetype == MOVETYPE_NONE) {
		v.movetype = MOVETYPE_WALK;
	}
}

/* an action asks the body to play a sequence for a while */
static void
L4DI_Play(L4DInfected b, string seq, float holdTime)
{
	b.m_anim = seq;
	b.m_anim_until = time + holdTime;
}

static void
L4DI_Hurt(L4DInfected b, entity victim, float amount)
{
	combat.RadiusDamage((victim.absmin + victim.absmax) * 0.5f, 1, (int)amount, (int)amount, b.m_prop, "");
}

static void
L4DI_Knock(entity e, vector push)
{
	if (e.flags & FL_ONGROUND) {
		e.flags &= ~FL_ONGROUND;
		ents.Input(e, "SetOrigin", vtos(e.origin + [0, 0, 2]), world);
	}

	e.velocity = push;
}

float
L4DInfected::IsEnemy(entity e)
{
	if (!e || e == this || !(e.flags & FL_CLIENT)) {
		return (FALSE);
	}

	return L4DI_Valid(e) ? TRUE : FALSE;
}

float
L4DInfected::IsFriend(entity e)
{
	return (FALSE);
}

/* --- Hunter ----------------------------------------------------------------------- */

class L4DHunterPinned : BWAction {
	entity m_target;
	float m_next_hit;
	virtual string GetName(void) { return "Pinned"; };
	virtual float OnStart(BWAction prior)
	{
		L4DInfected b = (L4DInfected)m_bot;
		b.m_pinned = m_target;
		m_target.movetype = MOVETYPE_NONE;
		m_target.velocity = [0, 0, 0];
		m_bot.m_loco.Stop();
		m_next_hit = time + 0.5;
		L4DI_Hurt(b, m_target, autocvar_coop_l4dHunterPinDamage);
		return Continue();
	};
	virtual float Update(float interval)
	{
		L4DInfected b = (L4DInfected)m_bot;

		if (!L4DI_Valid(m_target)) {
			return Done("victim gone");
		}

		m_target.movetype = MOVETYPE_NONE;
		m_target.velocity = [0, 0, 0];
		m_bot.m_loco.Stop();
		m_bot.m_loco.FaceTowards(m_target.origin);
		L4DI_Play(b, "Melee_Pounce", 0.5);

		if (time >= m_next_hit) {
			m_next_hit = time + 0.5;
			L4DI_Hurt(b, m_target, autocvar_coop_l4dHunterPinDamage);
		}
		return Continue();
	};
	virtual void OnEnd(BWAction next) { L4DI_Release((L4DInfected)m_bot); };
};

class L4DHunterPounce : BWAction {
	entity m_target;
	float m_phase, m_until, m_touched;
	virtual string GetName(void) { return "Pounce"; };
	virtual float OnStart(BWAction prior)
	{
		m_bot.m_loco.Stop();
		m_bot.m_body.SetDesiredPosture(BWPOSTURE_CROUCH);
		m_until = time + 0.6;
		return Continue();
	};
	virtual float Update(float interval)
	{
		L4DInfected b = (L4DInfected)m_bot;
		vector pred, v;
		float d, t, g = cvar("sv_gravity");

		if (!L4DI_Valid(m_target)) {
			return Done("target gone");
		}

		switch (m_phase) {
		case 0:	/* crouch, then leap at where the target will be */
			m_bot.m_loco.Stop();
			m_bot.m_loco.FaceTowards(m_target.origin);
			m_bot.m_body.AimHeadTowardsEntity(m_target, BWLOOK_IMPORTANT, 0.3, __NULL__, "pounce");
			L4DI_Play(b, "pounce_idle_01", 0.2);

			if (time < m_until) {
				return Continue();
			}
			/* a target flying from a punch can't be led; wait for it to land */
			if (!(m_target.flags & FL_ONGROUND) && time < m_until + 1) {
				return Continue();
			}

			d = bw_dist2d(m_bot.origin, m_target.origin);
			pred = m_target.origin + bw_flat(m_target.velocity) * (d / 700);
			t = max(0.1, bw_dist2d(m_bot.origin, pred) / 700);
			v = normalize(bw_flat(pred - m_bot.origin)) * 700;
			v[2] = bound(100, ((pred[2] - m_bot.origin[2]) + 0.5 * g * t * t) / t, 450);
			m_bot.m_body.SetDesiredPosture(BWPOSTURE_STAND);
			m_bot.m_loco.Leap(v);
			/* a little air control keeps it on a target that turns */
			m_bot.m_loco.m_air_goal = pred;
			m_bot.m_loco.m_air_speed = 700;
			m_bot.m_loco.m_air_accel = 400;
			L4DI_Play(b, "Lunge_While_Running_01", 0.4);
			m_phase = 1;
			m_until = time + 3;
			return Continue();
		case 1:	/* in the air */
			if (!m_bot.m_loco.IsOnGround()) {
				m_bot.m_loco.m_air_goal = m_target.origin;
			}

			/* the brain doesn't collide with players: landing next to one is a hit */
			if (m_touched || vlen(m_target.origin - (m_bot.origin + [0, 0, 32])) < 56) {
				if (!L4DI_PinnedBy(m_target)) {
					return ChangeTo(spawn(L4DHunterPinned, m_target: m_target), "pinned");
				}
			}

			if (m_bot.m_loco.IsOnGround() || time > m_until) {
				m_phase = 2;
				m_until = time + 1.5;
				L4DI_Play(b, "Lunge_Land_low_nav_01", 0.7);
			}
			return Continue();
		}

		/* missed: wait before trying again */
		if (time < m_until) {
			return Continue();
		}

		return Done("missed");
	};
	virtual float OnContact(entity touched)
	{
		if (m_phase == 1 && touched == m_target) {
			m_touched = TRUE;
		}
		return BWR_CONTINUE;
	};
	virtual void OnEnd(BWAction next) { m_bot.m_body.SetDesiredPosture(BWPOSTURE_STAND); };
};

class L4DHunterMain : BWAction {
	BWChasePath m_chase;
	virtual string GetName(void) { return "HunterAttack"; };
	virtual float OnStart(BWAction prior)
	{
		m_chase = spawn(BWChasePath);
		Own(m_chase);
		return Continue();
	};
	virtual float Update(float interval)
	{
		BWKnown k = m_bot.m_vision.GetPrimaryKnownThreat(FALSE);
		entity t;

		if (!k) {
			m_bot.m_loco.Stop();
			return Continue();
		}

		t = k.m_subject;

		if (k.m_visible && vlen(t.origin - m_bot.origin) < 600 && m_bot.m_loco.IsOnGround() &&
			!L4DI_PinnedBy(t) && (t.flags & FL_ONGROUND)) {
			return SuspendFor(spawn(L4DHunterPounce, m_target: t), "target in range");
		}

		m_chase.Chase(m_bot, t);
		m_bot.m_body.AimHeadTowardsEntity(t, BWLOOK_IMPORTANT, 0.3, __NULL__, "hunting");
		return Continue();
	};
};

/* --- Tank --------------------------------------------------------------------------- */

class L4DTankPunch : BWAction {
	entity m_target;
	float m_hit_at;
	virtual string GetName(void) { return "Punch"; };
	virtual float OnStart(BWAction prior)
	{
		m_hit_at = time + 0.4;
		L4DI_Play((L4DInfected)m_bot, "Attack", 1.0);
		return Continue();
	};
	virtual float Update(float interval)
	{
		L4DInfected b = (L4DInfected)m_bot;
		vector dir;

		if (!L4DI_Valid(m_target)) {
			return Done("target gone");
		}

		m_bot.m_loco.Stop();
		m_bot.m_loco.FaceTowards(m_target.origin);

		if (time < m_hit_at) {
			return Continue();
		}

		b.m_cooldown = time + 1.5;

		if (vlen(m_target.origin - m_bot.origin) > 110) {
			return Done("out of reach");
		}

		dir = normalize(bw_flat(m_target.origin - m_bot.origin));

		/* a punch knocks a pinned survivor free */
		L4DInfected pinner = L4DI_PinnedBy(m_target);

		if (pinner) {
			L4DI_Release(pinner);
		}

		L4DI_Knock(m_target, dir * 450 + [0, 0, 300]);
		L4DI_Hurt(b, m_target, autocvar_coop_l4dTankPunchDamage);
		return Done("punched");
	};
};

class L4DTankMain : BWAction {
	BWChasePath m_chase;
	virtual string GetName(void) { return "TankAttack"; };
	virtual float OnStart(BWAction prior)
	{
		m_chase = spawn(BWChasePath, m_lead: 500);
		Own(m_chase);
		return Continue();
	};
	virtual float Update(float interval)
	{
		L4DInfected b = (L4DInfected)m_bot;
		BWKnown k = m_bot.m_vision.GetPrimaryKnownThreat(FALSE);
		entity t;

		if (!k) {
			m_bot.m_loco.Stop();
			return Continue();
		}

		t = k.m_subject;

		if (vlen(t.origin - m_bot.origin) < 80 && time >= b.m_cooldown) {
			return SuspendFor(spawn(L4DTankPunch, m_target: t), "in reach");
		}

		m_chase.Chase(m_bot, t);
		m_bot.m_body.AimHeadTowardsEntity(t, BWLOOK_IMPORTANT, 0.3, __NULL__, "tank");
		return Continue();
	};
};

BWAction
L4DInfected::InitialAction(void)
{
	if (m_kind == L4DI_TANK) {
		return spawn(L4DTankMain);
	}

	return spawn(L4DHunterMain);
}

/* --- body: animation, damage, death ------------------------------------------------ */

/* the sequence for what the brain is doing now */
static string
L4DI_PickAnim(L4DInfected b)
{
	float speed = vlen(bw_flat(b.velocity));
	bool hunter = (b.m_kind == L4DI_HUNTER);

	if (b.m_bot_dead) {
		return hunter ? "deathpose_front" : "Death";
	}

	if (b.m_anim != "" && time < b.m_anim_until) {
		return b.m_anim;
	}

	if (!b.m_loco.IsOnGround()) {
		return hunter ? "Fall_Idle" : "Jump";
	}

	if (b.m_body.GetPosture() == BWPOSTURE_CROUCH) {
		if (speed > 20) {
			return hunter ? "Crouch_Walk_Upper_KNIFE:a_Crouch_Walk_Upper_KNIFEN" : "Crouch_Walk:a_CrouchWalkN";
		}
		return hunter ? "pounce_idle_01" : "Crouch_Idle";
	}

	if (speed > 150) {
		return hunter ? "Run_Upper_KNIFE:a_RunN" : "Run_1:a_RunN";
	}

	if (speed > 20) {
		return hunter ? "Walk_Upper_Knife:a_Walk_Upper_KnifeN" : "Walk:a_WalkN";
	}

	return hunter ? "Idle_Standing_01" : "Idle";
}

static void
L4DI_Remove(int slot)
{
	L4DInfected b = g_l4dInfected[slot];

	g_l4dInfected[slot] = __NULL__;

	if (!b || wasfreed(b)) {
		return;
	}

	L4DI_Release(b);

	if (b.m_prop && !wasfreed(b.m_prop)) {
		remove(b.m_prop);
	}

	b.BotRemove();
}

static void
L4DI_BodyFrame(int slot)
{
	L4DInfected b = g_l4dInfected[slot];
	entity body = b.m_prop;

	if (!body || wasfreed(body)) {
		L4DI_Remove(slot);
		return;
	}

	/* damage the players did to the body comes off the brain */
	if (!b.m_bot_dead && body.health < L4DI_BODYHEALTH) {
		float dmg = L4DI_BODYHEALTH - body.health;
		ents.Input(body, "SetHealth", ftos(L4DI_BODYHEALTH), world);
		b.m_hp -= dmg;
		b.health = max(1, b.m_hp);
		bw_notify_injured(b, world, world, dmg);

		if (b.m_hp <= 0) {
			L4DI_Release(b);
			b.Killed(world, world, dmg);
			body.solid = SOLID_NOT;
			body.takedamage = DAMAGE_NO;
			b.m_remove_at = time + 10;
			print(sprintf("coop_l4dbot: %s killed\n", b.netname));
		}
	}

	if (b.m_bot_dead && time >= b.m_remove_at) {
		L4DI_Remove(slot);
		return;
	}

	/* follow the brain */
	setorigin(body, b.origin);
	body.angles = [0, b.angles[1], 0];
	body.velocity = b.velocity;

	if (!b.m_bot_dead) {
		setsize(body, b.mins, b.maxs);
	}

	float fr = frameforname(body.modelindex, L4DI_PickAnim(b));

	if (fr >= 0 && body.frame != fr) {
		body.frame = fr;

		if (cvar("coop_l4dDebug")) {
			print(sprintf("%.2f %s: %s (%s)\n", time, b.netname, frametoname(body.modelindex, fr), b.m_intention.StackString()));
		}
	}
}

void
L4DInfected_Frame(void)
{
	if (!g_l4dBotsReady) {
		return;
	}

	for (int i = 0i; i < L4DI_MAX; i++) {
		if (g_l4dInfected[i]) {
			L4DI_BodyFrame(i);
		}
	}
}

/* --- console ----------------------------------------------------------------------- */

static void
L4DI_Spawn(entity pl, string which)
{
	float kind = 0;
	string bodyClass = "";
	int slot = -1i;

	switch (strtolower(which)) {
	case "hunter":
		kind = L4DI_HUNTER;
		bodyClass = "l4d_hunter_ai";
		break;
	case "tank":
	case "hulk":
		kind = L4DI_TANK;
		bodyClass = "l4d_tank_ai";
		break;
	default:
		print("coop_l4dbot: hunter or tank\n");
		return;
	}

	for (int i = 0i; i < L4DI_MAX; i++) {
		if (!g_l4dInfected[i]) {
			slot = i;
			break;
		}
	}

	if (slot < 0i) {
		print("coop_l4dbot: too many; coop_l4dbotclear removes them\n");
		return;
	}

	if (!g_l4dBotsReady) {
		bw_cvars_register();
		g_l4dBotsReady = true;
	}

	/* up to 320 units ahead, on the floor */
	vector eye = pl.origin + pl.view_ofs;
	makevectors([0, pl.v_angle[1], 0]);
	tracebox(eye, [-16, -16, 0], [16, 16, 16], eye + v_forward * 320, MOVE_NOMONSTERS, pl);
	vector spot = trace_endpos - v_forward * 16;

	/* stepped aside from any already there, so they don't start stuck */
	for (int tries = 0i; tries < 8i; tries++) {
		bool taken = false;

		for (int i = 0i; i < L4DI_MAX; i++) {
			L4DInfected other = g_l4dInfected[i];

			if (other && vlen([other.origin[0] - spot[0], other.origin[1] - spot[1], 0]) < 64) {
				taken = true;
			}
		}

		if (!taken) {
			break;
		}

		spot += v_right * 72;
	}

	traceline(spot, spot - [0, 0, 512], MOVE_NOMONSTERS, pl);
	spot = trace_endpos + [0, 0, 1];

	L4DInfected b = spawn(L4DInfected, m_kind: kind, team: 3);
	b.netname = (kind == L4DI_TANK) ? "Tank" : "Hunter";
	b.classname = "l4d_infected";
	b.angles = [0, pl.v_angle[1] + 180, 0];
	b.origin = spot;
	b.m_hp = (kind == L4DI_TANK) ? autocvar_coop_l4dTankHealth : autocvar_coop_l4dHunterHealth;
	b.health = b.m_hp;
	b.BotStart();
	/* the brain is invisible and neither solid nor a target: the body is */
	b.solid = SOLID_NOT;
	b.takedamage = DAMAGE_NO;
	b.flags &= ~FL_MONSTER;
	b.m_loco.m_run_speed = (kind == L4DI_TANK) ? 210 : 250;

	if (kind == L4DI_TANK) {
		b.m_loco.m_accel = 800;
	}

	b.m_loco.Run();

	entity body = ents.Create(bodyClass, spot);
	body.owner = b;
	body.angles = b.angles;
	ents.Input(body, "SetMaxHealth", ftos(L4DI_BODYHEALTH), world);
	ents.Input(body, "SetHealth", ftos(L4DI_BODYHEALTH), world);
	body.solid = SOLID_BBOX;
	setsize(body, b.mins, b.maxs);
	b.m_prop = body;
	g_l4dInfected[slot] = b;
	print(sprintf("coop_l4dbot: %s at %v with %g health (brain #%d, body #%d)\n", b.netname, spot, b.m_hp, num_for_edict(b), num_for_edict(body)));
}

bool
L4DInfected_Command(entity pl, string line)
{
	tokenize(line);

	switch (argv(0)) {
	case "coop_l4dbot":
		L4DI_Spawn(pl, argv(1));
		return (true);
	case "coop_l4dbotclear":
		for (int i = 0i; i < L4DI_MAX; i++) {
			L4DI_Remove(i);
		}
		return (true);
	}

	if (g_l4dBotsReady && substring(argv(0), 0, 4) == "bot_") {
		return bw_console_command(line) ? true : false;
	}

	return (false);
}
