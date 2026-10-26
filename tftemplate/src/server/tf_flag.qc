/*
 * Copyright (c) 2026 sokkycakes
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

var float autocvar_tf_flag_returntime = 60.0f;

/** item_teamflag: a flag (intelligence) that the enemy team carries to one
of its func_capturezone volumes.

Keys follow Team Fortress 2's item_teamflag where they overlap:
- "TeamNum": owning team (2 = RED, 3 = BLU, 0 = neutral, anyone may take it)
- "ReturnTime": seconds a dropped flag waits before going home (default: cvar tf_flag_returntime)
- "flag_model": model to use
- "tf_returnOnTouch": 1 lets the owning team return a dropped flag by touching it

Outputs: OnPickUp, OnPickupTeam1, OnPickupTeam2, OnDrop, OnReturn, OnCapture,
OnCapTeam1, OnCapTeam2.
*/
class
tfFlag:ncRenderableEntity
{
public:
	void tfFlag(void);

	virtual void SpawnKey(string, string);
	virtual void Spawned(void);
	virtual void Respawn(void);
	virtual void Touch(entity);
	virtual void Input(entity, string, string);

	nonvirtual void PickUp(ncPlayer);
	nonvirtual void Drop(void);
	nonvirtual void ReturnHome(void);
	nonvirtual void Captured(ncPlayer);
	nonvirtual void _CarryThink(void);
	nonvirtual void _DroppedThink(void);

private:
	float m_flagTeam;
	float m_returnTime;
	float m_returnAt;
	bool m_returnOnTouch;
	string m_flagModel;
	vector m_homeOrigin;
	vector m_homeAngles;
	float m_nextPickup;

	string m_outputOnPickUp;
	string m_outputOnPickupTeam1;
	string m_outputOnPickupTeam2;
	string m_outputOnDrop;
	string m_outputOnReturn;
	string m_outputOnCapture;
	string m_outputOnCapTeam1;
	string m_outputOnCapTeam2;
};

void
tfFlag::tfFlag(void)
{
	m_flagTeam = TF_TEAM_NONE;
	m_returnTime = -1.0f;
	m_returnOnTouch = false;
	m_flagModel = "progs/w_g_key.mdl";
	m_outputOnPickUp = __NULL__;
	m_outputOnPickupTeam1 = __NULL__;
	m_outputOnPickupTeam2 = __NULL__;
	m_outputOnDrop = __NULL__;
	m_outputOnReturn = __NULL__;
	m_outputOnCapture = __NULL__;
	m_outputOnCapTeam1 = __NULL__;
	m_outputOnCapTeam2 = __NULL__;
}

void
tfFlag::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "TeamNum":
		m_flagTeam = TF_TeamFromMapKey(ReadFloat(setValue));
		break;
	case "team":
		m_flagTeam = ReadFloat(setValue);
		break;
	case "ReturnTime":
		m_returnTime = ReadFloat(setValue);
		break;
	case "flag_model":
	case "model":
		m_flagModel = ReadString(setValue);
		break;
	case "tf_returnOnTouch":
		m_returnOnTouch = ReadBool(setValue);
		break;
	case "OnPickUp":
		m_outputOnPickUp = PrepareOutput(m_outputOnPickUp, setValue);
		break;
	case "OnPickupTeam1":
		m_outputOnPickupTeam1 = PrepareOutput(m_outputOnPickupTeam1, setValue);
		break;
	case "OnPickupTeam2":
		m_outputOnPickupTeam2 = PrepareOutput(m_outputOnPickupTeam2, setValue);
		break;
	case "OnDrop":
		m_outputOnDrop = PrepareOutput(m_outputOnDrop, setValue);
		break;
	case "OnReturn":
		m_outputOnReturn = PrepareOutput(m_outputOnReturn, setValue);
		break;
	case "OnCapture":
		m_outputOnCapture = PrepareOutput(m_outputOnCapture, setValue);
		break;
	case "OnCapTeam1":
		m_outputOnCapTeam1 = PrepareOutput(m_outputOnCapTeam1, setValue);
		break;
	case "OnCapTeam2":
		m_outputOnCapTeam2 = PrepareOutput(m_outputOnCapTeam2, setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfFlag::Spawned(void)
{
	super::Spawned();

	precache.Model(m_flagModel);

	if (STRING_SET(m_outputOnPickUp))
		m_outputOnPickUp = CreateOutput(m_outputOnPickUp);
	if (STRING_SET(m_outputOnPickupTeam1))
		m_outputOnPickupTeam1 = CreateOutput(m_outputOnPickupTeam1);
	if (STRING_SET(m_outputOnPickupTeam2))
		m_outputOnPickupTeam2 = CreateOutput(m_outputOnPickupTeam2);
	if (STRING_SET(m_outputOnDrop))
		m_outputOnDrop = CreateOutput(m_outputOnDrop);
	if (STRING_SET(m_outputOnReturn))
		m_outputOnReturn = CreateOutput(m_outputOnReturn);
	if (STRING_SET(m_outputOnCapture))
		m_outputOnCapture = CreateOutput(m_outputOnCapture);
	if (STRING_SET(m_outputOnCapTeam1))
		m_outputOnCapTeam1 = CreateOutput(m_outputOnCapTeam1);
	if (STRING_SET(m_outputOnCapTeam2))
		m_outputOnCapTeam2 = CreateOutput(m_outputOnCapTeam2);
}

void
tfFlag::Respawn(void)
{
	m_homeOrigin = GetSpawnVector("origin");
	m_homeAngles = GetSpawnVector("angles");

	tf_isObjective = 1;
	tf_objective = TFOBJ_FLAG;
	team = m_flagTeam;

	/* a flag might be respawned while someone is still carrying it */
	if (tf_flagCarrier) {
		tf_flagCarrier.tf_carriedFlag = __NULL__;
	}

	tf_flagCarrier = __NULL__;
	tf_flagState = TFFLAG_HOME;

	SetModel(m_flagModel);
	SetSize([-16, -16, 0], [16, 16, 48]);
	SetOrigin(m_homeOrigin);
	SetAngles(m_homeAngles);
	SetMovetype(MOVETYPE_NONE);
	SetSolid(SOLID_TRIGGER);
	SetRenderFX(RFX_GLOWSHELL);
	SetRenderAmt(64);

	if (m_flagTeam == TF_TEAM_RED) {
		SetRenderColor([255, 32, 32]);
	} else if (m_flagTeam == TF_TEAM_BLU) {
		SetRenderColor([32, 96, 255]);
	} else {
		SetRenderColor([255, 255, 255]);
	}

	Show();
	ReleaseThink();
}

void
tfFlag::Touch(entity touchingEnt)
{
	ncPlayer touchPlayer;

	if (is.Player(touchingEnt) == false) {
		return;
	}

	if (is.Alive(touchingEnt) == false) {
		return;
	}

	if (tf_flagState == TFFLAG_CARRIED) {
		return;
	}

	touchPlayer = (ncPlayer)touchingEnt;

	/* the owners can only return it, and only when the map allows it */
	if (m_flagTeam != TF_TEAM_NONE && touchPlayer.team == m_flagTeam) {
		if (tf_flagState == TFFLAG_DROPPED && m_returnOnTouch == true) {
			ReturnHome();
		}
		return;
	}

	/* the person who just dropped it can't grab it back immediately */
	if (time < m_nextPickup) {
		return;
	}

	if (touchPlayer.tf_carriedFlag) {
		return;
	}

	if (TF_RulesAllow("TFRules_AllowFlagPickup", touchPlayer, m_flagTeam) == false) {
		return;
	}

	PickUp(touchPlayer);
}

void
tfFlag::PickUp(ncPlayer carrier)
{
	tf_flagState = TFFLAG_CARRIED;
	tf_flagCarrier = carrier;
	carrier.tf_carriedFlag = this;
	SetSolid(SOLID_NOT);
	SetMovetype(MOVETYPE_NONE);

	UseOutput(carrier, m_outputOnPickUp);

	if (carrier.team == TF_TEAM_RED) {
		UseOutput(carrier, m_outputOnPickupTeam1);
	} else if (carrier.team == TF_TEAM_BLU) {
		UseOutput(carrier, m_outputOnPickupTeam2);
	}

	TF_RulesEvent("TF_FlagPickup", carrier, ftos(m_flagTeam));
	ScheduleThink(_CarryThink, 0.0f);
}

void
tfFlag::_CarryThink(void)
{
	ncPlayer carrier = (ncPlayer)tf_flagCarrier;

	if (tf_flagState != TFFLAG_CARRIED) {
		return;
	}

	/* carrier died, left or switched teams */
	if (!carrier || is.Alive(carrier) == false || carrier.tf_carriedFlag != this || carrier.team == m_flagTeam) {
		Drop();
		return;
	}

	makevectors([0, carrier.v_angle[1], 0]);
	SetOrigin(carrier.origin + (v_forward * -12) + [0, 0, 8]);
	SetAngles([0, carrier.v_angle[1], 0]);
	ScheduleThink(_CarryThink, 0.0f);
}

void
tfFlag::Drop(void)
{
	entity oldCarrier = tf_flagCarrier;
	float returnDelay = (m_returnTime >= 0.0f) ? m_returnTime : autocvar_tf_flag_returntime;

	if (oldCarrier) {
		if (oldCarrier.tf_carriedFlag == this) {
			oldCarrier.tf_carriedFlag = __NULL__;
		}

		SetOrigin(oldCarrier.origin);
	}

	tf_flagCarrier = __NULL__;
	tf_flagState = TFFLAG_DROPPED;
	m_nextPickup = time + 1.0f;
	SetSolid(SOLID_TRIGGER);
	SetMovetype(MOVETYPE_TOSS);
	SetSize([-16, -16, 0], [16, 16, 48]);
	SetVelocity([0, 0, 200]);
	m_returnAt = time + returnDelay;

	UseOutput(oldCarrier, m_outputOnDrop);
	TF_RulesEvent("TF_FlagDropped", oldCarrier, ftos(m_flagTeam));
	ScheduleThink(_DroppedThink, 0.1f);
}

void
tfFlag::_DroppedThink(void)
{
	if (tf_flagState != TFFLAG_DROPPED) {
		return;
	}

	/* fell out of the world, or waited long enough */
	float flagContents = pointcontents(origin + [0, 0, 16]);

	if (time >= m_returnAt || flagContents == CONTENT_SOLID || flagContents == CONTENT_LAVA || flagContents == CONTENT_SKY) {
		ReturnHome();
		return;
	}

	ScheduleThink(_DroppedThink, 0.1f);
}

void
tfFlag::ReturnHome(void)
{
	Respawn();
	UseOutput(this, m_outputOnReturn);
	TF_RulesEvent("TF_FlagReturned", this, ftos(m_flagTeam));
}

void
tfFlag::Captured(ncPlayer capturer)
{
	UseOutput(capturer, m_outputOnCapture);

	if (capturer.team == TF_TEAM_RED) {
		UseOutput(capturer, m_outputOnCapTeam1);
	} else if (capturer.team == TF_TEAM_BLU) {
		UseOutput(capturer, m_outputOnCapTeam2);
	}

	capturer.tf_carriedFlag = __NULL__;
	tf_flagCarrier = __NULL__;
	Respawn();
	TF_RulesEvent("TF_FlagCaptured", capturer, ftos(m_flagTeam));
}

void
tfFlag::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "ForceDrop":
		if (tf_flagState == TFFLAG_CARRIED)
			Drop();
		break;
	case "ForceReset":
		ReturnHome();
		break;
	case "SetTeam":
		m_flagTeam = stof(dataField);
		Respawn();
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}

/** func_capturezone: the team that owns it ("TeamNum") scores here by
bringing in any flag that isn't theirs. Brush entity, or "mins"/"maxs" when
placed by an objective overlay. Outputs: OnCapture, OnCapTeam1, OnCapTeam2.
*/
class
tfCaptureZone:tfVolume
{
public:
	void tfCaptureZone(void);

	virtual void SpawnKey(string, string);
	virtual void Spawned(void);
	virtual void Respawn(void);
	virtual void PlayerInside(ncPlayer);

private:
	string m_outputOnCapture;
	string m_outputOnCapTeam1;
	string m_outputOnCapTeam2;
};

void
tfCaptureZone::tfCaptureZone(void)
{
	m_outputOnCapture = __NULL__;
	m_outputOnCapTeam1 = __NULL__;
	m_outputOnCapTeam2 = __NULL__;
}

void
tfCaptureZone::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "OnCapture":
		m_outputOnCapture = PrepareOutput(m_outputOnCapture, setValue);
		break;
	case "OnCapTeam1":
		m_outputOnCapTeam1 = PrepareOutput(m_outputOnCapTeam1, setValue);
		break;
	case "OnCapTeam2":
		m_outputOnCapTeam2 = PrepareOutput(m_outputOnCapTeam2, setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfCaptureZone::Spawned(void)
{
	super::Spawned();

	if (STRING_SET(m_outputOnCapture))
		m_outputOnCapture = CreateOutput(m_outputOnCapture);
	if (STRING_SET(m_outputOnCapTeam1))
		m_outputOnCapTeam1 = CreateOutput(m_outputOnCapTeam1);
	if (STRING_SET(m_outputOnCapTeam2))
		m_outputOnCapTeam2 = CreateOutput(m_outputOnCapTeam2);
}

void
tfCaptureZone::Respawn(void)
{
	super::Respawn();
	tf_isObjective = 1;
	tf_objective = TFOBJ_CAPZONE;
}

void
tfCaptureZone::PlayerInside(ncPlayer insidePlayer)
{
	tfFlag carriedFlag = (tfFlag)insidePlayer.tf_carriedFlag;

	if (!carriedFlag) {
		return;
	}

	/* zones belonging to a team only accept that team's carriers */
	if (m_volumeTeam != TF_TEAM_NONE && insidePlayer.team != m_volumeTeam) {
		return;
	}

	/* rules can veto, e.g. when your own flag must be at home first */
	if (TF_RulesAllow("TFRules_AllowFlagCapture", insidePlayer, carriedFlag.team) == false) {
		return;
	}

	UseOutput(insidePlayer, m_outputOnCapture);

	if (insidePlayer.team == TF_TEAM_RED) {
		UseOutput(insidePlayer, m_outputOnCapTeam1);
	} else if (insidePlayer.team == TF_TEAM_BLU) {
		UseOutput(insidePlayer, m_outputOnCapTeam2);
	}

	carriedFlag.Captured(insidePlayer);
}
