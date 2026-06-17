// VMainMenu + VFooterPanel (declarations only; ctors defined out-of-line)

class VMainMenu : CBaseModFrame
{
	void VMainMenu(void);
};

class VFooterPanel : vguiWidget
{
	void VFooterPanel(void);
};

void
VMainMenu::VMainMenu(void)
{
	m_WindowType = WT_MAINMENU;
	m_Priority = WPRI_NORMAL;
}

void
VFooterPanel::VFooterPanel(void)
{
}
