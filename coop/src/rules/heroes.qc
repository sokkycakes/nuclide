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

/* Heroes: players pick a hero and one of its kits, and spawn as that kit.

   - coop_heroes 0 (default) is plain co-op: everyone spawns as player_mp
     with their own player model, and only the XP mod sets players apart.
     1 turns heroes on. Both are read when a map starts.
   - The heroes and kits are defs (coop/decls/def/heroes.def). A kit
     inherits its hero, so the kit is the player class. coop_heroList names
     the heroes on offer, in menu order.
   - The pick is the "*hero" userinfo key (a kit), so it lasts through
     deaths. It takes effect at the next spawn: picking while alive doesn't
     respawn anyone or take away what they bought. Until they pick on this
     server, the client's own "hero" key is used: the hero picked on the
     title menu, saved with the player's config.
   - coop_heroLimit is how many players may play one hero, 0 for any
     number. Someone over the limit gets the first hero with room.
   - A hero has two weapon slots, as in Left 4 Dead: a static one with the
     hero's own weapon (the hero def's "hero_weapon"), given at every spawn
     and never dropped, whose reserve never runs out; and a dynamic one
     with one other gun, from the kit or picked up. Picking up a second gun
     drops the one held. Melee weapons and throwables (HUD slots 0 and 4)
     are outside both. Hero_SlotThink keeps this every frame.
   - "cmd heroes" asks for the list and "cmd hero <kit>" picks. The server
     answers with menu_coop commands, drawn on the Hero tab of the shop
     menu (coop/src/menu/main.qc). A player's first spawn on a map with
     heroes on opens that tab once. */

#define HERO_MAX 16
#define HERO_MAXKITS 32

var bool autocvar_coop_heroes = false;
var string autocvar_coop_heroList = "hero_dispatch hero_choir hero_bulkhead hero_kettle hero_vector hero_stray hero_ledger hero_tripwire hero_longhand hero_mantis hero_tank hero_support hero_pointman";
var int autocvar_coop_heroLimit = 2;

/* g_coopHeroes, heroes on for this map, is declared in coop.qc */
string g_heroDef[HERO_MAX];
int g_heroCount;
string g_heroKit[HERO_MAXKITS];
int g_heroKitHero[HERO_MAXKITS];	/* the hero each kit belongs to */
int g_heroKitCount;
bool g_heroAsked[COOP_MAXPLAYERS];	/* the Hero tab was opened for them */
string g_heroDynamic[COOP_MAXPLAYERS];	/* the gun in their dynamic slot, zoned */
string g_heroSwitch[COOP_MAXPLAYERS];	/* gun to switch to once the client has it, zoned */
float g_heroSwitchTime[COOP_MAXPLAYERS];
float g_heroSettle[COOP_MAXPLAYERS];	/* when to settle the dynamic slot after a spawn, 0 once done */

/* reads coop_heroes and the roster */
void
Hero_Load(void)
{
	string heroes[HERO_MAX];
	int n;

	for (int i = 0i; i < g_heroCount; i++) {
		strunzone(g_heroDef[i]);
	}

	for (int i = 0i; i < g_heroKitCount; i++) {
		strunzone(g_heroKit[i]);
	}

	g_heroCount = 0i;
	g_heroKitCount = 0i;
	g_coopHeroes = autocvar_coop_heroes;

	if (!g_coopHeroes) {
		return;
	}

	/* the lookups tokenize too, so copy the names out first */
	n = min((int)tokenize(autocvar_coop_heroList), HERO_MAX);

	for (int i = 0i; i < n; i++) {
		heroes[i] = argv(i);
	}

	for (int i = 0i; i < n; i++) {
		string kits = entityDef.GetString(heroes[i], "hero_kits");
		int kitCount = (int)tokenizebyseparator(kits, ",");

		if (kitCount <= 0i) {
			print(sprintf("^3coop^7: hero %s has no kits, left out\n", heroes[i]));
			continue;
		}

		for (int k = 0i; k < kitCount && g_heroKitCount < HERO_MAXKITS; k++) {
			g_heroKit[g_heroKitCount] = strzone(argv(k));
			g_heroKitHero[g_heroKitCount] = g_heroCount;
			g_heroKitCount++;
		}

		g_heroDef[g_heroCount] = strzone(heroes[i]);
		g_heroCount++;
	}

	if (g_heroCount <= 0i) {
		print("^3coop^7: coop_heroList has no heroes, heroes are off\n");
		g_coopHeroes = false;
	}
}

void Hero_AbilityPrecache(void);	/* hero_abilities.qc */

void
Hero_Precache(void)
{
	Hero_Load();
	Hero_AbilityPrecache();

	for (int i = 0i; i < g_heroKitCount; i++) {
		precache.Entity(g_heroKit[i]);
	}

	for (int i = 0i; i < g_heroCount; i++) {
		string weapon = entityDef.GetString(g_heroDef[i], "hero_weapon");

		if (weapon != "") {
			precache.Entity(weapon);
		}
	}
}

/* the kit's index, or -1 */
int
Hero_KitIndex(string kit)
{
	for (int i = 0i; i < g_heroKitCount; i++) {
		if (g_heroKit[i] == kit) {
			return (i);
		}
	}

	return (-1i);
}

/* the hero a kit belongs to, or -1 */
int
Hero_OfKit(string kit)
{
	int k = Hero_KitIndex(kit);
	return (k >= 0i) ? g_heroKitHero[k] : -1i;
}

/* the kit pl picked here, or else the one their client saved; "" for none */
string
Hero_Wanted(entity pl)
{
	string kit = userinfo.GetString(pl, "*hero");

	if (Hero_KitIndex(kit) >= 0i) {
		return (kit);
	}

	kit = userinfo.GetString(pl, "hero");
	return (Hero_KitIndex(kit) >= 0i) ? kit : "";
}

/* the hero pl plays now, or picked for the next spawn */
int
Hero_Claimed(entity pl)
{
	int h = Hero_OfKit(Hero_Wanted(pl));
	return (h >= 0i) ? h : Hero_OfKit(pl.classname);
}

/* how many players other than pl play or picked hero h */
int
Hero_Players(int h, entity pl)
{
	int count = 0i;

	for (entity p = world; (p = next.Player(p));) {
		if (p != pl && Hero_Claimed(p) == h) {
			count++;
		}
	}

	return (count);
}

bool
Hero_HasRoom(int h, entity pl)
{
	return (autocvar_coop_heroLimit <= 0i || Hero_Players(h, pl) < autocvar_coop_heroLimit) ? true : false;
}

/* the class pl spawns as */
string
Hero_SpawnClass(entity pl)
{
	string want;
	int h;

	if (!g_coopHeroes) {
		return ("player_mp");
	}

	want = Hero_Wanted(pl);
	h = Hero_OfKit(want);

	if (h >= 0i && Hero_HasRoom(h, pl)) {
		return (want);
	}

	/* keep playing what they play */
	h = Hero_OfKit(pl.classname);

	if (h >= 0i && Hero_HasRoom(h, pl)) {
		return (pl.classname);
	}

	/* the first hero with room, in its first kit */
	for (int k = 0i; k < g_heroKitCount; k++) {
		if (Hero_HasRoom(g_heroKitHero[k], pl)) {
			return (g_heroKit[k]);
		}
	}

	return (g_heroKit[0]);
}

string
Hero_Name(string def, string key)
{
	string name = entityDef.GetString(def, key);
	return (name != "") ? name : def;
}

/* the hero list for the menu */
void
Hero_Send(entity pl, string message)
{
	string picked = Hero_Wanted(pl);

	stuffcmd(pl, sprintf("menu_coop heroes_begin %i \"%s\" \"%s\" \"%s\"\n", g_coopHeroes ? 1i : 0i,
		(Hero_KitIndex(pl.classname) >= 0i) ? pl.classname : "", picked, message));

	for (int h = 0i; h < g_heroCount; h++) {
		string def = g_heroDef[h];
		float speed = stof(entityDef.GetString(def, "pm_walkspeed"));

		if (speed <= 0) {
			speed = cvars.GetFloat("pm_walkspeed");
		}

		/* builtins drop arguments past the eighth, so in two parts */
		stuffcmd(pl, strcat(sprintf("menu_coop heroes_item %i \"%s\" \"%s\" \"%s\" ", h, def,
			Hero_Name(def, "hero_name"), entityDef.GetString(def, "hero_role")),
			sprintf("\"%s\" %d %d %i\n", entityDef.GetString(def, "hero_desc"),
			stof(entityDef.GetString(def, "health")), speed, Hero_HasRoom(h, pl) ? 0i : 1i)));
	}

	for (int k = 0i; k < g_heroKitCount; k++) {
		string kit = g_heroKit[k];

		stuffcmd(pl, sprintf("menu_coop heroes_kit %i %i \"%s\" \"%s\" \"%s\"\n", k, g_heroKitHero[k], kit,
			Hero_Name(kit, "kit_name"), entityDef.GetString(kit, "kit_desc")));
	}

	stuffcmd(pl, "menu_coop heroes_end\n");
}

void
Hero_Select(entity pl, string kit)
{
	int h;

	if (!g_coopHeroes) {
		Hero_Send(pl, "Heroes are off on this server.");
		return;
	}

	h = Hero_OfKit(kit);

	if (h < 0i) {
		Hero_Send(pl, "There's no such kit.");
		return;
	}

	if (!Hero_HasRoom(h, pl)) {
		Hero_Send(pl, sprintf("%s is taken by %i players already.", Hero_Name(g_heroDef[h], "hero_name"),
			autocvar_coop_heroLimit));
		return;
	}

	userinfo.SetString(pl, "*hero", kit);

	if (pl.classname == kit) {
		Hero_Send(pl, "");
	} else if (is.Alive(pl) && autocvar_coop_waves && g_coopWaveState == WAVE_WAITING) {
		/* a checkpoint: between waves the swap happens now, on the spot */
		vector spot = pl.origin;
		vector look = pl.v_angle;

		CodeCallback_PlayerSpawn(pl);
		ents.Input(pl, "SetOrigin", vtos(spot + [0, 0, 4]), pl);
		pl.angles = [0, look[1], 0];
		pl.v_angle = look;
		pl.fixangle = TRUE;
		Hero_Send(pl, sprintf("You're %s now.", Hero_Name(g_heroDef[h], "hero_name")));
	} else if (is.Alive(pl)) {
		Hero_Send(pl, sprintf("You'll be %s, %s, at the next wave break or respawn.", Hero_Name(g_heroDef[h], "hero_name"),
			Hero_Name(kit, "kit_name")));
	} else {
		Hero_Send(pl, sprintf("You'll spawn as %s, %s.", Hero_Name(g_heroDef[h], "hero_name"),
			Hero_Name(kit, "kit_name")));
	}
}

bool
Hero_ClientCommand(entity pl, string command)
{
	tokenize(command);

	switch (argv(0)) {
	case "shop":
		/* the shop menu has the Hero tab too: send it first, the shop opens it */
		if (g_coopHeroes) {
			Hero_Send(pl, "");
		}
		return (false);
	case "heroes":
		Hero_Send(pl, "");
		return (true);
	case "hero":
		Hero_Select(pl, argv(1));
		return (true);
	}

	return (false);
}

/* opens the Hero tab: a moment after the first spawn, because what's sent
   to a client while it's still connecting doesn't reach its menu. By then
   the hero their client saved has come in if they have one. */
void
Hero_AskThink(void)
{
	entity pl = self.owner;
	string wanted;

	if (pl && is.Player(pl)) {
		wanted = Hero_Wanted(pl);

		/* a game started with +map spawns the player before their client
		   sends the hero it saved: spawn them again, as it */
		if (wanted != "") {
			if (is.Alive(pl) && Hero_SpawnClass(pl) != pl.classname) {
				CodeCallback_PlayerSpawn(pl);
			}

			remove(self);
			return;
		}

		Hero_Send(pl, "Pick a hero. A change applies when you respawn.");
		stuffcmd(pl, "menu_coop loadout_open hero\n");
	}

	remove(self);
}

/* the first spawn on a map with heroes on opens the Hero tab, unless they
   came with a hero picked on the title menu (or it comes in by then) */
void
Hero_PlayerSpawned(entity pl)
{
	int slot = Coop_Slot(pl);
	entity asker;

	if (!g_coopHeroes || slot < 0i || g_heroAsked[slot] || is.Bot(pl) || Hero_Wanted(pl) != "") {
		return;
	}

	g_heroAsked[slot] = true;
	asker = spawn();
	asker.owner = pl;
	asker.think = Hero_AskThink;
	asker.nextthink = time + 1.0f;
}

void
Hero_PlayerConnect(entity pl)
{
	int slot = Coop_Slot(pl);

	if (slot >= 0i) {
		g_heroAsked[slot] = false;
	}
}

/* ---- weapon slots ------------------------------------------------------- */

#define HERO_PICKUPDELAY 1.5f	/* before a dropped gun can be picked up */

/* the hero's own weapon, "" for none */
string
Hero_StaticWeapon(entity pl)
{
	return (entityDef.GetString(pl.classname, "hero_weapon"));
}

/* a gun that takes the dynamic slot: not melee or a throwable, not a
   static weapon */
bool
Hero_IsDynamic(string item)
{
	float slot;

	if (substring(item, 0, 7) != "weapon_" || entityDef.GetBool(item, "hero_static")) {
		return (false);
	}

	slot = entityDef.GetFloat(item, "hudSlot");
	return (slot >= 1 && slot <= 3) ? true : false;
}

void
Hero_SetDynamic(int slot, string item)
{
	if (g_heroDynamic[slot]) {
		strunzone(g_heroDynamic[slot]);
	}

	g_heroDynamic[slot] = (item != "") ? strzone(item) : __NULL__;
}

/* lets a dropped gun be picked up again */
void
Hero_DropThink(void)
{
	self.solid = SOLID_TRIGGER;
	setorigin(self, self.origin);
	self.think = __NULL__;
}

/* takes item out of pl's hands and puts it on the ground in front of them */
void
Hero_DropWeapon(entity pl, string item)
{
	entity dropped;
	vector spot;

	ents.Input(pl, "RemoveItem", item, pl);
	makevectors([0, pl.angles[1], 0]);
	spot = pl.origin + v_forward * 64;
	traceline(pl.origin, spot, MOVE_NOMONSTERS, pl);
	dropped = ents.Create(item, trace_endpos);

	/* not straight back into the hands that dropped it */
	dropped.solid = SOLID_NOT;
	setorigin(dropped, dropped.origin);
	dropped.think = Hero_DropThink;
	dropped.nextthink = time + HERO_PICKUPDELAY;
}

/* the hero's weapons at spawn: the static one and its reserve. The kit's
   own items arrive after the spawn callback, so Hero_SlotThink settles
   the dynamic slot a moment later */
void
Hero_GiveWeapons(entity pl)
{
	int slot = Coop_Slot(pl);
	string weapon = Hero_StaticWeapon(pl);

	if (slot < 0i) {
		return;
	}

	if (weapon != "" && !actor.HasItem(pl, weapon)) {
		ents.Input(pl, "GiveItem", weapon, pl);
	}

	ents.Input(pl, "GiveAmmo", "ammo_hero 200", pl);
	Hero_SetDynamic(slot, "");
	g_heroSettle[slot] = time + 0.25f;
}

/* puts pl on item. A switch made on the server alone leaves the client
   drawing the old view model, so players are asked to select it */
void
Hero_SelectWeapon(entity pl, string item)
{
	if (is.Bot(pl)) {
		ents.Input(pl, "SwitchToWeapon", item, pl);
	} else {
		stuffcmd(pl, sprintf("selectItem %s\n", item));
	}
}

/* every frame, for each living hero: one gun in the dynamic slot, the
   static weapon kept and its reserve full */
void
Hero_SlotThink(entity pl)
{
	int slot = Coop_Slot(pl);
	string held = (slot >= 0i && g_heroDynamic[slot]) ? g_heroDynamic[slot] : "";
	string picked = "";
	bool hasHeld = false;
	int n;

	if (!g_coopHeroes || slot < 0i || !is.Alive(pl) || Hero_OfKit(pl.classname) < 0i) {
		return;
	}

	n = (int)tokenize(actor.GetInventory(pl));

	/* just after spawning, once the kit's items are in: the kit's gun is
	   the dynamic one, and a kit without a gun (or a hero with abilities)
	   starts with the static weapon out */
	if (g_heroSettle[slot] > 0.0f) {
		if (time < g_heroSettle[slot]) {
			return;
		}

		g_heroSettle[slot] = 0.0f;

		for (int i = 0i; i < n; i++) {
			if (Hero_IsDynamic(argv(i))) {
				picked = argv(i);
			}
		}

		Hero_SetDynamic(slot, picked);

		/* the ten example heroes start with their primary, the static one */
		if ((picked == "" || entityDef.GetString(pl.classname, "hero_logic") != "") && Hero_StaticWeapon(pl) != "") {
			Hero_SelectWeapon(pl, Hero_StaticWeapon(pl));
		}

		return;
	}

	for (int i = 0i; i < n; i++) {
		string item = argv(i);

		if (!Hero_IsDynamic(item)) {
			continue;
		}

		if (item == held) {
			hasHeld = true;
		} else {
			picked = item;
		}
	}

	if (picked != "") {
		/* a second gun came in: it takes the slot, the old one goes */
		if (hasHeld) {
			Hero_DropWeapon(pl, held);

			/* the picked-up gun is a new entity: the client can only
			   select it once it has been sent */
			if (g_heroSwitch[slot]) {
				strunzone(g_heroSwitch[slot]);
			}

			g_heroSwitch[slot] = strzone(picked);
			g_heroSwitchTime[slot] = time + 0.1f;
		}

		Hero_SetDynamic(slot, picked);
	} else if (!hasHeld && held != "") {
		Hero_SetDynamic(slot, "");
	}

	if (g_heroSwitch[slot] && time >= g_heroSwitchTime[slot]) {
		Hero_SelectWeapon(pl, g_heroSwitch[slot]);
		strunzone(g_heroSwitch[slot]);
		g_heroSwitch[slot] = __NULL__;
	}

	if (actor.GetReserveAmmo(pl, ammo.NumForName("ammo_hero")) < 200i) {
		ents.Input(pl, "GiveAmmo", "ammo_hero 200", pl);
	}
}
