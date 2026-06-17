// Nuclide QC port of CBaseModFrame (from basemodframe.cpp/h)

class CBaseModFrame : vguiWindow
{
	WINDOW_TYPE m_WindowType;
	WINDOW_PRIORITY m_Priority;
	CBaseModFrame m_NavBack;
	bool m_bCanNavBack;

	void() CBaseModFrame;
	nonvirtual void OnOpen();
	nonvirtual void OnClose();
	nonvirtual void RunFrame();
	nonvirtual void LoadLayout();
	nonvirtual void LoadControlSettings(string resName);

	nonvirtual void SetNavBack(CBaseModFrame nav);
	nonvirtual CBaseModFrame GetNavBack();
};

void() CBaseModFrame::CBaseModFrame
{
	// Set style to be non-movable, non-titled, but closable (for custom close button)
	m_styleMask = vguiWindowClosable;
	// port of constructor + LoadLayout + ReloadSettings
}

void CBaseModFrame::OnOpen() {}
void CBaseModFrame::OnClose() {}
void CBaseModFrame::RunFrame() {}
void CBaseModFrame::LoadLayout() {}
void CBaseModFrame::LoadControlSettings(string resName) {}  // .res parser TODO

void CBaseModFrame::SetNavBack(CBaseModFrame nav) { m_NavBack = nav; }
CBaseModFrame CBaseModFrame::GetNavBack() { return m_NavBack; }
