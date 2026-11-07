/*
 * Copyright (c) 2016-2022 Vera Visions LLC.
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF MIND, USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
*/

void m_display(void);

void
m_init(void)
{
	Platform_Init();
	UISystem_Init();
	Desktop_Init();
	L4D_Init();
	UIOMP_RestoreSavedSpray();

	registercommand("packageList");
	registercommand("friendsList");
	registercommand("console");
	registercommand("menu_quit");
	registercommand("menu_music");
	registercommand("menu_options");
	registercommand("menu_title");
#ifdef LAB_L4D360_TEST
	registercommand("menu_title_test");
#endif
#ifdef LAB_OPTIONS_TEST
	registercommand("menu_options_test");
#endif
	registercommand("map_background");

	/* Quake manifest startup can reload MenuQC after the initial menu command.
	 * The title has no background server to reopen it, so restore its offline
	 * visibility when the VM is initialized. In-level menus keep their flow. */
	if (L4D_Active()) m_display();
}

void
Menu_RendererRestarted(string renderer)
{
	Platform_RendererRestarted();
	UIOMP_ReloadImages();
	if (g_l4dLoaded) L4D_ReloadFonts();
}

void
m_shutdown(void)
{
	UI_Options_Close();
	Platform_Shutdown();
}

void
m_draw(vector screensize)
{
	UI_Options_Frame();
	/* set new scale whenever the resolution changes */
	if (Platform_DimensionsChanged(screensize) == true) {
		Platform_CalculateRenderingScale(screensize);
		Desktop_CanvasChanged();
	}


	frametime = time - lasttime;
	lasttime = time;

	if (Platform_Draw(screensize) == false) {
		return;
	}

	if (!L4D_Active()) Background_Draw([0,0], g_vidsize, false);
	Desktop_Draw();
}

void
m_drawloading(vector screensize, float opaque)
{
	UI_Options_Frame();
	vector pos;

	/* set new scale whenever the resolution changes */
	if (Platform_DimensionsChanged(screensize) == true) {
		Platform_CalculateRenderingScale(screensize);
		Desktop_CanvasChanged();
	}

	pos = (screensize / 2) - [32,32];

	if (opaque || (clientstate() != 2)) {
		Background_Draw([0,0], screensize, opaque);
	}

	Loading_Draw(screensize);
}

float
Menu_InputEvent (float evtype, float scanx, float chary, float devid)
{
    g_vecMousePos = getmousepos();
    if (UI_Options_InputEvent(evtype, scanx, chary, devid))
        return 1;
    if (evtype == IE_KEYDOWN && getkeybind(scanx, 0, 0) == "toggleconsole") {
        localcmd("toggleconsole\n");
        return 1;
    }
    if (L4D_Active()) {
        if (L4D_ModalInput(evtype,scanx,chary,devid)) return 1;
        return L4D_Input(evtype,scanx,chary,devid);
    }
	switch (evtype) {
	case IE_KEYDOWN:
		if (scanx == K_ESCAPE) {
			if (clientstate() == 2 && !g_background) {
				m_toggle(0);
			}
		}
		break;
	case IE_MOUSEABS:
		g_vecMousePos[0] = scanx;
		g_vecMousePos[1] = chary;
		break;
	case IE_MOUSEDELTA:
		g_vecMousePos[0] += scanx;
		g_vecMousePos[1] += chary;
		break;
	}

	g_vecMousePos = getmousepos();
	if (!L4D_ModalInput(evtype,scanx,chary,devid))
		g_uiClassicDesktop.Input(evtype, scanx, chary, devid);
	return (float)g_active;
}

void
m_display(void)
{
	g_active = TRUE;
	setkeydest(KEY_MENU);
	setmousetarget(TARGET_MENU);
	setcursormode(TRUE, "gfx/icon16/cursor");
}

/*
=================
m_hide
=================
*/
void
m_hide(void)
{
	UI_Options_Close();
	L4D_CloseFlyout(false);
	g_l4dPressed = -1;
	g_l4dNotice = false;
	g_active = FALSE;
	setkeydest(KEY_GAME);
	setmousetarget(TARGET_CLIENT);
	setcursormode(FALSE);
}

/*
=================
m_toggle
=================
*/
void
m_toggle(float fMode)
{
	if (fMode == FALSE)
		m_hide();
	else
		m_display();
}

float
m_consolecommand(string cmd)
{
	int c = (int)tokenize(cmd);

	switch (argv(0)) {
#ifdef LAB_L4D360_TEST
	case "menu_title_test":
		L4D_RunTests(cmd);
		break;
#endif
	case "menu_title":
		UI_Options_Close();
		L4D_CloseFlyout(false);
		g_l4dNotice = false;
		g_l4dPressed = -1;
		for (vguiWidget child=g_uiDesktop.m_next;child;child=child.m_next) child.Hide();
		m_display();
		break;
	case "console":
		static VGUIConsole consoleWindow;

		if (!consoleWindow)
			consoleWindow = spawn(VGUIConsole);

		g_uiDesktop.Add( consoleWindow );
		break;
    case "menu_options":
        string requestedPage = argv(1);
        UI_Options_Show();
        for (int page = 0; page < 6; page++)
            if (requestedPage == UIO_Part("keyboard|mouse|audio|video|voice|multiplayer", page))
                UIO_SetPage(page);
        m_display();
        break;
#ifdef LAB_OPTIONS_TEST
    case "menu_options_test":
        UIO_RunTestCommand(cmd);
        break;
#endif
	case "menu_quit":
		UI_QuitGame_Show();
		break;
	case "menu_music":
		UI_MusicPlayer_Show();
		break;
	case "friendsList":
		UI_Friends_Show();
		break;
	case "packageList":
		UI_Packages_Show();
		break;
	default:
		return Platform_ConsoleCommand(cmd, c);
	}

	return (1);
}
