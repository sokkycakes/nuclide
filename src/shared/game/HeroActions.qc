/*
 * Hero action router — Phase 1 routing seam.
 *
 * Tool press/release still forwards to weapon ability virtuals for parity.
 * Ownership moves off m_activeWeapon in a later phase.
 */

void
HeroActions_Reset(entity player)
{
	HeroActions_ClearMeleeWeapon(player);
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
HeroActions_ClearMeleeWeapon(entity player)
{
	ncPlayer pl;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
#ifdef SERVER
	if (pl.m_heroMeleeWeapon) {
		if (!wasfreed(pl.m_heroMeleeWeapon)) {
			remove(pl.m_heroMeleeWeapon);
		}
		pl.m_heroMeleeWeapon = __NULL__;
	}
#endif
}

void
HeroActions_EnsureMeleeWeapon(entity player)
{
	ncPlayer pl;
	string meleeDef;
	ncWeapon w;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;
#ifdef SERVER
	if (pl.m_heroMeleeWeapon && !wasfreed(pl.m_heroMeleeWeapon)) {
		return;
	}

	pl.m_heroMeleeWeapon = __NULL__;
	meleeDef = pl.GetDefString("hero_melee_weapon");
	if (!STRING_SET(meleeDef)) {
		return;
	}

	w = (ncWeapon)EntityDef_CreateClassname(meleeDef);
	if (!w) {
		if (autocvar_hero_actions_debug) {
			print(sprintf("[hero_actions] failed to create melee '%s'\n", meleeDef));
		}
		return;
	}

	/* Non-selectable auxiliary: own it, but do not GiveItem / weapon-chain. */
	w.SetOwner(pl);
	pl.m_heroMeleeWeapon = w;

	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] spawned melee '%s' for player=%d\n",
			meleeDef, num_for_edict(pl)));
	}
#endif
}

void
HeroActions_MeleePress(entity player)
{
	ncPlayer pl;
	ncWeapon melee;

	if (!player) {
		return;
	}

	pl = (ncPlayer)player;

	if (autocvar_hero_actions_debug) {
		print(sprintf("[hero_actions] melee press player=%d\n", num_for_edict(pl)));
	}

#ifdef SERVER
	HeroActions_EnsureMeleeWeapon(pl);
	melee = pl.m_heroMeleeWeapon;
	if (!melee || wasfreed(melee)) {
		return;
	}

	/* Never change m_activeWeapon — swing the auxiliary entity directly. */
	melee._PrimaryAttack();
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

	if (meleeNow && !meleePrev) {
		HeroActions_MeleePress(pl);
	}
}
