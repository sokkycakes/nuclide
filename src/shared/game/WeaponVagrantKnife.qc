/*
 * Vagrant knife — melee + throw projectile + warpknife.
 *
 * M1 = throw knife, Q = melee swing, M2 = warp functions, R = nothing.
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
	if (wp) { m_entWarpKnife = wp; m_flWarpThrowTime = time; PlaySound(GetDefString("snd_fire"), CHAN_WEAPON, false); }
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
	if (p) { p.gravity = 1.0; p.movetype = MOVETYPE_TOSS; PlaySound(GetDefString("snd_fire"), CHAN_WEAPON, false); }
	m_flReloadEnd = time + 2.0;
}
void ncWeaponVagrantKnife::SecondaryAttack(void) { DoMeleeSwing(); }
void ncWeaponVagrantKnife::DoAbilityAction(void)
{
	ncPlayer o = (ncPlayer)GetOwner(); if (!o) return;
	if (m_entWarpKnife) {
		float d = vlen(o.origin - m_entWarpKnife.origin);
		if (d <= WARP_PICKUP_RANGE) m_flPickupHoldStart = time;
		else if (time >= m_flNextWarpTime) DoWarpTeleport(o, d);
	} else FireWarpKnife(o);
	m_bAbilityHeld = true;
}
void ncWeaponVagrantKnife::OnAbilityReleased(void) { m_bAbilityHeld = false; }
void ncWeaponVagrantKnife::InputFrame(void)
{
	ncPlayer o = (ncPlayer)GetOwner();
	if (m_entWarpKnife && o) {
		if (m_bAbilityHeld) {
			if (vlen(o.origin - m_entWarpKnife.origin) <= WARP_PICKUP_RANGE && m_flPickupHoldStart > 0 && (time - m_flPickupHoldStart) >= WARP_PICKUP_HOLD) {
				remove(m_entWarpKnife); m_entWarpKnife = __NULL__; m_bWarpQueued = false; m_flPickupHoldStart = 0;
				m_weaponClip = min(m_weaponClip + 1, m_weaponClipSize); return;
			}
		} else m_flPickupHoldStart = 0;
	}
	if (!m_entWarpKnife) return;
	if (!o) return;
	if (wasfreed(m_entWarpKnife)) { m_entWarpKnife = __NULL__; m_bWarpQueued = false; return; }
	if (o.health <= 0) { remove(m_entWarpKnife); m_entWarpKnife = __NULL__; m_bWarpQueued = false; return; }
	if (o.m_stilettoLastDamageTime > m_flWarpThrowTime) { remove(m_entWarpKnife); m_entWarpKnife = __NULL__; m_bWarpQueued = false; }
	if (m_weaponFireInfoValue && time >= m_flReloadEnd) m_weaponFireInfoValue = 0;
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
		o.m_stilettoAirStallEnd = time + 1.5; o.AddVFlags(VFL_STILETTO_WALL); o.m_stilettoWallNorm = wk.m_lastPlaneNormal;
	}
	remove(m_entWarpKnife); m_entWarpKnife = __NULL__; m_bWarpQueued = false;
	float cd;
	if (dist <= WARP_COOLDOWN_FLAT) cd = WARP_COOLDOWN_MIN;
	else {
		float n = bound(0, (dist - WARP_COOLDOWN_FLAT) / (WARP_COOLDOWN_DIST - WARP_COOLDOWN_FLAT), 1.0);
		cd = WARP_COOLDOWN_MIN + n * (WARP_COOLDOWN_MAX - WARP_COOLDOWN_MIN);
		o.m_stilettoAirStallEnd = time + 1.3; o.AddVFlags(VFL_FROZEN);
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
void ncWeaponVagrantKnife::DoMeleeSwing(void)
{
	if (time < m_flReloadEnd) { Idle(); return; }
	if (m_bCanCut && time < m_flDeflectCooldownEnd) { Idle(); return; }
	ncPlayer p = (ncPlayer)GetOwner();
	if (p) { string s = GetDefString("snd_swing"); if (s) p.StartSoundDef(s, CHAN_WEAPON, true); }
	DoSwingTrace();
}
void ncWeaponVagrantKnife::DoSwingTrace(void)
{
	ncPlayer p = (ncPlayer)GetOwner(); if (!p) return;
	float rng = max(1, GetDefFloat("melee_range"));
	vector fwd = anglesToForward(p.v_angle);
	vector st = p.GetEyePos(); vector en = st + fwd * rng;
	traceline(st, en, MOVE_NORMAL, p);
	if (trace_fraction < 1.0 && trace_ent && trace_ent != p) {
		ncSurfacePropEntity sp = (ncSurfacePropEntity)trace_ent;
		if (sp && sp.IsVulnerable()) ApplyMeleeDamage(trace_ent, trace_endpos, fwd);
		else if (m_bCanCut) {
			ncProjectile pj = (ncProjectile)trace_ent;
			if (pj) { remove(trace_ent); m_flDeflectCooldownEnd = time + m_flDeflectCooldown; string sc = GetDefString("snd_cut"); if (sc && p) p.StartSoundDef(sc, CHAN_WEAPON, true); }
		}
	}
}
void ncWeaponVagrantKnife::ApplyMeleeDamage(entity t, vector hp, vector dir)
{
	ncPlayer p = (ncPlayer)GetOwner(); if (!p || !t) return;
	ncSurfacePropEntity sp = (ncSurfacePropEntity)t; if (!sp || !sp.IsVulnerable()) return;
	float yd = t.angles_y - vectoyaw(p.origin - t.origin);
	if (yd < 0) yd = -yd; if (yd > 180) yd = 360 - yd; if (yd > 120) { t.health = 0; }
	float dmg = stof(GetDefString("melee_damage")); float push = GetDefFloat("melee_push");
	ncDict dd = spawn(ncDict);
	dd.AddKey("damage", itos(dmg)); dd.AddKey("weapon", classname); dd.AddKey("location", vtos(hp));
	if (push > 0) { dd.AddKey("push", ftos(push)); dd.AddKey("knockback", ftos(push)); }
	sp.Damage(this, p, dd, 1.0, dir, hp); remove(dd);
	string sh = GetDefString("snd_hit"); if (sh) { p.StartSoundDef(sh, CHAN_WEAPON, true); SoundDef_Play(t, CHAN_BODY, sh); }
}
void ncWeaponVagrantKnife::FreezeEndThink(void)
{
	ncPlayer o = (ncPlayer)GetOwner(); if (o) o.RemoveVFlags(VFL_FROZEN);
}
#endif
