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

/** A team-owned volume that polls for players instead of relying on touch.

Map brush entities (model "*N") use the brush bounds. Entities placed by an
objective overlay, which have no brush, use their "mins" and "maxs" keys
relative to "origin". Every volume reads the Team Fortress 2 "TeamNum" key
(2 = RED, 3 = BLU) and the native "team" key (1 = RED, 2 = BLU).

Subclasses implement PlayerInside(), which is called for every living player
in the volume about ten times a second, and VolumeThink() for anything else
they want to do on that tick.
*/
class
tfVolume:ncEntity
{
public:
	void tfVolume(void);

	virtual void SpawnKey(string, string);
	virtual void Respawn(void);
	virtual void PlayerInside(ncPlayer);
	virtual void VolumeThink(void);
	virtual void Input(entity, string, string);

	nonvirtual bool Contains(entity);
	nonvirtual void _PollPlayers(void);

	float m_volumeTeam;
	bool m_volumeDisabled;
	bool m_volumeStartDisabled;
	vector m_volumeMins;
	vector m_volumeMaxs;
};

void
tfVolume::tfVolume(void)
{
	m_volumeTeam = TF_TEAM_NONE;
	m_volumeDisabled = false;
	m_volumeStartDisabled = false;
	m_volumeMins = [-64, -64, 0];
	m_volumeMaxs = [64, 64, 128];
}

void
tfVolume::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "TeamNum":
		m_volumeTeam = TF_TeamFromMapKey(ReadFloat(setValue));
		break;
	case "team":
		m_volumeTeam = ReadFloat(setValue);
		break;
	case "StartDisabled":
		m_volumeStartDisabled = ReadBool(setValue);
		break;
	case "mins":
		m_volumeMins = ReadVector(setValue);
		break;
	case "maxs":
		m_volumeMaxs = ReadVector(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfVolume::Respawn(void)
{
	string brushModel = GetSpawnString("model");

	SetMovetype(MOVETYPE_NONE);
	SetSolid(SOLID_NOT);
	SetOrigin(GetSpawnVector("origin"));

	if (substring(brushModel, 0, 1) == "*") {
		SetModel(brushModel);
	} else {
		SetSize(m_volumeMins, m_volumeMaxs);
	}

	Hide();
	team = m_volumeTeam;
	m_volumeDisabled = m_volumeStartDisabled;
	ScheduleThink(_PollPlayers, 0.1f);
}

bool
tfVolume::Contains(entity testEnt)
{
	vector ourMins = absmin;
	vector ourMaxs = absmax;

	if (testEnt.absmin[0] > ourMaxs[0] || testEnt.absmax[0] < ourMins[0])
		return (false);
	if (testEnt.absmin[1] > ourMaxs[1] || testEnt.absmax[1] < ourMins[1])
		return (false);
	if (testEnt.absmin[2] > ourMaxs[2] || testEnt.absmax[2] < ourMins[2])
		return (false);

	return (true);
}

void
tfVolume::PlayerInside(ncPlayer insidePlayer)
{
}

void
tfVolume::VolumeThink(void)
{
}

void
tfVolume::_PollPlayers(void)
{
	if (m_volumeDisabled == false) {
		for (entity e = world; (e = next.Player(e));) {
			if (is.Alive(e) == false) {
				continue;
			}

			if (Contains(e) == true) {
				PlayerInside((ncPlayer)e);
			}
		}

		VolumeThink();
	}

	ScheduleThink(_PollPlayers, 0.1f);
}

void
tfVolume::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "Enable":
		m_volumeDisabled = false;
		break;
	case "Disable":
		m_volumeDisabled = true;
		break;
	case "SetTeam":
		m_volumeTeam = team = stof(dataField);
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}
