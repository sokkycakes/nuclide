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

/* Like Source's viewport, one input panel at a time:
- a menu the player opens (changeteam, changeclass) puts the MOTD away and
  the MOTD comes back once that menu is done, as the last active panel.
- a menu the server pushes waits for the MOTD to close; in Source the team
  menu only comes after the MOTD's exit command. */
var bool g_motdVisible;
var bool g_motdSuspended;
var string g_motdPendingMenu;
var vguiWindow g_motdWindow;

/** Returns true (and remembers the command) when a server-pushed team or
class menu must wait for the MOTD. */
bool
VGUI_MOTDDefersMenu(string menuCommand)
{
	if (g_motdVisible == false) {
		return (false);
	}

	g_motdPendingMenu = menuCommand;
	return (true);
}

/** Puts the MOTD away for a menu the player opened. */
void
VGUI_MOTDSuspend(void)
{
	if (g_motdVisible == false || !g_motdWindow) {
		return;
	}

	g_motdWindow.Hide();
	g_motdVisible = false;
	g_motdSuspended = true;
}

/** Brings the MOTD back once the player's menus are closed. */
void
VGUI_MOTDResume(void)
{
	if (g_motdSuspended == false || !g_motdWindow) {
		return;
	}

	g_motdSuspended = false;
	g_motdVisible = true;
	g_motdWindow.Show();
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
		int playerTeam = player.GetTeam();
		bool teamSelect = ((playerTeam == TEAM_UNASSIGNED) || (playerTeam == TEAM_SPECTATOR)) ? (true) : (false);

		if (playerTeam == 0) {
			teamSelect = true;
		}

		g_motdVisible = false;
		g_motdSuspended = false;

		if (STRING_SET(g_motdPendingMenu)) {
			localcmd(sprintf("%s\n", g_motdPendingMenu));
			g_motdPendingMenu = "";
		} else if ((teams.OpenTeamCount() > 0i) && (teamSelect == true)) {
			printf("Opening Team Selection\n");
			localcmd("showTeamSelectionMenu\n");
		}

		if (winMotd) {
			winMotd.Hide();
		}
	}

	if (MOTD_GetLineCount() < 1i) {
		VGUI_ShowMOTD_Close();
		return;
	}

	if (!initialized) {
		initialized = TRUE;
		winMotd = spawn(vguiWindow);
		g_motdWindow = winMotd;
		winMotd.SetTitle("Message Of The Day");
		winMotd.SetStyleMask(vguiWindowBorderless | vguiWindowFullscreen);
		winMotd.SetSize('424 312');
		winMotd.SetStyleMask(0);

		winMotdClose = spawn(vguiButton);
		winMotdClose.SetTitle("OK");
		winMotdClose.SetPos([16, 266]);
		winMotdClose.SetSize([160, 30]);
		winMotdClose.SetFunc(VGUI_ShowMOTD_Close);

		winMotdHostname = spawn(vguiLabel);
		winMotdHostname.SetTitle(serverkey("hostname"));
		winMotdHostname.SetTextSize(19);
		winMotdHostname.SetPos([16, 20]);

		winMotdBody = spawn(vguiLabel);
		winMotdBody.SetTitle(MOTD_GetTextBody());
		winMotdBody.SetPos([16, 48]);
		winMotdBody.SetSize([392, 210]);

		g_uiDesktop.Add(winMotd);
		winMotd.Add(winMotdClose);
		winMotd.Add(winMotdHostname);
		winMotd.Add(winMotdBody);
	}

	g_motdVisible = true;
	winMotd.Show();
	winMotd.SetPos((g_vidsize / 2) - (winMotd.GetSize() / 2));
}
