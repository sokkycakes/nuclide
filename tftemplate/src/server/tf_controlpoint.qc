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

var float autocvar_tf_cp_decaytime = 30.0f;
var float autocvar_tf_cp_blockrate = 1.0f;

/** team_control_point: the visible point and its ownership state. The
capturing itself is done by a trigger_capture_area that names this point in
its "area_cap_point" key.

Keys follow Team Fortress 2:
- "point_index": order of the point, also shown on the HUD
- "point_printname": name shown to players
- "point_default_owner": 0 neutral, 2 RED, 3 BLU
- "point_start_locked": 1 to start locked (KOTH unlocks it from the rules)
- "team_previouspoint_2_0" .. "_2_2": points RED must own before capping this
- "team_previouspoint_3_0" .. "_3_2": the same for BLU

Inputs: SetOwner (2/3 or 0), SetLocked (0/1).
Outputs: OnOwnerChangedToTeam1, OnOwnerChangedToTeam2, OnCapTeam1,
OnCapTeam2, OnCapReset, OnUnlocked.
*/
class
tfControlPoint:ncRenderableEntity
{
public:
	void tfControlPoint(void);

	virtual void SpawnKey(string, string);
	virtual void Spawned(void);
	virtual void Respawn(void);
	virtual void Input(entity, string, string);

	nonvirtual void SetOwner(float, entity);
	nonvirtual void SetLocked(bool);
	nonvirtual bool CanBeCappedBy(float);
	nonvirtual string PrintName(void);
	nonvirtual void _UpdateLook(void);

private:
	string m_printName;
	float m_defaultOwner;
	bool m_startLocked;
	string m_previousPoints[6]; /* 0-2 for RED, 3-5 for BLU */
	string m_pointModel;

	string m_outputOnOwnerChangedToTeam1;
	string m_outputOnOwnerChangedToTeam2;
	string m_outputOnCapTeam1;
	string m_outputOnCapTeam2;
	string m_outputOnCapReset;
	string m_outputOnUnlocked;
};

void
tfControlPoint::tfControlPoint(void)
{
	m_printName = __NULL__;
	m_defaultOwner = TF_TEAM_NONE;
	m_startLocked = false;
	m_pointModel = "progs/quaddama.mdl";

	for (int i = 0; i < 6; i++) {
		m_previousPoints[i] = __NULL__;
	}

	m_outputOnOwnerChangedToTeam1 = __NULL__;
	m_outputOnOwnerChangedToTeam2 = __NULL__;
	m_outputOnCapTeam1 = __NULL__;
	m_outputOnCapTeam2 = __NULL__;
	m_outputOnCapReset = __NULL__;
	m_outputOnUnlocked = __NULL__;
}

void
tfControlPoint::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "point_index":
		tf_cpIndex = ReadFloat(setValue);
		break;
	case "point_printname":
		m_printName = ReadString(setValue);
		break;
	case "point_default_owner":
		m_defaultOwner = TF_TeamFromMapKey(ReadFloat(setValue));
		break;
	case "point_start_locked":
		m_startLocked = ReadBool(setValue);
		break;
	case "model":
		m_pointModel = ReadString(setValue);
		break;
	case "team_previouspoint_2_0":
		m_previousPoints[0] = ReadString(setValue);
		break;
	case "team_previouspoint_2_1":
		m_previousPoints[1] = ReadString(setValue);
		break;
	case "team_previouspoint_2_2":
		m_previousPoints[2] = ReadString(setValue);
		break;
	case "team_previouspoint_3_0":
		m_previousPoints[3] = ReadString(setValue);
		break;
	case "team_previouspoint_3_1":
		m_previousPoints[4] = ReadString(setValue);
		break;
	case "team_previouspoint_3_2":
		m_previousPoints[5] = ReadString(setValue);
		break;
	case "OnOwnerChangedToTeam1":
		m_outputOnOwnerChangedToTeam1 = PrepareOutput(m_outputOnOwnerChangedToTeam1, setValue);
		break;
	case "OnOwnerChangedToTeam2":
		m_outputOnOwnerChangedToTeam2 = PrepareOutput(m_outputOnOwnerChangedToTeam2, setValue);
		break;
	case "OnCapTeam1":
		m_outputOnCapTeam1 = PrepareOutput(m_outputOnCapTeam1, setValue);
		break;
	case "OnCapTeam2":
		m_outputOnCapTeam2 = PrepareOutput(m_outputOnCapTeam2, setValue);
		break;
	case "OnCapReset":
		m_outputOnCapReset = PrepareOutput(m_outputOnCapReset, setValue);
		break;
	case "OnUnlocked":
		m_outputOnUnlocked = PrepareOutput(m_outputOnUnlocked, setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfControlPoint::Spawned(void)
{
	super::Spawned();

	precache.Model(m_pointModel);

	if (STRING_SET(m_outputOnOwnerChangedToTeam1))
		m_outputOnOwnerChangedToTeam1 = CreateOutput(m_outputOnOwnerChangedToTeam1);
	if (STRING_SET(m_outputOnOwnerChangedToTeam2))
		m_outputOnOwnerChangedToTeam2 = CreateOutput(m_outputOnOwnerChangedToTeam2);
	if (STRING_SET(m_outputOnCapTeam1))
		m_outputOnCapTeam1 = CreateOutput(m_outputOnCapTeam1);
	if (STRING_SET(m_outputOnCapTeam2))
		m_outputOnCapTeam2 = CreateOutput(m_outputOnCapTeam2);
	if (STRING_SET(m_outputOnCapReset))
		m_outputOnCapReset = CreateOutput(m_outputOnCapReset);
	if (STRING_SET(m_outputOnUnlocked))
		m_outputOnUnlocked = CreateOutput(m_outputOnUnlocked);
}

void
tfControlPoint::Respawn(void)
{
	tf_isObjective = 1;
	tf_objective = TFOBJ_POINT;
	team = m_defaultOwner;
	tf_cpLocked = m_startLocked;
	tf_cpProgress = 0.0f;
	tf_cpCapTeam = TF_TEAM_NONE;
	tf_cpContested = 0;

	SetModel(m_pointModel);
	SetSize([-16, -16, 0], [16, 16, 32]);
	SetOrigin(GetSpawnVector("origin"));
	SetMovetype(MOVETYPE_NONE);
	SetSolid(SOLID_NOT);
	SetRenderFX(RFX_GLOWSHELL);
	SetRenderAmt(64);
	_UpdateLook();
	UseOutput(this, m_outputOnCapReset);
}

string
tfControlPoint::PrintName(void)
{
	if (STRING_SET(m_printName)) {
		return (m_printName);
	}

	return (sprintf("Point %d", tf_cpIndex + 1));
}

void
tfControlPoint::_UpdateLook(void)
{
	if (team == TF_TEAM_RED) {
		SetRenderColor([255, 32, 32]);
	} else if (team == TF_TEAM_BLU) {
		SetRenderColor([32, 96, 255]);
	} else {
		SetRenderColor([200, 200, 200]);
	}

	/* locked points don't glow */
	SetRenderFX(tf_cpLocked ? RFX_NORMAL : RFX_GLOWSHELL);
}

/** Whether `teamID` may capture this point right now, ignoring who stands on it. */
bool
tfControlPoint::CanBeCappedBy(float teamID)
{
	int first;

	if (teamID != TF_TEAM_RED && teamID != TF_TEAM_BLU) {
		return (false);
	}

	if (tf_cpLocked) {
		return (false);
	}

	if (team == teamID) {
		return (false);
	}

	/* the rules may lock everything, e.g. during setup */
	if (TF_RulesAllow("TFRules_AllowPointCapture", this, teamID) == false) {
		return (false);
	}

	first = (teamID == TF_TEAM_RED) ? 0 : 3;

	for (int i = first; i < first + 3; i++) {
		if (STRING_SET(m_previousPoints[i])) {
			entity prevPoint = find(world, ::targetname, m_previousPoints[i]);

			if (prevPoint && prevPoint.team != teamID) {
				return (false);
			}
		}
	}

	return (true);
}

void
tfControlPoint::SetOwner(float newOwner, entity capturer)
{
	if (team == newOwner) {
		return;
	}

	team = newOwner;
	tf_cpProgress = 0.0f;
	tf_cpCapTeam = TF_TEAM_NONE;
	_UpdateLook();

	if (newOwner == TF_TEAM_RED) {
		UseOutput(capturer, m_outputOnOwnerChangedToTeam1);
		UseOutput(capturer, m_outputOnCapTeam1);
	} else if (newOwner == TF_TEAM_BLU) {
		UseOutput(capturer, m_outputOnOwnerChangedToTeam2);
		UseOutput(capturer, m_outputOnCapTeam2);
	}

	TF_RulesEvent("TF_PointCaptured", capturer, sprintf("%d %d", tf_cpIndex, newOwner));
}

void
tfControlPoint::SetLocked(bool lockState)
{
	bool wasLocked = tf_cpLocked;
	tf_cpLocked = lockState;
	_UpdateLook();

	if (wasLocked && lockState == false) {
		UseOutput(this, m_outputOnUnlocked);
	}
}

void
tfControlPoint::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "SetOwner":
		SetOwner(TF_TeamFromMapKey(stof(dataField)), activatorEnt);
		break;
	case "SetLocked":
		SetLocked(stof(dataField) ? true : false);
		break;
	case "ShowModel":
		Show();
		break;
	case "HideModel":
		Hide();
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}

/** trigger_capture_area: the volume in which players capture the
team_control_point named by "area_cap_point".

Keys follow Team Fortress 2:
- "area_cap_point": targetname of the point
- "area_time_to_cap": seconds one player needs to capture (default 5)
- "team_cancap_2" / "team_cancap_3": whether RED / BLU may capture here (default 1)
- "team_startcap_2" / "team_startcap_3": players needed to start capturing (default 1)
- "team_numcap_2" / "team_numcap_3": most players that speed up the capture (default 3)

Capture speed follows TF2's harmonic rule: n players capture
1 + 1/2 + ... + 1/n times as fast as one, and a class's "tf_capRate" makes a
player count as more than one (Scouts count as two). Progress decays when
nobody stands on the point, and defenders on the point push it back.
Outputs: OnStartCap, OnBreakCap, OnEndCap, OnCapTeam1, OnCapTeam2.
*/
class
tfCaptureArea:tfVolume
{
public:
	void tfCaptureArea(void);

	virtual void SpawnKey(string, string);
	virtual void Spawned(void);
	virtual void Respawn(void);
	virtual void PlayerInside(ncPlayer);
	virtual void VolumeThink(void);
	virtual void Input(entity, string, string);

	nonvirtual tfControlPoint GetPoint(void);
	nonvirtual bool TeamCanCap(float);

private:
	string m_pointName;
	float m_timeToCap;
	bool m_canCap[3];
	float m_startCap[3];
	float m_numCap[3];

	/* gathered each tick */
	float m_cappers[3];
	float m_capRate[3];
	float m_capWeight[3];
	float m_lastTick;
	bool m_wasCapping;

	string m_outputOnStartCap;
	string m_outputOnBreakCap;
	string m_outputOnEndCap;
	string m_outputOnCapTeam1;
	string m_outputOnCapTeam2;
};

void
tfCaptureArea::tfCaptureArea(void)
{
	m_pointName = __NULL__;
	m_timeToCap = 5.0f;

	for (int i = 0; i < 3; i++) {
		m_canCap[i] = true;
		m_startCap[i] = 1;
		m_numCap[i] = 3;
	}

	m_outputOnStartCap = __NULL__;
	m_outputOnBreakCap = __NULL__;
	m_outputOnEndCap = __NULL__;
	m_outputOnCapTeam1 = __NULL__;
	m_outputOnCapTeam2 = __NULL__;
}

void
tfCaptureArea::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "area_cap_point":
		m_pointName = ReadString(setValue);
		break;
	case "area_time_to_cap":
		m_timeToCap = ReadFloat(setValue);
		break;
	case "team_cancap_2":
		m_canCap[TF_TEAM_RED] = ReadBool(setValue);
		break;
	case "team_cancap_3":
		m_canCap[TF_TEAM_BLU] = ReadBool(setValue);
		break;
	case "team_startcap_2":
		m_startCap[TF_TEAM_RED] = ReadFloat(setValue);
		break;
	case "team_startcap_3":
		m_startCap[TF_TEAM_BLU] = ReadFloat(setValue);
		break;
	case "team_numcap_2":
		m_numCap[TF_TEAM_RED] = ReadFloat(setValue);
		break;
	case "team_numcap_3":
		m_numCap[TF_TEAM_BLU] = ReadFloat(setValue);
		break;
	case "OnStartCap":
		m_outputOnStartCap = PrepareOutput(m_outputOnStartCap, setValue);
		break;
	case "OnBreakCap":
		m_outputOnBreakCap = PrepareOutput(m_outputOnBreakCap, setValue);
		break;
	case "OnEndCap":
		m_outputOnEndCap = PrepareOutput(m_outputOnEndCap, setValue);
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
tfCaptureArea::Spawned(void)
{
	super::Spawned();

	if (STRING_SET(m_outputOnStartCap))
		m_outputOnStartCap = CreateOutput(m_outputOnStartCap);
	if (STRING_SET(m_outputOnBreakCap))
		m_outputOnBreakCap = CreateOutput(m_outputOnBreakCap);
	if (STRING_SET(m_outputOnEndCap))
		m_outputOnEndCap = CreateOutput(m_outputOnEndCap);
	if (STRING_SET(m_outputOnCapTeam1))
		m_outputOnCapTeam1 = CreateOutput(m_outputOnCapTeam1);
	if (STRING_SET(m_outputOnCapTeam2))
		m_outputOnCapTeam2 = CreateOutput(m_outputOnCapTeam2);
}

void
tfCaptureArea::Respawn(void)
{
	super::Respawn();
	m_lastTick = time;
	m_wasCapping = false;

	/* let the point know where it can be captured, for bots and HUDs */
	tfControlPoint ourPoint = GetPoint();

	if (ourPoint) {
		ourPoint.tf_cpArea = this;
	}
}

tfControlPoint
tfCaptureArea::GetPoint(void)
{
	if (!STRING_SET(m_pointName)) {
		return (__NULL__);
	}

	return ((tfControlPoint)find(world, ::targetname, m_pointName));
}

/** Whether `teamID` may capture here at all ("team_cancap_*"). */
bool
tfCaptureArea::TeamCanCap(float teamID)
{
	if (teamID != TF_TEAM_RED && teamID != TF_TEAM_BLU) {
		return (false);
	}

	return (m_canCap[teamID]);
}

void
tfCaptureArea::PlayerInside(ncPlayer insidePlayer)
{
	float playerTeam = insidePlayer.team;
	float playerRate = insidePlayer.tf_capRate;

	if (playerTeam != TF_TEAM_RED && playerTeam != TF_TEAM_BLU) {
		return;
	}

	if (playerRate <= 0.0f) {
		playerRate = 1.0f;
	}

	m_cappers[playerTeam] += 1;

	/* harmonic speed-up: the n-th capper adds 1/n, up to team_numcap */
	for (float i = 0; i < playerRate; i++) {
		m_capWeight[playerTeam] += 1;

		if (m_capWeight[playerTeam] <= m_numCap[playerTeam]) {
			m_capRate[playerTeam] += 1.0f / m_capWeight[playerTeam];
		}
	}
}

void
tfCaptureArea::VolumeThink(void)
{
	tfControlPoint ourPoint = GetPoint();
	float frameTime = time - m_lastTick;
	float redOn = m_cappers[TF_TEAM_RED];
	float bluOn = m_cappers[TF_TEAM_BLU];
	float attackTeam = TF_TEAM_NONE;
	float attackRate = 0.0f;
	m_lastTick = time;

	if (!ourPoint) {
		goto reset;
	}

	ourPoint.tf_cpContested = 0;

	if (redOn > 0 && bluOn > 0) {
		/* both teams on the point: nothing moves */
		if (ourPoint.CanBeCappedBy(TF_TEAM_RED) || ourPoint.CanBeCappedBy(TF_TEAM_BLU)) {
			ourPoint.tf_cpContested = 1;
		}
		goto reset;
	}

	if (redOn > 0 && m_canCap[TF_TEAM_RED] && redOn >= m_startCap[TF_TEAM_RED] && ourPoint.CanBeCappedBy(TF_TEAM_RED)) {
		attackTeam = TF_TEAM_RED;
		attackRate = m_capRate[TF_TEAM_RED];
	} else if (bluOn > 0 && m_canCap[TF_TEAM_BLU] && bluOn >= m_startCap[TF_TEAM_BLU] && ourPoint.CanBeCappedBy(TF_TEAM_BLU)) {
		attackTeam = TF_TEAM_BLU;
		attackRate = m_capRate[TF_TEAM_BLU];
	}

	if (attackTeam != TF_TEAM_NONE) {
		/* someone else's partial capture has to be undone first */
		if (ourPoint.tf_cpCapTeam != attackTeam && ourPoint.tf_cpProgress > 0.0f) {
			ourPoint.tf_cpProgress -= frameTime * attackRate / m_timeToCap;

			if (ourPoint.tf_cpProgress <= 0.0f) {
				ourPoint.tf_cpProgress = 0.0f;
				ourPoint.tf_cpCapTeam = TF_TEAM_NONE;
			}
			goto reset;
		}

		if (m_wasCapping == false) {
			m_wasCapping = true;
			UseOutput(this, m_outputOnStartCap);
		}

		ourPoint.tf_cpCapTeam = attackTeam;
		ourPoint.tf_cpProgress += frameTime * attackRate / m_timeToCap;

		if (ourPoint.tf_cpProgress >= 1.0f) {
			entity capturer = __NULL__;

			for (entity e = world; (e = next.Player(e));) {
				if (e.team == attackTeam && is.Alive(e) && Contains(e)) {
					capturer = e;
					TF_RulesEvent("TF_PlayerCapped", e, ftos(ourPoint.tf_cpIndex));
				}
			}

			m_wasCapping = false;
			UseOutput(capturer, m_outputOnEndCap);

			if (attackTeam == TF_TEAM_RED) {
				UseOutput(capturer, m_outputOnCapTeam1);
			} else {
				UseOutput(capturer, m_outputOnCapTeam2);
			}

			ourPoint.SetOwner(attackTeam, capturer);
		}
		goto reset;
	}

	/* nobody capturing: defenders push it back, otherwise it decays */
	if (ourPoint.tf_cpProgress > 0.0f) {
		float defendRate = 0.0f;

		if (ourPoint.tf_cpCapTeam == TF_TEAM_RED && bluOn > 0) {
			defendRate = m_capRate[TF_TEAM_BLU] * autocvar_tf_cp_blockrate / m_timeToCap;
		} else if (ourPoint.tf_cpCapTeam == TF_TEAM_BLU && redOn > 0) {
			defendRate = m_capRate[TF_TEAM_RED] * autocvar_tf_cp_blockrate / m_timeToCap;
		} else if (autocvar_tf_cp_decaytime > 0.0f) {
			defendRate = 1.0f / autocvar_tf_cp_decaytime;
		}

		ourPoint.tf_cpProgress -= frameTime * defendRate;

		if (ourPoint.tf_cpProgress <= 0.0f) {
			ourPoint.tf_cpProgress = 0.0f;
			ourPoint.tf_cpCapTeam = TF_TEAM_NONE;
		}
	}

	if (m_wasCapping == true) {
		m_wasCapping = false;
		UseOutput(this, m_outputOnBreakCap);
	}

reset:
	m_cappers[TF_TEAM_RED] = m_cappers[TF_TEAM_BLU] = 0;
	m_capRate[TF_TEAM_RED] = m_capRate[TF_TEAM_BLU] = 0.0f;
	m_capWeight[TF_TEAM_RED] = m_capWeight[TF_TEAM_BLU] = 0.0f;
}

void
tfCaptureArea::Input(entity activatorEnt, string inputName, string dataField)
{
	tfControlPoint ourPoint;

	switch (inputName) {
	case "SetTeamCanCap":
		/* "<team> <0/1>", team in TF2 numbering */
		tokenize_console(dataField);
		m_canCap[TF_TeamFromMapKey(stof(argv(0)))] = stof(argv(1)) ? true : false;
		break;
	case "SetControlPoint":
		m_pointName = dataField;
		ourPoint = GetPoint();

		if (ourPoint)
			ourPoint.tf_cpArea = this;
		break;
	case "CaptureCurrentCP":
		ourPoint = GetPoint();

		/* map logic (a payload path_track) has no team: the point goes
		   to the one team allowed to capture here */
		float capTeam = activatorEnt.team;

		if (capTeam != TF_TEAM_RED && capTeam != TF_TEAM_BLU) {
			if (m_canCap[TF_TEAM_BLU] && !m_canCap[TF_TEAM_RED]) {
				capTeam = TF_TEAM_BLU;
			} else if (m_canCap[TF_TEAM_RED] && !m_canCap[TF_TEAM_BLU]) {
				capTeam = TF_TEAM_RED;
			}
		}

		if (ourPoint && capTeam != TF_TEAM_NONE)
			ourPoint.SetOwner(capTeam, activatorEnt);
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}
