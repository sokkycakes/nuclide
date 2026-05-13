/*
 * Stiletto prototype movement: wall contact/slide/jump, grapple tuning,
 * air dodge + air stall (KickbackModulev2: +attack2 -> INPUT_SECONDARY edge;
 * dodge if forward/side move wish magnitude exceeds threshold, else stall),
 * short parry window. Constants live here (no decl tuning layer).
 */

#define STILETTO_GRAPPLE_PULL			600.0f
#define STILETTO_GRAPPLE_CHARGE_MAX		3.0f
#define STILETTO_GRAPPLE_RECHARGE_TIME		4.0f
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
#define STILETTO_WALL_SLIDE_MAX_FALL		420.0f
#define STILETTO_WALL_CLING_MAX_FALL		140.0f

#define STILETTO_AIR_DASH_SPEED			440.0f
#define STILETTO_MAX_AIR_DODGES			1.0f
#define STILETTO_MAX_AIR_STALLS			1.0f
#define STILETTO_AIR_MOVE_INPUT_THRESH		8.0f

#define STILETTO_AIR_STALL_TIME			0.2f
#define STILETTO_AIR_STALL_GRAV_SCALE		0.22f

#define STILETTO_PARRY_TIME			0.28f

#define STILETTO_VFL_WALL			(1 << 17)
#define STILETTO_VFL_PARRY			(1 << 18)

void
Stiletto_ApplyMoveTuning(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	if (time < pl.m_stilettoAirStallEnd) {
		pl.gravity *= STILETTO_AIR_STALL_GRAV_SCALE;
	}

	if ((pl.m_nuclideFlags & STILETTO_VFL_WALL) && (input_buttons & INPUT_CROUCH)) {
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

	if (pl.m_stilettoGrappleCharges >= STILETTO_GRAPPLE_CHARGE_MAX) {
		pl.m_stilettoGrappleRechargeAccum = 0.0f;
		return;
	}

	pl.m_stilettoGrappleRechargeAccum += input_timelength;
	while (pl.m_stilettoGrappleRechargeAccum >= STILETTO_GRAPPLE_RECHARGE_TIME) {
		pl.m_stilettoGrappleRechargeAccum -= STILETTO_GRAPPLE_RECHARGE_TIME;
		if (pl.m_stilettoGrappleCharges < STILETTO_GRAPPLE_CHARGE_MAX) {
			pl.m_stilettoGrappleCharges += 1.0f;
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
	}
}

void
Stiletto_ParryWindow(entity e)
{
	ncPlayer pl = (ncPlayer)e;

	if (time >= pl.m_stilettoParryEnd) {
		pl.RemoveVFlags(STILETTO_VFL_PARRY);
	}

	if ((input_buttons & INPUT_RELOAD) && !(pl.m_stilettoPrevButtons & INPUT_RELOAD)) {
		pl.m_stilettoParryEnd = time + STILETTO_PARRY_TIME;
		pl.AddVFlags(STILETTO_VFL_PARRY);
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

	pl.RemoveVFlags(STILETTO_VFL_WALL);
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
	pl.AddVFlags(STILETTO_VFL_WALL);
}

void
Stiletto_PmGunjumpAir(entity e, int curButtons, vector moveWish)
{
	ncPlayer pl = (ncPlayer)e;
	float horiz;
	vector dodgeDir;
	vector fwd;
	vector right;

	if (pl.flags & FL_ONGROUND) {
		return;
	}

	if (pl.waterlevel != WATERLEVEL_OUTSIDE) {
		return;
	}

	if (!(curButtons & INPUT_SECONDARY)) {
		return;
	}

	if (pl.m_stilettoPrevButtons & INPUT_SECONDARY) {
		return;
	}

#ifdef SERVER
	if (((ncActor)pl).m_hook != __NULL__ || pl.m_pmoveHookVelocity != g_vec_null) {
#else
	if (pl.m_pmoveHookVelocity != g_vec_null) {
#endif
		return;
	}

	horiz = sqrt(moveWish[0] * moveWish[0] + moveWish[1] * moveWish[1]);

	if (horiz > STILETTO_AIR_MOVE_INPUT_THRESH) {
		if (pl.m_stilettoAirDodgeCharges < 1.0f) {
			return;
		}

		pl.m_stilettoAirDodgeCharges -= 1.0f;

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

		dodgeDir = normalize(dodgeDir);
		pl.velocity += dodgeDir * STILETTO_AIR_DASH_SPEED;
	} else {
		if (pl.m_stilettoAirStallCharges < 1.0f) {
			return;
		}

		pl.m_stilettoAirStallCharges -= 1.0f;
		pl.m_stilettoAirStallEnd = time + STILETTO_AIR_STALL_TIME;
	}
}

void
Stiletto_WallJump(entity e, int curButtons)
{
	ncPlayer pl = (ncPlayer)e;
	vector away;
	float along;

	if (!(pl.m_nuclideFlags & STILETTO_VFL_WALL)) {
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
	along = (pl.velocity[0] * away[0]) + (pl.velocity[1] * away[1]);
	if (along < 0.0f) {
		pl.velocity[0] -= away[0] * along;
		pl.velocity[1] -= away[1] * along;
	}

	pl.velocity += away * STILETTO_WALL_JUMP_HORIZ + [0, 0, STILETTO_WALL_JUMP_UP];
	pl.flags &= ~FL_ONGROUND;
	pl.m_stilettoWallJumpCooldown = STILETTO_WALL_JUMP_COOLDOWN;
	pl.RemoveVFlags(STILETTO_VFL_WALL);
	pl.m_stilettoWallNorm = g_vec_null;
}

void
Stiletto_WallSlidePostMove(entity e)
{
	ncPlayer pl = (ncPlayer)e;
	float cap;

	if (!(pl.m_nuclideFlags & STILETTO_VFL_WALL)) {
		return;
	}

	cap = STILETTO_WALL_SLIDE_MAX_FALL;
	if (input_buttons & INPUT_CROUCH) {
		cap = STILETTO_WALL_CLING_MAX_FALL;
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
