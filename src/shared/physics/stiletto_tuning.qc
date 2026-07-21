/*
 * Stiletto prototype movement: wall contact/slide/jump, grapple tuning,
 * air dodge + air stall, short parry window. Constants live here (no decl
 * tuning layer).
 *
 * Input model:
 *   INPUT_JUMP (jump) is the context-sensitive air button. While airborne and
 *   off a wall, a fresh jump press performs an air dash (if there is movement
 *   wish) or an air stall (if not). On a wall, the jump press is consumed by
 *   the wall jump instead, so dash/stall do not fire.
 *
 *   INPUT_STILETTO_DASH (MOUSE4) is now a held "acro" modifier (shift-style),
 *   not a standalone action. While it is held:
 *     - wall jump launches at a fixed steep upward angle;
 *     - air dash (with movement wish) angles diagonally downward;
 *     - jump with no movement wish becomes a drop dash (straight down).
 */

#define STILETTO_GRAPPLE_PULL			600.0f
#define STILETTO_GRAPPLE_CHARGE_MAX		3
#define STILETTO_GRAPPLE_RECHARGE_GROUNDED	0.6f
#define STILETTO_GRAPPLE_RECHARGE_AIRBORNE	1.2f
#define STILETTO_GRAPPLE_RECHARGE_WALL		1.75f
#define STILETTO_GRAPPLE_HOP_FORWARD		480.0f
#define STILETTO_GRAPPLE_HOP_UP			315.0f

// Godot snaps when we get within ~0.5m of the anchor point.
#define STILETTO_GRAPPLE_SNAP_DIST_QUAKE	20.0f

#define STILETTO_GRAPPLE_METERS_TO_QUAKE	39.37008f
#define STILETTO_GRAPPLE_MAX_DIST_METERS	30.0f
#define STILETTO_GRAPPLE_HOOK_SPEED_MS		40.0f
#define STILETTO_GRAPPLE_SPEED_LO_MS		5.0f
#define STILETTO_GRAPPLE_SPEED_HI_MS		20.0f
#define STILETTO_GRAPPLE_DIST_MULT_MAX		2.0f

#define STILETTO_WALL_PROBE			40.0f
#define STILETTO_WALL_CONTACT_DIST		14.0f
#define STILETTO_WALL_FAN_DIRS			12
#define STILETTO_WALL_MAX_Z_NORMAL		0.35f
#define STILETTO_WALL_ORIGIN_VEL_SCALE		0.018f
#define STILETTO_WALL_ORIGIN_VEL_CAP		10.0f
#define STILETTO_WALL_VEL_BLEND_MIN		64.0f
#define STILETTO_WALL_CLING_GRAV_SCALE		0.5f
#define STILETTO_WALL_JUMP_HORIZ		260.0f
#define STILETTO_WALL_JUMP_UP			240.0f
#define STILETTO_WALL_JUMP_COOLDOWN		0.22f

/* acro modifier (MOUSE4 held): fixed steep launch off the wall, applied as an
 * override so the takeoff angle is consistent regardless of incoming speed. */
#define STILETTO_WALL_JUMP_ACRO_HORIZ		140.0f
#define STILETTO_WALL_JUMP_ACRO_UP		360.0f
#define STILETTO_WALL_SLIDE_MAX_FALL		420.0f
#define STILETTO_WALL_CLING_MAX_FALL		140.0f

#define STILETTO_AIR_DASH_SPEED			440.0f
#define STILETTO_MAX_AIR_DODGES			1.0f
#define STILETTO_MAX_AIR_STALLS			1.0f
#define STILETTO_AIR_MOVE_INPUT_THRESH		8.0f

/* acro modifier (MOUSE4 held): air dash angles downward (vertical velocity is
 * overridden so the dive angle is consistent), and a no-movement jump becomes a
 * drop dash straight down. */
#define STILETTO_AIR_DASH_DOWN_SPEED		300.0f
#define STILETTO_DROP_DASH_SPEED		600.0f

/* Air dash is a purely additive impulse that exists for only an extremely short
 * time. The dash velocity (dodgeDir * STILETTO_AIR_DASH_SPEED) is added to the
 * current velocity, then that same contribution is bled back out linearly over
 * STILETTO_AIR_DASH_ADD_TIME. This is independent of ground/run speed caps: it
 * just shifts your position and ekes a little distance, then leaves your
 * underlying velocity (and air control) untouched, so it can't stack speed. */
#define STILETTO_AIR_DASH_ADD_TIME		0.5f

#define STILETTO_AIR_STALL_TIME			0.2f
#define STILETTO_AIR_STALL_GRAV_SCALE		0.0f

#define STILETTO_PARRY_TIME			0.28f

void
Stiletto_ApplyMoveTuning(entity e)
{
	ncPlayer pl = (ncPlayer)e;
	float addMag;
	float step;
	vector addDelta;

	if (time < pl.m_stilettoAirStallEnd) {
		pl.gravity *= STILETTO_AIR_STALL_GRAV_SCALE;
		
		/* Godot-style: completely nullify downward velocity during stall */
		if (pl.velocity[2] < 0.0f) {
			pl.velocity[2] = 0.0f;
		}
	}

	/* air dash bleed: remove the additive dash contribution over a very short
	 * window, so the dash is a brief positional shift rather than a permanent
	 * speed add. This subtracts only the dash's own impulse and never references
	 * run-speed caps, leaving the player's underlying velocity / air control
	 * intact. (Air dash is single-charge per airtime, so the stored contribution
	 * is never clobbered mid-bleed.) */
	if (pl.m_stilettoDashAddVel != g_vec_null) {
		/* Collision response (PMoveCustom_Rebound) may have already removed
		 * components of the dash impulse from velocity (e.g. when dashing into
		 * a wall). Clip the stored additive velocity per axis so the bleed does
		 * not subtract components that are no longer present — which would
		 * reverse the player away from the wall for the entire bleed window. */
		if (pl.m_stilettoDashAddVel[0] > 0.0f && pl.velocity[0] <= 0.0f) {
			pl.m_stilettoDashAddVel[0] = 0.0f;
		} else if (pl.m_stilettoDashAddVel[0] < 0.0f && pl.velocity[0] >= 0.0f) {
			pl.m_stilettoDashAddVel[0] = 0.0f;
		}
		if (pl.m_stilettoDashAddVel[1] > 0.0f && pl.velocity[1] <= 0.0f) {
			pl.m_stilettoDashAddVel[1] = 0.0f;
		} else if (pl.m_stilettoDashAddVel[1] < 0.0f && pl.velocity[1] >= 0.0f) {
			pl.m_stilettoDashAddVel[1] = 0.0f;
		}

		addMag = vlen(pl.m_stilettoDashAddVel);

		/* reduced gravity that decays back to normal alongside the dash bleed.
		 * remaining frac drives a lerp from 0.3→1.0 over the dash window. */
		pl.gravity *= 0.3f + (0.7f * (1.0f - addMag / STILETTO_AIR_DASH_SPEED));

		step = (STILETTO_AIR_DASH_SPEED / STILETTO_AIR_DASH_ADD_TIME) * input_timelength;

		if (addMag <= 0.0f || step >= addMag) {
			/* final frame: subtract whatever remains */
			pl.velocity -= pl.m_stilettoDashAddVel;
			pl.m_stilettoDashAddVel = g_vec_null;
		} else {
			addDelta = pl.m_stilettoDashAddVel * (step / addMag);
			pl.velocity -= addDelta;
			pl.m_stilettoDashAddVel -= addDelta;
		}
	}

	if ((pl.m_nuclideFlags & VFL_STILETTO_WALL) && (input_buttons & INPUT_CROUCH)) {
		pl.gravity *= STILETTO_WALL_CLING_GRAV_SCALE;
	}
}

float
Stiletto_GrapplePullSpeed(void)
{
	return (STILETTO_GRAPPLE_PULL);
}

float
Stiletto_GrappleMaxRange(entity e)
{
	ncPlayer pl = (ncPlayer)e;
	float horiz;
	float t;
	float mult;
	float base;

	base = STILETTO_GRAPPLE_MAX_DIST_METERS * STILETTO_GRAPPLE_METERS_TO_QUAKE;

	if (pl.flags & FL_ONGROUND) {
		return (base);
	}

	horiz = sqrt(pl.velocity[0] * pl.velocity[0] + pl.velocity[1] * pl.velocity[1]);
	if (horiz <= STILETTO_GRAPPLE_SPEED_LO_MS * STILETTO_GRAPPLE_METERS_TO_QUAKE) {
		return (base);
	}

	if (horiz >= STILETTO_GRAPPLE_SPEED_HI_MS * STILETTO_GRAPPLE_METERS_TO_QUAKE) {
		return (base * STILETTO_GRAPPLE_DIST_MULT_MAX);
	}

	t = (horiz - STILETTO_GRAPPLE_SPEED_LO_MS * STILETTO_GRAPPLE_METERS_TO_QUAKE) /
	    (STILETTO_GRAPPLE_SPEED_HI_MS * STILETTO_GRAPPLE_METERS_TO_QUAKE -
	     STILETTO_GRAPPLE_SPEED_LO_MS * STILETTO_GRAPPLE_METERS_TO_QUAKE);
	mult = 1.0f + (STILETTO_GRAPPLE_DIST_MULT_MAX - 1.0f) * t;
	return (base * mult);
}

void
Stiletto_Grapple_CheckFlyingMiss(entity e)
{
#ifdef SERVER
	ncPlayer pl = (ncPlayer)e;
	ncActor act = (ncActor)pl;
	entity hk;
	float maxR;
	float rope;

	if (pl.m_pmoveHookVelocity != g_vec_null) {
		return;
	}

	hk = act.m_hook;
	if (hk == __NULL__) {
		return;
	}

	maxR = Stiletto_GrappleMaxRange(pl);
	rope = vlen(hk.origin - pl.GetEyePos());
	if (rope > maxR * 1.05f) {
		Grapple_Clear(pl);
	}
#endif
}

void
Stiletto_GrappleHop(entity e)
{
	ncPlayer pl = (ncPlayer)e;
	vector anchor;
	vector rope;
	vector fwd;
	vector dir;
	float dist;

	if (pl.m_stilettoGrappleHeld) {
		return;
	}

#ifdef SERVER
	ncActor act = (ncActor)pl;

	if (act.m_hook == __NULL__ && pl.m_pmoveHookVelocity == g_vec_null) {
		return;
	}

	anchor = pl.m_pmoveHookVelocity;
	if (act.m_hook != __NULL__) {
		anchor = act.m_hook.origin;
	}
#else
	if (pl.m_pmoveHookVelocity == g_vec_null) {
		return;
	}

	anchor = pl.m_pmoveHookVelocity;
#endif

	rope = anchor - pl.origin;
	dist = vlen(rope);
	if (dist < 1.0f) {
		rope = anglesToForward(pl.v_angle);
	} else {
		rope = rope * (1.0f / dist);
	}

	fwd = anglesToForward(pl.v_angle);
	dir = normalize(fwd * 0.55f + rope * 0.45f);
	pl.velocity += dir * STILETTO_GRAPPLE_HOP_FORWARD + [0, 0, STILETTO_GRAPPLE_HOP_UP];
	pl.m_stilettoGrappleHeld = 0;
}

void
Stiletto_Server_GrappleRecharge(entity e)
{
#ifdef SERVER
	ncPlayer pl = (ncPlayer)e;
	float rechargeTime;
	int i;
	bool isGrounded;
	bool isOnWall;

	/* Check if all charges are full */
	if (pl.m_stilettoGrappleCharges >= STILETTO_GRAPPLE_CHARGE_MAX) {
		/* Reset all timers when full */
		for (i = 0; i < STILETTO_GRAPPLE_CHARGE_MAX; i++) {
			pl.m_stilettoGrappleChargeTimers[i] = 0.0f;
		}
		return;
	}

	/* Determine player state */
	isGrounded = (pl.flags & FL_ONGROUND) ? true : false;
	isOnWall = (pl.m_nuclideFlags & VFL_STILETTO_WALL) ? true : false;

	/* Wall recharge: only recharge up to 1 charge, takes 1.75 seconds */
	if (isOnWall) {
		/* Reset midair flag when touching wall */
		pl.m_stilettoGrappleUsedInMidair = false;

		/* Only recharge the first charge slot if we have less than 1 charge */
		if (pl.m_stilettoGrappleCharges < 1) {
			if (pl.m_stilettoGrappleChargeTimers[0] > 0.0f) {
				/* Progress existing timer */
				pl.m_stilettoGrappleChargeTimers[0] -= input_timelength;
				if (pl.m_stilettoGrappleChargeTimers[0] <= 0.0f) {
					pl.m_stilettoGrappleChargeTimers[0] = 0.0f;
					if (pl.m_stilettoGrappleCharges < 1) {
						pl.m_stilettoGrappleCharges = 1;
					}
				}
			} else if (!pl.m_stilettoGrappleUsedInMidair) {
				/* Start recharging the first charge */
				pl.m_stilettoGrappleChargeTimers[0] = STILETTO_GRAPPLE_RECHARGE_WALL;
			}
		}
		/* Don't recharge other charges while on wall */
		for (i = 1; i < STILETTO_GRAPPLE_CHARGE_MAX; i++) {
			pl.m_stilettoGrappleChargeTimers[i] = 0.0f;
		}
	}
	/* Ground recharge: recharge each charge one by one */
	else if (isGrounded) {
		/* Reset midair flag when touching ground */
		pl.m_stilettoGrappleUsedInMidair = false;

		rechargeTime = STILETTO_GRAPPLE_RECHARGE_GROUNDED;
		for (i = 0; i < STILETTO_GRAPPLE_CHARGE_MAX; i++) {
			if (pl.m_stilettoGrappleChargeTimers[i] > 0.0f) {
				/* Progress existing timer */
				pl.m_stilettoGrappleChargeTimers[i] -= input_timelength;
				if (pl.m_stilettoGrappleChargeTimers[i] <= 0.0f) {
					pl.m_stilettoGrappleChargeTimers[i] = 0.0f;
					if (pl.m_stilettoGrappleCharges < STILETTO_GRAPPLE_CHARGE_MAX) {
						pl.m_stilettoGrappleCharges += 1;
					}
				}
			} else if (pl.m_stilettoGrappleCharges <= i && !pl.m_stilettoGrappleUsedInMidair) {
				/* Start recharging this charge slot if we need it */
				bool canStart = false;
				if (i == 0) {
					canStart = true;
				} else if (i > 0) {
					/* Previous charge must be done and we must have at least i charges */
					canStart = (pl.m_stilettoGrappleChargeTimers[i - 1] <= 0.0f) && (pl.m_stilettoGrappleCharges >= i);
				}

				if (canStart) {
					pl.m_stilettoGrappleChargeTimers[i] = rechargeTime;
				}
			}
		}
	}
	/* In midair: progress existing timers but don't start new ones if grapple was used in midair */
	else {
		rechargeTime = STILETTO_GRAPPLE_RECHARGE_AIRBORNE;
		for (i = 0; i < STILETTO_GRAPPLE_CHARGE_MAX; i++) {
			if (pl.m_stilettoGrappleChargeTimers[i] > 0.0f) {
				/* Progress existing timer even in midair */
				pl.m_stilettoGrappleChargeTimers[i] -= input_timelength;
				if (pl.m_stilettoGrappleChargeTimers[i] <= 0.0f) {
					pl.m_stilettoGrappleChargeTimers[i] = 0.0f;
					if (pl.m_stilettoGrappleCharges < STILETTO_GRAPPLE_CHARGE_MAX) {
						pl.m_stilettoGrappleCharges += 1;
					}
				}
			}
		}
	}
#endif
}

void
Stiletto_OnPhysicsStart(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	if (pl.flags & FL_ONGROUND) {
		pl.m_stilettoAirDodgeCharges = STILETTO_MAX_AIR_DODGES;
		pl.m_stilettoAirStallCharges = STILETTO_MAX_AIR_STALLS;
		pl.m_stilettoAirTime = time;  // Stamp ref time (time - m_stilettoAirTime ≈ 0 while grounded)
	} else if (pl.m_stilettoAirTime == 0.0f) {
		pl.m_stilettoAirTime = time;  // Init for fresh spawns already airborne
	}
}

/* Called after the physics step when the player first leaves the ground (jump / fall).
 * Stamps current time so Physics_Fall can measure airborne duration. */
void
Stiletto_LeaveGround(entity e)
{
	ncPlayer pl = (ncPlayer)e;
	pl.m_stilettoAirTime = time;
}

void
Stiletto_ParryWindow(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	if (time >= pl.m_stilettoParryEnd) {
		pl.RemoveVFlags(VFL_STILETTO_PARRY);
	}

	if ((input_buttons & INPUT_RELOAD) && !(pl.m_stilettoPrevButtons & INPUT_RELOAD)) {
		pl.m_stilettoParryEnd = time + STILETTO_PARRY_TIME;
		pl.AddVFlags(VFL_STILETTO_PARRY);
	}
}

void
Stiletto_UpdateWallState(entity e, vector moveWish)
{
	ncPlayer pl = (ncPlayer)e;
	vector wish;
	vector velFlat;
	vector start;
	vector end;
	vector dir;
	vector bestNorm;
	float baseYaw;
	float bestFrac;
	float y;
	float nz;
	float vb;
	float hitDist;
	int i;

	pl.RemoveVFlags(VFL_STILETTO_WALL);
	pl.m_stilettoWallNorm = g_vec_null;

	if (pl.GetMovetype() != MOVETYPE_WALK) {
		return;
	}

	if (pl.waterlevel != WATERLEVEL_OUTSIDE) {
		return;
	}

#ifdef SERVER
	if (((ncActor)pl).m_hook != __NULL__ || pl.m_pmoveHookVelocity != g_vec_null) {
#else
	if (pl.m_pmoveHookVelocity != g_vec_null) {
#endif
		return;
	}

	makevectors(input_angles);
	wish = (v_forward * moveWish[0]) + (v_right * moveWish[1]);
	wish[2] = 0.0f;

	if (vlen(wish) < 8.0f) {
		wish = v_forward;
		wish[2] = 0.0f;
		if (vlen(wish) > 0.125f) {
			wish = normalize(wish);
		} else {
			wish = [1, 0, 0];
		}
	} else {
		wish = normalize(wish);
	}

	velFlat = pl.velocity;
	velFlat[2] = 0.0f;

	if (vlen(velFlat) >= STILETTO_WALL_VEL_BLEND_MIN) {
		wish = normalize(wish * 0.55f + normalize(velFlat) * 0.45f);
	}

	baseYaw = vectoyaw(wish);

	start = pl.origin + [0, 0, 8];
	if (vlen(velFlat) > 4.0f) {
		dir = normalize(velFlat);
		vb = vlen(velFlat) * STILETTO_WALL_ORIGIN_VEL_SCALE;
		if (vb > STILETTO_WALL_ORIGIN_VEL_CAP) {
			vb = STILETTO_WALL_ORIGIN_VEL_CAP;
		}
		start += dir * vb;
	}

	bestFrac = 2.0f;
	bestNorm = g_vec_null;

	for (i = 0; i < STILETTO_WALL_FAN_DIRS; i++) {
		y = baseYaw + ((float)i * (360.0f / (float)STILETTO_WALL_FAN_DIRS));
		makevectors([0, y, 0]);
		dir = v_forward;
		dir[2] = 0.0f;
		if (vlen(dir) < 0.0625f) {
			continue;
		}
		dir = normalize(dir);
		end = start + dir * STILETTO_WALL_PROBE;
		tracebox(start, pl.mins, pl.maxs, end, MOVE_NORMAL, pl);
		if (trace_fraction >= 1.0f) {
			continue;
		}
		nz = fabs(trace_plane_normal[2]);
		if (nz >= STILETTO_WALL_MAX_Z_NORMAL) {
			continue;
		}
		if (trace_fraction < bestFrac) {
			bestFrac = trace_fraction;
			bestNorm = trace_plane_normal;
		}
	}

	if (bestFrac >= 1.0f || vlen(bestNorm) < 0.0625f) {
		return;
	}

	hitDist = bestFrac * STILETTO_WALL_PROBE;
	if (hitDist > STILETTO_WALL_CONTACT_DIST) {
		return;
	}

	pl.m_stilettoWallNorm = bestNorm;
	pl.AddVFlags(VFL_STILETTO_WALL);
}

void
Stiletto_PmGunjumpAir(entity e, int curButtons, vector moveWish)
{
	ncPlayer pl = (ncPlayer)e;
	float horiz;
	float acro;
	vector dodgeDir;
	vector fwd;
	vector right;

	if (pl.flags & FL_ONGROUND) {
		return;
	}

	if (pl.waterlevel != WATERLEVEL_OUTSIDE) {
		return;
	}

	/* on a wall the jump press belongs to the wall jump; no dash/stall here */
	if (pl.m_nuclideFlags & VFL_STILETTO_WALL) {
		return;
	}

	/* jump is now the context-sensitive air button (fresh press only) */
	if (!(curButtons & INPUT_JUMP)) {
		return;
	}

	if (pl.m_stilettoPrevButtons & INPUT_JUMP) {
		return;
	}

#ifdef SERVER
	if (((ncActor)pl).m_hook != __NULL__ || pl.m_pmoveHookVelocity != g_vec_null) {
#else
	if (pl.m_pmoveHookVelocity != g_vec_null) {
#endif
		return;
	}

	/* MOUSE4 held = acro modifier (no edge requirement, it is a held shift) */
	acro = (curButtons & INPUT_STILETTO_DASH) ? 1.0f : 0.0f;

	horiz = sqrt(moveWish[0] * moveWish[0] + moveWish[1] * moveWish[1]);

	if (horiz > STILETTO_AIR_MOVE_INPUT_THRESH) {
		if (pl.m_stilettoAirDodgeCharges < 1.0f) {
			return;
		}

		makevectors(input_angles);
		fwd = v_forward;
		right = v_right;
		fwd[2] = 0.0f;
		right[2] = 0.0f;

		if (vlen(fwd) > 0.125f) {
			fwd = normalize(fwd);
		} else {
			fwd = g_vec_null;
		}

		if (vlen(right) > 0.125f) {
			right = normalize(right);
		} else {
			right = g_vec_null;
		}

		dodgeDir = (fwd * moveWish[0]) + (right * moveWish[1]);
		dodgeDir[2] = 0.0f;

		if (vlen(dodgeDir) < 0.125f) {
			return;
		}

		/* validate direction before spending the charge */
		pl.m_stilettoAirDodgeCharges -= 1.0f;

#ifdef SERVER
		pl.StartSoundDef("Player.AirDash", CHAN_AUTO, true);
#endif

		dodgeDir = normalize(dodgeDir);

		/* purely additive horizontal impulse; remember the contribution so it
		 * can be bled back out over a very short window (see ApplyMoveTuning) */
		pl.m_stilettoDashAddVel = dodgeDir * STILETTO_AIR_DASH_SPEED;
		pl.m_stilettoDashAddVel[2] = 0.0f;
		pl.velocity += pl.m_stilettoDashAddVel;

		/* acro: dive the dash diagonally downward at a consistent angle */
		if (acro) {
			pl.velocity[2] = -STILETTO_AIR_DASH_DOWN_SPEED;
		}
	} else {
		if (pl.m_stilettoAirStallCharges < 1.0f) {
			return;
		}

		pl.m_stilettoAirStallCharges -= 1.0f;

		if (acro) {
			/* drop dash: cancel horizontal momentum and slam straight down */
#ifdef SERVER
			pl.StartSoundDef("Player.AirDash", CHAN_AUTO, true);
#endif
			pl.velocity[0] = 0.0f;
			pl.velocity[1] = 0.0f;
			pl.velocity[2] = -STILETTO_DROP_DASH_SPEED;
		} else {
#ifdef SERVER
			pl.StartSoundDef("Player.AirStall", CHAN_AUTO, true);
#endif
			pl.m_stilettoAirStallEnd = time + STILETTO_AIR_STALL_TIME;
		}
	}
}

void
Stiletto_WallJump(entity e, int curButtons)
{
	ncPlayer pl = (ncPlayer)e;
	vector away;
	float along;

	if (!(pl.m_nuclideFlags & VFL_STILETTO_WALL)) {
		return;
	}

	if (pl.flags & FL_ONGROUND) {
		return;
	}

	if (pl.m_stilettoWallJumpCooldown > 0.0f) {
		return;
	}

	if (!(curButtons & INPUT_JUMP)) {
		return;
	}

	if (pl.m_stilettoPrevButtons & INPUT_JUMP) {
		return;
	}

	away = pl.m_stilettoWallNorm;
	away[2] = 0.0f;
	if (vlen(away) < 0.125f) {
		return;
	}
	away = normalize(away);

	if (curButtons & INPUT_STILETTO_DASH) {
		/* acro modifier: fixed steep upward launch, applied as an override so
		 * the takeoff angle is consistent regardless of incoming velocity */
		pl.velocity[0] = away[0] * STILETTO_WALL_JUMP_ACRO_HORIZ;
		pl.velocity[1] = away[1] * STILETTO_WALL_JUMP_ACRO_HORIZ;
		pl.velocity[2] = STILETTO_WALL_JUMP_ACRO_UP;
	} else {
		along = (pl.velocity[0] * away[0]) + (pl.velocity[1] * away[1]);
		if (along < 0.0f) {
			pl.velocity[0] -= away[0] * along;
			pl.velocity[1] -= away[1] * along;
		}

		pl.velocity += away * STILETTO_WALL_JUMP_HORIZ + [0, 0, STILETTO_WALL_JUMP_UP];
	}

	pl.flags &= ~FL_ONGROUND;
	pl.m_stilettoWallJumpCooldown = STILETTO_WALL_JUMP_COOLDOWN;
	pl.RemoveVFlags(VFL_STILETTO_WALL);
	pl.m_stilettoWallNorm = g_vec_null;
}

void
Stiletto_WallSlidePostMove(entity e)
{
	ncPlayer pl = (ncPlayer)e;
	float cap;
	vector wallNorm;
	vector velFlat;
	float awayDot;

	if (!(pl.m_nuclideFlags & VFL_STILETTO_WALL)) {
		return;
	}

	cap = STILETTO_WALL_SLIDE_MAX_FALL;
	if (input_buttons & INPUT_CROUCH) {
		cap = STILETTO_WALL_CLING_MAX_FALL;
		
		/* Make player "sticky" to wall when crouching */
		wallNorm = pl.m_stilettoWallNorm;
		wallNorm[2] = 0.0f;
		
		if (vlen(wallNorm) > 0.125f) {
			wallNorm = normalize(wallNorm);
			
			/* Get horizontal velocity */
			velFlat = pl.velocity;
			velFlat[2] = 0.0f;
			
			/* Check if moving away from wall */
			awayDot = (velFlat[0] * wallNorm[0]) + (velFlat[1] * wallNorm[1]);
			
			/* If moving away from wall, cancel that component */
			if (awayDot > 0.0f) {
				pl.velocity[0] -= wallNorm[0] * awayDot;
				pl.velocity[1] -= wallNorm[1] * awayDot;
			}
		}
	}

	if (pl.velocity[2] < -cap) {
		pl.velocity[2] = -cap;
	}
}

void
Stiletto_EndPhysicsFrame(entity e, int curButtons)
{
	ncPlayer pl = (ncPlayer)e;

	pl.m_stilettoWallJumpCooldown = max(0.0f, pl.m_stilettoWallJumpCooldown - input_timelength);

	pl.m_stilettoPrevButtons = curButtons;
}

void
Stiletto_Lunge_Clear(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	pl.m_stilettoLungeCharging = 0;
	pl.m_stilettoLungeChargeStart = 0.0f;
	pl.m_stilettoLungeSeqStrength = 0.0f;
	pl.m_stilettoLungeFlight = 0;
	pl.m_stilettoLungeLaunch = 0;
}

void
Stiletto_Lunge_RequestLaunch(entity e, float strength)
{
	ncPlayer pl = (ncPlayer)e;

	if (strength < STILETTO_LUNGE_MIN_STRENGTH) {
		strength = STILETTO_LUNGE_MIN_STRENGTH;
	}
	if (strength > 1.0f) {
		strength = 1.0f;
	}

	pl.m_stilettoLungeSeqStrength = strength;
	pl.m_stilettoLungeLaunch = 1;
}

void
Stiletto_Lunge_PreMove(entity e)
{
	ncPlayer pl = (ncPlayer)e;
	float speed;
	vector dir;

	if (pl.m_stilettoLungeCharging) {
		input_movevalues[0] *= STILETTO_LUNGE_MOVE_SCALE;
		input_movevalues[1] *= STILETTO_LUNGE_MOVE_SCALE;
	}

	if (!pl.m_stilettoLungeLaunch) {
		return;
	}

	pl.m_stilettoLungeLaunch = 0;

	makevectors(pl.v_angle);
	dir = v_forward;
	speed = STILETTO_LUNGE_IMPULSE_MIN
	    + (STILETTO_LUNGE_IMPULSE_MAX - STILETTO_LUNGE_IMPULSE_MIN)
	    * pl.m_stilettoLungeSeqStrength;

	pl.velocity = dir * speed;
	pl.m_stilettoLungeFlight = 1;
	pl.RemoveFlags(FL_ONGROUND);
}

void
Stiletto_Lunge_PostMove(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	/* Mid-charge left the ground — cancel charge, no launch. */
	if (pl.m_stilettoLungeCharging && !(pl.flags & FL_ONGROUND)) {
		pl.m_stilettoLungeCharging = 0;
		pl.m_stilettoLungeChargeStart = 0.0f;
	}

	if (!pl.m_stilettoLungeFlight && pl.m_stilettoLungeSeqStrength <= 0.0f) {
		return;
	}

	/* Grounded: leave flight (no longer tool-punishable). Keep sequence
	 * strength only while wall-touching so wall re-lunge still works. */
	if (pl.flags & FL_ONGROUND) {
		pl.m_stilettoLungeFlight = 0;
		if (!(pl.m_nuclideFlags & VFL_STILETTO_WALL)) {
			pl.m_stilettoLungeSeqStrength = 0.0f;
		}
	}
}

#ifdef SERVER
void
Stiletto_FireGrapple(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	if (!is.Player(pl)) {
		return;
	}

	ncAttack_SpawnDef("attack_stiletto_grapple_hook", (ncActor)pl);
}

void
Stiletto_ReleaseGrapple(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	if (!is.Player(pl)) {
		return;
	}

	if (pl.m_pmoveHookVelocity != g_vec_null) {
		Stiletto_GrappleHop(pl);
		Grapple_Clear(pl);
	}
}
#endif
