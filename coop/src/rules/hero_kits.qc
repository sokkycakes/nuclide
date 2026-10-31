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

/* The ten prototype heroes' kits (example-heroes.md, two per genre):
   tool, two abilities, the henshin form and its exclusive move. The
   shared parts (Energy, Barrier, henshin, placed things, stuns, taunts)
   are in hero_abilities.qc. Where the design asks for something the
   rules can't do yet (a slower turn, faster fire, seeing through walls),
   the comment says so and the kit does the nearest thing it can. */

/* extra per-slot state, for the kits that need more than the shared set */
float g_steadyUntil[COOP_MAXPLAYERS];	/* Choir's Hold the Line on this player */
float g_boostUntil[COOP_MAXPLAYERS];	/* Vector's Trace on this player */
bool g_fieldKit[COOP_MAXPLAYERS];	/* carries a Ledger revive kit */
float g_windReady[COOP_MAXPLAYERS];	/* Stray's Second Wind, kept through respawns */
float g_riseAt[COOP_MAXPLAYERS];	/* Stray gets back up at this time */
vector g_riseOrigin[COOP_MAXPLAYERS];
float g_prevShot[COOP_MAXPLAYERS];	/* Longhand: the shot before the last one */
float g_lastShot[COOP_MAXPLAYERS];
bool g_stance[COOP_MAXPLAYERS];		/* Longhand's Overwatch */
float g_studySeen[COOP_MAXPLAYERS];	/* Longhand: last time the study target was under the crosshair */
float g_studyStart[COOP_MAXPLAYERS];
float g_markHealth[COOP_MAXPLAYERS];	/* the marked target's health last frame */
int g_markSprite[COOP_MAXPLAYERS];
float g_stabReady[COOP_MAXPLAYERS];	/* Mantis's backstab bonus */
bool g_reap[COOP_MAXPLAYERS];		/* Mantis: the next (or this) Execute is untargetable */
float g_kitNotice[COOP_MAXPLAYERS];	/* throttles repeated notices */

string
Kit_Key(entity pl, string key)
{
	return (entityDef.GetString(pl.classname, key));
}

/* true when the ability is ready; tells them how long otherwise */
bool
Kit_Ready(entity pl, float when, string key)
{
	if (time < when) {
		Hero_Notice(pl, sprintf("%s in %ds", Kit_Key(pl, key), ceil(when - time)));
		return (false);
	}

	return (true);
}

/* the flat direction they face */
vector
Kit_Flat(entity pl)
{
	vector dir = Hero_AimDir(pl);
	dir[2] = 0;
	return (normalize(dir));
}

float
Kit_FlatSpeed(entity e)
{
	return (vlen([e.velocity[0], e.velocity[1], 0]));
}

/* the nearest downed teammate within range of org, or world */
entity
Kit_Downed(vector org, float range, entity skip)
{
	entity best = world;
	float bestDist = range;

	for (entity p = world; (p = next.Player(p));) {
		int s = Coop_Slot(p);

		if (s < 0i || p == skip || !g_coopDown[s] || is.Alive(p)) {
			continue;
		}

		float d = vlen(g_coopDownOrigin[s] - org);

		if (d < bestDist) {
			bestDist = d;
			best = p;
		}
	}

	return (best);
}

void
Kit_Throttled(entity pl, int slot, string text)
{
	if (time >= g_kitNotice[slot]) {
		g_kitNotice[slot] = time + 1.0f;
		Hero_Notice(pl, text);
	}
}

/* a short burst of particles where a placed thing explodes */
void
Kit_Boom(vector org)
{
	te_explosion(org);
	sound(world, CHAN_AUTO, "weapons/explode3.wav", 1, ATTN_NORM);
}

/* ==== DISPATCH (Commander) ==================================================
   Orders: up to two markers (four in Operations form), placed where she
   aims. The first is Hold (Barrier builds fast), the second Push (Barrier
   builds slowly, kills inside give Energy). Another Dispatch can't place
   on a spot one already covers. Courier: a drone flies to the nearest
   downed teammate (two in form) and revives them in 3 s unless a foe is
   near it. Reroute: her Hold and Push swap places. Recall: everyone
   standing in one of her markers comes to her. */

#define ORDER_RADIUS 128
#define ORDER_HOLD 0
#define ORDER_PUSH 1

void
Dispatch_Orders(entity pl, int slot)
{
	vector spot = Hero_AimFloor(pl, 1500);
	int most = Hero_InForm(slot) ? 4i : 2i;
	int holds = 0i;
	int i;

	if (Hero_PlaceNear(spot, PK_ORDER, ORDER_RADIUS, pl, true) >= 0i) {
		Hero_Notice(pl, "Another Dispatch already covers that spot");
		return;
	}

	while (Hero_PlaceCount(pl, PK_ORDER) >= most) {
		Hero_UnplaceOldest(pl, PK_ORDER);
	}

	for (int k = 0i; k < HERO_MAXPLACE; k++) {
		if (g_placeKind[k] == PK_ORDER && g_placeOwner[k] == pl && g_placeData[k] == ORDER_HOLD) {
			holds++;
		}
	}

	/* the first is a HOLD, then they alternate */
	float type = (holds <= Hero_PlaceCount(pl, PK_ORDER) - holds) ? ORDER_HOLD : ORDER_PUSH;
	i = Hero_Place(pl, PK_ORDER, (type == ORDER_HOLD) ? "jtf_vis_hold" : "jtf_vis_push", spot + [0, 0, 32], 0);

	if (i < 0i) {
		return;
	}

	g_placeData[i] = type;
	sound(pl, CHAN_ITEM, "buttons/blip1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, (g_placeData[i] == ORDER_HOLD) ? "Order: HOLD here" : "Order: PUSH there");
}

void
Dispatch_Courier(entity pl, int slot)
{
	int sent = 0i;
	int most = Hero_InForm(slot) ? 2i : 1i;
	entity skip = world;

	if (!Kit_Ready(pl, g_hReady1[slot], "hero_ab1")) {
		return;
	}

	while (sent < most) {
		entity t = world;
		float bestDist = 99999;

		for (entity p = world; (p = next.Player(p));) {
			int s = Coop_Slot(p);

			if (s < 0i || p == skip || !g_coopDown[s] || is.Alive(p)) {
				continue;
			}

			/* one drone per body */
			bool taken = false;

			for (int k = 0i; k < HERO_MAXPLACE; k++) {
				if (g_placeKind[k] == PK_DRONE && g_placeTarget[k] == p) {
					taken = true;
				}
			}

			if (!taken && vlen(g_coopDownOrigin[s] - pl.origin) < bestDist) {
				bestDist = vlen(g_coopDownOrigin[s] - pl.origin);
				t = p;
			}
		}

		if (!t) {
			break;
		}

		int i = Hero_Place(pl, PK_DRONE, "jtf_vis_drone", Hero_Eye(pl) + [0, 0, 16], 30);

		if (i >= 0i) {
			g_placeTarget[i] = t;
			Hero_Notice(pl, sprintf("Courier on its way to %s", t.netname));
			centerprint(t, sprintf("%s sent a Courier drone to revive you", pl.netname));
			sent++;
		}

		skip = t;
	}

	if (sent == 0i) {
		Hero_Notice(pl, "Nobody is down");
		return;
	}

	g_hReady1[slot] = time + 20;
	sound(pl, CHAN_ITEM, "buttons/button9.wav", 1, ATTN_NORM);
}

void
Dispatch_Reroute(entity pl, int slot)
{
	int hold = -1i;
	int push = -1i;
	vector spot;

	if (!Kit_Ready(pl, g_hReady2[slot], "hero_ab2")) {
		return;
	}

	/* her newest HOLD and PUSH change places */
	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] != PK_ORDER || g_placeOwner[i] != pl) {
			continue;
		}

		if (g_placeData[i] == ORDER_HOLD && (hold < 0i || g_placeBorn[i] > g_placeBorn[hold])) {
			hold = i;
		} else if (g_placeData[i] == ORDER_PUSH && (push < 0i || g_placeBorn[i] > g_placeBorn[push])) {
			push = i;
		}
	}

	if (hold < 0i || push < 0i) {
		Hero_Notice(pl, "Reroute needs a HOLD and a PUSH out");
		return;
	}

	spot = g_placeEnt[hold].origin;
	Hero_Move(g_placeEnt[hold], g_placeEnt[push].origin);
	Hero_Move(g_placeEnt[push], spot);
	g_hReady2[slot] = time + 6;
	sound(pl, CHAN_ITEM, "buttons/blip1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, "Rerouted: HOLD and PUSH swapped");
}

void
Dispatch_Recall(entity pl, int slot)
{
	int n = 0i;

	for (entity p = world; (p = next.Player(p));) {
		bool inside = false;

		if (p == pl || !is.Alive(p)) {
			continue;
		}

		for (int i = 0i; i < HERO_MAXPLACE; i++) {
			if (g_placeKind[i] == PK_ORDER && g_placeOwner[i] == pl && vlen(p.origin - g_placeEnt[i].origin) < ORDER_RADIUS + 32) {
				inside = true;
			}
		}

		if (!inside) {
			continue;
		}

		float a = n * 60;
		vector spot = pl.origin + [cos(a * (M_PI / 180)) * 64, sin(a * (M_PI / 180)) * 64, 8];
		ents.Input(p, "SetOrigin", vtos(spot), pl);
		p.velocity = [0, 0, 0];
		centerprint(p, sprintf("Recalled by %s", pl.netname));
		n++;
	}

	if (n == 0i) {
		Hero_Notice(pl, "Nobody is standing in your orders");
		return;
	}

	g_hExUsed[slot] = true;
	sound(pl, CHAN_ITEM, "x/x_teleattack1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, sprintf("RECALL: %i pulled out", n));
}

void
Dispatch_PlaceThink(int i)
{
	entity owner = g_placeOwner[i];

	if (g_placeKind[i] == PK_ORDER) {
		float rate = (g_placeData[i] == ORDER_HOLD) ? 6 : 2;

		for (entity p = world; (p = next.Player(p));) {
			if (is.Alive(p) && vlen(p.origin - g_placeEnt[i].origin) < ORDER_RADIUS + 32) {
				Hero_AddBarrier(p, rate * frametime);
			}
		}

		return;
	}

	/* Courier */
	entity t = g_placeTarget[i];
	int s = Coop_Slot(t);

	if (!t || s < 0i || is.Alive(t) || !g_coopDown[s]) {
		Hero_Unplace(i);
		return;
	}

	vector dest = g_coopDownOrigin[s] + [0, 0, 40];
	vector to = dest - g_placeEnt[i].origin;
	float step = 400 * frametime;

	if (vlen(to) > step + 4) {
		Hero_Move(g_placeEnt[i], g_placeEnt[i].origin + normalize(to) * step);
		g_placeData[i] = 0;
		return;
	}

	/* reviving: a foe near the drone starts it over */
	for (entity e = findradius(g_placeEnt[i].origin, 160); e; e = e.chain) {
		if (Hero_IsFoe(e)) {
			if (g_placeData[i] > 0) {
				Hero_Notice(owner, "Courier interrupted: cover it");
			}

			g_placeData[i] = 0;
			return;
		}
	}

	g_placeData[i] += frametime;

	if (g_placeData[i] >= 3.0f) {
		Hero_Unplace(i);
		Coop_Revive(owner, t);
		return;
	}

	if (time >= g_placeData2[i]) {
		g_placeData2[i] = time + 0.25f;
		float filled = floor(g_placeData[i] / 3 * 10);
		centerprint(t, sprintf("Courier reviving you\n[%s]", strcat(substring("##########", 0, filled),
			substring("----------", 0, 10 - filled))));
	}
}

void
Dispatch_NPCKilled(entity pl, int slot, entity npc, entity attacker)
{
	if (!is.Player(attacker)) {
		return;
	}

	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] != PK_ORDER || g_placeOwner[i] != pl) {
			continue;
		}

		if (vlen(npc.origin - g_placeEnt[i].origin) < ORDER_RADIUS + 64 && vlen(attacker.origin - g_placeEnt[i].origin) < ORDER_RADIUS + 32) {
			Hero_AddEnergy(attacker, (g_placeData[i] == ORDER_PUSH) ? 5 : 2);
			return;
		}
	}
}

string
Dispatch_Status(entity pl, int slot)
{
	return (sprintf("[C] Orders %i/%i  [G] Courier %s  [X] Reroute %s", Hero_PlaceCount(pl, PK_ORDER),
		Hero_InForm(slot) ? 4i : 2i, Hero_Ready(g_hReady1[slot]), Hero_Ready(g_hReady2[slot])));
}

/* ==== CHOIR (Commander) =====================================================
   Cadence is always on: teammates in a cone in front of her (a ring in
   Chorus form) gain Barrier, the most for whoever is closest to the
   middle. A player only counts for the nearest Choir. (Faster fire isn't
   in: the rules can't change a weapon's rate.) On Your Feet: a teammate
   who fell less than 5 s ago, near her, stands at once. Hold the Line:
   teammates in the cone can't be knocked about for 4 s. Sync: everyone in
   the ring gets 10 s of their own henshin, 10 of her Energy each. */

#define CADENCE_RANGE 700
#define CADENCE_DOT 0.7

/* 0 outside her cone, up to 1 in the middle */
float
Choir_Centrality(entity choir, int cslot, entity p)
{
	vector to = p.origin - choir.origin;
	float d = vlen(to);

	if (d > CADENCE_RANGE || d < 1) {
		return (0);
	}

	if (Hero_InForm(cslot)) {
		return (1 - d / CADENCE_RANGE);
	}

	to[2] = 0;
	float dot = normalize(to) * Kit_Flat(choir);

	if (dot < CADENCE_DOT) {
		return (0);
	}

	return ((dot - CADENCE_DOT) / (1 - CADENCE_DOT));
}

/* the Choir whose cadence p is in: the nearest one that reaches */
entity
Choir_Of(entity p)
{
	entity best = world;
	float bestDist = 99999;

	for (entity c = world; (c = next.Player(c));) {
		int cs = Coop_Slot(c);

		if (c == p || cs < 0i || g_hLogic[cs] != HL_CHOIR || !is.Alive(c)) {
			continue;
		}

		if (vlen(c.origin - p.origin) < bestDist) {
			bestDist = vlen(c.origin - p.origin);
			best = c;
		}
	}

	return (best);
}

void
Choir_Think(entity pl, int slot)
{
	for (entity p = world; (p = next.Player(p));) {
		if (p == pl || !is.Alive(p) || Choir_Of(p) != pl) {
			continue;
		}

		float c = Choir_Centrality(pl, slot, p);

		if (c > 0) {
			Hero_AddBarrier(p, (2 + 8 * c) * frametime);
		}
	}
}

void
Choir_OnYourFeet(entity pl, int slot)
{
	entity t;
	int s;

	if (!Kit_Ready(pl, g_hReady1[slot], "hero_ab1")) {
		return;
	}

	t = Kit_Downed(pl.origin, 200, world);

	if (!t) {
		Hero_Notice(pl, "Nobody is down near you");
		return;
	}

	s = Coop_Slot(t);

	if (time - g_coopDownTime[s] > 5) {
		Hero_Notice(pl, "Too late for that: hold E to revive them");
		return;
	}

	Coop_Revive(pl, t);
	g_hReady1[slot] = time + 15;
	sound(pl, CHAN_VOICE, "hgrunt/gr_alert1.wav", 1, ATTN_NORM);
}

void
Choir_HoldTheLine(entity pl, int slot)
{
	int n = 0i;

	if (!Kit_Ready(pl, g_hReady2[slot], "hero_ab2")) {
		return;
	}

	for (entity p = world; (p = next.Player(p));) {
		int s = Coop_Slot(p);

		if (s < 0i || !is.Alive(p) || (p != pl && Choir_Centrality(pl, slot, p) <= 0)) {
			continue;
		}

		g_steadyUntil[s] = time + 4;

		if (p != pl) {
			centerprint(p, sprintf("%s: HOLD THE LINE", pl.netname));
		}

		n++;
	}

	g_hReady2[slot] = time + 14;
	sound(pl, CHAN_VOICE, "hgrunt/gr_alert1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, sprintf("Hold the Line: %i steady", n));
}

void
Choir_Sync(entity pl, int slot)
{
	int n = 0i;

	for (entity p = world; (p = next.Player(p));) {
		int s = Coop_Slot(p);

		if (p == pl || s < 0i || !is.Alive(p) || Choir_Centrality(pl, slot, p) <= 0) {
			continue;
		}

		if (g_hEnergy[slot] < 10) {
			break;
		}

		g_hEnergy[slot] -= 10;
		g_hLiteUntil[s] = time + 10;
		g_hExUsed[s] = false;
		Hero_AddBarrier(p, g_hBarrierCap[s]);
		centerprint(p, sprintf("%s synced you: henshin for 10 s", pl.netname));
		Kit_FormStarted(p, s);
		n++;
	}

	if (n == 0i) {
		Hero_Notice(pl, "Nobody in the ring to sync");
		return;
	}

	g_hExUsed[slot] = true;
	sound(pl, CHAN_ITEM, "debris/beamstart1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, sprintf("SYNC: %i transformed", n));
}

string
Choir_Status(entity pl, int slot)
{
	int n = 0i;

	for (entity p = world; (p = next.Player(p));) {
		if (p != pl && is.Alive(p) && Choir_Of(p) == pl && Choir_Centrality(pl, slot, p) > 0) {
			n++;
		}
	}

	return (sprintf("Cadence: %i backed  [G] On Your Feet %s  [X] Hold the Line %s", n, Hero_Ready(g_hReady1[slot]),
		Hero_Ready(g_hReady2[slot])));
}

/* ==== BULKHEAD (Wall) =======================================================
   The Door: carried in front of him, it stops monsters and their shots
   (C lowers or raises it). Set: plants it as a barricade, or picks it up
   when he's next to it. Breach: a short ram with the door raised that
   shoves everything in front and stuns the first thing it hits. Vault
   form: a bigger door, and teammates by a planted one gain Barrier.
   Lockdown: a planted door grows a wall on each side until the form
   ends. (The narrower turn and one-way shooting aren't in.) */

int
Bulkhead_Door(entity pl, float planted)
{
	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] == PK_DOOR && g_placeOwner[i] == pl && g_placeData[i] == planted) {
			return (i);
		}
	}

	return (-1i);
}

void
Bulkhead_DoorSize(int i, bool big)
{
	entity d = g_placeEnt[i];

	d.solid = SOLID_BBOX;

	if (big) {
		setsize(d, [-32, -32, 0], [32, 32, 88]);
	} else {
		setsize(d, [-20, -20, 0], [20, 20, 72]);
	}
}

void
Bulkhead_Raise(entity pl, int slot)
{
	int i = Hero_Place(pl, PK_DOOR, "jtf_vis_door", pl.origin, 0);

	if (i >= 0i) {
		g_placeData[i] = 0;
		Bulkhead_DoorSize(i, Hero_InForm(slot));
	}
}

void
Bulkhead_Spawned(entity pl, int slot)
{
	int carried = Bulkhead_Door(pl, 0);

	if (carried >= 0i) {
		Hero_Unplace(carried);
	}

	if (Bulkhead_Door(pl, 1) < 0i) {
		Bulkhead_Raise(pl, slot);
	}
}

void
Bulkhead_Toggle(entity pl, int slot)
{
	int carried = Bulkhead_Door(pl, 0);

	if (carried >= 0i) {
		Hero_Unplace(carried);
		Hero_Notice(pl, "Door lowered");
		return;
	}

	if (Bulkhead_Door(pl, 1) >= 0i) {
		Hero_Notice(pl, "Your door is planted: walk to it and press G");
		return;
	}

	Bulkhead_Raise(pl, slot);
	Hero_Notice(pl, "Door raised");
}

void
Bulkhead_Set(entity pl, int slot)
{
	int carried = Bulkhead_Door(pl, 0);
	int planted = Bulkhead_Door(pl, 1);

	if (planted >= 0i) {
		if (vlen(g_placeEnt[planted].origin - pl.origin) > 128) {
			Hero_Notice(pl, "Too far from your door to pick it up");
			return;
		}

		Hero_Unplace(planted);
		Hero_UnplaceAll(pl, PK_DOORWING);
		Bulkhead_Raise(pl, slot);
		sound(pl, CHAN_ITEM, "items/gunpickup2.wav", 1, ATTN_NORM);
		Hero_Notice(pl, "Door picked up");
		return;
	}

	if (carried < 0i) {
		Hero_Notice(pl, "Raise the door first (C)");
		return;
	}

	g_placeData[carried] = 1;
	traceline(g_placeEnt[carried].origin + [0, 0, 32], g_placeEnt[carried].origin - [0, 0, 256], MOVE_NOMONSTERS, g_placeEnt[carried]);
	Hero_Move(g_placeEnt[carried], trace_endpos);
	sound(pl, CHAN_ITEM, "doors/doorstop1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, "Door SET");
}

void
Bulkhead_Breach(entity pl, int slot)
{
	if (Bulkhead_Door(pl, 0) < 0i) {
		Hero_Notice(pl, "Breach needs the door raised (C)");
		return;
	}

	if (!Kit_Ready(pl, g_hReady2[slot], "hero_ab2")) {
		return;
	}

	g_hReady2[slot] = time + 8;
	g_hUntil[slot] = time + 0.35f;
	g_hTarget2[slot] = world;	/* the first thing hit, stunned */
	sound(pl, CHAN_ITEM, "garg/gar_stomp1.wav", 1, ATTN_NORM);
}

void
Bulkhead_Lockdown(entity pl, int slot)
{
	int planted = Bulkhead_Door(pl, 1);
	entity d;
	vector right;

	if (planted < 0i) {
		Hero_Notice(pl, "Lockdown needs the door planted");
		return;
	}

	d = g_placeEnt[planted];
	makevectors([0, d.angles[1], 0]);
	right = v_right;

	for (float side = -1; side <= 1; side += 2) {
		int w = Hero_Place(pl, PK_DOORWING, "jtf_vis_door", d.origin + right * side * 64, 0);

		if (w >= 0i) {
			g_placeEnt[w].angles = d.angles;
			Bulkhead_DoorSize(w, true);
			w = Hero_Place(pl, PK_DOORWING, "jtf_vis_door", d.origin + right * side * 128, 0);

			if (w >= 0i) {
				g_placeEnt[w].angles = d.angles;
				Bulkhead_DoorSize(w, true);
			}
		}
	}

	g_hExUsed[slot] = true;
	sound(pl, CHAN_ITEM, "plats/bigstop1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, "LOCKDOWN: the corridor is sealed");
}

void
Bulkhead_Think(entity pl, int slot)
{
	int carried = Bulkhead_Door(pl, 0);
	vector fwd = Kit_Flat(pl);

	if (carried >= 0i) {
		entity d = g_placeEnt[carried];
		Hero_Move(d, pl.origin + fwd * 48 + [0, 0, -36]);	/* on the floor, under his sights */
		d.angles = [0, vectoyaw(fwd), 0];
	}

	/* the Breach ram */
	if (time < g_hUntil[slot]) {
		pl.velocity = fwd * 650 + [0, 0, pl.velocity[2]];

		for (entity e = findradius(pl.origin + fwd * 48, 72); e; e = e.chain) {
			if (!Hero_IsFoe(e)) {
				continue;
			}

			Hero_Knock(e, fwd * 450 + [0, 0, 200]);
			Hero_Hurt(e, 15, pl);

			if (!g_hTarget2[slot]) {
				g_hTarget2[slot] = e;
				Hero_Stun(e, 1.5f);
			}
		}
	}

	/* Vault form: Barrier by a planted door */
	if (Hero_InForm(slot)) {
		int planted = Bulkhead_Door(pl, 1);

		if (planted >= 0i) {
			for (entity p = world; (p = next.Player(p));) {
				if (is.Alive(p) && vlen(p.origin - g_placeEnt[planted].origin) < 160) {
					Hero_AddBarrier(p, 4 * frametime);
				}
			}
		}
	}
}

void
Bulkhead_Form(entity pl, int slot, bool on)
{
	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] == PK_DOOR && g_placeOwner[i] == pl) {
			Bulkhead_DoorSize(i, on);
		}
	}

	if (!on) {
		Hero_UnplaceAll(pl, PK_DOORWING);
	}
}

string
Bulkhead_Status(entity pl, int slot)
{
	string door = "lowered";

	if (Bulkhead_Door(pl, 0) >= 0i) {
		door = "raised";
	} else if (Bulkhead_Door(pl, 1) >= 0i) {
		door = "SET";
	}

	return (sprintf("[C] Door %s  [G] Set/pick up  [X] Breach %s", door, Hero_Ready(g_hReady2[slot])));
}

/* ==== KETTLE (Wall) =========================================================
   Pressure: damage he takes builds it (and his own swings, in Boiler
   form). He regenerates while it's under half. Vent: lets it all out,
   knocking everything around him back by how much there was (aimed down
   a corridor in Boiler form). Something already in the air flies less,
   so many Kettles venting on one spot don't stack. Come Here: foes
   nearby turn on him. Charge: he runs through the pack and drags it into
   a clump. (The slower turn while roaring isn't in.) */

void
Kettle_Think(entity pl, int slot)
{
	float now = pl.health + g_hBarrier[slot];
	float maxHealth = entityDef.GetFloat(pl.classname, "health");

	if (now < g_hLastHealth[slot]) {
		g_hRes[slot] = min(100, g_hRes[slot] + (g_hLastHealth[slot] - now));
	}

	if (Hero_InForm(slot) && g_hFireHeld[slot]) {
		g_hRes[slot] = min(100, g_hRes[slot] + 8 * frametime);
	}

	/* regeneration stops while the pressure is high */
	if (g_hRes[slot] < 50 && time - g_hHurtTime[slot] > 2 && pl.health < maxHealth) {
		g_hRes2[slot] += 5 * frametime;

		if (g_hRes2[slot] >= 1) {
			float add = floor(g_hRes2[slot]);
			g_hRes2[slot] -= add;
			ents.Input(pl, "SetHealth", ftos(min(maxHealth, pl.health + add)), pl);
		}
	}

	/* Charge: whoever he runs into comes along */
	if (time < g_hUntil[slot]) {
		vector fwd = Kit_Flat(pl);
		pl.velocity = fwd * 900 + [0, 0, pl.velocity[2]];

		for (entity e = findradius(pl.origin + fwd * 40, 80); e; e = e.chain) {
			if (Hero_IsFoe(e)) {
				vector side = e.origin - pl.origin;
				side = side - fwd * (side * fwd);
				ents.Input(e, "SetOrigin", vtos(pl.origin + fwd * 56 + normalize(side) * min(vlen(side), 40) + [0, 0, 4]), world);
				Hero_Stun(e, 1.2f);
			}
		}
	}
}

void
Kettle_Vent(entity pl, int slot)
{
	float force;
	vector fwd = Kit_Flat(pl);
	int n = 0i;

	if (!Kit_Ready(pl, g_hReady1[slot], "hero_ab1")) {
		return;
	}

	if (g_hRes[slot] < 10) {
		Hero_Notice(pl, "Not enough pressure to vent");
		return;
	}

	force = 250 + g_hRes[slot] * 6;

	for (entity e = findradius(pl.origin, Hero_InForm(slot) ? 520 : 240); e; e = e.chain) {
		vector to;
		float f = force;

		if (!Hero_IsFoe(e)) {
			continue;
		}

		to = e.origin - pl.origin;
		to[2] = 0;

		if (Hero_InForm(slot)) {
			/* a blast down the way he faces */
			if (normalize(to) * fwd < 0.6) {
				continue;
			}

			f *= 1.3;
			Hero_Hurt(e, g_hRes[slot] * 0.5, pl);
		} else if (vlen(to) > 240) {
			continue;
		}

		if (!(e.flags & FL_ONGROUND)) {
			f *= 0.4;
		}

		Hero_Knock(e, normalize(to) * f + [0, 0, 220]);
		n++;
	}

	ents.Input(pl, "Shockwave", "sprites/shockwave.spr 240 0 4 8 220 220 220 255", pl);
	sound(pl, CHAN_ITEM, "ambience/steamburst1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, sprintf("VENT: %d pressure, %i thrown", g_hRes[slot], n));
	g_hRes[slot] = 0;
	g_hReady1[slot] = time + 2;
}

void
Kettle_ComeHere(entity pl, int slot)
{
	int n = 0i;

	if (!Kit_Ready(pl, g_hReady2[slot], "hero_ab2")) {
		return;
	}

	for (entity e = findradius(pl.origin, 600); e; e = e.chain) {
		if (Hero_IsFoe(e)) {
			Hero_Taunt(e, pl);
			n++;
		}
	}

	g_hReady2[slot] = time + 15;
	sound(pl, CHAN_VOICE, "garg/gar_stomp1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, sprintf("COME HERE: %i turned on you", n));
}

void
Kettle_Charge(entity pl, int slot)
{
	g_hUntil[slot] = time + 0.7f;
	g_hExUsed[slot] = true;
	sound(pl, CHAN_VOICE, "garg/gar_stomp1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, "CHARGE");
}

string
Kettle_Status(entity pl, int slot)
{
	return (sprintf("Pressure %d%s  [G] Vent %s  [X] Come Here %s", g_hRes[slot], (g_hRes[slot] >= 50) ? " (no regen)" : "",
		Hero_Ready(g_hReady1[slot]), Hero_Ready(g_hReady2[slot])));
}

/* ==== VECTOR (Runner) =======================================================
   Line: a grapple to any surface under the crosshair (C again lets go);
   her speed carries on after. Beacon: up to three foes take a quarter
   more damage from everyone; a foe one Vector beaconed can't be beaconed
   by another. In Streak form a beacon jumps to the next foe when its
   target dies. Pick-up: carries a downed teammate's body (the revive
   happens wherever she puts them). Trace: for 8 s teammates near her move
   faster. (Seeing beacons through walls and carrying mission objects
   aren't in.) */

void
Vector_Line(entity pl, int slot)
{
	vector eye = Hero_Eye(pl);

	if (time < g_hUntil[slot]) {
		g_hUntil[slot] = 0;
		return;
	}

	if (time < g_hReadyT[slot]) {
		return;
	}

	traceline(eye, eye + Hero_AimDir(pl) * 1200, MOVE_NOMONSTERS, pl);

	if (trace_fraction >= 1.0f) {
		Hero_Notice(pl, "Nothing to grab there");
		return;
	}

	g_hVec[slot] = trace_endpos;
	g_hUntil[slot] = time + 1.2f;
	g_hReadyT[slot] = time + 0.3f;
	sound(pl, CHAN_ITEM, "weapons/xbow_hit1.wav", 1, ATTN_NORM);
}

int
Vector_BeaconOn(entity foe)
{
	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] == PK_SPRITE && g_placeData2[i] == 1 && g_placeTarget[i] == foe) {
			return (i);
		}
	}

	return (-1i);
}

void
Vector_PlaceBeacon(entity pl, entity foe)
{
	int i = Hero_PlaceSprite(pl, foe, "jtf_vis_beacon", 0, [0, 0, foe.maxs[2] + 16]);

	if (i >= 0i) {
		g_placeData[i] = foe.health;
		g_placeData2[i] = 1;
	}
}

void
Vector_Beacon(entity pl, int slot)
{
	entity foe;
	int mine = 0i;
	int oldest = -1i;

	if (!Kit_Ready(pl, g_hReady1[slot], "hero_ab1")) {
		return;
	}

	foe = Hero_AimedFoe(pl, 3000);

	if (!foe) {
		Hero_Notice(pl, "No foe under the crosshair");
		return;
	}

	if (Vector_BeaconOn(foe) >= 0i) {
		Hero_Notice(pl, "Already beaconed");
		return;
	}

	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] == PK_SPRITE && g_placeData2[i] == 1 && g_placeOwner[i] == pl) {
			mine++;

			if (oldest < 0i || g_placeBorn[i] < g_placeBorn[oldest]) {
				oldest = i;
			}
		}
	}

	if (mine >= 3i) {
		Hero_Unplace(oldest);
	}

	Vector_PlaceBeacon(pl, foe);
	g_hReady1[slot] = time + 1.5f;
	sound(pl, CHAN_ITEM, "buttons/blip1.wav", 1, ATTN_NORM);
}

void
Vector_PickUp(entity pl, int slot)
{
	entity t;

	if (g_hTarget2[slot]) {
		Hero_Notice(pl, sprintf("Put %s down", g_hTarget2[slot].netname));
		g_hTarget2[slot] = world;
		return;
	}

	t = Kit_Downed(pl.origin, 112, world);

	if (!t) {
		Hero_Notice(pl, "No downed teammate within reach");
		return;
	}

	g_hTarget2[slot] = t;
	Hero_Notice(pl, sprintf("Carrying %s (X to put down)", t.netname));
}

void
Vector_Trace(entity pl, int slot)
{
	g_hUntil2[slot] = time + 8;
	g_hExUsed[slot] = true;
	sound(pl, CHAN_ITEM, "debris/beamstart1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, "TRACE: follow me");
}

void
Vector_Think(entity pl, int slot)
{
	/* the grapple */
	if (time < g_hUntil[slot]) {
		vector to = g_hVec[slot] - Hero_Eye(pl);

		if (vlen(to) < 72) {
			g_hUntil[slot] = 0;
		} else {
			pl.flags &= ~FL_ONGROUND;
			pl.velocity = normalize(to) * 850;
		}
	}

	/* beacons: a quarter more damage from everyone */
	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] != PK_SPRITE || g_placeData2[i] != 1 || g_placeOwner[i] != pl) {
			continue;
		}

		entity t = g_placeTarget[i];

		if (t && t.health > 0 && t.health < g_placeData[i]) {
			Hero_Hurt(t, (g_placeData[i] - t.health) * 0.25, pl);
		}

		if (t) {
			g_placeData[i] = t.health;
		}
	}

	/* a carried body */
	entity body = g_hTarget2[slot];

	if (body) {
		int s = Coop_Slot(body);

		if (s < 0i || is.Alive(body) || !g_coopDown[s]) {
			g_hTarget2[slot] = world;
		} else {
			g_coopDownOrigin[s] = pl.origin;
			ents.Input(body, "SetOrigin", vtos(pl.origin - Kit_Flat(pl) * 24), pl);
		}
	}

	/* Trace: teammates near her get her pace */
	if (time < g_hUntil2[slot]) {
		for (entity p = world; (p = next.Player(p));) {
			int s2 = Coop_Slot(p);

			if (s2 >= 0i && p != pl && is.Alive(p) && vlen(p.origin - pl.origin) < 300) {
				g_boostUntil[s2] = time + 0.5f;
			}
		}
	}
}

void
Vector_NPCKilled(entity pl, int slot, entity npc)
{
	int i = Vector_BeaconOn(npc);
	entity next = world;
	float bestDist = 400;

	if (i < 0i || g_placeOwner[i] != pl || !Hero_InForm(slot)) {
		return;
	}

	for (entity e = findradius(npc.origin, 400); e; e = e.chain) {
		if (e != npc && Hero_IsFoe(e) && Vector_BeaconOn(e) < 0i && vlen(e.origin - npc.origin) < bestDist) {
			bestDist = vlen(e.origin - npc.origin);
			next = e;
		}
	}

	if (next) {
		Vector_PlaceBeacon(pl, next);
	}
}

string
Vector_Status(entity pl, int slot)
{
	int beacons = 0i;

	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeKind[i] == PK_SPRITE && g_placeData2[i] == 1 && g_placeOwner[i] == pl) {
			beacons++;
		}
	}

	return (sprintf("[C] Line  [G] Beacon %i/3 %s  [X] Pick-up %s", beacons, Hero_Ready(g_hReady1[slot]),
		g_hTarget2[slot] ? "carrying" : "ready"));
}

/* ==== STRAY (Runner) ========================================================
   Slide: a long slide that knocks down the first foe it hits, and is
   ready again at once when it connects. Racket: a noise-maker; foes
   around it go for whoever is nearest it, so thrown at the Wall's feet it
   hands them the pack. Rackets near each other merge. Second Wind: the
   first time she goes down she gets back up at low health, then 45 s
   before it works again. Afterimage form throws the Racket's draw
   further. Rush: one long slide she can't be hurt or seen in, knocking
   everything over. (The afterimages themselves aren't in.) */

void
Stray_Slide(entity pl, int slot, float secs, float speed)
{
	g_hUntil[slot] = time + secs;
	g_hVec[slot] = Kit_Flat(pl) * speed;
	g_hTarget2[slot] = world;
	pl.velocity = g_hVec[slot] + [0, 0, pl.velocity[2]];
	sound(pl, CHAN_ITEM, "weapons/cbar_hitbod1.wav", 0.6, ATTN_NORM);
}

void
Stray_SlideKey(entity pl, int slot)
{
	if (!(pl.flags & FL_ONGROUND)) {
		return;
	}

	if (!Kit_Ready(pl, g_hReadyT[slot], "hero_tool")) {
		return;
	}

	g_hReadyT[slot] = time + 2.5f;
	Stray_Slide(pl, slot, 0.55f, 700);
}

void
Stray_Racket(entity pl, int slot)
{
	int i;
	vector fwd = Hero_AimDir(pl);

	if (!Kit_Ready(pl, g_hReady1[slot], "hero_ab1")) {
		return;
	}

	i = Hero_Place(pl, PK_RACKET, "jtf_vis_racket", Hero_Eye(pl) + fwd * 16, 6);

	if (i < 0i) {
		return;
	}

	g_placeEnt[i].movetype = MOVETYPE_TOSS;
	g_placeEnt[i].velocity = fwd * 600 + [0, 0, 200];
	g_placeData[i] = 0;	/* next draw */
	g_hReady1[slot] = time + 12;
	sound(pl, CHAN_ITEM, "squeek/sqk_deploy1.wav", 1, ATTN_NORM);
}

void
Stray_RacketThink(int i)
{
	entity r = g_placeEnt[i];
	entity owner = g_placeOwner[i];
	int os = Coop_Slot(owner);
	entity bait = world;
	float bestDist = 400;
	float reach;

	if (time < g_placeData[i]) {
		return;
	}

	/* a racket next to one already going joins it */
	for (int k = 0i; k < HERO_MAXPLACE; k++) {
		if (k != i && g_placeKind[k] == PK_RACKET && g_placeData[k] > 0 && vlen(g_placeEnt[k].origin - r.origin) < 300) {
			g_placeExpire[k] = max(g_placeExpire[k], g_placeExpire[i]);
			Hero_Unplace(i);
			return;
		}
	}

	g_placeData[i] = time + 1.5f;
	sound(r, CHAN_AUTO, "buttons/button9.wav", 1, ATTN_IDLE);

	for (entity p = world; (p = next.Player(p));) {
		if (is.Alive(p) && vlen(p.origin - r.origin) < bestDist) {
			bestDist = vlen(p.origin - r.origin);
			bait = p;
		}
	}

	if (!bait) {
		bait = owner;
	}

	reach = (os >= 0i && Hero_InForm(os)) ? 1000 : 600;

	for (entity e = findradius(r.origin, reach); e; e = e.chain) {
		if (Hero_IsFoe(e)) {
			Hero_Taunt(e, bait);
		}
	}
}

void
Stray_Rush(entity pl, int slot)
{
	g_hExUsed[slot] = true;
	Hero_Untouchable(pl, true);
	pl.flags |= FL_NOTARGET;
	Stray_Slide(pl, slot, 1.2f, 950);
	g_hRes[slot] = 1;	/* rushing */
	Hero_Notice(pl, "RUSH");
}

void
Stray_Think(entity pl, int slot)
{
	if (time < g_hUntil[slot]) {
		vector fwd = normalize(g_hVec[slot]);
		pl.velocity = g_hVec[slot] + [0, 0, pl.velocity[2]];

		for (entity e = findradius(pl.origin + fwd * 32, (g_hRes[slot] > 0) ? 80 : 56); e; e = e.chain) {
			if (!Hero_IsFoe(e) || Hero_IsStunned(e)) {
				continue;
			}

			Hero_Knock(e, fwd * 250 + [0, 0, 200]);
			Hero_Stun(e, (g_hRes[slot] > 0) ? 1.5f : 1.0f);

			/* a slide that connects is ready again, and ends */
			if (g_hRes[slot] <= 0) {
				g_hReadyT[slot] = time;
				g_hUntil[slot] = 0;
				break;
			}
		}
	} else if (g_hRes[slot] > 0) {
		g_hRes[slot] = 0;
		Hero_Untouchable(pl, false);
		pl.flags &= ~FL_NOTARGET;
	}
}

void
Stray_Killed(entity pl, int slot)
{
	if (time < g_windReady[slot]) {
		return;
	}

	g_windReady[slot] = time + 45;
	g_riseAt[slot] = time + 0.5f;
	g_riseOrigin[slot] = pl.origin;
}

void
Stray_DeadThink(entity pl, int slot)
{
	if (g_riseAt[slot] <= 0 || time < g_riseAt[slot]) {
		return;
	}

	g_riseAt[slot] = 0;
	CodeCallback_PlayerSpawn(pl);
	ents.Input(pl, "SetOrigin", vtos(g_riseOrigin[slot] + [0, 0, 8]), pl);
	ents.Input(pl, "SetHealth", "30", pl);
	sound(pl, CHAN_VOICE, "items/smallmedkit1.wav", 1, ATTN_NORM);
	Hero_Notice(pl, "SECOND WIND");
}

string
Stray_Status(entity pl, int slot)
{
	return (sprintf("[C] Slide %s  [G] Racket %s  Second Wind %s", Hero_Ready(g_hReadyT[slot]), Hero_Ready(g_hReady1[slot]),
		Hero_Ready(g_windReady[slot])));
}

/* ==== LEDGER (Planner) ======================================================
   Stock (0 to 100): salvage from foes that die near her, a refund when a
   teammate uses one of her caches, and a trickle while she isn't firing
   or being hit. (No credit for objectives or new areas: maps don't say.)
   Cache (30): a crate with ammo and 15 Energy for each teammate who walks
   into it, once, and a field revive kit the first one carries: hold E on
   a downed teammate to stand them up at once. A cache next to another
   Ledger's only adds its revive kit. Jump pad (20): flings whoever steps
   on it the way she faced; monsters don't trigger it. Depot form: caches
   give Barrier nearby and a third pad. Requisition: everything she placed
   comes back as stock. All of it goes when she swaps hero. */

#define CACHE_COST 30
#define PAD_COST 20

void
Ledger_Think(entity pl, int slot)
{
	if (time - g_hFireTime[slot] > 3 && time - g_hHurtTime[slot] > 3) {
		g_hRes[slot] = min(100, g_hRes[slot] + 1.0 * frametime);
	}
}

bool
Ledger_Spend(entity pl, int slot, float cost)
{
	if (g_hRes[slot] < cost) {
		Hero_Notice(pl, sprintf("Needs %d stock", cost));
		return (false);
	}

	g_hRes[slot] -= cost;
	return (true);
}

void
Ledger_Cache(entity pl, int slot)
{
	vector spot = Hero_AimFloor(pl, 220);
	int i;
	bool supplies = (Hero_PlaceNear(spot, PK_CACHE, 300, pl, true) < 0i) ? true : false;

	if (!Ledger_Spend(pl, slot, CACHE_COST)) {
		return;
	}

	while (Hero_PlaceCount(pl, PK_CACHE) >= 2i) {
		Hero_UnplaceOldest(pl, PK_CACHE);
	}

	i = Hero_Place(pl, PK_CACHE, "jtf_vis_cache", spot, 0);

	if (i < 0i) {
		return;
	}

	g_placeData[i] = 1;	/* the revive kit is in */
	g_placeData2[i] = supplies ? 1 : 0;
	sound(pl, CHAN_ITEM, "items/gunpickup2.wav", 1, ATTN_NORM);
	Hero_Notice(pl, supplies ? "Cache placed" : "Cache placed: only its revive kit, another Ledger supplies here");
}

void
Ledger_Pad(entity pl, int slot)
{
	vector spot = Hero_AimFloor(pl, 320);
	int most = Hero_InForm(slot) ? 3i : 2i;
	int i;

	if (!Ledger_Spend(pl, slot, PAD_COST)) {
		return;
	}

	while (Hero_PlaceCount(pl, PK_PAD) >= most) {
		Hero_UnplaceOldest(pl, PK_PAD);
	}

	i = Hero_Place(pl, PK_PAD, "jtf_vis_pad", spot + [0, 0, 1], 0);

	if (i >= 0i) {
		g_placeVec[i] = Kit_Flat(pl);
		g_placeEnt[i].angles = [0, vectoyaw(Kit_Flat(pl)), 0];
		sound(pl, CHAN_ITEM, "buttons/blip1.wav", 1, ATTN_NORM);
	}
}

void
Ledger_Requisition(entity pl, int slot)
{
	float back = 0;

	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeOwner[i] != pl) {
			continue;
		}

		if (g_placeKind[i] == PK_CACHE) {
			back += CACHE_COST;
			Hero_Unplace(i);
		} else if (g_placeKind[i] == PK_PAD) {
			back += PAD_COST;
			Hero_Unplace(i);
		}
	}

	g_hRes[slot] = min(100, g_hRes[slot] + back);
	g_hExUsed[slot] = true;
	sound(pl, CHAN_ITEM, "items/gunpickup2.wav", 1, ATTN_NORM);
	Hero_Notice(pl, sprintf("REQUISITION: %d stock back", back));
}

void
Ledger_PlaceThink(int i)
{
	entity owner = g_placeOwner[i];
	int os = Coop_Slot(owner);
	entity box = g_placeEnt[i];

	if (g_placeKind[i] == PK_PAD) {
		if (time < g_placeData2[i]) {
			return;
		}

		for (entity p = world; (p = next.Player(p));) {
			vector to = p.origin - box.origin;

			if (!is.Alive(p) || vlen([to[0], to[1], 0]) > 40 || to[2] < -8 || to[2] > 48) {
				continue;
			}

			p.flags &= ~FL_ONGROUND;
			p.velocity = g_placeVec[i] * 550 + [0, 0, 560];
			g_placeData2[i] = time + 0.4f;
			sound(p, CHAN_AUTO, "weapons/rocketfire1.wav", 0.6, ATTN_NORM);
		}

		return;
	}

	/* a cache */
	for (entity p = world; (p = next.Player(p));) {
		int s = Coop_Slot(p);
		float bit;

		if (s < 0i || !is.Alive(p)) {
			continue;
		}

		float d = vlen(p.origin - box.origin);

		if (os >= 0i && Hero_InForm(os) && d < 200) {
			Hero_AddBarrier(p, 4 * frametime);
		}

		if (d > 56) {
			continue;
		}

		/* a float holds whole numbers to 2^24: one bit per slot up to 24 */
		bit = 0;

		if (s < 24i) {
			bit = 1;

			for (int b = 0i; b < s; b++) {
				bit *= 2;
			}
		}

		if (g_placeData2[i] > 0 && bit > 0 && !((float)g_placeUsedBy[i] & bit)) {
			g_placeUsedBy[i] += bit;
			ents.Input(p, "GiveAmmo", "ammo_9mm 50", owner);
			ents.Input(p, "GiveAmmo", "ammo_buckshot 12", owner);
			ents.Input(p, "GiveAmmo", "ammo_357 12", owner);
			ents.Input(p, "GiveAmmo", "ammo_bolt 5", owner);
			ents.Input(p, "GiveAmmo", "ammo_m203_grenade 1", owner);
			Hero_AddEnergy(p, 15);
			sound(p, CHAN_ITEM, "items/gunpickup2.wav", 1, ATTN_NORM);
			centerprint(p, "Cache: ammo and 15 Energy");

			if (p != owner && os >= 0i) {
				g_hRes[os] = min(100, g_hRes[os] + 5);
			}
		}

		if (g_placeData[i] > 0 && !g_fieldKit[s]) {
			g_placeData[i] = 0;
			g_fieldKit[s] = true;
			centerprint(p, "You have a field revive kit:\nhold E on a downed teammate");
		}
	}
}

void
Ledger_NPCKilled(entity pl, int slot, entity npc)
{
	if (vlen(npc.origin - pl.origin) < 700) {
		g_hRes[slot] = min(100, g_hRes[slot] + 4);
	}
}

string
Ledger_Status(entity pl, int slot)
{
	return (sprintf("Stock %d  [G] Cache (%d) %i/2  [X] Jump pad (%d) %i/%i", g_hRes[slot], CACHE_COST,
		Hero_PlaceCount(pl, PK_CACHE), PAD_COST, Hero_PlaceCount(pl, PK_PAD), Hero_InForm(slot) ? 3i : 2i));
}

/* a carried revive kit, used by holding E (every input frame) */
void
Kit_FieldReviveInput(entity pl)
{
	int slot = Coop_Slot(pl);
	entity t;

	if (slot < 0i || !g_fieldKit[slot] || !is.Alive(pl)) {
		return;
	}

	if (!((float)externvalue(0, "input_buttons") & INPUT_USE)) {
		return;
	}

	t = Kit_Downed(pl.origin, autocvar_coop_reviveRange, pl);

	if (t) {
		g_fieldKit[slot] = false;
		Coop_Revive(pl, t);
	}
}

/* ==== TRIPWIRE (Planner) ====================================================
   Recon prep (0 to 100) builds quickly while she's away from the team
   (600 units from everyone), slowly otherwise, and drains while she
   fires. Mines (15): go off when a foe comes close; another mine on the
   same spot is refused. Snare (20): holds up to four foes that walk into
   it in place for 4 s. Both arm after a moment, instantly in Armed form,
   where mines also reach further. Remote: every mine of hers goes off in
   turn and every snare springs. (Tripwires and seeing what's ahead
   aren't in.) */

#define MINE_COST 15
#define SNARE_COST 20

void
Tripwire_Think(entity pl, int slot)
{
	bool alone = true;

	if (g_hFireHeld[slot]) {
		g_hRes[slot] = max(0, g_hRes[slot] - 3 * frametime);
		return;
	}

	for (entity p = world; (p = next.Player(p));) {
		if (p != pl && is.Alive(p) && vlen(p.origin - pl.origin) < 600) {
			alone = false;
		}
	}

	g_hRes[slot] = min(100, g_hRes[slot] + (alone ? 2.0 : 0.4) * frametime);
}

void
Tripwire_Mine(entity pl, int slot)
{
	vector spot = Hero_AimFloor(pl, 260);

	if (Hero_PlaceNear(spot, PK_MINE, 64, pl, false) >= 0i) {
		Hero_Notice(pl, "A mine is already there");
		return;
	}

	if (g_hRes[slot] < MINE_COST) {
		Hero_Notice(pl, sprintf("Needs %d prep", MINE_COST));
		return;
	}

	g_hRes[slot] -= MINE_COST;

	while (Hero_PlaceCount(pl, PK_MINE) >= 6i) {
		Hero_UnplaceOldest(pl, PK_MINE);
	}

	Hero_Place(pl, PK_MINE, "jtf_vis_mine", spot, 0);
	sound(pl, CHAN_ITEM, "weapons/mine_activate.wav", 1, ATTN_NORM);
}

void
Tripwire_Snare(entity pl, int slot)
{
	vector spot = Hero_AimFloor(pl, 260);

	if (g_hRes[slot] < SNARE_COST) {
		Hero_Notice(pl, sprintf("Needs %d prep", SNARE_COST));
		return;
	}

	g_hRes[slot] -= SNARE_COST;

	while (Hero_PlaceCount(pl, PK_SNARE) >= 3i) {
		Hero_UnplaceOldest(pl, PK_SNARE);
	}

	Hero_Place(pl, PK_SNARE, "jtf_vis_snare", spot, 90);
	sound(pl, CHAN_ITEM, "buttons/blip1.wav", 1, ATTN_NORM);
}

void
Tripwire_Spring(int i, float radius)
{
	int held = (int)g_placeData2[i];

	for (entity e = findradius(g_placeEnt[i].origin, radius); e && held < 4i; e = e.chain) {
		if (Hero_IsFoe(e) && !Hero_IsStunned(e)) {
			Hero_Stun(e, 4);
			held++;
		}
	}

	g_placeData2[i] = held;
}

void
Tripwire_Remote(entity pl, int slot)
{
	int n = 0i;

	for (int i = 0i; i < HERO_MAXPLACE; i++) {
		if (g_placeOwner[i] != pl) {
			continue;
		}

		if (g_placeKind[i] == PK_MINE) {
			g_placeData[i] = time + 0.2f * n;	/* a fuse */
			n++;
		} else if (g_placeKind[i] == PK_SNARE) {
			Tripwire_Spring(i, 160);
			Hero_Unplace(i);
		}
	}

	g_hExUsed[slot] = true;
	Hero_Notice(pl, sprintf("REMOTE: %i mines", n));
}

void
Tripwire_PlaceThink(int i)
{
	entity owner = g_placeOwner[i];
	int os = Coop_Slot(owner);
	bool armed = (os >= 0i && Hero_InForm(os)) || time - g_placeBorn[i] > 1.5f;
	vector org = g_placeEnt[i].origin;

	if (g_placeKind[i] == PK_SNARE) {
		if (!armed) {
			return;
		}

		Tripwire_Spring(i, 80);

		if (g_placeData2[i] > 0) {
			sound(g_placeEnt[i], CHAN_AUTO, "weapons/xbow_hit1.wav", 1, ATTN_NORM);
			Hero_Unplace(i);
		}

		return;
	}

	/* a mine */
	bool boom = (g_placeData[i] > 0 && time >= g_placeData[i]);

	if (!boom && armed && g_placeData[i] <= 0) {
		for (entity e = findradius(org, (os >= 0i && Hero_InForm(os)) ? 160 : 96); e; e = e.chain) {
			if (Hero_IsFoe(e)) {
				boom = true;
				break;
			}
		}
	}

	if (boom) {
		Hero_Unplace(i);
		Kit_Boom(org + [0, 0, 8]);
		Hero_HurtRadius(org, 200, 120, owner);
	}
}

string
Tripwire_Status(entity pl, int slot)
{
	return (sprintf("Prep %d  [G] Mine (%d) %i/6  [X] Snare (%d) %i/3", g_hRes[slot], MINE_COST, Hero_PlaceCount(pl, PK_MINE),
		SNARE_COST, Hero_PlaceCount(pl, PK_SNARE)));
}

/* ==== LONGHAND (Hunter) =====================================================
   Mark: keeping the crosshair on a foe studies it, for a time that grows
   with its health (a headcrab is near instant, a gargantua takes
   seconds). Looking away for long or being hit starts it over. Then it
   has a weak point at a random spot on its body, shown with a dot. Her
   hit on the weak point does up to three times the damage, more the
   longer since her last shot; anyone else's hit on it does half again.
   One mark at a time. Overwatch: she can't move, and studies twice as
   fast. Clear Shot: a leap back that costs her charge. Longshot form
   studies three times as fast. Verdict: the foe under the crosshair dies,
   or a boss loses 40%. (Piercing shots and slowed time aren't in.) */

float
Longhand_Charge(int slot)
{
	return (min(time - g_lastShot[slot], 3) / 3);
}

void
Longhand_ClearMark(entity pl, int slot)
{
	if (g_markSprite[slot] >= 0i && g_placeKind[g_markSprite[slot]] == PK_SPRITE && g_placeOwner[g_markSprite[slot]] == pl) {
		Hero_Unplace(g_markSprite[slot]);
	}

	g_markSprite[slot] = -1i;
	g_hTarget[slot] = world;
}

/* how far a player's aim passes from a point, or a big number behind them */
float
Kit_AimMiss(entity p, vector point)
{
	vector eye = Hero_Eye(p);
	vector dir = Hero_AimDir(p);
	vector v = point - eye;
	float along = v * dir;

	if (along < 0) {
		return (99999);
	}

	return (vlen(v - dir * along));
}

void
Longhand_Think(entity pl, int slot)
{
	entity aimed;
	float rate = 1;
	entity t = g_hTarget[slot];

	/* shots: the time between them is the charge */
	if (g_hFirePress[slot] > g_lastShot[slot] + 0.05f) {
		g_prevShot[slot] = g_lastShot[slot];
		g_lastShot[slot] = g_hFirePress[slot];
	}

	if (g_stance[slot]) {
		pl.velocity = [0, 0, min(pl.velocity[2], 0)];
		rate *= 2;
	}

	if (Hero_InForm(slot)) {
		rate *= 3;
	}

	/* the study */
	aimed = Hero_AimedFoe(pl, 4000);

	if (g_hHurtTime[slot] > g_studyStart[slot] && g_hTarget2[slot]) {
		g_hTarget2[slot] = world;
		Kit_Throttled(pl, slot, "Study broken");
	}

	if (aimed && aimed != t) {
		if (aimed != g_hTarget2[slot]) {
			g_hTarget2[slot] = aimed;
			g_hRes[slot] = 0;
			g_hRes2[slot] = bound(0.3, aimed.health / 100, 8);
			g_studyStart[slot] = time;
		}

		g_studySeen[slot] = time;
		g_hRes[slot] += rate * frametime;

		if (g_hRes[slot] >= g_hRes2[slot]) {
			vector size = aimed.maxs - aimed.mins;

			Longhand_ClearMark(pl, slot);
			g_hTarget[slot] = aimed;
			g_hTarget2[slot] = world;
			g_hVec[slot] = aimed.mins + [size[0] * (0.25 + random() * 0.5), size[1] * (0.25 + random() * 0.5), size[2] * (0.2 + random() * 0.75)];
			g_markHealth[slot] = aimed.health;
			g_markSprite[slot] = Hero_PlaceSprite(pl, aimed, "jtf_vis_weakpoint", 0, g_hVec[slot]);
			sound(pl, CHAN_ITEM, "buttons/blip1.wav", 1, ATTN_NORM);
			Hero_Notice(pl, "Weak point found");
			t = aimed;
		}
	} else if (g_hTarget2[slot] && time - g_studySeen[slot] > 0.4f) {
		g_hTarget2[slot] = world;
	}

	/* the weak point: who hit it this frame */
	if (t && t.health <= 0) {
		Longhand_ClearMark(pl, slot);
	} else if (t) {
		vector wp = t.origin + g_hVec[slot];

		if (t.health < g_markHealth[slot]) {
			float drop = g_markHealth[slot] - t.health;

			for (entity p = world; (p = next.Player(p));) {
				int s = Coop_Slot(p);

				if (s < 0i || !is.Alive(p) || time - g_hFireTime[s] > 0.2f || Kit_AimMiss(p, wp) > 14) {
					continue;
				}

				if (p == pl) {
					float charge = min(g_lastShot[slot] - g_prevShot[slot], 3) / 3;
					Hero_Hurt(t, drop * (1 + 2 * charge), pl);
					Kit_Throttled(pl, slot, sprintf("WEAK POINT x%d", 2 + 2 * charge));
				} else {
					Hero_Hurt(t, drop * 0.5, p);
				}

				break;
			}
		}

		g_markHealth[slot] = (t.health > 0) ? t.health : 0;
	}
}

void
Longhand_Overwatch(entity pl, int slot)
{
	g_stance[slot] = !g_stance[slot];

	if (!g_stance[slot]) {
		g_lastShot[slot] = time;	/* leaving drops the charge */
	}

	Hero_Notice(pl, g_stance[slot] ? "Overwatch" : "Overwatch off");
}

void
Longhand_ClearShot(entity pl, int slot)
{
	if (!Kit_Ready(pl, g_hReady2[slot], "hero_ab2")) {
		return;
	}

	g_stance[slot] = false;
	g_lastShot[slot] = time;
	pl.flags &= ~FL_ONGROUND;
	pl.velocity = Kit_Flat(pl) * -550 + [0, 0, 320];
	g_hReady2[slot] = time + 8;
	sound(pl, CHAN_ITEM, "weapons/cbar_hitbod1.wav", 0.6, ATTN_NORM);
}

void
Longhand_Verdict(entity pl, int slot)
{
	entity t = Hero_AimedFoe(pl, 6000);

	if (!t) {
		Hero_Notice(pl, "No foe under the crosshair");
		return;
	}

	g_hExUsed[slot] = true;

	if (t.health > 1500) {
		Hero_Hurt(t, t.health * 0.4, pl);
		Hero_Notice(pl, "VERDICT: 40%");
	} else {
		Hero_Hurt(t, t.health + 50, pl);
		Hero_Notice(pl, "VERDICT");
	}

	sound(pl, CHAN_ITEM, "weapons/xbow_hit1.wav", 1, ATTN_NORM);
}

string
Longhand_Status(entity pl, int slot)
{
	string mark = "none";

	if (g_hTarget2[slot]) {
		mark = sprintf("studying %d%%", 100 * min(1, g_hRes[slot] / g_hRes2[slot]));
	} else if (g_hTarget[slot]) {
		mark = "weak point up";
	}

	return (sprintf("Mark: %s  Charge %d%%  [G] Overwatch %s  [X] Clear Shot %s", mark, 100 * Longhand_Charge(slot),
		g_stance[slot] ? "ON" : "off", Hero_Ready(g_hReady2[slot])));
}

/* ==== MANTIS (Hunter) =======================================================
   Still: standing still for a second, she fades and monsters lose her;
   moving shows her again (moving slowly is fine in Ghost form). Her
   swings from behind do much more. Execute: from behind a foe, a 1.2 s
   channel that finishes most things; being hit breaks it. Ghost form
   chains it to the next foe close by. Slip: a blink through the foe in
   front, to its back. Reap: the next Execute can't be hurt or seen.
   Another Mantis's target can't be executed twice. (Her fade isn't drawn:
   other players see her as usual.) */

bool
Mantis_Behind(entity pl, entity foe)
{
	vector to = foe.origin - pl.origin;
	to[2] = 0;
	makevectors([0, foe.angles[1], 0]);
	return (normalize(to) * v_forward > 0.3) ? true : false;
}

bool
Mantis_Executing(entity foe, entity skip)
{
	for (entity p = world; (p = next.Player(p));) {
		int s = Coop_Slot(p);

		if (p != skip && s >= 0i && g_hLogic[s] == HL_MANTIS && time < g_hUntil[s] && g_hTarget[s] == foe) {
			return (true);
		}
	}

	return (false);
}

bool
Mantis_StartExecute(entity pl, int slot, entity foe)
{
	if (Mantis_Executing(foe, pl)) {
		Hero_Notice(pl, "Already being executed");
		return (false);
	}

	g_hTarget[slot] = foe;
	g_hUntil[slot] = time + 1.2f;
	g_hUntil2[slot] = time;	/* hits after this break it */
	Hero_Stun(foe, 1.4f);

	if (g_reap[slot]) {
		Hero_Untouchable(pl, true);
	}

	return (true);
}

void
Mantis_Execute(entity pl, int slot)
{
	entity foe;

	if (time < g_hUntil[slot]) {
		return;
	}

	if (!Kit_Ready(pl, g_hReady1[slot], "hero_ab1")) {
		return;
	}

	foe = Hero_FoeInFront(pl, 100, 0.5);

	if (!foe) {
		Hero_Notice(pl, "Get behind a foe first");
		return;
	}

	if (!Mantis_Behind(pl, foe)) {
		Hero_Notice(pl, "Not from the front");
		return;
	}

	Mantis_StartExecute(pl, slot, foe);
}

void
Mantis_EndExecute(entity pl, int slot)
{
	g_hUntil[slot] = 0;
	g_hTarget[slot] = world;
	g_hReady1[slot] = time + 6;

	if (g_reap[slot]) {
		g_reap[slot] = false;
		Hero_Untouchable(pl, false);
	}
}

void
Mantis_Slip(entity pl, int slot)
{
	entity foe;
	vector dir;
	vector dest;

	if (!Kit_Ready(pl, g_hReady2[slot], "hero_ab2")) {
		return;
	}

	foe = Hero_FoeInFront(pl, 320, 0.8);

	if (!foe) {
		Hero_Notice(pl, "No foe in front to slip through");
		return;
	}

	dir = foe.origin - pl.origin;
	dir[2] = 0;
	dir = normalize(dir);
	dest = foe.origin + dir * (foe.maxs[0] + 40);
	dest[2] = pl.origin[2] + 4;
	tracebox(dest, pl.mins, pl.maxs, dest, MOVE_NORMAL, pl);

	if (trace_startsolid || trace_allsolid) {
		Hero_Notice(pl, "No room behind it");
		return;
	}

	ents.Input(pl, "SetOrigin", vtos(dest), pl);
	pl.angles = [0, vectoyaw(-dir), 0];
	pl.v_angle = pl.angles;
	pl.fixangle = TRUE;
	g_hReady2[slot] = time + 14;
	sound(pl, CHAN_ITEM, "x/x_teleattack1.wav", 0.7, ATTN_NORM);
}

void
Mantis_Reap(entity pl, int slot)
{
	g_reap[slot] = true;
	g_hExUsed[slot] = true;

	if (time < g_hUntil[slot]) {
		Hero_Untouchable(pl, true);
	}

	Hero_Notice(pl, "REAP: the next Execute can't be stopped");
}

void
Mantis_Think(entity pl, int slot)
{
	float speed = Kit_FlatSpeed(pl);
	bool faded;

	/* Still */
	if (speed < (Hero_InForm(slot) ? 160 : 20)) {
		g_hRes[slot] += frametime;
	} else {
		g_hRes[slot] = 0;
	}

	faded = (g_hRes[slot] >= (Hero_InForm(slot) ? 0.5 : 1.0)) || g_reap[slot] && time < g_hUntil[slot];

	if (faded) {
		pl.flags |= FL_NOTARGET;
	} else {
		pl.flags &= ~FL_NOTARGET;
	}

	/* swings from behind */
	if (g_hFirePress[slot] > time - 0.05f && time >= g_stabReady[slot]) {
		entity foe = Hero_FoeInFront(pl, 80, 0.7);

		if (foe && Mantis_Behind(pl, foe)) {
			g_stabReady[slot] = time + 0.3f;
			Hero_Hurt(foe, 55, pl);
		}
	}

	/* the Execute channel */
	if (g_hUntil[slot] > 0) {
		entity t = g_hTarget[slot];

		if (!t || t.health <= 0) {
			Mantis_EndExecute(pl, slot);
			return;
		}

		if (!g_reap[slot] && g_hHurtTime[slot] > g_hUntil2[slot]) {
			Hero_Notice(pl, "Execute broken");
			Mantis_EndExecute(pl, slot);
			return;
		}

		pl.velocity = [0, 0, min(pl.velocity[2], 0)];

		if (time >= g_hUntil[slot]) {
			Hero_Hurt(t, 400, pl);
			sound(pl, CHAN_ITEM, "weapons/cbar_hitbod1.wav", 1, ATTN_NORM);
			Mantis_EndExecute(pl, slot);

			/* Ghost form: on to the next one close by */
			if (Hero_InForm(slot)) {
				for (entity e = findradius(pl.origin, 200); e; e = e.chain) {
					if (Hero_IsFoe(e) && e != t && !Mantis_Executing(e, pl)) {
						g_hReady1[slot] = 0;
						Mantis_StartExecute(pl, slot, e);
						break;
					}
				}
			}
		}
	}
}

string
Mantis_Status(entity pl, int slot)
{
	bool faded = (pl.flags & FL_NOTARGET) ? true : false;

	return (sprintf("%s  [G] Execute %s  [X] Slip %s%s", faded ? "STILL: unseen" : "Seen", (time < g_hUntil[slot]) ? "channeling" :
		Hero_Ready(g_hReady1[slot]), Hero_Ready(g_hReady2[slot]), g_reap[slot] ? "  REAP armed" : ""));
}

/* ==== routing ============================================================== */

void
Kit_Spawned(entity pl, int slot)
{
	g_steadyUntil[slot] = 0;
	g_boostUntil[slot] = 0;
	g_riseAt[slot] = 0;
	g_stance[slot] = false;
	g_reap[slot] = false;
	g_markSprite[slot] = -1i;
	g_lastShot[slot] = time;
	g_prevShot[slot] = time;

	switch (g_hLogic[slot]) {
	case HL_BULKHEAD:
		Bulkhead_Spawned(pl, slot);
		break;
	case HL_LEDGER:
		g_hRes[slot] = 30;	/* enough for a first cache */
		break;
	case HL_TRIPWIRE:
		g_hRes[slot] = 15;
		break;
	}
}

void
Kit_Use(entity pl, int slot, int ab)
{
	switch (g_hLogic[slot]) {
	case HL_DISPATCH:
		if (ab == AB_TOOL) Dispatch_Orders(pl, slot);
		else if (ab == AB_ONE) Dispatch_Courier(pl, slot);
		else if (ab == AB_TWO) Dispatch_Reroute(pl, slot);
		else if (ab == AB_EX) Dispatch_Recall(pl, slot);
		break;
	case HL_CHOIR:
		if (ab == AB_TOOL) Hero_Notice(pl, "Cadence is always on: face who you're backing");
		else if (ab == AB_ONE) Choir_OnYourFeet(pl, slot);
		else if (ab == AB_TWO) Choir_HoldTheLine(pl, slot);
		else if (ab == AB_EX) Choir_Sync(pl, slot);
		break;
	case HL_BULKHEAD:
		if (ab == AB_TOOL) Bulkhead_Toggle(pl, slot);
		else if (ab == AB_ONE) Bulkhead_Set(pl, slot);
		else if (ab == AB_TWO) Bulkhead_Breach(pl, slot);
		else if (ab == AB_EX) Bulkhead_Lockdown(pl, slot);
		break;
	case HL_KETTLE:
		if (ab == AB_TOOL) Hero_Notice(pl, "Pressure builds when you're hit: vent it with G");
		else if (ab == AB_ONE) Kettle_Vent(pl, slot);
		else if (ab == AB_TWO) Kettle_ComeHere(pl, slot);
		else if (ab == AB_EX) Kettle_Charge(pl, slot);
		break;
	case HL_VECTOR:
		if (ab == AB_TOOL) Vector_Line(pl, slot);
		else if (ab == AB_ONE) Vector_Beacon(pl, slot);
		else if (ab == AB_TWO) Vector_PickUp(pl, slot);
		else if (ab == AB_EX) Vector_Trace(pl, slot);
		break;
	case HL_STRAY:
		if (ab == AB_TOOL) Stray_SlideKey(pl, slot);
		else if (ab == AB_ONE) Stray_Racket(pl, slot);
		else if (ab == AB_TWO) Hero_Notice(pl, sprintf("Second Wind %s", (time < g_windReady[slot]) ? "recharging" : "ready: it works by itself"));
		else if (ab == AB_EX) Stray_Rush(pl, slot);
		break;
	case HL_LEDGER:
		if (ab == AB_TOOL) Hero_Notice(pl, "Stock comes from salvage, used caches and not firing");
		else if (ab == AB_ONE) Ledger_Cache(pl, slot);
		else if (ab == AB_TWO) Ledger_Pad(pl, slot);
		else if (ab == AB_EX) Ledger_Requisition(pl, slot);
		break;
	case HL_TRIPWIRE:
		if (ab == AB_TOOL) Hero_Notice(pl, "Prep builds fastest away from the team");
		else if (ab == AB_ONE) Tripwire_Mine(pl, slot);
		else if (ab == AB_TWO) Tripwire_Snare(pl, slot);
		else if (ab == AB_EX) Tripwire_Remote(pl, slot);
		break;
	case HL_LONGHAND:
		if (ab == AB_TOOL) Hero_Notice(pl, "Hold the crosshair on a foe to study it");
		else if (ab == AB_ONE) Longhand_Overwatch(pl, slot);
		else if (ab == AB_TWO) Longhand_ClearShot(pl, slot);
		else if (ab == AB_EX) Longhand_Verdict(pl, slot);
		break;
	case HL_MANTIS:
		if (ab == AB_TOOL) Hero_Notice(pl, "Stand still to fade");
		else if (ab == AB_ONE) Mantis_Execute(pl, slot);
		else if (ab == AB_TWO) Mantis_Slip(pl, slot);
		else if (ab == AB_EX) Mantis_Reap(pl, slot);
		break;
	}
}

/* every frame, for every living hero player, whatever their kit */
void
Kit_AnyThink(entity pl, int slot)
{
	float walk = entityDef.GetFloat(pl.classname, "pm_walkspeed");

	if (walk <= 0) {
		walk = 270;
	}

	/* Hold the Line: no being thrown about */
	if (time < g_steadyUntil[slot]) {
		float speed = Kit_FlatSpeed(pl);

		if (speed > walk * 1.1) {
			float k = walk * 1.1 / speed;
			pl.velocity = [pl.velocity[0] * k, pl.velocity[1] * k, min(pl.velocity[2], 270)];
		}
	}

	/* Trace: a third faster while moving */
	if (time < g_boostUntil[slot] && (pl.flags & FL_ONGROUND)) {
		float speed2 = Kit_FlatSpeed(pl);

		if (speed2 > 50 && speed2 < walk * 1.35) {
			float k2 = walk * 1.35 / speed2;
			pl.velocity = [pl.velocity[0] * k2, pl.velocity[1] * k2, pl.velocity[2]];
		}
	}
}

void
Kit_Think(entity pl, int slot)
{
	switch (g_hLogic[slot]) {
	case HL_CHOIR:
		Choir_Think(pl, slot);
		break;
	case HL_BULKHEAD:
		Bulkhead_Think(pl, slot);
		break;
	case HL_KETTLE:
		Kettle_Think(pl, slot);
		break;
	case HL_VECTOR:
		Vector_Think(pl, slot);
		break;
	case HL_STRAY:
		Stray_Think(pl, slot);
		break;
	case HL_LEDGER:
		Ledger_Think(pl, slot);
		break;
	case HL_TRIPWIRE:
		Tripwire_Think(pl, slot);
		break;
	case HL_LONGHAND:
		Longhand_Think(pl, slot);
		break;
	case HL_MANTIS:
		Mantis_Think(pl, slot);
		break;
	}
}

void
Kit_DeadThink(entity pl, int slot)
{
	if (g_hLogic[slot] == HL_STRAY) {
		Stray_DeadThink(pl, slot);
	}
}

void
Kit_PlaceThink(int i)
{
	switch (g_placeKind[i]) {
	case PK_ORDER:
	case PK_DRONE:
		Dispatch_PlaceThink(i);
		break;
	case PK_RACKET:
		Stray_RacketThink(i);
		break;
	case PK_CACHE:
	case PK_PAD:
		Ledger_PlaceThink(i);
		break;
	case PK_MINE:
	case PK_SNARE:
		Tripwire_PlaceThink(i);
		break;
	}
}

void
Kit_FormStarted(entity pl, int slot)
{
	if (g_hLogic[slot] == HL_BULKHEAD) {
		Bulkhead_Form(pl, slot, true);
	}
}

void
Kit_FormEnded(entity pl, int slot)
{
	switch (g_hLogic[slot]) {
	case HL_BULKHEAD:
		Bulkhead_Form(pl, slot, false);
		break;
	case HL_DISPATCH:
		while (Hero_PlaceCount(pl, PK_ORDER) > 2i) {
			Hero_UnplaceOldest(pl, PK_ORDER);
		}
		break;
	case HL_LEDGER:
		while (Hero_PlaceCount(pl, PK_PAD) > 2i) {
			Hero_UnplaceOldest(pl, PK_PAD);
		}
		break;
	}
}

void
Kit_Killed(entity pl, int slot)
{
	switch (g_hLogic[slot]) {
	case HL_BULKHEAD:
		/* a carried door falls with him; a planted one stays */
		if (Bulkhead_Door(pl, 0) >= 0i) {
			Hero_Unplace(Bulkhead_Door(pl, 0));
		}
		break;
	case HL_STRAY:
		Stray_Killed(pl, slot);
		break;
	case HL_LONGHAND:
		Longhand_ClearMark(pl, slot);
		break;
	case HL_MANTIS:
		Mantis_EndExecute(pl, slot);
		break;
	}

	pl.flags &= ~FL_NOTARGET;
	Hero_Untouchable(pl, false);
}

void
Kit_NPCKilled(entity pl, int slot, entity npc, entity attacker)
{
	switch (g_hLogic[slot]) {
	case HL_DISPATCH:
		Dispatch_NPCKilled(pl, slot, npc, attacker);
		break;
	case HL_VECTOR:
		Vector_NPCKilled(pl, slot, npc);
		break;
	case HL_LEDGER:
		Ledger_NPCKilled(pl, slot, npc);
		break;
	}
}

string
Kit_Status(entity pl, int slot)
{
	switch (g_hLogic[slot]) {
	case HL_DISPATCH: return (Dispatch_Status(pl, slot));
	case HL_CHOIR: return (Choir_Status(pl, slot));
	case HL_BULKHEAD: return (Bulkhead_Status(pl, slot));
	case HL_KETTLE: return (Kettle_Status(pl, slot));
	case HL_VECTOR: return (Vector_Status(pl, slot));
	case HL_STRAY: return (Stray_Status(pl, slot));
	case HL_LEDGER: return (Ledger_Status(pl, slot));
	case HL_TRIPWIRE: return (Tripwire_Status(pl, slot));
	case HL_LONGHAND: return (Longhand_Status(pl, slot));
	case HL_MANTIS: return (Mantis_Status(pl, slot));
	}

	return ("");
}
