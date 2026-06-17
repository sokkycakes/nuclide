// QC port of VGenericConfirmation + VGenericWaitScreen

class VGenericConfirmation : CBaseModFrame
{
	void VGenericConfirmation(void);
};

class VGenericWaitScreen : CBaseModFrame
{
	void VGenericWaitScreen(void);
};

void
VGenericConfirmation::VGenericConfirmation(void)
{
	m_WindowType = WT_GENERICCONFIRMATION;
	m_Priority = WPRI_MESSAGE;
}

void
VGenericWaitScreen::VGenericWaitScreen(void)
{
	m_WindowType = WT_GENERICWAITSCREEN;
	m_Priority = WPRI_WAITSCREEN;
}
