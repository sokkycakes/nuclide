/*
 * Copyright (c) 2026 Nuclide / Bulwark Protofunny.
 *
 * Base melee weapon class — TF2-inspired line+hull trace with cleave.
 *
 * Overrides the projectile-based attack in ncWeapon to perform direct
 * melee hit detection.  Single swing does line trace (precision), then
 * hull trace (forgiveness).  When melee_cleave is 1 the swing hits
 * every damageable entity in the swept volume, one per swing.
 *
 * EntityDef keys added on top of ncWeapon:
 *   "melee_range"          swing distance (default 64)
 *   "melee_bounds_mins"    hull min for trace (default -18 -18 -18)
 *   "melee_bounds_maxs"    hull max for trace (default 18 18 18)
 *   "melee_cleave"         enable multi-target (default 0)
 *   "melee_damage"         damage per hit (may use skill: prefix)
 *   "melee_push"           push / knockback force
 *
 * Parent keys that still apply:
 *   "testDistance"   hit/miss animation split (UseAmmo pre-check)
 *   "fireRate"       cooldown on hit
 *   "failRate"       cooldown on miss
 *   "snd_hit"        sound on successful hit
 *   "snd_failed"     sound on miss
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
}

void
ncWeaponBaseMelee::PrimaryAttack(void)
{
	if (CanFire() == false) {
		Idle();
		return;
	}

	/* play swing sound on every swing attempt (hit or miss) */
	ncPlayer p = (ncPlayer)GetOwner();
	if (p) {
		string snd = GetDefString("snd_swing");
		if (snd) {
			p.StartSoundDef(snd, CHAN_WEAPON, true);
		}
	}

	Attack(m_primaryFireInfo);
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

	/* apply defaults if no hull specified */
	if (vecMins_x == 0 && vecMins_y == 0 && vecMins_z == 0)
		vecMins = [-18,-18,-18];

	if (vecMaxs_x == 0 && vecMaxs_y == 0 && vecMaxs_z == 0)
		vecMaxs = [18,18,18];

	/* calc swing */
	vector vecForward = anglesToForward(pPlayer.v_angle);
	vector vecStart = pPlayer.GetEyePos();
	vector vecEnd = vecStart + vecForward * fRange;

	int oldHitContents = pPlayer.hitcontentsmaski;
	pPlayer.hitcontentsmaski = CONTENTBITS_POINTSOLID | CONTENTBIT_CORPSE;

	/* phase 1 — line trace (precision) */
	traceline(vecStart, vecEnd, MOVE_NORMAL, pPlayer);

	bool bLineHit = (trace_fraction < 1.0);
	entity eLineHit = trace_ent;
	vector vecLinePos = trace_endpos;

	/* phase 2 — hull trace (forgiveness); wider Y extents let the swing
	 * connect even when the target isn't centred on the crosshair.  The
	 * hull sweeps at eye height so it never hits the floor. */
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

	/* decide what we hit (single-target path from here) */
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

	ncSurfacePropEntity spTarget = (ncSurfacePropEntity)eTarget;
	if (spTarget && spTarget.IsVulnerable() && eTarget != pPlayer) {
		ApplyMeleeDamage(eTarget, vecHitPos, vecHitDir);
	} else {
		return; /* missed everything */
	}

	/* cleave: find additional targets within the forward cone */
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
		if (flDist > fRange + 32)
			{ eSeen = nextent(eSeen); continue; }

		vector vecDir = normalize(vecToTarget);
		if (vecDir * vecForward < 0.1)
			{ eSeen = nextent(eSeen); continue; }

		/* hull trace to this specific target */
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
