/*
 * Copyright (c) 2026 Marco Cawthorne <marco@icculus.org>
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

/* The pause page's Host Menu and Call a Vote (menu_hostmenu, menu_callvote).

   Both are VGUI windows drawn by the client game, so they work the same on
   every engine and with or without the HTML menus. One window, two jobs:

   - Host Menu (only the player whose game is the listen server, isserver()):
     change map, change game type, kick a player, add or remove a bot,
     restart the map. The commands run on the host's own console.
   - Call a Vote (anyone): the same lists, but each pick calls a vote
     (callvote map|gametype|kick|restart|nextmap, src/server/vote.qc), with
     Yes (F1) and No (F2) for the vote that is running.

   Lists: maps and game types come from scripts/lobby.txt (the lobby's own
   choices) plus mapcycle.txt, keeping only maps and rules progs this
   install has. Players come from the scoreboard's slots. */

#define ADMIN_MAXENTRIES 64

enum
{
	ADMINTAB_MAPS,
	ADMINTAB_MODES,
	ADMINTAB_PLAYERS
};

static string g_adminMapIDs[ADMIN_MAXENTRIES];
static string g_adminMapNames[ADMIN_MAXENTRIES];
static int g_adminMapCount;
static string g_adminModeIDs[ADMIN_MAXENTRIES];
static string g_adminModeNames[ADMIN_MAXENTRIES];
static int g_adminModeCount;
static string g_adminPlayerNames[ADMIN_MAXENTRIES];
static bool g_adminPlayerBot[ADMIN_MAXENTRIES];
static int g_adminPlayerCount;
static bool g_adminListsRead;

/* fgets gives "" for a blank line and at the end of the file alike: stop
   after a run of empty reads */
static string
Admin_NextLine(filestream fh)
{
	for (int blanks = 0i; blanks < 16i; blanks++) {
		string line = fgets(fh);

		if (STRING_SET(line)) {
			return (line);
		}
	}

	return ("");
}

static bool
Admin_FileExists(string fileName)
{
	filestream fh = fopen(fileName, FILE_READ);

	if (fh < 0) {
		return (false);
	}

	fclose(fh);
	return (true);
}

static void
Admin_AddMap(string mapID, string title)
{
	if (!STRING_SET(mapID) || g_adminMapCount >= ADMIN_MAXENTRIES) {
		return;
	}

	for (int i = 0i; i < g_adminMapCount; i++) {
		if (g_adminMapIDs[i] == mapID) {
			return;
		}
	}

	if (Admin_FileExists(sprintf("maps/%s.bsp", mapID)) == false) {
		return;
	}

	g_adminMapIDs[g_adminMapCount] = strzone(mapID);
	g_adminMapNames[g_adminMapCount] = strzone(STRING_SET(title) ? sprintf("%s (%s)", title, mapID) : mapID);
	g_adminMapCount++;
}

static void
Admin_AddMode(string modeID, string title)
{
	if (!STRING_SET(modeID) || g_adminModeCount >= ADMIN_MAXENTRIES) {
		return;
	}

	modeID = strtolower(modeID);

	for (int i = 0i; i < g_adminModeCount; i++) {
		if (g_adminModeIDs[i] == modeID) {
			return;
		}
	}

	if (Admin_FileExists(sprintf("progs/%s.dat", modeID)) == false) {
		return;
	}

	g_adminModeIDs[g_adminModeCount] = strzone(modeID);
	g_adminModeNames[g_adminModeCount] = strzone(STRING_SET(title) ? title : modeID);
	g_adminModeCount++;
}

static void
Admin_ReadLists(void)
{
	filestream fh;
	string line;

	if (g_adminListsRead) {
		return;
	}

	g_adminListsRead = true;
	g_adminMapCount = 0i;
	g_adminModeCount = 0i;

	/* map <id> "<title>" / ruleset <ID> "<title>" [<map>] */
	fh = fopen("scripts/lobby.txt", FILE_READ);
	if (fh >= 0) {
		for (line = Admin_NextLine(fh); STRING_SET(line); line = Admin_NextLine(fh)) {
			int c = (int)tokenize_console(line);

			if (c < 2i || substring(argv(0), 0, 2) == "//") {
				continue;
			}

			if (argv(0) == "map") {
				Admin_AddMap(argv(1), argv(2));
			} else if (argv(0) == "ruleset") {
				Admin_AddMode(argv(1), argv(2));
			}
		}
		fclose(fh);
	}

	/* the map cycle's maps (the lqdm set) */
	fh = fopen("mapcycle.txt", FILE_READ);
	if (fh >= 0) {
		for (line = Admin_NextLine(fh); STRING_SET(line); line = Admin_NextLine(fh)) {
			if (tokenize_console(line) >= 1 && substring(argv(0), 0, 2) != "//") {
				Admin_AddMap(argv(0), "");
			}
		}
		fclose(fh);
	}

	/* rules the lobby list leaves out but this install ships */
	Admin_AddMode("deathmatch", "Deathmatch");
	Admin_AddMode("teamdm", "Team Deathmatch");
	Admin_AddMode("lastmanstanding", "Last Man Standing");
	Admin_AddMode("domination", "Domination");
	Admin_AddMode("duel", "Duel");
	Admin_AddMode("freezetag", "Freeze Tag");
	Admin_AddMode("archstiletto", "Archstiletto");
}

static void
Admin_ReadPlayers(void)
{
	int slots = Util_GetMaxPlayers();

	if (slots <= 0i) {
		slots = 32i;
	}

	for (int i = 0i; i < g_adminPlayerCount; i++) {
		strunzone(g_adminPlayerNames[i]);
	}
	g_adminPlayerCount = 0i;

	for (int i = 0i; i < slots && g_adminPlayerCount < ADMIN_MAXENTRIES; i++) {
		string playerName = getplayerkeyvalue(i, "name");

		if (!STRING_SET(playerName)) {
			continue;
		}

		g_adminPlayerNames[g_adminPlayerCount] = strzone(playerName);
		g_adminPlayerBot[g_adminPlayerCount] = (getplayerkeyvalue(i, "*bot") == "1");
		g_adminPlayerCount++;
	}
}

/* the current game type, as g_gametype names it (serverinfo carries it on
   servers that publish it; the host can read its own cvar) */
static string
Admin_CurrentMode(void)
{
	string mode = serverkey("g_gametype");

	if (!STRING_SET(mode) && isserver()) {
		mode = cvar_string("g_gametype");
	}

	return (STRING_SET(mode) ? mode : "?");
}

/* the console may only see plain names: no quotes or line breaks */
static bool
Admin_SafeWord(string text)
{
	if (!STRING_SET(text)) {
		return (false);
	}
	if (strstrofs(text, "\"") >= 0 || strstrofs(text, ";") >= 0 || strstrofs(text, "\n") >= 0) {
		return (false);
	}
	return (true);
}

/* -------------------------------------------------------------------------
 * The window
 * ------------------------------------------------------------------------- */

static vguiWindow g_adminWindow;
static vguiList g_adminList;
static vguiScrollBar g_adminScroll;
static vguiLabel g_adminStatus;
static vguiLabel g_adminKeyHint;
static vguiButton g_adminTabButtons[3];
static vguiButton g_adminActionButton;
static vguiButton g_adminRestartButton;
static vguiButton g_adminExtra1Button;
static vguiButton g_adminExtra2Button;
static vguiButton g_adminYesButton;
static vguiButton g_adminNoButton;
static int g_adminTab;
static bool g_adminHostMode;	/* true: host menu; false: call a vote */

static void Admin_Refresh(void);

static void
Admin_SetStatus(string text)
{
	g_adminStatus.SetTitle(text);
}

static string g_adminListText[ADMIN_MAXENTRIES];
static int g_adminListCount;

static void
Admin_ListAdd(string text)
{
	if (g_adminListCount >= ADMIN_MAXENTRIES) {
		return;
	}
	g_adminListText[g_adminListCount] = strzone(text);
	g_adminListCount++;
}

static void
Admin_FillList(void)
{
	/* the list keeps references: keep our own copies alive */
	for (int i = 0i; i < g_adminListCount; i++) {
		strunzone(g_adminListText[i]);
	}
	g_adminListCount = 0i;

	switch (g_adminTab) {
	case ADMINTAB_MAPS:
		for (int i = 0i; i < g_adminMapCount; i++) {
			Admin_ListAdd(g_adminMapIDs[i] == mapname ? strcat("^3", g_adminMapNames[i], " (now)") : g_adminMapNames[i]);
		}
		break;
	case ADMINTAB_MODES:
		for (int i = 0i; i < g_adminModeCount; i++) {
			Admin_ListAdd(g_adminModeIDs[i] == Admin_CurrentMode() ? strcat("^3", g_adminModeNames[i], " (now)") : g_adminModeNames[i]);
		}
		break;
	case ADMINTAB_PLAYERS:
		Admin_ReadPlayers();
		for (int i = 0i; i < g_adminPlayerCount; i++) {
			Admin_ListAdd(g_adminPlayerBot[i] ? strcat(g_adminPlayerNames[i], " (bot)") : g_adminPlayerNames[i]);
		}
		break;
	}

	/* vguiList holds a fixed number of rows, set before adding any */
	g_adminList.RemoveAllItems();
	g_adminList.SetItemCount(g_adminListCount > 0i ? g_adminListCount : 1i);
	for (int i = 0i; i < g_adminListCount; i++) {
		g_adminList.AddItem(g_adminListText[i]);
	}
	if (g_adminListCount == 0i) {
		g_adminList.AddItem("^8(nothing here)");
	}

	g_adminList.SetSelected(-1i);
	g_adminList.SetOffset(0i, FALSE);
	g_adminScroll.SetValue(0i);
	g_adminScroll.SetMax(g_adminList.GetMaxVisibleItems());
}

static void
Admin_SelectTab(int tab)
{
	g_adminTab = tab;

	switch (tab) {
	case ADMINTAB_MAPS:
		g_adminActionButton.SetTitle(g_adminHostMode ? "Change map" : "Vote map");
		break;
	case ADMINTAB_MODES:
		g_adminActionButton.SetTitle(g_adminHostMode ? "Set game type" : "Vote game type");
		break;
	case ADMINTAB_PLAYERS:
		g_adminActionButton.SetTitle(g_adminHostMode ? "Kick player" : "Vote kick");
		break;
	}

	Admin_FillList();
	Admin_Refresh();
}

static void Admin_TabMaps(void) { Admin_SelectTab(ADMINTAB_MAPS); }
static void Admin_TabModes(void) { Admin_SelectTab(ADMINTAB_MODES); }
static void Admin_TabPlayers(void) { Admin_SelectTab(ADMINTAB_PLAYERS); }

static void
Admin_Close(void)
{
	g_adminWindow.Hide();
}

/* run on our own console (host) or ask the server for a vote (anyone) */
static void
Admin_Do(string hostCommand, string voteCommand)
{
	if (g_adminHostMode) {
		if (!isserver()) {
			Admin_SetStatus("^1Only the host can do that.");
			return;
		}
		localcmd(strcat(hostCommand, "\n"));
		Admin_SetStatus(strcat("^2Done: ", hostCommand));
	} else {
		localcmd(sprintf("callvote %s\n", voteCommand));
		Admin_SetStatus(strcat("^2Vote called: ", voteCommand, " (F1 yes, F2 no)"));
	}
}

static void
Admin_Action(void)
{
	int selected = g_adminList.GetSelected();

	if (selected < 0i) {
		Admin_SetStatus("^1Pick something from the list first.");
		return;
	}

	switch (g_adminTab) {
	case ADMINTAB_MAPS:
		if (selected >= g_adminMapCount) {
			return;
		}
		Admin_Do(sprintf("map %s", g_adminMapIDs[selected]),
			sprintf("map %s", g_adminMapIDs[selected]));
		break;
	case ADMINTAB_MODES:
		if (selected >= g_adminModeCount) {
			return;
		}
		/* g_gametype takes effect when a map loads: load this one again */
		Admin_Do(sprintf("g_gametype %s; map %s", g_adminModeIDs[selected], mapname),
			sprintf("gametype %s", g_adminModeIDs[selected]));
		break;
	case ADMINTAB_PLAYERS:
		if (selected >= g_adminPlayerCount) {
			return;
		}
		if (Admin_SafeWord(g_adminPlayerNames[selected]) == false) {
			Admin_SetStatus("^1That name can't be typed on the console.");
			return;
		}
		if (g_adminHostMode && g_adminPlayerBot[selected]) {
			Admin_Do(sprintf("sv kickBot \"%s\"", g_adminPlayerNames[selected]), "");
		} else {
			Admin_Do(sprintf("kick \"%s\"", g_adminPlayerNames[selected]),
				sprintf("kick \"%s\"", g_adminPlayerNames[selected]));
		}
		/* the list catches up a moment later */
		break;
	}
}

static void
Admin_Restart(void)
{
	Admin_Do(sprintf("map %s", mapname), "restart");
}

/* host: add a bot / vote: next map */
static void
Admin_Extra1(void)
{
	if (g_adminHostMode) {
		Admin_Do("sv addBot", "");
	} else {
		Admin_Do("", "nextmap");
	}
}

/* host: remove a bot */
static void
Admin_Extra2(void)
{
	if (g_adminHostMode) {
		Admin_Do("sv kickBot", "");
	}
}

static void
Admin_VoteYes(void)
{
	localcmd("vote yes\n");
	Admin_SetStatus("^2You voted yes.");
}

static void
Admin_VoteNo(void)
{
	localcmd("vote no\n");
	Admin_SetStatus("^1You voted no.");
}

static void
Admin_ScrollUpdate(void)
{
	g_adminScroll.SetValue(g_adminList.GetOffset());
}

static void
Admin_ListUpdate(void)
{
	g_adminList.SetOffset(g_adminScroll.GetValue(), FALSE);
}

/* buttons and title for the job the window is doing now */
static void
Admin_Refresh(void)
{
	bool voteRunning = STRING_SET(serverkey("vote_cmd"));

	if (g_adminHostMode) {
		g_adminWindow.SetTitle("Host Menu");
		g_adminRestartButton.SetTitle("Restart map");
		g_adminExtra1Button.SetTitle("Add bot");
		g_adminExtra2Button.SetTitle("Remove bot");
		g_adminExtra2Button.Show();
		g_adminYesButton.Hide();
		g_adminNoButton.Hide();
		g_adminKeyHint.SetTitle("^8Up/Down: pick   Enter/A: do it   Tab, LB/RB: tabs\n^81/X: restart   2/Y: add bot   3: remove bot   Esc/B: close");
	} else {
		g_adminWindow.SetTitle("Call a Vote");
		g_adminRestartButton.SetTitle("Vote restart");
		g_adminExtra1Button.SetTitle("Vote next map");
		g_adminExtra2Button.Hide();
		g_adminYesButton.Show();
		g_adminNoButton.Show();
		g_adminKeyHint.SetTitle("^8Up/Down: pick   Enter/A: vote   Tab, LB/RB: tabs\n^81/X: vote restart   2/Y: vote next map   Esc/B: close");
	}

	if (voteRunning) {
		Admin_SetStatus(sprintf("Vote: %s  (yes %s, no %s)", serverkey("vote_cmd"),
			serverkey("votes_y"), serverkey("votes_n")));
	} else {
		Admin_SetStatus(sprintf("%s on %s", Admin_CurrentMode(), mapname));
	}
}

static vguiButton
Admin_MakeButton(string title, vector pos, vector size, void(void) func)
{
	vguiButton btn = spawn(vguiButton);
	btn.SetTitle(title);
	btn.SetPos(pos);
	btn.SetSize(size);
	btn.SetFunc(func);
	g_adminWindow.Add(btn);
	return (btn);
}

static void
Admin_Open(bool hostMode)
{
	static bool initialized;

	Admin_ReadLists();

	if (!initialized) {
		initialized = true;

		g_adminWindow = spawn(vguiWindow);
		g_adminWindow.SetTitle("Host Menu");
		g_adminWindow.SetSize([480, 412]);
		g_adminWindow.SetStyleMask(vguiWindowStyleDefault);
		g_adminWindow.SetIcon("gfx/icon16/server");
		g_uiDesktop.Add(g_adminWindow);

		g_adminTabButtons[0] = Admin_MakeButton("Maps", [16, 36], [104, 24], Admin_TabMaps);
		g_adminTabButtons[1] = Admin_MakeButton("Game types", [124, 36], [104, 24], Admin_TabModes);
		g_adminTabButtons[2] = Admin_MakeButton("Players", [232, 36], [104, 24], Admin_TabPlayers);

		g_adminList = spawn(vguiList);
		g_adminList.SetPos([16, 68]);
		g_adminList.SetSize([304, 256]);
		g_adminList.CallOnScroll(Admin_ScrollUpdate);
		g_adminWindow.Add(g_adminList);

		g_adminScroll = spawn(vguiScrollBar);
		g_adminScroll.SetPos([320, 68]);
		g_adminScroll.SetLength(256);
		g_adminScroll.SetMin(0);
		g_adminScroll.SetStep(1);
		g_adminScroll.CallOnChange(Admin_ListUpdate);
		g_adminWindow.Add(g_adminScroll);

		g_adminActionButton = Admin_MakeButton("Change map", [348, 68], [116, 24], Admin_Action);
		g_adminRestartButton = Admin_MakeButton("Restart map", [348, 100], [116, 24], Admin_Restart);
		g_adminExtra1Button = Admin_MakeButton("Add bot", [348, 132], [116, 24], Admin_Extra1);
		g_adminExtra2Button = Admin_MakeButton("Remove bot", [348, 164], [116, 24], Admin_Extra2);
		g_adminYesButton = Admin_MakeButton("Yes (F1)", [348, 236], [116, 24], Admin_VoteYes);
		g_adminNoButton = Admin_MakeButton("No (F2)", [348, 268], [116, 24], Admin_VoteNo);
		Admin_MakeButton("Close", [348, 300], [116, 24], Admin_Close);

		g_adminStatus = spawn(vguiLabel);
		g_adminStatus.SetPos([16, 336]);
		g_adminStatus.SetSize([448, 40]);
		g_adminWindow.Add(g_adminStatus);

		g_adminKeyHint = spawn(vguiLabel);
		g_adminKeyHint.SetPos([16, 372]);
		g_adminKeyHint.SetSize([448, 32]);
		g_adminWindow.Add(g_adminKeyHint);
	}

	g_adminHostMode = hostMode;
	Admin_SelectTab(ADMINTAB_MAPS);
	g_adminWindow.Show();
	g_adminWindow.Focus();	/* in front of a team or hero picker */
	g_adminWindow.SetPos((g_vidsize / 2) - (g_adminWindow.GetSize() / 2));
}

/* -------------------------------------------------------------------------
 * Keyboard and controller. VGUI buttons only take mouse clicks, so the
 * window reads its own keys (CSQC_InputEvent asks first while it is open):
 *   Up/Down, D-pad, left stick   move the list highlight
 *   Enter, A                     the main button (Change map, Vote kick...)
 *   Tab, Left/Right, LB/RB       next or previous tab
 *   1 / X                        Restart map (or Vote restart)
 *   2 / Y                        Add bot (or Vote next map)
 *   3                            Remove bot (host)
 *   Escape, B, Menu (Start)      close
 * F1/F2 (vote yes/no) are binds and pass through.
 * ------------------------------------------------------------------------- */

static void
Admin_MoveSelection(int dir)
{
	int count = g_adminListCount;

	if (count <= 0i) {
		return;
	}

	int sel = g_adminList.GetSelected();

	if (sel < 0i) {
		sel = (dir > 0i) ? 0i : count - 1i;
	} else {
		sel += dir;
	}

	if (sel < 0i) {
		sel = 0i;
	} else if (sel >= count) {
		sel = count - 1i;
	}

	g_adminList.SetSelected(sel);

	/* keep the highlight in view */
	int rows = (int)floor(g_adminList.GetSize()[1] / 20);
	int offset = g_adminList.GetOffset();

	if (sel < offset) {
		offset = sel;
	} else if (rows > 0i && sel >= offset + rows) {
		offset = sel - rows + 1i;
	}

	g_adminList.SetOffset(offset, FALSE);
	g_adminScroll.SetValue(g_adminList.GetOffset());
}

static void
Admin_CycleTab(int dir)
{
	int tab = g_adminTab + dir;

	if (tab < ADMINTAB_MAPS) {
		tab = ADMINTAB_PLAYERS;
	} else if (tab > ADMINTAB_PLAYERS) {
		tab = ADMINTAB_MAPS;
	}

	Admin_SelectTab(tab);
}

bool
VGUI_Admin_Visible(void)
{
	return (g_adminWindow && g_adminWindow.Visible());
}

void
VGUI_Admin_Close(void)
{
	if (VGUI_Admin_Visible()) {
		g_adminWindow.Hide();
	}
}

/* a key went down while the window is open: true when the window used it */
bool
VGUI_Admin_KeyDown(float key)
{
	if (!VGUI_IsFrontWindow(g_adminWindow)) {
		return (false);
	}

	switch (key) {
	case K_ESCAPE:
	case K_GP_B:
	case K_GP_MENU:
	case K_GP_VIEW:
		Admin_Close();
		return (true);
	case K_ENTER:
	case K_KP_ENTER:
	case K_GP_A:
		Admin_Action();
		return (true);
	case K_UPARROW:
	case K_GP_DPAD_UP:
	case K_GP_LTHUMB_UP:
		Admin_MoveSelection(-1i);
		return (true);
	case K_DOWNARROW:
	case K_GP_DPAD_DOWN:
	case K_GP_LTHUMB_DOWN:
		Admin_MoveSelection(1i);
		return (true);
	case K_PGUP:
		Admin_MoveSelection(-8i);
		return (true);
	case K_PGDN:
		Admin_MoveSelection(8i);
		return (true);
	case K_TAB:
	case K_RIGHTARROW:
	case K_GP_RSHOULDER:
	case K_GP_DPAD_RIGHT:
	case K_GP_LTHUMB_RIGHT:
		Admin_CycleTab(1i);
		return (true);
	case K_LEFTARROW:
	case K_GP_LSHOULDER:
	case K_GP_DPAD_LEFT:
	case K_GP_LTHUMB_LEFT:
		Admin_CycleTab(-1i);
		return (true);
	case '1':
	case K_GP_X:
		Admin_Restart();
		return (true);
	case '2':
	case K_GP_Y:
		Admin_Extra1();
		return (true);
	case '3':
		Admin_Extra2();
		return (true);
	}

	return (false);
}

/* menu_hostmenu: the host's admin window; anyone else gets the vote window */
void
VGUI_HostMenu(void)
{
	if (!isserver()) {
		print("Only the host can use the Host Menu: call a vote instead.\n");
		Admin_Open(false);
		Admin_SetStatus("^1Only the host can use the Host Menu. Call a vote instead.");
		return;
	}

	Admin_Open(true);
}

/* menu_callvote */
void
VGUI_CallVote(void)
{
	Admin_Open(false);
}

/* the pause pages show Host Menu only to the host: they read this cvar */
void
VGUI_HostMenu_Publish(void)
{
	static float published = -1;
	float host = isserver() ? 1 : 0;

	if (host != published) {
		published = host;
		localcmd(sprintf("set _cl_host %d\n", host));
	}
}
