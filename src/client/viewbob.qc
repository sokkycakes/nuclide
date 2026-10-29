/*
 * Copyright (c) 2026 Vera Visions LLC.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF MIND, USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/* Quake II / Quake III style view and viewmodel motion, shared by every game.
 *
 * Style 2 matches the numbers of Quake II's server-side view code
 * (SV_CalcViewOffset, SV_CalcGunOffset, P_FallingDamage in p_view.c) with
 * the Action Quake 2 TNG fixes: the step cycle stops in the air, and
 * crouching speeds up the step rather than the whole accumulated time.
 * Quake II ran those at 10 Hz and the client interpolated, so the per-tick
 * values here are scaled by frametime and the turn lag is smoothed.
 *
 * In Quake II most of the motion comes from the camera: the gun is drawn at
 * the view origin with the view angles, so it inherits the camera bob, run
 * tilt and fall kick, and adds its own swing and turn lag on top. That is
 * why cg_viewBobCamera is on by default; without it only the gun moves.
 *
 * cg_viewBobStyle picks the motion: 0 keeps the game's own bob,
 * 2 is Quake II / AQ2, 3 is Quake III. */

var float autocvar_cg_viewBobStyle = 2;
var float autocvar_cg_viewBobScale = 1.0f;
var bool autocvar_cg_viewBobLand = true;
var bool autocvar_cg_viewBobCamera = true;

/* camera bob, same defaults as Quake II's bob_up/bob_pitch/bob_roll and
 * run_pitch/run_roll */
var float autocvar_cg_bobUp = 0.005f;
var float autocvar_cg_bobPitch = 0.002f;
var float autocvar_cg_bobRoll = 0.002f;
var float autocvar_cg_runPitch = 0.002f;
var float autocvar_cg_runRoll = 0.005f;

/* Quake II: bob cycle added per 10 Hz tick at run/walk/creep speeds */
#define VIEWBOB_Q2_TICK 0.1f
#define VIEWBOB_Q2_RUN 0.25f
#define VIEWBOB_Q2_WALK 0.125f
#define VIEWBOB_Q2_CREEP 0.0625f

/* Quake II: how long the fall kick takes to fade, in seconds */
#define VIEWBOB_Q2_FALLTIME 0.3f

/* Quake III: half cycles (footsteps) per second, per stance */
#define VIEWBOB_Q3_RUN 1.6f
#define VIEWBOB_Q3_WALK 1.2f
#define VIEWBOB_Q3_CROUCH 2.0f

/* Quake III landing: time to reach the lowest point, then to settle back */
#define VIEWBOB_LAND_DOWN 0.15f
#define VIEWBOB_LAND_UP 0.3f

struct
{
	float m_flCalcTime;
	float m_flBobTime;
	float m_flSpeed;
	float m_flFracSin;
	int m_iCycle;
	bool m_bCrouching;
	vector m_vecVelocity;

	bool m_bWasOnGround;
	float m_flOldVelZ;
	float m_flFallValue;
	float m_flFallTime;
	float m_flLandTime;
	float m_flLandDepth;

	vector m_vecLastAngles;
	vector m_vecTurnLag;
} g_quakeBobVars[4], *pQuakeBob;

bool
ViewBob_QuakeEnabled(void)
{
	return (autocvar_cg_viewBobStyle == 2 || autocvar_cg_viewBobStyle == 3) ? true : false;
}

bool
ViewBob_QuakeCameraEnabled(void)
{
	return (ViewBob_QuakeEnabled() && autocvar_cg_viewBobCamera) ? true : false;
}

static float
ViewBob_WrapAngle(float a)
{
	return a - 360.0f * rint(a / 360.0f);
}

static void
ViewBob_SelectSeat(void)
{
	int s = (float)getproperty(VF_ACTIVESEAT);
	pQuakeBob = &g_quakeBobVars[s];
}

/* advances the cycle, fall kick and turn lag. safe to call more than once
 * per frame, only the first call does anything. */
void
ViewBob_QuakeCalc(vector viewAngles)
{
	ViewBob_SelectSeat();

	if (pQuakeBob->m_flCalcTime == time)
		return;

	pQuakeBob->m_flCalcTime = time;

	ncPlayer pl = (ncPlayer)pSeat->m_ePlayer;
	bool isQ2 = (autocvar_cg_viewBobStyle == 2) ? true : false;
	bool onGround = (pl.flags & FL_ONGROUND) ? true : false;
	vector vel = pSeat->m_vecPredictedVelocity;

	pQuakeBob->m_bCrouching = (pl.m_nuclideFlags & VFL_CROUCHING) ? true : false;
	pQuakeBob->m_vecVelocity = vel;
	pQuakeBob->m_flSpeed = vlen([vel[0], vel[1], 0.0f]);

	/* step cycle, only while on the ground */
	if (pQuakeBob->m_flSpeed < 5.0f) {
		pQuakeBob->m_flBobTime = 0.0f;
	} else if (onGround) {
		float move;

		if (isQ2) {
			if (pQuakeBob->m_flSpeed > 210.0f)
				move = VIEWBOB_Q2_RUN;
			else if (pQuakeBob->m_flSpeed > 100.0f)
				move = VIEWBOB_Q2_WALK;
			else
				move = VIEWBOB_Q2_CREEP;

			if (pQuakeBob->m_bCrouching)
				move *= 4.0f;

			move *= frametime / VIEWBOB_Q2_TICK;
		} else {
			if (pQuakeBob->m_bCrouching)
				move = VIEWBOB_Q3_CROUCH;
			else if (pQuakeBob->m_flSpeed > 200.0f)
				move = VIEWBOB_Q3_RUN;
			else
				move = VIEWBOB_Q3_WALK;

			move *= frametime;
		}

		pQuakeBob->m_flBobTime += move;
	}

	pQuakeBob->m_iCycle = (int)pQuakeBob->m_flBobTime;
	pQuakeBob->m_flFracSin = fabs(sin(pQuakeBob->m_flBobTime * M_PI));

	/* touching down: the kick grows with the square of the fall speed */
	if (onGround && pQuakeBob->m_bWasOnGround == false && pQuakeBob->m_flOldVelZ < 0.0f) {
		float fallSpeed = -pQuakeBob->m_flOldVelZ;
		float delta = fallSpeed * fallSpeed * 0.0001f;

		/* Quake II: a plain jump on flat ground stays under the threshold */
		if (delta >= 15.0f) {
			pQuakeBob->m_flFallValue = min(delta * 0.5f, 40.0f);
			pQuakeBob->m_flFallTime = time + VIEWBOB_Q2_FALLTIME;
		}

		/* Quake III: every landing dips the gun */
		if (fallSpeed > 100.0f) {
			pQuakeBob->m_flLandDepth = bound(4.0f, fallSpeed * 0.025f, 24.0f);
			pQuakeBob->m_flLandTime = time;
		}
	}
	pQuakeBob->m_bWasOnGround = onGround;
	pQuakeBob->m_flOldVelZ = vel[2];

	/* Quake II: the gun trails turns by a fifth of the last tick's turn */
	if (isQ2 && frametime > 0.0f) {
		vector target = g_vec_null;

		for (int i = 0; i < 2; i++) {
			float turn = ViewBob_WrapAngle(pQuakeBob->m_vecLastAngles[i] - viewAngles[i]);

			/* respawns and teleports snap the view, don't swing for them */
			if (fabs(turn) > 90.0f)
				turn = 0.0f;

			turn = bound(-45.0f, turn * (VIEWBOB_Q2_TICK / frametime), 45.0f);

			if (i == 1)
				target[2] += 0.1f * turn;

			target[i] += 0.2f * turn;
		}

		/* stands in for the client lerping between 10 Hz snapshots */
		float k = 1.0f - pow(0.5f, frametime / 0.07f);
		pQuakeBob->m_vecTurnLag += (target - pQuakeBob->m_vecTurnLag) * k;
	} else {
		pQuakeBob->m_vecTurnLag = g_vec_null;
	}

	pQuakeBob->m_vecLastAngles = viewAngles;
}

static float
ViewBob_FallRatio(void)
{
	if (autocvar_cg_viewBobLand == false)
		return 0.0f;

	return max(0.0f, (pQuakeBob->m_flFallTime - time) / VIEWBOB_Q2_FALLTIME);
}

/* view angles plus the step bob, run tilt and fall kick */
vector
ViewBob_QuakeCameraAngles(vector viewAngles)
{
	ViewBob_SelectSeat();

	float scale = autocvar_cg_viewBobScale;
	float crouchMul = pQuakeBob->m_bCrouching ? 6.0f : 1.0f;
	float delta;
	vector kick = g_vec_null;

	kick[0] += ViewBob_FallRatio() * pQuakeBob->m_flFallValue;

	makevectors(viewAngles);
	kick[0] += dotproduct(pQuakeBob->m_vecVelocity, v_forward) * autocvar_cg_runPitch;
	kick[2] += dotproduct(pQuakeBob->m_vecVelocity, v_right) * autocvar_cg_runRoll;

	kick[0] += pQuakeBob->m_flFracSin * autocvar_cg_bobPitch * pQuakeBob->m_flSpeed * crouchMul;

	delta = pQuakeBob->m_flFracSin * autocvar_cg_bobRoll * pQuakeBob->m_flSpeed * crouchMul;
	if (pQuakeBob->m_iCycle & 1)
		delta = -delta;
	kick[2] += delta;

	return viewAngles + kick * scale;
}

/* height offset for the camera: step bob up, fall dip down */
vector
ViewBob_QuakeCameraOffset(void)
{
	ViewBob_SelectSeat();

	float height = min(pQuakeBob->m_flFracSin * pQuakeBob->m_flSpeed * autocvar_cg_bobUp, 6.0f);
	height -= ViewBob_FallRatio() * pQuakeBob->m_flFallValue * 0.4f;

	return [0.0f, 0.0f, height * autocvar_cg_viewBobScale];
}

/* how far down the Quake III landing dip currently is */
static float
ViewBob_LandOffset(void)
{
	float t = time - pQuakeBob->m_flLandTime;

	if (autocvar_cg_viewBobLand == false || pQuakeBob->m_flLandDepth <= 0.0f)
		return 0.0f;

	if (t < 0.0f)
		return 0.0f;

	if (t < VIEWBOB_LAND_DOWN)
		return pQuakeBob->m_flLandDepth * (t / VIEWBOB_LAND_DOWN);

	t -= VIEWBOB_LAND_DOWN;

	if (t < VIEWBOB_LAND_UP)
		return pQuakeBob->m_flLandDepth * (1.0f - (t / VIEWBOB_LAND_UP));

	pQuakeBob->m_flLandDepth = 0.0f;
	return 0.0f;
}

/* the gun's own motion on top of the camera.
 * v_forward, v_right and v_up must hold the camera's axes */
void
ViewBob_QuakeApply(entity gun)
{
	ViewBob_SelectSeat();

	float swing = pQuakeBob->m_flSpeed * pQuakeBob->m_flFracSin;
	vector bobAngles = g_vec_null;
	float land = 0.0f;

	bobAngles[0] = swing * 0.005f;

	if (autocvar_cg_viewBobStyle == 2) {
		bobAngles[1] = swing * 0.01f;
		bobAngles[2] = swing * 0.005f;
	} else {
		bobAngles[1] = swing * 0.005f;
		bobAngles[2] = swing * 0.005f;
	}

	/* alternate the side every footstep */
	if (pQuakeBob->m_iCycle & 1) {
		bobAngles[1] = -bobAngles[1];
		bobAngles[2] = -bobAngles[2];
	}

	if (autocvar_cg_viewBobStyle == 2) {
		bobAngles += pQuakeBob->m_vecTurnLag;
	} else {
		/* Quake III: slow drift, a little wider while moving */
		float drift = (pQuakeBob->m_flSpeed + 40.0f) * sin(time) * 0.01f;
		bobAngles += [drift, drift, drift];

		/* landing pushes the gun down and tips it forward */
		land = ViewBob_LandOffset();
		bobAngles[0] += land * 0.25f;
	}

	gun.angles += bobAngles * autocvar_cg_viewBobScale;
	gun.origin -= v_up * (land * 0.5f * autocvar_cg_viewBobScale * autocvar_cg_viewmodelScale);
	gun.origin += (v_forward * autocvar_cg_viewmodelOffset[0])
		+ (v_right * autocvar_cg_viewmodelOffset[1])
		+ (v_up * autocvar_cg_viewmodelOffset[2]);
}
