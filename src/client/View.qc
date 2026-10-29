/*
 * Copyright (c) 2022 Vera Visions LLC.
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

var bool autocvar_r_skipWorld = false;
var float autocvar_cg_viewZSmoothingMax = 16;
var float autocvar_cg_viewZSmoothingMin = 1;
var float autocvar_cg_viewZSmoothingTime = 0.1;

void
ncView::ncView(void)
{
	m_viewTarget = __NULL__;
	m_vecPosition = [0,0];
	m_vecSize = [0,0];
	m_iSeat = 0;
	m_flFieldOfView = 90.0f;
	m_client = __NULL__;
	m_flSensitivity = 1.0f;
	m_bDrawEntities = true;
	m_deathCamActive = false;
}

string Sky_GetMaterial(void);


int
ncView_Contents(vector org)
{
	int oldhitcontents = self.hitcontentsmaski;
	self.hitcontentsmaski = -1;
	traceline(org, org, MOVE_EVERYTHING, self);
	self.hitcontentsmaski = oldhitcontents;
	return trace_endcontentsi;
}

void
ncView::SetupView(void)
{
	setproperty(VF_DRAWENGINESBAR, (float)0);
	setproperty(VF_DRAWCROSSHAIR, (float)0);

	if (g_cheats == true) {
		setproperty(VF_DRAWWORLD, autocvar_r_skipWorld ? false : true);
	} else {
		setproperty(VF_DRAWWORLD, (float)1);
	}

	setproperty(VF_ACTIVESEAT, (float)m_iSeat);
	setproperty(VF_MIN, m_vecPosition);
	setproperty(VF_SIZE, m_vecSize);
	setproperty(VF_AFOV, m_flFieldOfView);
	setsensitivityscaler(m_flSensitivity);

	/* if yes, draw everything. */
	if (m_bDrawLocalPlayer) {
		setproperty(VF_VIEWENTITY, 0);
	} else {
		setproperty(VF_VIEWENTITY, m_viewTarget.entnum);
	}

	/* Nasty and we should implement that VF_UNDERWATER/FORCECONTENTS thing Spoike and I discussed */
	if (ncView_Contents(origin) & CONTENTBITS_FLUID) {
		//cvar_set("r_postprocshader", "waterwarp");
		//setproperty(VF_RT_SOURCECOLOUR, "waterwarp");
		//setproperty(VF_RT_DESTCOLOUR, "waterwarp", IMGFMT_R8G8B8A8, m_vecSize);
	} else {
		//cvar_set("r_postprocshader", "");
	}

	/* handle camera override */
	if (pSeat->m_flCameraTime > time || pSeat->m_flCameraTime == -1) {
		setproperty(VF_ORIGIN, pSeat->m_vecCameraOrigin);
		setproperty(VF_CL_VIEWANGLES, pSeat->m_vecCameraAngle);
		setproperty(VF_ANGLES, pSeat->m_vecCameraAngle);
	} else {
		setproperty(VF_ORIGIN, origin);
		//setproperty(VF_CL_VIEWANGLES, angles);
		setproperty(VF_ANGLES, angles);
		pSeat->m_flCameraTime = 0.0f;
	}

	/* the view may not have gotten the chance to set the client angle early on */
	/* honestly this could be handled a lot better, but I don't know of a more reliable solution right now */
	if (m_bSetClientAngle == true || cltime <= 0.5) {
		setproperty(VF_ANGLES, m_vecClientAngle);
		setproperty(VF_CL_VIEWANGLES, m_vecClientAngle);
		m_bSetClientAngle = false;
	}

	m_vecLastOrigin = origin;
}

void
ncView::RenderView(void)
{
	renderscene();
}

void
ncView::SetDrawLocalPlayer(bool choice)
{
	m_bDrawLocalPlayer = choice;
}

void
ncView::StairSmooth(void)
{
	/* don't run this on anything going up or down... */
	if (fabs(m_viewTarget.groundentity.velocity[2]))
		return;

	/* handle stair stepping */
	if (GetViewMode() == VIEWMODE_FPS) {
		vector endpos = origin;

		/* Have we gone up since last frame? */
		if ((m_viewTarget.flags & FL_ONGROUND) && (endpos[2] - m_vecLastOrigin[2] > 0)) {
			endpos[2] = m_vecLastOrigin[2] += (frametime * 1000) * autocvar_cg_viewZSmoothingTime;

			if (endpos[2] > origin[2]) {
				endpos[2] = origin[2];
			}
			if (origin[2] - endpos[2] > autocvar_cg_viewZSmoothingMax) {
				endpos[2] = origin[2] - autocvar_cg_viewZSmoothingMax;
			}
		}

		// Teleport hack
		if (fabs(origin[2] - m_vecLastOrigin[2]) > 64) {
			endpos[2] = origin[2];
		}

		origin = endpos;
	}
}

void
ncView::SetViewPosition(vector new_pos)
{
	m_vecPosition = new_pos;
}

void
ncView::SetViewSize(vector new_size)
{
	m_vecSize = new_size;
}

void
ncView::SetViewTarget(ncEntity new_target)
{
	m_viewTarget = new_target;
}

void
ncView::SetCameraOrigin(vector new_origin)
{
	origin = new_origin;
}

void
ncView::SetCameraAngle(vector new_angle)
{
	angles = new_angle;
}

vector
ncView::GetCameraOrigin(void)
{
	return origin;
}

vector
ncView::GetCameraAngle(void)
{
	return angles;
}

void
ncView::SetClientAngle(vector new_angle)
{
	m_vecClientAngle = new_angle;
	m_bSetClientAngle = true;
}

void
ncView::SetViewMode(viewmode_t new_mode)
{
	m_viewmode = new_mode;
}

viewmode_t
ncView::GetViewMode(void)
{
	return m_viewmode;
}

void
ncView::SetSeatID(int new_id)
{
	m_iSeat = new_id;
}

void
ncView::SetClientOwner(ncClient new_owner)
{
	m_client = new_owner;
}

void
ncView::SetAFOV(float new_fov)
{
	m_flFieldOfView = new_fov;
}

float
ncView::GetAFOV(void)
{
	return m_flFieldOfView;
}

void
ncView::SetSensitivity(float new_fov)
{
	m_flSensitivity = new_fov;
}

float
ncView::GetSensitivity(void)
{
	return m_flSensitivity;
}

vector
ncView::GetHUDCanvasPos(void)
{
	if (autocvar_cg_hudAspect <= 0) {
		return m_vecPosition;
	} else {
		return [m_vecPosition[0] + ((m_vecSize[0] / 2) - ((m_vecSize[1] * autocvar_cg_hudAspect) / 2)), m_vecPosition[1]];
	}
}

vector
ncView::GetHUDCanvasSize(void)
{
	if (autocvar_cg_hudAspect <= 0) {
		return m_vecSize;
	} else {
		return [m_vecSize[1] * autocvar_cg_hudAspect, m_vecSize[1]];
	}
}

float
ncView::GetViewWidth(void)
{
	return m_vecSize[0];
}

float
ncView::GetViewHeight(void)
{
	return m_vecSize[1];
}

void
ncView::AddPunchAngle(vector vecAdd)
{
	angles += vecAdd;
}

void
ncView::SetSoundScape(ncSoundScape newSoundScape)
{
	m_soundScape = newSoundScape;
}

ncSoundScape
ncView::GetSoundScape(void)
{
	return (m_soundScape);
}

void View_PreDraw();
void View_PostDraw();
void View_DrawViewModel();

void
ncView::UpdateView(void)
{
	ncPlayer pl = (ncPlayer)m_viewTarget;
	ncPlayer cl = (ncPlayer)m_viewTarget;
	ncSpectator spec = (ncSpectator)m_viewTarget;
	entity c;

	clearscene();

	/* is a client attached to this view? */
	if (cl) {
		/* run preframe code on our viewtarget */
		cl.PreFrame();

		/* update our player seat info with predicted info */
		pSeat->m_vecPredictedOrigin = cl.origin;
		pSeat->m_flPredictedFlags = cl.flags;
		pSeat->m_vecPredictedVelocity = cl.velocity;
		pSeat->m_weaponAnimSequence = cl.m_weaponAnimSequence;
		pSeat->m_weaponAnimTime = cl.m_weaponAnimTime;

		if (cl.m_activeWeapon) {
			pSeat->m_weaponModel = cl.m_activeWeapon.m_viewModel;
			pSeat->m_weaponClass = cl.m_activeWeapon.declclass;
			pSeat->m_weaponFireInfo = cl.m_activeWeapon.m_weaponLastFireInfo;
		} else {
			pSeat->m_weaponModel = 0;
			pSeat->m_weaponClass = "";
			pSeat->m_weaponFireInfo = "";
		}

		SetCameraOrigin(cl.origin);

		/* this player will respawn, so null visual damage cues */
		if (Client_IsDead(cl)) {
			if (_m_bWasAlive == true) {
				pSeat->m_flDamageAlpha = 0.0f;
				pSeat->m_vecDamagePos = g_vec_null;
				pSeat->m_iDamageFlags = 0i;
				Shake_Stop();
			}
			_m_bWasAlive = false;
		} else {
			_m_bWasAlive = true;
		}
	}

	/* put entities into the scene (and call their predraws */
	if (m_bDrawEntities) {
		addentities(MASK_ENGINE);
	}

	/* after predraws we can act upon their new positions */
	if (cl) {
	switch (GetViewMode()) {
	case VIEWMODE_FPS:
		m_deathCamActive = false;

		if (Client_InIntermission()) {
			cl.UpdateIntermissionCam();
		} else {
			if (Client_IsDead(pl)) {
				SetAFOV(cvar("fov"));
				SetSensitivity(1.0f);
				pl.UpdateDeathcam();
			} else {
				float totalZoom = pl.viewzoom;
				
				if (pl.viewzoom == 1.0f && pSeat->m_iZoomed == true) {
					pSeat->m_flZoomTime += clframetime;
				} else {
					pSeat->m_flZoomTime -= clframetime;
				}

				pSeat->m_flZoomTime = bound(0.0, pSeat->m_flZoomTime, 1.0f);
				totalZoom *= lerp(1.0f, 0.5, pSeat->m_flZoomTime);

				SetAFOV(cvar("fov") * totalZoom);
				SetSensitivity(totalZoom);
				cl.UpdateAliveCam();
				StairSmooth();
				View_DrawViewModel();
				_m_bWasAlive = true;
			}
		}
		break;
	case VIEWMODE_THIRDPERSON:
		break;
	case VIEWMODE_SPECTATING:
		spec = (ncSpectator)m_viewTarget;

		drawfill(m_vecPosition, m_vecSize, [0.1, 0.1, 0.15], 1.0f, 0);

		if (spec.m_spectatingMode != SPECMODE_DEATHCAM) {
			m_deathCamActive = false;
		}

		switch (spec.m_spectatingMode) {
		case SPECMODE_DEATHCAM:
			/* we stay where we died. the camera pulls back from there and
			   looks at whoever we're tracking (our killer), then after
			   cl_freezecam_delay seconds moves in on them and holds the
			   shot, like Team Fortress 2's death and freeze cams. with
			   nobody to track it looks back at where we fell. */
			if (m_deathCamActive == false) {
				m_deathCamActive = true;
				m_deathCamStart = time;
				m_deathCamFrozen = false;
			}

			float camTime = time - m_deathCamStart;
			vector bodyPos = spec.origin + [0, 0, 16];
			vector lookAt = bodyPos;
			vector awayDir;
			c = __NULL__;

			if (spec.m_spectatingEntity > 0 && spec.m_spectatingEntity != spec.entnum) {
				c = findfloat(world, ::entnum, spec.m_spectatingEntity);
			}

			if (c) {
				lookAt = ((c.absmin + c.absmax) * 0.5f) + [0, 0, 16];
				awayDir = normalize(bodyPos - lookAt);
			} else {
				awayDir = anglesToForward(view_angles) * -1.0f;
			}

			/* pull back from the body over half a second */
			float pullBack = bound(0.0f, camTime / 0.5f, 1.0f);
			vector camPos = bodyPos + (awayDir * (96.0f * pullBack)) + [0, 0, 32.0f * pullBack];
			traceline(bodyPos, camPos, MOVE_NOMONSTERS, spec);
			camPos = trace_endpos + (normalize(bodyPos - trace_endpos) * 4.0f * (trace_fraction < 1.0f));

			if (c && camTime >= autocvar(cl_freezecam_delay, 2.0f)) {
				if (m_deathCamFrozen == false) {
					m_deathCamFrozen = true;
					m_deathCamFreezeFrom = camPos;
					m_deathCamFreezeAt = lookAt;
				}

				vector freezePos = m_deathCamFreezeAt + (normalize(m_deathCamFreezeFrom - m_deathCamFreezeAt) * 96.0f);
				traceline(m_deathCamFreezeAt, freezePos, MOVE_NOMONSTERS, spec);
				freezePos = trace_endpos + (normalize(m_deathCamFreezeAt - trace_endpos) * 4.0f * (trace_fraction < 1.0f));

				float travel = bound(0.0f, (camTime - autocvar(cl_freezecam_delay, 2.0f)) / 0.4f, 1.0f);
				camPos = m_deathCamFreezeFrom + ((freezePos - m_deathCamFreezeFrom) * travel);
				lookAt = m_deathCamFreezeAt;
			}

			SetCameraOrigin(camPos);

			if (vlen(lookAt - camPos) > 1.0f) {
				SetCameraAngle(vectoangles(lookAt - camPos));
			} else {
				SetCameraAngle(view_angles);
			}
			break;
		case SPECMODE_LOCKEDCHASE:
			view_angles = [0, spec.v_angle[1], 0];
		case SPECMODE_THIRDPERSON:
			makevectors(view_angles);
			vector vecStart = spec.GetEyePos();
			vecStart[2] += 16;
			vecStart += (v_right * 4);

			vector vecEnd = vecStart + (v_forward * -48) + [0,0,16] + (v_right * 4);
			traceline(vecStart, vecEnd, FALSE, m_viewTarget);

			SetCameraOrigin(trace_endpos + (v_forward * 5));
			SetCameraAngle(view_angles);
			break;
		case SPECMODE_FIRSTPERSON:
			c = findfloat(world, ::entnum, spec.m_spectatingEntity);

			if (is.Player(c)) {
				ncPlayer bp = (ncPlayer)c;
				removeentity(c);
				SetCameraOrigin(bp.GetEyePos());
				SetCameraAngle(bp.v_angle);
				SetAFOV(cvar("fov") * bp.viewzoom);

				/* 0 means world */
				if (spec.m_spectatingEntity) {
					c = findfloat(world, ::entnum, spec.m_spectatingEntity);

					/* we found them */
					if (c && c != spec) {
						ncPlayer ps = (ncPlayer)c;
						if (ps.health <= 0)
							pl.UpdateDeathcam();
						else
							View_DrawViewModel();
					}
				}
			}
			break;
		case SPECMODE_CHASEOVERVIEW:
			c = findfloat(world, ::entnum, spec.m_spectatingEntity);
			if (is.Player(c)) {
				SetCameraOrigin(c.origin);
			}
			
			drawfill(m_vecPosition, m_vecSize, [0,0,0], 1.0f, DRAWFLAG_NORMAL);
			g_overview.SetViewPosition(m_vecPosition);
			g_overview.SetViewSize(m_vecSize);
			g_overview.SetRadarPitch(view_angles[0]);
			g_overview.UpdateView();
			return;
		case SPECMODE_FREEOVERVIEW:
			SetCameraOrigin(pSeat->m_vecPredictedOrigin);
			drawfill(m_vecPosition, m_vecSize, [0,0,0], 1.0f, DRAWFLAG_NORMAL);
			g_overview.SetViewPosition(m_vecPosition);
			g_overview.SetViewSize(m_vecSize);
			g_overview.SetRadarPitch(view_angles[0]);
			g_overview.UpdateView();
			return;
			break;
		default:
			SetCameraOrigin(cl.GetEyePos());
			SetCameraAngle(view_angles);
		}
		break;
	default:
		break;
	}

	View_PreDraw();

	}

	/* prepare our scene properties */
	SetupView();

	/* properties are locked in place, run logic that depends on final values */
	if (m_bDrawEntities)
		addentities(MASK_GLOWS);

	SkyCamera_Setup(origin);

	if (cl)
		ncXRManager::UpdateView(m_viewTarget);

	/* render our frame */
	RenderView();
	RenderTarget_Monitor_Update();

	/* all 2D operations happen after this point */
	for (entity b = world; (b = findfloat(b, ::isCSQC, 1));) {
		ncEntity pf = (ncEntity) b;

		if (pf.postdraw)
			pf.postdraw();
	}

	/* the blinding stuff */
	if (cl) {
		Fade_Update(m_vecPosition[0], m_vecPosition[1], m_vecSize[0], m_vecSize[1]);

		View_PostDraw();

		/* move this into ncClient methods */
		cl.PostFrame();
	}

	if (autocvar(r_showView, 0) == false)
		return;

	Font_DrawText(m_vecPosition + [8,8], "ncView Debug Information", FONT_CON);
	Font_DrawText(m_vecPosition + [8,20], sprintf("Seat: %i", m_iSeat), FONT_CON);
	Font_DrawText(m_vecPosition + [8,32], sprintf("FOV: %d", m_flFieldOfView), FONT_CON);
	Font_DrawText(m_vecPosition + [8,44], sprintf("Origin: %v", origin), FONT_CON);
	Font_DrawText(m_vecPosition + [8,56], sprintf("Angles: %v", angles), FONT_CON);
	Font_DrawText(m_vecPosition + [8,68], sprintf("View-Target: %d", num_for_edict(m_viewTarget)), FONT_CON);
	Font_DrawText(m_vecPosition + [8,80], sprintf("View-Mode: %d", m_viewmode), FONT_CON);

	if (!m_soundScape)
		return;

	m_soundScape.DebugDraw();
}
