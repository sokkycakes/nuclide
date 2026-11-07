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
}

/* Quake-style player voice. ncPlayer doesn't voice pain or death itself,
   so the rules do it through the entity's StartSoundDef input (CHAN_VOICE). */
float g_painSoundTime[256];

void
Util_PlayerPainSound(entity playerEntity)
{
	float slot = num_for_edict(playerEntity);

	if (slot < 0 || slot >= 256) {
		return;
	}

	/* Quake waits half a second between pain cries */
	if (g_painSoundTime[slot] > time) {
		return;
	}

	g_painSoundTime[slot] = time + 0.5f;
	ents.Input(playerEntity, "StartSoundDef", "Player.Pain", playerEntity);
}

void
Util_PlayerDeathSound(entity playerEntity)
{
	/* ncPlayer::Death gibs below -50 health */
	if (playerEntity.health < -50) {
		ents.Input(playerEntity, "StartSoundDef", "Player.Gib", playerEntity);
	} else {
		ents.Input(playerEntity, "StartSoundDef", "Player.Death", playerEntity);
	}
}
