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
   layout/coop/loadout.xml is the shop menu: a Hero tab when the server
   has heroes on, a Shop tab with the points shop and a Skills tab with the
   XP mod's skills. The server sends them as menu_coop commands
   (coop/src/rules/heroes.qc, coop/src/rules/shop.qc,
   coop/src/plugins/xpm.qc).
   The shop list opens the view, the skills are kept for their tab, and
   "menu_coop loadout_open <tab>" opens it on a tab. Buying is
   "cmd buy <n>", spending a skill point "cmd menuselect <n>" and picking
   a hero's kit "cmd hero <kit>".

   Heroes can be picked out of a game too, on the title menu's Hero page:
   this progs reads the roster from decls/def/heroes.def itself, and the
   pick is the "hero" cvar, saved in the config and sent to servers as
   userinfo (coop/src/rules/heroes.qc spawns players as it). Both menus
   show the hero in 3D: a script asks for the preview with
   Bulwark.Send("preview", "<kit> <rect>") and this progs draws it each
   frame under the views, so the view leaves that rect see-through. */

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
string g_heroesJson;
bool g_heroSent;	/* the saved hero is in the userinfo */

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

/* ---- the hero roster, read from the defs -------------------------------- */

/* The menu has no def parser, so this reads decls/def/heroes.def itself:
   entityDef blocks of "key" "value" pairs, with inherit. Only the keys the
   menus show are kept. */

#define DEF_MAX 64
#define DEF_KEYS "inherit hero_name hero_role hero_desc hero_kits hero_weight kit_name kit_desc model health pm_walkspeed"
#define HERO_LIST "hero_tank hero_support hero_pointman"

string g_defName[DEF_MAX];
string g_defInfo[DEF_MAX];	/* the kept keys, as an infostring */
float g_defCount;
string g_rosterJson;

void
Defs_Load(string path)
{
	float file = fopen(path, FILE_READ);
	float blank = 0;
	float in = -1;	/* the def being read */
	string pendingName = "";
	string line;

	if (file < 0)
		return;

	/* fgets gives "" for blank lines and at the end alike */
	while (blank < 32) {
		line = fgets(file);

		if (line == "") {
			blank++;
			continue;
		}

		blank = 0;
		float n = tokenize(line);

		for (float i = 0; i < n; i++) {
			string t = argv(i);

			if (substring(t, 0, 2) == "//") {
				break;
			} else if (in < 0 && t == "entityDef" && i + 1 < n) {
				pendingName = argv(++i);
			} else if (in < 0 && t == "{" && pendingName != "" && g_defCount < DEF_MAX) {
				in = g_defCount++;
				g_defName[in] = strzone(pendingName);
				g_defInfo[in] = strzone("");
				pendingName = "";
			} else if (in >= 0 && t == "}") {
				in = -1;
			} else if (in >= 0 && i + 1 < n) {
				string value = argv(++i);

				if (strstrofs(strcat(" ", DEF_KEYS, " "), strcat(" ", t, " ")) >= 0) {
					string old = g_defInfo[in];
					g_defInfo[in] = strzone(infoadd(old, t, value));
					strunzone(old);
				}
			}
		}
	}

	fclose(file);
}

float
Def_Index(string def)
{
	for (float i = 0; i < g_defCount; i++)
		if (g_defName[i] == def)
			return i;

	return -1;
}

/* a key of a def or what it inherits, "" when none has it */
string
Def_Get(string def, string key)
{
	for (float depth = 0; depth < 8; depth++) {
		float i = Def_Index(def);

		if (i < 0)
			return "";

		string value = infoget(g_defInfo[i], key);

		if (value != "")
			return value;

		def = infoget(g_defInfo[i], "inherit");
	}

	return "";
}

string
Def_Name(string def, string key)
{
	string name = Def_Get(def, key);
	return (name != "") ? name : def;
}

/* the roster as the Hero tab's "heroes" event takes it, from the defs, with
   picked as the pick: what a server with heroes on would send, minus who's
   playing what */
void
Roster_Build(string picked)
{
	string list = cvar_string("coop_heroList");
	string heroes[8];
	float heroCount;
	string json;
	float kitCount = 0;

	if (!g_defCount)
		Defs_Load("decls/def/heroes.def");

	if (list == "")
		list = HERO_LIST;

	heroCount = min(tokenize(list), 8);

	for (float h = 0; h < heroCount; h++)
		heroes[h] = argv(h);

	json = "";

	for (float h = 0; h < heroCount; h++) {
		string def = heroes[h];
		float speed = stof(Def_Get(def, "pm_walkspeed"));

		if (Def_Index(def) < 0)
			continue;

		if (speed <= 0)
			speed = cvar("pm_walkspeed") > 0 ? cvar("pm_walkspeed") : 270;

		json = strcat(json, (json == "") ? "" : ",",
			sprintf("{\"type\":\"hero\",\"id\":%d,\"def\":%s,\"name\":%s,", h, Json_Str(def),
				Json_Str(Def_Name(def, "hero_name"))),
			sprintf("\"role\":%s,\"desc\":%s,\"health\":%d,\"speed\":%d,\"full\":0}",
				Json_Str(Def_Get(def, "hero_role")), Json_Str(Def_Get(def, "hero_desc")),
				stof(Def_Get(def, "health")), speed));

		float n = tokenizebyseparator(Def_Get(def, "hero_kits"), ",");

		for (float k = 0; k < n; k++) {
			string kit = argv(k);
			json = strcat(json, ",", sprintf("{\"type\":\"kit\",\"id\":%d,\"hero\":%d,\"def\":%s,", kitCount++, h,
				Json_Str(kit)), sprintf("\"name\":%s,\"desc\":%s}", Json_Str(Def_Name(kit, "kit_name")),
				Json_Str(Def_Get(kit, "kit_desc"))));
			tokenizebyseparator(Def_Get(def, "hero_kits"), ",");
		}
	}

	if (g_rosterJson)
		strunzone(g_rosterJson);

	g_rosterJson = strzone(sprintf("{\"on\":1,\"current\":\"\",\"picked\":%s,\"message\":\"\",\"items\":[%s]}",
		Json_Str(picked), json));
}

/* saves the hero picked, for this game and the next */
void
Hero_Save(string kit)
{
	if (strstrofs(kit, "\"") >= 0 || strstrofs(kit, "\\") >= 0 || strstrofs(kit, ";") >= 0)
		return;

	localcmd(sprintf("seta hero \"%s\"\nsetinfo hero \"%s\"\n", kit, kit));
	g_heroSent = true;
}

/* the saved hero goes out with the userinfo, once the config that has it
   has run: before m_init when a game is started from the command line,
   after it otherwise */
void
Hero_SendSaved(void)
{
	if (g_heroSent || cvar_string("hero") == "")
		return;

	g_heroSent = true;
	Hero_Save(cvar_string("hero"));
}

/* ---- the 3D hero preview ------------------------------------------------ */

/* Drawn in m_draw, before the views, so a view shows it through a part it
   leaves see-through. The rect is either fractions of the screen
   ("screen x y w h") or design units at the 1080-line height from the
   screen's centre ("center x y w h"). */

float(string name) pv_getmodelindex = #0:getmodelindex;
void() pv_clearscene = #0:clearscene;
void(entity e) pv_addentity = #0:addentity;
void() pv_renderscene = #0:renderscene;
float(float property, ...) pv_setproperty = #0:setproperty;
void(string texture, float flags, float is2d) pv_beginpolygon = #0:R_BeginPolygon;
void(vector org, vector st, vector rgb, float alpha) pv_polygonvertex = #0:R_PolygonVertex;
void() pv_endpolygon = #0:R_EndPolygon;

/* the fields addentity reads */
.vector origin;
.vector angles;
.float frame;
.float frame1time;
.float modelindex;

#define VF_DRAWWORLD 19

entity g_preview;
string g_previewModel;
string g_previewAnchor;
vector g_previewPos;
vector g_previewSize;
float g_previewView;	/* the view that asked; it ends with it */
float g_previewStart;
string g_previewUnder;	/* what to draw under it: "dim" for the shop's darkening,
			   "backdrop" for the title menu's backdrop */

void
Preview_Off(void)
{
	if (g_previewModel)
		strunzone(g_previewModel);

	g_previewModel = __NULL__;
	g_previewView = 0;
}

/* "<kit> <screen|center> <x> <y> <w> <h> [dim|backdrop]", or "" to stop */
void
Preview_Set(float view, string arg)
{
	float n = tokenize(arg);
	string model;

	if (n < 6) {
		Preview_Off();
		return;
	}

	if (!g_defCount) {
		Defs_Load("decls/def/heroes.def");
		tokenize(arg);
	}

	model = Def_Get(argv(0), "model");

	if (model == "" || whichpack(model) == "") {
		Preview_Off();
		return;
	}

	if (model != g_previewModel) {
		if (g_previewModel)
			strunzone(g_previewModel);
		g_previewModel = strzone(model);
		g_previewStart = time;
	}

	if (g_previewAnchor)
		strunzone(g_previewAnchor);

	g_previewAnchor = strzone(argv(1));
	g_previewPos = [stof(argv(2)), stof(argv(3))];
	g_previewSize = [stof(argv(4)), stof(argv(5))];
	if (g_previewUnder)
		strunzone(g_previewUnder);
	g_previewUnder = strzone(argv(6));
	g_previewView = view;
}

void
Preview_Draw(void)
{
	vector pos, size;
	float fovY = 30;

	if (!g_previewModel)
		return;

	if (!g_previewView || !ui_isopen(g_previewView)) {
		Preview_Off();
		return;
	}

	if (g_previewAnchor == "center") {
		float scale = g_screen[1] / 1080;
		pos = g_screen * 0.5 + g_previewPos * scale;
		size = g_previewSize * scale;
	} else {
		pos = [g_previewPos[0] * g_screen[0], g_previewPos[1] * g_screen[1]];
		size = [g_previewSize[0] * g_screen[0], g_previewSize[1] * g_screen[1]];
	}

	if (g_previewUnder == "dim") {
		drawfill([0,0], g_screen, [0,0,0], 0.4, 0);
	} else if (g_previewUnder == "backdrop") {
		/* menu.css's .backdrop gradient, corner to corner */
		pv_beginpolygon("$white", 0, true);
		pv_polygonvertex([0, 0], [0, 0], [0.047, 0.047, 0.047], 1);
		pv_polygonvertex([g_screen[0], 0], [1, 0], [0.075, 0.059, 0.031], 1);
		pv_polygonvertex(g_screen, [1, 1], [0.141, 0.094, 0.020], 1);
		pv_polygonvertex([0, g_screen[1]], [0, 1], [0.075, 0.059, 0.031], 1);
		pv_endpolygon();
	}

	if (size[0] < 8 || size[1] < 8)
		return;

	if (!g_preview)
		g_preview = spawn();

	/* model indexes reset when a game starts, so look it up every frame */
	g_preview.modelindex = pv_getmodelindex(g_previewModel);
	g_preview.origin = [0, 0, 0];
	g_preview.angles = [0, 200 + (time - g_previewStart) * 30, 0];
	g_preview.frame = 0;	/* the idle framegroup */
	g_preview.frame1time = time - g_previewStart;

	pv_clearscene();
	pv_setproperty(VF_MIN, pos);
	pv_setproperty(VF_SIZE, size);
	pv_setproperty(VF_FOV, [atan2(tan(fovY * M_PI / 360) * size[0] / size[1], 1) * 360 / M_PI, fovY]);
	pv_setproperty(VF_ORIGIN, [220, 0, 4]);
	pv_setproperty(VF_ANGLES, [0, 180, 0]);
	pv_setproperty(VF_DRAWWORLD, 0);
	pv_addentity(g_preview);
	pv_renderscene();
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
		if (g_heroesJson)
			ui_post(g_panelView, "heroes", g_heroesJson);
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
	} else if (kind == "heroes") {
		if (g_heroesJson)
			strunzone(g_heroesJson);
		g_heroesJson = json;
	} else {
		if (g_skillsJson)
			strunzone(g_skillsJson);
		g_skillsJson = json;
	}

	/* the shop list is the answer to "cmd shop", so it opens the menu;
	   skills also come on level-up and heroes before the shop, and only
	   update it */
	if (kind == "shop" && !Panel_IsOpen())
		Panel_Open("shop");
	else if (Panel_IsOpen())
		ui_post(g_panelView, kind, json);
}

/* menu_coop shop_begin <points> "<closed>" "<message>",
   shop_item <n> <category> "<name>" <price> <state>, shop_end;
   menu_coop skills_begin <points> <level> "<rank>",
   skills_item <n> "<name>" <level> <max>, skills_end;
   menu_coop heroes_begin <on> "<kit now>" "<kit picked>" "<message>",
   heroes_item <n> "<def>" "<name>" "<role>" "<desc>" <health> <speed> <full>,
   heroes_kit <n> <hero> "<def>" "<name>" "<desc>", heroes_end;
   menu_coop loadout_open <hero|shop|skills>, panel_close */
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
	case "heroes_begin":
		Panel_Begin(sprintf("{\"on\":%d,\"current\":%s,\"picked\":%s,\"message\":%s,\"items\":[",
			stof(argv(2)), Json_Str(argv(3)), Json_Str(argv(4)), Json_Str(argv(5))));
		break;
	case "heroes_item":
		if (g_panelJson)
			Panel_Append(strcat(sprintf("%s{\"type\":\"hero\",\"id\":%d,\"def\":%s,\"name\":%s,",
				Panel_Comma(), stof(argv(2)), Json_Str(argv(3)), Json_Str(argv(4))),
				sprintf("\"role\":%s,\"desc\":%s,\"health\":%d,\"speed\":%d,\"full\":%d}",
				Json_Str(argv(5)), Json_Str(argv(6)), stof(argv(7)), stof(argv(8)), stof(argv(9)))));
		break;
	case "heroes_kit":
		if (g_panelJson)
			Panel_Append(sprintf("%s{\"type\":\"kit\",\"id\":%d,\"hero\":%d,\"def\":%s,\"name\":%s,\"desc\":%s}",
				Panel_Comma(), stof(argv(2)), stof(argv(3)), Json_Str(argv(4)), Json_Str(argv(5)), Json_Str(argv(6))));
		break;
	case "heroes_end":
		Panel_End("heroes");
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
		else if (action == "hero") {
			Hero_Save(arg);
			localcmd(sprintf("cmd hero %s\n", arg));
		} else if (action == "preview")
			Preview_Set(view, arg);
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
	case "roster":
		Roster_Build(cvar_string("hero"));
		ui_post(view, "roster", g_rosterJson);
		break;
	case "hero":
		/* the cvar changes when the command buffer runs, after this */
		Hero_Save(arg);
		Roster_Build(arg);
		ui_post(view, "roster", g_rosterJson);
		break;
	case "preview":
		Preview_Set(view, arg);
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

void Menu_DefaultBind(string command, string keys);
void Menu_ForceHeroKeys(void);
void Menu_DefaultBinds(void);

/* first choice, then fallbacks */
#define HERO_KEYS_21 "C H MOUSE4 KP_INS"
#define HERO_KEYS_22 "G J MOUSE5 KP_END"
#define HERO_KEYS_23 "X K N KP_DOWNARROW"
#define HERO_KEYS_24 "Z L M KP_PGDN"
#define HERO_KEYS_25 "V O P KP_LEFTARROW"

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

	/* the default keys wait for the saved config: at m_init it hasn't run
	   yet (it's still in the command buffer), so every key looks free and
	   a bind made now would overwrite the player's own */
	registercommand("coop_defaultbinds");
	registercommand("coop_herokeys");
	localcmd("coop_defaultbinds\n");

	Hero_SendSaved();
}

/* coop_defaultbinds: the keys a new player gets, only where neither the
   command nor the key is taken. The shop: B. The hero abilities
   (coop/src/rules/hero_abilities.qc): C tool, G and X abilities, Z henshin,
   V the form's move. Configs from other games often hold C/G/X/Z (radio,
   drop), so each has fallbacks, tried in order; "coop_herokeys" forces the
   first choices */
void
Menu_DefaultBinds(void)
{
	Menu_DefaultBind("cmd shop", "B");
	Menu_DefaultBind("impulse 21", HERO_KEYS_21);
	Menu_DefaultBind("impulse 22", HERO_KEYS_22);
	Menu_DefaultBind("impulse 23", HERO_KEYS_23);
	Menu_DefaultBind("impulse 24", HERO_KEYS_24);
	Menu_DefaultBind("impulse 25", HERO_KEYS_25);
}

/* binds command to the first free key of keys (space separated), if the
   command has no key yet */
void
Menu_DefaultBind(string command, string keys)
{
	float i, c;
	string key;

	if (findkeysforcommandex(command) != "")
		return;

	c = tokenize(keys);
	for (i = 0; i < c; i++) {
		key = argv(i);
		if (getkeybind(stringtokeynum(key)) == "") {
			localcmd(sprintf("bind %s \"%s\"\n", key, command));
			return;
		}
	}

	print(sprintf("^3coop: no free key for \"%s\" (tried %s); bind one in Options or run coop_herokeys\n", command, keys));
}

/* coop_herokeys: puts the hero keys on C G X Z V, over whatever is there */
void
Menu_ForceHeroKeys(void)
{
	localcmd("bind C \"impulse 21\"\nbind G \"impulse 22\"\nbind X \"impulse 23\"\nbind Z \"impulse 24\"\nbind V \"impulse 25\"\n");
	print("coop: hero keys set to C G X Z V\n");
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
	Hero_SendSaved();

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

	Preview_Draw();

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

	Hero_SendSaved();

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
	case "coop_defaultbinds":
		Menu_DefaultBinds();
		return TRUE;
	case "coop_herokeys":
		Menu_ForceHeroKeys();
		return TRUE;
	}

	return FALSE;
}
