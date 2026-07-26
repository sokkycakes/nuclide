/*
 * Hero action router — player-owned melee + signature tools.
 */

#define HERO_WARP_PICKUP_RANGE		32
#define HERO_WARP_PICKUP_HOLD		1.5
#define HERO_WARP_COOLDOWN_MIN		1.0
#define HERO_WARP_COOLDOWN_MAX		10.0
#define HERO_WARP_COOLDOWN_FLAT		512
#define HERO_WARP_COOLDOWN_DIST		2000
#define HERO_WARP_GHOST_DURATION	1.0

void HeroActions_WarpknifeClear(entity player);
void HeroActions_WarpknifeFrame(entity player);
void HeroActions_WarpknifePress(entity player);
void HeroActions_WarpknifeRelease(entity player);

#ifdef SERVER
void HeroActions_WarpknifeFire(entity player);
void HeroActions_WarpknifeTeleport(entity player, float dist);
void HeroActions_WarpknifeGhost(entity player, vector dest);
void HeroActions_WarpknifeFreezeEnd(void);
void HeroActions_WarpknifeGhostRemove(void);
#endif

void
HeroActions_Reset(entity player)
{
	HeroActions_ClearMeleeWeapon(player);
	HeroActions_WarpknifeClear(player);
}

#ifdef SERVER
void
HeroActions_WarpknifeClear(entity player)
{
	ncPlayer pl;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
	if (pl.m_heroWarpKnife && !wasfreed(pl.m_heroWarpKnife)) {
		remove(pl.m_heroWarpKnife);
	}
	pl.m_heroWarpKnife = __NULL__;
	pl.m_heroToolHeld = false;
	pl.m_heroWarpPickupHoldStart = 0;
	pl.m_stilettoLungeCharging = 0;
	pl.m_stilettoLungeChargeStart = 0.0f;
}

void
HeroActions_WarpknifeGhostRemove(void)
{
	remove(self);
}

void
HeroActions_WarpknifeFreezeEnd(void)
{
	ncPlayer o = (ncPlayer)self.owner;
	if (o) {
		o.RemoveVFlags(VFL_FROZEN);
	}
	remove(self);
}

void
HeroActions_WarpknifeGhost(entity player, vector dest)
{
	ncPlayer p = (ncPlayer)player;
	entity g;
	vector t;

	if (!p) {
		return;
	}

	g = spawn();
	if (!g) {
		return;
	}

	setmodel(g, p.model);
	setorigin(g, p.origin);
	t = dest - p.origin;
	t_z = 0;
	g.angles = vlen(t) > 0 ? vectoangles(t) : p.angles;
	g.frame = frameforname(g.modelindex, "treadwater") + 13.40;
	g.skin = p.skin;
	g.solid = SOLID_NOT;
	g.movetype = MOVETYPE_NONE;
	g.alpha = 0.3;
	g.effects |= EF_FULLBRIGHT | EF_NOSHADOW;
	g.nextthink = time + HERO_WARP_GHOST_DURATION;
	g.think = HeroActions_WarpknifeGhostRemove;
}

void
HeroActions_WarpknifeFire(entity player)
{
	ncPlayer pl = (ncPlayer)player;
	ncProjectile wp;

	if (!pl || pl.m_heroWarpKnife) {
		return;
	}
	if (time < pl.m_heroWarpReloadEnd) {
		return;
	}

	wp = ncProjectile_SpawnDef("projectile_vagrant_warpknife", pl);
	if (wp) {
		pl.m_heroWarpKnife = wp;
		pl.m_heroWarpThrowTime = time;
		SoundDef_Play(pl, CHAN_WEAPON, "Weapon_Axe.Miss");
	}
	pl.m_heroWarpReloadEnd = time + 2.0;
	pl.m_heroWarpNextTime = time + 0.5;
}

void
HeroActions_WarpknifeTeleport(entity player, float dist)
{
	ncPlayer o = (ncPlayer)player;
	ncProjectile wk;
	vector dst;
	float off;
	float cd;
	entity freezer;

	if (!o || !o.m_heroWarpKnife) {
		return;
	}

	wk = (ncProjectile)o.m_heroWarpKnife;
	dst = wk.origin;
	HeroActions_WarpknifeGhost(o, dst);
	off = 24;
	if (wk.m_lastPlaneNormal_z >= -0.5 && wk.m_lastPlaneNormal_z <= 0.5) {
		off = 6;
	}
	dst += wk.m_lastPlaneNormal * off;
	setorigin(o, dst);
	o.SetVelocity([0, 0, 0]);
	o.SetAngles(o.v_angle);

	if (wk.m_lastPlaneNormal_z >= -0.1 && wk.m_lastPlaneNormal_z <= 0.1) {
		o.m_stilettoAirStallEnd = time + 1.5;
		o.AddVFlags(VFL_STILETTO_WALL);
		o.m_stilettoWallNorm = wk.m_lastPlaneNormal;
	}

	remove(o.m_heroWarpKnife);
	o.m_heroWarpKnife = __NULL__;
	o.m_heroWarpPickupHoldStart = 0;

	if (dist <= HERO_WARP_COOLDOWN_FLAT) {
		cd = HERO_WARP_COOLDOWN_MIN;
	} else {
		float n = bound(0, (dist - HERO_WARP_COOLDOWN_FLAT) / (HERO_WARP_COOLDOWN_DIST - HERO_WARP_COOLDOWN_FLAT), 1.0);
		cd = HERO_WARP_COOLDOWN_MIN + n * (HERO_WARP_COOLDOWN_MAX - HERO_WARP_COOLDOWN_MIN);
		o.m_stilettoAirStallEnd = time + 1.3;
		o.AddVFlags(VFL_FROZEN);
		freezer = spawn();
		if (freezer) {
			freezer.owner = o;
			freezer.nextthink = time + 1.3;
			freezer.think = HeroActions_WarpknifeFreezeEnd;
		}
	}
	o.m_heroWarpNextTime = time + cd;
}

void
HeroActions_WarpknifePress(entity player)
{
	ncPlayer pl = (ncPlayer)player;
	float d;

	if (!pl) {
		return;
	}

	if (pl.m_heroWarpKnife) {
		d = vlen(pl.origin - pl.m_heroWarpKnife.origin);
		if (d <= HERO_WARP_PICKUP_RANGE) {
			pl.m_heroWarpPickupHoldStart = time;
		} else if (time >= pl.m_heroWarpNextTime) {
			HeroActions_WarpknifeTeleport(pl, d);
		}
	} else {
		HeroActions_WarpknifeFire(pl);
	}
	pl.m_heroToolHeld = true;
}

void
HeroActions_WarpknifeRelease(entity player)
{
	ncPlayer pl = (ncPlayer)player;

	if (!pl) {
		return;
	}

	pl.m_heroToolHeld = false;
}

void
HeroActions_WarpknifeFrame(entity player)
{
	ncPlayer pl = (ncPlayer)player;

	if (!pl) {
		return;
	}

	if (pl.m_heroWarpKnife && pl.m_heroToolHeld) {
		if (vlen(pl.origin - pl.m_heroWarpKnife.origin) <= HERO_WARP_PICKUP_RANGE
		    && pl.m_heroWarpPickupHoldStart > 0
		    && (time - pl.m_heroWarpPickupHoldStart) >= HERO_WARP_PICKUP_HOLD) {
			remove(pl.m_heroWarpKnife);
			pl.m_heroWarpKnife = __NULL__;
			pl.m_heroWarpPickupHoldStart = 0;
			return;
		}
	} else {
		pl.m_heroWarpPickupHoldStart = 0;
	}

	if (!pl.m_heroWarpKnife) {
		return;
	}
	if (wasfreed(pl.m_heroWarpKnife)) {
		pl.m_heroWarpKnife = __NULL__;
		return;
	}
	if (pl.health <= 0) {
		HeroActions_WarpknifeClear(pl);
		return;
	}
	if (pl.m_stilettoLastDamageTime > pl.m_heroWarpThrowTime) {
		HeroActions_WarpknifeClear(pl);
	}
}
#endif

#ifndef SERVER
void HeroActions_WarpknifeClear(entity player) { }
void HeroActions_WarpknifeFrame(entity player) { }
void HeroActions_WarpknifePress(entity player) { }
void HeroActions_WarpknifeRelease(entity player) { }
#endif

void
HeroActions_HeroToolPress(entity player)
{
	ncPlayer pl;
	string tool;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
	tool = pl.GetDefString("hero_tool");
	if (!STRING_SET(tool)) {
		tool = "grapple";
	}

	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] tool press player=%d tool=%s\n",
			num_for_edict(pl), tool));
	}

#ifdef SERVER
	pl.m_stilettoGrappleActionHeld = 1;

	if (tool == "lunge") {
		Archstiletto_AbilityPress(pl);
	} else if (tool == "warpknife") {
		HeroActions_WarpknifePress(pl);
	} else {
		Stiletto_FireGrapple(pl);
	}
#endif
}

void
HeroActions_HeroToolRelease(entity player)
{
	ncPlayer pl;
	string tool;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
	tool = pl.GetDefString("hero_tool");
	if (!STRING_SET(tool)) {
		tool = "grapple";
	}

	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] tool release player=%d tool=%s\n",
			num_for_edict(pl), tool));
	}

#ifdef SERVER
	pl.m_stilettoGrappleActionHeld = 0;

	if (tool == "lunge") {
		Archstiletto_AbilityRelease(pl);
	} else if (tool == "warpknife") {
		HeroActions_WarpknifeRelease(pl);
	}
#endif
}

void
HeroActions_ClearMeleeWeapon(entity player)
{
	ncPlayer pl;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
#ifdef SERVER
	if (pl.m_heroMeleeWeapon) {
		if (!wasfreed(pl.m_heroMeleeWeapon)) {
			remove(pl.m_heroMeleeWeapon);
		}
		pl.m_heroMeleeWeapon = __NULL__;
	}
#endif
}

void
HeroActions_EnsureMeleeWeapon(entity player)
{
	ncPlayer pl;
	string meleeDef;
	ncWeapon w;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
#ifdef SERVER
	if (pl.m_heroMeleeWeapon && !wasfreed(pl.m_heroMeleeWeapon)) {
		return;
	}

	pl.m_heroMeleeWeapon = __NULL__;
	meleeDef = pl.GetDefString("hero_melee_weapon");
	if (!STRING_SET(meleeDef)) {
		return;
	}

	w = (ncWeapon)EntityDef_CreateClassname(meleeDef);
	if (!w) {
		if (autocvar_hero_actions_debug) {
			print(sprintf("[hero_actions] failed to create melee '%s'\n", meleeDef));
		}
		return;
	}

	w.SetOwner(pl);
	pl.m_heroMeleeWeapon = w;

	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] spawned melee '%s' for player=%d\n",
			meleeDef, num_for_edict(pl)));
	}
#endif
}

void
HeroActions_MeleePress(entity player)
{
	ncPlayer pl;
	ncWeapon melee;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;

	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] melee press player=%d\n", num_for_edict(pl)));
	}

#ifdef SERVER
	HeroActions_EnsureMeleeWeapon(pl);
	melee = pl.m_heroMeleeWeapon;
	if (!melee || wasfreed(melee)) {
		return;
	}

	melee._PrimaryAttack();
#endif
}

void
HeroActions_InputFrame(entity player, int currentButtons, int previousButtons)
{
	ncPlayer pl;
	int toolNow;
	int toolPrev;
	int meleeNow;
	int meleePrev;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
	toolNow = currentButtons & INPUT_HERO_TOOL;
	toolPrev = previousButtons & INPUT_HERO_TOOL;
	meleeNow = currentButtons & INPUT_MELEE;
	meleePrev = previousButtons & INPUT_MELEE;

	if (toolNow && !toolPrev) {
		HeroActions_HeroToolPress(pl);
	} else if (!toolNow && toolPrev) {
		HeroActions_HeroToolRelease(pl);
	}

	if (meleeNow && !meleePrev) {
		HeroActions_MeleePress(pl);
	}

#ifdef SERVER
	HeroActions_WarpknifeFrame(pl);
#endif
}
