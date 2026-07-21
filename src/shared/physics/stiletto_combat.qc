/*
 * Stiletto combat-reaction layer (sits beside the movement kit in
 * stiletto_tuning.qc). Ports two prototype systems and Archstiletto's duel
 * exceptions:
 *
 *   - Health pacing (player_health.gd): a hit grants a short invulnerability
 *     window, and going long enough without taking damage heals to full.
 *   - Tool punish (punish_state_machine.gd): getting hit while airborne and
 *     mid air-dodge / air-stall / recent-kickback kills horizontal control for
 *     the rest of the fall, then lands the hero in a stun + sluggish recovery.
 *   - Archstiletto: a super-armor buffer absorbs the first chunk of damage
 *     before any punish applies; once spent, the punish PRESERVES trajectory
 *     (no velocity-zero / straight-down) but still locks control until landing.
 *
 * Constants live here (no decl tuning layer), matching stiletto_tuning.qc.
 *
 * State fields are declared in Player.h. The two punish fields
 * (m_stilettoPunishState / m_stilettoPunishEnd) are networked so the shared
 * Physics_Run movement lock predicts identically on client and server. The
 * i-frame / regen / arch-buffer fields are server-authoritative (damage is
 * applied server-side).
 */

#define STILETTO_IFRAME_TIME		1.3f	/* post-hit invulnerability */
#define STILETTO_REGEN_DELAY		12.0f	/* out-of-combat heal-to-full delay */

#define STILETTO_PUNISH_STUN		1.0f	/* full movement lock on landing */
#define STILETTO_PUNISH_RECOVER		1.0f	/* accel ramp after the stun */
#define STILETTO_PUNISH_ACCEL_MIN	0.30f	/* control at the start of recovery */
#define STILETTO_TOOL_WINDOW		0.35f	/* "tool active" grace after an air-dodge */

#define STILETTO_ARCH_SUPERARMOR	2.0f	/* HP absorbed before Arch is punishable */

#define STILETTO_PUNISH_NONE		0
#define STILETTO_PUNISH_STANDARD	1	/* zero horizontal velocity, then stun */
#define STILETTO_PUNISH_ARCH		2	/* keep trajectory, lock control until land */

/** True while the hero has no movement control: airborne-pending punish, or the
 * full-stun window after landing. Used to suppress air-dodge / wall-jump. */
bool
Stiletto_Combat_IsFullyStunned(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	if (pl.m_stilettoPunishState == STILETTO_PUNISH_NONE) {
		return (false);
	}

	/* not landed yet -> fully locked */
	if (pl.m_stilettoPunishEnd <= 0.0f) {
		return (true);
	}

	return (time < pl.m_stilettoPunishEnd - STILETTO_PUNISH_RECOVER);
}

/** Movement-input scale for the current punish phase: 0 while stunned, a
 * 0.30 -> 1.0 ramp through the recovery window, 1.0 when not punished. */
float
Stiletto_Combat_MoveScale(entity e)
{
	ncPlayer pl = (ncPlayer)e;
	float stunEnd;
	float t;

	if (pl.m_stilettoPunishState == STILETTO_PUNISH_NONE) {
		return (1.0f);
	}

	/* airborne pending: locked */
	if (pl.m_stilettoPunishEnd <= 0.0f) {
		return (0.0f);
	}

	stunEnd = pl.m_stilettoPunishEnd - STILETTO_PUNISH_RECOVER;

	if (time < stunEnd) {
		return (0.0f);
	}

	if (time >= pl.m_stilettoPunishEnd) {
		return (1.0f);
	}

	t = (time - stunEnd) / STILETTO_PUNISH_RECOVER;
	return (STILETTO_PUNISH_ACCEL_MIN + (1.0f - STILETTO_PUNISH_ACCEL_MIN) * t);
}

/** Per-frame, BEFORE physics integration. Kills horizontal velocity while a
 * standard punish is still airborne (Arch keeps its trajectory), and scales the
 * movement wish down for the stun/recovery. Shared so prediction matches. */
void
Stiletto_Combat_PreMove(entity e)
{
	ncPlayer pl = (ncPlayer)e;
	float scale;

	if (pl.m_stilettoPunishState == STILETTO_PUNISH_NONE) {
		return;
	}

	/* airborne, not yet landed */
	if (pl.m_stilettoPunishEnd <= 0.0f && !(pl.flags & FL_ONGROUND)) {
		if (pl.m_stilettoPunishState == STILETTO_PUNISH_STANDARD) {
			pl.velocity[0] = 0.0f;
			pl.velocity[1] = 0.0f;
		}
		/* Arch: preserve current trajectory (leave velocity untouched) */
	}

	scale = Stiletto_Combat_MoveScale(pl);
	input_movevalues[0] *= scale;
	input_movevalues[1] *= scale;
	input_movevalues[2] *= scale;
}

/** Per-frame, AFTER physics (ground state is current). Starts the ground punish
 * on landing, expires it, and runs server-authoritative out-of-combat regen. */
void
Stiletto_Combat_PostMove(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	if (pl.m_stilettoPunishState != STILETTO_PUNISH_NONE) {
		if (pl.m_stilettoPunishEnd <= 0.0f) {
			/* pending -> begin the landing punish once we touch ground */
			if (pl.flags & FL_ONGROUND) {
				pl.m_stilettoPunishEnd = time + STILETTO_PUNISH_STUN + STILETTO_PUNISH_RECOVER;
			}
		} else if (time >= pl.m_stilettoPunishEnd) {
			pl.m_stilettoPunishState = STILETTO_PUNISH_NONE;
			pl.m_stilettoPunishEnd = 0.0f;
		}
	}

#ifdef SERVER
	if (is.Alive(pl) && pl.GetHealth() > 0) {
		if (pl.m_stilettoLastDamageTime > 0.0f
		    && (time - pl.m_stilettoLastDamageTime) >= STILETTO_REGEN_DELAY
		    && pl.GetHealth() < pl.GetMaxHealth()) {
			pl.SetHealth(pl.GetMaxHealth());
			/* heal-to-full resets Archstiletto's super-armor buffer */
			pl.m_stilettoArchBuffer = 0.0f;
		}
	}
#endif
}

#ifdef SERVER
/** True if a fresh hit should be ignored because we're still inside the
 * post-hit invulnerability window. Lethal/forced damage (noGod) bypasses it. */
bool
Stiletto_Combat_DamageBlocked(entity e, ncDict damageDecl)
{
	ncPlayer pl = (ncPlayer)e;

	if (!is.Player(pl)) {
		return (false);
	}

	if (damageDecl.GetBool("noGod") == true) {
		return (false);
	}

	return (time < pl.m_stilettoInvulnEnd);
}

/** Stamp the invulnerability window + last-damage time on a registered hit. */
void
Stiletto_Combat_StampDamage(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	if (!is.Player(pl)) {
		return;
	}

	pl.m_stilettoLastDamageTime = time;
	pl.m_stilettoInvulnEnd = time + STILETTO_IFRAME_TIME;
}

/** Decide whether a hit triggers a tool punish. Only fires when the hero is
 * airborne AND mid air-dodge / air-stall / recent-kickback. Archstiletto first
 * burns a super-armor buffer, then takes a trajectory-preserving punish. */
void
Stiletto_Combat_OnDamaged(entity e, float dmg)
{
	ncPlayer pl = (ncPlayer)e;
	bool airborne;
	bool toolActive;

	if (!is.Player(pl)) {
		return;
	}

	airborne = !(pl.flags & FL_ONGROUND);

	/* "tool active" = mid air-stall, or an air-dodge/air-stall charge already
	 * spent this airtime (charges refill on the ground, so a spent charge means
	 * the hero used the tool during this jump). Kickback joins this list when it
	 * ships; the exact window is a flagged playtest item. */
	toolActive = (time < pl.m_stilettoAirStallEnd)
	    || (pl.m_stilettoAirDodgeCharges < STILETTO_MAX_AIR_DODGES)
	    || (pl.m_stilettoAirStallCharges < STILETTO_MAX_AIR_STALLS)
	    || (pl.m_stilettoLungeFlight != 0);

	/* only being hit mid-air-tool is punishable */
	if (!airborne || !toolActive) {
		return;
	}

	/* don't restack a punish that's already running */
	if (pl.m_stilettoPunishState != STILETTO_PUNISH_NONE) {
		return;
	}

	if (pl.m_stilettoIsArch) {
		pl.m_stilettoArchBuffer += dmg;

		/* super armor: absorb until MORE than the buffer has accumulated */
		if (pl.m_stilettoArchBuffer <= STILETTO_ARCH_SUPERARMOR) {
			return;
		}

		pl.m_stilettoPunishState = STILETTO_PUNISH_ARCH;
		pl.m_stilettoPunishEnd = 0.0f;
	} else {
		pl.m_stilettoPunishState = STILETTO_PUNISH_STANDARD;
		pl.m_stilettoPunishEnd = 0.0f;
	}
}

/** Reset all combat-reaction state on (re)spawn and read the Arch flag from the
 * active hero def. Called from MakePlayer (server). */
void
Stiletto_Combat_Respawn(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	pl.m_stilettoInvulnEnd = 0.0f;
	pl.m_stilettoLastDamageTime = 0.0f;
	pl.m_stilettoArchBuffer = 0.0f;
	pl.m_stilettoPunishState = STILETTO_PUNISH_NONE;
	pl.m_stilettoPunishEnd = 0.0f;
	Stiletto_Lunge_Clear(pl);

	/* Arch flag from the def, with a declclass fallback in case the spawn-key
	 * buffer isn't populated after a ChangeToClass hero swap. */
	pl.m_stilettoIsArch = (pl.GetSpawnFloat("stiletto_arch") > 0.0f
	    || pl.declclass == "hero_archstiletto") ? 1 : 0;
}
#endif
