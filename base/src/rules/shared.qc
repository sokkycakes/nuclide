void
Util_RemoveAllMonsters(void)
{
	for (entity npcChain = world; (npcChain = next.NPC(npcChain));) {
		ents.Input(npcChain, "Kill", "", world);
	}
}

void
Util_SetItemRespawnTimers(void)
{
	for (entity itemChain = world; (itemChain = next.Item(itemChain));) {
		string isWeapon = substring(itemChain.classname, 0, 7);
		string isAmmo = substring(itemChain.classname, 0, 5);

		if (isWeapon == "weapon_" || isAmmo == "ammo_") {
			ents.Input(itemChain, "SetRespawnTime", "20.0f", world);
		} else {
			ents.Input(itemChain, "SetRespawnTime", "30.0f", world);
		}
	}
}

void
Util_SharedPrecaches(void)
{
	precache.Entity("player_mp");
	precache.Model("models/player/alice2/alice2.mdl");
	precache.Model("models/player/jennifer2/jennifer2.mdl");
	precache.Model("models/player/natasha2/natasha2.mdl");
	precache.Model("models/player/yuri2/yuri2.mdl");
	precache.Model("progs/enforcer.mdl");

	/* Stiletto roster: precache each playable hero (pulls in model + loadout) */
	precache.Entity("hero_collier");
	precache.Entity("hero_beaumont");
	precache.Entity("hero_vagrant");
	precache.Entity("hero_skipstream");
	precache.Entity("hero_angel");
	precache.Entity("hero_motionblue");
	precache.Entity("hero_archstiletto");
}

/* =========================================================================
 * Hero roster system (data-driven playable characters)
 *
 * A "hero" is a player entityDef under decls/def/heroes/ inheriting hero_base.
 * Rulesets register the playable roster per team via teams.AddClass(), pick a
 * swap policy (when a player may change hero) and a composition policy (whether
 * teammates may share a hero), then route "selecthero <id>" client commands
 * through Hero_TrySelect().
 * ========================================================================= */

/* swap policy: when may a player change hero? */
#define HEROSWAP_ATSPAWN		0	/* apply immediately (re-spawn as the new hero) */
#define HEROSWAP_BETWEENROUNDS	1	/* queue while alive, apply on next respawn */
#define HEROSWAP_BETWEENMATCHES	2	/* locked in-match, apply at next match/respawn */

/* composition policy: may teammates share the same hero? */
#define HEROCOMP_DUPLICATES		0	/* any number of teammates may pick the same hero */
#define HEROCOMP_LOCK			1	/* each hero held by at most one player per team */

/* defaults (0/0) are HEROSWAP_ATSPAWN + HEROCOMP_DUPLICATES; set via Hero_SetPolicy.
   Not initialized inline so fteqcc treats them as mutable globals, not constants. */
int g_heroSwapPolicy;
int g_heroCompPolicy;

/** Sets the active swap + composition policy for the current ruleset. */
void
Hero_SetPolicy(int swapPolicy, int compPolicy)
{
	g_heroSwapPolicy = swapPolicy;
	g_heroCompPolicy = compPolicy;
}

/** Registers the shared hero roster onto a team's class list. */
void
Hero_RegisterRoster(int teamNum)
{
	teams.AddClass(teamNum, "hero_collier");
	teams.AddClass(teamNum, "hero_beaumont");
	teams.AddClass(teamNum, "hero_vagrant");
	teams.AddClass(teamNum, "hero_skipstream");
	teams.AddClass(teamNum, "hero_angel");
	teams.AddClass(teamNum, "hero_motionblue");
	teams.AddClass(teamNum, "hero_archstiletto");
}

/** Returns true if heroID is part of the given team's registered roster. */
bool
Hero_IsRegistered(int teamNum, string heroID)
{
	int total = teams.TotalClasses(teamNum);

	for (int i = 0i; i < total; i++) {
		if (teams.ClassForIndex(teamNum, i) == heroID) {
			return (true);
		}
	}

	return (false);
}

/** Returns the hero a player currently claims on their team: their queued pick
 * if one is set, otherwise their live hero class. Computed on demand so the
 * hero-lock "taken" set never leaks on disconnect/death/swap. */
string
Hero_ClaimedHero(entity pl)
{
	string queued = userinfo.GetString(pl, "*hero");

	if (STRING_SET(queued)) {
		return (queued);
	}

	if (substring(pl.classname, 0, 5) == "hero_") {
		return (pl.classname);
	}

	return ("");
}

/** Returns true if any OTHER player on teamNum already claims heroID. */
bool
Hero_TeamHasHero(int teamNum, string heroID, entity exclude)
{
	for (entity p = world; (p = next.Player(p));) {
		if (p == exclude) {
			continue;
		}

		if (p.team != (float)teamNum) {
			continue;
		}

		if (Hero_ClaimedHero(p) == heroID) {
			return (true);
		}
	}

	return (false);
}

/** Default hero for a team when a player has made no valid selection.
 * Team 1 defaults to Collier, all other teams to Beaumont, so the two sides
 * spawn visibly distinct before anyone opens the hero-select menu. */
string
Hero_DefaultForTeam(int teamNum)
{
	if (teamNum == 1) {
		return ("hero_collier");
	}

	return ("hero_beaumont");
}

/** Resolves which hero a player should (re)spawn as. Honors a valid queued pick,
 * falls back to their current hero, then to the team default. Consumes nothing -
 * the queued *hero key stays so it persists as the player's choice. */
string
Hero_ResolveSpawnHero(entity pl)
{
	int teamNum = (int)pl.team;
	string queued = userinfo.GetString(pl, "*hero");

	/* honor a queued/selected pick if it's valid for this team */
	if (STRING_SET(queued) && Hero_IsRegistered(teamNum, queued)) {
		if (g_heroCompPolicy != HEROCOMP_LOCK || Hero_TeamHasHero(teamNum, queued, pl) == false) {
			return (queued);
		}
	}

	/* keep the current hero if it's still valid for this team */
	if (Hero_IsRegistered(teamNum, pl.classname)) {
		return (pl.classname);
	}

	return (Hero_DefaultForTeam(teamNum));
}

/** Sends a short hero-select feedback message to a client. */
void
Hero_Notify(entity pl, string msg)
{
	centerprint(pl, msg);
}

/** Validates and applies a hero selection, honoring swap + composition policy.
 * Returns true if the request was accepted (applied now or queued). */
bool
Hero_TrySelect(entity pl, string heroID)
{
	int teamNum = (int)pl.team;

	if (!STRING_SET(heroID)) {
		return (false);
	}

	/* must be on a real team */
	if (teamNum == TEAM_SPECTATOR || teams.Valid(teamNum) == false) {
		Hero_Notify(pl, "Join a team before selecting a hero.");
		return (false);
	}

	/* hero must be in this team's roster */
	if (Hero_IsRegistered(teamNum, heroID) == false) {
		Hero_Notify(pl, sprintf("Hero %S is not available.", heroID));
		return (false);
	}

	/* composition policy: hero-lock rejects a hero already claimed by a teammate */
	if (g_heroCompPolicy == HEROCOMP_LOCK) {
		if (Hero_TeamHasHero(teamNum, heroID, pl) == true) {
			Hero_Notify(pl, sprintf("Hero %S is already taken.", heroID));
			return (false);
		}
	}

	/* record the pick: clients can read *hero, and it's consumed on respawn */
	userinfo.SetString(pl, "*hero", heroID);

	/* swap policy decides when the pick takes effect */
	if (g_heroSwapPolicy == HEROSWAP_ATSPAWN || is.Alive(pl) == false) {
		ents.ChangeToClass(pl, heroID);
		game.TeleportToSpawn(pl);
		Hero_Notify(pl, sprintf("Now playing as %S.", heroID));
	} else {
		Hero_Notify(pl, sprintf("Hero %S queued for next respawn.", heroID));
	}

	return (true);
}
