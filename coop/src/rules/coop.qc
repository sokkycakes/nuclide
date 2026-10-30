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

/* Co-op: every player is on one team against the monsters.

   - Friendly fire is off (the player team makes Nuclide skip player on
     player damage while sv_friendlyFire is 0).
   - Dead players can respawn after coop_respawnDelay seconds. Until then
     a teammate can revive them where they fell by holding USE next to the
     body. With coop_survival 1 nobody respawns on their own: revive them,
     or the map restarts once everyone is down.
   - A wave director spawns monsters at info_monster_spawn points. Each
     wave is bigger than the last and scales with the number of players,
     and so does monster health.
   - Score is points: killing a monster gives a share of its health,
     reviving a teammate gives coop_revivePoints, killing an ally costs.
     The same points can be spent in the shop (shop.qc). */

#define COOP_MAXPLAYERS 64
#define COOP_MAXMONSTERS 256
#define COOP_PLAYERTEAM 1

#ifndef INPUT_USE
#define INPUT_USE 0x00000010 /* see src/shared/input/input.h */
#endif

void CodeCallback_PlayerSpawn(entity playerEntity);
void Coop_PrintStatus(void);
void Coop_AddPoints(entity pl, int amount);	/* shop.qc */
void Shop_Load(void);
void Shop_PlayerConnect(entity pl);
bool Shop_ClientCommand(entity pl, string command);
void Shop_PlayerSpawned(entity pl);
int Coop_Points(entity pl);
void Hero_Precache(void);
string Hero_SpawnClass(entity pl);
void Hero_PlayerSpawned(entity pl);
void Hero_PlayerConnect(entity pl);
bool Hero_ClientCommand(entity pl, string command);
var bool g_coopHeroes;

var float autocvar_coop_respawnDelay = 5;
var bool autocvar_coop_survival = false;
var float autocvar_coop_reviveTime = 2.5;
var float autocvar_coop_reviveRange = 72;
var float autocvar_coop_reviveHealth = 50;
var int autocvar_coop_revivePoints = 5;
var bool autocvar_coop_botsRevive = true;
var float autocvar_coop_botReviveRange = 1536;

var bool autocvar_coop_waves = true;
/* maps that bring their own monsters (Sven Co-op maps, monster makers) get no waves unless this is set */
var bool autocvar_coop_mapWaves = false;
var string autocvar_coop_waveMonsters = "monster_headcrab monster_zombie;monster_houndeye monster_bullchicken;monster_alien_slave monster_human_grunt;monster_alien_grunt";
var int autocvar_coop_waveBase = 6;
var float autocvar_coop_wavePerPlayer = 2;
var float autocvar_coop_wavePerWave = 3;
var int autocvar_coop_maxMonsters = 40;
var float autocvar_coop_waveDelay = 10;
var float autocvar_coop_spawnInterval = 0.5;
var float autocvar_coop_healthPerPlayer = 0.15;
var float autocvar_coop_healthScaleMax = 4;
var float autocvar_coop_allyKillPenalty = 10;
var int autocvar_coop_debug = 0;
var float autocvar_coop_statusInterval = 0;	/* print coop_status every N seconds (tests) */
var int autocvar_coop_weapontest = 0;	/* tests: the first bot fires every weapon at a target */
var string autocvar_coop_weapontestList = "";	/* tests: comma-separated weapons to try, all if empty */
var float autocvar_coop_weapontestSettle = 1.5;	/* tests: seconds to wait for slow projectiles */
var string autocvar_coop_plugins = "xpm";	/* server plugins (plugins/<name>.dat) loaded every map */

/* per player slot, indexed by entity number - 1 */
float g_coopDownTime[COOP_MAXPLAYERS];
vector g_coopDownOrigin[COOP_MAXPLAYERS];
bool g_coopDown[COOP_MAXPLAYERS];
bool g_coopAnyDown;	/* refreshed each frame: revive checks skip work when false */
entity g_coopReviveTarget[COOP_MAXPLAYERS];
float g_coopReviveStart[COOP_MAXPLAYERS];
float g_coopReviveSeen[COOP_MAXPLAYERS];
float g_coopBotOrder[COOP_MAXPLAYERS];
float g_coopBotNext;
float g_coopStatusNext;

/* wave director */
enum
{
	WAVE_WAITING,
	WAVE_SPAWNING,
	WAVE_FIGHTING
};

int g_coopWave;
int g_coopWaveState;
float g_coopWaveNext;
int g_coopWaveLeft;		/* still to spawn this wave */
entity g_coopMonsters[COOP_MAXMONSTERS];
int g_coopMonsterCount;
bool g_coopRestarting;
bool g_coopStarted;	/* StartGameType ran: frames can come before it */
bool g_coopMapMonsters;	/* the map spawns its own monsters */

int
Coop_Slot(entity pl)
{
	int n = (int)num_for_edict(pl) - 1i;

	if (n < 0i || n >= COOP_MAXPLAYERS) {
		return (-1i);
	}

	return (n);
}

void
Coop_Debug(string msg)
{
	if (autocvar_coop_debug) {
		print(sprintf("^3coop^7: %s\n", msg));
	}
}

void
Coop_Announce(string msg)
{
	for (entity p = world; (p = next.Player(p));) {
		centerprint(p, msg);
	}

	print(sprintf("coop: %s\n", msg));
}

int
Coop_PlayerCount(void)
{
	int c = 0i;

	for (entity p = world; (p = next.Player(p));) {
		if (p.classname == "spectator") {
			continue;
		}

		c++;
	}

	return (c);
}

int
Coop_AlivePlayerCount(void)
{
	int c = 0i;

	for (entity p = world; (p = next.Player(p));) {
		if (is.Alive(p)) {
			c++;
		}
	}

	return (c);
}

/* drops dead or removed monsters from the list, returns how many are left */
int
Coop_MonstersAlive(void)
{
	int j = 0i;

	for (int i = 0i; i < g_coopMonsterCount; i++) {
		entity m = g_coopMonsters[i];

		if (wasfreed(m) || !is.Alive(m)) {
			continue;
		}

		g_coopMonsters[j++] = m;
	}

	g_coopMonsterCount = j;
	return (j);
}

float
Coop_HealthScale(void)
{
	float s = 1.0f + autocvar_coop_healthPerPlayer * (float)max(0i, Coop_PlayerCount() - 1i);
	return (min(s, autocvar_coop_healthScaleMax));
}

/* picks a monster class for the current wave: wave 1 uses the first tier,
   later waves mix every tier up to theirs */
string
Coop_PickMonster(void)
{
	int tierCount = (int)tokenizebyseparator(autocvar_coop_waveMonsters, ";");
	int topTier;
	string tier;
	int classCount;

	if (tierCount <= 0i) {
		return ("monster_zombie");
	}

	topTier = min(g_coopWave - 1i, tierCount - 1i);
	tier = argv((float)floor(random(0, (float)topTier + 1)));
	classCount = (int)tokenize(tier);

	if (classCount <= 0i) {
		return ("monster_zombie");
	}

	return (argv((float)floor(random(0, (float)classCount))));
}

bool
Coop_SpotClear(vector spot)
{
	for (entity e = world; (e = findradius(spot, 64));) {
		if (e.solid == SOLID_SLIDEBOX || e.solid == SOLID_BBOX) {
			if (is.Sentient(e) || is.Player(e)) {
				return (false);
			}
		}
	}

	return (true);
}

entity
Coop_FindMonsterSpot(void)
{
	entity spot;

	/* a few tries at a free spot, so a crowd at one point doesn't stall the wave */
	for (int i = 0i; i < 4i; i++) {
		spot = game.FindRandomClassObject("info_monster_spawn");

		if (!spot) {
			spot = game.FindRandomClassObject("info_player_deathmatch");
		}

		if (spot && Coop_SpotClear(spot.origin)) {
			return (spot);
		}
	}

	return (world);
}

bool
Coop_SpawnMonster(void)
{
	string monsterClass;
	entity spot;
	entity monster;
	float scale;

	if (g_coopMonsterCount >= COOP_MAXMONSTERS) {
		return (false);
	}

	spot = Coop_FindMonsterSpot();

	if (!spot) {
		return (false);
	}

	monsterClass = Coop_PickMonster();
	monster = ents.Create(monsterClass, spot.origin);
	monster.angles = spot.angles;
	ents.Input(monster, "DropToFloor", "", world);

	scale = Coop_HealthScale();

	/* the def's health ends up in .health; max_health is only a default */
	if (scale != 1.0f && monster.health > 0) {
		float newHealth = rint(monster.health * scale);
		ents.Input(monster, "SetMaxHealth", ftos(newHealth), world);
		ents.Input(monster, "SetHealth", ftos(newHealth), world);
	}

	/* horde monsters always know where the nearest player is */
	ents.Input(monster, "HordeOn", "", world);
	g_coopMonsters[g_coopMonsterCount++] = monster;
	Coop_Debug(sprintf("spawned %s at %v (health %d)", monsterClass, spot.origin, monster.health));
	return (true);
}

int
Coop_WaveSize(void)
{
	float size = (float)autocvar_coop_waveBase;
	size += autocvar_coop_wavePerPlayer * (float)Coop_PlayerCount();
	size += autocvar_coop_wavePerWave * (float)(g_coopWave - 1i);
	return ((int)rint(size));
}

void
Coop_StartWave(void)
{
	g_coopWave++;
	g_coopWaveLeft = Coop_WaveSize();
	g_coopWaveState = WAVE_SPAWNING;
	g_coopWaveNext = time;
	serverinfo.SetString("coop_wave", itos(g_coopWave));
	Coop_Announce(sprintf("Wave %i: %i monsters", g_coopWave, g_coopWaveLeft));
}

void
Coop_WaveThink(void)
{
	if (!autocvar_coop_waves || g_coopRestarting || !g_coopStarted) {
		return;
	}

	if (g_coopMapMonsters && !autocvar_coop_mapWaves) {
		return;
	}

	/* no point in fighting nobody */
	if (Coop_PlayerCount() <= 0i) {
		return;
	}

	switch (g_coopWaveState) {
	case WAVE_WAITING:
		if (time >= g_coopWaveNext) {
			Coop_StartWave();
		}
		break;
	case WAVE_SPAWNING:
		if (time < g_coopWaveNext) {
			break;
		}

		g_coopWaveNext = time + autocvar_coop_spawnInterval;

		if (g_coopWaveLeft <= 0i) {
			g_coopWaveState = WAVE_FIGHTING;
			break;
		}

		/* keep the crowd under the cap; the rest wait their turn */
		if (Coop_MonstersAlive() >= autocvar_coop_maxMonsters) {
			break;
		}

		if (Coop_SpawnMonster() == true) {
			g_coopWaveLeft--;
		}
		break;
	case WAVE_FIGHTING:
		if (Coop_MonstersAlive() <= 0i) {
			Coop_Announce(sprintf("Wave %i cleared! Next wave in %d seconds", g_coopWave, autocvar_coop_waveDelay));
			g_coopWaveState = WAVE_WAITING;
			g_coopWaveNext = time + autocvar_coop_waveDelay;

			/* a cleared wave brings back everyone who is down */
			for (entity p = world; (p = next.Player(p));) {
				if (!is.Alive(p) && p.classname != "spectator") {
					CodeCallback_PlayerSpawn(p);
				}
			}
		}
		break;
	}
}

/* revive */

void
Coop_Revive(entity reviver, entity target)
{
	int slot = Coop_Slot(target);
	vector downOrigin = g_coopDownOrigin[slot];

	CodeCallback_PlayerSpawn(target);
	ents.Input(target, "SetOrigin", vtos(downOrigin + [0, 0, 8]), reviver);
	ents.Input(target, "SetHealth", ftos(autocvar_coop_reviveHealth), reviver);

	Coop_AddPoints(reviver, autocvar_coop_revivePoints);
	centerprint(target, sprintf("Revived by %s", reviver.netname));
	centerprint(reviver, sprintf("You revived %s", target.netname));
	print(sprintf("coop: %s revived %s\n", reviver.netname, target.netname));
}

entity
Coop_DownedNear(vector org)
{
	entity best = world;
	float bestDist = autocvar_coop_reviveRange;

	for (entity p = world; (p = next.Player(p));) {
		int slot = Coop_Slot(p);

		if (slot < 0i || !g_coopDown[slot] || is.Alive(p)) {
			continue;
		}

		float d = vlen(g_coopDownOrigin[slot] - org);

		if (d < bestDist) {
			bestDist = d;
			best = p;
		}
	}

	return (best);
}

/* runs every input frame for every living player */
void
Coop_ReviveInput(entity pl)
{
	int slot = Coop_Slot(pl);
	float buttons;
	bool holding;
	entity target;

	if (!g_coopAnyDown || slot < 0i || !is.Alive(pl)) {
		return;
	}

	buttons = (float)externvalue(0, "input_buttons");
	holding = (buttons & INPUT_USE) ? true : false;

	/* bots don't press use: standing next to the body is enough */
	if (autocvar_coop_botsRevive && is.Bot(pl)) {
		holding = true;
	}

	if (!holding) {
		g_coopReviveTarget[slot] = world;
		return;
	}

	target = Coop_DownedNear(pl.origin);

	if (!target) {
		g_coopReviveTarget[slot] = world;
		return;
	}

	/* new target, or we let go for a moment: start over */
	if (target != g_coopReviveTarget[slot] || time - g_coopReviveSeen[slot] > 0.25f) {
		g_coopReviveTarget[slot] = target;
		g_coopReviveStart[slot] = time;
	}

	g_coopReviveSeen[slot] = time;

	float progress = (time - g_coopReviveStart[slot]) / autocvar_coop_reviveTime;

	if (progress >= 1.0f) {
		g_coopReviveTarget[slot] = world;
		Coop_Revive(pl, target);
	} else {
		float filled = floor(progress * 10);
		string bar = strcat(substring("##########", 0, filled), substring("----------", 0, 10 - filled));
		centerprint(pl, sprintf("Reviving %s\n[%s]", target.netname, bar));
		centerprint(target, sprintf("%s is reviving you\n[%s]", pl.netname, bar));
	}
}

/* bots: respawn on their own once allowed, and go to downed teammates */
void
Coop_BotThink(void)
{
	if (time < g_coopBotNext || !g_coopStarted) {
		return;
	}

	g_coopBotNext = time + 0.5f;

	for (entity pl = world; (pl = next.Player(pl));) {
		int slot = Coop_Slot(pl);

		if (slot < 0i || !is.Bot(pl)) {
			continue;
		}

		if (!is.Alive(pl)) {
			if (!autocvar_coop_survival && g_coopDown[slot] && time - g_coopDownTime[slot] >= autocvar_coop_respawnDelay) {
				CodeCallback_PlayerSpawn(pl);
			}
			continue;
		}

		if (!autocvar_coop_botsRevive || time < g_coopBotOrder[slot]) {
			continue;
		}

		/* nearest downed teammate in range */
		entity best = world;
		float bestDist = autocvar_coop_botReviveRange;

		for (entity p = world; (p = next.Player(p));) {
			int pslot = Coop_Slot(p);

			if (pslot < 0i || !g_coopDown[pslot] || is.Alive(p)) {
				continue;
			}

			float d = vlen(g_coopDownOrigin[pslot] - pl.origin);

			if (d < bestDist) {
				bestDist = d;
				best = p;
			}
		}

		if (best && bestDist > autocvar_coop_reviveRange * 0.5f) {
			ents.Input(pl, "GoToPosition", vtos(g_coopDownOrigin[Coop_Slot(best)]), pl);
			g_coopBotOrder[slot] = time + 2.0f;
		}
	}
}

void
Coop_CheckWipe(void)
{
	if (!autocvar_coop_survival || g_coopRestarting) {
		return;
	}

	if (Coop_PlayerCount() > 0i && Coop_AlivePlayerCount() <= 0i) {
		g_coopRestarting = true;
		Coop_Announce("Everyone is down. Restarting...");
		localcmd(sprintf("wait 300; map %s\n", game.GetMap()));
	}
}

/* rule callbacks */

bool
AllowFlashlight(void)
{
	return (true);
}

/* every Half-Life weapon: maps hand out whatever they like in co-op, so
   all of them are precached, along with what they spawn */
const string g_coopWeapons = "weapon_crowbar weapon_9mmhandgun weapon_357 weapon_9mmAR weapon_shotgun weapon_crossbow weapon_rpg weapon_gauss weapon_egon weapon_hornetgun weapon_handgrenade weapon_satchel weapon_tripmine weapon_snark weapon_chumtoad";
const string g_coopWeaponExtras = "monster_snark monster_snark_thrown monster_tripmine monster_chumtoad";

void
CodeCallback_Precache(void)
{
	/* every monster a wave can pick */
	string monsterList = strreplace(";", " ", autocvar_coop_waveMonsters);
	int monsterCount;
	string monsterClasses[64];

	motd.LoadDefault();
	precache.Entity("player_mp");
	Hero_Precache();
	monsterCount = (int)tokenize(monsterList);

	/* the precaches tokenize too, so copy the names out first */
	monsterCount = min(monsterCount, 64i);

	for (int i = 0i; i < monsterCount; i++) {
		monsterClasses[i] = argv(i);
	}

	for (int i = 0i; i < monsterCount; i++) {
		precache.Entity(monsterClasses[i]);
	}

	string weaponList = strcat(g_coopWeapons, " ", g_coopWeaponExtras);
	int weaponCount = min((int)tokenize(weaponList), 64i);

	for (int i = 0i; i < weaponCount; i++) {
		monsterClasses[i] = argv(i);
	}

	for (int i = 0i; i < weaponCount; i++) {
		precache.Entity(monsterClasses[i]);
	}
}

/* Bulwark's script layer. src/common/c_script.h skips it here, because rules
   progs define SERVER only after the common headers */
void(string name, string keyvalues) script_event = #0:script_event;

/* true when the map places monsters or something that makes them */
bool
Coop_MapHasMonsters(void)
{
	for (entity e = world; (e = nextent(e));) {
		if (substring(e.classname, 0, 8) == "monster_" && e.classname != "monster_furniture") {
			return (true);
		}

		switch (e.classname) {
		case "squadmaker":
		case "monstermaker":
		case "env_xenmaker":
			return (true);
		}
	}

	return (false);
}

void
CodeCallback_StartGameType(void)
{
	teams.SetUp(COOP_PLAYERTEAM, "Survivors", [128, 192, 255], true);

	if (exists.InMap("info_player_coop")) {
		game.SetSpawnPoint("info_player_coop");
		teams.SetSpawnPoint(COOP_PLAYERTEAM, "info_player_coop");
	} else {
		game.SetSpawnPoint("info_player_deathmatch");
		teams.SetSpawnPoint(COOP_PLAYERTEAM, "info_player_deathmatch");
	}

	/* weapons come back quickly so everyone gets one */
	for (entity s = world; (s = next.Item(s));) {
		string isWeapon = substring(s.classname, 0, 7);
		string isAmmo = substring(s.classname, 0, 5);

		if (isWeapon == "weapon_") {
			ents.Input(s, "SetRespawnTime", "2.0f", world);
		} else if (isAmmo == "ammo_") {
			ents.Input(s, "SetRespawnTime", "15.0f", world);
		} else {
			ents.Input(s, "SetRespawnTime", "30.0f", world);
		}
	}

	g_coopWave = 0i;
	g_coopWaveLeft = 0i;
	g_coopWaveState = WAVE_WAITING;
	g_coopStarted = true;
	g_coopMapMonsters = Coop_MapHasMonsters();
	g_coopWaveNext = time + autocvar_coop_waveDelay;
	g_coopMonsterCount = 0i;
	g_coopRestarting = false;
	serverinfo.SetString("coop_wave", "0");
	serverinfo.SetString("nameplates", "1");
	serverinfo.SetString("targetid", "1");
	serverinfo.SetString("coop_heroes", g_coopHeroes ? "1" : "0");
	Shop_Load();

	/* plugins live as long as the map, so load them again on each one */
	int pluginCount = (int)tokenize(autocvar_coop_plugins);

	for (int i = 0i; i < pluginCount; i++) {
		localcmd(sprintf("sv addon load %s\n", argv(i)));
	}
}

string
CodeCallback_Title(void)
{
	return ("Co-op");
}

void
CodeCallback_PlayerSpawn(entity playerEntity)
{
	int slot = Coop_Slot(playerEntity);
	string playerModel;

	ents.ChangeToClass(playerEntity, Hero_SpawnClass(playerEntity));
	ents.Input(playerEntity, "SetTeam", itos(COOP_PLAYERTEAM), playerEntity);

	if (g_coopHeroes) {
		/* respawning as the class one already is skips the def's health:
		   the player is reset to 100 (ncPlayer::MakePlayer) */
		float heroHealth = entityDef.GetFloat(playerEntity.classname, "health");

		if (heroHealth > 0) {
			ents.Input(playerEntity, "SetMaxHealth", ftos(heroHealth), playerEntity);
			ents.Input(playerEntity, "SetHealth", ftos(heroHealth), playerEntity);
		}

		/* the hero's model, unless its pack isn't installed */
		playerModel = entityDef.GetString(playerEntity.classname, "model");

		if (exists.InVFS(playerModel) == false) {
			playerEntity.modelindex = getmodelindex("models/player.mdl");
		}
	} else {
		/* the player's own model: only a look, the class is the same */
		playerModel = userinfo.GetString(playerEntity, "model");

		if (playerModel != "") {
			playerModel = sprintf("models/player/%s/%s.mdl", playerModel, playerModel);
		}

		if (playerModel == "" || exists.InVFS(playerModel) == false) {
			playerModel = "models/player.mdl";
		}

		playerEntity.modelindex = getmodelindex(playerModel);
	}

	game.TeleportToSpawn(playerEntity);

	if (slot >= 0i) {
		g_coopDown[slot] = false;
	}

	Shop_PlayerSpawned(playerEntity);
	Hero_PlayerSpawned(playerEntity);

	/* map scripts hand out the map's loadout from here */
	if (checkbuiltin(script_event)) {
		script_event("player_spawn", sprintf("\"entindex\" \"%d\"", num_for_edict(playerEntity)));
	}
}

void
CodeCallback_PlayerConnect(entity playerEntity)
{
	int slot = Coop_Slot(playerEntity);

	if (slot >= 0i) {
		g_coopDown[slot] = false;
		g_coopReviveTarget[slot] = world;
	}

	Shop_PlayerConnect(playerEntity);
	Hero_PlayerConnect(playerEntity);
}

bool
CodeCallback_ClientCommand(entity playerEntity, string command)
{
	if (Hero_ClientCommand(playerEntity, command)) {
		return (true);
	}

	return Shop_ClientCommand(playerEntity, command);
}

void
CodeCallback_PlayerDisconnect(entity playerEntity)
{
	int slot = Coop_Slot(playerEntity);

	if (slot >= 0i) {
		g_coopDown[slot] = false;
	}

	Coop_CheckWipe();
}

bool
CodeCallback_PlayerRequestRespawn(entity playerEntity)
{
	int slot = Coop_Slot(playerEntity);

	if (is.Alive(playerEntity)) {
		return (false);
	}

	if (autocvar_coop_survival) {
		centerprint(playerEntity, "Survival mode: wait for a teammate to revive you");
		return (false);
	}

	if (slot >= 0i && time - g_coopDownTime[slot] < autocvar_coop_respawnDelay) {
		centerprint(playerEntity, sprintf("Respawn in %d seconds", ceil(autocvar_coop_respawnDelay - (time - g_coopDownTime[slot]))));
		return (false);
	}

	CodeCallback_PlayerSpawn(playerEntity);
	return (true);
}

void
CodeCallback_PlayerDamage(entity playerEntity, entity inflictor, entity attacker)
{
}

bool
CodeCallback_CallRequestTeam(entity playerEntity, int teamNum)
{
	/* there's only one team */
	return (false);
}

void
CodeCallback_PlayerKilled(entity playerEntity, entity inflictor, entity attacker, string weapon)
{
	int slot = Coop_Slot(playerEntity);

	if (playerEntity == attacker) {
		combat.Obituary(playerEntity.netname, attacker.netname, weapon, "self");
	} else {
		combat.Obituary(playerEntity.netname, attacker.netname, weapon, "");
	}

	playerEntity.deaths++;

	if (slot >= 0i) {
		g_coopDown[slot] = true;
		g_coopDownTime[slot] = time;
		g_coopDownOrigin[slot] = playerEntity.origin;
	}

	if (!autocvar_coop_survival) {
		centerprint(playerEntity, sprintf("You are down. A teammate can revive you, or respawn in %d seconds", autocvar_coop_respawnDelay));
	}

	Coop_CheckWipe();
}

void
CodeCallback_NPCKilled(entity npcEntity, entity inflictor, entity attacker, string weapon)
{
	string npcName = npcEntity.netname;

	if (!STRING_SET(npcName)) {
		npcName = npcEntity.classname;
	}

	if (attacker) {
		combat.Obituary(npcName, attacker.netname, weapon, "");
	}

	if (!is.Player(attacker)) {
		return;
	}

	/* allies are on the player's side */
	if (npcEntity.team == COOP_PLAYERTEAM || npcEntity.classname == "monster_barney" || npcEntity.classname == "monster_scientist") {
		Coop_AddPoints(attacker, -(int)autocvar_coop_allyKillPenalty);
		return;
	}

	/* points: a tenth of the monster's health, at least one */
	Coop_AddPoints(attacker, (int)max(1, rint(npcEntity.max_health / 10)));
	teams.AddScore(COOP_PLAYERTEAM, 1i);
}

/* weapon test (coop_weapontest 1): the first bot is given each weapon in
   turn and taps, then holds primary and then secondary attack at a sturdy
   zombie in front of it; a line per attack reports the damage done and
   what was left in the world. Run with bot_pause 1 so the bot holds still. */
const string g_coopTestAmmo = "ammo_9mm ammo_357 ammo_buckshot ammo_bolt ammo_rocket ammo_uranium ammo_handgrenade ammo_satchel ammo_tripmine ammo_snark ammo_hornet ammo_m203_grenade ammo_chumtoad";
var int g_coopTestIndex = -1i;
#define COOP_TESTLIST (autocvar_coop_weapontestList != "" ? strreplace(",", " ", autocvar_coop_weapontestList) : g_coopWeapons)
float g_coopTestNext;
int g_coopTestPhase;
entity g_coopTestTarget;
float g_coopTestHealth;
vector g_coopTestSpot;

string
Coop_TestLeftovers(void)
{
	string out = "";

	for (entity e = world; (e = nextent(e));) {
		string c = e.classname;

		if (substring(c, 0, 11) == "projectile_" || substring(c, 0, 7) == "ranged_" || substring(c, 0, 7) == "monster" && e != g_coopTestTarget) {
			out = strcat(out, " ", c);

			if (autocvar_coop_debug) {
				print(sprintf("weapontest:   %s at %v vel %v movetype %d solid %d\n", c, e.origin, e.velocity, e.movetype, e.solid));
			}
		}
	}

	return out;
}

void
Coop_TestGiveAmmo(entity b)
{
	for (int i = 0i; i < tokenize(g_coopTestAmmo); i++) {
		tokenize(g_coopTestAmmo);
		ents.Input(b, "GiveAmmo", sprintf("%s 100", argv(i)), world);
	}
}

void
Coop_WeaponTestThink(void)
{
	entity b = world;
	string weaponName;

	/* the target stays put, so every shot aimed straight ahead can land */
	if (g_coopTestTarget && !wasfreed(g_coopTestTarget) && g_coopTestTarget.origin != g_coopTestSpot) {
		ents.Input(g_coopTestTarget, "SetOrigin", vtos(g_coopTestSpot), world);
	}

	if (!g_coopStarted || time < g_coopTestNext) {
		return;
	}

	for (entity p = world; (p = next.Player(p));) {
		if (is.Bot(p) && is.Alive(p)) {
			b = p;
			break;
		}
	}

	if (!b) {
		return;
	}

	if (g_coopTestPhase == 0i) {
		/* next weapon, fresh target */
		g_coopTestIndex++;

		if (g_coopTestIndex >= tokenize(COOP_TESTLIST)) {
			print("weapontest: done\n");
			cvar_set("coop_weapontest", "0");
			cvar_set("bot_forceAttack", "0");
			return;
		}

		weaponName = argv(g_coopTestIndex);
		ents.Input(b, "SetMaxHealth", "10000", world);
		ents.Input(b, "SetHealth", "10000", world);

		/* a tripmine needs a wall close in front: stand by the far one */
		if (weaponName == "weapon_tripmine") {
			ents.Input(b, "SetOrigin", vtos([1990, b.origin[1], b.origin[2]]), world);
		}
		ents.Input(b, "GiveItem", weaponName, world);

		Coop_TestGiveAmmo(b);
		ents.Input(b, "SwitchToWeapon", weaponName, world);

		if (g_coopTestTarget && !wasfreed(g_coopTestTarget)) {
			remove(g_coopTestTarget);
		}

		/* nobody else may hurt the target */
		for (entity m = world; (m = nextent(m));) {
			if (substring(m.classname, 0, 8) == "monster_") {
				remove(m);
			}
		}

		vector targetOffset = [128, 0, 0];

		switch (weaponName) {
		case "weapon_crowbar": targetOffset = [56, 0, 0]; break;
		case "weapon_snark": targetOffset = [320, 0, 0]; break;
		case "weapon_tripmine": targetOffset = [0, 64, 0]; break;
		}

		g_coopTestTarget = ents.Create("monster_zombie", b.origin + targetOffset);
		ents.Input(g_coopTestTarget, "DropToFloor", "", world);
		g_coopTestSpot = g_coopTestTarget.origin;
		ents.Input(g_coopTestTarget, "SetMaxHealth", "50000", world);
		ents.Input(g_coopTestTarget, "SetHealth", "50000", world);
		g_coopTestHealth = 50000;
		g_coopTestPhase = 1i;
		g_coopTestNext = time + 1.0f;
	} else if (g_coopTestPhase == 4i || g_coopTestPhase == 8i) {
		/* the shots have landed: report */
		tokenize(COOP_TESTLIST);
		weaponName = argv(g_coopTestIndex);
		print(sprintf("weapontest: %s %s damage %d left:%s\n", weaponName,
			g_coopTestPhase == 4i ? "primary" : "secondary",
			g_coopTestHealth - g_coopTestTarget.health, Coop_TestLeftovers()));
		g_coopTestHealth = g_coopTestTarget.health;
		g_coopTestPhase = g_coopTestPhase == 8i ? 0i : 5i;
		g_coopTestNext = time + 0.1f;
	} else {
		/* 1, 2: tap then hold primary; 5, 6: the same for secondary;
		   3, 7: let go and wait for slow projectiles */
		string force = "0";
		float wait = 1.5f;

		switch (g_coopTestPhase) {
		case 1i: force = "1"; break;
		case 2i: force = "3"; break;
		case 5i: force = "2"; break;
		case 6i: force = "4"; break;
		default: wait = autocvar_coop_weapontestSettle;
		}

		if (g_coopTestPhase == 5i) {
			Coop_TestGiveAmmo(b);
		}

		cvar_set("bot_forceAttack", force);
		if (autocvar_coop_debug) {
			print(sprintf("weapontest:   phase %i force %s for %f\n", g_coopTestPhase, force, wait));
		}
		ents.Input(b, "SetHealth", "10000", world);
		g_coopTestPhase++;
		g_coopTestNext = time + wait;
	}
}

void
CodeCallback_FrameStart(void)
{
	g_coopAnyDown = false;

	for (int i = 0i; i < COOP_MAXPLAYERS; i++) {
		if (g_coopDown[i]) {
			g_coopAnyDown = true;
			break;
		}
	}

	Coop_WaveThink();
	Coop_BotThink();

	if (autocvar_coop_weapontest) {
		Coop_WeaponTestThink();
	}

	if (autocvar_coop_statusInterval > 0 && time >= g_coopStatusNext) {
		if (g_coopStatusNext > 0)
			Coop_PrintStatus();
		g_coopStatusNext = time + autocvar_coop_statusInterval;
	}
}

bool
CodeCallback_ImpulseCommand(entity playerEntity, float impulseNum)
{
	/* called every input frame, impulse or not */
	Coop_ReviveInput(playerEntity);

	switch (impulseNum) {
	case 100:
		/* the suit's flashlight, as in Rad-Therapy's own rules */
		if (AllowFlashlight() == true) {
			ents.Input(playerEntity, "UseItem", "item_suit", playerEntity);
		}
		return (true);
	case 101:
		/* every weapon and full ammo, with sv_cheats on */
		if (cvar("sv_cheats") == 0) {
			return (false);
		}

		ents.Input(playerEntity, "GiveItem", "item_suit", world);

		/* Input can tokenize, so re-split the lists every time */
		for (int i = 0i; i < tokenize(g_coopWeapons); i++) {
			tokenize(g_coopWeapons);
			ents.Input(playerEntity, "GiveItem", argv(i), world);
		}

		for (int i = 0i; i < tokenize(g_coopTestAmmo); i++) {
			tokenize(g_coopTestAmmo);
			ents.Input(playerEntity, "GiveAmmo", sprintf("%s 255", argv(i)), world);
		}
		return (true);
	default:
		return (false);
	}
}

void
Coop_PrintStatus(void)
{
	/* at most 8 arguments: Bulwark can't find the globals that carry a 9th yet */
	print(sprintf("coop: wave %i state %i left %i alive %i players %i/%i",
		g_coopWave, g_coopWaveState, g_coopWaveLeft, Coop_MonstersAlive(),
		Coop_AlivePlayerCount(), Coop_PlayerCount()));
	print(sprintf(" scale %f skill %d\n", Coop_HealthScale(), cvar("skill")));

	for (entity p = world; (p = next.Player(p));) {
		int slot = Coop_Slot(p);
		print(sprintf("  %s: score %d points %i deaths %d health %d %s\n", p.netname, p.frags, Coop_Points(p),
			p.deaths, p.health, (slot >= 0i && g_coopDown[slot] && !is.Alive(p)) ? "DOWN" : ""));

		if (autocvar_coop_debug) {
			print(sprintf("    at %v inventory %s\n", p.origin, actor.GetInventory(p)));
		}
	}

	if (autocvar_coop_debug) {
		for (int i = 0i; i < g_coopMonsterCount; i++) {
			entity m = g_coopMonsters[i];
			print(sprintf("  %s at %v health %d enemy %s\n", m.classname, m.origin, m.health, m.enemy.netname));
		}
	}
}

bool
CodeCallback_ConsoleCommand(entity playerEntity, string command)
{
	tokenize(command);

	switch (argv(0)) {
	case "coop_status":
		Coop_PrintStatus();
		break;
	/* test hooks: bots can't type, so call or answer a vote for them */
	case "coop_botvote":
	case "coop_botvoteyes":
		entity oldSelf = self;
		void(string) callVote = externvalue(0, "CSEv_CallVote_s");
		void(void) voteYes = externvalue(0, "CSEv_VoteY");
		string voteText = sprintf("%s %s", argv(1), argv(2));
		bool firstBot = true;

		for (entity b = world; (b = next.Player(b));) {
			if (!is.Bot(b)) {
				continue;
			}

			self = b;

			if (argv(0) == "coop_botvote") {
				callVote(voteText);
				self = oldSelf;
				break;
			} else if (firstBot == false || argv(1) != "skipfirst") {
				voteYes();
			}

			firstBot = false;
		}

		self = oldSelf;
		break;
	case "coop_givepoints":
		/* tests: points for every player */
		for (entity p = world; (p = next.Player(p));) {
			Coop_AddPoints(p, stoi(argv(1)));
		}
		break;
	/* map scripts: respawn every player ("all") or only the dead ones */
	case "coop_respawn":
		for (entity p = world; (p = next.Player(p));) {
			if (argv(1) == "dead" && is.Alive(p)) {
				continue;
			}

			CodeCallback_PlayerSpawn(p);
		}
		break;
	case "coop_nextwave":
		g_coopWaveNext = time;
		g_coopWaveState = WAVE_WAITING;
		break;
	case "coop_killmonsters":
		for (int i = 0i; i < g_coopMonsterCount; i++) {
			if (!wasfreed(g_coopMonsters[i]) && is.Alive(g_coopMonsters[i])) {
				ents.Input(g_coopMonsters[i], "Damage", "10000", world);
			}
		}
		break;
	default:
		return (false);
	}

	return (true);
}
