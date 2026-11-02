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

/* Quake II / Quake III style viewmodel motion, shared by every game.
 *
 * Written from how the motion looks and from public descriptions of it,
 * not from either game's source:
 *
 * - The step cycle only runs while on the ground. Each half cycle is one
 *   footstep. The rate depends on stance (walk, run, crouch), not on the
 *   exact speed, and the cycle starts over when the player stops.
 * - The size of the motion scales with horizontal speed.
 * - Every footstep the gun dips in pitch, and swings in roll and yaw
 *   towards the stepping side, alternating left and right.
 * - Landing from a fall pushes the gun down quickly and lets it settle
 *   back up more slowly. Harder falls push further.
 * - Quake III adds a slow idle drift that is always running.
 * - Quake II lets the gun trail behind quick turns and catch up.
 *
 * cg_viewBobStyle picks the motion: 0 keeps the game's own bob,
 * 2 is Quake II, 3 is Quake III. */

var float autocvar_cg_viewBobStyle = 3;
var float autocvar_cg_viewBobScale = 1.0f;
var bool autocvar_cg_viewBobLand = true;

/* degrees of swing per unit of speed at the peak of a step */
#define VIEWBOB_ANGLE 0.005f

/* half cycles (footsteps) per second, per stance */
#define VIEWBOB_Q3_RUN 1.6f
#define VIEWBOB_Q3_WALK 1.2f
#define VIEWBOB_Q3_CROUCH 2.0f
#define VIEWBOB_Q2_RUN 2.5f
#define VIEWBOB_Q2_WALK 1.25f
#define VIEWBOB_Q2_CROUCH 0.625f

/* landing: time to reach the lowest point, then time to settle back */
#define VIEWBOB_LAND_DOWN 0.15f
#define VIEWBOB_LAND_UP 0.3f

struct
{
	float m_flPhase;
	float m_flSpeed;
	float m_flFracSin;
	int m_iCycle;

	bool m_bWasOnGround;
	float m_flFallSpeed;
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

static float
ViewBob_StepRate(bool isQ2, bool isCrouching, float speed)
{
	if (isQ2) {
		if (isCrouching)
			return VIEWBOB_Q2_CROUCH;
		return (speed > 210.0f) ? VIEWBOB_Q2_RUN : VIEWBOB_Q2_WALK;
	}

	if (isCrouching)
		return VIEWBOB_Q3_CROUCH;
	return (speed > 200.0f) ? VIEWBOB_Q3_RUN : VIEWBOB_Q3_WALK;
}

static float
ViewBob_WrapAngle(float a)
{
	a = a - 360.0f * rint(a / 360.0f);
	return a;
}

/* runs once per frame, before ViewBob_QuakeApply */
void
ViewBob_QuakeCalc(vector viewAngles)
{
	int s = (float)getproperty(VF_ACTIVESEAT);
	pQuakeBob = &g_quakeBobVars[s];

	ncPlayer pl = (ncPlayer)pSeat->m_ePlayer;
	bool isQ2 = (autocvar_cg_viewBobStyle == 2) ? true : false;
	bool onGround = (pl.flags & FL_ONGROUND) ? true : false;
	bool isCrouching = (pl.m_nuclideFlags & VFL_CROUCHING) ? true : false;
	vector vel = pSeat->m_vecPredictedVelocity;
	float fallSpeed = -vel[2];

	vel[2] = 0.0f;
	pQuakeBob->m_flSpeed = vlen(vel);

	/* step cycle */
	if (pQuakeBob->m_flSpeed < 5.0f) {
		pQuakeBob->m_flPhase = 0.0f;
	} else if (onGround) {
		pQuakeBob->m_flPhase += frametime * ViewBob_StepRate(isQ2, isCrouching, pQuakeBob->m_flSpeed);
	}

	pQuakeBob->m_iCycle = (int)pQuakeBob->m_flPhase;
	pQuakeBob->m_flFracSin = fabs(sin(pQuakeBob->m_flPhase * M_PI));

	/* landing: remember how fast we were falling, kick when we touch down */
	if (!onGround) {
		pQuakeBob->m_flFallSpeed = max(fallSpeed, 0.0f);
	} else if (pQuakeBob->m_bWasOnGround == false) {
		float fall = pQuakeBob->m_flFallSpeed;

		if (fall > 100.0f) {
			pQuakeBob->m_flLandDepth = bound(4.0f, fall * 0.025f, 24.0f);
			pQuakeBob->m_flLandTime = time;
		}

		pQuakeBob->m_flFallSpeed = 0.0f;
	}
	pQuakeBob->m_bWasOnGround = onGround;

	/* Quake II: the gun trails behind turns and eases back */
	if (isQ2) {
		vector delta;
		delta[0] = ViewBob_WrapAngle(pQuakeBob->m_vecLastAngles[0] - viewAngles[0]);
		delta[1] = ViewBob_WrapAngle(pQuakeBob->m_vecLastAngles[1] - viewAngles[1]);
		delta[2] = 0.0f;

		/* a teleport or respawn snaps the view, don't swing for it */
		if (fabs(delta[0]) > 90.0f || fabs(delta[1]) > 90.0f)
			delta = g_vec_null;

		pQuakeBob->m_vecTurnLag += delta * 0.2f;
		pQuakeBob->m_vecTurnLag *= pow(0.5f, frametime * 14.0f);
		pQuakeBob->m_vecTurnLag[0] = bound(-9.0f, pQuakeBob->m_vecTurnLag[0], 9.0f);
		pQuakeBob->m_vecTurnLag[1] = bound(-9.0f, pQuakeBob->m_vecTurnLag[1], 9.0f);
	} else {
		pQuakeBob->m_vecTurnLag = g_vec_null;
	}

	pQuakeBob->m_vecLastAngles = viewAngles;
}

/* how far down the landing kick currently is, from 0 to m_flLandDepth */
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

/* v_forward, v_right and v_up must hold the camera's axes */
void
ViewBob_QuakeApply(entity gun)
{
	int s = (float)getproperty(VF_ACTIVESEAT);
	pQuakeBob = &g_quakeBobVars[s];

	float swing = pQuakeBob->m_flSpeed * pQuakeBob->m_flFracSin * VIEWBOB_ANGLE;
	float side = swing;
	float land;
	vector bobAngles = g_vec_null;

	/* alternate the side every footstep */
	if (pQuakeBob->m_iCycle & 1)
		side = -side;

	bobAngles[0] = swing;
	bobAngles[1] = side;
	bobAngles[2] = side;

	/* Quake III: slow drift, a little wider while moving */
	if (autocvar_cg_viewBobStyle == 3) {
		float drift = (pQuakeBob->m_flSpeed + 40.0f) * sin(time) * 0.01f;
		bobAngles += [drift, drift, drift];
	}

	bobAngles += pQuakeBob->m_vecTurnLag;

	/* landing pushes the gun down and tips it forward */
	land = ViewBob_LandOffset();
	bobAngles[0] += land * 0.25f;

	gun.angles += bobAngles * autocvar_cg_viewBobScale;
	gun.origin -= v_up * (land * 0.5f * autocvar_cg_viewBobScale * autocvar_cg_viewmodelScale);
	gun.origin += (v_forward * autocvar_cg_viewmodelOffset[0])
		+ (v_right * autocvar_cg_viewmodelOffset[1])
		+ (v_up * autocvar_cg_viewmodelOffset[2]);
}
