/* Justice Task Force HUD: sokky's Figma HUD (layout/coop/hud.xml) drawn as
   an embedded Panorama view. This progs gathers what the HUD shows and
   posts it to the view as JSON:

     "state"   health, armour, ammo, the hero (from the "*herohud" infokey
               the rules set), teammates ("*mate"), the wave (serverinfo
               coop_wave, coop_left) and a key prompt ("*prompt"); posted
               only when it changed
     "feed"    one kill, from HUD_Obituary
     "notice"  wave news, from serverinfo coop_notice ("seq|text")

   Weapon selection, pickup notices, damage arrows and the crosshair are
   still the Half-Life HUD's (classic.qc). cg_hudPanorama 0, or an engine
   without Panorama (FTE), draws the Half-Life HUD instead. The "phud 1"
   userinfo tells the rules to stop sending the hero text line and wave
   centerprints this HUD replaces. */

float(string layout, float flags) ui_open = #0:ui_open;
void(float view) ui_close = #0:ui_close;
float(float view) ui_isopen = #0:ui_isopen;
void(float view, string event, string json) ui_post = #0:ui_post;
void(float view, vector pos, vector size, float alpha) ui_draw = #0:ui_draw;

#define JTF_LAYOUT "layout/coop/hud.xml"
#define JTF_EMBED 2

var float autocvar_cg_hudPanorama = 1;

float g_jtfView;
bool g_jtfTried;
string g_jtfLast;
float g_jtfNoticeSeq;
bool g_jtfNoticeInit;
string g_jtfPhud;

string
Jtf_Str(string s)
{
	s = strreplace("\\", "\\\\", s);
	s = strreplace("\"", "\\\"", s);
	s = strreplace("\n", "\\n", s);
	return strcat("\"", s, "\"");
}

/* the view, opened once; false when the engine has no Panorama */
bool
Jtf_Ready(void)
{
	if (g_jtfView && ui_isopen(g_jtfView)) {
		return (true);
	}

	if (g_jtfTried) {
		return (false);
	}

	/* the menu registers the faces (coop/src/menu/main.qc m_init); a view
	   opened before that keeps the fallback face's look */
	if (!cvar("_coop_uifonts")) {
		return (false);
	}

	g_jtfTried = true;

	if (!checkbuiltin(ui_open) || !checkbuiltin(ui_draw)) {
		return (false);
	}

	g_jtfView = ui_open(JTF_LAYOUT, JTF_EMBED);
	return (g_jtfView) ? true : false;
}

/* tell the rules which HUD we draw, when that changes */
void
Jtf_SetPhud(string value)
{
	if (g_jtfPhud == value) {
		return;
	}

	g_jtfPhud = value;
	localcmd(sprintf("setinfo phud %s\n", value));
}

string
Jtf_WeaponName(string def)
{
	string name = entityDef.GetString(def, "inv_name");

	if (name == "") {
		return (def);
	}

	return (name);
}

/* the bound key for a command, "" for none */
string
Jtf_KeyFor(string command)
{
	/* the controller's button when it was used last (the engine's
	   in_lastdevice), else the first keyboard or mouse key */
	bool pad = cvar("in_lastdevice") ? true : false;
	float c = tokenize(findkeysforcommandex(command));

	/* the engine answers with key names ("E MOUSE2 GP_Y") */
	for (float i = 0; i < c; i++) {
		string name = argv(i);
		float key = stringtokeynum(name);
		bool padKey = (key >= 768 && key <= 831) ? true : false;

		if (key > 0 && padKey == pad) {
			return (strtoupper(name));
		}
	}

	return ("");
}

/* the respawn bar: {"frac":0..1,"left":seconds,"survival":bool}, or null
   when alive. From "*respawn" (coop/src/rules/hud_info.qc); the progress
   is worked out here each frame against the client's clock, in 1% steps
   so the state is posted at most a hundred times a respawn */
string
Jtf_Respawn(void)
{
	string r = getplayerkeyvalue(player_localnum, "*respawn");

	if (r == "") {
		return ("null");
	}

	if (r == "survival") {
		return ("{\"frac\":0,\"left\":0,\"survival\":true}");
	}

	tokenize(r);
	float down = stof(argv(0));
	float delay = max(0.01f, stof(argv(1)));
	float frac = bound(0, (time - down) / delay, 1);

	frac = floor(frac * 100) / 100;
	return (sprintf("{\"frac\":%s,\"left\":%d,\"survival\":false}", ftos(frac),
		ceil(max(0, delay - (time - down)))));
}

/* the Use key; on a controller that's the west button, "+coop_x" */
string
Jtf_UseKey(void)
{
	string key = Jtf_KeyFor("+use");

	if (key == "") {
		key = Jtf_KeyFor("+coop_x");
	}

	return (key);
}

/* the keys for the letters in the hero status line ("[G] Vent"): what the
   player presses for each, by what it runs. On a controller ability 1 and
   2 are the shoulders and engage both (coop/src/menu/main.qc) */
string
Jtf_HeroKeys(void)
{
	bool pad = cvar("in_lastdevice") ? true : false;
	string g = Jtf_KeyFor("impulse 22"), x = Jtf_KeyFor("impulse 23"), z = Jtf_KeyFor("impulse 24");

	if (pad) {
		string lb = Jtf_KeyFor("+coop_lb"), rb = Jtf_KeyFor("+coop_rb");

		if (g == "") g = lb;
		if (x == "") x = rb;
		if (z == "" && lb != "" && rb != "") z = strcat(lb, "+", rb);
	}

	return (sprintf("{\"C\":%s,\"G\":%s,\"X\":%s,\"Z\":%s,\"V\":%s,\"pad\":%s}",
		Jtf_Str(Jtf_KeyFor("impulse 21")), Jtf_Str(g), Jtf_Str(x), Jtf_Str(z),
		Jtf_Str(Jtf_KeyFor("impulse 25")), pad ? "true" : "false"));
}

/* "name|energy|energymax|barrier|cap|form|status|formline|static|dynamic"
   from the rules (coop/src/rules/hero_abilities.qc Hero_Hud) */
string
Jtf_Hero(__out string staticName, __out string dynamicName)
{
	string s = player.GetString("*herohud");
	staticName = dynamicName = "";

	if (s == "" || tokenizebyseparator(s, "|") < 10) {
		return ("null");
	}

	string json = sprintf("{\"name\":%s,\"energy\":%s,\"emax\":%s,\"barrier\":%s,\"cap\":%s,",
		Jtf_Str(argv(0)), argv(1), argv(2), argv(3), argv(4));
	json = strcat(json, sprintf("\"form\":%s,\"status\":%s,\"formLine\":%s,", argv(5), Jtf_Str(argv(6)),
		Jtf_Str(argv(7))));
	staticName = (argv(8) != "") ? Jtf_WeaponName(argv(8)) : "";
	dynamicName = (argv(9) != "") ? Jtf_WeaponName(argv(9)) : "";
	return (strcat(json, sprintf("\"staticName\":%s,\"dynamicName\":%s,\"ecost\":%d}", Jtf_Str(staticName),
		Jtf_Str(dynamicName), stof(serverkey("coop_engageCost")))));
}

var string(void) Jtf_PlayerDistances;
bool g_jtfDistancesLinked;
float g_jtfMateDist[32];
bool g_jtfMateUsed[32];

/* the three closest of everyone else: "*mate" is "health|state", state a alive,
   d down, x dead or spectating */
string
Jtf_Team(void)
{
	/* only the three closest teammates (sokky 2026-11-02): distances from
	   the client (src/client/nameplates.qc), for the ones we can see; the
	   rest count as far away, in player order */
	if (!g_jtfDistancesLinked) {
		g_jtfDistancesLinked = true;
		Jtf_PlayerDistances = externvalue(0, "Nameplates_PlayerDistances");
	}

	for (float i = 0; i < 32; i++) {
		g_jtfMateDist[i] = 1000000 + i;
		g_jtfMateUsed[i] = false;
	}

	if (Jtf_PlayerDistances) {
		float n = tokenize(Jtf_PlayerDistances());

		for (float t = 0; t + 1 < n; t += 2) {
			float slot = stof(argv(t));

			if (slot >= 0 && slot < 32) {
				g_jtfMateDist[slot] = stof(argv(t + 1));
			}
		}
	}

	string json = "";

	for (float shown = 0; shown < 3; shown++) {
		float best = -1;

		for (float i = 0; i < 32; i++) {
			if (i == player_localnum || g_jtfMateUsed[i]) {
				continue;
			}

			if (getplayerkeyvalue(i, "name") == "" || getplayerkeyvalue(i, "*mate") == "") {
				continue;
			}

			/* (QC's || evaluates both sides: no [best] while it's -1) */
			if (best < 0) {
				best = i;
			} else if (g_jtfMateDist[i] < g_jtfMateDist[best]) {
				best = i;
			}
		}

		if (best < 0) {
			break;
		}

		g_jtfMateUsed[best] = true;
		tokenizebyseparator(getplayerkeyvalue(best, "*mate"), "|");
		json = strcat(json, (json == "") ? "" : ",", sprintf("{\"name\":%s,\"hp\":%d,\"st\":%s,\"cad\":%d}",
			Jtf_Str(getplayerkeyvalue(best, "name")), stof(argv(0)), Jtf_Str(argv(1)),
			stof(getplayerkeyvalue(best, "*cadence"))));
	}

	return (strcat("[", json, "]"));
}

/* the client's target ID (src/client/nameplates.qc) as a teammate card:
   null, or name, health, max, status, the Cadence buff and the fade */
var string(void) Jtf_TargetIDInfo;
bool g_jtfTargetIDLinked;

string
Jtf_TargetID(void)
{
	if (!g_jtfTargetIDLinked) {
		g_jtfTargetIDLinked = true;
		Jtf_TargetIDInfo = externvalue(0, "Nameplates_TargetIDInfo");
	}

	if (!Jtf_TargetIDInfo) {
		return ("null");
	}

	string info = Jtf_TargetIDInfo();

	if (info == "") {
		return ("null");
	}

	float bar = strstrofs(info, "|");
	string name = substring(info, bar + 1, -1);
	tokenize(substring(info, 0, bar));
	float ent = stof(argv(1));
	float hp = stof(argv(2));
	float maxHp = max(1, stof(argv(3)));
	float cad = (ent >= 1 && ent <= 32) ? stof(getplayerkeyvalue(ent - 1, "*cadence")) : 0;

	/* fade in steps, so the state isn't reposted every frame */
	return (sprintf("{\"name\":%s,\"hp\":%d,\"max\":%d,\"cad\":%d,\"a\":%g}", Jtf_Str(name), hp, maxHp, cad,
		rint(stof(argv(0)) * 10) / 10));
}

string g_jtfPromptAt;

void
Jtf_Post(void)
{
	string staticName, dynamicName;
	string hero = Jtf_Hero(staticName, dynamicName);
	string title = weapon.GetTitle();
	bool noAmmo = (weapon.AmmoRequired() == false) ? true : false;
	float held = 0;
	string left = serverkey("coop_left");
	string prompt = player.GetString("*prompt");
	string json;

	if (!weapon.IsValid()) {
		title = "";
	}

	if (title != "" && title == staticName) {
		held = 1;
	} else if (title != "" && title == dynamicName) {
		held = 2;
	}

	json = sprintf("{\"hp\":%d,\"ar\":%d,\"weapon\":%s,\"clip\":%i,\"clipSize\":%i,\"reserve\":%i,",
		max(0, player.GetHealth()), player.GetArmor(), Jtf_Str(title), weapon.GetClip(), weapon.GetClipSize(),
		weapon.GetAmmo1());
	json = strcat(json, sprintf("\"noAmmo\":%s,\"held\":%d,\"hero\":%s,", noAmmo ? "true" : "false", held, hero));
	json = strcat(json, sprintf("\"wave\":%d,\"left\":%d,\"team\":%s,\"prompt\":%s,\"promptKey\":%s,\"keys\":%s}",
		stof(serverkey("coop_wave")), (left == "") ? -1 : stof(left), Jtf_Team(), Jtf_Str(prompt),
		Jtf_Str(Jtf_UseKey()), Jtf_HeroKeys()));
	json = strcat(substring(json, 0, strlen(json) - 1), sprintf(",\"respawn\":%s,\"fireKey\":%s,", Jtf_Respawn(),
		Jtf_Str(Jtf_KeyFor("+attack"))));
	/* Choir's Cadence: how strongly it buffs us (0-3), and on a Choir how
	   many teammates it buffs (-1 when we aren't one) */
	string cadN = player.GetString("*cadenceN");
	json = strcat(json, sprintf("\"cadence\":%d,\"cadenceN\":%d,\"tid\":%s,", stof(player.GetString("*cadence")),
		(cadN == "") ? -1 : stof(cadN), Jtf_TargetID()));
	/* the objective panel: "score|points" (hud_info.qc) and the XPM
	   plugin's "xp|need|level|max|rank|medals|max medals" */
	json = strcat(json, sprintf("\"stats\":%s,\"xpm\":%s}", Jtf_Str(player.GetString("*stats")),
		Jtf_Str(player.GetString("*xpm"))));

	if (json != g_jtfLast) {
		if (g_jtfLast) {
			strunzone(g_jtfLast);
		}

		g_jtfLast = strzone(json);
		ui_post(g_jtfView, "state", json);
	}

	/* a pickup's prompt is a callout on the item (sokky 2026-11-02): where
	   the item is on screen, in the view's layout units (900 rows tall),
	   posted when it moves; null puts the prompt back under the crosshair */
	string at = player.GetString("*promptAt");
	string atJson = "null";

	if (at != "") {
		vector onScreen = project(stov(at));

		if (onScreen[2] > 0) {
			float units = 900 / screen.Size()[1];
			atJson = sprintf("{\"x\":%d,\"y\":%d}", rint((onScreen[0] - screen.Mins()[0]) * units),
				rint((onScreen[1] - screen.Mins()[1]) * units));
		}
	}

	if (atJson != g_jtfPromptAt) {
		if (g_jtfPromptAt) {
			strunzone(g_jtfPromptAt);
		}

		g_jtfPromptAt = strzone(atJson);
		ui_post(g_jtfView, "promptAt", atJson);
	}

	/* wave news: "seq|Wave 3: 12 monsters" */
	string notice = serverkey("coop_notice");

	if (!g_jtfNoticeInit) {
		/* the one already up when we joined isn't news */
		g_jtfNoticeInit = true;
		g_jtfNoticeSeq = (notice != "") ? stof(substring(notice, 0, strstrofs(notice, "|"))) : 0;
	} else if (notice != "") {
		float seq = stof(substring(notice, 0, strstrofs(notice, "|")));

		if (seq != g_jtfNoticeSeq) {
			string text = substring(notice, strstrofs(notice, "|") + 1, -1);
			string sub = "";
			float split = strstrofs(text, ": ");

			if (split < 0) {
				split = strstrofs(text, "! ");
			}

			if (split >= 0) {
				sub = substring(text, split + 2, -1);
				text = substring(text, 0, split);
			}

			ui_post(g_jtfView, "notice", sprintf("{\"title\":%s,\"sub\":%s,\"hold\":3}", Jtf_Str(text),
				Jtf_Str(sub)));

			g_jtfNoticeSeq = seq;
		}
	}
}

/* the Half-Life feedback kept on top of the Panorama HUD: damage arrows and
   tint, pickup notices, weapon selection, crosshair (valve/src/hud/hud.qc) */
void
Jtf_DrawFeedback(vector hud_mins, vector hud_size)
{
	vector pos;

	HLHUD_UpdateTimers(player.GetHealth(), player.GetArmor(), weapon.GetClip(), weapon.GetAmmo1(),
		weapon.GetAmmo2());
	HLHUD_DamageNotifyDraw(hud_mins, hud_size);

	/* pickup notices stack up from just above the Panorama weapon slots
	   (hud.css .weapons: about 270 of the layout's 900 rows) */
	pos = g_hudMins + [g_hudRes[0] - 192, 0];
	pos[1] = screen.Mins()[1] + screen.Size()[1] * (1 - 270 / 900);
	HLHUD_ItemNotify_Draw(pos);
	HLHUD_AmmoNotify_Draw(pos);

	if (g_damageAlpha > 0.0f) {
		vector center = hud_mins + (hud_size / 2);
		vector playerPosition = player.GetCameraPosition();
		vector playerAngle = player.GetCameraAngles();
		playerPosition[2] = g_damageLocation[2];
		vector rel_pos = vectorNormalize(g_damageLocation - playerPosition);
		float fw = vectorDot(rel_pos, anglesToForward(playerAngle));
		float rt = vectorDot(rel_pos, anglesToRight(playerAngle));
		float fw_alpha = fabs(fw) * g_damageAlpha;
		float rt_alpha = fabs(rt) * g_damageAlpha;

		if (fw > 0.25f) {
			draw.Pic(center + [-64,-102], g_damage_spr_t, [128,48], [1,1,1], fw_alpha, DRAWFLAG_ADDITIVE);
		} else if (fw < -0.25f) {
			draw.Pic(center + [-64,70], g_damage_spr_b, [128,48], [1,1,1], fw_alpha, DRAWFLAG_ADDITIVE);
		}

		if (rt > 0.25f) {
			draw.Pic(center + [70,-64], g_damage_spr_r, [48,128], [1,1,1], rt_alpha, DRAWFLAG_ADDITIVE);
		} else if (rt < -0.25f) {
			draw.Pic(center + [-102,-64], g_damage_spr_l, [48,128], [1,1,1], rt_alpha, DRAWFLAG_ADDITIVE);
		}

		if (autocvar_cg_damageFill > 0.0) {
			vector finalColor = [1,1,1];
			finalColor[1] = finalColor[2] = 1.0 - (g_damageAlpha * autocvar_cg_damageFill);
			draw.Pic(screen.Mins(), "fade_modulate", screen.Size(), finalColor, 1.0, DRAWFLAG_NORMAL);
		}

		g_damageAlpha -= clframetime;
	}

	weaponSelectionHUD.Draw();

	if (g_spriteCrosshair != -1i) {
		atlasPic.DrawCrosshair(g_spriteCrosshair);
	}

	HLHUD_ClampTimers();
}

void
HUD_Draw(void)
{
	if (!autocvar_cg_hudPanorama || !Jtf_Ready()) {
		Jtf_SetPhud("0");
		HLHUD_ClassicDraw();
		return;
	}

	Jtf_SetPhud("1");
	g_hudMins = screen.HUDMins();
	g_hudRes = screen.HUDSize();
	Jtf_Post();

	/* the Figma frame is the whole screen, not Half-Life's 4:3 HUD area */
	ui_draw(g_jtfView, screen.Mins(), screen.Size(), 1.0f);
	Jtf_DrawFeedback(g_hudMins, g_hudRes);
}

void
HUD_Obituary(string targetName, string attackerName, string weaponDef, string meansOfDeath)
{
	HLHUD_ClassicObituary(targetName, attackerName, weaponDef, meansOfDeath);

	if (!autocvar_cg_hudPanorama || !g_jtfView) {
		return;
	}

	string me = getplayerkeyvalue(player_localnum, "name");
	bool self = wordInString(meansOfDeath, "self");
	string attacker = self ? "" : attackerName;
	string weaponName = (weaponDef != "") ? Jtf_WeaponName(weaponDef) : "";

	ui_post(g_jtfView, "feed", sprintf("{\"a\":%s,\"w\":%s,\"v\":%s,\"you\":%s}", Jtf_Str(attacker),
		Jtf_Str(weaponName), Jtf_Str(targetName), (attacker == me || targetName == me) ? "true" : "false"));
}

/* ---- the controller's west button: Use or reload, by what's ahead --------
   bound to "+coop_x" (coop/src/menu/main.qc, pad layout 3). It uses when
   the server says Use would do something here ("*usable",
   coop/src/rules/hud_info.qc: a teammate to revive, a gun to take, a
   button or door), else it reloads; its release ends whichever began */
string g_coopXHeld;

void
HUD_Init(void)
{
	HLHUD_ClassicInit();
	registercommand("+coop_x");
	registercommand("-coop_x");
}

bool
HUD_ConsoleCommand(string commandString)
{
	tokenize_console(commandString);

	switch (argv(0)) {
	case "+coop_x":
		if (g_coopXHeld != "") {
			return (true);	/* key repeat */
		}

		g_coopXHeld = (getplayerkeyvalue(player_localnum, "*usable") == "1") ? "use" : "reload";
		localcmd(sprintf("+%s\n", g_coopXHeld));
		return (true);
	case "-coop_x":
		if (g_coopXHeld != "") {
			localcmd(sprintf("-%s\n", g_coopXHeld));
			g_coopXHeld = "";
		}
		return (true);
	}

	return HLHUD_ClassicConsoleCommand(commandString);
}
