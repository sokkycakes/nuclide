#pragma once

class
HLWeaponSelect
{
	public:
		void HLWeaponSelect(void);

		virtual void Draw(void);
		virtual void SelectSlot(int, bool);
		virtual void SelectNext(bool);
		virtual void SelectPrevious(bool);
		virtual void DrawBar(vector, float);

		nonvirtual void Event_Opened(void);
		nonvirtual void Event_Closed(void);
		nonvirtual void Event_SelectionChanged(void);
		nonvirtual void Event_SelectionTriggered(void);

		virtual bool Active(void);
		virtual void Trigger(void);
		virtual void Deactivate(void);

		virtual void DrawSlotNum(vector, float);

	private:
		float m_flHUDWeaponSelectTime;
		entity m_selectedWeapon;
		entity m_firstWeapon;
		entity m_lastWeapon;
		int m_iWantSlot;
		int m_iWantSlotPos;
};
