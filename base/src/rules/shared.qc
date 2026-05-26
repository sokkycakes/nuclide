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
}
