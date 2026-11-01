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

/** The player class every template class def spawns as.

All class stats live in decls/def/tf_classes.def; this only reads the
template's own keys so the rules and bots can see them:
- "tf_classIndex": 1 to 9, the slot on the class menu
- "tf_capRate": how many players this class counts as on a capture area
- "tf_regen": health regenerated per second (the Medic's trait in TF2)
- "tf_noAfterburn": 1 for classes flames don't set on fire (the Pyro)
- "tf_cloak": 1 for classes that cloak with secondary fire (the Spy)

It also carries the TF2 mechanics that aren't tied to one weapon:
- knockback that scales with damage, stronger on yourself, so rockets and
  stickies can be jumped on (cvars tf_knockback and tf_selfknockback)
- afterburn from damage with a "tf_afterburn" key (seconds)
- Ubercharge invulnerability (ApplyUber)
- the Spy's cloak and disguises
- the "*hp", "*maxhp" and "*tf_meter" userinfo keys the HUD draws

Give new class mechanics a home here (or in a subclass) rather than in the
rules, so they keep working in every game mode. */

var float autocvar_tf_knockback = 5;
var float autocvar_tf_selfknockback = 16;
var float autocvar_tf_knockback_max = 1000;
var float autocvar_tf_afterburn_damage = 4;
var float autocvar_tf_cloak_drain = 10;
var float autocvar_tf_cloak_regen = 3.3;
/** TF2's damage variance: 1 (TF2's default) always uses the middle of the
range, so falloff and ramp-up are exact; 0 adds +/-10% random spread */
var float autocvar_tf_damage_disablespread = 1;
/** how far falloff and ramp-up can move damage, as a fraction of it */
var float autocvar_tf_damage_range = 0.5;
/** seconds of death cam and freeze cam before spectating (TF2: 2 + 0.4 + 4) */
var float autocvar_tf_deathcam_time = 6.4;
/** the same when nobody else killed us: no freeze cam */
var float autocvar_tf_deathcam_time_suicide = 2.0;

#define TFCLASS_SPY 9

class
tfPlayer:ncPlayer
{
public:
	void tfPlayer(void);

	virtual void SpawnKey(string, string);
	virtual void Input(entity, string, string);
	virtual void Respawn(void);
	virtual void Damage(entity, entity, ncDict, float, vector, vector);
	virtual void Death(entity, entity, int, vector, vector, int);
	virtual void ServerInputFrame(void);

	/** Shields the player from damage for this many seconds. */
	nonvirtual void ApplyUber(float);
	nonvirtual bool IsInvulnerable(void);
	/** Sets the player on fire, like TF2's afterburn. */
	nonvirtual void TFIgnite(entity, float, string);
	nonvirtual void Extinguish(void);
	nonvirtual void SetCloaked(bool);
	/** Puts on a class's model for the player's team, when the class def
	has "model_red" and "model_blue" and the pack holding them is there. */
	nonvirtual void SetClassModel(string);
	/** Makes a Spy look like a player of another team and class. */
	nonvirtual void Disguise(float, string);
	nonvirtual void Undisguise(void);
	/** Text the HUD shows for the active weapon this frame, like "CHARGE 40%". */
	nonvirtual void SetWeaponMeter(string);

	/** The Medic's Ubercharge, 0 to 1. Kept on the player so it survives
	weapon switches. */
	float m_tfUberCharge;
	/** Time this player last took damage from someone else (the medigun heals
	faster the longer ago it was). */
	float m_tfLastDamaged;

	/** Test driving (tf_test_hold): pinned in place with buttons held until
	a time, aimed at an entity if one is set, until tf_test_release.
	Overrides the player's or bot's own input. */
	bool m_tfTestPinned;
	float m_tfTestButtons;
	float m_tfTestUntil;
	entity m_tfTestAim;
	vector m_tfTestPos;
	bool m_tfTestFixedAim;
	vector m_tfTestAngles;
	vector m_tfTestMove;

private:
	nonvirtual void TFFrame(void);
	nonvirtual void UpdateSpeedTarget(void);
	nonvirtual void StartDeathCam(entity);
	nonvirtual void StartSpectating(void);
	nonvirtual void UpdateRender(void);
	nonvirtual void PublishInfo(void);
	nonvirtual void ApplyClassModel(float, string);

	bool m_tfNoAfterburn;
	bool m_tfCanCloak;
	float m_tfCloakMeter;
	float m_tfBurnNext;
	entity m_tfBurnAttacker;
	string m_tfBurnWeapon;
	bool m_tfSecondaryWasDown;
	float m_tfLastFrame;
	float m_tfNextPublish;
	string m_tfWeaponMeter;
	float m_tfRenderState;
	float m_tfSpectateAt;
	string m_tfClassDef;
};

void
tfPlayer::tfPlayer(void)
{
	tf_capRate = 1.0f;
	tf_regenRate = 0.0f;
	tf_classIndex = 0;
	tf_charge = 0.0f;
	tf_healTarget = __NULL__;
	m_tfNoAfterburn = false;
	m_tfCanCloak = false;
	m_tfCloakMeter = 100.0f;
	m_tfRenderState = -1;
}

void
tfPlayer::SpawnKey(string keyName, string setValue)
{
	switch (keyName) {
	case "tf_classIndex":
		tf_classIndex = ReadFloat(setValue);
		break;
	case "tf_capRate":
		tf_capRate = ReadFloat(setValue);
		break;
	case "tf_regen":
		tf_regenRate = ReadFloat(setValue);
		break;
	case "tf_noAfterburn":
		m_tfNoAfterburn = ReadBool(setValue);
		break;
	case "tf_cloak":
		m_tfCanCloak = ReadBool(setValue);
		break;
	default:
		super::SpawnKey(keyName, setValue);
	}
}

void
tfPlayer::Input(entity activator, string inputName, string inputData)
{
	switch (inputName) {
	/* from the rules (TF_SpawnPlayer), which can't call tfPlayer's methods */
	case "SetClassModel":
		SetClassModel(inputData);
		break;
	default:
		super::Input(activator, inputName, inputData);
	}
}

void
tfPlayer::Respawn(void)
{
	super::Respawn();
	tf_charge = 0.0f;
	tf_healTarget = __NULL__;
	tf_lastRegenTime = time;
	tf_uberUntil = 0.0f;
	tf_burnUntil = 0.0f;
	tf_cloaked = 0.0f;
	m_tfCloakMeter = 100.0f;
	m_tfUberCharge = 0.0f;
	m_tfWeaponMeter = "";
	m_tfRenderState = -1;
	m_tfSpectateAt = 0.0f;
	Undisguise();
}

bool
tfPlayer::IsInvulnerable(void)
{
	return (tf_uberUntil > time) ? true : false;
}

void
tfPlayer::ApplyUber(float uberTime)
{
	tf_uberUntil = max(tf_uberUntil, time + uberTime);
	Extinguish();
}

void
tfPlayer::TFIgnite(entity burnAttacker, float burnTime, string weaponDef)
{
	if (m_tfNoAfterburn || IsInvulnerable() || WaterLevel() >= 2) {
		return;
	}

	/* the first tick lands half a second after catching fire, as in TF2 */
	if (tf_burnUntil <= time) {
		m_tfBurnNext = time + 0.5f;
	}

	tf_burnUntil = max(tf_burnUntil, time + burnTime);
	m_tfBurnAttacker = burnAttacker;
	m_tfBurnWeapon = weaponDef;
}

void
tfPlayer::Extinguish(void)
{
	tf_burnUntil = 0.0f;
}

/** A damage key from the damage decl, else from the def of the weapon
that dealt it (the decl's "weapon" key). */
float
TF_DamageModKey(ncDict damageDecl, string keyName)
{
	string keyValue = damageDecl.GetString(keyName);

	if (!STRING_SET(keyValue)) {
		keyValue = EntityDef_GetKeyValue(damageDecl.GetString("weapon"), keyName);
	}

	return stof(keyValue);
}

/** Range falloff and ramp-up, as TF2's ApplyOnDamageModifyRules does it.
Returns the damage with the modifier applied. Keys, on the damage decl or
the weapon def:
- "tf_distanceMod": 1 for damage that changes with range (TF2's
  DMG_USEDISTANCEMOD): 150% up close, 100% at "tf_optimalDistance" (512)
  and about 53% from 1.8 times that (922) on
- "tf_noCloseMod": 1 caps the close range bonus (DMG_NOCLOSEDISTANCEMOD)
- "tf_rampUpScale": scales only the close range bonus (rockets 0.5,
  scattergun 1.5)
- "tf_varianceScale": scales the change both ways (grenades 0.2), unless
  "tf_noCloseMod" is set
- "tf_fromInflictor": 1 measures from the inflictor (sentry guns)
Self damage is never modified. */
float
TF_DistanceDamage(entity victim, entity inflictor, entity attacker, ncDict damageDecl, float rawDamage)
{
	if (attacker == victim || rawDamage <= 0.0f) {
		return (rawDamage);
	}

	if (TF_DamageModKey(damageDecl, "tf_distanceMod") <= 0.0f) {
		return (rawDamage);
	}

	bool noCloseMod = (TF_DamageModKey(damageDecl, "tf_noCloseMod") > 0.0f) ? true : false;
	float optimalDistance = TF_DamageModKey(damageDecl, "tf_optimalDistance");
	float rampUpScale = TF_DamageModKey(damageDecl, "tf_rampUpScale");
	float varianceScale = TF_DamageModKey(damageDecl, "tf_varianceScale");
	entity measureFrom = (TF_DamageModKey(damageDecl, "tf_fromInflictor") > 0.0f && inflictor) ? inflictor : attacker;
	float randomDamage = rawDamage * autocvar_tf_damage_range;
	float randomSpread = 0.1f;

	if (optimalDistance <= 0.0f) {
		optimalDistance = 512.0f;
	}

	vector fromPos = (measureFrom.absmin + measureFrom.absmax) * 0.5f;
	vector toPos = (victim.absmin + victim.absmax) * 0.5f;
	float hitDistance = max(1.0f, vlen(toPos - fromPos));
	float rangeCenter = bound(0.0f, 1.0f - ((hitDistance / optimalDistance) * 0.5f), 1.0f);

	if (noCloseMod && rangeCenter > 0.5f) {
		rangeCenter = 0.5f + ((rangeCenter - 0.5f) * 0.3f);
	}

	/* TF2 clamps the spread's bottom at 0 and, without spread, takes
	   bottom + 0.1, so the far end bottoms out at 0.1 (about 53%), not 0 */
	float rangeMin = max(0.0f, rangeCenter - randomSpread);
	float rangeMax = min(1.0f, rangeCenter + randomSpread);
	float rangeVal = rangeMin + randomSpread;

	if (autocvar_tf_damage_disablespread == 0.0f) {
		rangeVal = random(rangeMin, rangeMax);
	}

	if (rampUpScale > 0.0f && rangeVal > 0.5f) {
		randomDamage *= rampUpScale;
	}

	if (varianceScale > 0.0f && noCloseMod == false) {
		randomDamage *= varianceScale;
	}

	/* SimpleSplineRemapValClamped(rangeVal, 0, 1, -randomDamage, randomDamage) */
	float splineVal = (3.0f * rangeVal * rangeVal) - (2.0f * rangeVal * rangeVal * rangeVal);
	return rawDamage + lerp(-randomDamage, randomDamage, splineVal);
}

void
tfPlayer::Damage(entity inflictor, entity attacker, ncDict damageDecl, float damageScale, vector dmgDir, vector hitLocation)
{
	if (is.Alive(this) == false) {
		return;
	}

	float rawDamage = stof(ReadString(damageDecl.GetString("damage"))) * damageScale;
	bool isSelf = (attacker == this) ? true : false;

	/* range falloff and ramp-up go into the decl, so armour, uber and
	   death all see the final number */
	float modDamage = TF_DistanceDamage(this, inflictor, attacker, damageDecl, rawDamage);

	if (modDamage != rawDamage && damageScale > 0.0f) {
		damageDecl.AddKey("damage", ftos(modDamage / damageScale));
		rawDamage = modDamage;
	}
	bool isFriendly = false;

	if (isSelf == false && attacker.team == team && is.Player(attacker)) {
		isFriendly = true;
	}

	if (isFriendly == false) {
		float burnTime = damageDecl.GetFloat("tf_afterburn");

		if (burnTime > 0.0f) {
			TFIgnite(attacker, burnTime, damageDecl.GetString("weapon"));
		}

		/* TF2 knockback: proportional to damage, much stronger on yourself
		   so explosives can be jumped on. invulnerable players still fly. */
		if (rawDamage > 0.0f && vlen(dmgDir) > 0.0f && damageDecl.GetFloat("tf_noKnockback") == 0.0f) {
			float pushScale = isSelf ? autocvar_tf_selfknockback : autocvar_tf_knockback;
			float pushSpeed = min(rawDamage * pushScale, autocvar_tf_knockback_max);
			vector pushDir = normalize(dmgDir);

			AddVelocity(pushDir * pushSpeed);

			if (pushDir[2] > 0.0f) {
				RemoveFlags(FL_ONGROUND);
			}
		}

		if (isSelf == false && rawDamage > 0.0f) {
			m_tfLastDamaged = time;
		}
	}

	if (IsInvulnerable()) {
		return;
	}

	/* TF classes have no armour: base Nuclide players spawn with some */
	damageDecl.AddKey("noArmor", "1");
	super::Damage(inflictor, attacker, damageDecl, damageScale, dmgDir, hitLocation);
}

void
tfPlayer::Death(entity inflictor, entity attacker, int damagePoints, vector dmgDir, vector hitLocation, int hitBody)
{
	Extinguish();
	SetCloaked(false);
	Undisguise();
	tf_uberUntil = 0.0f;
	tf_healTarget = __NULL__;
	super::Death(inflictor, attacker, damagePoints, dmgDir, hitLocation, hitBody);
	StartDeathCam(attacker);
}

/** Team Fortress 2's view after dying: the death cam looks at the killer
from where we fell (the client moves in on them for the freeze cam after
cl_freezecam_delay seconds), then we spectate teammates until we respawn.
A building's kill counts as its Engineer's. Bots skip it. */
void
tfPlayer::StartDeathCam(entity killer)
{
	m_tfSpectateAt = 0.0f;

	if (clienttype(this) != CLIENTTYPE_REAL) {
		return;
	}

	if (killer && is.Player(killer) == false && killer.tf_builder) {
		killer = killer.tf_builder;
	}

	if (killer && killer != this && is.Player(killer)) {
		m_spectatingEntity = num_for_edict(killer);
		m_tfSpectateAt = time + autocvar_tf_deathcam_time;
	} else {
		m_spectatingEntity = 0;
		m_tfSpectateAt = time + autocvar_tf_deathcam_time_suicide;
	}

	m_spectatingMode = SPECMODE_DEATHCAM;
}

/** After the death cam: follow a living teammate (the one we watched last
if they're still up), or the killer, or fly freely. */
void
tfPlayer::StartSpectating(void)
{
	entity watchTarget = __NULL__;

	for (entity e = world; (e = next.Player(e));) {
		if (e == this || e.team != team || is.Alive(e) == false) {
			continue;
		}

		watchTarget = e;
		break;
	}

	if (!watchTarget && m_spectatingEntity > 0) {
		entity killerEnt = edict_num(m_spectatingEntity);

		if (is.Player(killerEnt) && is.Alive(killerEnt)) {
			watchTarget = killerEnt;
		}
	}

	MakeTempSpectator();

	if (watchTarget) {
		m_spectatingEntity = num_for_edict(watchTarget);
		m_spectatingMode = SPECMODE_THIRDPERSON;
		SetOrigin(watchTarget.origin);
	} else {
		m_spectatingEntity = 0;
		m_spectatingMode = SPECMODE_FREE;
	}
}

void
tfPlayer::SetCloaked(bool wantCloak)
{
	if (wantCloak) {
		if (m_tfCanCloak == false || m_tfCloakMeter < 10.0f) {
			return;
		}

		tf_cloaked = 1.0f;
		m_nuclideFlags |= VFL_NOATTACK;
		StartSoundDef("item_artifact_invisibility.pickup", CHAN_ITEM, true);
	} else {
		if (tf_cloaked) {
			StartSoundDef("item_artifact_invisibility.expiring", CHAN_ITEM, true);
		}

		tf_cloaked = 0.0f;
		m_nuclideFlags &= ~VFL_NOATTACK;
	}
}

/** The colour TF_SpawnPlayer gives each team, as userinfo wants it. */
string
TF_TeamColorString(float teamID)
{
	return (teamID == TF_TEAM_RED) ? "0xff1800" : "0x9aff";
}

/* whether a model file is installed (the Quake Live models live in a pack
   outside git) */
static bool
TF_ModelInstalled(string modelPath)
{
	filestream fileHandle = fopen(modelPath, FILE_READ);

	if (fileHandle < 0) {
		return (false);
	}

	fclose(fileHandle);
	return (true);
}

void
tfPlayer::ApplyClassModel(float teamID, string classDef)
{
	string modelPath = entityDef.GetString(classDef, (teamID == TF_TEAM_BLU) ? "model_blue" : "model_red");

	if (!STRING_SET(modelPath) || !TF_ModelInstalled(modelPath)) {
		return;
	}

	/* the model mustn't change the player's hull */
	vector hullMins = mins;
	vector hullMaxs = maxs;
	SetModel(modelPath);
	SetSize(hullMins, hullMaxs);
}

void
tfPlayer::SetClassModel(string classDef)
{
	m_tfClassDef = classDef;
	ApplyClassModel(team, classDef);
}

void
tfPlayer::Disguise(float teamID, string classDef)
{
	tf_disguiseTeam = teamID;
	tf_disguiseClass = classDef;
	userinfo.SetString(this, "topcolor", TF_TeamColorString(teamID));
	userinfo.SetString(this, "bottomcolor", TF_TeamColorString(teamID));
	userinfo.SetString(this, "*tf_disguise", sprintf("%d %s", teamID, classDef));
	ApplyClassModel(teamID, classDef);
}

void
tfPlayer::Undisguise(void)
{
	if (tf_disguiseTeam == 0) {
		return;
	}

	tf_disguiseTeam = 0;
	tf_disguiseClass = "";
	userinfo.SetString(this, "topcolor", TF_TeamColorString(team));
	userinfo.SetString(this, "bottomcolor", TF_TeamColorString(team));
	userinfo.SetString(this, "*tf_disguise", "");

	if (STRING_SET(m_tfClassDef) && GetHealth() > 0) {
		ApplyClassModel(team, m_tfClassDef);
	}
}

void
tfPlayer::SetWeaponMeter(string meterText)
{
	m_tfWeaponMeter = meterText;
}

/* cloak and Ubercharge look. only touches the render state when it
   changes, so map entities that recolour players aren't fought every frame */
void
tfPlayer::UpdateRender(void)
{
	float wantState = 0;

	if (tf_cloaked) {
		wantState = 1;
	} else if (IsInvulnerable()) {
		wantState = 2;
	}

	if (wantState == m_tfRenderState) {
		return;
	}

	m_tfRenderState = wantState;

	if (wantState == 1) {
		SetRenderMode(RM_TEXTURE);
		SetRenderFX(RFX_NORMAL);
		SetRenderAmt(12);
	} else if (wantState == 2) {
		SetRenderMode(RM_NORMAL);
		SetRenderFX(RFX_GLOWSHELL);
		SetRenderAmt(64);
		SetRenderColor((team == TF_TEAM_RED) ? [255, 32, 32] : [32, 96, 255]);
	} else {
		SetRenderMode(RM_NORMAL);
		SetRenderFX(RFX_NORMAL);
		SetRenderAmt(255);
	}
}

void
tfPlayer::PublishInfo(void)
{
	string meterText = m_tfWeaponMeter;

	if (m_tfCanCloak) {
		meterText = sprintf("CLOAK %d%%  %s", rint(m_tfCloakMeter), meterText);
	}

	userinfo.SetFloat(this, "*hp", rint(max(GetHealth(), 0)));
	userinfo.SetFloat(this, "*maxhp", max_health);

	/* the class for the HUD's portrait: "tfclass_soldier_bot" is "soldier" */
	string className = tf_desiredClass;

	if (substring(className, 0, 8) == "tfclass_") {
		className = substring(className, 8, -1);
	}

	if (substring(className, -4, 4) == "_bot") {
		className = substring(className, 0, strlen(className) - 4);
	}

	if (className != userinfo.GetString(this, "*tf_class")) {
		userinfo.SetString(this, "*tf_class", className);
	}

	if (meterText != userinfo.GetString(this, "*tf_meter")) {
		userinfo.SetString(this, "*tf_meter", meterText);
	}
}

/** Team Fortress 2's speed rules: a Medic healing a faster patient keeps
up with them, and a disguised Spy moves no faster than the disguise's
class. The client predicts the result (m_pmoveSpeedTarget). */
void
tfPlayer::UpdateSpeedTarget(void)
{
	float speedTarget = 0.0f;
	float ownSpeed = m_pmoveVars ? m_pmoveVars.pm_walkspeed : 0.0f;

	if (is.Alive(this) == false) {
		m_pmoveSpeedTarget = 0.0f;
		return;
	}

	if (tf_healTarget && m_activeWeapon && m_activeWeapon.classname == "tf_weapon_medigun") {
		tfPlayer patient = (tfPlayer)tf_healTarget;
		float patientSpeed = patient.m_pmoveVars ? patient.m_pmoveVars.pm_walkspeed : 0.0f;

		if (patientSpeed > ownSpeed) {
			speedTarget = patientSpeed;
		}
	}

	if (STRING_SET(tf_disguiseClass)) {
		float disguiseSpeed = stof(EntityDef_GetKeyValue(tf_disguiseClass, "pm_walkspeed"));

		if (disguiseSpeed > 0.0f && disguiseSpeed < ownSpeed) {
			speedTarget = disguiseSpeed;
		}
	}

	m_pmoveSpeedTarget = speedTarget;
}

void
tfPlayer::TFFrame(void)
{
	float frameTime = bound(0.0f, time - m_tfLastFrame, 0.2f);
	m_tfLastFrame = time;

	UpdateSpeedTarget();

	if (is.Alive(this) == false) {
		if (m_tfSpectateAt > 0.0f && time >= m_tfSpectateAt) {
			m_tfSpectateAt = 0.0f;
			StartSpectating();
		}

		if (time >= m_tfNextPublish) {
			m_tfNextPublish = time + 0.1f;
			PublishInfo();
		}
		return;
	}

	/* afterburn ticks */
	if (tf_burnUntil > 0.0f) {
		if (tf_burnUntil <= time || WaterLevel() >= 2 || IsInvulnerable()) {
			Extinguish();
		} else if (time >= m_tfBurnNext) {
			m_tfBurnNext = time + 0.5f;
			pointparticles(particleeffectnum("burn.burning"), origin, [0, 0, 1], 1);

			ncDict burnDecl = spawn(ncDict);
			burnDecl.AddKey("damage", ftos(autocvar_tf_afterburn_damage));
			burnDecl.AddKey("noArmor", "1");
			burnDecl.AddKey("tf_noKnockback", "1");
			burnDecl.AddKey("type", "burn");
			burnDecl.AddKey("weapon", m_tfBurnWeapon);
			Damage(m_tfBurnAttacker, m_tfBurnAttacker, burnDecl, 1.0f, g_vec_null, origin);
			remove(burnDecl);

			if (is.Alive(this) == false) {
				return;
			}
		}
	}

	/* the Spy's cloak: secondary fire toggles it with any weapon */
	if (m_tfCanCloak) {
		bool secondaryDown = (input_buttons & INPUT_SECONDARY) ? true : false;

		if (secondaryDown && m_tfSecondaryWasDown == false) {
			SetCloaked(tf_cloaked ? false : true);
		}

		m_tfSecondaryWasDown = secondaryDown;

		if (tf_cloaked) {
			m_tfCloakMeter -= autocvar_tf_cloak_drain * frameTime;

			if (m_tfCloakMeter <= 0.0f) {
				m_tfCloakMeter = 0.0f;
				SetCloaked(false);
			}
		} else {
			m_tfCloakMeter = min(100.0f, m_tfCloakMeter + (autocvar_tf_cloak_regen * frameTime));
		}
	}

	/* attacking gives a disguised Spy away */
	if (tf_disguiseTeam && (input_buttons & INPUT_PRIMARY) && m_activeWeapon) {
		string weaponName = m_activeWeapon.classname;

		if (weaponName != "tf_weapon_pda_spy" && weaponName != "tf_weapon_builder") {
			Undisguise();
		}
	}

	UpdateRender();

	if (time >= m_tfNextPublish) {
		m_tfNextPublish = time + 0.1f;
		PublishInfo();
	}
}

void
tfPlayer::ServerInputFrame(void)
{
	/* weapons run in here (Physics_Run, then ProcessInput) and refresh
	   the meter text */
	m_tfWeaponMeter = "";

	if (m_tfTestPinned) {
		/* ncPlayer::ServerInputFrame without the bot's AI, which would
		   switch weapons and steer */
		bool testHeld = (time < m_tfTestUntil);
		input_buttons = testHeld ? m_tfTestButtons : 0;
		input_movevalues = movement = (testHeld ? m_tfTestMove : [0, 0, 0]);

		/* bots steer themselves in ways input can't undo: pin them,
		   unless they are told to walk */
		if (m_tfTestMove == [0, 0, 0]) {
			SetOrigin(m_tfTestPos);
			SetVelocity([0, 0, 0]);
		}

		if (m_tfTestFixedAim) {
			input_angles = v_angle = m_tfTestAngles;
		} else if (m_tfTestAim) {
			/* r_meshpitch 1: vectoangles already gives a view's pitch */
			vector aimAngles = vectoangles(((m_tfTestAim.absmin + m_tfTestAim.absmax) * 0.5f) - (origin + view_ofs));
			input_angles = v_angle = [aimAngles[0], aimAngles[1], 0];
		}

		Physics_Run();
	} else {
		super::ServerInputFrame();
	}

	TFFrame();
}

/** A bullet's trace from a player (their eyes) or a building, which hits
players. Sets the trace_* globals. */
void
TF_HitscanTrace(vector startPos, vector endPos, entity ignoreEnt)
{
	/* MOVE_HITMODEL misses players' Quake models on this engine, and a
	   trace that skips a non-player passes through players, so: lag
	   compensated for players, otherwise skip nothing (starting inside
	   our own box is fine) */
	if (ignoreEnt.flags & FL_CLIENT) {
		traceline(startPos, endPos, MOVE_LAGGED, ignoreEnt);
	} else {
		traceline(startPos, endPos, MOVE_NORMAL, world);
	}
}

/** Bots spawn as this class instead, through the class's "_bot" def, so bot
code can derive from it without losing its methods on every class change.
A bot framework replaces it by defining TF_BOT_PAWN and its own tfBotPawn
class (for example `class tfBotPawn:BWBot {}` with BW_PAWN_BASE set to
tfPlayer) before this file is compiled. */
#ifndef TF_BOT_PAWN
class
tfBotPawn:tfPlayer
{
public:
	void tfBotPawn(void);
};

void
tfBotPawn::tfBotPawn(void)
{
}
#endif
