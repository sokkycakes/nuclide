class ncWeaponBaseMelee : ncWeapon
{
public:
	void ncWeaponBaseMelee(void);

#ifdef SERVER
	/* Precache sounds used by this weapon class. */
	virtual void Spawned(void);

	/* Override: play swing sound on every fire attempt */
	virtual void PrimaryAttack(void);

	/* Override: replaces projectile spawn with direct melee swing */
	virtual void FiredWeaponAttack(string);

	/* Swing trace. Line-first, then hull; optional cleave. */
	virtual void DoSwingTrace(void);

	/* Apply damage + push to a single entity. */
	virtual void ApplyMeleeDamage(entity, vector, vector);

	/* Config queries */
	virtual float GetMeleeRange(void);
	virtual float GetMeleeDamage(void);
	virtual float GetMeleePush(void);
	virtual bool GetMeleeCleave(void);

	/* Deflect / cut support */
	bool m_bCanCut;
	float m_flDeflectCooldown;
	float m_flDeflectCooldownEnd;
#endif
};
