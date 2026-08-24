/*
 * Vagrant knife — throw projectile + warpknife.
 * Melee lives on hero_vagrant_melee (ncWeaponVagrantMelee).
 */

#define WARP_PICKUP_RANGE		32
#define WARP_PICKUP_HOLD		1.5
#define WARP_COOLDOWN_MIN		1.0
#define WARP_COOLDOWN_MAX		10.0
#define WARP_COOLDOWN_FLAT		512
#define WARP_COOLDOWN_DIST		2000
#define GHOST_DURATION			1.0

void ncWeaponVagrantKnife::ncWeaponVagrantKnife(void) {}

#ifdef SERVER
void ncWeaponVagrantKnife::Reload(void) {}

void ncWeaponVagrantKnife::Spawned(void)
{
	super::Spawned();
	m_bCanCut = GetDefBool("can_cut");
	m_flDeflectCooldown = max(0, GetDefFloat("deflect_cooldown"));
	m_flDeflectCooldownEnd = 0;
	string s;
	s = GetDefString("snd_cut"); if (s) precache.Sound(s);
	s = GetDefString("snd_swing"); if (s) precache.Sound(s);
	s = GetDefString("snd_hit"); if (s) precache.Sound(s);
	s = GetDefString("snd_failed"); if (s) precache.Sound(s);
	s = GetDefString("snd_fire"); if (s) precache.Sound(s);
	m_bWarpQueued = false; m_entWarpKnife = __NULL__;
	m_flWarpThrowTime = 0; m_flNextWarpTime = 0;
	m_flReloadEnd = 0; m_flPickupHoldStart = 0; m_bAbilityHeld = false;
}

void ncWeaponVagrantKnife::FireWarpKnife(entity ourOwnerEnt)
{
	ncPlayer ourOwner = (ncPlayer)ourOwnerEnt;
	if (m_entWarpKnife || !ourOwner) return;
	if (time < m_flReloadEnd) return;
	ncProjectile wp = ncProjectile_SpawnDef("projectile_vagrant_warpknife", ourOwner);
	if (wp) {
		string sndFire;
		m_entWarpKnife = wp;
		m_flWarpThrowTime = time;
		sndFire = GetDefString("snd_fire");
		if (STRING_SET(sndFire)) {
			ourOwner.StartSoundDef(sndFire, CHAN_WEAPON, true);
		}
	}
	m_flReloadEnd = time + 2.0; m_flNextWarpTime = time + 0.5;
}

void ncWeaponVagrantKnife::PrimaryAttack(void)
{
	if (time < m_flReloadEnd) { Idle(); return; }
	if (m_bCanCut && time < m_flDeflectCooldownEnd) { Idle(); return; }
	ncPlayer o = (ncPlayer)GetOwner(); if (!o) return;
	if (m_fiAmmoRequired) {
		if (m_weaponClipSize) { if (m_weaponClip <= 0i) m_weaponClip = m_weaponClipSize; m_weaponClip -= m_fiAmmoPerShot; }
		else if (!o.UseAmmo(m_fiAmmoType, m_fiAmmoPerShot)) { EmptySound(); return; }
	}
	ncProjectile p = ncProjectile_SpawnDef("projectile_vagrant_throwknife", o);
	if (p) {
		string sndFire;
		p.gravity = 1.0;
		p.movetype = MOVETYPE_TOSS;
		sndFire = GetDefString("snd_fire");
		if (STRING_SET(sndFire)) {
			o.StartSoundDef(sndFire, CHAN_WEAPON, true);
		}
	}
	m_flReloadEnd = time + 2.0;
}

void ncWeaponVagrantKnife::SecondaryAttack(void)
{
	/* Route weapon-secondary melee through the shared hero-melee path. */
	ncPlayer o = (ncPlayer)GetOwner();
	if (o) {
		HeroActions_MeleePress(o);
	}
}

void ncWeaponVagrantKnife::DoAbilityAction(void)
{
	/* Compatibility: warpknife is player-owned via HeroActions. */
	ncPlayer o = (ncPlayer)GetOwner();
	if (o) {
		HeroActions_HeroToolPress(o);
	}
}

void ncWeaponVagrantKnife::OnAbilityReleased(void)
{
	ncPlayer o = (ncPlayer)GetOwner();
	if (o) {
		HeroActions_HeroToolRelease(o);
	}
}

void ncWeaponVagrantKnife::InputFrame(void)
{
	/* Warpknife tick runs from HeroActions_InputFrame. */
}

void ncWeaponVagrantKnife::DoWarpTeleport(entity e, float dist)
{
	ncPlayer o = (ncPlayer)e; if (!o || !m_entWarpKnife) return;
	ncProjectile wk = (ncProjectile)m_entWarpKnife;
	vector dst = wk.origin;
	SpawnGhost(o, dst);
	float off = 24;
	if (wk.m_lastPlaneNormal_z >= -0.5 && wk.m_lastPlaneNormal_z <= 0.5) off = 6;
	dst += wk.m_lastPlaneNormal * off;
	setorigin(o, dst); o.SetVelocity([0,0,0]); o.SetAngles(o.v_angle);
	if (wk.m_lastPlaneNormal_z >= -0.1 && wk.m_lastPlaneNormal_z <= 0.1) {
		o.m_stilettoAirStallTime = 1.5f; o.AddVFlags(VFL_STILETTO_WALL); o.m_stilettoWallNorm = wk.m_lastPlaneNormal;
	}
	remove(m_entWarpKnife); m_entWarpKnife = __NULL__; m_bWarpQueued = false;
	float cd;
	if (dist <= WARP_COOLDOWN_FLAT) cd = WARP_COOLDOWN_MIN;
	else {
		float n = bound(0, (dist - WARP_COOLDOWN_FLAT) / (WARP_COOLDOWN_DIST - WARP_COOLDOWN_FLAT), 1.0);
		cd = WARP_COOLDOWN_MIN + n * (WARP_COOLDOWN_MAX - WARP_COOLDOWN_MIN);
		o.m_stilettoAirStallTime = 1.3f; o.AddVFlags(VFL_FROZEN);
		nextthink = time + 1.3; think = FreezeEndThink;
	}
	m_flNextWarpTime = time + cd;
}

void Ghost_RemoveThink(void) { remove(self); }

void ncWeaponVagrantKnife::SpawnGhost(entity pl, vector dest)
{
	ncPlayer p = (ncPlayer)pl; if (!p) return;
	entity g = spawn(); if (!g) return;
	setmodel(g, p.model); setorigin(g, p.origin);
	vector t = dest - p.origin; t_z = 0;
	g.angles = vlen(t) > 0 ? vectoangles(t) : p.angles;
	g.frame = frameforname(g.modelindex, "treadwater") + 13.40;
	g.skin = p.skin; g.solid = SOLID_NOT; g.movetype = MOVETYPE_NONE;
	g.alpha = 0.3; g.effects |= EF_FULLBRIGHT | EF_NOSHADOW;
	g.nextthink = time + GHOST_DURATION; g.think = Ghost_RemoveThink;
}

/* Legacy line-only path retained for compatibility callers. */
void ncWeaponVagrantKnife::DoMeleeSwing(void)
{
	ncPlayer o = (ncPlayer)GetOwner();
	if (o) {
		HeroActions_MeleePress(o);
	}
}

void ncWeaponVagrantKnife::DoSwingTrace(void) {}
void ncWeaponVagrantKnife::ApplyMeleeDamage(entity t, vector hp, vector dir) {}

void ncWeaponVagrantKnife::FreezeEndThink(void)
{
	ncPlayer o = (ncPlayer)GetOwner(); if (o) o.RemoveVFlags(VFL_FROZEN);
}
#endif

/* ---- Auxiliary Vagrant melee (line+hull base + backstab) ---- */

void ncWeaponVagrantMelee::ncWeaponVagrantMelee(void) {}

#ifdef SERVER
void ncWeaponVagrantMelee::ApplyMeleeDamage(entity t, vector hp, vector dir)
{
	ncPlayer p = (ncPlayer)GetOwner();
	float yd;
	bool isBackstab;
	string sndBackstab;
	float fDamage;
	float fPush;
	ncDict damageDecl;
	ncSurfacePropEntity sp;

	if (!p || !t) {
		return;
	}

	sp = (ncSurfacePropEntity)t;
	if (!sp || !sp.IsVulnerable()) {
		return;
	}

	/* Backstab: yaw delta > 120° instantly drops health. */
	yd = t.angles_y - vectoyaw(p.origin - t.origin);
	if (yd < 0) {
		yd = -yd;
	}
	if (yd > 180) {
		yd = 360 - yd;
	}
	isBackstab = (yd > 120);

	if (isBackstab) {
		/* Lethal via Damage() — do NOT pre-zero health. Player::Damage
		 * returns early when GetHealth() <= 0, skipping Death(), so the
		 * client shows dead UI while the server still allows movement. */
		fDamage = sp.GetHealth();
		if (fDamage < 1) {
			fDamage = 1;
		}
		fPush = GetMeleePush();
		damageDecl = spawn(ncDict);
		damageDecl.AddKey("damage", itos(fDamage));
		damageDecl.AddKey("weapon", classname);
		damageDecl.AddKey("location", vtos(hp));
		if (fPush > 0) {
			damageDecl.AddKey("push", ftos(fPush));
			damageDecl.AddKey("knockback", ftos(fPush));
		}
		/* Skip super — its snd_hit would replace backstab on CHAN_WEAPON. */
		sp.Damage(this, p, damageDecl, 1.0, dir, hp);
		remove(damageDecl);

		sndBackstab = GetDefString("snd_backstab");
		if (STRING_SET(sndBackstab)) {
			p.StartSoundDef(sndBackstab, CHAN_WEAPON, true);
			SoundDef_Play(t, CHAN_BODY, sndBackstab);
		}
		return;
	}

	/* Vagrant hit-confirm sounded too loud because the base melee path plays
	 * snd_hit on both attacker and target. Keep the local confirm only. */
	fDamage = GetMeleeDamage();
	fPush = GetMeleePush();
	damageDecl = spawn(ncDict);
	damageDecl.AddKey("damage", itos(fDamage));
	damageDecl.AddKey("weapon", classname);
	damageDecl.AddKey("location", vtos(hp));
	if (fPush > 0) {
		damageDecl.AddKey("push", ftos(fPush));
		damageDecl.AddKey("knockback", ftos(fPush));
	}
	sp.Damage(this, p, damageDecl, 1.0, dir, hp);
	remove(damageDecl);

	string sndHit = GetDefString("snd_hit");
	if (STRING_SET(sndHit)) {
		p.StartSoundDef(sndHit, CHAN_WEAPON, true);
	}
}
#endif
