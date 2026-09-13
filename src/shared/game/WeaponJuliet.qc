/*
 * Juliet stored charge shot. Predicted ncPlayer fields, not chargeTime.
 * Store = charging off, keep level. Fire / dump / reset clear level.
 */

#define JULIET_CHARGE_TIME		2.5f
#define JULIET_DASH_RECOVERY		0.5f
#define JULIET_FIRE_INTERVAL		1.7f
#define JULIET_GROUND_DASH_SPEED	660.0f
/* Match crouch-slide: PMove divides pm_friction by this (slide default 100). */
#define JULIET_DASH_FRICTION		100.0f
/* Flat-ground soft drag while icing (slide default 3; lower = slipperier). */
#define JULIET_DASH_DRAG		1.5f
#define JULIET_CHARGE_SND		"weapon_juliet.charge"
#define JULIET_SHOT_SND			"weapon_juliet.shot"
#define JULIET_CHARGE_FIRE_SND		"weapon_juliet.charge_fire"
#define JULIET_READY_SND		"weapon_juliet.ready"
#define JULIET_CHARGE_CHAN		CHAN_WEAPON

void Juliet_ChargeStore(entity player);
void Juliet_ChargeReset(entity player);
bool Juliet_ChargePress(entity player);
void Juliet_ChargePMove(entity player);

static string
Juliet_ProjForLevel(float level)
{
	if (level >= 0.85f) {
		return ("projectile_juliet_full");
	}
	if (level >= 0.55f) {
		return ("projectile_juliet_near");
	}
	if (level >= 0.25f) {
		return ("projectile_juliet_mid");
	}
	return ("projectile_juliet_min");
}

#ifdef SERVER
static void
Juliet_Dirty(ncPlayer pl)
{
	if (pl) {
		pl.SendFlags |= PLAYER_STILETTO;
	}
}

static void
Juliet_ChargeSound(entity player, int playing)
{
	ncPlayer pl = (ncPlayer)player;

	if (!pl) {
		return;
	}

	if (playing) {
		precache.Sound(JULIET_CHARGE_SND);
		pl.StartSoundDef(JULIET_CHARGE_SND, JULIET_CHARGE_CHAN, true);
	} else {
		pl.StopSound(JULIET_CHARGE_CHAN, true);
	}
}

/* Low 0.25: 75% vol / +5% pitch. Mid 0.55: 80% / flat. Full 1.0: 100% / -15%. */
static void
Juliet_PlayChargeFire(entity player, float level)
{
	ncPlayer pl = (ncPlayer)player;
	float t;
	float vol;
	float pitch;

	if (!pl) {
		return;
	}

	if (level < 0.55f) {
		t = bound(0.0f, (level - 0.25f) / 0.30f, 1.0f);
		vol = 0.75f + (0.05f * t);
		pitch = 105.0f - (5.0f * t);
	} else {
		t = bound(0.0f, (level - 0.55f) / 0.45f, 1.0f);
		vol = 0.80f + (0.20f * t);
		pitch = 100.0f - (15.0f * t);
	}

	precache.Sound(JULIET_CHARGE_FIRE_SND);
	sound(pl, JULIET_CHARGE_CHAN, "weapons/julietcharge_fire.ogg",
	    vol, ATTN_NORM, pitch, SOUNDFLAG_FOLLOW, 0);
}

/* Fire lock is about to expire this frame (PostMove ticks the timer after). */
static void
Juliet_ReadyCue(ncPlayer pl)
{
	if (!pl) {
		return;
	}

	if (pl.declclass != "hero_juliet" && pl.classname != "hero_juliet") {
		return;
	}

	if (pl.m_timeUntilNextAttack <= 0.0f
	    || pl.m_timeUntilNextAttack > input_timelength) {
		return;
	}

	precache.Sound(JULIET_READY_SND);
	pl.StartSoundDef(JULIET_READY_SND, CHAN_ITEM, true);
}
#endif

void
Juliet_ChargeStore(entity player)
{
	ncPlayer pl = (ncPlayer)player;

	if (!pl) {
		return;
	}

	pl.m_julietCharging = 0;
	pl.m_julietMoveLatch = 0;
#ifdef SERVER
	Juliet_ChargeSound(pl, 0);
	Juliet_Dirty(pl);
#endif
}

void
Juliet_ChargeReset(entity player)
{
	ncPlayer pl = (ncPlayer)player;

	if (!pl) {
		return;
	}

	pl.m_julietChargeLevel = 0.0f;
	pl.m_julietCharging = 0;
	pl.m_julietDashRecovery = 0.0f;
	pl.m_julietMoveLatch = 0;
#ifdef SERVER
	Juliet_ChargeSound(pl, 0);
	Juliet_Dirty(pl);
#endif
}

bool
Juliet_ChargePress(entity player)
{
	ncPlayer pl = (ncPlayer)player;
	string proj;

	if (!pl) {
		return (false);
	}

	/* Own gate — do not trust weapon m_fiFireRate (often 0 if fireInfo
	 * cache missed). Shared timer already ticks in Physics_InputPostMove. */
	if (pl.m_timeUntilNextAttack > 0.0f) {
		return (false);
	}

	if (pl.m_julietDashRecovery > 0.0f) {
		return (false);
	}

	if (pl.m_julietCharging) {
		float level = pl.m_julietChargeLevel;

		proj = Juliet_ProjForLevel(level);
		pl.m_julietCharging = 0;
		pl.m_julietChargeLevel = 0.0f;
		pl.m_julietMoveLatch = 0;
		/* Shot fired: lock start/fire for JULIET_FIRE_INTERVAL. */
		pl.m_timeUntilNextAttack = JULIET_FIRE_INTERVAL;
#ifdef SERVER
		Juliet_ChargeSound(pl, 0);
		if (proj == "projectile_juliet_min") {
			precache.Sound(JULIET_SHOT_SND);
			pl.StartSoundDef(JULIET_SHOT_SND, JULIET_CHARGE_CHAN, true);
		} else {
			Juliet_PlayChargeFire(pl, level);
		}
		ncProjectile_SpawnDef(proj, (ncActor)pl);
		Juliet_Dirty(pl);
#endif
		return (true);
	}

	pl.m_julietCharging = 1;
	/* Held walk must be released before a dodge-cancel can fire. */
	pl.m_julietMoveLatch = 1;
#ifdef SERVER
	Juliet_ChargeSound(pl, 1);
	Juliet_Dirty(pl);
#endif
	return (true);
}

void
Juliet_ChargePMove(entity player)
{
	ncPlayer pl = (ncPlayer)player;
	float horiz;
	vector dodgeDir;
	vector fwd;
	vector right;

	if (!pl) {
		return;
	}

#ifdef SERVER
	/* Runs even while not charging — cue when shot lock expires. */
	Juliet_ReadyCue(pl);
#endif

	if (pl.m_julietDashRecovery > 0.0f) {
		float drag;

		pl.m_julietDashRecovery -= input_timelength;
		if (pl.m_julietDashRecovery < 0.0f) {
			pl.m_julietDashRecovery = 0.0f;
		}
		/* Full action lock until dash recovery ends. */
		input_movevalues[0] = 0;
		input_movevalues[1] = 0;
		input_movevalues[2] = 0;
		input_buttons &= ~(INPUT_PRIMARY | INPUT_SECONDARY | INPUT_RELOAD
		    | INPUT_JUMP | INPUT_MELEE | INPUT_HERO_TOOL
		    | INPUT_STILETTO_DASH | INPUT_USE | INPUT_CROUCH | INPUT_PRONE);
		/* Same friction divisor hook as crouch-slide (consumed in PMove). */
		pl.friction = JULIET_DASH_FRICTION;
		/* Soft horizontal coast — do not use m_stilettoDashAddVel (air-dash
		 * bleed subtracts that impulse and kills the slide). */
		if (pl.flags & FL_ONGROUND) {
			drag = JULIET_DASH_DRAG * input_timelength;
			if (drag > 0.999f) {
				drag = 0.999f;
			}
			pl.velocity[0] *= (1.0f - drag);
			pl.velocity[1] *= (1.0f - drag);
		}
		return;
	}

	if (!pl.m_julietCharging) {
		return;
	}

	/* Jump stores without spending the burst. Rising edge so held jump
	 * after landing does not immediately store a fresh charge. */
	if ((input_buttons & INPUT_JUMP)
	    && !(pl.m_stilettoPrevButtons & INPUT_JUMP)) {
		Juliet_ChargeStore(pl);
		return;
	}

	pl.m_julietChargeLevel += input_timelength / JULIET_CHARGE_TIME;
	if (pl.m_julietChargeLevel > 1.0f) {
		pl.m_julietChargeLevel = 1.0f;
	}

	horiz = sqrt(input_movevalues[0] * input_movevalues[0]
	    + input_movevalues[1] * input_movevalues[1]);

	/* Charge start latches held move; wait for neutral, then a fresh press
	 * can dodge-cancel. */
	if (pl.m_julietMoveLatch) {
		if (horiz <= STILETTO_AIR_MOVE_INPUT_THRESH) {
			pl.m_julietMoveLatch = 0;
#ifdef SERVER
			Juliet_Dirty(pl);
#endif
		}
	} else if (horiz > STILETTO_AIR_MOVE_INPUT_THRESH
	    && pl.m_julietDashRecovery <= 0.0f) {
		makevectors(input_angles);
		fwd = v_forward;
		right = v_right;
		fwd[2] = 0.0f;
		right[2] = 0.0f;
		if (vlen(fwd) > 0.125f) {
			fwd = normalize(fwd);
		}
		if (vlen(right) > 0.125f) {
			right = normalize(right);
		}
		dodgeDir = (fwd * input_movevalues[0]) + (right * input_movevalues[1]);
		dodgeDir[2] = 0.0f;
		if (vlen(dodgeDir) >= 0.125f) {
			dodgeDir = normalize(dodgeDir);
			if (pl.flags & FL_ONGROUND) {
				/* Naked impulse + ice friction/drag below. DashAddVel would
				 * be bled off by Stiletto_ApplyMoveTuning and kill the slide. */
				pl.velocity += dodgeDir * JULIET_GROUND_DASH_SPEED;
				pl.velocity[2] = 0.0f;
			} else {
				pl.velocity += dodgeDir * STILETTO_AIR_DASH_SPEED;
			}
			Juliet_ChargeStore(pl);
			pl.m_julietDashRecovery = JULIET_DASH_RECOVERY;
			pl.friction = JULIET_DASH_FRICTION;
			input_movevalues[0] = 0;
			input_movevalues[1] = 0;
			return;
		}
	}

	input_movevalues[0] = 0;
	input_movevalues[1] = 0;
}
