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

void
m_init(void)
{
	UI_Options_ResetKeybindCapture();
	Platform_Init();
	UISystem_Init();
	Desktop_Init();

	registercommand("packageList");
	registercommand("friendsList");
	registercommand("console");
	registercommand("menu_quit");
	registercommand("menu_music");
	registercommand("map_background");
}

void
Menu_RendererRestarted(string renderer)
{
	Platform_RendererRestarted();
}

void
m_shutdown(void)
{
	Platform_Shutdown();
}

void
m_draw(vector screensize)
{
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

	Background_Draw([0,0], g_vidsize, false);
	Desktop_Draw();
}

void
m_drawloading(vector screensize, float opaque)
{
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

static float
Menu_IsEngineToggleConsoleKey(float evtype, float scanx)
{
	float n;
	float i;
	float k;

	if (evtype != IE_KEYDOWN)
		return 0;

	if (scanx <= 0)
		return 0;

	n = tokenize(findkeysforcommand("toggleconsole"));

	for (i = 0; i < n; i++) {
		k = stof(argv(i));

		if (k >= 0 && scanx == k)
			return 1;
	}

	return (scanx == K_BACKQUOTE);
}

float
Menu_InputEvent (float evtype, float scanx, float chary, float devid)
{
	switch (evtype) {
	case IE_MOUSEABS:
		g_vecMousePos[0] = scanx;
		g_vecMousePos[1] = chary;
		break;
	case IE_MOUSEDELTA:
		g_vecMousePos[0] += scanx;
		g_vecMousePos[1] += chary;
		break;
	default:
		break;
	}

	g_vecMousePos = getmousepos();

	if (Menu_IsEngineToggleConsoleKey(evtype, scanx)) {
		localcmd("toggleconsole\n");
		return (float)g_active;
	}

	if (UI_Options_KeybindCapture(evtype, scanx, chary, devid))
		return (float)g_active;

	if (UI_Options_HandleMenuKeys(evtype, scanx, chary, devid))
		return (float)g_active;

	switch (evtype) {
	case IE_KEYDOWN:
		if (chary == K_ESCAPE) {
			if (clientstate() == 2 && !g_background) {
				m_toggle(0);
			}
		}
		break;
	default:
		break;
	}

	g_uiDesktop.Input(evtype, scanx, chary, devid);
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
	UI_Options_ResetKeybindCapture();
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
	case "console":
		static VGUIConsole consoleWindow;

		if (!consoleWindow)
			consoleWindow = spawn(VGUIConsole);

		g_uiDesktop.Add( consoleWindow );
		break;
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
