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

/* Co-op front end: the menus are Panorama views (coop/panorama/), drawn
   and laid out by Bulwark. This progs only opens and closes them and
   answers what a script can't find out itself: the map list, the LAN
   servers and key bindings. Scripts read cvars themselves
   (Bulwark.Query("cvar:name")) and run commands with Bulwark.Cmd.

   Views: layout/coop/menu.xml is the title menu and, in a game, the pause
   menu; the script is told which with the "context" event.
   layout/coop/loadout.xml is the shop menu: a Shop tab with the points
   shop and a Skills tab with the XP mod's skills. The server sends both
   as menu_coop commands (coop/src/rules/shop.qc, coop/src/plugins/xpm.qc).
   The shop list opens the view, the skills are kept for their tab, and
   "menu_coop loadout_open <tab>" opens it on a tab. Buying is
   "cmd buy <n>" and spending a skill point "cmd menuselect <n>". */

/* Bulwark's view builtins, bound by name (docs/spec/ui.md) */
float(string layout, float flags) ui_open = #0:ui_open;
void(float view) ui_close = #0:ui_close;
float(float view) ui_isopen = #0:ui_isopen;
void(float view, string event, string json) ui_post = #0:ui_post;

typedef float bool;
#define true 1
#define false 0

#define UI_INPUT 1
#define MENU_LAYOUT "layout/coop/menu.xml"
#define LOADOUT_LAYOUT "layout/coop/loadout.xml"

float g_view;
bool g_inGame;		/* the open view was opened in a game (pause menu) */
string g_mapsJson;
bool g_browsing;
float g_browseNext;
float g_serverCount;
vector g_screen;
float g_panelView;	/* the shop menu */
string g_panelJson;	/* the list being received, zoned */
string g_shopJson;	/* the last lists, zoned, for when the view opens */
string g_skillsJson;

/* ---- JSON --------------------------------------------------------------- */

string
Json_Str(string s)
{
	s = strreplace("\\", "\\\\", s);
	s = strreplace("\"", "\\\"", s);
	s = strreplace("\n", "\\n", s);
	return strcat("\"", s, "\"");
}

/* ---- data the scripts ask for ------------------------------------------- */

/* every map on the search path, co-op maps first */
void
Maps_Build(void)
{
	string coopMaps = "";
	string otherMaps = "";
	searchhandle h = search_begin("maps/*.bsp", SB_CASEINSENSITIVE | SB_NAMESORT, TRUE);
	float n = search_getsize(h);

	for (float i = 0; i < n; i++) {
		string name = search_getfilename(h, i);
		name = substring(name, 5, strlen(name) - 9);	/* maps/<name>.bsp */

		if (name == "" || substring(name, 0, 1) == "_")
			continue;

		if (substring(name, 0, 5) == "coop_" || substring(name, 0, 3) == "sc_") {
			coopMaps = strcat(coopMaps, (coopMaps == "") ? "" : ",", Json_Str(name));
		} else {
			otherMaps = strcat(otherMaps, (otherMaps == "") ? "" : ",", Json_Str(name));
		}
	}

	search_end(h);

	if (g_mapsJson)
		strunzone(g_mapsJson);

	g_mapsJson = strzone(sprintf("{\"coop\":[%s],\"other\":[%s]}", coopMaps, otherMaps));
}

/* the keys bound to each command in a space-separated list */
string
Binds_Json(string commands)
{
	string json = "";
	float n = tokenize(commands);

	for (float i = 0; i < n; i++) {
		string command = argv(i);
		string keys = findkeysforcommandex(command);
		json = strcat(json, (json == "") ? "" : ",", Json_Str(command), ":", Json_Str(keys));
		tokenize(commands);
	}

	return strcat("{", json, "}");
}

void
Servers_Refresh(void)
{
	resethostcachemasks();
	sethostcachemaskstring(0, gethostcacheindexforkey("gamedir"), cvar_string("fs_game"), SLIST_TEST_EQUAL);
	sethostcachesort(gethostcacheindexforkey("ping"), FALSE);
	refreshhostcache(TRUE);
	resorthostcache();
	g_browsing = true;
	g_browseNext = 0;
	g_serverCount = -1;
}

string
Servers_Json(void)
{
	float fName = gethostcacheindexforkey("name");
	float fAddress = gethostcacheindexforkey("cname");
	float fMap = gethostcacheindexforkey("map");
	float fPing = gethostcacheindexforkey("ping");
	float fPlayers = gethostcacheindexforkey("numhumans");
	float fMax = gethostcacheindexforkey("maxplayers");
	float count = gethostcachevalue(SLIST_HOSTCACHEVIEWCOUNT);
	string json = "";

	for (float i = 0; i < count; i++) {
		json = strcat(json, (json == "") ? "" : ",",
			sprintf("{\"name\":%s,\"address\":%s,\"map\":%s,", Json_Str(gethostcachestring(fName, i)),
				Json_Str(gethostcachestring(fAddress, i)), Json_Str(gethostcachestring(fMap, i))),
			sprintf("\"ping\":%d,\"players\":%d,\"max\":%d}", gethostcachenumber(fPing, i),
				gethostcachenumber(fPlayers, i), gethostcachenumber(fMax, i)));
	}

	return strcat("[", json, "]");
}

/* ---- the view ----------------------------------------------------------- */

bool
Menu_IsOpen(void)
{
	return (g_view && ui_isopen(g_view)) ? true : false;
}

void
Menu_Close(void)
{
	if (Menu_IsOpen())
		ui_close(g_view);

	g_view = 0;
	g_browsing = false;
	setkeydest(0);
}

void
Menu_Open(void)
{
	bool inGame = (clientstate() == 2) ? true : false;

	if (Menu_IsOpen() && g_inGame == inGame)
		return;

	Menu_Close();
	g_view = ui_open(MENU_LAYOUT, UI_INPUT);
	g_inGame = inGame;

	if (!g_view) {
		print(sprintf("^1menu: can't open %s\n", MENU_LAYOUT));
		return;
	}

	setkeydest(2);
	ui_post(g_view, "context", sprintf("{\"ingame\":%s}", inGame ? "true" : "false"));
}

/* ---- panels the server fills: the points shop and the XP skill menu ---- */

/* A server sends a panel as menu_coop <kind>_begin, <kind>_item lines and
   <kind>_end (coop/src/rules/shop.qc, coop/src/plugins/xpm.qc). One panel
   is open at a time. */

void
Panel_Close(void)
{
	if (g_panelView && ui_isopen(g_panelView))
		ui_close(g_panelView);

	if (g_panelView && !Menu_IsOpen())
		setkeydest(0);

	g_panelView = 0;
}

bool
Panel_IsOpen(void)
{
	return (g_panelView && ui_isopen(g_panelView)) ? true : false;
}

void
Panel_Append(string s)
{
	string old = g_panelJson;
	g_panelJson = strzone(strcat(old, s));

	if (old)
		strunzone(old);
}

void
Panel_Begin(string json)
{
	if (g_panelJson)
		strunzone(g_panelJson);

	g_panelJson = strzone(json);
}

/* the comma before an item, none after the opening bracket */
string
Panel_Comma(void)
{
	return (substring(g_panelJson, strlen(g_panelJson) - 1, 1) == "[") ? "" : ",";
}

/* opens the shop menu if it isn't up, on a tab, with the lists it has */
void
Panel_Open(string tab)
{
	if (clientstate() != 2)
		return;

	if (Menu_IsOpen())
		Menu_Close();

	if (!Panel_IsOpen()) {
		g_panelView = ui_open(LOADOUT_LAYOUT, UI_INPUT);

		if (!g_panelView) {
			print(sprintf("^1menu: can't open %s\n", LOADOUT_LAYOUT));
			return;
		}

		if (g_shopJson)
			ui_post(g_panelView, "shop", g_shopJson);
		if (g_skillsJson)
			ui_post(g_panelView, "skills", g_skillsJson);
	}

	setkeydest(2);

	if (tab != "")
		ui_post(g_panelView, "tab", Json_Str(tab));
}

/* a list is complete: keep it, and show it if the menu is up */
void
Panel_End(string kind)
{
	string json;

	if (!g_panelJson)
		return;

	Panel_Append("]}");
	json = g_panelJson;
	g_panelJson = __NULL__;

	if (kind == "shop") {
		if (g_shopJson)
			strunzone(g_shopJson);
		g_shopJson = json;
	} else {
		if (g_skillsJson)
			strunzone(g_skillsJson);
		g_skillsJson = json;
	}

	/* the shop list is the answer to "cmd shop", so it opens the menu;
	   skills also come on level-up and only update it */
	if (kind == "shop" && !Panel_IsOpen())
		Panel_Open("shop");
	else if (Panel_IsOpen())
		ui_post(g_panelView, kind, json);
}

/* menu_coop shop_begin <points> "<closed>" "<message>",
   shop_item <n> <category> "<name>" <price> <state>, shop_end;
   menu_coop skills_begin <points> <level> "<rank>",
   skills_item <n> "<name>" <level> <max>, skills_end;
   menu_coop loadout_open <shop|skills>, panel_close */
void
Panel_Command(void)
{
	switch (argv(1)) {
	case "shop_begin":
		Panel_Begin(sprintf("{\"points\":%d,\"closed\":%s,\"message\":%s,\"items\":[",
			stof(argv(2)), Json_Str(argv(3)), Json_Str(argv(4))));
		break;
	case "shop_item":
		if (g_panelJson)
			Panel_Append(sprintf("%s{\"id\":%d,\"category\":%s,\"name\":%s,\"price\":%d,\"state\":%d}",
				Panel_Comma(), stof(argv(2)), Json_Str(argv(3)), Json_Str(argv(4)), stof(argv(5)), stof(argv(6))));
		break;
	case "shop_end":
		Panel_End("shop");
		break;
	case "skills_begin":
		Panel_Begin(sprintf("{\"points\":%d,\"level\":%d,\"rank\":%s,\"skills\":[",
			stof(argv(2)), stof(argv(3)), Json_Str(argv(4))));
		break;
	case "skills_item":
		if (g_panelJson)
			Panel_Append(sprintf("%s{\"id\":%d,\"name\":%s,\"level\":%d,\"max\":%d}",
				Panel_Comma(), stof(argv(2)), Json_Str(argv(3)), stof(argv(4)), stof(argv(5))));
		break;
	case "skills_end":
		Panel_End("skills");
		break;
	case "loadout_open":
		Panel_Open(argv(2));
		break;
	case "panel_close":
		Panel_Close();
		break;
	}
}

string g_bindsWanted;
float g_bindsFrames;

/* a script asks for something with Bulwark.Send(action, arg) */
void
Menu_UIAction(float view, string action, string arg)
{
	if (view == g_panelView) {
		if (action == "buy")
			localcmd(sprintf("cmd buy %d\n", stof(arg)));
		else if (action == "spend")
			localcmd(sprintf("cmd menuselect %d\n", stof(arg)));
		else if (action == "close")
			Panel_Close();
		return;
	}

	switch (action) {
	case "maps":
		Maps_Build();
		ui_post(view, "maps", g_mapsJson);
		break;
	case "binds":
		/* a bind the script just sent is still in the command buffer, so
		   answer once it has run, two frames from now */
		g_bindsWanted = arg;
		g_bindsFrames = 2;
		break;
	case "servers":
		Servers_Refresh();
		break;
	case "stopservers":
		g_browsing = false;
		break;
	case "close":
		/* only a pause menu closes; the title menu stays up */
		if (clientstate() == 2)
			Menu_Close();
		break;
	default:
		print(sprintf("menu: unknown action %s(%s)\n", action, arg));
	}
}

/* ---- entry points ------------------------------------------------------- */

void
m_init(void)
{
	registercommand("menu_coop");

	/* the menu's faces: Tahoma when the game has one, Nimbus Sans otherwise */
	localcmd("ui_font Nimbus fonts/nimbus/NimbusSanL-Reg.otf 400\n");
	localcmd("ui_font Nimbus fonts/nimbus/NimbusSanL-Bol.otf 700\n");

	if (whichpack("fonts/tahoma.ttf") != "")
		localcmd("ui_font Tahoma fonts/tahoma.ttf 400\n");

	if (whichpack("fonts/tahomabd.ttf") != "")
		localcmd("ui_font Tahoma fonts/tahomabd.ttf 700\n");

	/* the shop's key, the first time: B, if it's free */
	if (findkeysforcommandex("cmd shop") == "" && getkeybind(stringtokeynum("B")) == "")
		localcmd("bind B \"cmd shop\"\n");
}

void
m_shutdown(void)
{
	Panel_Close();
	Menu_Close();
}

void
m_toggle(float wantmode)
{
	if (wantmode == 0) {
		if (clientstate() == 2)
			Menu_Close();
	} else if (wantmode == 1 || !Menu_IsOpen()) {
		Menu_Open();
	} else if (clientstate() == 2) {
		Menu_Close();
	}
}

void
m_draw(vector screensize)
{
	g_screen = screensize;

	if (clientstate() != 2) {
		/* out of a game the title menu is always up */
		drawfill([0,0], screensize, [0,0,0], 1.0, 0);

		if (!Menu_IsOpen() || g_inGame)
			Menu_Open();
		Panel_Close();
	} else if (Menu_IsOpen() && !g_inGame) {
		/* just joined a game from the title menu */
		Menu_Close();
	}

	if (g_bindsFrames > 0 && --g_bindsFrames == 0 && Menu_IsOpen())
		ui_post(g_view, "binds", Binds_Json(g_bindsWanted));

	if (g_browsing && Menu_IsOpen() && time >= g_browseNext) {
		float count = gethostcachevalue(SLIST_HOSTCACHEVIEWCOUNT);
		g_browseNext = time + 0.5;

		if (count != g_serverCount) {
			g_serverCount = count;
			resorthostcache();
			ui_post(g_view, "servers", Servers_Json());
		}
	}
}

void
m_drawloading(vector screensize, float opaque)
{
	string map = cvar_string("cl_loadmap");
	float progress = bound(0, cvar("cl_loadprogress"), 1);
	vector barSize = [screensize[0] * 0.4, 6];
	vector barPos = [(screensize[0] - barSize[0]) / 2, screensize[1] * 0.6];
	string text = (map != "") ? sprintf("Loading %s", map) : "Connecting...";

	if (Menu_IsOpen())
		Menu_Close();

	drawfill([0,0], screensize, [0,0,0], 1.0, 0);
	drawstring(barPos - [0, 24], text, [16,16], [1, 0.63, 0.1], 1.0, 0);
	drawfill(barPos, barSize, [0.2, 0.2, 0.2], 1.0, 0);
	drawfill(barPos, [barSize[0] * progress, barSize[1]], [1, 0.63, 0.1], 1.0, 0);
}

float
Menu_InputEvent(float evtype, float scanx, float chary, float devid)
{
	/* the open view takes input before this; Escape in a game reaches
	   here when none is open */
	return (Menu_IsOpen()) ? TRUE : FALSE;
}

float
m_consolecommand(string cmd)
{
	tokenize(cmd);

	switch (argv(0)) {
	case "menu_coop":
		if (strstrofs(argv(1), "_") > 0)
			Panel_Command();
		else if (argv(1) == "close")
			Menu_Close();
		else
			Menu_Open();
		return TRUE;
	}

	return FALSE;
}
