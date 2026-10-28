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

/* XP mod: players earn experience from their score, level up to 1800 and
   spend a point per level on nine skills (health, armour, regeneration,
   ammo, low gravity, team support, blocking...). Progress is saved per
   player. The gameplay follows the classic Sven Co-op XP mod (SCXPM); see
   xpm-spec.md next to this file for the numbers. This is a fresh
   implementation from that description.

   Loaded by the co-op rules (coop_plugins) or with "sv addon load xpm". */

#define SERVER


/* the player's armour, a field of Nuclide's ncSurfacePropEntity */
.float armor;

#define XPM_VERSION "1.0"
#define XPM_MAXLEVEL 1800i
#define XPM_MAXMEDALS 15i
#define XPM_PLAYERS 64
#define XPM_TICK 0.5
#define XPM_FASTTICK 0.05
#define XPM_TEAMRANGE 650
#define XPM_SAVETICKS 60i

var float autocvar_xpm_xpgain = 1.0;	/* XP per point of score is 5 * this */
var string autocvar_xpm_admins = "";	/* names allowed to use the admin commands */
var bool autocvar_xpm_hud = true;
var bool autocvar_xpm_textmenu = false;	/* the plain text menu instead of co-op's Panorama one */

enum
{
	SK_STRENGTH,
	SK_ARMOR,
	SK_REGEN,
	SK_NANOARMOR,
	SK_AMMO,
	SK_GRAVITY,
	SK_AWARENESS,
	SK_TEAMPOWER,
	SK_BLOCK,
	SK_COUNT
};

const string g_xpmSkillNames[SK_COUNT] = {
	"Strength",
	"Superior Armor",
	"Health Regeneration",
	"Nano Armor",
	"Ammo Reincarnation",
	"Anti Gravity Device",
	"Awareness",
	"Team Power",
	"Block Attack"
};

const int g_xpmSkillCaps[SK_COUNT] = {
	450i, 450i, 300i, 300i, 30i, 40i, 80i, 60i, 90i
};

typedef struct
{
	bool loaded;
	string key;
	int xp;
	int level;
	int points;
	int medals;	/* 0 to XPM_MAXMEDALS */
	int skill[SK_COUNT];

	float lastScore;
	bool wasAlive;
	float baseHealth;	/* what the game spawned them with */
	float baseArmor;
	int healthWait;
	int armorWait;
	int ammoWait;
	bool blocking;
	float oldTakeDamage;
	bool lowGravity;
	bool menuOpen;
} xpmPlayer_t;

static xpmPlayer_t g_xpm[XPM_PLAYERS];
static entity g_xpmTicker;
static entity g_xpmFastTicker;
static int g_xpmSaveTicks;	/* everyone is saved every XPM_SAVETICKS ticks */

/* ---- helpers ------------------------------------------------------------ */

static int
XPM_Slot(entity pl)
{
	int n = (int)num_for_edict(pl) - 1i;
	return (n >= 0i && n < XPM_PLAYERS) ? n : -1i;
}

static bool
XPM_IsPlayer(entity e)
{
	return (e && is.Player(e)) ? true : false;
}

static bool
XPM_Alive(entity e)
{
	return (XPM_IsPlayer(e) && e.health > 0 && e.deadflag == 0) ? true : false;
}

static int
XPM_NeededXP(int level)
{
	return (int)rint(70 * level + 3.5 * level * level + 30);
}

static string
XPM_Rank(int level)
{
	if (level >= 1800i) return "Highest Force Leader";
	if (level >= 1700i) return "Highest Force Member";
	if (level >= 1600i) return "Top 15 of most famous Leaders";
	if (level >= 1500i) return "Top 30 of most famous Leaders";
	if (level >= 1400i) return "General";
	if (level >= 1300i) return "Hidden Operations Leader";
	if (level >= 1200i) return "Hidden Operations Scheduler";
	if (level >= 1100i) return "Hidden Operations Member";
	if (level >= 1000i) return "United Forces Leader";
	if (level >= 900i) return "United Forces Member";
	if (level >= 800i) return "Special Force Leader";
	if (level >= 700i) return "Special Force Member";
	if (level >= 600i) return "Professional Force Leader";
	if (level >= 500i) return "Professional Force Member";
	if (level >= 400i) return "Professional Free Agent";
	if (level >= 300i) return "Free Agent";
	if (level >= 200i) return "Private First Class";
	if (level >= 100i) return "Private Second Class";
	if (level >= 50i) return "Private Third Class";
	if (level >= 20i) return "Fighter";
	if (level >= 5i) return "Civilian";
	return "Frightened Civilian";
}

static void
XPM_Tell(entity pl, string msg)
{
	sprint(pl, PRINT_HIGH, sprintf("^3[XPM]^7 %s\n", msg));
}

/* a text channel on one player's HUD (EV_TEXT_STRING, as game_text sends) */
static void
XPM_HudText(entity pl, int channel, string text, float x, float y, vector col, float hold)
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
	WriteFloat(MSG_MULTICAST, 0.2f);
	WriteFloat(MSG_MULTICAST, hold);
	WriteFloat(MSG_MULTICAST, 0.0f);
	msg_entity = pl;
	multicast([0,0,0], MULTICAST_ONE_R);
}

/* the most health or armour skills let a player have */
static float
XPM_HealthCap(int s, bool armour)
{
	float base = armour ? g_xpm[s].baseArmor : g_xpm[s].baseHealth;
	int bonus = armour ? g_xpm[s].skill[SK_ARMOR] : g_xpm[s].skill[SK_STRENGTH];
	return base + bonus + g_xpm[s].medals + floor(g_xpm[s].skill[SK_AWARENESS] / 2);
}

static void
XPM_AddHealth(entity pl, float amount, float cap)
{
	float newHealth = min(pl.health + amount, cap);

	if (newHealth <= pl.health) {
		return;
	}

	if (pl.max_health < newHealth) {
		ents.Input(pl, "SetMaxHealth", ftos(newHealth), world);
	}

	ents.Input(pl, "SetHealth", ftos(newHealth), world);
}

static void
XPM_AddArmor(entity pl, float amount, float cap)
{
	float newArmor = min(pl.armor + amount, cap);

	if (newArmor <= pl.armor) {
		return;
	}

	ents.Input(pl, "SetMaxArmor", ftos(max(cap, 100)), world);
	ents.Input(pl, "SetArmor", ftos(newArmor), world);
}

/* ---- saving ------------------------------------------------------------- */

static string
XPM_KeyFor(entity pl)
{
	string playerId = infokey(pl, "*guid");

	if (playerId == "") {
		playerId = infokey(pl, "*cert_sha1");
	}

	if (playerId == "") {
		playerId = strcat("name_", infokey(pl, "name"));
	}

	/* keep it a plain file name */
	string safe = "";

	for (float i = 0; i < strlen(playerId); i++) {
		float c = str2chr(playerId, i);

		if ((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c == 45) {
			safe = strcat(safe, chr2str(c));
		} else {
			safe = strcat(safe, "_");
		}
	}

	return safe;
}

static void
XPM_Save(int s)
{
	filestream f;
	string line;

	if (!g_xpm[s].loaded || g_xpm[s].key == "") {
		return;
	}

	f = fopen(sprintf("data/xpm/%s.txt", g_xpm[s].key), FILE_WRITE);

	if (f < 0) {
		return;
	}

	line = sprintf("%i %i %i %i", g_xpm[s].xp, g_xpm[s].level, g_xpm[s].points, g_xpm[s].medals);

	for (int i = 0i; i < SK_COUNT; i++) {
		line = strcat(line, " ", itos(g_xpm[s].skill[i]));
	}

	fputs(f, strcat(line, "\n"));
	fclose(f);
}

static void
XPM_Load(entity pl, int s)
{
	filestream f;
	string line;

	/* bots level up for the match but aren't saved */
	g_xpm[s].key = (clienttype(pl) == CLIENTTYPE_BOT) ? "" : strzone(XPM_KeyFor(pl));
	g_xpm[s].xp = 0i;
	g_xpm[s].level = 0i;
	g_xpm[s].points = 0i;
	g_xpm[s].medals = 3i;

	for (int i = 0i; i < SK_COUNT; i++) {
		g_xpm[s].skill[i] = 0i;
	}

	f = fopen(sprintf("data/xpm/%s.txt", g_xpm[s].key), FILE_READ);

	if (f >= 0) {
		line = fgets(f);
		fclose(f);

		if (tokenize(line) >= 4 + SK_COUNT) {
			g_xpm[s].xp = stoi(argv(0));
			g_xpm[s].level = bound(0i, stoi(argv(1)), XPM_MAXLEVEL);
			g_xpm[s].points = max(0i, stoi(argv(2)));
			g_xpm[s].medals = bound(0i, stoi(argv(3)), XPM_MAXMEDALS);

			for (int i = 0i; i < SK_COUNT; i++) {
				g_xpm[s].skill[i] = bound(0i, stoi(argv(4i + i)), g_xpmSkillCaps[i]);
			}
		}
	} else {
		XPM_Tell(pl, "Welcome! The XP mod is on. Say /selectskills, /resetskills, /playerskills or /skillsinfo.");
	}

	g_xpm[s].lastScore = pl.frags;
	g_xpm[s].wasAlive = false;
	g_xpm[s].loaded = true;
}

/* ---- menu --------------------------------------------------------------- */

static void
XPM_ShowMenu(entity pl, int s)
{
	/* co-op's menu progs draws it (coop/src/menu/main.qc, panorama/scripts/coop/skills.js) */
	if (!autocvar_xpm_textmenu) {
		stuffcmd(pl, sprintf("menu_coop skills_begin %i %i \"%s\"\n", g_xpm[s].points, g_xpm[s].level, XPM_Rank(g_xpm[s].level)));

		for (int i = 0i; i < SK_COUNT; i++) {
			stuffcmd(pl, sprintf("menu_coop skills_item %i \"%s\" %i %i\n", i + 1i, g_xpmSkillNames[i], g_xpm[s].skill[i], g_xpmSkillCaps[i]));
		}

		stuffcmd(pl, "menu_coop skills_end\n");
		g_xpm[s].menuOpen = true;
		return;
	}

	string text = sprintf("Select Skills - Skillpoints available: %i\\n\\n", g_xpm[s].points);

	for (int i = 0i; i < SK_COUNT; i++) {
		text = strcat(text, sprintf("%i. %s  [ %i / %i ]\\n", i + 1i, g_xpmSkillNames[i], g_xpm[s].skill[i], g_xpmSkillCaps[i]));
	}

	text = strcat(text, "\\n0. Done");
	stuffcmd(pl, sprintf("svmenu \"%s\"\n", text));
	g_xpm[s].menuOpen = true;
}

static void
XPM_Spend(entity pl, int s, int skillNum)
{
	if (g_xpm[s].points <= 0i) {
		XPM_Tell(pl, sprintf("You need a skill point to improve %s.", g_xpmSkillNames[skillNum]));
		return;
	}

	if (g_xpm[s].skill[skillNum] >= g_xpmSkillCaps[skillNum]) {
		XPM_Tell(pl, sprintf("%s is already mastered.", g_xpmSkillNames[skillNum]));
	} else {
		g_xpm[s].points--;
		g_xpm[s].skill[skillNum]++;
		XPM_Tell(pl, sprintf("%s is now level %i.", g_xpmSkillNames[skillNum], g_xpm[s].skill[skillNum]));

		/* the flat bonuses apply at once */
		if (XPM_Alive(pl) && skillNum == SK_STRENGTH) {
			XPM_AddHealth(pl, 1, XPM_HealthCap(s, false));
		} else if (XPM_Alive(pl) && skillNum == SK_ARMOR) {
			XPM_AddArmor(pl, 1, XPM_HealthCap(s, true));
		}
	}

	/* the Panorama menu is told too, so it can close when the points run out */
	if (g_xpm[s].points > 0i || !autocvar_xpm_textmenu) {
		XPM_ShowMenu(pl, s);
	}
}

static void
XPM_ResetSkills(entity pl, int s)
{
	for (int i = 0i; i < SK_COUNT; i++) {
		g_xpm[s].skill[i] = 0i;
	}

	g_xpm[s].points = g_xpm[s].level;

	if (XPM_Alive(pl)) {
		if (pl.health > XPM_HealthCap(s, false)) {
			ents.Input(pl, "SetHealth", ftos(XPM_HealthCap(s, false)), world);
		}

		if (pl.armor > XPM_HealthCap(s, true)) {
			ents.Input(pl, "SetArmor", ftos(XPM_HealthCap(s, true)), world);
		}
	}

	pl.gravity = 1.0;

	if (g_xpm[s].points > 0i) {
		XPM_Tell(pl, "Your skills were reset. Choose again...");
		XPM_ShowMenu(pl, s);
	} else {
		XPM_Tell(pl, "You have no skills to reset.");
	}
}

static void
XPM_PrintPlayers(entity pl)
{
	XPM_Tell(pl, "Player                  Level  Medals");

	for (entity p = world; (p = next.Player(p));) {
		int ps = XPM_Slot(p);

		if (ps >= 0i && g_xpm[ps].loaded) {
			string name = p.netname;

			while (strlen(name) < 20) {
				name = strcat(name, " ");
			}

			sprint(pl, PRINT_HIGH, sprintf("  %s  %i  %i\n", name, g_xpm[ps].level, g_xpm[ps].medals));
		}
	}
}

static void
XPM_PrintSkillsInfo(entity pl)
{
	XPM_Tell(pl, "Skills:");
	sprint(pl, PRINT_HIGH, "  1. Strength: +1 health per level\n");
	sprint(pl, PRINT_HIGH, "  2. Superior Armor: +1 armour per level\n");
	sprint(pl, PRINT_HIGH, "  3. Health Regeneration: 1 HP every (150 - level/2) s, plus a chance each half second\n");
	sprint(pl, PRINT_HIGH, "  4. Nano Armor: the same for armour\n");
	sprint(pl, PRINT_HIGH, "  5. Ammo Reincarnation: ammo every (90 - 2.5 * level) s\n");
	sprint(pl, PRINT_HIGH, "  6. Anti Gravity Device: 1.5% less gravity per level while you hold jump\n");
	sprint(pl, PRINT_HIGH, "  7. Awareness: improves the other skills a little\n");
	sprint(pl, PRINT_HIGH, "  8. Team Power: heals and armours teammates near you\n");
	sprint(pl, PRINT_HIGH, "  9. Block Attack: (level / 3)% chance to block every attack\n");
	sprint(pl, PRINT_HIGH, "  Medals: given by admins, add a little to most skills\n");
}

/* ---- leveling ----------------------------------------------------------- */

static void
XPM_GainXP(entity pl, int s)
{
	float newScore = pl.frags - g_xpm[s].lastScore;
	g_xpm[s].lastScore = pl.frags;

	if (g_xpm[s].level >= XPM_MAXLEVEL) {
		return;
	}

	if (newScore > 0) {
		g_xpm[s].xp += (int)rint(newScore * 5 * autocvar_xpm_xpgain);
	}

	while (g_xpm[s].level < XPM_MAXLEVEL && g_xpm[s].xp >= XPM_NeededXP(g_xpm[s].level)) {
		g_xpm[s].level++;
		g_xpm[s].points++;

		if (g_xpm[s].level >= XPM_MAXLEVEL) {
			bprint(PRINT_HIGH, sprintf("^3[XPM]^7 Everyone congratulate %s, who reached level %i!\n", pl.netname, XPM_MAXLEVEL));
		} else {
			XPM_Tell(pl, sprintf("You are now level %i (%s). Next level at %i XP.", g_xpm[s].level, XPM_Rank(g_xpm[s].level), XPM_NeededXP(g_xpm[s].level)));
		}

		XPM_ShowMenu(pl, s);
		XPM_Save(s);
	}
}

static void
XPM_DrawHud(entity pl, int s)
{
	string text;

	if (!autocvar_xpm_hud) {
		return;
	}

	if (g_xpm[s].level >= XPM_MAXLEVEL) {
		text = sprintf("Level: %i / %i\nRank: %s\nMedals: %i / %i", XPM_MAXLEVEL, XPM_MAXLEVEL, XPM_Rank(XPM_MAXLEVEL), g_xpm[s].medals, XPM_MAXMEDALS);
	} else {
		int need = XPM_NeededXP(g_xpm[s].level);
		/* split up: builtins lose arguments past the eighth on Bulwark */
		text = sprintf("Exp: %i / %i (+%i)\n", g_xpm[s].xp, need, need - g_xpm[s].xp);
		text = strcat(text, sprintf("Level: %i / %i\nRank: %s\n", g_xpm[s].level, XPM_MAXLEVEL, XPM_Rank(g_xpm[s].level)));
		text = strcat(text, sprintf("Medals: %i / %i", g_xpm[s].medals, XPM_MAXMEDALS));
	}

	XPM_HudText(pl, 4i, text, 0.02, 0.3, [50, 135, 180], 1.5f);
}

/* ---- skills ------------------------------------------------------------- */

/* ammo for one of the weapons the player carries: [weapon, ammo type, amount] */
const string g_xpmAmmoTable = "weapon_9mmhandgun ammo_9mm 17 weapon_357 ammo_357 6 weapon_9mmAR ammo_9mm 25 weapon_9mmAR ammo_m203_grenade 1 weapon_shotgun ammo_buckshot 12 weapon_crossbow ammo_bolt 5 weapon_rpg ammo_rocket 1 weapon_gauss ammo_uranium 20 weapon_egon ammo_uranium 20 weapon_handgrenade ammo_handgrenade 1 weapon_satchel ammo_satchel 1 weapon_tripmine ammo_tripmine 1 weapon_snark ammo_snark 1";

static void
XPM_GiveAmmo(entity pl)
{
	int rows = (int)tokenize(g_xpmAmmoTable) / 3i;
	int pick = (int)floor(random() * rows);

	/* start at a random row and give the first one the player can use */
	for (int n = 0i; n < rows; n++) {
		int row = (pick + n) % rows;
		tokenize(g_xpmAmmoTable);
		string weaponName = argv(row * 3i);
		string ammoType = argv(row * 3i + 1i);
		string amount = argv(row * 3i + 2i);

		if (actor.HasItem(pl, weaponName)) {
			ents.Input(pl, "GiveAmmo", sprintf("%s %s", ammoType, amount), world);
			return;
		}
	}
}

static void
XPM_Regenerate(entity pl, int s)
{
	int aw = g_xpm[s].skill[SK_AWARENESS];
	int halfAw = (int)floor(aw / 2);
	float healthCap = XPM_HealthCap(s, false);
	float armorCap = XPM_HealthCap(s, true);
	int regen = g_xpm[s].skill[SK_REGEN];
	int nano = g_xpm[s].skill[SK_NANOARMOR];
	int ammo = g_xpm[s].skill[SK_AMMO];

	if (regen > 0i) {
		if (g_xpm[s].healthWait <= 0i) {
			XPM_AddHealth(pl, 1, healthCap);
			g_xpm[s].healthWait = 300i - regen;
		} else {
			g_xpm[s].healthWait--;

			if (random() * (200 + regen + g_xpm[s].medals + halfAw) > 200) {
				XPM_AddHealth(pl, 1, healthCap);
			}
		}
	}

	if (nano > 0i) {
		if (g_xpm[s].armorWait <= 0i) {
			XPM_AddArmor(pl, 1, armorCap);
			g_xpm[s].armorWait = 300i - nano;
		} else {
			g_xpm[s].armorWait--;

			if (random() * (200 + nano + g_xpm[s].medals + halfAw) > 200) {
				XPM_AddArmor(pl, 1, armorCap);
			}
		}
	}

	if (ammo > 0i) {
		if (g_xpm[s].ammoWait <= 0i) {
			XPM_GiveAmmo(pl);
			g_xpm[s].ammoWait = 179i - 5i * ammo - (int)floor(aw / 18);
		} else {
			g_xpm[s].ammoWait--;
		}
	}
}

/* teammates near a player with Team Power slowly gain health and armour */
static void
XPM_TeamPower(entity giver, int gs)
{
	int power = g_xpm[gs].skill[SK_TEAMPOWER];
	int crowd = 0i;

	if (power <= 0i) {
		return;
	}

	for (entity p = world; (p = next.Player(p));) {
		crowd++;
	}

	for (entity mate = world; (mate = next.Player(mate));) {
		int ms = XPM_Slot(mate);

		if (mate == giver || ms < 0i || !g_xpm[ms].loaded || !XPM_Alive(mate)) {
			continue;
		}

		if (vlen(mate.origin - giver.origin) > XPM_TEAMRANGE) {
			continue;
		}

		int halfAw = (int)floor(g_xpm[ms].skill[SK_AWARENESS] / 2);
		float cap = XPM_HealthCap(ms, false) + 60 + power;
		float low = 1651 - crowd * 50;
		float high = 4200 + power + g_xpm[ms].skill[SK_TEAMPOWER] + halfAw;

		if (low + random() * (high - low) > 4200) {
			XPM_AddHealth(mate, 1, cap);
		}

		if (low + random() * (high - low) > 4200) {
			XPM_AddArmor(mate, 1, cap);
		}

		if (power >= 40i && random() * (1000 + power) > 1038) {
			XPM_AddHealth(mate, 1, cap);
			XPM_AddArmor(mate, 1, cap);
		}
	}
}

/* Block Attack: each tick, a chance to be untouchable until the next one */
static void
XPM_Block(entity pl, int s)
{
	int block = g_xpm[s].skill[SK_BLOCK];
	bool want = false;

	if (block > 0i) {
		float piece = floor(g_xpm[s].skill[SK_AWARENESS] / 7);
		want = (random() * (185 + block + g_xpm[s].medals + piece) > 185) ? true : false;
	}

	if (want && !g_xpm[s].blocking) {
		g_xpm[s].oldTakeDamage = pl.takedamage;
		pl.takedamage = DAMAGE_NO;
		g_xpm[s].blocking = true;
	} else if (!want && g_xpm[s].blocking) {
		pl.takedamage = g_xpm[s].oldTakeDamage;
		g_xpm[s].blocking = false;
	}
}

static void
XPM_Spawned(entity pl, int s)
{
	g_xpm[s].baseHealth = pl.health;
	g_xpm[s].baseArmor = pl.armor;
	g_xpm[s].blocking = false;

	float newHealth = pl.health + g_xpm[s].skill[SK_STRENGTH] + g_xpm[s].medals;
	float newArmor = pl.armor + g_xpm[s].skill[SK_ARMOR] + g_xpm[s].medals;

	ents.Input(pl, "SetMaxHealth", ftos(max(pl.max_health, newHealth)), world);
	ents.Input(pl, "SetHealth", ftos(newHealth), world);
	ents.Input(pl, "SetMaxArmor", ftos(max(100, newArmor)), world);
	ents.Input(pl, "SetArmor", ftos(newArmor), world);
}

/* ---- ticks -------------------------------------------------------------- */

static void
XPM_Tick(void)
{
	for (entity pl = world; (pl = next.Player(pl));) {
		int s = XPM_Slot(pl);

		if (s < 0i || !XPM_IsPlayer(pl)) {
			continue;
		}

		if (!g_xpm[s].loaded) {
			XPM_Load(pl, s);
		}

		XPM_GainXP(pl, s);
		XPM_DrawHud(pl, s);

		if (XPM_Alive(pl)) {
			XPM_Regenerate(pl, s);
			XPM_TeamPower(pl, s);
			XPM_Block(pl, s);
		}
	}

	/* save now and then too, so a crash or a map change loses little */
	if (++g_xpmSaveTicks >= XPM_SAVETICKS) {
		g_xpmSaveTicks = 0i;

		for (int i = 0i; i < XPM_PLAYERS; i++) {
			XPM_Save(i);
		}
	}

	self.nextthink = time + XPM_TICK;
}

/* spawns and the jump key need a faster look than the half-second tick */
static void
XPM_FastTick(void)
{
	for (entity pl = world; (pl = next.Player(pl));) {
		int s = XPM_Slot(pl);

		if (s < 0i || !g_xpm[s].loaded) {
			continue;
		}

		bool alive = XPM_Alive(pl);

		if (alive && !g_xpm[s].wasAlive) {
			XPM_Spawned(pl, s);
		} else if (!alive && g_xpm[s].blocking) {
			g_xpm[s].blocking = false;
		}

		g_xpm[s].wasAlive = alive;

		if (!alive) {
			continue;
		}

		/* Anti Gravity works while jump is held after a jump (the player
		   physics clears FL_JUMPRELEASED on a jump and sets it on release) */
		bool jumpHeld = (pl.flags & FL_JUMPRELEASED) ? false : true;

		if (jumpHeld && g_xpm[s].skill[SK_GRAVITY] > 0i) {
			pl.gravity = 1.0 - 0.015 * g_xpm[s].skill[SK_GRAVITY] - 0.001 * g_xpm[s].medals;
			g_xpm[s].lowGravity = true;
		} else if (g_xpm[s].lowGravity) {
			pl.gravity = 1.0;
			g_xpm[s].lowGravity = false;
		}
	}

	self.nextthink = time + XPM_FASTTICK;
}

/* ---- admin -------------------------------------------------------------- */

static bool
XPM_IsAdmin(entity pl)
{
	/* the host of a listen server */
	if (num_for_edict(pl) == 1 && cvar("sv_playerslots") >= 1 && !cvar("dedicated") && infokey(pl, "ip") == "loopback") {
		return true;
	}

	if (cvar("sv_cheats")) {
		return true;
	}

	int n = (int)tokenize(autocvar_xpm_admins);

	for (int i = 0i; i < n; i++) {
		if (argv(i) == infokey(pl, "name")) {
			return true;
		}
	}

	return false;
}

static entity
XPM_FindTarget(string partName)
{
	partName = strtolower(partName);

	for (entity p = world; (p = next.Player(p));) {
		if (strstrofs(strtolower(p.netname), partName) >= 0) {
			return p;
		}
	}

	return world;
}

static void
XPM_SetLevel(entity admin, entity target, int newLevel)
{
	int s = XPM_Slot(target);
	int oldLevel = g_xpm[s].level;

	newLevel = bound(0i, newLevel, XPM_MAXLEVEL);
	g_xpm[s].level = newLevel;
	g_xpm[s].xp = (newLevel > 0i) ? XPM_NeededXP(newLevel - 1i) : 0i;

	if (newLevel < oldLevel) {
		XPM_ResetSkills(target, s);
	} else if (newLevel >= XPM_MAXLEVEL) {
		for (int i = 0i; i < SK_COUNT; i++) {
			g_xpm[s].skill[i] = g_xpmSkillCaps[i];
		}

		g_xpm[s].points = 0i;
	} else {
		g_xpm[s].points += newLevel - oldLevel;
		XPM_ShowMenu(target, s);
	}

	XPM_Tell(admin, sprintf("%s is now level %i.", target.netname, newLevel));

	if (admin != target) {
		XPM_Tell(target, sprintf("An admin set your level to %i.", newLevel));
	}
}

static bool
XPM_AdminCommand(entity pl, string cmd, int argc)
{
	entity target;
	int ts;

	if (cmd != "setlvl" && cmd != "addmedal" && cmd != "removemedal" && cmd != "godmode" && cmd != "noclipmode") {
		return false;
	}

	if (!XPM_IsAdmin(pl)) {
		XPM_Tell(pl, "That's an admin command.");
		return true;
	}

	target = XPM_FindTarget(argv(1));
	ts = XPM_Slot(target);

	if (!target || ts < 0i || !g_xpm[ts].loaded) {
		XPM_Tell(pl, "No player by that name.");
		return true;
	}

	switch (cmd) {
	case "setlvl":
		XPM_SetLevel(pl, target, stoi(argv(2)));
		break;
	case "addmedal":
		if (g_xpm[ts].medals < XPM_MAXMEDALS) {
			g_xpm[ts].medals++;
			bprint(PRINT_HIGH, sprintf("^3[XPM]^7 %s was awarded a medal (%i now).\n", target.netname, g_xpm[ts].medals));
		} else {
			XPM_Tell(pl, sprintf("%s already has %i medals.", target.netname, XPM_MAXMEDALS));
		}
		break;
	case "removemedal":
		if (g_xpm[ts].medals > 0i) {
			g_xpm[ts].medals--;
			bprint(PRINT_HIGH, sprintf("^3[XPM]^7 %s lost a medal (%i now).\n", target.netname, g_xpm[ts].medals));
		} else {
			XPM_Tell(pl, sprintf("%s has no medals.", target.netname));
		}
		break;
	case "godmode":
		if (!XPM_Alive(target)) {
			XPM_Tell(pl, "They're dead.");
		} else if (target.flags & FL_GODMODE) {
			target.flags &= ~FL_GODMODE;
			XPM_Tell(pl, sprintf("God mode off for %s.", target.netname));
		} else {
			target.flags |= FL_GODMODE;
			XPM_Tell(pl, sprintf("God mode on for %s.", target.netname));
		}
		break;
	case "noclipmode":
		if (!XPM_Alive(target)) {
			XPM_Tell(pl, "They're dead.");
		} else if (target.movetype == MOVETYPE_NOCLIP) {
			target.movetype = MOVETYPE_WALK;
			XPM_Tell(pl, sprintf("Noclip off for %s.", target.netname));
		} else {
			target.movetype = MOVETYPE_NOCLIP;
			XPM_Tell(pl, sprintf("Noclip on for %s.", target.netname));
		}
		break;
	}

	XPM_Save(ts);
	return true;
}

/* ---- plugin hooks ------------------------------------------------------- */

void
Plug_Load(void)
{
	if (!g_xpmTicker) {
		g_xpmTicker = spawn();
		g_xpmFastTicker = spawn();
	}

	g_xpmTicker.think = XPM_Tick;
	g_xpmTicker.nextthink = time + XPM_TICK;
	g_xpmFastTicker.think = XPM_FastTick;
	g_xpmFastTicker.nextthink = time + XPM_FASTTICK;
	print(sprintf("XP mod %s loaded.\n", XPM_VERSION));
}

void
Plug_Shutdown(void)
{
	for (int s = 0i; s < XPM_PLAYERS; s++) {
		XPM_Save(s);
	}

	g_xpmTicker.nextthink = 0;
	g_xpmFastTicker.nextthink = 0;
}

void
Plug_PlayerConnect(entity pl)
{
	int s = XPM_Slot(pl);

	if (s >= 0i) {
		g_xpm[s].loaded = false;
		g_xpm[s].wasAlive = false;
	}
}

void
Plug_PlayerDisconnect(entity pl)
{
	int s = XPM_Slot(pl);

	if (s >= 0i) {
		XPM_Save(s);
		g_xpm[s].loaded = false;
	}
}

string
Plug_ClientCommand(entity pl, string commandString)
{
	int s = XPM_Slot(pl);
	int argc = (int)tokenize(commandString);
	string cmd = strtolower(argv(0));

	if (s < 0i) {
		return commandString;
	}

	/* chat versions: "say selectskills" or "say /selectskills" */
	if ((cmd == "say" || cmd == "say_team") && argc >= 2i) {
		string said = strtolower(argv(1));

		if (substring(said, 0, 1) == "/") {
			said = substring(said, 1, -1);
		}

		argc = (int)tokenize(said);
		cmd = argv(0);
	}

	if (!g_xpm[s].loaded) {
		XPM_Load(pl, s);
	}

	switch (cmd) {
	case "selectskills":
		if (g_xpm[s].points > 0i) {
			XPM_ShowMenu(pl, s);
		} else {
			XPM_Tell(pl, "You have no skill points to spend.");
		}
		break;
	case "resetskills":
		XPM_ResetSkills(pl, s);
		XPM_Save(s);
		break;
	case "playerskills":
		XPM_PrintPlayers(pl);
		break;
	case "skillsinfo":
		XPM_PrintSkillsInfo(pl);
		break;
	case "scxpminfo":
	case "xpminfo":
		XPM_Tell(pl, sprintf("XP mod %s for co-op. XP rate: %g.", XPM_VERSION, autocvar_xpm_xpgain));
		break;
	case "menuselect":
		if (!g_xpm[s].menuOpen) {
			break;
		}

		int choice = stoi(argv(1));
		g_xpm[s].menuOpen = false;

		if (choice >= 1i && choice <= SK_COUNT) {
			XPM_Spend(pl, s, choice - 1i);
			XPM_Save(s);
		}
		break;
	default:
		XPM_AdminCommand(pl, cmd, argc);
	}

	return commandString;
}
