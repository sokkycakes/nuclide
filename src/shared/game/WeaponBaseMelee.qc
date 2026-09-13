/*
 * Copyright (c) 2026 Nuclide / Bulwark Protofunny.
 *
 * Base melee weapon class — TF2 CTFWeaponBaseMelee line+hull swing.
 *
 * Mirrors source-sdk-2013 tf_weaponbase_melee.cpp DoSwingTraceInternal:
 *   1. Line trace from eye along look (precision)
 *   2. If miss, UTIL_TraceHull with ±18 AABB (forgiveness vs entity BBOX,
 *      not mesh hitboxes — MASK_SOLID / MOVE_NORMAL equivalent)
 * Cleave (melee_cleave 1) then hits additional targets in the swing volume.
 *
 * testDistance must be 0: a negative testDistance required a LINE hit in
 * UseAmmo before FiredWeaponAttack ran, so the hull phase never executed.
 *
 * EntityDef keys added on top of ncWeapon:
 *   "melee_range"          swing distance (default 64)
 *   "melee_bounds_mins"    hull min for trace (default -18 -18 -18)
 *   "melee_bounds_maxs"    hull max for trace (default 18 18 18)
 *   "melee_cleave"         enable multi-target (default 0)
 *   "melee_damage"         damage per hit (may use skill: prefix)
 *   "melee_push"           push / knockback force
 *   "melee_hit_delay"      seconds before DoSwingTrace (default 0)
 *
 * Parent keys that still apply:
 *   "testDistance"   must be 0 for TF2-style swings (see above)
 *   "fireRate"       cooldown on fire
 *   "failRate"       unused when testDistance is 0
 *   "snd_hit"        sound on successful hit
 *   "snd_failed"     sound on miss (played from DoSwingTrace)
 *   "ammoRequired"   should be 0 for pure melee
 */

void
ncWeaponBaseMelee::ncWeaponBaseMelee(void)
{
}

#ifdef SERVER
void
ncWeaponBaseMelee::Spawned(void)
{
	super::Spawned();

	/* Explicitly precache sounds — EntityDef_Precaches only runs during
	 * initial map loading (g_ents_initialized == false), but weapons are
	 * typically given to the player after that point.  */
	string snd;
	snd = GetDefString("snd_swing");
	if (snd) { precache.Sound(snd); }
	snd = GetDefString("snd_hit");
	if (snd) { precache.Sound(snd); }
	snd = GetDefString("snd_failed");
	if (snd) { precache.Sound(snd); }

	/* Read deflect/cut config from def */
	m_bCanCut = GetDefBool("can_cut");
	m_flDeflectCooldown = max(0, GetDefFloat("deflect_cooldown"));
	m_flDeflectCooldownEnd = 0;

	snd = GetDefString("snd_cut");
	if (snd) { precache.Sound(snd); }
	snd = GetDefString("snd_backstab");
	if (snd) { precache.Sound(snd); }
}

void
ncWeaponBaseMelee::PrimaryAttack(void)
{
	ncPlayer p;
	string snd;
	string actName;
	float seq;
	float rate;
	float shotAnim;

	if (CanFire() == false) {
		Idle();
		return;
	}

	if (m_bCanCut && time < m_flDeflectCooldownEnd) {
		Idle();
		return;
	}

	p = (ncPlayer)GetOwner();
	if (!p) {
		return;
	}

	/* Skip full Attack() — it calls Event_FireWeapon() with whatever the
	 * *active* weapon last set as m_actAttack (Collier sidearm = gun shoot).
	 * Mirror axe logic: swing trace + owner/weapon melee gesture only. */
	snd = GetDefString("snd_swing");
	if (STRING_SET(snd)) {
		p.StartSoundDef(snd, CHAN_WEAPON, true);
	}

	/* Animation/sound start now; optional windup before the hit trace. */
	float hitDelay = GetDefFloat("melee_hit_delay");
	if (hitDelay > 0.0f) {
		ncTimer::TemporaryTimer(this, _MeleeHitThink, hitDelay, false);
	} else {
		FiredWeaponAttack("");
	}

	rate = GetDefFloat("fireRate");
	if (rate <= 0) {
		rate = 0.5;
	}
	SetAttackNext(rate);

	/* ALT melee has no viewmodel — hide the held gun for the swing duration. */
	if (!m_viewModel) {
		p.m_heroMeleeHolster = rate;
	}

	/* Viewmodel swing when this melee *is* the held weapon (Arch axe). */
	if (m_viewModel) {
		shotAnim = GetSubDefActVM(classname, "fire", m_viewModel);
		if (shotAnim < 0) {
			shotAnim = 0;
		}
		SetWeaponFrame(shotAnim);
		SetIdleNext(frameduration(m_viewModel, shotAnim));
	}

	/* Third-person: weapon act_attack (CSO knife) first, else owner
	 * m_actAttack like Event_FireWeapon / axe animPrefix. */
	seq = ACTIVITY_NOTFOUND;
	if (p.IsCrouching()) {
		actName = GetDefString("act_attack_crouch");
		if (!STRING_SET(actName)) {
			actName = "crouch_shoot_knife";
		}
	} else {
		actName = GetDefString("act_attack");
		if (!STRING_SET(actName)) {
			actName = "ref_shoot_knife";
		}
	}
	if (STRING_SET(actName) && p.modelindex > 0) {
		seq = frameforname(p.modelindex, actName);
	}
	if (seq < 0) {
		seq = p.m_actAttack;
	}
	if (seq >= 0 && seq != ACTIVITY_NOTFOUND) {
		p.PlayGesture(seq, -1);
		p.SendFlags |= PLAYER_TOPFRAME;
	}
}

void
ncWeaponBaseMelee::FiredWeaponAttack(string fireInfo)
{
	ncPlayer ourOwner = (ncPlayer)GetOwner();
	if (!ourOwner) {
		return;
	}

	_SetWeaponState(WEAPONSTATE_IDLE);

	/* apply weapon-owned knockback to the shooter */
	if (m_fiKnockBack) {
		ourOwner.AddVelocity(
			anglesToForward(ourOwner.v_angle) * -m_fiKnockBack);
	}

	/* do the melee swing — replaces the projectile spawn */
	DoSwingTrace();
}

void
ncWeaponBaseMelee::_MeleeHitThink(void)
{
	FiredWeaponAttack("");
}

float
ncWeaponBaseMelee::GetMeleeRange(void)
{
	return max(1, GetDefFloat("melee_range"));
}

float
ncWeaponBaseMelee::GetMeleeDamage(void)
{
	return stof(GetDefString("melee_damage"));
}

float
ncWeaponBaseMelee::GetMeleePush(void)
{
	return GetDefFloat("melee_push");
}

bool
ncWeaponBaseMelee::GetMeleeCleave(void)
{
	return GetDefBool("melee_cleave");
}

void
ncWeaponBaseMelee::DoSwingTrace(void)
{
	ncPlayer pPlayer = (ncPlayer)GetOwner();
	if (!pPlayer)
		return;

	float fRange = GetMeleeRange();
	vector vecMins = GetDefVector("melee_bounds_mins");
	vector vecMaxs = GetDefVector("melee_bounds_maxs");

	/* TF2 defaults: static Vector vecSwingMinsBase( -18, -18, -18 ); */
	if (vecMins_x == 0 && vecMins_y == 0 && vecMins_z == 0)
		vecMins = [-18,-18,-18];

	if (vecMaxs_x == 0 && vecMaxs_y == 0 && vecMaxs_z == 0)
		vecMaxs = [18,18,18];

	vector vecForward = anglesToForward(pPlayer.v_angle);
	vector vecStart = pPlayer.GetEyePos();
	vector vecEnd = vecStart + vecForward * fRange;

	/* MASK_SOLID analogue: entity BBOX (SOLID_BBOX/SLIDEBOX), not mesh
	 * hitboxes. MOVE_HITMODEL would be the bullet/hitbox path — avoid it. */
	int oldHitContents = pPlayer.hitcontentsmaski;
	pPlayer.hitcontentsmaski = CONTENTBITS_POINTSOLID | CONTENTBIT_CORPSE;

	/* phase 1 — line (UTIL_TraceLine) */
	traceline(vecStart, vecEnd, MOVE_NORMAL, pPlayer);

	bool bLineHit = (trace_fraction < 1.0);
	entity eLineHit = trace_ent;
	vector vecLinePos = trace_endpos;

	/* phase 2 — hull (UTIL_TraceHull) only when the line missed entirely.
	 * ±18 AABB sweep connects vs player/monster collision boxes even when
	 * the crosshair is not centred on the visual mesh. */
	bool bHullHit = false;
	entity eHullHit = __NULL__;
	vector vecHullPos = vecEnd;

	if (!bLineHit) {
		tracebox(vecStart, vecMins, vecMaxs, vecEnd, MOVE_NORMAL, pPlayer);

		if (trace_fraction < 1.0) {
			bHullHit = true;
			eHullHit = trace_ent;
			vecHullPos = trace_endpos;
		}
	}

	pPlayer.hitcontentsmaski = oldHitContents;

	entity eTarget = __NULL__;
	vector vecHitPos = vecEnd;
	vector vecHitDir = vecForward;

	if (bLineHit) {
		eTarget = eLineHit;
		vecHitPos = vecLinePos;
	} else if (bHullHit) {
		eTarget = eHullHit;
		vecHitPos = vecHullPos;
	}

	vecHitDir = normalize(vecHitPos - vecStart);

	/* Cut projectiles only. FTE class casts are not instanceof — casting a
	 * player to ncProjectile still yields a non-null pointer, which wrongly
	 * triggered deflect cooldown + snd_cut instead of damage. */
	if (m_bCanCut && eTarget && eTarget.spawnclass == "ncProjectile") {
		remove(eTarget);
		m_flDeflectCooldownEnd = time + m_flDeflectCooldown;
		string sndCut = GetDefString("snd_cut");
		if (sndCut && pPlayer) {
			pPlayer.StartSoundDef(sndCut, CHAN_WEAPON, true);
		}
		return;
	}

	ncSurfacePropEntity spTarget = (ncSurfacePropEntity)eTarget;
	if (spTarget && spTarget.IsVulnerable() && eTarget != pPlayer) {
		ApplyMeleeDamage(eTarget, vecHitPos, vecHitDir);
	} else {
		/* clean miss — swing already played; impact miss cue here */
		string sndMiss = GetDefString("snd_failed");
		if (sndMiss) {
			pPlayer.StartSoundDef(sndMiss, CHAN_WEAPON, true);
		}
		return;
	}

	/* cleave: TF2 UTIL_EntitiesAlongRay analogue — extra targets in volume */
	if (!GetMeleeCleave())
		return;

	entity eSeen = __NULL__;
	eSeen = nextent(world);
	while (eSeen)
	{
		if (eSeen == pPlayer)
			{ eSeen = nextent(eSeen); continue; }
		if (eSeen == eTarget)
			{ eSeen = nextent(eSeen); continue; }
		if (!(eSeen.flags & (FL_CLIENT | FL_MONSTER)))
			{ eSeen = nextent(eSeen); continue; }

		ncSurfacePropEntity spSeen = (ncSurfacePropEntity)eSeen;
		if (!spSeen || !spSeen.IsVulnerable())
			{ eSeen = nextent(eSeen); continue; }

		vector vecToTarget = eSeen.origin - vecStart;
		float flDist = vlen(vecToTarget);
		/* hull corner extends ~18*sqrt(3) past range — pad like TF2 */
		if (flDist > fRange + 32)
			{ eSeen = nextent(eSeen); continue; }

		vector vecDir = normalize(vecToTarget);
		if (vecDir * vecForward < 0.1)
			{ eSeen = nextent(eSeen); continue; }

		/* hull sweep toward this target's origin (entity BBOX) */
		tracebox(vecStart, vecMins, vecMaxs, eSeen.origin, MOVE_NORMAL, pPlayer);

		if (trace_fraction < 1.0 && trace_ent == eSeen) {
			ApplyMeleeDamage(eSeen, trace_endpos, vecDir);
		}

		eSeen = nextent(eSeen);
	}
}

void
ncWeaponBaseMelee::ApplyMeleeDamage(entity eTarget, vector vecHitPos, vector vecHitDir)
{
	ncPlayer pPlayer = (ncPlayer)GetOwner();
	if (!pPlayer)
		return;

	if (!eTarget)
		return;

	ncSurfacePropEntity spTarget = (ncSurfacePropEntity)eTarget;
	if (!spTarget || !spTarget.IsVulnerable())
		return;

	float fDamage = GetMeleeDamage();
	float fPush = GetMeleePush();

	ncDict damageDecl;
	damageDecl = spawn(ncDict);
	damageDecl.AddKey("damage", itos(fDamage));
	damageDecl.AddKey("weapon", classname);
	damageDecl.AddKey("location", vtos(vecHitPos));

	if (fPush > 0) {
		damageDecl.AddKey("push", ftos(fPush));
		damageDecl.AddKey("knockback", ftos(fPush));
	}

	spTarget.Damage(this, pPlayer, damageDecl, 1.0, vecHitDir, vecHitPos);
	remove(damageDecl);

	/* hit sound — played on the attacker (for hit confirmation) and on
	 * the target (so the victim hears it too), matching the projectile
	 * system's snd_hitActor pattern. */
	string sndHit = GetDefString("snd_hit");
	if (sndHit) {
		pPlayer.StartSoundDef(sndHit, CHAN_WEAPON, true);
		SoundDef_Play(eTarget, CHAN_BODY, sndHit);
	}
}

#endif
