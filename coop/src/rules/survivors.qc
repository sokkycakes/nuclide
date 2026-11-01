/* Survivor bots: AI teammates in the manner of Left 4 Dead's survivor bots.

   - coop_survivorBots (1) is how many of them the server keeps while at
     least one human is playing. They're Nuclide's own bots (addBot), so
     they spawn, pick a hero, shoot and are revived like anyone else; this
     file only adds what makes them teammates. Bots added by hand count
     towards the number too.
   - They stay with the humans: a bot further than coop_survivorFollow (320)
     from the nearest human, with no foe near it, walks back to them. One
     further than coop_survivorWarp (2000) that no human can see is moved
     to just behind that human, as Left 4 Dead does with stragglers.
   - Reviving comes first: Coop_BotThink (coop.qc) sends bots to downed
     teammates within coop_botReviveRange, and standing by the body revives.
   - Heroes: a bot engages (Z) once it has the Energy and three or more foes
     are within 512 units.
   - "sv coop_survivors" lists them with their leader and distance. */

var int autocvar_coop_survivorBots = 1;
var float autocvar_coop_survivorFollow = 320;
var float autocvar_coop_survivorWarp = 2000;
var string autocvar_coop_survivorProfiles = "Gina,Gordon,Helmet,Barney";	/* scripts/bots.txt */

float g_survivorNext;	/* when to check the bot count again */
int g_survivorAdded;	/* bots this map asked for, to take turns at the profiles */

int
Survivor_HumanCount(void)
{
	int c = 0i;

	for (entity p = world; (p = next.Player(p));) {
		if (!is.Bot(p) && p.classname != "spectator") {
			c++;
		}
	}

	return (c);
}

int
Survivor_BotCount(void)
{
	int c = 0i;

	for (entity p = world; (p = next.Player(p));) {
		if (is.Bot(p)) {
			c++;
		}
	}

	return (c);
}

/* the living human nearest to org */
entity
Survivor_Leader(vector org)
{
	entity best = world;
	float bestDist = 999999;

	for (entity p = world; (p = next.Player(p));) {
		if (is.Bot(p) || !is.Alive(p) || p.classname == "spectator") {
			continue;
		}

		float d = vlen(p.origin - org);

		if (d < bestDist) {
			bestDist = d;
			best = p;
		}
	}

	return (best);
}

/* foes within dist of org */
int
Survivor_FoesNear(vector org, float dist)
{
	int c = 0i;

	for (entity e = findradius(org, dist); e; e = e.chain) {
		if (Hero_IsFoe(e)) {
			c++;
		}
	}

	return (c);
}

/* true when a human can see pl */
bool
Survivor_Seen(entity pl)
{
	for (entity p = world; (p = next.Player(p));) {
		if (is.Bot(p) || !is.Alive(p)) {
			continue;
		}

		traceline(p.origin + p.view_ofs, pl.origin + [0, 0, 16], MOVE_NOMONSTERS, p);

		if (trace_fraction >= 1.0f) {
			return (true);
		}
	}

	return (false);
}

/* moves pl to a free spot just behind leader */
bool
Survivor_Warp(entity pl, entity leader)
{
	makevectors([0, leader.angles[1], 0]);

	for (float side = -1; side <= 1; side++) {
		vector spot = leader.origin - v_forward * 64 + v_right * side * 48;

		tracebox(spot, pl.mins, pl.maxs, spot, MOVE_NORMAL, pl);

		if (!trace_startsolid && !trace_allsolid) {
			setorigin(pl, spot);
			pl.velocity = [0, 0, 0];
			return (true);
		}
	}

	return (false);
}

/* every half second from Coop_BotThink, for each living bot without a
   revive to go to */
void
Survivor_BotThink(entity pl, int slot)
{
	entity leader;
	float dist;
	int foes;

	if (autocvar_coop_survivorBots <= 0i) {
		return;
	}

	leader = Survivor_Leader(pl.origin);

	if (!leader) {
		return;
	}

	dist = vlen(leader.origin - pl.origin);
	foes = Survivor_FoesNear(pl.origin, 512);

	/* heroes: engage when it's crowded */
	if (Hero_Active(pl) && !Hero_InForm(slot) && foes >= 3i && g_hEnergy[slot] >= autocvar_coop_engageCost) {
		Hero_EngageStart(pl, slot);
	}

	if (dist > autocvar_coop_survivorWarp && !Survivor_Seen(pl)) {
		Survivor_Warp(pl, leader);
		return;
	}

	/* stay with the humans, unless there's fighting to do here */
	if (dist > autocvar_coop_survivorFollow && foes == 0i) {
		makevectors([0, leader.angles[1], 0]);
		ents.Input(pl, "GoToPosition", vtos(leader.origin - v_forward * 96), pl);
	}
}

/* every frame: keep coop_survivorBots bots in while humans play */
void
Survivor_Frame(void)
{
	int names;

	if (time < g_survivorNext || !g_coopStarted) {
		return;
	}

	g_survivorNext = time + 2.0f;

	if (autocvar_coop_survivorBots <= 0i || Survivor_HumanCount() <= 0i) {
		return;
	}

	if (Survivor_BotCount() >= autocvar_coop_survivorBots) {
		return;
	}

	/* Nuclide's own addBot (botlib/profiles.qc), called directly: a console
	   "addBot" from here reaches the engine's command of that name */
	bool(string, float, float, string) addBot = externvalue(0, "Bot_AddBot_f");

	if (!addBot) {
		return;
	}

	names = (int)tokenizebyseparator(autocvar_coop_survivorProfiles, ",");
	string profile = strtolower((names > 0i) ? argv(g_survivorAdded % names) : "gina");
	g_survivorAdded++;

	/* the profile names it (Gina, Gordon, ...) */
	addBot(profile, 0, 0, __NULL__);
}

/* "sv coop_survivors" */
void
Survivor_List(void)
{
	/* "sv coop_survivors stack": puts the bots inside the first human, to
	   test Coop_Unstick */
	/* "sv coop_survivors hurt": the bots at 30 health, 120 units in front
	   of the first human, to test the Medic */
	if (argv(1) == "hurt") {
		for (entity hh = world; (hh = next.Player(hh));) {
			if (!is.Bot(hh) && is.Alive(hh)) {
				makevectors([0, hh.v_angle[1], 0]);

				for (entity bb = world; (bb = next.Player(bb));) {
					if (is.Bot(bb) && is.Alive(bb)) {
						setorigin(bb, hh.origin + v_forward * 120);
						ents.Input(bb, "SetHealth", "30", hh);
					}
				}
				break;
			}
		}
	}

	if (argv(1) == "stack") {
		entity human = world;

		for (entity h = world; (h = next.Player(h));) {
			if (!is.Bot(h) && is.Alive(h)) {
				human = h;
				break;
			}
		}

		for (entity b = world; human && (b = next.Player(b));) {
			if (is.Bot(b) && is.Alive(b)) {
				setorigin(b, human.origin);
			}
		}
	}

	for (entity p = world; (p = next.Player(p));) {
		if (!is.Bot(p)) {
			continue;
		}

		entity leader = Survivor_Leader(p.origin);
		print(sprintf("%s: %s, leader %s at %d, %i foes near\n", p.netname, is.Alive(p) ? "alive" : "down",
			leader ? leader.netname : "none", leader ? vlen(leader.origin - p.origin) : 0,
			Survivor_FoesNear(p.origin, 512)));
	}
}

/* ---- nobody stays stuck inside a teammate ----

   Two players whose boxes overlap can't move at all, since each one starts
   every move inside the other. That happens when someone is revived (or
   respawned) where a teammate stands, or a bot is warped. Five times a
   second, overlapping living players are pulled apart: the bot moves when
   one of them is a bot, else the second one, to the nearest free spot. */

var bool autocvar_coop_unstick = true;
float g_unstickNext;

/* org if who fits there, else the nearest free spot around it that can be
   seen from org, else org */
vector
Coop_FreeSpot(entity who, vector org)
{
	tracebox(org, who.mins, who.maxs, org, MOVE_NORMAL, who);

	if (!trace_startsolid && !trace_allsolid) {
		return (org);
	}

	for (float dist = 40; dist <= 136; dist += 32) {
		for (float yaw = 0; yaw < 360; yaw += 45) {
			vector spot = org + [cos(yaw * (M_PI / 180)), sin(yaw * (M_PI / 180)), 0] * dist;

			traceline(org, spot, MOVE_NOMONSTERS, who);

			if (trace_fraction < 1.0f) {
				continue;
			}

			tracebox(spot, who.mins, who.maxs, spot, MOVE_NORMAL, who);

			if (!trace_startsolid && !trace_allsolid) {
				return (spot);
			}
		}
	}

	return (org);
}

bool
Coop_Overlap(entity a, entity b)
{
	return (a.absmin[0] < b.absmax[0] && a.absmax[0] > b.absmin[0]
		&& a.absmin[1] < b.absmax[1] && a.absmax[1] > b.absmin[1]
		&& a.absmin[2] < b.absmax[2] && a.absmax[2] > b.absmin[2]) ? true : false;
}

void
Coop_Unstick(void)
{
	if (!autocvar_coop_unstick || time < g_unstickNext) {
		return;
	}

	g_unstickNext = time + 0.2f;

	for (entity p = world; (p = next.Player(p));) {
		if (!is.Alive(p) || p.classname == "spectator" || p.solid != SOLID_SLIDEBOX) {
			continue;
		}

		for (entity q = p; (q = next.Player(q));) {
			if (!is.Alive(q) || q.classname == "spectator" || q.solid != SOLID_SLIDEBOX) {
				continue;
			}

			if (!Coop_Overlap(p, q)) {
				continue;
			}

			entity mover = (is.Bot(p) && !is.Bot(q)) ? p : q;
			vector spot = Coop_FreeSpot(mover, mover.origin);

			if (spot != mover.origin) {
				setorigin(mover, spot);
				mover.velocity = [0, 0, 0];
				print(sprintf("coop: moved %s out of %s\n", mover.netname, (mover == p) ? q.netname : p.netname));
			}
		}
	}
}

/* ---- corpses fade away like gibs ----

   A dead monster stays where it fell for good in Nuclide. In co-op it waits
   coop_corpseTime (15) seconds, then fades out the way gibs do (255 to 0,
   7 every tenth of a second, about 3.6 s) and goes. Wave monsters are
   removed; map-placed ones (with a targetname, which something may still
   point at) are only hidden. 0 keeps corpses. Players' bodies aren't
   touched: reviving needs them. */

var float autocvar_coop_corpseTime = 15;

void
Coop_CorpseThink(void)
{
	entity npc = self.owner;

	/* gibbed, removed, or alive again (a corpse keeps some health, for gibbing) */
	if (!npc || wasfreed(npc) || !npc.modelindex || npc.solid != SOLID_CORPSE || is.Player(npc)) {
		remove(self);
		return;
	}

	if (self.health == 0) {
		self.health = 255;
		ents.Input(npc, "SetRenderMode", "2", world);
	} else {
		self.health -= 7;
	}

	if (self.health > 0) {
		ents.Input(npc, "Alpha", ftos(self.health), world);
		self.nextthink = time + 0.1f;
		return;
	}

	ents.Input(npc, (npc.targetname == "") ? "Kill" : "Disappear", "", world);
	remove(self);
}

void
Coop_CorpseFade(entity npc)
{
	if (autocvar_coop_corpseTime <= 0 || !npc || is.Player(npc)) {
		return;
	}

	entity fader = spawn();
	fader.classname = "coop_corpsefade";
	fader.owner = npc;
	fader.health = 0;
	fader.think = Coop_CorpseThink;
	fader.nextthink = time + autocvar_coop_corpseTime;
}
