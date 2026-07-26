/*
 * Player-owned hero action router.
 */

var bool autocvar_hero_actions_debug = false;

void HeroActions_Reset(entity player);
void HeroActions_InputFrame(entity player, int currentButtons, int previousButtons);
void HeroActions_HeroToolPress(entity player);
void HeroActions_HeroToolRelease(entity player);
void HeroActions_MeleePress(entity player);
void HeroActions_EnsureMeleeWeapon(entity player);
void HeroActions_ClearMeleeWeapon(entity player);

/* Phase 4+ */
void HeroActions_SetGuardHeld(entity player, bool held);
bool HeroActions_CanAttack(entity player);
float HeroActions_ApplyGuardDamageRules(entity victim, entity attacker, float damage);
void HeroActions_InitResources(entity player);

/* Phase 5+ */
void HeroActions_CycleWeaponMode(entity player);

/* Phase 6+ */
void HeroActions_AddDrive(entity player, int amount);
bool HeroActions_SpendDrive(entity player, int amount);
void HeroActions_AddEX(entity player, int amount);
bool HeroActions_SpendEX(entity player, int amount);
bool HeroActions_CanUseAction(entity player, string actionId);

/* Phase 7+ */
void HeroActions_RequestSlot(entity player, int slot, string context);

#ifdef CLIENT
/* CSQC: publish Drive/EX/guard for WebCore HUD (hud.dat has no ncPlayer). */
void HeroActions_PublishHud(entity player);
#endif
