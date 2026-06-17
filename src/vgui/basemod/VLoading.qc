// QC port of VLoadingProgress + VTransitionScreen

class VLoadingProgress : CBaseModFrame
{
	void VLoadingProgress(void);
};

class VTransitionScreen : CBaseModFrame
{
	void VTransitionScreen(void);
};

void
VLoadingProgress::VLoadingProgress(void)
{
	m_WindowType = WT_LOADINGPROGRESS;
	m_Priority = WPRI_LOADINGPLAQUE;
}

void
VTransitionScreen::VTransitionScreen(void)
{
	m_WindowType = WT_TRANSITIONSCREEN;
	m_Priority = WPRI_BKGNDSCREEN;
}
