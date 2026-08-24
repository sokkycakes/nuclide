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
	HeroActions_InitResources(player);
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
	pl.m_stilettoLungeCharge = 0.0f;
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
		o.m_stilettoAirStallTime = 1.5f;
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
		o.m_stilettoAirStallTime = 1.3f;
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

	/* Lunge is movement-affecting — replay on client and server. */
	if (tool == "lunge") {
#ifdef SERVER
		if (pl.m_stilettoGrappleActionHeld) {
			return;
		}
		pl.m_stilettoGrappleActionHeld = 1;
#endif
		Archstiletto_AbilityPress(pl);
		return;
	}

#ifdef SERVER
	/* Idempotent: cmd path and button-11 rising edge may both arrive. */
	if (pl.m_stilettoGrappleActionHeld) {
		return;
	}
	pl.m_stilettoGrappleActionHeld = 1;

	if (tool == "warpknife") {
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

	if (tool == "lunge") {
#ifdef SERVER
		if (!pl.m_stilettoGrappleActionHeld) {
			return;
		}
		pl.m_stilettoGrappleActionHeld = 0;
#endif
		Archstiletto_AbilityRelease(pl);
		return;
	}

#ifdef SERVER
	if (!pl.m_stilettoGrappleActionHeld) {
		return;
	}
	pl.m_stilettoGrappleActionHeld = 0;

	if (tool == "warpknife") {
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
	if (!HeroActions_CanAttack(pl)) {
		return;
	}
	/* Idempotent vs cmd + button-10 rising edge in the same beat. */
	if (time < pl.m_heroMeleeNextTime) {
		return;
	}
	pl.m_heroMeleeNextTime = time + 0.05;

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

	/* Guard heartbeat expiry: lost -hero_guard cannot stick forever. */
	if (pl.m_heroGuardHeld && pl.m_heroGuardExpire > 0 && time > pl.m_heroGuardExpire) {
		HeroActions_SetGuardHeld(pl, false);
	}
#endif
}

/* ===================== Phase 4+: Guard ===================== */

void
HeroActions_SetGuardHeld(entity player, bool held)
{
	ncPlayer pl;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;

#ifdef SERVER
	if (held && !pl.m_heroGuardHeld) {
		if (pl.m_activeWeapon) {
			pl.m_activeWeapon.Release();
		}
	}

	pl.m_heroGuardHeld = held;
	pl.m_heroGuardState = held ? 1 : 0;
	if (held) {
		pl.m_heroGuardExpire = time + 1.5;
	} else {
		pl.m_heroGuardExpire = 0;
	}

	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] guard=%d player=%d\n",
			held, num_for_edict(pl)));
	}
#endif
}

bool
HeroActions_CanAttack(entity player)
{
	ncPlayer pl;

	if (!player) {
		return (false);
	}

	pl = (ncPlayer)player;
	if (pl.m_heroGuardState) {
		return (false);
	}
	return (true);
}

float
HeroActions_ApplyGuardDamageRules(entity victim, entity attacker, float damage)
{
	ncPlayer pl;
	vector toAtk;
	vector fwd;
	float facing;

	if (damage <= 0) {
		return damage;
	}

	pl = (ncPlayer)victim;
	if (!pl || !pl.m_heroGuardState) {
		return damage;
	}

	/* Directional block: must roughly face the attacker. */
	if (attacker && attacker != world && attacker != victim) {
		toAtk = attacker.origin - pl.origin;
		toAtk_z = 0;
		if (vlen(toAtk) > 1) {
			fwd = anglesToForward(pl.v_angle);
			fwd_z = 0;
			facing = normalize(toAtk) * normalize(fwd);
			if (facing < 0.25) {
				return damage;
			}
		}
	}

#ifdef SERVER
	/* 50% reduction; award Drive on a successful block. */
	damage = rint(damage * 0.5);
	if (damage < 1 && damage > 0) {
		damage = 1;
	}
	HeroActions_AddDrive(pl, 50);
#endif
	return damage;
}

void
HeroActions_InitResources(entity player)
{
	ncPlayer pl;
	int dmax;
	int emax;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
	dmax = pl.GetDefInt("groove_drive_max");
	emax = pl.GetDefInt("groove_ex_max");
	if (dmax <= 0) {
		dmax = 1000;
	}
	if (emax <= 0) {
		emax = 3;
	}

	pl.m_driveMax = dmax;
	pl.m_exMax = emax;
	pl.m_drive = 0;
	pl.m_ex = 0;
	pl.m_heroWeaponMode = 0;
	HeroActions_SetGuardHeld(pl, false);
}

/* ===================== Phase 5: Weapon mode ===================== */

void
HeroActions_CycleWeaponMode(entity player)
{
	ncPlayer pl;
	int modes;
	ncWeapon w;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
#ifdef SERVER
	if (!HeroActions_CanAttack(pl)) {
		return;
	}

	w = pl.m_activeWeapon;
	modes = 0;
	if (w) {
		modes = w.GetDefInt("weapon_modes");
	}
	if (modes <= 0) {
		modes = pl.GetDefInt("hero_weapon_modes");
	}
	if (modes <= 1) {
		pl.m_heroWeaponMode = 0;
		if (autocvar_hero_actions_debug) {
			print("[hero_actions] weapon_mode unsupported (stay 0)\n");
		}
		return;
	}

	pl.m_heroWeaponMode = (pl.m_heroWeaponMode + 1) % modes;
	if (w) {
		w.OnWeaponModeChanged(pl.m_heroWeaponMode);
	}

	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] weapon_mode=%d / %d\n",
			pl.m_heroWeaponMode, modes));
	}
#endif
}

/* ===================== Phase 6: Drive / EX ===================== */

void
HeroActions_AddDrive(entity player, int amount)
{
	ncPlayer pl;

	if (!player || amount == 0) {
		return;
	}

	pl = (ncPlayer)player;
#ifdef SERVER
	pl.m_drive = bound(0, pl.m_drive + amount, pl.m_driveMax);
	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] drive=%d/%d\n", pl.m_drive, pl.m_driveMax));
	}
#endif
}

bool
HeroActions_SpendDrive(entity player, int amount)
{
	ncPlayer pl;

	if (!player || amount <= 0) {
		return (false);
	}

	pl = (ncPlayer)player;
#ifdef SERVER
	if (pl.m_drive < amount) {
		return (false);
	}
	pl.m_drive -= amount;
	return (true);
#else
	return (false);
#endif
}

void
HeroActions_AddEX(entity player, int amount)
{
	ncPlayer pl;

	if (!player || amount == 0) {
		return;
	}

	pl = (ncPlayer)player;
#ifdef SERVER
	pl.m_ex = bound(0, pl.m_ex + amount, pl.m_exMax);
	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] ex=%d/%d\n", pl.m_ex, pl.m_exMax));
	}
#endif
}

bool
HeroActions_SpendEX(entity player, int amount)
{
	ncPlayer pl;

	if (!player || amount <= 0) {
		return (false);
	}

	pl = (ncPlayer)player;
#ifdef SERVER
	if (pl.m_ex < amount) {
		return (false);
	}
	pl.m_ex -= amount;
	return (true);
#else
	return (false);
#endif
}

bool
HeroActions_CanUseAction(entity player, string actionId)
{
	ncPlayer pl;

	if (!player || !STRING_SET(actionId)) {
		return (false);
	}

	pl = (ncPlayer)player;
	if (pl.health <= 0 || pl.HasVFlags(VFL_FAKESPEC)) {
		return (false);
	}
	if (pl.m_heroGuardState) {
		return (false);
	}
	if (actionId == "drive_pulse") {
		return (pl.m_drive >= 200);
	}
	if (actionId == "ex_pulse") {
		return (pl.m_ex >= 1);
	}
	return (false);
}

/* ===================== Phase 7: Slot protocol ===================== */

void
HeroActions_RequestSlot(entity player, int slot, string context)
{
	ncPlayer pl;
	string key;
	string actionId;
	float now;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
#ifdef SERVER
	now = time;
	if (now < pl.m_heroActionNextTime) {
		if (autocvar_hero_actions_debug) {
			print("[hero_actions] slot rate-limited\n");
		}
		return;
	}

	if (slot < 0 || slot > 2) {
		return;
	}
	if (pl.health <= 0 || pl.HasVFlags(VFL_FAKESPEC)) {
		return;
	}
	if (!STRING_SET(context)) {
		context = "normal";
	}

	/* Resolve whitelisted action from hero def only — never from client. */
	if (context == "groove") {
		if (slot == 0) key = "groove_action_z";
		else if (slot == 1) key = "groove_action_x";
		else key = "groove_action_c";
	} else {
		if (slot == 0) key = "groove_normal_action_z";
		else if (slot == 1) key = "groove_normal_action_x";
		else key = "groove_normal_action_c";
	}

	actionId = pl.GetDefString(key);
	if (!STRING_SET(actionId)) {
		if (autocvar_hero_actions_debug) {
			print(sprintf("[hero_actions] empty action slot=%d ctx=%s\n", slot, context));
		}
		return;
	}

	/* Whitelist */
	if (actionId != "drive_pulse" && actionId != "ex_pulse") {
		if (autocvar_hero_actions_debug) {
			print(sprintf("[hero_actions] rejected action '%s'\n", actionId));
		}
		return;
	}

	if (!HeroActions_CanUseAction(pl, actionId)) {
		return;
	}

	if (actionId == "drive_pulse") {
		if (!HeroActions_SpendDrive(pl, 200)) {
			return;
		}
		pl.AddVelocity(anglesToForward(pl.v_angle) * 320);
	} else if (actionId == "ex_pulse") {
		if (!HeroActions_SpendEX(pl, 1)) {
			return;
		}
		if (pl.health < pl.max_health) {
			pl.SetHealth(min(pl.max_health, pl.health + 1));
		}
	}

	pl.m_heroActionNextTime = now + 0.35;

	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] ran '%s' slot=%d ctx=%s\n",
			actionId, slot, context));
	}
#endif
}

#ifdef CLIENT
void
HeroActions_PublishHud(entity player)
{
	ncPlayer pl;
	int speed;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
	/* Publish from the predicted CSQC player; these values change per-frame. */
	/* Horizontal Quake units/sec (same scale as classic speedometers). */
	speed = floor(sqrt(pl.velocity[0] * pl.velocity[0] + pl.velocity[1] * pl.velocity[1]));
	cvar_set("webcore_hud_speed", itos(speed));
	cvar_set("webcore_hud_charges", itos(pl.m_stilettoGrappleCharges));
	if (pl.m_activeWeapon && pl.m_activeWeapon._isWeapon) {
		cvar_set("webcore_hud_clip", itos(pl.m_activeWeapon.GetClip()));
		cvar_set("webcore_hud_ammo_max", itos(pl.m_activeWeapon.GetClipSize()));
	} else {
		cvar_set("webcore_hud_clip", "0");
		cvar_set("webcore_hud_ammo_max", "0");
	}
	cvar_set("webcore_hud_health", itos(floor(pl.health)));
	cvar_set("webcore_hud_health_max", itos(floor(pl.max_health)));
	cvar_set("webcore_hud_drive", ftos(pl.m_drive));
	cvar_set("webcore_hud_drive_max", ftos(pl.m_driveMax));
	cvar_set("webcore_hud_ex", ftos(pl.m_ex));
	cvar_set("webcore_hud_ex_max", ftos(pl.m_exMax));
	cvar_set("webcore_hud_guard", ftos(pl.m_heroGuardState));
	cvar_set("webcore_hud_mode", ftos(pl.m_heroWeaponMode));
}
#endif

