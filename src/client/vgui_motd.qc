/*
 * Copyright (c) 2023 Marco Cawthorne <marco@icculus.org>
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

/* cg_motd 0: never show the message of the day; 1 (default): show it when
   joining someone else's server, but not on a single-player map or to the
   host of a listen server (their own console map); 2: always. The server
   can also send none (g_nomotd 1). */
var float autocvar_cg_motd = 1;

static vguiWindow g_motdWindow;

/* The join order is the MOTD first, then the hero or team picker. A server
   can stuff showClassSelectionMenu before the first frame that opens the
   MOTD (deathmatch does on the first spawn), which drew the two windows on
   top of each other. Until the MOTD has been shown and closed (or skipped),
   a picker request is kept here and run when it goes away. It is kept
   per split-screen seat: each seat gets its own showClassSelectionMenu,
   and the command must run again for the seat it was sent to. */
static bool g_motdAutoDone;
static string g_motdDeferredPicker[4];
void VGUI_ShowMOTD(void);

/* The VGUI fonts carry no typographic dashes or quotes; a motd.txt written
   in a word processor would show gaps. */
string
VGUI_MOTD_PlainText(string text)
{
	text = strreplace("\xe2\x80\x94", "-", text);	/* em dash */
	text = strreplace("\xe2\x80\x93", "-", text);	/* en dash */
	text = strreplace("\xe2\x80\x98", "'", text);
	text = strreplace("\xe2\x80\x99", "'", text);
	text = strreplace("\xe2\x80\x9c", "\"", text);
	text = strreplace("\xe2\x80\x9d", "\"", text);
	text = strreplace("\xe2\x80\xa6", "...", text);	/* ellipsis */
	return (text);
}

/* true when a picker command must wait for the MOTD; the command is kept
   and run by VGUI_MOTD_Proceed. The latest request for a seat wins. */
bool
VGUI_MOTD_DeferPicker(string pickerCommand)
{
	bool motdUp = (g_motdWindow && g_motdWindow.Visible()) ? (true) : (false);
	int seatNum = (int)getproperty(VF_ACTIVESEAT);

	if (g_motdAutoDone && !motdUp) {
		return (false);
	}

	if (seatNum < 0i || seatNum > 3i) {
		seatNum = 0i;
	}

	if (g_motdDeferredPicker[seatNum]) {
		strunzone(g_motdDeferredPicker[seatNum]);
	}

	g_motdDeferredPicker[seatNum] = strzone(pickerCommand);
	return (true);
}

/* the window gets out of the way of the team and hero pickers */
void
VGUI_HideMOTD(void)
{
	if (g_motdWindow) {
		g_motdWindow.Hide();
	}
}

/* what closing the window does: arena and team modes go on to the team
   (join) page so a joiner is never left waiting with no way in */
static void
VGUI_MOTD_Proceed(void)
{
	/* pickers the server asked for while the MOTD was pending or up. A
	   seat other than the first gets the 'p<N>' prefix the engine uses
	   for a command aimed at that seat, so it runs in its own context. */
	bool ranPicker = false;

	for (int seatNum = 0i; seatNum < 4i; seatNum++) {
		string pickerCommand = g_motdDeferredPicker[seatNum];

		if (!pickerCommand) {
			continue;
		}

		g_motdDeferredPicker[seatNum] = __NULL__;

		if (seatNum == 0i) {
			localcmd(sprintf("%s\n", pickerCommand));
		} else {
			localcmd(sprintf("p%i %s\n", seatNum + 1i, pickerCommand));
		}

		strunzone(pickerCommand);
		ranPicker = true;
	}

	if (ranPicker) {
		return;
	}

	int playerTeam = player.GetTeam();
	bool teamSelect = ((playerTeam == TEAM_UNASSIGNED) || (playerTeam == TEAM_SPECTATOR)) ? (true) : (false);

	if (playerTeam == 0) {
		teamSelect = true;
	}

	/* arena modes (duel): a joiner waits on a team with no way in
	 * until they pick JOIN MATCH, which the team selection opens */
	bool arenaMode = STRING_SET(serverkey("arena_state"));

	if (arenaMode || ((teams.TeamCount() > 0i) && (teamSelect == true))) {
		printf("Opening Team Selection\n");
		localcmd("showTeamSelectionMenu\n");
	}
}

/* true when 'win' is showing and is the front-most window on the desktop:
   a window left open behind another (a hero picker, say) must not take
   the keys meant for the one in front */
bool
VGUI_IsFrontWindow(vguiWidget win)
{
	vguiWidget front = __NULL__;

	if (!win || !win.Visible()) {
		return (false);
	}

	for (vguiWidget w = g_uiDesktop.m_next; w; w = w.m_next) {
		if (w.m_parent == g_uiDesktop && w.Visible()) {
			front = w;
		}
	}

	return (front == win);
}

bool
VGUI_MOTD_Visible(void)
{
	return (VGUI_IsFrontWindow(g_motdWindow));
}

/* the OK button, from a key: Enter, Space, Escape or a pad's A/B/Start all
   close the window and go on to the team or join page, so nobody needs a
   mouse to get past it */
bool
VGUI_MOTD_KeyDown(float key)
{
	if (!VGUI_MOTD_Visible()) {
		return (false);
	}

	switch (key) {
	case K_ENTER:
	case K_KP_ENTER:
	case K_SPACE:
	case K_ESCAPE:
	case K_GP_A:
	case K_GP_B:
	case K_GP_MENU:
		g_motdWindow.Hide();
		VGUI_MOTD_Proceed();
		return (true);
	}

	return (false);
}

/* on connect: show it only to someone joining another person's server */
void
VGUI_AutoMOTD(void)
{
	bool show = true;

	g_motdAutoDone = true;

	if (autocvar_cg_motd <= 0) {
		show = false;
	} else if (autocvar_cg_motd < 2) {
		/* single player (one slot) or our own listen server */
		if (serverkeyfloat("sv_playerslots") <= 1 || isserver()) {
			show = false;
		}
	}

	if (show) {
		VGUI_ShowMOTD();
	} else {
		VGUI_MOTD_Proceed();
	}
}

void
VGUI_ShowMOTD(void)
{
	static int initialized;
	static vguiButton winMotdClose;
	static vguiWindow winMotd;
	static vguiLabel winMotdHostname;
	static vguiLabel winMotdBody;
	
	static void VGUI_ShowMOTD_Close(void)
	{
		if (winMotd) {
			winMotd.Hide();
		}

		VGUI_MOTD_Proceed();
	}

	if (MOTD_GetLineCount() < 1i) {
		VGUI_ShowMOTD_Close();
		return;
	}

	if (!initialized) {
		initialized = TRUE;
		winMotd = spawn(vguiWindow);
		winMotd.SetTitle("Message Of The Day");
		winMotd.SetStyleMask(vguiWindowBorderless | vguiWindowFullscreen);
		winMotd.SetSize('424 312');
		winMotd.SetStyleMask(0);
		g_motdWindow = winMotd;

		winMotdClose = spawn(vguiButton);
		winMotdClose.SetTitle("OK (Enter)");
		winMotdClose.SetPos([16, 266]);
		winMotdClose.SetSize([160, 30]);
		winMotdClose.SetFunc(VGUI_ShowMOTD_Close);
		/* a controller's B dismisses it like OK (A presses OK) */
		winMotd.CallOnCancel(VGUI_ShowMOTD_Close);

		winMotdHostname = spawn(vguiLabel);
		winMotdHostname.SetTextSize(19);
		winMotdHostname.SetPos([16, 20]);
		winMotdHostname.SetSize([392, 24]);	/* a label draws inside its size */

		winMotdBody = spawn(vguiLabel);
		winMotdBody.SetPos([16, 48]);
		winMotdBody.SetSize([392, 210]);

		g_uiDesktop.Add(winMotd);
		winMotd.Add(winMotdClose);
		winMotd.Add(winMotdHostname);
		winMotd.Add(winMotdBody);
	}

	/* the server's name and message as they are now, not as they were the
	   first time the window opened (or before serverinfo arrived) */
	string hostName = serverkey("hostname");
	if (!STRING_SET(hostName)) {
		hostName = cvar_string("hostname");
	}
	winMotdHostname.SetTitle(VGUI_MOTD_PlainText(hostName));
	winMotdBody.SetTitle(VGUI_MOTD_PlainText(MOTD_GetTextBody()));

	winMotd.Show();
	winMotd.SetPos((g_vidsize / 2) - (winMotd.GetSize() / 2));
}
