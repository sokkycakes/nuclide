/* Archstiletto primary — melee (base) + charged lunge ability (MOUSE2). */
class ncWeaponArchstiletto : ncWeaponBaseMelee
{
public:
	void ncWeaponArchstiletto(void);

#ifdef SERVER
	virtual void DoAbilityAction(void);
	virtual void OnAbilityReleased(void);
#endif
};
