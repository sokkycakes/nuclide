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

/* Points shop: players spend the points they earn on weapons, ammo,
   health and armour.

   - Points are earned with the score (Coop_AddPoints) but kept apart from
     it, so buying doesn't lower anyone's score.
   - coop_shop 0 turns the shop off, 1 (default) opens it at any time,
     2 only between waves.
   - The price list is coop_shopFile (scripts/shop.txt), read when a map
     starts.
   - "cmd shop" asks for the list. The server answers with menu_coop
     commands (coop/src/menu/main.qc draws the shop), so a client always
     shows this server's prices. "cmd buy <n>" buys item n and sends the
     list again with the new balance. */

#define SHOP_MAXITEMS 64

var int autocvar_coop_shop = 1;
var string autocvar_coop_shopFile = "scripts/shop.txt";
var float autocvar_coop_shopMaxHealth = 100;
var float autocvar_coop_shopMaxArmor = 100;

.float armor;

string g_shopCategory[SHOP_MAXITEMS];
string g_shopGive[SHOP_MAXITEMS];
string g_shopName[SHOP_MAXITEMS];
int g_shopPrice[SHOP_MAXITEMS];
int g_shopCount;

int g_coopPoints[COOP_MAXPLAYERS];

void
Coop_AddPoints(entity pl, int amount)
{
	int slot = Coop_Slot(pl);

	pl.frags += amount;

	if (slot >= 0i) {
		g_coopPoints[slot] = max(0i, g_coopPoints[slot] + amount);
	}
}

int
Coop_Points(entity pl)
{
	int slot = Coop_Slot(pl);
	return (slot >= 0i) ? g_coopPoints[slot] : 0i;
}

void
Shop_Load(void)
{
	filestream fh;
	string line;

	for (int i = 0i; i < g_shopCount; i++) {
		strunzone(g_shopCategory[i]);
		strunzone(g_shopGive[i]);
		strunzone(g_shopName[i]);
	}

	g_shopCount = 0i;
	fh = fopen(autocvar_coop_shopFile, FILE_READ);

	if (fh < 0) {
		print(sprintf("^3coop^7: no shop list %s\n", autocvar_coop_shopFile));
		return;
	}

	while ((line = fgets(fh))) {
		if (tokenize_console(line) < 4 || substring(argv(0), 0, 2) == "//") {
			continue;
		}

		if (g_shopCount >= SHOP_MAXITEMS) {
			print(sprintf("^3coop^7: %s has more than %d items\n", autocvar_coop_shopFile, SHOP_MAXITEMS));
			break;
		}

		g_shopCategory[g_shopCount] = strzone(argv(0));
		g_shopGive[g_shopCount] = strzone(argv(1));
		g_shopPrice[g_shopCount] = stoi(argv(2));
		g_shopName[g_shopCount] = strzone(argv(3));
		g_shopCount++;
	}

	fclose(fh);
}

/* why pl can't shop right now, or "" */
string
Shop_Closed(entity pl)
{
	if (autocvar_coop_shop <= 0i) {
		return ("The shop is closed on this server.");
	}

	if (autocvar_coop_shop == 2i && g_coopWaveState != WAVE_WAITING) {
		return ("The shop opens between waves.");
	}

	if (!is.Alive(pl)) {
		return ("You can't shop while you're down.");
	}

	return ("");
}

/* why pl can't buy item n, or "" */
string
Shop_Refuse(entity pl, int n)
{
	tokenize(g_shopGive[n]);

	switch (argv(0)) {
	case "health":
		if (pl.health >= autocvar_coop_shopMaxHealth) {
			return ("Your health is full.");
		}
		break;
	case "armor":
		if (pl.armor >= autocvar_coop_shopMaxArmor) {
			return ("Your armour is full.");
		}
		break;
	default:
		if (substring(argv(0), 0, 7) == "weapon_" && actor.HasItem(pl, argv(0))) {
			return ("You have one.");
		}
	}

	if (Coop_Points(pl) < g_shopPrice[n]) {
		return ("Not enough points.");
	}

	return ("");
}

/* item states for the menu: 0 can buy, 1 can't afford, 2 owned, 3 full */
int
Shop_State(entity pl, int n)
{
	switch (Shop_Refuse(pl, n)) {
	case "":
		return (0i);
	case "Not enough points.":
		return (1i);
	case "You have one.":
		return (2i);
	default:
		return (3i);
	}
}

void
Shop_Send(entity pl, string message)
{
	string closed = Shop_Closed(pl);

	stuffcmd(pl, sprintf("menu_coop shop_begin %i \"%s\" \"%s\"\n", Coop_Points(pl), closed, message));

	if (closed == "") {
		for (int i = 0i; i < g_shopCount; i++) {
			stuffcmd(pl, sprintf("menu_coop shop_item %i %s \"%s\" %i %i\n", i, g_shopCategory[i],
				g_shopName[i], g_shopPrice[i], Shop_State(pl, i)));
		}
	}

	stuffcmd(pl, "menu_coop shop_end\n");
}

void
Shop_Buy(entity pl, int n)
{
	string why;
	string what;
	float amount;

	if (n < 0i || n >= g_shopCount) {
		return;
	}

	why = Shop_Closed(pl);

	if (why == "") {
		why = Shop_Refuse(pl, n);
	}

	if (why != "") {
		Shop_Send(pl, why);
		return;
	}

	tokenize(g_shopGive[n]);
	what = argv(0);
	amount = stof(argv(1));

	switch (what) {
	case "health":
		ents.Input(pl, "SetHealth", ftos(min(autocvar_coop_shopMaxHealth, pl.health + amount)), pl);
		break;
	case "armor":
		ents.Input(pl, "SetArmor", ftos(min(autocvar_coop_shopMaxArmor, pl.armor + amount)), pl);
		break;
	default:
		if (substring(what, 0, 5) == "ammo_") {
			ents.Input(pl, "GiveAmmo", g_shopGive[n], pl);
		} else {
			ents.Input(pl, "GiveItem", what, pl);
		}
	}

	g_coopPoints[Coop_Slot(pl)] -= g_shopPrice[n];
	print(sprintf("coop: %s bought %s for %i\n", pl.netname, g_shopName[n], g_shopPrice[n]));
	Shop_Send(pl, sprintf("Bought %s.", g_shopName[n]));
}

bool
Shop_ClientCommand(entity pl, string command)
{
	tokenize(command);

	switch (argv(0)) {
	case "shop":
		Shop_Send(pl, "");
		return (true);
	case "buy":
		Shop_Buy(pl, stoi(argv(1)));
		return (true);
	}

	return (false);
}

void
Shop_PlayerConnect(entity pl)
{
	int slot = Coop_Slot(pl);

	if (slot >= 0i) {
		g_coopPoints[slot] = 0i;
	}
}
