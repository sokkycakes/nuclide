/*
 * Archstiletto weapon — axe-derived melee plus ground-charged mobility lunge
 * on the hero-ability key (see stiletto_tuning.qc for impulse / slow).
 */

void
ncWeaponArchstiletto::ncWeaponArchstiletto(void)
{
}

#ifdef SERVER
void
ncWeaponArchstiletto::DoAbilityAction(void)
{
	ncPlayer o = (ncPlayer)GetOwner();

	if (!o) {
		return;
	}

	/* Wall re-lunge: press while wall-touching and a sequence is active. */
	if ((o.m_nuclideFlags & VFL_STILETTO_WALL)
	    && o.m_stilettoLungeSeqStrength > 0.0f) {
		Stiletto_Lunge_RequestLaunch(o, o.m_stilettoLungeSeqStrength);
		return;
	}

	/* Ground charge only; ignore air holds that aren't wall re-lunges. */
	if (!(o.flags & FL_ONGROUND)) {
		return;
	}

	if (time < o.m_stilettoLungeCooldownEnd) {
		return;
	}

	if (o.m_stilettoLungeCharging) {
		return;
	}

	o.m_stilettoLungeCharging = 1;
	o.m_stilettoLungeChargeStart = time;
}

void
ncWeaponArchstiletto::OnAbilityReleased(void)
{
	ncPlayer o = (ncPlayer)GetOwner();
	float held;
	float strength;

	if (!o) {
		return;
	}

	if (!o.m_stilettoLungeCharging) {
		return;
	}

	o.m_stilettoLungeCharging = 0;

	/* Walked off a ledge mid-charge — cancel, no launch. */
	if (!(o.flags & FL_ONGROUND)) {
		o.m_stilettoLungeChargeStart = 0.0f;
		return;
	}

	held = time - o.m_stilettoLungeChargeStart;
	o.m_stilettoLungeChargeStart = 0.0f;

	if (held < 0.0f) {
		held = 0.0f;
	}

	strength = held / STILETTO_LUNGE_CHARGE_TIME;
	if (strength > 1.0f) {
		strength = 1.0f;
	}
	if (strength < STILETTO_LUNGE_MIN_STRENGTH) {
		strength = STILETTO_LUNGE_MIN_STRENGTH;
	}

	o.m_stilettoLungeSeqStrength = strength;
	o.m_stilettoLungeCooldownEnd = time + STILETTO_LUNGE_COOLDOWN;
	Stiletto_Lunge_RequestLaunch(o, strength);
}
#endif
