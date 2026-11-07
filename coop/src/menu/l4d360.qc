/*
 * Copyright (c) 2026 sokky
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

/* Left 4 Dead 360 menus for co-op (sokky 2026-11-07: "full L4D menus
   everywhere").

   The title and pause menus are sokky's QuakeC BaseMod renderer
   (src/menu-vgui/l4d360/title.qc), drawing Valve's Xbox frames
   mainmenu.res and ingamemainmenu.res as authored. This file only maps
   their commands onto co-op: the pages behind them (Play, Hero, Find
   servers, Options, Vote) and the shop stay the co-op Panorama views,
   restyled by styles/coop/l4d360.css when the view gets "l4d" in its
   context.

   The Xbox resources are Valve's and not in git: resource/l4d360/ (scheme,
   ui/ layouts, locale, fonts, images) and sound/l4d360/ come from sokky's
   private pack. Without them, or with ui_l4d360 0, the JTF menus are used.

   Commands the frames send, and what co-op does with them:
   title  BtnCoOp flyout: QuickMatchCoOp, PlayCoopWithAnyone -> Find servers,
          PlayCoopWithFriends -> Play. BtnVersus becomes Hero (no versus in
          co-op). SoloPlay -> Play. Options flyout -> Options. X (SeeAll) ->
          Find servers. Quit asks first.
   pause  ReturnToGame closes. BtnInviteAFriend becomes Requisition (the
          shop) and BtnStatsAndAchievements Hero (the shop's Hero tab).
          Vote flyout: ReturnToLobby becomes Next Map, RestartScenario and
          ChangeDifficulty call votes, BootPlayer is off (no kick vote).
          ExitToMainMenu asks first. GoIdle is off. */

/* the parts of Nuclide's VGUI the renderer leans on */
class vguiControl
{
	void vguiControl(void);
};
void vguiControl::vguiControl(void) {}

vector g_vidsize;

bool
fileExists(string path)
{
	filestream f = fopen(path, FILE_READ);

	if (f < 0)
		return false;

	fclose(f);
	return true;
}

/* sokky's renderer, shared with the stock VGUI menu */
#include "../../../src/menu-vgui/l4d360/resource.qc"
#include "../../../src/menu-vgui/l4d360/title.qc"

string g_l4dConfirm;	/* the command a yes/no notice runs: "quit", "disconnect" */
bool g_l4dPause;	/* the pause frame is up */
string g_l4dPageTab;	/* the shop tab to open when the shop list arrives */

void L4D_OpenPage(string page);	/* main.qc: a co-op Panorama page over the frame */
void L4D_ClosePause(void);

bool
L4D_On(void)
{
	return (autocvar_ui_l4d360 != 0 && g_l4dLoaded) ? true : false;
}

bool
L4D_HasModal(void)
{
	return false;
}

void
L4D_Notice(string title, string message)
{
	g_l4dNoticeTitle = title;
	g_l4dNoticeText = message;
	g_l4dNotice = true;
	g_l4dPressed = -1;
	g_l4dConfirm = "";
}

void
L4D_Ask(string title, string message, string action)
{
	L4D_Notice(title, message);
	g_l4dConfirm = action;
}

/* a button by name: new label, new command, or off */
void
L4D_Rewire(string field, int scope, string label, string command)
{
	int i = L4D_FindButton(field, scope);

	if (i < 0)
		return;

	if (label != "")
		g_l4dButtons[i].text = label;
	if (command != "")
		g_l4dButtons[i].command = command;
}

void
L4D_Help(string field, int scope, string help)
{
	int i = L4D_FindButton(field, scope);

	if (i >= 0)
		g_l4dButtons[i].helpText = g_l4dButtons[i].disabledHelpText = help;
}

void
L4D_Disable(string field, int scope)
{
	int i = L4D_FindButton(field, scope);

	if (i >= 0)
		g_l4dButtons[i].available = false;
}

int
L4D_FlyoutIndex(string name)
{
	for (int i = 0; i < g_l4dFlyoutCount; i++)
		if (g_l4dFlyouts[i].fieldName == name)
			return i;
	return -1;
}

void
L4D_FrameLoaded(string frame)
{
	if (frame == "mainmenu.res") {
		L4D_Rewire("BtnVersus", -1, "HERO", "CoopHero");
		L4D_Help("BtnVersus", -1, "Pick the hero you play as.");
		return;
	}

	if (frame == "ingamemainmenu.res") {
		L4D_Rewire("BtnInviteAFriend", -1, "REQUISITION", "CoopShop");
		L4D_Rewire("BtnStatsAndAchievements", -1, "HERO", "CoopHeroTab");
		L4D_Help("BtnInviteAFriend", -1, "Buy weapons and gear with your points.");
		L4D_Help("BtnStatsAndAchievements", -1, "Change your hero. It takes effect when you respawn.");
		L4D_Disable("BtnGoIdle", -1);
		/* both have tabPosition 1; the last (Go Idle, off here) would win */
		L4D_SetFocus(L4D_FindButton("BtnReturnToGame", -1), false);

		int vote = L4D_FlyoutIndex("FlmVoteFlyout");
		L4D_Rewire("BtnReturnToLobby", vote, "Next Map", "CoopVoteNextMap");
		L4D_Disable("BtnBootPlayer", vote);
	}
}

void
L4D_RunCommand(string command)
{
	g_l4dLastAction = command;

	switch (command) {
	/* title */
	case "QuickMatchCoOp":
	case "PlayCoopWithAnyone":
	case "SeeAll":
		L4D_OpenPage("servers");
		break;
	case "PlayCoopWithFriends":
	case "SoloPlay":
		L4D_OpenPage("play");
		break;
	case "CoopHero":
		L4D_OpenPage("hero");
		break;
	case "AudioVideo":
	case "OpenOptionsDialog":
		L4D_OpenPage("settings");
		break;
	case "Controller":
		L4D_OpenPage("controller");
		break;
	case "QuitGame":
		L4D_Ask(L4D_Text("#L4D360UI_MainMenu_Quit"),
			"Are you sure you want to quit?", "quit");
		break;
	case "Storage":
		L4D_Notice(L4D_Text("#L4D360UI_Storage"),
			"Co-op saves its settings on this computer. There is no storage device to pick.");
		break;
	case "StatsAndAchievements":
		L4D_Notice(L4D_Text("#L4D360UI_MainMenu_StatsAndAchievements"),
			"Co-op keeps no statistics or achievements yet.");
		break;
	case "WatchMovie":
	case "DeveloperCommentary":
		L4D_Notice(L4D_Text("#L4D360UI_MainMenu_Extras"),
			"This isn't available in co-op.");
		break;
	case "Credits":
		L4D_Notice(L4D_Text("#L4D360UI_Extras_Credits"),
			"Justice Task Force: sokky. Menu layouts: Left 4 Dead (Valve). Framework: Nuclide (Vera Visions). Engine: Bulwark.");
		break;
	case "EnableSplitscreen":
	case "DisableSplitscreen":
		L4D_Notice(L4D_Text("#L4D360UI_MainMenu_EnableSplitscreen"),
			"Press Start on another controller to join as a guest.");
		break;

	/* pause */
	case "ReturnToGame":
		L4D_ClosePause();
		break;
	case "CoopShop":
		L4D_ClosePause();
		localcmd("cmd shop\n");
		break;
	case "CoopHeroTab":
		L4D_ClosePause();
		g_l4dPageTab = "hero";
		localcmd("cmd shop\n");
		break;
	case "CoopVoteNextMap":
		L4D_ClosePause();
		localcmd("callvote nextmap 0\n");
		break;
	case "RestartScenario":
		L4D_ClosePause();
		localcmd("callvote map_restart 0\n");
		break;
	case "ChangeDifficulty":
		L4D_OpenPage("vote");
		break;
	case "ExitToMainMenu":
		L4D_Ask(L4D_Text("#L4D360UI_InGameMainMenu_ExitToMainMenu"),
			"Are you sure you want to leave this game?", "disconnect");
		break;
	default:
		print(sprintf("L4D360: co-op has no use for %s\n", command));
		L4D_Sound("invalid");
		break;
	}
}

/* the title frame, or the pause frame over a game */
void
L4D_ShowFrame(bool inGame)
{
	if (!L4D_LoadFrame(inGame ? "ingamemainmenu.res" : "mainmenu.res"))
		return;

	g_l4dBackdrop = !inGame;
	g_l4dPause = inGame;
	g_l4dOverGame = inGame;
	g_l4dOpen = -1;
	g_l4dPressed = -1;
	setkeydest(2);
}

void
L4D_ClosePause(void)
{
	g_l4dPause = false;
	g_l4dOverGame = false;
	g_l4dNotice = false;
	g_l4dOpen = -1;
	setkeydest(0);
}

/* behind a Panorama page: the title's street, or the game dimmed, and the
   footer's prompts */
void
L4D_DrawUnderPage(bool inGame)
{
	L4D_Layout();

	if (inGame)
		drawfill([0,0], g_vidsize, [0,0,0], 0.55, 0);
	else
		L4D_DrawBackdrop();

	float y = L4D_Coord(g_l4dFooter.Get("FooterPanel/ypos","r100"), g_l4dExtent[1]);
	float tall = g_l4dFooter.Number("FooterPanel/tall", 70);
	L4D_Fill([0, y + tall * 0.25], [g_l4dExtent[0], tall * 0.75], [0,0,0], 225/255);
	L4D_FooterButton([100, y + 58], 'A', "#L4D360UI_Select", false);
	L4D_FooterButton([225, y + 58], 'B', "#L4D360UI_Back", false);
}

/* input for a frame; false when it should go to the game */
bool
L4D_FrameInput(float event, float key, float character, float device)
{
	bool down = (event == IE_KEYDOWN) ? true : false;
	bool accept = (key == K_ENTER || key == K_GP_A || key == K_SPACE) ? true : false;
	bool back = (key == K_ESCAPE || key == K_GP_B) ? true : false;

	/* a yes/no notice: A runs it, B keeps the menu */
	if (g_l4dNotice && g_l4dConfirm != "" && down && (accept || back || key == K_MOUSE1)) {
		string action = g_l4dConfirm;
		g_l4dNotice = false;
		g_l4dConfirm = "";
		g_l4dPressed = -1;

		if (back) {
			L4D_Sound("back");
		} else {
			L4D_Sound("accept");
			if (action == "disconnect")
				L4D_ClosePause();
			localcmd(strcat(action, "\n"));
		}
		return true;
	}

	/* the pause frame: Escape, B or Start at its root goes back to the game */
	if (g_l4dPause && !g_l4dNotice && g_l4dOpen < 0 && down &&
		(back || key == K_GP_MENU)) {
		L4D_Sound("back");
		L4D_ClosePause();
		return true;
	}

	return L4D_Input(event, key, character, device);
}

/* the confirmation's own footer prompts over the frame's */
void
L4D_DrawFrame(void)
{
	L4D_Draw();

	if (g_l4dNotice && g_l4dConfirm != "") {
		float y = L4D_Coord(g_l4dFooter.Get("FooterPanel/ypos","r100"), g_l4dExtent[1]);
		float tall = g_l4dFooter.Number("FooterPanel/tall", 70);
		L4D_Fill([0, y + tall * 0.25], [g_l4dExtent[0], tall * 0.75], [0,0,0], 1);
		L4D_FooterButton([100, y + 58], 'A', "#GameUI_Yes", false);
		L4D_FooterButton([225, y + 58], 'B', "#GameUI_No", false);
	}
}
