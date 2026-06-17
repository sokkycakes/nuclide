// BaseModUI QC test entry points.
// Console:
//   basemodui_test                  - opens MainMenu + InGameMainMenu
//   basemodui_open <res-basename>   - opens a generic frame and parses .res by name
//                                     (lowercased; matches base/ui/l4d360ui/*.res)
//   basemodui_close                 - clears all open BaseMod frames

CBaseModFrame g_baseModTestFrames[16];
int g_baseModTestCount;

static void
BaseModUI_AddDesktop(CBaseModFrame frame)
{
	if (!frame) return;
	if (g_baseModTestCount < 16) {
		g_baseModTestFrames[g_baseModTestCount] = frame;
		g_baseModTestCount++;
	}
	g_uiDesktop.Add(frame);
}

void
BaseModUI_Test(void)
{
	CBaseModPanel p;
	CBaseModFrame menu;
	CBaseModFrame ingame;

	if (!g_BaseModPanel) {
		spawn(CBaseModPanel);
	}

	p = CBaseModPanel_GetSingleton();

	menu = p.OpenWindow(WT_MAINMENU, __NULL__);
	if (menu) {
		menu.SetSize([640, 480]);
		menu.SetPos([32, 32]);
		BaseModUI_AddDesktop(menu);
	}

	ingame = p.OpenWindow(WT_INGAMEMAINMENU, __NULL__);
	if (ingame) {
		ingame.SetSize([640, 480]);
		ingame.SetPos([96, 96]);
		BaseModUI_AddDesktop(ingame);
	}

	m_display();
	print("BaseModUI: opened MainMenu + InGameMainMenu\n");
}

void
BaseModUI_Open(string resName)
{
	if (resName == "") {
		print("usage: basemodui_open <res-basename>\n");
		return;
	}

	CBaseModFrame frame = spawn(CBaseModFrame);
	frame.SetPos([32, 32]);
	frame.SetSize([640, 480]);
	frame.SetTitle(resName);

	BaseMod_LoadControlSettings(frame, resName);
	BaseModUI_AddDesktop(frame);

	m_display();
}

void
BaseModUI_Close(void)
{
	int i;
	for (i = 0; i < g_baseModTestCount; i++) {
		if (g_baseModTestFrames[i]) {
			g_baseModTestFrames[i].Hide();
			g_baseModTestFrames[i] = __NULL__;
		}
	}
	g_baseModTestCount = 0;
	print("BaseModUI: closed all test frames\n");
}
