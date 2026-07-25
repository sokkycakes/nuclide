/*
 * Vagrant knife — melee + throw projectile + warpknife.
 *
 * Controls:
 *   M1 (INPUT_PRIMARY)       — throw knife projectile (1 shot, 2s reload)
 *   Q  (INPUT_SECONDARY)     — melee swing (89u range) + bullet cut + backstab
 *   M2 (nuclide_abi_grapple) — throw warpknife / teleport / hold-to-pickup
 *   R                        — no function (replaced by M2)
 *
 * Backstab: Q-hit from behind (yaw diff > 120°) sets health = 0 instantly,
 * bypassing HP and any future armor/barrier system.
 *
 * Warpknife: thrown via M2, sticks to surfaces. M2 again teleports to it.
 * Hold M2 within 32u for 1.5s to pick up. Despawns on damage.
 * Cooldown: 1s close (≤512u), ramps to 10s at 2000u.
 * Wall stick: teleporting to a vertical surface gives 1.5s cling + slide.
 * Long-range freeze: teleports ≥512u freeze the player for 1.3s.
 *
 * Inherits ncWeapon directly (not ncWeaponBaseMelee). Melee swing is
 * a simple forward traceline — no hull trace or cleave.
 */
class ncWeaponVagrantKnife : ncWeapon
{
public:
	void ncWeaponVagrantKnife(void);

#ifdef SERVER
	/* Precache + read def config */
	virtual void Spawned(void);

	/* Primary: throw knife projectile */
	virtual void PrimaryAttack(void);

	/* Secondary: melee swing + cut */
	virtual void SecondaryAttack(void);

	/* Reload: no function */
	virtual void Reload(void);

	/* Per-frame: warpknife health check + cleanup */
	virtual void InputFrame(void);

	/* Hero ability: throw warpknife / warp teleport / hold-to-pickup */
	virtual void DoAbilityAction(void);
	virtual void OnAbilityReleased(void);

	/* Fire a warpknife projectile */
	virtual void FireWarpKnife(entity);

	/* Melee swing + cut (shared by both fire modes) */
	virtual void DoMeleeSwing(void);

	/* Warp teleport + ghost image */
	virtual void DoWarpTeleport(entity, float);
	virtual void SpawnGhost(entity, vector);


	/* Think: unfreeze after long-range warp */
	virtual void FreezeEndThink(void);

	/* Swing trace + damage (ported from ncWeaponBaseMelee) */
	virtual void DoSwingTrace(void);
	virtual void ApplyMeleeDamage(entity, vector, vector);

	/* Deflect / cut support */
	bool m_bCanCut;
	float m_flDeflectCooldown;
	float m_flDeflectCooldownEnd;

	/* Warpknife state */
	bool m_bWarpQueued;
	entity m_entWarpKnife;
	float m_flWarpThrowTime;
	float m_flNextWarpTime;
	float m_flReloadEnd;
	float m_flPickupHoldStart;
	bool m_bAbilityHeld;
#endif
};

/* Auxiliary Vagrant melee: ncWeaponBaseMelee + backstab. */
class ncWeaponVagrantMelee : ncWeaponBaseMelee
{
public:
	void ncWeaponVagrantMelee(void);

#ifdef SERVER
	virtual void ApplyMeleeDamage(entity, vector, vector);
#endif
};
