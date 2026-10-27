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


/** @file tf_buildings.qc
The Engineer's buildings: sentry gun, dispenser and teleporters. Each one is
an entityDef in decls/def/tf_buildings.def, placed by the Construction PDA
(tfBuildPDA in tf_weapons.qc) and looked after with the wrench.

Def keys every building reads:
- "tf_buildingType": sentry, dispenser, tele_entrance or tele_exit
- "tf_cost": metal to build
- "tf_buildTime": seconds to construct (wrench hits speed it up)
- "tf_health": max health at levels 1, 2 and 3, like "150 180 216"
- "tf_upgradeCost": metal a level takes, paid 25 per wrench hit (0: can't upgrade)

Buildings blow up when their Engineer leaves, changes class or picks them
up with the PDA's reload key. A Spy's sapper (tfSapper) disables a building
and damages it until a wrench knocks it off. */

var float autocvar_tf_sapper_dps = 25;

class
tfBuilding:ncSurfacePropEntity
{
public:
	void tfBuilding(void);

	virtual void SpawnKey(string, string);
	virtual void Damage(entity, entity, ncDict, float, vector, vector);

	/** Puts the building down for an Engineer and starts building it. */
	nonvirtual void PlaceFor(entity, vector, float);
	/** A wrench hit from its own team: removes a sapper, repairs, refills
	and upgrades, paid for with the Engineer's metal. True if it did
	anything. */
	virtual bool WrenchHit(entity, float);
	nonvirtual void Explode(entity);
	nonvirtual void AttachSapper(entity);
	nonvirtual bool IsWorking(void);
	nonvirtual string BuildingType(void);
	nonvirtual float LevelHealth(float);

	/** Called every 0.1 seconds while built and not sapped. */
	virtual void BuildingThink(void);
	virtual void LevelChanged(void);

	nonvirtual void _Think(void);

	string m_tfType;
	float m_tfConstructing;
	float m_tfBuildTime;
	float m_tfBuildProgress;
	float m_tfUpgradeCost;
	float m_tfUpgradeProgress;
	string m_tfLevelHealth;
	entity m_tfSapper;
	float m_tfNextSapperTick;
};

void
tfBuilding::tfBuilding(void)
{
	tf_isBuilding = 1.0f;
	tf_buildingLevel = 1.0f;
	m_tfLevelHealth = "150 180 216";
	m_tfBuildTime = 10.0f;
	m_tfUpgradeCost = 200.0f;
}

void
tfBuilding::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "tf_buildingType":
		m_tfType = ReadString(setValue);
		break;
	case "tf_buildTime":
		m_tfBuildTime = ReadFloat(setValue);
		break;
	case "tf_upgradeCost":
		m_tfUpgradeCost = ReadFloat(setValue);
		break;
	case "tf_health":
		m_tfLevelHealth = ReadString(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

string
tfBuilding::BuildingType(void)
{
	return (m_tfType);
}

float
tfBuilding::LevelHealth(float buildingLevel)
{
	int levelCount = tokenize_console(m_tfLevelHealth);
	int levelIndex = (int)bound(0, buildingLevel - 1, levelCount - 1);
	return stof(argv(levelIndex));
}

void
tfBuilding::PlaceFor(entity engineerEnt, vector placeOrigin, float placeYaw)
{
	tf_builder = engineerEnt;
	team = engineerEnt.team;
	SetOrigin(placeOrigin);
	SetAngles([0, placeYaw, 0]);
	SetSolid(SOLID_BBOX);
	SetMovetype(MOVETYPE_TOSS);
	SetSize(GetSpawnVector("mins"), GetSpawnVector("maxs"));
	MakeVulnerable();
	tf_buildingLevel = 1.0f;
	SetMaxHealth(LevelHealth(1));
	SetHealth(1);
	m_tfConstructing = 1.0f;
	m_tfBuildProgress = 0.0f;
	m_tfUpgradeProgress = 0.0f;

	SetRenderFX(RFX_GLOWSHELL);
	SetRenderAmt(48);
	SetRenderColor((team == TF_TEAM_RED) ? [255, 32, 32] : [32, 96, 255]);

	SetThink(_Think);
	SetNextThink(0.1f);
	StartSoundDef("weapon.pickup", CHAN_BODY, true);
	LevelChanged();
}

bool
tfBuilding::IsWorking(void)
{
	if (m_tfConstructing || tf_sapped) {
		return (false);
	}

	return (true);
}

void
tfBuilding::AttachSapper(entity spyEnt)
{
	if (tf_sapped) {
		return;
	}

	tf_sapped = 1.0f;
	m_tfSapper = spyEnt;
	m_tfNextSapperTick = time;
	SetRenderFX(RFX_FASTSTROBE);
}

void
tfBuilding::Explode(entity attackerEnt)
{
	pointparticles(particleeffectnum("fx_explosion.main"), WorldSpaceCenter(), [0, 0, 1], 1);
	StartSoundDef("weapon_rocketlauncher.explode", CHAN_BODY, true);

	if (is.Player(tf_builder) && attackerEnt != tf_builder) {
		sprint(tf_builder, PRINT_HIGH, sprintf("Your %s was destroyed.\n", GetSpawnString("inv_name")));
	}

	tf_isBuilding = 0.0f;
	Destroy();
}

void
tfBuilding::Damage(entity inflictor, entity attacker, ncDict damageDecl, float damageScale, vector dmgDir, vector hitLocation)
{
	/* the builder's team can't hurt it, and the builder only by picking it up */
	if (attacker.team == team && attacker != world) {
		return;
	}

	float damagePoints = rint(stof(ReadString(damageDecl.GetString("damage"))) * damageScale);

	if (damagePoints <= 0) {
		return;
	}

	SetHealth(GetHealth() - damagePoints);

	if (GetHealth() <= 0) {
		Explode(attacker);
	}
}

bool
tfBuilding::WrenchHit(entity engineerEnt, float metalPerHit)
{
	ncPlayer engineerPlayer = (ncPlayer)engineerEnt;
	int metalType = ammoNumForName("ammo_tf_metal");
	bool didWork = false;

	/* knocking a sapper off takes the whole hit */
	if (tf_sapped) {
		tf_sapped = 0.0f;
		m_tfSapper = __NULL__;
		SetRenderFX(RFX_GLOWSHELL);
		return (true);
	}

	/* hitting a building under construction speeds it up */
	if (m_tfConstructing) {
		m_tfBuildProgress += 1.5f;
		return (true);
	}

	/* repairs: 3 health per metal, up to 102 health a hit */
	float missingHealth = GetMaxHealth() - GetHealth();

	if (missingHealth > 0) {
		float repairMetal = min(ceil(min(missingHealth, 102) / 3), engineerPlayer.GetReserveAmmo(metalType));

		if (repairMetal > 0) {
			engineerPlayer.UseAmmo(metalType, (int)repairMetal);
			SetHealth(min(GetHealth() + (repairMetal * 3), GetMaxHealth()));
			didWork = true;
		}
	}

	/* upgrades, paid a hit at a time */
	if (m_tfUpgradeCost > 0 && tf_buildingLevel < 3 && engineerPlayer.GetReserveAmmo(metalType) > 0) {
		float upgradeMetal = min(metalPerHit, engineerPlayer.GetReserveAmmo(metalType));
		upgradeMetal = min(upgradeMetal, m_tfUpgradeCost - m_tfUpgradeProgress);
		engineerPlayer.UseAmmo(metalType, (int)upgradeMetal);
		m_tfUpgradeProgress += upgradeMetal;
		didWork = true;

		if (m_tfUpgradeProgress >= m_tfUpgradeCost) {
			m_tfUpgradeProgress = 0.0f;
			tf_buildingLevel += 1.0f;
			SetMaxHealth(LevelHealth(tf_buildingLevel));
			SetHealth(GetMaxHealth());
			StartSoundDef("item_artifact_super_damage.pickup", CHAN_BODY, true);
			LevelChanged();
		}
	}

	return (didWork);
}

void
tfBuilding::LevelChanged(void)
{
}

void
tfBuilding::BuildingThink(void)
{
}

void
tfBuilding::_Think(void)
{
	SetNextThink(0.1f);

	/* the Engineer left, died out of the class, or changed class */
	if (!tf_builder || wasfreed(tf_builder) || !(tf_builder.flags & FL_CLIENT) || tf_builder.team != team || tf_builder.tf_classIndex != 6) {
		Explode(world);
		return;
	}

	if (m_tfConstructing) {
		m_tfBuildProgress += 0.1f;
		float buildFrac = min(m_tfBuildProgress / m_tfBuildTime, 1.0f);
		SetHealth(max(GetHealth(), rint(GetMaxHealth() * buildFrac)));

		if (buildFrac >= 1.0f) {
			m_tfConstructing = 0.0f;
			StartSoundDef("item.respawn", CHAN_BODY, true);
		}
		return;
	}

	if (tf_sapped) {
		if (time >= m_tfNextSapperTick) {
			m_tfNextSapperTick = time + 0.5f;
			ncDict sapperDecl = spawn(ncDict);
			sapperDecl.AddKey("damage", ftos(autocvar_tf_sapper_dps * 0.5f));
			sapperDecl.AddKey("weapon", "tf_weapon_builder");
			Damage(m_tfSapper, m_tfSapper, sapperDecl, 1.0f, g_vec_null, origin);
			remove(sapperDecl);
		}
		return;
	}

	BuildingThink();
}

/** Every building an Engineer owns of one type (or any type for ""). */
entity
TF_BuildingOf(entity engineerEnt, string buildingType)
{
	for (entity e = world; (e = findfloat(e, ::tf_isBuilding, 1));) {
		if (e.tf_builder == engineerEnt) {
			tfBuilding theBuilding = (tfBuilding)e;

			if (buildingType == "" || theBuilding.BuildingType() == buildingType) {
				return (e);
			}
		}
	}

	return (__NULL__);
}

/* ---- sentry gun --------------------------------------------------------- */

/** Extra keys: "tf_range", "tf_damage", "tf_fireRate" (per level, like
"0.25 0.125 0.125"), "tf_shells" (max shells per level), "tf_rockets",
"tf_rocketDef" and "tf_rocketRate" (level 3 rockets). */
class
tfSentryGun:tfBuilding
{
public:
	void tfSentryGun(void);

	virtual void SpawnKey(string, string);
	virtual void BuildingThink(void);
	virtual void LevelChanged(void);
	virtual bool WrenchHit(entity, float);

	nonvirtual bool CanTarget(entity);
	nonvirtual entity FindTarget(void);
	nonvirtual float LevelValue(string);

	float m_tfRange;
	float m_tfDamage;
	string m_tfFireRates;
	string m_tfMaxShells;
	float m_tfMaxRockets;
	string m_tfRocketDef;
	float m_tfRocketRate;
	float m_tfShells;
	float m_tfRockets;
	entity m_tfTarget;
	float m_tfNextShot;
	float m_tfNextRocket;
	float m_tfNextSearch;
};

void
tfSentryGun::tfSentryGun(void)
{
	m_tfRange = 1100.0f;
	m_tfDamage = 16.0f;
	m_tfFireRates = "0.25 0.125 0.125";
	m_tfMaxShells = "150 200 200";
	m_tfMaxRockets = 20.0f;
	m_tfRocketRate = 3.0f;
}

void
tfSentryGun::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "tf_range":
		m_tfRange = ReadFloat(setValue);
		break;
	case "tf_damage":
		m_tfDamage = ReadFloat(setValue);
		break;
	case "tf_fireRate":
		m_tfFireRates = ReadString(setValue);
		break;
	case "tf_shells":
		m_tfMaxShells = ReadString(setValue);
		break;
	case "tf_rockets":
		m_tfMaxRockets = ReadFloat(setValue);
		break;
	case "tf_rocketDef":
		m_tfRocketDef = ReadString(setValue);
		break;
	case "tf_rocketRate":
		m_tfRocketRate = ReadFloat(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

float
tfSentryGun::LevelValue(string levelValues)
{
	int levelCount = tokenize_console(levelValues);
	return stof(argv((int)bound(0, tf_buildingLevel - 1, levelCount - 1)));
}

void
tfSentryGun::LevelChanged(void)
{
	m_tfShells = LevelValue(m_tfMaxShells);

	if (tf_buildingLevel >= 3) {
		m_tfRockets = m_tfMaxRockets;
	}
}

bool
tfSentryGun::WrenchHit(entity engineerEnt, float metalPerHit)
{
	ncPlayer engineerPlayer = (ncPlayer)engineerEnt;
	int metalType = ammoNumForName("ammo_tf_metal");
	bool didWork = false;

	/* refill: a metal per shell, two per rocket, 40 shells a hit */
	if (tf_sapped == 0 && m_tfConstructing == 0) {
		float shellsWanted = min(LevelValue(m_tfMaxShells) - m_tfShells, 40);
		float shellMetal = min(shellsWanted, engineerPlayer.GetReserveAmmo(metalType));

		if (shellMetal > 0) {
			engineerPlayer.UseAmmo(metalType, (int)shellMetal);
			m_tfShells += shellMetal;
			didWork = true;
		}

		if (tf_buildingLevel >= 3) {
			float rocketsWanted = min(m_tfMaxRockets - m_tfRockets, 8);
			float rocketsAfforded = min(rocketsWanted, floor(engineerPlayer.GetReserveAmmo(metalType) / 2));

			if (rocketsAfforded > 0) {
				engineerPlayer.UseAmmo(metalType, (int)(rocketsAfforded * 2));
				m_tfRockets += rocketsAfforded;
				didWork = true;
			}
		}
	}

	if (super::WrenchHit(engineerEnt, metalPerHit)) {
		didWork = true;
	}

	return (didWork);
}

bool
tfSentryGun::CanTarget(entity targetEnt)
{
	if (!targetEnt || wasfreed(targetEnt)) {
		return (false);
	}

	if (is.Alive(targetEnt) == false || targetEnt.team == team || targetEnt.team == 0) {
		return (false);
	}

	/* cloaked Spies, and Spies disguised as our team, slip past */
	if (targetEnt.tf_cloaked || targetEnt.tf_disguiseTeam == team) {
		return (false);
	}

	vector eyePos = origin + [0, 0, maxs[2] * 0.75];
	vector targetPos = targetEnt.origin + [0, 0, 8];

	if (vlen(targetPos - eyePos) > m_tfRange) {
		return (false);
	}

	traceline(eyePos, targetPos, MOVE_NOMONSTERS, this);
	return (trace_fraction >= 1.0f) ? true : false;
}

entity
tfSentryGun::FindTarget(void)
{
	entity bestTarget = __NULL__;
	float bestDistance = m_tfRange + 1;

	for (entity e = world; (e = next.Player(e));) {
		if (CanTarget(e)) {
			float targetDistance = vlen(e.origin - origin);

			if (targetDistance < bestDistance) {
				bestDistance = targetDistance;
				bestTarget = e;
			}
		}
	}

	return (bestTarget);
}

void
tfSentryGun::BuildingThink(void)
{
	if (CanTarget(m_tfTarget) == false) {
		m_tfTarget = __NULL__;

		if (time >= m_tfNextSearch) {
			m_tfNextSearch = time + 0.2f;
			m_tfTarget = FindTarget();

			if (m_tfTarget) {
				StartSoundDef("item_artifact_super_damage.attack", CHAN_VOICE, true);
			}
		}
	}

	/* idle sweep */
	if (!m_tfTarget) {
		angles[1] += 4;
		return;
	}

	vector eyePos = origin + [0, 0, maxs[2] * 0.75];
	vector aimDir = normalize((m_tfTarget.origin + [0, 0, 8]) - eyePos);
	vector aimAngles = vectoangles(aimDir);
	angles[1] = aimAngles[1];

	if (time >= m_tfNextShot && m_tfShells > 0) {
		m_tfNextShot = time + LevelValue(m_tfFireRates);
		m_tfShells -= 1;
		TF_HitscanTrace(eyePos, eyePos + (aimDir * m_tfRange), this);
		trailparticles(particleeffectnum("tf_weapons.tracer"), this, eyePos, trace_endpos);
		StartSoundDef("weapon_nailgun.shoot", CHAN_WEAPON, true);

		if (trace_ent && trace_ent.takedamage != DAMAGE_NO) {
			ncSurfacePropEntity hitEnt = (ncSurfacePropEntity)trace_ent;
			ncDict shotDecl = spawn(ncDict);
			shotDecl.AddKey("damage", ftos(m_tfDamage));
			shotDecl.AddKey("weapon", "tf_building_sentry");
			hitEnt.Damage(this, tf_builder, shotDecl, 1.0f, aimDir, trace_endpos);
			remove(shotDecl);
		}
	}

	/* level 3 rockets */
	if (tf_buildingLevel >= 3 && STRING_SET(m_tfRocketDef) && m_tfRockets > 0 && time >= m_tfNextRocket) {
		m_tfNextRocket = time + m_tfRocketRate;
		m_tfRockets -= 1;
		ncProjectile_SpawnDefAtPosition(m_tfRocketDef, (ncActor)tf_builder, eyePos + (aimDir * 24), aimAngles);
	}
}

/* ---- dispenser ---------------------------------------------------------- */

/** Extra keys: "tf_range", "tf_heal" (health per second per level, like
"10 15 20"), "tf_ammo" (share of each ammo maximum per second per level),
"tf_metal" (metal per second per level, for Engineers). */
class
tfDispenser:tfBuilding
{
public:
	void tfDispenser(void);

	virtual void SpawnKey(string, string);
	virtual void BuildingThink(void);

	nonvirtual float LevelValue(string);

	float m_tfRange;
	string m_tfHeal;
	string m_tfAmmo;
	string m_tfMetal;
	float m_tfNextGive;
};

void
tfDispenser::tfDispenser(void)
{
	m_tfRange = 96.0f;
	m_tfHeal = "10 15 20";
	m_tfAmmo = "0.2 0.3 0.4";
	m_tfMetal = "8 10 12";
}

void
tfDispenser::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "tf_range":
		m_tfRange = ReadFloat(setValue);
		break;
	case "tf_heal":
		m_tfHeal = ReadString(setValue);
		break;
	case "tf_ammo":
		m_tfAmmo = ReadString(setValue);
		break;
	case "tf_metal":
		m_tfMetal = ReadString(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

float
tfDispenser::LevelValue(string levelValues)
{
	int levelCount = tokenize_console(levelValues);
	return stof(argv((int)bound(0, tf_buildingLevel - 1, levelCount - 1)));
}

void
tfDispenser::BuildingThink(void)
{
	if (time < m_tfNextGive) {
		return;
	}

	m_tfNextGive = time + 1.0f;
	float healAmount = LevelValue(m_tfHeal);
	float ammoShare = LevelValue(m_tfAmmo);
	float metalAmount = LevelValue(m_tfMetal);
	int metalType = ammoNumForName("ammo_tf_metal");

	for (entity e = world; (e = next.Player(e));) {
		if (e.team != team || is.Alive(e) == false) {
			continue;
		}

		if (vlen(e.origin - origin) > m_tfRange) {
			continue;
		}

		traceline(WorldSpaceCenter(), e.origin, MOVE_NOMONSTERS, this);

		if (trace_fraction < 1.0f) {
			continue;
		}

		ncPlayer thePlayer = (ncPlayer)e;
		thePlayer.SetHealth(min(thePlayer.GetHealth() + healAmount, max(thePlayer.GetMaxHealth(), thePlayer.GetHealth())));

		for (int ammoID = 1i; ammoID < 16i; ammoID++) {
			int maxAmmo = ammo.MaxForNum(ammoID);

			if (maxAmmo <= 0i) {
				continue;
			}

			if (ammoID == metalType) {
				if (e.tf_classIndex == 6) {
					thePlayer.GiveAmmo(ammoID, (int)metalAmount);
				}
			} else {
				thePlayer.GiveAmmo(ammoID, (int)ceil(maxAmmo * ammoShare));
			}
		}
	}
}

/* ---- teleporters -------------------------------------------------------- */

/** An entrance sends teammates standing on it to the same Engineer's exit.
Extra keys: "tf_recharge" (seconds per level, like "10 5 3"). Both ends
share a level: upgrading either one upgrades the pair. */
class
tfTeleporter:tfBuilding
{
public:
	void tfTeleporter(void);

	virtual void SpawnKey(string, string);
	virtual void BuildingThink(void);
	virtual void LevelChanged(void);

	nonvirtual tfTeleporter OtherEnd(void);

	string m_tfRecharge;
	float m_tfReadyTime;
};

void
tfTeleporter::tfTeleporter(void)
{
	m_tfRecharge = "10 5 3";
}

void
tfTeleporter::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "tf_recharge":
		m_tfRecharge = ReadString(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

tfTeleporter
tfTeleporter::OtherEnd(void)
{
	string otherType = (BuildingType() == "tele_entrance") ? "tele_exit" : "tele_entrance";
	return (tfTeleporter)TF_BuildingOf(tf_builder, otherType);
}

void
tfTeleporter::LevelChanged(void)
{
	tfTeleporter otherEnd = OtherEnd();

	if (otherEnd && otherEnd.tf_buildingLevel < tf_buildingLevel) {
		otherEnd.tf_buildingLevel = tf_buildingLevel;
		otherEnd.SetMaxHealth(otherEnd.LevelHealth(tf_buildingLevel));
		otherEnd.SetHealth(otherEnd.GetMaxHealth());
	}
}

void
tfTeleporter::BuildingThink(void)
{
	if (BuildingType() != "tele_entrance" || time < m_tfReadyTime) {
		return;
	}

	tfTeleporter exitEnd = OtherEnd();

	if (!exitEnd || exitEnd.IsWorking() == false) {
		return;
	}

	for (entity e = world; (e = next.Player(e));) {
		if (e.team != team || is.Alive(e) == false) {
			continue;
		}

		vector offset = e.origin - origin;

		if (fabs(offset[0]) > 24 || fabs(offset[1]) > 24 || offset[2] < 0 || offset[2] > 48) {
			continue;
		}

		ncPlayer thePlayer = (ncPlayer)e;
		pointparticles(particleeffectnum("fx_spark.main"), e.origin, [0, 0, 1], 8);
		thePlayer.SetOrigin(exitEnd.origin + [0, 0, exitEnd.maxs[2] + 36]);
		thePlayer.SetVelocity(g_vec_null);
		thePlayer.SetAngles([0, exitEnd.angles[1], 0]);
		thePlayer.fixangle = 1;
		StartSoundDef("mayhem_teleporter.teleported", CHAN_BODY, true);
		exitEnd.StartSoundDef("mayhem_teleporter.teleported", CHAN_BODY, true);
		tokenize_console(m_tfRecharge);
		m_tfReadyTime = time + stof(argv((int)bound(0, tf_buildingLevel - 1, 2)));
		return;
	}
}
