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
