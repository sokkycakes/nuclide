// QC port of VOptions, VAudio, VVideo, VKeyboardMouse (core options flow)

class VOptions : CBaseModFrame { void VOptions(void); };
class VAudio : CBaseModFrame { void VAudio(void); };
class VVideo : CBaseModFrame { void VVideo(void); };
class VKeyboardMouse : CBaseModFrame { void VKeyboardMouse(void); };

void VOptions::VOptions(void) { m_WindowType = WT_OPTIONS; }
void VAudio::VAudio(void) { m_WindowType = WT_AUDIO; }
void VVideo::VVideo(void) { m_WindowType = WT_VIDEO; }
void VKeyboardMouse::VKeyboardMouse(void) { m_WindowType = WT_KEYBOARDMOUSE; }
