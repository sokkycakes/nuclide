// QC port of VMainMenu (from vmainmenu.cpp/h)
class VMainMenu : CBaseModFrame
{
	void() VMainMenu { m_WindowType = WT_MAINMENU; m_Priority = WPRI_NORMAL; }
	virtual void OnOpen() { /* load mainmenu.res layout */ }
};
