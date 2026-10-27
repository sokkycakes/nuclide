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


/** @file tf_weapons.qc
Server-side classes for the TF2 weapons that need more than an entityDef:
stickybombs, the minigun's spin-up, the airblast, the medigun, the sniper
rifle's charge and headshots, backstabs, the wrench, the Engineer's PDA,
the sapper and the disguise kit. Everything else is a plain ncWeapon def in
decls/def/tfweapons/.

The client predicts these as plain ncWeapons from the same defs, so their
extra behaviour (charging, spin-up, healing) shows up a moment later on the
client than the basic firing animation does. Their tunables are def keys,
listed with each class. */

/** Where the holder is looking: sets trace_* for a line from their eyes. */
void
TF_EyeTrace(ncPlayer ourOwner, float traceRange)
{
	vector eyePos = ourOwner.GetEyePos();
	vector eyeDir = anglesToForward(ourOwner.GetViewAngle());
	TF_HitscanTrace(eyePos, eyePos + (eyeDir * traceRange), ourOwner);
}

/** The ammo type the weapon's def names. */
int
TF_WeaponAmmoType(ncWeapon theWeapon)
{
	return ammoNumForName(theWeapon.GetDefString("ammoType"));
}

/* ---- Demoman: Stickybomb Launcher -------------------------------------- */

/** Hold primary fire to charge a shot further (up to "tf_chargeTime"
seconds, "tf_chargePower" times the speed), let go to fire. Secondary fire
detonates every stickybomb that has been out for "tf_armTime" seconds. At
most "tf_maxStickies" are out; firing another detonates the oldest. */
class
tfStickybombLauncher:ncWeapon
{
public:
	void tfStickybombLauncher(void);

	virtual void PrimaryAttack(void);
	virtual void SecondaryAttack(void);
	virtual void Release(void);
	virtual void FiredWeaponAttack(string);
	virtual void InputFrame(void);
	virtual bool CanReload(void);

	nonvirtual float ChargeFraction(void);
	nonvirtual void FireCharged(void);

	float m_tfChargeStart;
	float m_tfPower;
};

void
tfStickybombLauncher::tfStickybombLauncher(void)
{
	m_tfChargeStart = 0.0f;
	m_tfPower = 1.0f;
}

float
tfStickybombLauncher::ChargeFraction(void)
{
	if (m_tfChargeStart <= 0.0f) {
		return (0.0f);
	}

	return bound(0.0f, (time - m_tfChargeStart) / max(GetDefFloat("tf_chargeTime"), 0.1f), 1.0f);
}

bool
tfStickybombLauncher::CanReload(void)
{
	/* an automatic reload would eat the charged shot */
	if (m_tfChargeStart > 0.0f) {
		return (false);
	}

	return super::CanReload();
}

void
tfStickybombLauncher::FireCharged(void)
{
	/* between shots: keep the charge and try next frame */
	if (CanFire() == false) {
		return;
	}

	/* mid-reload: the first attack only stops the reload */
	if (GetWeaponState() == WEAPONSTATE_RELOAD) {
		super::PrimaryAttack();
		return;
	}

	m_tfPower = 1.0f + ((GetDefFloat("tf_chargePower") - 1.0f) * ChargeFraction());
	m_tfChargeStart = 0.0f;
	super::PrimaryAttack();
	m_tfPower = 1.0f;
}

void
tfStickybombLauncher::PrimaryAttack(void)
{
	if (m_tfChargeStart <= 0.0f) {
		/* empty or not ready: let the base class reload or idle */
		if (CanFire() == false || GetClip() <= 0) {
			super::PrimaryAttack();
			return;
		}

		m_tfChargeStart = time;
		return;
	}

	if (ChargeFraction() >= 1.0f) {
		FireCharged();
	}
}

void
tfStickybombLauncher::Release(void)
{
	/* the base class clears the semi-automatic lock that CanFire checks */
	super::Release();

	if (m_tfChargeStart > 0.0f) {
		FireCharged();
	}
}

void
tfStickybombLauncher::FiredWeaponAttack(string fireInfo)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();
	string stickyDef = GetDefString("tf_stickyDef");
	float maxStickies = GetDefFloat("tf_maxStickies");

	/* the base class handles state and knockback; we launch the bomb */
	super::FiredWeaponAttack("");

	ncProjectile newSticky = spawn(ncProjectile);
	newSticky.owner = ourOwner;
	EntityDef_SwitchClass(newSticky, stickyDef);
	newSticky.SetWeaponOwner(this);
	newSticky.Launch(ourOwner.GetEyePos(), ourOwner.GetViewAngle(), 0.0f, m_tfPower, 1.0f);
	newSticky.tf_charge = time + GetDefFloat("tf_armTime");

	/* too many out: the oldest goes off */
	float stickyCount = 0;
	entity oldestSticky = __NULL__;

	for (entity e = world; (e = find(e, ::classname, stickyDef));) {
		if (e.owner == ourOwner) {
			stickyCount++;

			if (!oldestSticky || e.tf_charge < oldestSticky.tf_charge) {
				oldestSticky = e;
			}
		}
	}

	if (maxStickies > 0 && stickyCount > maxStickies && oldestSticky) {
		ncProjectile toDetonate = (ncProjectile)oldestSticky;
		toDetonate.Trigger(ourOwner, TRIG_TOGGLE);
	}
}

void
tfStickybombLauncher::SecondaryAttack(void)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();
	string stickyDef = GetDefString("tf_stickyDef");

	for (entity e = world; (e = find(e, ::classname, stickyDef));) {
		if (e.owner == ourOwner && e.tf_charge <= time) {
			ncProjectile toDetonate = (ncProjectile)e;
			toDetonate.Trigger(ourOwner, TRIG_TOGGLE);
		}
	}
}

void
tfStickybombLauncher::InputFrame(void)
{
	tfPlayer ourOwner = (tfPlayer)GetOwner();
	float stickyCount = 0;
	string stickyDef = GetDefString("tf_stickyDef");

	for (entity e = world; (e = find(e, ::classname, stickyDef));) {
		if (e.owner == ourOwner) {
			stickyCount++;
		}
	}

	ourOwner.tf_charge = ChargeFraction();

	if (m_tfChargeStart > 0.0f) {
		ourOwner.SetWeaponMeter(sprintf("STICKIES %d  CHARGE %d%%", stickyCount, rint(ChargeFraction() * 100)));
	} else {
		ourOwner.SetWeaponMeter(sprintf("STICKIES %d", stickyCount));
	}
}

/* ---- Heavy: Minigun ----------------------------------------------------- */

/** Holding either fire button spins the barrels; it only fires once they
have spun for "tf_spinUp" seconds. The slowdown while spinning is the
def's "speed_mod_firing", which the client predicts. */
class
tfMinigun:ncWeapon
{
public:
	void tfMinigun(void);

	virtual void PrimaryAttack(void);
	virtual void SecondaryAttack(void);
	virtual void InputFrame(void);

	float m_tfSpinStart;
};

void
tfMinigun::tfMinigun(void)
{
	m_tfSpinStart = 0.0f;
}

void
tfMinigun::InputFrame(void)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();
	bool wantSpin = (input_buttons & (INPUT_PRIMARY | INPUT_SECONDARY)) ? true : false;

	if (wantSpin && m_tfSpinStart <= 0.0f) {
		m_tfSpinStart = time;
		ourOwner.StartSoundDef("weapon_supernailgun.shoot", CHAN_ITEM, true);
	} else if (wantSpin == false) {
		m_tfSpinStart = 0.0f;
	}

	ourOwner.tf_charge = (m_tfSpinStart > 0.0f) ? bound(0.0f, (time - m_tfSpinStart) / GetDefFloat("tf_spinUp"), 1.0f) : 0.0f;
}

void
tfMinigun::PrimaryAttack(void)
{
	if (m_tfSpinStart <= 0.0f || (time - m_tfSpinStart) < GetDefFloat("tf_spinUp")) {
		return;
	}

	super::PrimaryAttack();
}

void
tfMinigun::SecondaryAttack(void)
{
	/* secondary only spins; with primary held as well, fire */
	if (input_buttons & INPUT_PRIMARY) {
		PrimaryAttack();
	}
}

/* ---- Pyro: Flamethrower's airblast -------------------------------------- */

/** Secondary fire: an airblast costing "tf_airblastCost" fuel every
"tf_airblastRate" seconds. Within "tf_airblastRange" it shoves enemies with
"tf_airblastForce", sends enemy projectiles back where the Pyro is
looking (they become the Pyro's), and puts out burning teammates. */
class
tfFlamethrower:ncWeapon
{
public:
	void tfFlamethrower(void);

	virtual void SecondaryAttack(void);
};

void
tfFlamethrower::tfFlamethrower(void)
{
}


void
tfFlamethrower::SecondaryAttack(void)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();
	int fuelType = TF_WeaponAmmoType(this);
	int airblastCost = (int)GetDefFloat("tf_airblastCost");
	float blastRange = GetDefFloat("tf_airblastRange");
	float blastForce = GetDefFloat("tf_airblastForce");

	if (CanFire() == false) {
		return;
	}

	if (ourOwner.HasAmmo(fuelType, airblastCost) == false) {
		return;
	}

	ourOwner.UseAmmo(fuelType, airblastCost);
	SetAttackNext(GetDefFloat("tf_airblastRate"));

	vector eyePos = ourOwner.GetEyePos();
	vector blastDir = anglesToForward(ourOwner.GetViewAngle());
	vector blastCenter = eyePos + (blastDir * (blastRange * 0.5f));

	pointparticles(particleeffectnum("tf_weapons.airblast"), eyePos + (blastDir * 48), blastDir, 1);
	ourOwner.StartSoundDef("weapon_grenadelauncher.shoot", CHAN_WEAPON, true);

	for (entity e = findradius(blastCenter, blastRange); e; e = e.chain) {
		if (e == ourOwner) {
			continue;
		}

		vector toTarget = normalize(e.origin - eyePos);

		/* a cone in front of the Pyro */
		if ((toTarget * blastDir) < 0.5f) {
			continue;
		}

		if (is.Player(e) && is.Alive(e)) {
			tfPlayer otherPlayer = (tfPlayer)e;

			if (e.team == ourOwner.team) {
				otherPlayer.Extinguish();
			} else if (otherPlayer.IsInvulnerable() == false) {
				otherPlayer.AddVelocity((blastDir * blastForce) + [0, 0, 250]);
				otherPlayer.RemoveFlags(FL_ONGROUND);
			}
		} else if (e.classname != "" && e.owner && e.owner.team != ourOwner.team && e.movetype != MOVETYPE_NONE) {
			/* reflect anything flying that belongs to the other team */
			ncProjectile flyingThing = (ncProjectile)e;

			if (e.solid == SOLID_NOT && e.movetype == MOVETYPE_NOCLIP) {
				continue;
			}

			float flySpeed = vlen(flyingThing.velocity);

			if (flySpeed <= 0.0f) {
				continue;
			}

			flyingThing.owner = ourOwner;
			flyingThing.team = ourOwner.team;
			flyingThing.velocity = blastDir * flySpeed;
			flyingThing.angles = vectoangles(blastDir);
		}
	}
}

/* ---- Medic: Medi Gun ---------------------------------------------------- */

/** Hold primary fire on a teammate within "tf_healRange" to lock on and heal
them: "tf_healRate" health a second, rising to "tf_healRateMax" when they
haven't been hurt for 10 to 15 seconds, overhealing up to "tf_overheal"
times their maximum (Nuclide caps bonus health at +100). Healing builds
Ubercharge at "tf_uberRate" percent a second; secondary fire deploys it,
making the Medic and patient invulnerable for "tf_uberTime" seconds. */
class
tfMedigun:ncWeapon
{
public:
	void tfMedigun(void);

	virtual void PrimaryAttack(void);
	virtual void SecondaryAttack(void);
	virtual void Release(void);
	virtual void InputFrame(void);

	nonvirtual bool IsValidPatient(entity, float);
	nonvirtual void Heal(void);

	bool m_tfUberDeployed;
	float m_tfLastFrame;
	float m_tfLastHeal;
	float m_tfNextBeam;
};

void
tfMedigun::tfMedigun(void)
{
	m_tfUberDeployed = false;
}

bool
tfMedigun::IsValidPatient(entity patientEnt, float maxRange)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();

	if (!patientEnt || wasfreed(patientEnt) || is.Player(patientEnt) == false || is.Alive(patientEnt) == false) {
		return (false);
	}

	if (patientEnt == ourOwner) {
		return (false);
	}

	/* teammates, and enemy Spies disguised as one */
	if (patientEnt.team != ourOwner.team && patientEnt.tf_disguiseTeam != ourOwner.team) {
		return (false);
	}

	if (vlen(patientEnt.origin - ourOwner.origin) > maxRange) {
		return (false);
	}

	traceline(ourOwner.GetEyePos(), patientEnt.origin, MOVE_NOMONSTERS, ourOwner);
	return (trace_fraction >= 1.0f) ? true : false;
}

void
tfMedigun::Heal(void)
{
	tfPlayer ourOwner = (tfPlayer)GetOwner();
	float healRange = GetDefFloat("tf_healRange");
	float healTime = bound(0.0f, time - m_tfLastHeal, 0.2f);
	m_tfLastHeal = time;

	/* keep the patient while they stay a little past the lock-on range */
	if (IsValidPatient(ourOwner.tf_healTarget, healRange * 1.2f) == false) {
		ourOwner.tf_healTarget = __NULL__;
		TF_EyeTrace(ourOwner, healRange);
		entity aimedAt = trace_ent; /* IsValidPatient traces again */

		if (IsValidPatient(aimedAt, healRange)) {
			ourOwner.tf_healTarget = aimedAt;
			ourOwner.StartSoundDef("item_health.pickup", CHAN_WEAPON, true);
		}
	}

	if (!ourOwner.tf_healTarget) {
		return;
	}

	tfPlayer patient = (tfPlayer)ourOwner.tf_healTarget;
	float sinceHurt = time - patient.m_tfLastDamaged;
	float healRate = lerp(GetDefFloat("tf_healRate"), GetDefFloat("tf_healRateMax"), bound(0.0f, (sinceHurt - 10.0f) / 5.0f, 1.0f));
	float healAmount = healRate * healTime;
	float overhealCap = min(patient.max_health * GetDefFloat("tf_overheal"), patient.max_health + 100);

	if (patient.GetHealth() < patient.max_health) {
		patient.SetHealth(min(patient.GetHealth() + healAmount, patient.max_health));
	} else if (patient.GetHealth() < overhealCap) {
		patient.AddBonusHealth(min(healAmount, overhealCap - patient.GetHealth()));
	}

	if (m_tfUberDeployed == false) {
		ourOwner.m_tfUberCharge = min(1.0f, ourOwner.m_tfUberCharge + (GetDefFloat("tf_uberRate") * 0.01f * healTime));
	}

	if (time >= m_tfNextBeam) {
		m_tfNextBeam = time + 0.1f;
		trailparticles(particleeffectnum("tf_weapons.healbeam"), ourOwner, ourOwner.GetEyePos() - [0, 0, 8], patient.origin + [0, 0, 8]);
	}
}

void
tfMedigun::PrimaryAttack(void)
{
	Heal();
}

void
tfMedigun::SecondaryAttack(void)
{
	tfPlayer ourOwner = (tfPlayer)GetOwner();

	if (m_tfUberDeployed == false && ourOwner.m_tfUberCharge >= 1.0f) {
		m_tfUberDeployed = true;
		ourOwner.StartSoundDef("item_artifact_invulnerability.pickup", CHAN_ITEM, true);
	}

	if (input_buttons & INPUT_PRIMARY) {
		Heal();
	} else {
		m_tfLastHeal = time;
	}
}

void
tfMedigun::Release(void)
{
	tfPlayer ourOwner = (tfPlayer)GetOwner();
	ourOwner.tf_healTarget = __NULL__;
	m_tfLastHeal = time;
	super::Release();
}

void
tfMedigun::InputFrame(void)
{
	tfPlayer ourOwner = (tfPlayer)GetOwner();
	float frameTime = bound(0.0f, time - m_tfLastFrame, 0.2f);
	m_tfLastFrame = time;

	if (m_tfUberDeployed) {
		ourOwner.m_tfUberCharge -= frameTime / max(GetDefFloat("tf_uberTime"), 0.1f);
		ourOwner.ApplyUber(0.25f);

		if (ourOwner.tf_healTarget) {
			tfPlayer patient = (tfPlayer)ourOwner.tf_healTarget;
			patient.ApplyUber(0.25f);
		}

		if (ourOwner.m_tfUberCharge <= 0.0f) {
			ourOwner.m_tfUberCharge = 0.0f;
			m_tfUberDeployed = false;
		}
	}

	ourOwner.tf_charge = ourOwner.m_tfUberCharge;

	if (ourOwner.tf_healTarget) {
		ourOwner.SetWeaponMeter(sprintf("UBER %d%%  HEALING %s", floor(ourOwner.m_tfUberCharge * 100), ourOwner.tf_healTarget.netname));
	} else {
		ourOwner.SetWeaponMeter(sprintf("UBER %d%%", floor(ourOwner.m_tfUberCharge * 100)));
	}
}

/* ---- Sniper: Sniper Rifle ----------------------------------------------- */

/** Secondary fire zooms (the def's "zoomFov"). Zoomed shots charge from
"tf_baseDamage" to "tf_maxDamage" over "tf_chargeTime" seconds, and a
zoomed shot to the top of a player's box is a headshot worth
"tf_headshotMult" times the damage. */
class
tfSniperRifle:ncWeapon
{
public:
	void tfSniperRifle(void);

	virtual void FiredWeaponAttack(string);
	virtual void InputFrame(void);

	nonvirtual float ChargeFraction(void);

	float m_tfZoomStart;
};

void
tfSniperRifle::tfSniperRifle(void)
{
	m_tfZoomStart = 0.0f;
}

float
tfSniperRifle::ChargeFraction(void)
{
	if (m_tfZoomStart <= 0.0f) {
		return (0.0f);
	}

	return bound(0.0f, (time - m_tfZoomStart) / max(GetDefFloat("tf_chargeTime"), 0.1f), 1.0f);
}

void
tfSniperRifle::InputFrame(void)
{
	tfPlayer ourOwner = (tfPlayer)GetOwner();
	bool isZoomed = (ourOwner.viewzoom < 1.0f) ? true : false;

	if (isZoomed && m_tfZoomStart <= 0.0f) {
		m_tfZoomStart = time;
	} else if (isZoomed == false) {
		m_tfZoomStart = 0.0f;
	}

	ourOwner.tf_charge = ChargeFraction();

	if (isZoomed) {
		ourOwner.SetWeaponMeter(sprintf("CHARGE %d%%", rint(ChargeFraction() * 100)));
	}
}

void
tfSniperRifle::FiredWeaponAttack(string fireInfo)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();
	bool isZoomed = (ourOwner.viewzoom < 1.0f) ? true : false;
	float shotDamage = lerp(GetDefFloat("tf_baseDamage"), GetDefFloat("tf_maxDamage"), isZoomed ? ChargeFraction() : 0.0f);
	vector eyePos = ourOwner.GetEyePos();
	vector shotDir = anglesToForward(ourOwner.GetViewAngle());

	super::FiredWeaponAttack("");

	TF_EyeTrace(ourOwner, 8192);
	trailparticles(particleeffectnum("tf_weapons.tracer"), ourOwner, eyePos - [0, 0, 4], trace_endpos);

	if (trace_ent && trace_ent.takedamage != DAMAGE_NO) {
		ncSurfacePropEntity hitEnt = (ncSurfacePropEntity)trace_ent;
		ncDict shotDecl = spawn(ncDict);

		if (isZoomed && is.Player(hitEnt) && trace_endpos[2] >= (hitEnt.origin[2] + hitEnt.maxs[2] - 10)) {
			shotDamage *= GetDefFloat("tf_headshotMult");
			shotDecl.AddKey("tf_headshot", "1");
			sprint(ourOwner, PRINT_HIGH, "Headshot!\n");
		}

		shotDecl.AddKey("damage", ftos(rint(shotDamage)));
		shotDecl.AddKey("weapon", classname);
		hitEnt.Damage(ourOwner, ourOwner, shotDecl, 1.0f, shotDir, trace_endpos);
		remove(shotDecl);
	} else {
		pointparticles(particleeffectnum("fx_spark.main"), trace_endpos, trace_plane_normal, 1);
	}

	/* the charge starts over after every shot */
	if (isZoomed) {
		m_tfZoomStart = time;
	}
}

/* ---- Spy: Knife --------------------------------------------------------- */

/** A melee weapon that kills outright from behind: the victim takes
"tf_backstabMult" times their current health. */
class
tfKnife:ncWeapon
{
public:
	void tfKnife(void);

	virtual void FiredWeaponAttack(string);
};

void
tfKnife::tfKnife(void)
{
}

/** True when the attacker is behind the victim and facing them, the way
TF2 decides a backstab. */
bool
TF_IsBehind(entity attackerEnt, entity victimEnt)
{
	vector toVictim = victimEnt.origin - attackerEnt.origin;
	toVictim[2] = 0;
	toVictim = normalize(toVictim);
	vector victimForward = anglesToForward([0, victimEnt.v_angle[1], 0]);
	vector attackerForward = anglesToForward([0, attackerEnt.v_angle[1], 0]);

	if ((toVictim * victimForward) <= 0.0f) {
		return (false);
	}

	return ((attackerForward * toVictim) > 0.5f) ? true : false;
}

void
tfKnife::FiredWeaponAttack(string fireInfo)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();

	TF_EyeTrace(ourOwner, 72);

	if (is.Player(trace_ent) && is.Alive(trace_ent) && trace_ent.team != ourOwner.team && TF_IsBehind(ourOwner, trace_ent)) {
		ncPlayer victim = (ncPlayer)trace_ent;
		ncDict stabDecl = spawn(ncDict);
		stabDecl.AddKey("damage", ftos(ceil(victim.GetHealth() * GetDefFloat("tf_backstabMult"))));
		stabDecl.AddKey("weapon", classname);
		stabDecl.AddKey("noArmor", "1");
		stabDecl.AddKey("tf_backstab", "1");
		super::FiredWeaponAttack("");
		victim.Damage(ourOwner, ourOwner, stabDecl, 1.0f, anglesToForward(ourOwner.GetViewAngle()), trace_endpos);
		remove(stabDecl);
		ourOwner.StartSoundDef("Weapon_Axe.Melee_Hit", CHAN_WEAPON, true);
		return;
	}

	super::FiredWeaponAttack(fireInfo);
}

/* ---- Engineer: Wrench --------------------------------------------------- */

/** A melee weapon that, on your own team's buildings, repairs, refills,
upgrades and knocks sappers off instead of doing damage, spending up to
"tf_metalPerHit" metal on upgrades per hit. */
class
tfWrench:ncWeapon
{
public:
	void tfWrench(void);

	virtual void FiredWeaponAttack(string);
};

void
tfWrench::tfWrench(void)
{
}

void
tfWrench::FiredWeaponAttack(string fireInfo)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();

	TF_EyeTrace(ourOwner, 72);

	if (trace_ent.tf_isBuilding && trace_ent.team == ourOwner.team) {
		tfBuilding hitBuilding = (tfBuilding)trace_ent;
		vector hitPos = trace_endpos;

		super::FiredWeaponAttack("");

		if (hitBuilding.WrenchHit(ourOwner, GetDefFloat("tf_metalPerHit"))) {
			pointparticles(particleeffectnum("tf_weapons.sparks"), hitPos, [0, 0, 1], 1);
			ourOwner.StartSoundDef("Weapon_Axe.Melee_HitWorld", CHAN_WEAPON, true);
		}
		return;
	}

	super::FiredWeaponAttack(fireInfo);
}

/* ---- Engineer: Construction PDA ----------------------------------------- */

/** "tf_buildings" lists the building defs it can place. Primary fire
builds the selected one in front of the Engineer (paying its "tf_cost" in
metal), secondary fire selects the next, and reload blows up the selected
one so it can be built somewhere else. One of each per Engineer. */
class
tfBuildPDA:ncWeapon
{
public:
	void tfBuildPDA(void);

	virtual void PrimaryAttack(void);
	virtual void SecondaryAttack(void);
	virtual void Reload(void);
	virtual void InputFrame(void);

	nonvirtual string SelectedDef(void);

	float m_tfSelected;
};

void
tfBuildPDA::tfBuildPDA(void)
{
	m_tfSelected = 0;
}

string
tfBuildPDA::SelectedDef(void)
{
	int buildingCount = tokenize_console(GetDefString("tf_buildings"));

	if (buildingCount <= 0) {
		return ("");
	}

	return argv((int)m_tfSelected % buildingCount);
}

void
tfBuildPDA::PrimaryAttack(void)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();

	if (CanFire() == false) {
		return;
	}

	SetAttackNext(0.5f);

	string buildingDef = SelectedDef();
	string buildingType = entityDef.GetString(buildingDef, "tf_buildingType");
	string buildingName = entityDef.GetString(buildingDef, "inv_name");
	int metalType = ammoNumForName("ammo_tf_metal");
	float buildingCost = entityDef.GetFloat(buildingDef, "tf_cost");

	if (TF_BuildingOf(ourOwner, buildingType)) {
		sprint(ourOwner, PRINT_HIGH, sprintf("You already have a %s.\n", buildingName));
		return;
	}

	if (ourOwner.GetReserveAmmo(metalType) < buildingCost) {
		sprint(ourOwner, PRINT_HIGH, sprintf("A %s needs %d metal.\n", buildingName, buildingCost));
		return;
	}

	/* find floor 64 units in front of us, with room for the building */
	vector flatForward = anglesToForward([0, ourOwner.GetViewAngle()[1], 0]);
	vector placeSpot = ourOwner.origin + (flatForward * 72);
	vector buildMins = entityDef.GetVector(buildingDef, "mins");
	vector buildMaxs = entityDef.GetVector(buildingDef, "maxs");

	traceline(placeSpot + [0, 0, 16], placeSpot - [0, 0, 96], MOVE_NOMONSTERS, ourOwner);

	if (trace_fraction >= 1.0f) {
		sprint(ourOwner, PRINT_HIGH, "Can't build there.\n");
		return;
	}

	placeSpot = trace_endpos + [0, 0, 1];
	tracebox(placeSpot, buildMins, buildMaxs, placeSpot, MOVE_NORMAL, ourOwner);

	if (trace_startsolid || trace_allsolid) {
		sprint(ourOwner, PRINT_HIGH, "Can't build there.\n");
		return;
	}

	tfBuilding newBuilding = (tfBuilding)ents.Create(buildingDef, placeSpot);

	if (!newBuilding) {
		return;
	}

	ourOwner.UseAmmo(metalType, (int)buildingCost);
	newBuilding.PlaceFor(ourOwner, placeSpot, ourOwner.GetViewAngle()[1]);
}

void
tfBuildPDA::SecondaryAttack(void)
{
	if (CanFire() == false) {
		return;
	}

	SetAttackNext(0.3f);
	m_tfSelected++;
}

void
tfBuildPDA::Reload(void)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();

	if (CanFire() == false) {
		return;
	}

	SetAttackNext(0.5f);
	string buildingType = entityDef.GetString(SelectedDef(), "tf_buildingType");
	tfBuilding theBuilding = (tfBuilding)TF_BuildingOf(ourOwner, buildingType);

	if (theBuilding) {
		theBuilding.Explode(ourOwner);
	}
}

void
tfBuildPDA::InputFrame(void)
{
	tfPlayer ourOwner = (tfPlayer)GetOwner();
	string buildingDef = SelectedDef();
	string buildingName = entityDef.GetString(buildingDef, "inv_name");
	tfBuilding theBuilding = (tfBuilding)TF_BuildingOf(ourOwner, entityDef.GetString(buildingDef, "tf_buildingType"));
	int metalType = ammoNumForName("ammo_tf_metal");

	if (theBuilding) {
		ourOwner.SetWeaponMeter(sprintf("METAL %i  %s: level %d, %d/%d health%s", ourOwner.GetReserveAmmo(metalType), buildingName,
			theBuilding.tf_buildingLevel, theBuilding.GetHealth(), theBuilding.GetMaxHealth(), theBuilding.tf_sapped ? ", SAPPED" : ""));
	} else {
		ourOwner.SetWeaponMeter(sprintf("METAL %i  BUILD %s (%d metal)", ourOwner.GetReserveAmmo(metalType), buildingName,
			entityDef.GetFloat(buildingDef, "tf_cost")));
	}
}

/* ---- Spy: Sapper -------------------------------------------------------- */

/** Primary fire on an enemy building within "tf_sapperRange" puts a sapper
on it: it stops working and takes damage until an Engineer's wrench
knocks the sapper off. */
class
tfSapper:ncWeapon
{
public:
	void tfSapper(void);

	virtual void PrimaryAttack(void);
};

void
tfSapper::tfSapper(void)
{
}

void
tfSapper::PrimaryAttack(void)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();

	if (CanFire() == false) {
		return;
	}

	SetAttackNext(0.5f);
	TF_EyeTrace(ourOwner, GetDefFloat("tf_sapperRange"));

	if (trace_ent.tf_isBuilding && trace_ent.team != ourOwner.team && trace_ent.tf_sapped == 0) {
		tfBuilding theBuilding = (tfBuilding)trace_ent;
		theBuilding.AttachSapper(ourOwner);
		ourOwner.StartSoundDef("item_artifact_super_damage.attack", CHAN_WEAPON, true);
	}
}

/* ---- Spy: Disguise Kit -------------------------------------------------- */

/** Primary fire disguises as the next class (from the tf_classes cvar) on
the other team; reload drops the disguise. Attacking with anything but the
disguise kit or sapper drops it too (see tfPlayer). */
class
tfDisguiseKit:ncWeapon
{
public:
	void tfDisguiseKit(void);

	virtual void PrimaryAttack(void);
	virtual void Reload(void);
	virtual void InputFrame(void);

	float m_tfNextClass;
};

void
tfDisguiseKit::tfDisguiseKit(void)
{
	m_tfNextClass = 0;
}

void
tfDisguiseKit::PrimaryAttack(void)
{
	tfPlayer ourOwner = (tfPlayer)GetOwner();

	if (CanFire() == false) {
		return;
	}

	SetAttackNext(0.5f);
	int classCount = tokenize_console(cvar_string("tf_classes"));

	if (classCount <= 0) {
		return;
	}

	string disguiseClass = argv((int)m_tfNextClass % classCount);
	m_tfNextClass++;
	ourOwner.Disguise(TF_EnemyTeam(ourOwner.team), disguiseClass);
	sprint(ourOwner, PRINT_HIGH, sprintf("Disguised as a %s %s.\n", TF_TeamName(TF_EnemyTeam(ourOwner.team)), entityDef.GetString(disguiseClass, "inv_name")));
}

void
tfDisguiseKit::Reload(void)
{
	tfPlayer ourOwner = (tfPlayer)GetOwner();
	ourOwner.Undisguise();
}

void
tfDisguiseKit::InputFrame(void)
{
	tfPlayer ourOwner = (tfPlayer)GetOwner();

	if (ourOwner.tf_disguiseTeam) {
		ourOwner.SetWeaponMeter(sprintf("DISGUISED: %s %s", TF_TeamName(ourOwner.tf_disguiseTeam), ourOwner.tf_disguiseClass));
	} else {
		ourOwner.SetWeaponMeter("NOT DISGUISED");
	}
}
