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

/** info_player_teamspawn: a spawn point for one team ("TeamNum" 2 = RED,
3 = BLU, 0 = either). Maps can toggle them with Enable/Disable, as TF2 maps
do when the front line moves.

Nuclide picks spawn points by classname, so the entity renames itself to
info_player_team1, info_player_team2 or info_player_deathmatch, and to
info_player_teamspawn_off while disabled. */
class
tfTeamSpawn:ncSpawnPoint
{
public:
	void tfTeamSpawn(void);

	virtual void SpawnKey(string, string);
	virtual void Respawn(void);
	virtual void Input(entity, string, string);

	nonvirtual void _UpdateClassname(void);

private:
	float m_spawnTeam;
	bool m_startDisabled;
	bool m_disabled;
};

void
tfTeamSpawn::tfTeamSpawn(void)
{
	m_spawnTeam = TF_TEAM_NONE;
	m_startDisabled = false;
	m_disabled = false;
}

void
tfTeamSpawn::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "TeamNum":
		m_spawnTeam = TF_TeamFromMapKey(ReadFloat(setValue));
		break;
	case "team":
		m_spawnTeam = ReadFloat(setValue);
		break;
	case "StartDisabled":
		m_startDisabled = ReadBool(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfTeamSpawn::Respawn(void)
{
	super::Respawn();
	m_disabled = m_startDisabled;
	_UpdateClassname();
}

void
tfTeamSpawn::_UpdateClassname(void)
{
	if (m_disabled) {
		classname = "info_player_teamspawn_off";
	} else if (m_spawnTeam == TF_TEAM_RED) {
		classname = "info_player_team1";
	} else if (m_spawnTeam == TF_TEAM_BLU) {
		classname = "info_player_team2";
	} else {
		classname = "info_player_deathmatch";
	}
}

void
tfTeamSpawn::Input(entity activatorEnt, string inputName, string dataField)
{
	switch (inputName) {
	case "Enable":
		m_disabled = false;
		_UpdateClassname();
		break;
	case "Disable":
		m_disabled = true;
		_UpdateClassname();
		break;
	case "SetTeam":
		m_spawnTeam = TF_TeamFromMapKey(stof(dataField));
		_UpdateClassname();
		break;
	default:
		super::Input(activatorEnt, inputName, dataField);
	}
}

/** func_respawnroom: while inside their own team's respawn room, players can
change class instantly instead of on their next life. */
class
tfRespawnRoom:tfVolume
{
public:
	void tfRespawnRoom(void);
	virtual void PlayerInside(ncPlayer);
};

void
tfRespawnRoom::tfRespawnRoom(void)
{
}

void
tfRespawnRoom::PlayerInside(ncPlayer insidePlayer)
{
	if (m_volumeTeam == TF_TEAM_NONE || insidePlayer.team == m_volumeTeam) {
		insidePlayer.tf_inRespawnRoom = time;
	}
}

/** func_regenerate: a resupply cabinet. Players of its team ("TeamNum")
standing in it get full health, armour and ammo, at most once every
"tf_cooldown" seconds (default 3). */
class
tfRegenerate:tfVolume
{
public:
	void tfRegenerate(void);
	virtual void SpawnKey(string, string);
	virtual void PlayerInside(ncPlayer);

private:
	float m_cooldown;
};

.float tf_nextResupply;

void
tfRegenerate::tfRegenerate(void)
{
	m_cooldown = 3.0f;
}

void
tfRegenerate::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "tf_cooldown":
		m_cooldown = ReadFloat(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfRegenerate::PlayerInside(ncPlayer insidePlayer)
{
	if (m_volumeTeam != TF_TEAM_NONE && insidePlayer.team != m_volumeTeam) {
		return;
	}

	if (time < insidePlayer.tf_nextResupply) {
		return;
	}

	insidePlayer.tf_nextResupply = time + m_cooldown;
	TF_Resupply(insidePlayer);
}
