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

/** @file tf_triggers.qc
Activator filters and the triggers that use them, with Team Fortress 2's
semantics: triggers name a filter in "filtername", and only activators the
filter passes can touch them.
*/

.float tf_isFilter;

/** The base of the filter_activator_* entities. "Negated" 1 inverts it. */
class
tfFilter:ncEntity
{
public:
	void tfFilter(void);

	virtual void SpawnKey(string, string);
	virtual void Respawn(void);
	virtual bool Matches(entity);
	nonvirtual bool Passes(entity);

	bool m_negated;
};

void
tfFilter::tfFilter(void)
{
	m_negated = false;
}

void
tfFilter::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "Negated":
		m_negated = ReadBool(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfFilter::Respawn(void)
{
	tf_isFilter = 1;
	SetSolid(SOLID_NOT);
	SetMovetype(MOVETYPE_NONE);
}

bool
tfFilter::Matches(entity testEnt)
{
	return (true);
}

bool
tfFilter::Passes(entity testEnt)
{
	bool doesMatch = Matches(testEnt);
	return (m_negated) ? !doesMatch : doesMatch;
}

/** filter_activator_tfteam: passes players (and anything else with a team)
of "TeamNum" (2 = RED, 3 = BLU). */
class
tfFilterTeam:tfFilter
{
public:
	void tfFilterTeam(void);
	virtual void SpawnKey(string, string);
	virtual bool Matches(entity);

private:
	float m_filterTeam;
};

void
tfFilterTeam::tfFilterTeam(void)
{
	m_filterTeam = TF_TEAM_NONE;
}

void
tfFilterTeam::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "TeamNum":
		m_filterTeam = TF_TeamFromMapKey(ReadFloat(setValue));
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

bool
tfFilterTeam::Matches(entity testEnt)
{
	return (m_filterTeam == TF_TEAM_NONE || testEnt.team == m_filterTeam) ? (true) : (false);
}

/** filter_activator_name: passes the entity called "filtername". */
class
tfFilterName:tfFilter
{
public:
	void tfFilterName(void);
	virtual void SpawnKey(string, string);
	virtual bool Matches(entity);

	string m_filterName;
};

void
tfFilterName::tfFilterName(void)
{
	m_filterName = __NULL__;
}

void
tfFilterName::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "filtername":
		m_filterName = ReadString(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

bool
tfFilterName::Matches(entity testEnt)
{
	return (testEnt.targetname == m_filterName) ? (true) : (false);
}

/** filter_activator_class: passes entities of class "filterclass". In
Team Fortress 2 maps that is usually "player", which matches every
player whatever their class def. */
class
tfFilterClass:tfFilter
{
public:
	void tfFilterClass(void);
	virtual void SpawnKey(string, string);
	virtual bool Matches(entity);

private:
	string m_filterClass;
};

void
tfFilterClass::tfFilterClass(void)
{
	m_filterClass = __NULL__;
}

void
tfFilterClass::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "filterclass":
		m_filterClass = ReadString(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

bool
tfFilterClass::Matches(entity testEnt)
{
	if (m_filterClass == "player") {
		return is.Player(testEnt);
	}

	return (testEnt.classname == m_filterClass) ? (true) : (false);
}

/** Whether `testEnt` gets past the filter called `filterName`. No filter,
or one that doesn't exist, passes everything. */
bool
TF_FilterPasses(string filterName, entity testEnt)
{
	if (!STRING_SET(filterName)) {
		return (true);
	}

	for (entity f = world; (f = find(f, ::targetname, filterName));) {
		if (f.tf_isFilter) {
			tfFilter theFilter = (tfFilter)f;
			return theFilter.Passes(testEnt);
		}
	}

	return (true);
}

#define TFTRIG_MAXINSIDE 32

/** trigger_multiple and trigger_once with Team Fortress 2's outputs. They
poll for what's inside instead of relying on touch, so OnEndTouch fires
reliably and doors driven by them don't flap.

Keys: "filtername", "wait" (seconds between OnTrigger, default 0.2),
"StartDisabled", spawnflags 1 (players), 64 (everything); other flags let
non-players named by a filter_activator_name in. Quake and GoldSrc style
triggers with a "target" still fire it, for players.
Outputs: OnStartTouch, OnStartTouchAll, OnEndTouch, OnEndTouchAll,
OnTrigger. trigger_once fires OnTrigger and OnStartTouch once per round. */
class
tfTrigger:tfVolume
{
public:
	void tfTrigger(void);

	virtual void SpawnKey(string, string);
	virtual void Spawned(void);
	virtual void Respawn(void);
	virtual void VolumeThink(void);
	virtual void Input(entity, string, string);

	nonvirtual bool _Accepts(entity);
	nonvirtual void _Consider(entity);

	bool m_once;

private:
	string m_filterName;
	float m_wait;
	float m_nextTrigger;
	bool m_fired;

	int m_insideCount;
	entity m_inside[TFTRIG_MAXINSIDE];
	int m_seenCount;
	entity m_seen[TFTRIG_MAXINSIDE];

	string m_outputOnStartTouch;
	string m_outputOnStartTouchAll;
	string m_outputOnEndTouch;
	string m_outputOnEndTouchAll;
	string m_outputOnTrigger;
};

void
tfTrigger::tfTrigger(void)
{
	m_once = false;
	m_filterName = __NULL__;
	m_wait = 0.2f;
	m_outputOnStartTouch = __NULL__;
	m_outputOnStartTouchAll = __NULL__;
	m_outputOnEndTouch = __NULL__;
	m_outputOnEndTouchAll = __NULL__;
	m_outputOnTrigger = __NULL__;
}

void
tfTrigger::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "filtername":
		m_filterName = ReadString(setValue);
		break;
	case "wait":
		m_wait = ReadFloat(setValue);
		break;
	case "OnStartTouch":
		m_outputOnStartTouch = PrepareOutput(m_outputOnStartTouch, setValue);
		break;
	case "OnStartTouchAll":
		m_outputOnStartTouchAll = PrepareOutput(m_outputOnStartTouchAll, setValue);
		break;
	case "OnEndTouch":
		m_outputOnEndTouch = PrepareOutput(m_outputOnEndTouch, setValue);
		break;
	case "OnEndTouchAll":
		m_outputOnEndTouchAll = PrepareOutput(m_outputOnEndTouchAll, setValue);
		break;
	case "OnTrigger":
		m_outputOnTrigger = PrepareOutput(m_outputOnTrigger, setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfTrigger::Spawned(void)
{
	super::Spawned();

	if (STRING_SET(m_outputOnStartTouch))
		m_outputOnStartTouch = CreateOutput(m_outputOnStartTouch);
	if (STRING_SET(m_outputOnStartTouchAll))
		m_outputOnStartTouchAll = CreateOutput(m_outputOnStartTouchAll);
	if (STRING_SET(m_outputOnEndTouch))
		m_outputOnEndTouch = CreateOutput(m_outputOnEndTouch);
	if (STRING_SET(m_outputOnEndTouchAll))
		m_outputOnEndTouchAll = CreateOutput(m_outputOnEndTouchAll);
	if (STRING_SET(m_outputOnTrigger))
		m_outputOnTrigger = CreateOutput(m_outputOnTrigger);
}

void
tfTrigger::Respawn(void)
{
	super::Respawn();
	m_insideCount = 0i;
	m_nextTrigger = 0.0f;
	m_fired = false;
}

bool
tfTrigger::_Accepts(entity testEnt)
{
	if (is.Player(testEnt)) {
		/* Quake/GoldSrc triggers (with a "target") are for players */
		if (!HasSpawnFlags(1) && !HasSpawnFlags(64) && !HasTriggerTarget()) {
			return (false);
		}

		if (is.Alive(testEnt) == false) {
			return (false);
		}
	}

	return TF_FilterPasses(m_filterName, testEnt);
}

void
tfTrigger::_Consider(entity testEnt)
{
	if (m_seenCount >= TFTRIG_MAXINSIDE || Contains(testEnt) == false || _Accepts(testEnt) == false) {
		return;
	}

	for (int i = 0i; i < m_seenCount; i++) {
		if (m_seen[i] == testEnt) {
			return;
		}
	}

	m_seen[m_seenCount] = testEnt;
	m_seenCount++;
}

void
tfTrigger::VolumeThink(void)
{
	m_seenCount = 0i;

	if (m_once && m_fired) {
		return;
	}

	/* players, and the entities a name filter is waiting for */
	for (entity p = world; (p = next.Player(p));) {
		_Consider(p);
	}

	if (STRING_SET(m_filterName) && (spawnflags & ~1)) {
		for (entity f = world; (f = find(f, ::targetname, m_filterName));) {
			if (f.classname == "filter_activator_name" || f.tf_isFilter) {
				tfFilterName nameFilter = (tfFilterName)f;

				for (entity n = world; (n = find(n, ::targetname, nameFilter.m_filterName));) {
					if (!(n.effects & EF_NODRAW)) {
						_Consider(n);
					}
				}
			}
		}
	}

	bool wasEmpty = (m_insideCount == 0i) ? true : false;

	/* arrivals */
	for (int i = 0i; i < m_seenCount; i++) {
		bool wasInside = false;

		for (int j = 0i; j < m_insideCount; j++) {
			if (m_inside[j] == m_seen[i]) {
				wasInside = true;
			}
		}

		if (wasInside == false) {
			UseOutput(m_seen[i], m_outputOnStartTouch);

			if (wasEmpty) {
				UseOutput(m_seen[i], m_outputOnStartTouchAll);
				wasEmpty = false;
			}
		}

		if (time >= m_nextTrigger) {
			UseOutput(m_seen[i], m_outputOnTrigger);

			if (HasTriggerTarget()) {
				UseTargets(m_seen[i], TRIG_TOGGLE, GetTriggerDelay());
			}

			m_nextTrigger = time + max(m_wait, 0.1f);

			if (m_once) {
				m_fired = true;
			}
		}
	}

	/* departures */
	entity lastLeaving = this;

	for (int i = 0i; i < m_insideCount; i++) {
		bool stillInside = false;

		for (int j = 0i; j < m_seenCount; j++) {
			if (m_seen[j] == m_inside[i]) {
				stillInside = true;
			}
		}

		if (stillInside == false && !wasfreed(m_inside[i])) {
			lastLeaving = m_inside[i];
			UseOutput(lastLeaving, m_outputOnEndTouch);
		}
	}

	if (m_seenCount == 0i && m_insideCount > 0i) {
		UseOutput(lastLeaving, m_outputOnEndTouchAll);
	}

	for (int i = 0i; i < m_seenCount; i++) {
		m_inside[i] = m_seen[i];
	}

	m_insideCount = m_seenCount;
}

void
tfTrigger::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "Toggle":
		m_volumeDisabled = !m_volumeDisabled;
		break;
	case "Disable":
		m_volumeDisabled = true;

		/* everyone inside has left, as far as outputs go */
		if (m_insideCount > 0i) {
			UseOutput(m_inside[0], m_outputOnEndTouchAll);
		}

		m_insideCount = 0i;
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}

class
tfTriggerOnce:tfTrigger
{
public:
	void tfTriggerOnce(void);
};

void
tfTriggerOnce::tfTriggerOnce(void)
{
	m_once = true;
}

/** trigger_hurt that honours "filtername", so a payload cart's hurt brush
(filtered to non-players) doesn't kill the players pushing it. */
class
tfTriggerHurt:trigger_hurt
{
public:
	void tfTriggerHurt(void);
	virtual void SpawnKey(string, string);
	virtual void Touch(entity);

private:
	string m_filterName;
};

void
tfTriggerHurt::tfTriggerHurt(void)
{
	m_filterName = __NULL__;
}

void
tfTriggerHurt::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "filtername":
		m_filterName = ReadString(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfTriggerHurt::Touch(entity touchingEnt)
{
	if (TF_FilterPasses(m_filterName, touchingEnt) == false) {
		return;
	}

	super::Touch(touchingEnt);
}

/** trigger_catapult: launches players who enter it. With "launchTarget"
they fly to that entity: "playerSpeed" is the horizontal speed and the
upward speed is whatever lands them on it under sv_gravity. Without one
they're thrown along "launchDirection" at "playerSpeed".
Outputs: OnCatapulted. */
class
tfTriggerCatapult:tfVolume
{
public:
	void tfTriggerCatapult(void);

	virtual void SpawnKey(string, string);
	virtual void Spawned(void);
	virtual void PlayerInside(ncPlayer);

private:
	string m_targetName;
	float m_playerSpeed;
	vector m_launchDirection;
	string m_filterName;
	string m_outputOnCatapulted;
};

.float tf_nextCatapult;

void
tfTriggerCatapult::tfTriggerCatapult(void)
{
	m_targetName = __NULL__;
	m_playerSpeed = 450.0f;
	m_launchDirection = [0, 0, 0];
	m_filterName = __NULL__;
	m_outputOnCatapulted = __NULL__;
}

void
tfTriggerCatapult::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "launchTarget":
		m_targetName = ReadString(setValue);
		break;
	case "playerSpeed":
		m_playerSpeed = ReadFloat(setValue);
		break;
	case "launchDirection":
		m_launchDirection = ReadVector(setValue);
		break;
	case "filtername":
		m_filterName = ReadString(setValue);
		break;
	case "OnCatapulted":
		m_outputOnCatapulted = PrepareOutput(m_outputOnCatapulted, setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfTriggerCatapult::Spawned(void)
{
	super::Spawned();

	if (STRING_SET(m_outputOnCatapulted))
		m_outputOnCatapulted = CreateOutput(m_outputOnCatapulted);
}

void
tfTriggerCatapult::PlayerInside(ncPlayer insidePlayer)
{
	vector launchVelocity;
	entity targetEnt = STRING_SET(m_targetName) ? find(world, ::targetname, m_targetName) : world;

	if (time < insidePlayer.tf_nextCatapult || TF_FilterPasses(m_filterName, insidePlayer) == false) {
		return;
	}

	if (targetEnt) {
		vector toTarget = targetEnt.origin - insidePlayer.origin;
		vector flatDelta = [toTarget[0], toTarget[1], 0];
		float flatDistance = vlen(flatDelta);
		float gravityValue = cvars.GetFloat("sv_gravity");
		float flightTime = max(flatDistance / max(m_playerSpeed, 1.0f), 0.2f);

		if (gravityValue <= 0.0f) {
			gravityValue = 800.0f;
		}

		launchVelocity = (flatDelta * (1.0f / flightTime));
		launchVelocity[2] = (toTarget[2] / flightTime) + (0.5f * gravityValue * flightTime);
	} else {
		makevectors(m_launchDirection);
		launchVelocity = v_forward * m_playerSpeed;
	}

	insidePlayer.velocity = launchVelocity;
	insidePlayer.flags &= ~FL_ONGROUND;
	insidePlayer.tf_nextCatapult = time + 0.5f;
	UseOutput(insidePlayer, m_outputOnCatapulted);
}
