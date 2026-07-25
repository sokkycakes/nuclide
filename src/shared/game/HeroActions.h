/*
 * Player-owned hero action router. Phase 1: tool press/release + input edges.
 * Grow this surface per phase — do not stub later-phase APIs here.
 */

var bool autocvar_hero_actions_debug = false;

void HeroActions_Reset(entity player);
void HeroActions_InputFrame(entity player, int currentButtons, int previousButtons);
void HeroActions_HeroToolPress(entity player);
void HeroActions_HeroToolRelease(entity player);
