/*
 * Copyright (c) 2016-2024 Vera Visions LLC.
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

void
ncSpectator::ncSpectator(void)
{
	flags |= FL_CLIENT;
	m_spectatingMode = SPECMODE_FREE;
}

void
ncSpectator::Respawn(void)
{
	Unspectate();
	super::Respawn();
}

void
ncSpectator::OnRemoveEntity(void)
{
	Unspectate();
	super::Respawn();
}

void
ncSpectator::Unspectate(void)
{
	m_spectatingEntity = 0;
	m_spectatingMode = SPECMODE_FREE;
	m_flDeathCam = 0.0f;
}

#ifdef SERVER
void
ncSpectator::Save(float handle)
{
	super::Save(handle);
}

void
ncSpectator::Restore(string keyName, string setValue)
{
	switch (keyName) {
	default:
		super::Restore(keyName, setValue);
	}
}
#endif

bool
ncSpectator::IsRealSpectator(void)
{
	return (true);
}

bool
ncSpectator::IsDead(void)
{
	return (false);
}

bool
ncSpectator::IsPlayer(void)
{
	return (false);
}

bool
ncSpectator::IsFakeSpectator(void)
{
	return (false);
}

void
ncSpectator::ProcessInput(void)
{
	if (input_buttons & INPUT_PRIMARY) {
		InputMode();
	} else if (input_buttons & INPUT_SECONDARY) {
		InputModePrevious();
	} else {
		m_spectatingFlags &= ~SPECFLAG_MODE_RELEASED;
	}

	if (!(input_buttons & (INPUT_PRIMARY | INPUT_SECONDARY))) {
		if (input_impulse == IMPULSE_SPEC_NEXT) {
			InputNext();
			input_impulse = 0;
		} else if (input_impulse == IMPULSE_SPEC_PREV) {
			InputPrevious();
			input_impulse = 0;
		} else {
			m_spectatingFlags &= ~SPECFLAG_TARGET_RELEASED;
		}
	}
}

entity
Spectator_EntityForPlayerSlot(float slotEntnum)
{
#ifdef CLIENT
	return findfloat(world, ::entnum, slotEntnum);
#else
	return edict_num(slotEntnum);
#endif
}

void
ncSpectator::WarpToTarget(void)
{
	entity b;

	if (!m_spectatingEntity)
		return;

	b = Spectator_EntityForPlayerSlot(m_spectatingEntity);

	if (!IsValidChaseTarget(b))
		return;

	setorigin(this, b.origin);
}

bool
Spectator_TargetIsPlayablePlayer(entity target)
{
	if (!target)
		return false;

#ifdef SERVER
	if (!(target.flags & FL_CLIENT))
		return false;
#endif

	if (!target._isPlayer)
		return false;

	if (target.classname == "spectator")
		return false;

	ncPlayer pl = (ncPlayer)target;

	if (!pl.IsPlayer())
		return false;

	if (pl.IsFakeSpectator() || pl.IsRealSpectator())
		return false;

	if (!pl.modelindex)
		return false;

#ifdef CLIENT
	/* CSQC remote players often lack classname/team/health until late in the
	   replication stream; trust modelindex + userinfo for other slots. */
	int slot = (int)(target.entnum - 1);

	if (getplayerkeyfloat(slot, "*spec"))
		return false;

	if (getplayerkeyfloat(slot, "*spectator"))
		return false;

	if ((int)getplayerkeyfloat(slot, "*team") == TEAM_SPECTATOR)
		return false;

	/* health can be stale 0 on freshly replicated ents; userinfo *dead
	   is authoritative for whether the slot is a corpse */
	if (pl.health <= 0 && getplayerkeyfloat(slot, "*dead"))
		return false;
#else
	if (pl.IsDead())
		return false;

	if (pl.team == TEAM_SPECTATOR)
		return false;
#endif

	return true;
}

bool
Spectator_HasChaseTargetEntity(entity spec, entity target)
{
	ncSpectator sp = (ncSpectator)spec;

	if (!sp || !target || !sp.m_spectatingEntity)
		return false;

#ifdef SERVER
	if (num_for_edict(target) != sp.m_spectatingEntity)
		return false;
#else
	if (target.entnum != sp.m_spectatingEntity)
		return false;
#endif

	return Spectator_TargetIsPlayablePlayer(target);
}

bool
Spectator_IsValidChaseTarget(entity spectator, entity target)
{
	if (!target || !spectator)
		return false;

	/* never chase our own client slot */
	if (target == spectator)
		return false;

	if (num_for_edict(target) == num_for_edict(spectator))
		return false;

#ifdef CLIENT
	if (target.entnum == spectator.entnum)
		return false;
#endif

#ifdef SERVER
	if (clienttype(target) != CLIENTTYPE_REAL
		&& clienttype(target) != CLIENTTYPE_BOT) {
		return false;
	}
#else
	int slot = (int)(target.entnum - 1);

	if (!STRING_SET(getplayerkeyvalue(slot, "name")))
		return false;

	/* no CSQC entity yet — fall back to userinfo only */
	if (!target._isPlayer) {
		if (getplayerkeyfloat(slot, "*spec"))
			return false;

		if (getplayerkeyfloat(slot, "*spectator"))
			return false;

		if ((int)getplayerkeyfloat(slot, "*team") == TEAM_SPECTATOR)
			return false;

		return false;
	}
#endif

	return Spectator_TargetIsPlayablePlayer(target);
}

bool
ncSpectator::IsValidChaseTarget(entity target)
{
	return Spectator_IsValidChaseTarget(this, target);
}

void
ncSpectator::SharedInputFrame(void)
{
	/* Overview spectator cameras stay in the codebase (ncRadar, View.qc) but
	   are not used during play — remap if anything still selects them. */
	if (m_spectatingMode == SPECMODE_FREEOVERVIEW)
		m_spectatingMode = SPECMODE_FREE;
	else if (m_spectatingMode == SPECMODE_CHASEOVERVIEW)
		m_spectatingMode = SPECMODE_LOCKEDCHASE;

	SetSize(g_vec_null, g_vec_null);

	if (m_spectatingMode == SPECMODE_FREE || m_spectatingMode == SPECMODE_FREEOVERVIEW) {
		if (m_spectatingMode == SPECMODE_FREEOVERVIEW) {
			input_angles[0] = 0.0f;
		}

		SetSolid(SOLID_NOT);
		SetMovetype(MOVETYPE_NOCLIP);
	} else {
		SetSolid(SOLID_NOT);
		SetMovetype(MOVETYPE_NONE);
	}
}

#ifdef SERVER
float
ncSpectator::SendEntity(entity ePVSent, float flChanged)
{
	if (this != ePVSent) {
		return (0);
	}

	if (clienttype(ePVSent) != CLIENTTYPE_REAL) {
		return (0);
	}

	WriteByte(MSG_ENTITY, ENT_SPECTATOR);
	WriteFloat(MSG_ENTITY, flChanged);

	SENDENTITY_COORD(origin[0], SPECFL_ORIGIN)
	SENDENTITY_COORD(origin[1], SPECFL_ORIGIN)
	SENDENTITY_COORD(origin[2], SPECFL_ORIGIN)

	SENDENTITY_FLOAT(velocity[0], SPECFL_VELOCITY)
	SENDENTITY_FLOAT(velocity[1], SPECFL_VELOCITY)
	SENDENTITY_FLOAT(velocity[2], SPECFL_VELOCITY)

	SENDENTITY_BYTE(m_spectatingEntity, SPECFL_TARGET)
	SENDENTITY_BYTE(m_spectatingMode, SPECFL_MODE)
	SENDENTITY_BYTE(m_spectatingFlags, SPECFL_FLAGS)
	SENDENTITY_BYTE(movetype, SPECFL_TYPE)
	SENDENTITY_BYTE(solid, SPECFL_TYPE)

	return (1);
}

void
ncSpectator::ServerInputFrame(void)
{
	movetype = MOVETYPE_NOCLIP;

	if (m_spectatingMode == SPECMODE_FREE) {
		runstandardplayerphysics(this);
	} else {
		WarpToTarget();
	}

	/* since we are not using Physics_Run(), we have to call this manually */
	ProcessInput();
}

#else
void
ncSpectator::ClientInputFrame(void)
{
	/* If we are inside a VGUI, don't let the client do stuff outside */
	if (VGUI_Active()) {
		input_impulse = 0;
		input_buttons = 0;
		return;
	}

	/* background maps have no input */
	if (serverkeyfloat("background") == 1) {
		input_impulse = 0;
		input_buttons = 0;
		input_movevalues = g_vec_null;
		return;
	}

	vector movementDir = vectorNormalize(input_movevalues);

	/* normalize movement values */
	if (movementDir[0] > 0)
		input_movevalues[0] = movementDir[0] * GetForwardSpeed();
	else
		input_movevalues[0] = movementDir[0] * GetBackSpeed();

	input_movevalues[1] = movementDir[1] * GetSideSpeed();
}

void
ncSpectator::ReceiveEntity(float new, float flChanged)
{
	if (m_spectatingMode == SPECMODE_FREE || m_spectatingMode == SPECMODE_FREEOVERVIEW)
	if (new == FALSE) {
		/* Go through all the physics code between the last received frame
		 * and the newest frame and keep the changes this time around instead
		 * of rolling back, because we'll apply the new server-verified values
		 * right after anyway. */
		/* FIXME: splitscreen */
		if (entnum == player_localentnum) {
			CSQC_UpdateSeat();
			pSeat = &g_seats[(int)getproperty(VF_ACTIVESEAT)];

			for (int i = sequence+1; i <= servercommandframe; i++) {
				/* ...maybe the input state is too old? */
				if (!getinputstate(i)) {
					break;
				}
				input_sequence = i;
				runstandardplayerphysics(this);
				ProcessInput();
			}

			/* any differences in things that are read below are now
			 * officially from prediction misses. */
		}
	}

	/* seed for our prediction table */
	sequence = servercommandframe;

	READENTITY_COORD(origin[0], SPECFL_ORIGIN)
	READENTITY_COORD(origin[1], SPECFL_ORIGIN)
	READENTITY_COORD(origin[2], SPECFL_ORIGIN)

	READENTITY_FLOAT(velocity[0], SPECFL_VELOCITY)
	READENTITY_FLOAT(velocity[1], SPECFL_VELOCITY)
	READENTITY_FLOAT(velocity[2], SPECFL_VELOCITY)

	READENTITY_BYTE(m_spectatingEntity, SPECFL_TARGET)
	READENTITY_BYTE(m_spectatingMode, SPECFL_MODE)
	READENTITY_BYTE(m_spectatingFlags, SPECFL_FLAGS)
	READENTITY_BYTE(movetype, SPECFL_TYPE)
	READENTITY_BYTE(solid, SPECFL_TYPE)

	if (m_spectatingMode == SPECMODE_FREEOVERVIEW)
		m_spectatingMode = SPECMODE_FREE;
	else if (m_spectatingMode == SPECMODE_CHASEOVERVIEW)
		m_spectatingMode = SPECMODE_LOCKEDCHASE;

	if (flChanged & SPECFL_TARGET) {
		m_flLastSpecTargetChange = time;
	}
};

float
ncSpectator::predraw(void)
{
	addentity(this);
	return (PREDRAW_NEXT);
}
#endif

void
ncSpectator::InputNext(void)
{
	if (m_flDeathCam > time)
		return;

	if (m_spectatingFlags & SPECFLAG_TARGET_RELEASED) {
		return;
	}

	m_spectatingFlags |= SPECFLAG_TARGET_RELEASED;

#if 0
	float max_edict;

	max_edict = serverkeyfloat("sv_playerslots");

	m_spectatingEntity++;

	if (m_spectatingEntity > max_edict)
		m_spectatingEntity = 1;

	print(sprintf("edict: %d\n", m_spectatingEntity));
#else
	float max_edict;
	float sep = m_spectatingEntity;
	float best = 0;
	bool engageChase = (m_spectatingMode == SPECMODE_FREE
		|| m_spectatingMode == SPECMODE_FREEOVERVIEW
		|| (m_spectatingMode == SPECMODE_DEATHCAM && m_flDeathCam < time));

	max_edict = serverkeyfloat("sv_playerslots");

	if (sep) {
		entity cur = Spectator_EntityForPlayerSlot(sep);

		if (!IsValidChaseTarget(cur))
			sep = 0;
	}

	for (float i = 1; i <= max_edict; i++) {
		entity f;

		if (i <= sep && best == 0) {
			f = Spectator_EntityForPlayerSlot(i);
			if (IsValidChaseTarget(f))
				best = i;
		}

		if (i > sep) {
			f = Spectator_EntityForPlayerSlot(i);
			if (IsValidChaseTarget(f)) {
				best = i;
				break;
			}
		}
	}

	if (best == 0)
		return;

	m_spectatingEntity = best;

	if (engageChase) {
		if (m_spectatingMode == SPECMODE_FREEOVERVIEW)
			m_spectatingMode = SPECMODE_CHASEOVERVIEW;
		else if (m_spectatingMode == SPECMODE_DEATHCAM && m_flDeathCam < time)
			m_spectatingMode = SPECMODE_THIRDPERSON;
		else if (m_spectatingMode == SPECMODE_FREE)
			m_spectatingMode = SPECMODE_THIRDPERSON;
	}
#endif

	WarpToTarget();

	if (m_spectatingMode == SPECMODE_CHASEOVERVIEW)
		m_spectatingMode = SPECMODE_CHASEOVERVIEW;
}

void
ncSpectator::InputPrevious(void)
{
	if (m_flDeathCam > time)
		return;

	if (m_spectatingFlags & SPECFLAG_TARGET_RELEASED) {
		return;
	}

	m_spectatingFlags |= SPECFLAG_TARGET_RELEASED;

#if 0
	float max_edict;

	max_edict = serverkeyfloat("sv_playerslots");

	m_spectatingEntity--;

	if (m_spectatingEntity < 1)
		m_spectatingEntity = max_edict;
#else
	float max_edict;
	float sep = m_spectatingEntity;
	float best = 0;
	bool engageChase = (m_spectatingMode == SPECMODE_FREE
		|| m_spectatingMode == SPECMODE_FREEOVERVIEW
		|| (m_spectatingMode == SPECMODE_DEATHCAM && m_flDeathCam < time));

	max_edict = serverkeyfloat("sv_playerslots");

	if (sep) {
		entity cur = Spectator_EntityForPlayerSlot(sep);

		if (!IsValidChaseTarget(cur))
			sep = 0;
	}

	for (float i = max_edict; i > 0; i--) {
		entity f;

		/* remember the first valid one here */
		if (i >= sep && best == 0) {
			f = Spectator_EntityForPlayerSlot(i);

			if (IsValidChaseTarget(f))
				best = i;
		}

		/* find the first good one and take it */
		if (i < sep) {
			f = Spectator_EntityForPlayerSlot(i);
			if (IsValidChaseTarget(f)) {
				best = i;
				break;
			}
		}
	}

	if (best == 0)
		return;

	m_spectatingEntity = best;

	if (engageChase) {
		if (m_spectatingMode == SPECMODE_FREEOVERVIEW)
			m_spectatingMode = SPECMODE_CHASEOVERVIEW;
		else if (m_spectatingMode == SPECMODE_DEATHCAM && m_flDeathCam < time)
			m_spectatingMode = SPECMODE_THIRDPERSON;
		else if (m_spectatingMode == SPECMODE_FREE)
			m_spectatingMode = SPECMODE_THIRDPERSON;
	}
#endif


	WarpToTarget();

	/* overview entry disabled: stay in the locked chase camera instead of
	   snapping to the map overview. The overview rendering path is left
	   intact, it just isn't reachable from spectator input anymore. */
}

void
ncSpectator::InputMode(void)
{
	if (m_spectatingMode == SPECMODE_DEATHCAM && m_flDeathCam < time) {
		m_spectatingMode = SPECMODE_THIRDPERSON;
		return;
	}

	if (m_spectatingFlags & SPECFLAG_MODE_RELEASED) {
		return;
	}

	m_spectatingFlags |= SPECFLAG_MODE_RELEASED;

	ncClient f;
#ifdef CLIENT
	f = (ncClient)findfloat(world, ::entnum, m_spectatingEntity);
#else
	f = (ncClient)edict_num(m_spectatingEntity);
#endif

	if (!f || !IsValidChaseTarget(f)) {
		/* no valid target: stay in free-fly. Overview modes are
		   intentionally skipped here (the rendering path still
		   exists, we just never select it from input). */
		m_spectatingMode = SPECMODE_FREE;
	} else {
		m_spectatingMode++;

		/* skip the overview modes when cycling chase cameras, wrapping
		   back to the first chase mode instead of entering FREEOVERVIEW. */
		if (m_spectatingMode >= SPECMODE_FREEOVERVIEW)
			m_spectatingMode = SPECMODE_LOCKEDCHASE;
	}
}

void
ncSpectator::InputModePrevious(void)
{
	if (m_spectatingMode == SPECMODE_DEATHCAM && m_flDeathCam < time) {
		m_spectatingMode = SPECMODE_THIRDPERSON;
		return;
	}

	if (m_spectatingFlags & SPECFLAG_MODE_RELEASED) {
		return;
	}

	m_spectatingFlags |= SPECFLAG_MODE_RELEASED;

	ncClient f;
#ifdef CLIENT
	f = (ncClient)findfloat(world, ::entnum, m_spectatingEntity);
#else
	f = (ncClient)edict_num(m_spectatingEntity);
#endif

	if (!f || !IsValidChaseTarget(f)) {
		m_spectatingMode = SPECMODE_FREE;
	} else {
		m_spectatingMode--;

		/* wrap backward through the chase modes, skipping overview/deathcam */
		if (m_spectatingMode < SPECMODE_LOCKEDCHASE
			|| m_spectatingMode == SPECMODE_DEATHCAM
			|| m_spectatingMode == SPECMODE_FREEOVERVIEW
			|| m_spectatingMode == SPECMODE_CHASEOVERVIEW) {
			m_spectatingMode = SPECMODE_FIRSTPERSON;
		}
	}
}

void
ncSpectator::PreFrame(void)
{
#ifdef CLIENT
	/* base player attributes/fields we're going to roll back */
	SAVE_STATE(origin)
	SAVE_STATE(velocity)
	SAVE_STATE(m_spectatingEntity)
	SAVE_STATE(m_spectatingMode)
	SAVE_STATE(m_spectatingFlags)

	/* run physics code for all the input frames which we've not heard back
	 * from yet. This continues on in Player_ReceiveEntity! */
	for (int i = sequence + 1; i <= clientcommandframe; i++) {
		float flSuccess = getinputstate(i);
		if (flSuccess == FALSE) {
			continue;
		}

		if (i==clientcommandframe){
			CSQC_Input_Frame();
		}

		/* don't do partial frames, aka incomplete input packets */
		if (input_timelength == 0) {
			break;
		}

		/* this global is for our shared random number seed */
		input_sequence = i;

		/* run our custom physics */
		runstandardplayerphysics(this);
		ProcessInput();
	}
#endif

	SpectatorTrackPlayer();
}

void
ncSpectator::SpectatorTrackPlayer(void)
{
	if (m_spectatingMode == SPECMODE_DEATHCAM
		|| m_spectatingMode == SPECMODE_THIRDPERSON 
		|| m_spectatingMode == SPECMODE_FIRSTPERSON
		|| m_spectatingMode == SPECMODE_CHASEOVERVIEW
		|| m_spectatingMode == SPECMODE_LOCKEDCHASE ) {
		ncClient b;

	#ifdef CLIENT
		b = (ncClient)findfloat(world, ::entnum, m_spectatingEntity);
	#else
		b = (ncClient)edict_num(m_spectatingEntity);
	#endif

		if (m_spectatingMode != SPECMODE_DEATHCAM
			&& (!b || !IsValidChaseTarget(b))) {
			b = 0;
#ifdef SERVER
			/* server is authoritative — drop invalid chase targets */
			m_spectatingEntity = 0;
			m_spectatingMode = SPECMODE_FREE;
#endif
		}

		/* if the ent is dead... or not available in this current frame
		   just warp to the last 'good' one */
		if (b) {
			setorigin(this, b.origin);
			spec_org = b.origin;
		} else {
			setorigin(this, spec_org);
		}
	}
}

#ifdef SERVER
void
ncSpectator::EvaluateEntity(void)
{
	/* check for which values have changed in this frame
	   and announce to network said changes */
	EVALUATE_FIELD(origin, SPECFL_ORIGIN)
	EVALUATE_FIELD(velocity, SPECFL_VELOCITY)
	EVALUATE_FIELD(m_spectatingEntity, SPECFL_TARGET)
	EVALUATE_FIELD(m_spectatingMode, SPECFL_MODE)
	EVALUATE_FIELD(m_spectatingFlags, SPECFL_FLAGS)
	EVALUATE_FIELD(movetype, SPECFL_TYPE)
	EVALUATE_FIELD(solid, SPECFL_TYPE)
}

void
ncSpectator::SpectatorDeathcam(ncRenderableEntity ourCorpse, ncEntity trackEntity, float waitTime)
{
	m_spectatingEntity = num_for_edict(ourCorpse);
	m_spectatingMode = SPECMODE_DEATHCAM;
	m_flDeathCam = time + waitTime;
}
#endif

void
ncSpectator::PostFrame(void)
{
#ifdef CLIENT
	ROLL_BACK(origin)
	ROLL_BACK(velocity)
	ROLL_BACK(m_spectatingEntity)
	ROLL_BACK(m_spectatingMode)
	ROLL_BACK(m_spectatingFlags)
#endif
}

#ifdef CLIENT
void
Spectator_ReadEntity(float new)
{
	ncSpectator spec = (ncSpectator)self;

	if (new || self.classname != "spectator") {
		spawnfunc_ncSpectator();
		spec.classname = "spectator";
		spec.solid = SOLID_NOT;
		spec.drawmask = MASK_ENGINE;
		spec.customphysics = Empty;
		setsize(spec, [0,0,0], [0,0,0]);
	}

	float flags = readfloat();
	spec.ReceiveEntity(new, flags);
}
#endif
