/*
 * Stiletto combat-reaction layer (sits beside the movement kit in
 * stiletto_tuning.qc). Ports two prototype systems and Archstiletto's duel
 * exceptions:
 *
 *   - Health pacing (player_health.gd): a hit grants a short invulnerability
 *     window, and going long enough without taking damage heals to full.
 *   - Tool punish (punish_state_machine.gd): getting hit while airborne and
 *     mid air-dodge / air-stall / RMB movement tool (grapple, lunge, warpknife)
 *     kills horizontal control for the rest of the fall, then lands the hero
 *     in a stun + sluggish recovery. Grapple is dropped so the rope cannot
 *     yank out of the landing stun.
 *   - Archstiletto: a super-armor buffer absorbs the first chunk of damage
 *     before any punish applies; once spent, the punish PRESERVES trajectory
 *     (no velocity-zero / straight-down) but still locks control until landing.
 *
 * Constants live here (no decl tuning layer), matching stiletto_tuning.qc.
 *
 * State fields are declared in Player.h. The two punish fields
 * (m_stilettoPunishState / m_stilettoPunishTime) are networked so the shared
 * Physics_Run movement lock predicts identically on client and server. The
 * i-frame / regen / arch-buffer fields are server-authoritative (damage is
 * applied server-side).
 */

#define STILETTO_IFRAME_TIME		1.3f	/* post-hit invulnerability */
#define STILETTO_REGEN_DELAY		12.0f	/* out-of-combat heal-to-full delay */

#define STILETTO_PUNISH_STUN		1.0f	/* full movement lock on landing */
#define STILETTO_PUNISH_RECOVER		1.0f	/* accel ramp after the stun */
#define STILETTO_PUNISH_ACCEL_MIN	0.30f	/* control at the start of recovery */
#define STILETTO_TOOL_WINDOW		1.5f	/* grace after dodge/stall/grapple/lunge; stall itself is only 0.2s */

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
	if (pl.m_stilettoPunishTime <= 0.0f) {
		return (true);
	}

	return (pl.m_stilettoPunishTime > STILETTO_PUNISH_RECOVER);
}

/** Movement-input scale for the current punish phase: 0 while stunned, a
 * 0.30 -> 1.0 ramp through the recovery window, 1.0 when not punished. */
float
Stiletto_Combat_MoveScale(entity e)
{
	ncPlayer pl = (ncPlayer)e;
	float t;

	if (pl.m_stilettoPunishState == STILETTO_PUNISH_NONE) {
		return (1.0f);
	}

	/* airborne pending: locked */
	if (pl.m_stilettoPunishTime <= 0.0f) {
		return (0.0f);
	}

	if (pl.m_stilettoPunishTime > STILETTO_PUNISH_RECOVER) {
		return (0.0f);
	}

	t = 1.0f - (pl.m_stilettoPunishTime / STILETTO_PUNISH_RECOVER);
	return (STILETTO_PUNISH_ACCEL_MIN + (1.0f - STILETTO_PUNISH_ACCEL_MIN) * t);
}

/** Stamp the post-tool punish window. Air stall lasts 0.2s; a hit after it
 * still counts as mid-tool until this expires. */
void
Stiletto_Combat_MarkTool(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	if (!is.Player(pl)) {
		return;
	}

	pl.m_stilettoToolPunishUntil = time + STILETTO_TOOL_WINDOW;
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
	if (pl.m_stilettoPunishTime <= 0.0f && !(pl.flags & FL_ONGROUND)) {
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
		if (pl.m_stilettoPunishTime <= 0.0f) {
			/* pending -> begin the landing punish once we touch ground */
			if (pl.flags & FL_ONGROUND) {
				pl.m_stilettoPunishTime = STILETTO_PUNISH_STUN + STILETTO_PUNISH_RECOVER;
			}
		} else {
			pl.m_stilettoPunishTime = max(0.0f, pl.m_stilettoPunishTime - input_timelength);
			if (pl.m_stilettoPunishTime <= 0.0f) {
				pl.m_stilettoPunishState = STILETTO_PUNISH_NONE;
				pl.m_stilettoPunishTime = 0.0f;
			}
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
	/* Any HP hit drops the rope, even if punish did not start (grounded,
	 * early-out, Arch buffer). Holding RMB must not keep the latch. */
	Grapple_BreakFromHit(pl);
}

/** Decide whether a hit triggers a tool punish. Fires when the hero is
 * airborne mid air-dodge / air-stall, or using the RMB movement tool
 * (grapple / lunge / warpknife). Hooked heroes count even if they brush
 * the floor. Archstiletto first burns a super-armor buffer, then takes a
 * trajectory-preserving punish. */
void
Stiletto_Combat_OnDamaged(entity e, float dmg)
{
	ncPlayer pl = (ncPlayer)e;
	ncActor act;
	bool airborne;
	bool hooked;
	bool toolActive;

	if (!is.Player(pl)) {
		return;
	}

	act = (ncActor)pl;
	airborne = !(pl.flags & FL_ONGROUND)
	    || (pl.m_stilettoAirTime > 0.0f)
	    || (pl.velocity[2] < -40.0f);
	hooked = (pl.m_pmoveHookVelocity != g_vec_null)
	    || (act.m_hook != __NULL__);

	/* Live tool, or the post-tool grace (stall itself is only 0.2s). Spent
	 * dodge/stall charges still count for the rest of the jump. */
	toolActive = (pl.m_stilettoAirStallTime > 0.0f)
	    || (time < pl.m_stilettoToolPunishUntil)
	    || (pl.m_stilettoAirDodgeCharges < STILETTO_MAX_AIR_DODGES)
	    || (pl.m_stilettoAirStallCharges < STILETTO_MAX_AIR_STALLS)
	    || (pl.m_stilettoLungeFlight != 0)
	    || (pl.m_stilettoGrappleActionHeld != 0)
	    || (input_buttons & INPUT_HERO_TOOL)
	    || hooked
	    || pl.m_heroToolHeld;

	if (!toolActive) {
		return;
	}
	if (!airborne && !hooked) {
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
		pl.m_stilettoPunishTime = 0.0f;
	} else {
		pl.m_stilettoPunishState = STILETTO_PUNISH_STANDARD;
		pl.m_stilettoPunishTime = 0.0f;
		/* Full stop, then gravity. Keeping leftover Z looked like a
		 * downward shove and skipped the "redirect then fall" feel. */
		pl.velocity = g_vec_null;
		pl.RemoveFlags(FL_ONGROUND);
	}

	pl.SendFlags |= (PLAYER_VELOCITY | PLAYER_STILETTO | PLAYER_FLAGS);
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
	pl.m_stilettoPunishTime = 0.0f;
	pl.m_stilettoToolPunishUntil = 0.0f;
	Stiletto_Lunge_Clear(pl);

	/* Arch flag from the def, with a declclass fallback in case the spawn-key
	 * buffer isn't populated after a ChangeToClass hero swap. */
	pl.m_stilettoIsArch = (pl.GetSpawnFloat("stiletto_arch") > 0.0f
	    || pl.declclass == "hero_archstiletto") ? 1 : 0;
}
#endif
