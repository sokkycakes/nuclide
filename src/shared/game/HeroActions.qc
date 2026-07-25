/*
 * Hero action router — Phase 1 routing seam.
 *
 * Tool press/release still forwards to weapon ability virtuals for parity.
 * Ownership moves off m_activeWeapon in a later phase.
 */

void
HeroActions_Reset(entity player)
{
	/* Phase 1: no dedicated hero-action state to clear yet. */
}

void
HeroActions_HeroToolPress(entity player)
{
	ncPlayer pl;
	string weapName;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
	weapName = "(none)";
	if (pl.m_activeWeapon) {
		weapName = pl.m_activeWeapon.declclass;
	}

	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] tool press player=%d weapon=%s\n",
			num_for_edict(pl), weapName));
	}

#ifdef SERVER
	/* Parity path: keep existing weapon-owned ability behavior for now. */
	if (pl.m_activeWeapon) {
		pl.m_activeWeapon.DoAbilityAction();
	}
#endif
}

void
HeroActions_HeroToolRelease(entity player)
{
	ncPlayer pl;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;

	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] tool release player=%d\n",
			num_for_edict(pl)));
	}

#ifdef SERVER
	if (pl.m_activeWeapon) {
		pl.m_activeWeapon.OnAbilityReleased();
	}
#endif
}

void
HeroActions_InputFrame(entity player, int currentButtons, int previousButtons)
{
	ncPlayer pl;
	int toolNow;
	int toolPrev;
	int meleeNow;
	int meleePrev;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
	toolNow = currentButtons & INPUT_HERO_TOOL;
	toolPrev = previousButtons & INPUT_HERO_TOOL;
	meleeNow = currentButtons & INPUT_MELEE;
	meleePrev = previousButtons & INPUT_MELEE;

	if (toolNow && !toolPrev) {
		HeroActions_HeroToolPress(pl);
	} else if (!toolNow && toolPrev) {
		HeroActions_HeroToolRelease(pl);
	}

	/* Phase 2 will invoke auxiliary melee here. */
	if (meleeNow && !meleePrev && autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] melee press (noop until phase 2) player=%d\n",
			num_for_edict(pl)));
	}
}
