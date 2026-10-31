/*
 * Copyright (c) 2026 sokky
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

/* Hero abilities: what every hero shares. The ten heroes' own kits are in
   hero_kits.qc. A prototype: everything is server-side rules code, with
   Half-Life models and sprites standing in, and numbers that are first
   guesses.

   - Keys: impulse 21 the tool (C), 22 ability 1 (G), 23 ability 2 (X),
     24 henshin (Z), 25 the form's exclusive move (V). config.cfg binds them.
   - Energy (0 to 100) is the shared pool and only pays for henshin.
     Armour is Energy in hero mode: any armour a hero gets (batteries, the
     shop, the XP mod's armour skills) turns into Energy one for one.
   - Barrier is the armour stat now: it takes all damage before health
     (coop_hero_base sets armorProtection near 0), up to 75, 50 or 25 by
     hero_weight. Only Commanders, henshin and Planner emitters give it.
   - Henshin needs coop_henshinCost Energy, then drains coop_henshinDrain a
     second until it runs out or Z is pressed again. It fills Barrier, and
     the form's exclusive move (V) can be used once per transformation.
   - Swap at checkpoints: between waves a new pick applies at once, where
     the player stands. Whatever a player placed is destroyed when they
     change hero (the TF2 Engineer rule).
   - The HUD is two text channels: the hero line (1) and notices (2). */

/* && and || stop at the first answer from here on (the kits guard array
   indexes that way) */
#pragma flag enable lo

var float autocvar_coop_henshinCost = 50;
var float autocvar_coop_henshinDrain = 2.5;	/* Energy a second while transformed */
var float autocvar_coop_energyPerKill = 0;	/* Energy for each kill, 0: pickups only */
var bool autocvar_coop_heroAimTest = false;	/* tests, with sv_cheats: human players' view follows the nearest foe */

#ifndef INPUT_PRIMARY
#define INPUT_PRIMARY 0x00000001 /* INPUT_BUTTON0, see src/shared/input/input.h */
#endif

#define HERO_ENERGYMAX 100
#define HERO_HUDCHANNEL 1i
#define HERO_NOTICECHANNEL 2i

enum
{
	HL_NONE,
	HL_DISPATCH,
	HL_CHOIR,
	HL_BULKHEAD,
	HL_KETTLE,
	HL_VECTOR,
	HL_STRAY,
	HL_LEDGER,
	HL_TRIPWIRE,
	HL_LONGHAND,
	HL_MANTIS
};

enum
{
	AB_TOOL,
	AB_ONE,
	AB_TWO,
	AB_HENSHIN,
	AB_EX
};

/* per player slot */
int g_hLogic[COOP_MAXPLAYERS];
string g_hClass[COOP_MAXPLAYERS];	/* the class they last spawned as, zoned */
float g_hEnergy[COOP_MAXPLAYERS];
float g_hBarrier[COOP_MAXPLAYERS];	/* the armour we gave: more than this is a pickup */
float g_hBarrierCap[COOP_MAXPLAYERS];
bool g_hHenshin[COOP_MAXPLAYERS];
float g_hLiteUntil[COOP_MAXPLAYERS];	/* a partial henshin given by Choir's Sync */
bool g_hExUsed[COOP_MAXPLAYERS];
float g_hReady1[COOP_MAXPLAYERS];	/* when ability 1 is ready */
float g_hReady2[COOP_MAXPLAYERS];
float g_hReadyT[COOP_MAXPLAYERS];	/* the tool */
float g_hRes[COOP_MAXPLAYERS];		/* the private resource: pressure, stock, prep, study */
float g_hRes2[COOP_MAXPLAYERS];
float g_hUntil[COOP_MAXPLAYERS];	/* a running action (dash, stance, channel) ends */
float g_hUntil2[COOP_MAXPLAYERS];
entity g_hTarget[COOP_MAXPLAYERS];
entity g_hTarget2[COOP_MAXPLAYERS];
vector g_hVec[COOP_MAXPLAYERS];
float g_hLastHealth[COOP_MAXPLAYERS];	/* health + Barrier last frame, to see damage taken */
float g_hHurtTime[COOP_MAXPLAYERS];	/* when they last took damage */
float g_hFireTime[COOP_MAXPLAYERS];	/* when they last held attack */
float g_hFirePress[COOP_MAXPLAYERS];	/* when they last pressed it */
bool g_hFireHeld[COOP_MAXPLAYERS];
float g_hHudNext[COOP_MAXPLAYERS];

/* ---- helpers --------------------------------------------------------------- */

int
Hero_LogicOf(string def)
{
	switch (entityDef.GetString(def, "hero_logic")) {
	case "dispatch": return (HL_DISPATCH);
	case "choir": return (HL_CHOIR);
	case "bulkhead": return (HL_BULKHEAD);
	case "kettle": return (HL_KETTLE);
	case "vector": return (HL_VECTOR);
	case "stray": return (HL_STRAY);
	case "ledger": return (HL_LEDGER);
	case "tripwire": return (HL_TRIPWIRE);
	case "longhand": return (HL_LONGHAND);
	case "mantis": return (HL_MANTIS);
	}

	return (HL_NONE);
}

/* a hero who can use abilities now */
bool
Hero_Active(entity pl)
{
	int slot = Coop_Slot(pl);
	return (g_coopHeroes && slot >= 0i && is.Alive(pl) && g_hLogic[slot] != HL_NONE) ? true : false;
}

bool
Hero_InForm(int slot)
{
	return (g_hHenshin[slot] || time < g_hLiteUntil[slot]) ? true : false;
}

void
Hero_HudText(entity pl, int channel, string text, float x, float y, vector col, float hold)
{
	WriteByte(MSG_MULTICAST, SVC_CGAMEPACKET);
	WriteByte(MSG_MULTICAST, EV_TEXT_STRING);
	WriteByte(MSG_MULTICAST, channel);
	WriteString(MSG_MULTICAST, text);
	WriteFloat(MSG_MULTICAST, x);
	WriteFloat(MSG_MULTICAST, y);
	WriteByte(MSG_MULTICAST, 0);
	WriteByte(MSG_MULTICAST, col[0]);
	WriteByte(MSG_MULTICAST, col[1]);
	WriteByte(MSG_MULTICAST, col[2]);
	WriteByte(MSG_MULTICAST, 255);
	WriteByte(MSG_MULTICAST, 255);
	WriteByte(MSG_MULTICAST, 255);
	WriteFloat(MSG_MULTICAST, 0.0f);
	WriteFloat(MSG_MULTICAST, 0.1f);
	WriteFloat(MSG_MULTICAST, hold);
	WriteFloat(MSG_MULTICAST, 0.1f);
	msg_entity = pl;
	multicast([0,0,0], MULTICAST_ONE_R);
}

/* a short line in the middle of the screen */
void
Hero_Notice(entity pl, string text)
{
	if (is.Bot(pl)) {
		return;
	}

	Hero_HudText(pl, HERO_NOTICECHANNEL, text, -1, 0.68, [255, 163, 26], 1.5f);
}

/* friendly monsters (scientists, guards) are left alone by abilities */
bool
Hero_IsFoe(entity e)
{
	if (!e || !(e.flags & FL_MONSTER) || e.health <= 0 || e.takedamage == DAMAGE_NO) {
		return (false);
	}

	if (e.team == COOP_PLAYERTEAM) {
		return (false);
	}

	switch (e.classname) {
	case "monster_barney":
	case "monster_scientist":
	case "monster_sitting_scientist":
	case "monster_gman":
	case "monster_otis":
		return (false);
	}

	return (true);
}

vector
Hero_Center(entity e)
{
	return ((e.absmin + e.absmax) * 0.5f);
}

/* damage from a hero to one thing: a radius of one around its centre */
void
Hero_Hurt(entity target, float amount, entity attacker)
{
	if (!target || target.health <= 0 || amount < 1) {
		return;
	}

	combat.RadiusDamage(Hero_Center(target), 1, (int)amount, (int)amount, attacker, "");
}

/* damage to every foe in a radius, falling off to half at the edge */
void
Hero_HurtRadius(vector org, float radius, float amount, entity attacker)
{
	for (entity e = findradius(org, radius); e; e = e.chain) {
		if (Hero_IsFoe(e)) {
			float frac = 1.0f - (vlen(Hero_Center(e) - org) / radius) * 0.5f;
			Hero_Hurt(e, amount * frac, attacker);
		}
	}
}

void
Hero_Knock(entity e, vector push)
{
	if (e.flags & FL_ONGROUND) {
		e.flags &= ~FL_ONGROUND;
		ents.Input(e, "SetOrigin", vtos(e.origin + [0, 0, 2]), world);
	}

	e.velocity += push;
}

/* the player's eye and aim */
vector
Hero_Eye(entity pl)
{
	return (pl.origin + pl.view_ofs);
}

vector
Hero_AimDir(entity pl)
{
	makevectors(pl.v_angle);
	return (v_forward);
}

/* the foe under the crosshair, or world */
entity
Hero_AimedFoe(entity pl, float range)
{
	vector eye = Hero_Eye(pl);
	traceline(eye, eye + Hero_AimDir(pl) * range, MOVE_NORMAL, pl);
	return (Hero_IsFoe(trace_ent) ? trace_ent : world);
}

/* the nearest foe in front of pl within range and a cone (dot) */
entity
Hero_FoeInFront(entity pl, float range, float minDot)
{
	entity best = world;
	float bestDist = range;
	vector dir = Hero_AimDir(pl);

	dir[2] = 0;
	dir = normalize(dir);

	for (entity e = findradius(pl.origin, range); e; e = e.chain) {
		vector to;

		if (!Hero_IsFoe(e)) {
			continue;
		}

		to = Hero_Center(e) - Hero_Eye(pl);
		to[2] = 0;

		if (normalize(to) * dir < minDot || vlen(to) > bestDist) {
			continue;
		}

		bestDist = vlen(to);
		best = e;
	}

	return (best);
}

/* a spot on the floor under the crosshair, up to range away */
vector
Hero_AimFloor(entity pl, float range)
{
	vector eye = Hero_Eye(pl);
	traceline(eye, eye + Hero_AimDir(pl) * range, MOVE_NOMONSTERS, pl);
	vector spot = trace_endpos - Hero_AimDir(pl) * 8;
	traceline(spot, spot - [0, 0, 512], MOVE_NOMONSTERS, pl);
	return (trace_endpos);
}

/* points a foe at pl: everyone else is notarget for a moment, and the
   horde input makes it pick the nearest player it may target */
void
Hero_Taunt(entity foe, entity pl)
{
	float had[COOP_MAXPLAYERS];

	if (!Hero_IsFoe(foe) || !pl || !is.Alive(pl)) {
		return;
	}

	for (entity p = world; (p = next.Player(p));) {
		int s = Coop_Slot(p);

		if (s < 0i || p == pl) {
			continue;
		}

		had[s] = p.flags & FL_NOTARGET;
		p.flags |= FL_NOTARGET;
	}

	ents.Input(foe, "HordeOn", "", pl);

	for (entity p = world; (p = next.Player(p));) {
		int s = Coop_Slot(p);

		if (s >= 0i && p != pl && !had[s]) {
			p.flags &= ~FL_NOTARGET;
		}
	}
}

/* ---- stuns: the monster's AI stops, and starts again later ------------------ */

#define HERO_MAXSTUNS 64

entity g_stunEnt[HERO_MAXSTUNS];
float g_stunUntil[HERO_MAXSTUNS];

bool
Hero_IsStunned(entity e)
{
	for (int i = 0i; i < HERO_MAXSTUNS; i++) {
		if (g_stunEnt[i] == e) {
			return (true);
		}
	}

	return (false);
}

void
Hero_Stun(entity e, float secs)
{
	int free = -1i;

	if (!Hero_IsFoe(e)) {
		return;
	}

	for (int i = 0i; i < HERO_MAXSTUNS; i++) {
		if (g_stunEnt[i] == e) {
			g_stunUntil[i] = max(g_stunUntil[i], time + secs);
			return;
		}

		if (!g_stunEnt[i] && free < 0i) {
			free = i;
		}
	}

	if (free < 0i) {
		return;
	}

	g_stunEnt[free] = e;
	g_stunUntil[free] = time + secs;
	e.velocity = [0, 0, 0];
	ents.Input(e, "Sleep", "", world);
}

void
Hero_StunThink(void)
{
	for (int i = 0i; i < HERO_MAXSTUNS; i++) {
		entity e = g_stunEnt[i];

		if (!e) {
			continue;
		}

		/* a dead monster's own death code owns it now */
		if (e.health <= 0 || !(e.flags & FL_MONSTER)) {
			g_stunEnt[i] = world;
			continue;
		}

		if (time >= g_stunUntil[i]) {
			g_stunEnt[i] = world;
			ents.Input(e, "Wake", "", world);
		}
	}
}

/* ---- placed things: markers, doors, caches, pads, mines, drones ------------ */

#define HERO_MAXPLACE 128

enum
{
	PK_NONE,
	PK_ORDER,	/* Dispatch: data 0 hold, 1 push */
	PK_DRONE,	/* Dispatch: Courier */
	PK_DOOR,	/* Bulkhead: the planted door */
	PK_DOORWING,	/* Bulkhead: Lockdown's side walls */
	PK_RACKET,	/* Stray */
	PK_CACHE,	/* Ledger: data has the revive kit */
	PK_PAD,		/* Ledger */
	PK_MINE,	/* Tripwire */
	PK_SNARE,	/* Tripwire */
	PK_SPRITE	/* a marker that follows g_placeTarget (beacons, weak points) */
};

entity g_placeEnt[HERO_MAXPLACE];
entity g_placeOwner[HERO_MAXPLACE];
int g_placeKind[HERO_MAXPLACE];
float g_placeExpire[HERO_MAXPLACE];	/* 0: until removed */
float g_placeBorn[HERO_MAXPLACE];
float g_placeData[HERO_MAXPLACE];
float g_placeData2[HERO_MAXPLACE];
vector g_placeVec[HERO_MAXPLACE];
entity g_placeTarget[HERO_MAXPLACE];
float g_placeUsedBy[HERO_MAXPLACE];	/* bit per player slot (first 24) */

void
Hero_Unplace(int i)
{
	if (g_placeEnt[i]) {
		remove(g_placeEnt[i]);
	}

	g_placeEnt[i] = world;
	g_placeOwner[i] = world;
	g_placeKind[i] = PK_NONE;
	g_placeTarget[i] = world;
}

/* how many of kind pl has placed */
int
Hero_PlaceCount(entity pl, int kind)
{
	int n = 0i;

	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] == kind && g_placeOwner[i] == pl) {
			n++;
		}
	}

	return (n);
}

/* removes pl's oldest of kind */
void
Hero_UnplaceOldest(entity pl, int kind)
{
	int oldest = -1i;

	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] == kind && g_placeOwner[i] == pl) {
			if (oldest < 0i || g_placeBorn[i] < g_placeBorn[oldest]) {
				oldest = i;
			}
		}
	}

	if (oldest >= 0i) {
		Hero_Unplace(oldest);
	}
}

void
Hero_UnplaceAll(entity pl, int kind)
{
	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeOwner[i] == pl && (kind == PK_NONE || g_placeKind[i] == kind)) {
			Hero_Unplace(i);
		}
	}
}

/* is there a kind (anyone's, or not pl's when others is set) within dist */
int
Hero_PlaceNear(vector org, int kind, float dist, entity pl, bool others)
{
	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] != kind || !g_placeEnt[i]) {
			continue;
		}

		if (others && g_placeOwner[i] == pl) {
			continue;
		}

		if (vlen(g_placeEnt[i].origin - org) < dist) {
			return (i);
		}
	}

	return (-1i);
}

/* moves a placed thing: through the game's own input, so the move is
   sent to clients */
void
Hero_Move(entity e, vector org)
{
	if (e.classname == "jtf_placed") {
		setorigin(e, org);
	} else {
		ents.Input(e, "SetOrigin", vtos(org), world);
	}
}

/* spawns a placed thing that looks like the def look; returns its index,
   or -1 when full */
int
Hero_Place(entity pl, int kind, string look, vector org, float life)
{
	entity e;

	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] != PK_NONE) {
			continue;
		}

		/* a look (hero_visuals.def) has to be a game entity to be drawn */
		if (look != "") {
			e = ents.Create(look, org);
		} else {
			e = spawn();
			e.classname = "jtf_placed";
		}

		e.owner = pl;
		e.solid = SOLID_NOT;
		e.movetype = MOVETYPE_NONE;
		setorigin(e, org);
		g_placeEnt[i] = e;
		g_placeOwner[i] = pl;
		g_placeKind[i] = kind;
		g_placeBorn[i] = time;
		g_placeExpire[i] = (life > 0) ? time + life : 0;
		g_placeData[i] = 0;
		g_placeData2[i] = 0;
		g_placeVec[i] = [0, 0, 0];
		g_placeTarget[i] = world;
		g_placeUsedBy[i] = 0;
		return (i);
	}

	return (-1i);
}

/* a sprite that rides on a target; one per (owner, kind, target) */
int
Hero_PlaceSprite(entity pl, entity target, string spr, float life, vector offset)
{
	int i = Hero_Place(pl, PK_SPRITE, spr, target.origin + offset, life);

	if (i >= 0i) {
		g_placeTarget[i] = target;
		g_placeVec[i] = offset;
	}

	return (i);
}

void
Hero_UnplaceSpriteOn(entity pl, entity target)
{
	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] == PK_SPRITE && g_placeOwner[i] == pl && (target == world || g_placeTarget[i] == target)) {
			Hero_Unplace(i);
		}
	}
}

/* ---- Energy and Barrier ------------------------------------------------------ */

void
Hero_AddEnergy(entity pl, float amount)
{
	int slot = Coop_Slot(pl);

	if (slot >= 0i) {
		g_hEnergy[slot] = bound(0, g_hEnergy[slot] + amount, HERO_ENERGYMAX);
	}
}

void
Hero_AddBarrier(entity pl, float amount)
{
	int slot = Coop_Slot(pl);
	float now;

	if (slot < 0i || !is.Alive(pl) || Hero_OfKit(pl.classname) < 0i) {
		return;
	}

	now = min(actor.GetArmor(pl), g_hBarrier[slot]);
	g_hBarrier[slot] = bound(0, now + amount, g_hBarrierCap[slot]);
	ents.Input(pl, "SetArmor", ftos(g_hBarrier[slot]), pl);
}

/* any armour beyond the Barrier we gave is Energy; damage lowers the Barrier */
void
Hero_ArmorThink(entity pl, int slot)
{
	float armor = actor.GetArmor(pl);

	if (armor > g_hBarrier[slot] + 0.5f) {
		Hero_AddEnergy(pl, armor - g_hBarrier[slot]);
		ents.Input(pl, "SetArmor", ftos(g_hBarrier[slot]), pl);
	} else if (armor < g_hBarrier[slot]) {
		g_hBarrier[slot] = armor;
	}
}

float
Hero_BarrierCap(string def)
{
	switch (entityDef.GetString(def, "hero_weight")) {
	case "heavy": return (75);
	case "light": return (25);
	}

	return (50);
}

bool g_hGod[COOP_MAXPLAYERS];	/* we gave them god mode, and take it back */

/* can't be hurt, for a moment (Rush, Reap). God mode, not takedamage: a
   player who can't take damage counts as dead to the game */
void
Hero_Untouchable(entity pl, bool on)
{
	int slot = Coop_Slot(pl);

	if (slot < 0i) {
		return;
	}

	if (on && !(pl.flags & FL_GODMODE)) {
		pl.flags |= FL_GODMODE;
		g_hGod[slot] = true;
	} else if (!on && g_hGod[slot]) {
		pl.flags &= ~FL_GODMODE;
		g_hGod[slot] = false;
	}
}

/* ---- the hero's lifecycle ------------------------------------------------- */

void Kit_Spawned(entity pl, int slot);	/* hero_kits.qc */
void Kit_Think(entity pl, int slot);
void Kit_Use(entity pl, int slot, int ab);
void Kit_FormEnded(entity pl, int slot);
void Kit_FormStarted(entity pl, int slot);
void Kit_Killed(entity pl, int slot);
void Kit_NPCKilled(entity pl, int slot, entity npc, entity attacker);
string Kit_Status(entity pl, int slot);
void Kit_AnyThink(entity pl, int slot);
void Kit_DeadThink(entity pl, int slot);
void Kit_FieldReviveInput(entity pl);

void
Hero_ResetState(int slot)
{
	g_hHenshin[slot] = false;
	g_hLiteUntil[slot] = 0;
	g_hExUsed[slot] = false;
	g_hReady1[slot] = 0;
	g_hReady2[slot] = 0;
	g_hReadyT[slot] = 0;
	g_hRes[slot] = 0;
	g_hRes2[slot] = 0;
	g_hUntil[slot] = 0;
	g_hUntil2[slot] = 0;
	g_hTarget[slot] = world;
	g_hTarget2[slot] = world;
	g_hVec[slot] = [0, 0, 0];
	g_hBarrier[slot] = 0;
}

/* every spawn (and revive). A different class than last time is a swap:
   what they placed goes, and their private resource starts over. Energy
   is the shared pool and carries over. */
void
Hero_AbilitySpawned(entity pl)
{
	int slot = Coop_Slot(pl);
	bool swapped;

	if (slot < 0i) {
		return;
	}

	swapped = (g_hClass[slot] != pl.classname) ? true : false;

	if (swapped) {
		Hero_UnplaceAll(pl, PK_NONE);

		if (g_hClass[slot]) {
			strunzone(g_hClass[slot]);
		}

		g_hClass[slot] = strzone(pl.classname);
	}

	g_hLogic[slot] = g_coopHeroes ? Hero_LogicOf(pl.classname) : HL_NONE;

	/* a revive keeps the private resource, a swap or a death doesn't */
	Hero_ResetState(slot);
	g_hBarrierCap[slot] = Hero_BarrierCap(pl.classname);
	g_hLastHealth[slot] = pl.health;

	if (!g_coopHeroes || Hero_OfKit(pl.classname) < 0i) {
		return;
	}

	/* room for pickups above the Barrier: they become Energy */
	ents.Input(pl, "SetMaxArmor", "200", pl);
	ents.Input(pl, "SetArmor", "0", pl);
	pl.flags &= ~FL_NOTARGET;
	Hero_Untouchable(pl, false);

	if (g_hLogic[slot] != HL_NONE) {
		Kit_Spawned(pl, slot);
	}
}

void
Hero_HenshinEnd(entity pl, int slot)
{
	if (!g_hHenshin[slot]) {
		return;
	}

	g_hHenshin[slot] = false;
	Kit_FormEnded(pl, slot);
	Hero_Notice(pl, "Henshin over");
	sound(pl, CHAN_ITEM, "debris/beamstart4.wav", 1, ATTN_NORM);
}

void
Hero_HenshinStart(entity pl, int slot)
{
	if (g_hEnergy[slot] < autocvar_coop_henshinCost) {
		Hero_Notice(pl, sprintf("Henshin needs %d Energy", autocvar_coop_henshinCost));
		return;
	}

	g_hHenshin[slot] = true;
	g_hExUsed[slot] = false;
	g_hEnergy[slot] -= autocvar_coop_henshinCost * 0.5f;
	Hero_AddBarrier(pl, g_hBarrierCap[slot]);
	ents.Input(pl, "Shockwave", "sprites/shockwave.spr 120 0 4 12 255 163 26 200", pl);
	sound(pl, CHAN_ITEM, "debris/beamstart1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, sprintf("HENSHIN: %s form", entityDef.GetString(pl.classname, "hero_form")));
	Kit_FormStarted(pl, slot);
}

/* impulse 21 to 25 */
bool
Hero_AbilityImpulse(entity pl, float num)
{
	int slot = Coop_Slot(pl);

	if (num < 21 || num > 25) {
		return (false);
	}

	if (!Hero_Active(pl)) {
		return (true);
	}

	switch (num) {
	case 21:
		Kit_Use(pl, slot, AB_TOOL);
		break;
	case 22:
		Kit_Use(pl, slot, AB_ONE);
		break;
	case 23:
		Kit_Use(pl, slot, AB_TWO);
		break;
	case 24:
		if (g_hHenshin[slot]) {
			Hero_HenshinEnd(pl, slot);
		} else {
			Hero_HenshinStart(pl, slot);
		}
		break;
	case 25:
		if (!Hero_InForm(slot)) {
			Hero_Notice(pl, sprintf("%s only works in %s form", entityDef.GetString(pl.classname, "hero_ex"),
				entityDef.GetString(pl.classname, "hero_form")));
		} else if (g_hExUsed[slot]) {
			Hero_Notice(pl, "Once per henshin");
		} else {
			Kit_Use(pl, slot, AB_EX);
		}
		break;
	}

	return (true);
}

/* every input frame: the fire button, for kits that care when it's held */
void
Hero_AbilityInput(entity pl)
{
	int slot = Coop_Slot(pl);
	float buttons;

	if (slot < 0i) {
		return;
	}

	buttons = (float)externvalue(0, "input_buttons");

	if (buttons & INPUT_PRIMARY) {
		if (!g_hFireHeld[slot]) {
			g_hFirePress[slot] = time;
		}

		g_hFireHeld[slot] = true;
		g_hFireTime[slot] = time;
	} else {
		g_hFireHeld[slot] = false;
	}

	Kit_FieldReviveInput(pl);
}

/* cooldown text for the HUD */
string
Hero_Ready(float when)
{
	if (time >= when) {
		return ("ready");
	}

	return (sprintf("%ds", ceil(when - time)));
}

void
Hero_Hud(entity pl, int slot)
{
	string text;
	string form = entityDef.GetString(pl.classname, "hero_form");

	if (is.Bot(pl) || time < g_hHudNext[slot]) {
		return;
	}

	g_hHudNext[slot] = time + 0.25f;
	text = sprintf("%s  ENERGY %d  BARRIER %d/%d\n", strtoupper(entityDef.GetString(pl.classname, "hero_name")),
		g_hEnergy[slot], g_hBarrier[slot], g_hBarrierCap[slot]);
	text = strcat(text, Kit_Status(pl, slot));

	if (g_hHenshin[slot]) {
		text = strcat(text, sprintf("\n[Z] %s form  [V] %s %s", form, entityDef.GetString(pl.classname, "hero_ex"),
			g_hExUsed[slot] ? "used" : "ready"));
	} else if (time < g_hLiteUntil[slot]) {
		text = strcat(text, sprintf("\nSynced: %s form %ds", form, ceil(g_hLiteUntil[slot] - time)));
	} else {
		text = strcat(text, sprintf("\n[Z] Henshin: %s (%d)", form, autocvar_coop_henshinCost));
	}

	Hero_HudText(pl, HERO_HUDCHANNEL, text, 0.02, 0.62, g_hHenshin[slot] ? [255, 200, 80] : [255, 163, 26], 0.4f);
}

/* every frame, for every player */
void
Hero_AbilityThink(entity pl)
{
	int slot = Coop_Slot(pl);
	float hp;

	if (!g_coopHeroes || slot < 0i || Hero_OfKit(pl.classname) < 0i) {
		return;
	}

	if (!is.Alive(pl)) {
		if (g_hHenshin[slot]) {
			g_hHenshin[slot] = false;
			Kit_FormEnded(pl, slot);
		}

		Kit_DeadThink(pl, slot);
		return;
	}

	Hero_ArmorThink(pl, slot);
	Kit_AnyThink(pl, slot);

	/* a partial henshin from Choir's Sync runs out */
	if (g_hLiteUntil[slot] > 0 && time >= g_hLiteUntil[slot]) {
		g_hLiteUntil[slot] = 0;

		if (!g_hHenshin[slot]) {
			Kit_FormEnded(pl, slot);
		}
	}

	hp = pl.health + g_hBarrier[slot];

	if (hp < g_hLastHealth[slot]) {
		g_hHurtTime[slot] = time;
	}

	if (g_hHenshin[slot]) {
		g_hEnergy[slot] -= autocvar_coop_henshinDrain * frametime;

		if (g_hEnergy[slot] <= 0) {
			g_hEnergy[slot] = 0;
			Hero_HenshinEnd(pl, slot);
		}
	}

	/* tests: aim at the nearest foe, so aimed abilities can be tried
	   without a mouse */
	if (autocvar_coop_heroAimTest && cvar("sv_cheats") && !is.Bot(pl)) {
		entity near = world;
		float nearDist = 2000;

		for (entity e = findradius(pl.origin, 2000); e; e = e.chain) {
			if (Hero_IsFoe(e) && vlen(e.origin - pl.origin) < nearDist) {
				nearDist = vlen(e.origin - pl.origin);
				near = e;
			}
		}

		if (near) {
			vector look = vectoangles(Hero_Center(near) - Hero_Eye(pl));
			look[0] = -look[0];
			pl.angles = [0, look[1], 0];
			pl.v_angle = look;
			pl.fixangle = TRUE;
		}
	}

	if (g_hLogic[slot] != HL_NONE) {
		Kit_Think(pl, slot);
		Hero_Hud(pl, slot);
	}

	/* after the kit, which may have healed or hurt */
	g_hLastHealth[slot] = pl.health + g_hBarrier[slot];
}

/* placed things that act on their own */
void Kit_PlaceThink(int i);	/* hero_kits.qc */

void
Hero_PlaceThink(void)
{
	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] == PK_NONE) {
			continue;
		}

		if (!g_placeOwner[i] || !is.Player(g_placeOwner[i]) || (g_placeExpire[i] > 0 && time >= g_placeExpire[i])) {
			Hero_Unplace(i);
			continue;
		}

		if (g_placeKind[i] == PK_SPRITE) {
			entity t = g_placeTarget[i];

			if (!t || t.health <= 0) {
				Hero_Unplace(i);
				continue;
			}

			Hero_Move(g_placeEnt[i], t.origin + g_placeVec[i]);
			continue;
		}

		Kit_PlaceThink(i);
	}
}

void
Hero_AbilityFrame(void)
{
	if (!g_coopHeroes) {
		return;
	}

	Hero_StunThink();
	Hero_PlaceThink();

	for (entity p = world; (p = next.Player(p));) {
		Hero_AbilityThink(p);
	}
}

void
Hero_AbilityKilled(entity pl)
{
	int slot = Coop_Slot(pl);

	if (!g_coopHeroes || slot < 0i || g_hLogic[slot] == HL_NONE) {
		return;
	}

	if (g_hHenshin[slot]) {
		g_hHenshin[slot] = false;
		Kit_FormEnded(pl, slot);
	}

	Kit_Killed(pl, slot);
}

void
Hero_AbilityNPCKilled(entity npc, entity attacker)
{
	if (!g_coopHeroes) {
		return;
	}

	if (autocvar_coop_energyPerKill > 0 && is.Player(attacker)) {
		Hero_AddEnergy(attacker, autocvar_coop_energyPerKill);
	}

	for (entity p = world; (p = next.Player(p));) {
		int slot = Coop_Slot(p);

		if (slot >= 0i && g_hLogic[slot] != HL_NONE && is.Alive(p)) {
			Kit_NPCKilled(p, slot, npc, attacker);
		}
	}

	/* placed things that rode on it */
	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] == PK_SPRITE && g_placeTarget[i] == npc) {
			Hero_Unplace(i);
		}
	}
}

void
Hero_AbilityDisconnect(entity pl)
{
	int slot = Coop_Slot(pl);

	Hero_UnplaceAll(pl, PK_NONE);

	if (slot >= 0i) {
		g_hLogic[slot] = HL_NONE;
		g_hEnergy[slot] = 0;

		if (g_hClass[slot]) {
			strunzone(g_hClass[slot]);
			g_hClass[slot] = __NULL__;
		}
	}
}

/* "cmd energy [n]", with sv_cheats: Energy to test henshin with */
bool
Hero_AbilityCommand(entity pl, string command)
{
	tokenize(command);

	switch (argv(0)) {
	case "places":
		for (int i = 0i; i < HERO_MAXPLACE; i++) {
			if (g_placeKind[i] != PK_NONE) {
				entity e = g_placeEnt[i];
				sprint(pl, PRINT_HIGH, sprintf("place %i kind %i %s at %v model %s mi %d solid %d\n", i, g_placeKind[i], e.classname, e.origin, e.model, e.modelindex, e.solid));
			}
		}
		return (true);
	case "energy":
		if (cvar("sv_cheats") == 0) {
			sprint(pl, PRINT_HIGH, "energy needs sv_cheats 1\n");
			return (true);
		}

		Hero_AddEnergy(pl, (argv(1) != "") ? stof(argv(1)) : HERO_ENERGYMAX);
		return (true);
	}

	return (false);
}

void
Hero_AbilityPrecache(void)
{
	string looks = "jtf_vis_hold jtf_vis_push jtf_vis_drone jtf_vis_door jtf_vis_racket jtf_vis_cache jtf_vis_pad jtf_vis_mine jtf_vis_snare jtf_vis_beacon jtf_vis_weakpoint";
	string look[16];
	int n = min((int)tokenize(looks), 16i);

	/* the precaches tokenize too */
	for (int i = 0i; i < n; i++) {
		look[i] = argv(i);
	}

	for (int i = 0i; i < n; i++) {
		precache.Entity(look[i]);
	}

	precache_model("sprites/shockwave.spr");
	precache_sound("debris/beamstart1.wav");
	precache_sound("debris/beamstart4.wav");
	precache_sound("buttons/blip1.wav");
	precache_sound("buttons/button9.wav");
	precache_sound("ambience/steamburst1.wav");
	precache_sound("garg/gar_stomp1.wav");
	precache_sound("weapons/explode3.wav");
	precache_sound("weapons/mine_activate.wav");
	precache_sound("weapons/xbow_hit1.wav");
	precache_sound("weapons/cbar_hitbod1.wav");
	precache_sound("hgrunt/gr_alert1.wav");
	precache_sound("items/smallmedkit1.wav");
	precache_sound("items/gunpickup2.wav");
	precache_sound("doors/doorstop1.wav");
	precache_sound("x/x_teleattack1.wav");
	precache_sound("weapons/rocketfire1.wav");
	precache_sound("squeek/sqk_deploy1.wav");
	precache_sound("plats/bigstop1.wav");
}
