/*
 * Vagrant knife — combined melee + throw projectile weapon + warpknife.
 *
 * Single weapon, three firing modes sharing clip/reload state:
 *   Primary fire (INPUT_PRIMARY)       — throw knife projectile (1 shot, 2s reload)
 *   Secondary fire (INPUT_SECONDARY)   — melee swing (89u, 1 dmg) + bullet cut
 *   Reload (INPUT_RELOAD)              — queue warpknife / pick up stuck knife
 *
 * Warpknife: when queued via reload, the next throw spawns a sticky projectile
 * that stays on the surface it hits. Only one active at a time. Despawns if
 * the player takes damage. Pick up by pressing reload within 32 units.
 *
 * Inherits ncWeapon directly (not ncWeaponBaseMelee) because the primary
 * fire needs the standard projectile path while secondary does a melee swing.
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
