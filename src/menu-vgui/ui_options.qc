/*
 * Copyright (c) 2016-2024 Vera Visions LLC.
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

/*
Options layout metrics follow Half-Life 1 GoldSrc `valve/resource/OptionsSub*.res`
(Steam): 504×460 frame, 12px sheet margin, keyboard list 480×258 at (12,12)
relative to the tab page, bind buttons Defaults / Change / Clear at y=278 with
105×24 and 84×24, mouse checkboxes at x=30 with 24–28px row pitch, CCvarSlider
tracks 36px tall and 420px wide on Audio, footer OK/Cancel/Apply 72×24.

Key list: VControlsListPanel-style behaviors — double-click or Enter starts bind
capture (orange row), Delete clears, Escape cancels capture, arrows/Home/End/
PgUp/PgDn move selection. Section headers use kb_act.lst "blank" rows like
scripts/kb_act.lst in Source (non-selectable, skipped by navigation).
*/

#define UIOPT_NUM_RESOLUTIONS 33

#define UIOPT_KB_MAX 128

#define UIOPT_DLG_W 504
#define UIOPT_DLG_H 460
#define UIOPT_MAR 12
#define UIOPT_TAB_GAP 2
#define UIOPT_TAB_H 24
#define UIOPT_TAB_Y 30
#define UIOPT_TAB_W 78
#define UIOPT_SHEET_TOP 56
#define UIOPT_KB_LIST_W 480
#define UIOPT_KB_LIST_H 258
#define UIOPT_BTN_ROW_Y 334
#define UIOPT_BTN_H 24
#define UIOPT_SLIDER_H 36
#define UIOPT_HINT_Y 362
#define UIOPT_FOOT_Y 418

int g_iOptionsWindowInitialized;

var string autocvar_ui_name = "Player";

int g_uiopt_kb_capture_row;
vguiList g_uiopt_kb_list;

#define OPT_TAB_KEYBOARD 0
#define OPT_TAB_MOUSE 1
#define OPT_TAB_AUDIO 2
#define OPT_TAB_VIDEO 3
#define OPT_TAB_VOICE 4
#define OPT_TAB_MULTIPLAYER 5

static int g_uiopt_restore;
static int g_uiopt_active_tab;
static float g_uiopt_defaults_deadline;

static float s_snap_m_pitch;
static float s_snap_m_filter;
static float s_snap_in_rawinput;
static float s_snap_joystick;
static float s_snap_m_customaccel;
static float s_snap_hud_quickinfo;
static float s_snap_sensitivity;
static float s_snap_volume;
static float s_snap_bgmvolume;
static float s_snap_loadas8bit;
static float s_snap_reverb;
static float s_snap_vid_width;
static float s_snap_vid_height;
static float s_snap_vid_fs;
static float s_snap_gamma;
static float s_snap_brightness;
static float s_snap_voip_test;
static float s_snap_voip_play;
static float s_snap_voip_mic;
static float s_snap_crosshair;
static float s_snap_crosshairsize;
static float s_snap_crosshairalpha;
static string s_snap_crosshaircolor;
static float s_snap_gl_smoothcrosshair;
static string s_snap_player_name;
static string s_snap_res_item;
static float s_snap_kb_k0[UIOPT_KB_MAX];
static float s_snap_kb_k1[UIOPT_KB_MAX];

static vguiWindow winOptions;
static vguiButton btnCancel;
static vguiButton btnApply;
static vguiButton btnOK;
static vguiButton tabKeyboard;
static vguiButton tabMouse;
static vguiButton tabAudio;
static vguiButton tabVideo;
static vguiButton tabVoice;
static vguiButton tabMultiplayer;
static vguiLabel lblKbHdrAction;
static vguiLabel lblKbHdrKey;
static vguiLabel lblKbHint;
static vguiList lstKeyBinds;
static vguiButton btnKbChange;
static vguiButton btnKbClear;
static vguiButton btnKbDefaults;
static vguiLabel lblKbDefaultsWarn;
static vguiCheckbox cbReverseMouse;
static vguiCheckbox cbMouseFilter;
static vguiCheckbox cbRawInput;
static vguiCheckbox cbJoystick;
static vguiCheckbox cbMouseAccel;
static vguiCheckbox cbHudQuickInfo;
static vguiLabel lblSensitivity;
static vguiSlider sldSensitivity;
static vguiLabel lblVolume;
static vguiSlider sldVolume;
static vguiLabel lblMusic;
static vguiSlider sldMusic;
static vguiCheckbox cbHQSound;
static vguiCheckbox cbReverb;
static vguiLabel lblResolution;
static vguiListBox lbxResolution;
static vguiCheckbox cbFullscreen;
static vguiLabel lblGamma;
static vguiSlider sldGamma;
static vguiLabel lblBrightness;
static vguiSlider sldBrightness;
static vguiLabel lblVoiceHelp;
static vguiCheckbox cbVoipTest;
static vguiLabel lblVoipPlay;
static vguiSlider sldVoipPlay;
static vguiLabel lblVoipMic;
static vguiSlider sldVoipMic;
static vguiPic picPlayerModel;
static vguiLabel lblPlayerName;
static vguiTextBox txbPlayerName;
static vguiLabel lblCrosshairHdr;
static vguiCheckbox cbCrosshair;
static vguiLabel lblCrossSize;
static vguiSlider sldCrossSize;
static vguiLabel lblCrossAlpha;
static vguiSlider sldCrossAlpha;
static vguiLabel lblCrossColR;
static vguiLabel lblCrossColG;
static vguiLabel lblCrossColB;
static vguiSlider sldCrossR;
static vguiSlider sldCrossG;
static vguiSlider sldCrossB;
static vguiCheckbox cbSmoothCross;

static int g_kb_count;
static string g_kb_cmd[UIOPT_KB_MAX];
static string g_kb_desc[UIOPT_KB_MAX];

static bool
UI_Options_Kb_RowBindable(int row)
{
	if (row < 0i || row >= g_kb_count)
		return false;
	return STRING_SET(g_kb_cmd[row]);
}

void UI_Options_MarkDirty(void);
static void UI_Options_MatchResolutionList(vguiListBox lbx, float vw, float vh);

static void
UI_Options_KbUnbindRow(int row)
{
	float k0;
	float k1;

	if (row < 0i || row >= g_kb_count)
		return;
	if (!STRING_SET(g_kb_cmd[row]))
		return;

	tokenize(findkeysforcommand(g_kb_cmd[row]));
	k0 = stof(argv(0));
	k1 = stof(argv(1));

	if (k0 >= 0)
		localcmd(sprintf("unbind %s\n", keynumtostring(k0)));

	if (k1 >= 0)
		localcmd(sprintf("unbind %s\n", keynumtostring(k1)));
}

static string
UI_Options_KbKeysForCmd(string cmd)
{
	float k0;
	float k1;

	if (!STRING_SET(cmd))
		return "";

	tokenize(findkeysforcommand(cmd));
	k0 = stof(argv(0));
	k1 = stof(argv(1));

	if (k0 >= 0 && k1 >= 0)
		return sprintf("%s, %s", keynumtostring(k0), keynumtostring(k1));

	if (k0 >= 0)
		return keynumtostring(k0);

	return "";
}

static string
UI_Options_KbFormatRow(int row)
{
	if (row < 0i || row >= g_kb_count)
		return "";

	if (!STRING_SET(g_kb_cmd[row])) {
		return sprintf("^x888%s", g_kb_desc[row]);
	}

	return sprintf("%s  |  %s", g_kb_desc[row],
		UI_Options_KbKeysForCmd(g_kb_cmd[row]));
}

void
UI_Options_KbRefreshRows(void)
{
	int n;

	if (!g_uiopt_kb_list || g_kb_count <= 0i)
		return;

	for (n = 0i; n < g_kb_count; n++)
		g_uiopt_kb_list.SetItem(n, UI_Options_KbFormatRow(n));
}

static void
UI_Options_Kb_ApplyConfigDefaultCfg(filestream fs)
{
	string line;

	localcmd("unbindall\n");
	while ((line = fgets(fs))) {
		if (tokenize_console(line) < 3i)
			continue;
		if (argv(0) != "bind")
			continue;
		if (argv(2) == "+voicerecord") {
			localcmd(sprintf("bind \"%s\" \"+voip\"\n", argv(1)));
		} else {
			localcmd(sprintf("bind \"%s\" \"%s\"\n", argv(1),
				argv(2)));
		}
	}
	fclose(fs);
}

static void
UI_Options_KbLoadIntoList(vguiList lst)
{
	filestream fs;
	string line;
	int n;

	g_kb_count = 0i;
	fs = fopen("scripts/kb_act.lst", FILE_READ);
	if (fs < 0)
		fs = fopen("gfx/shell/kb_act.lst", FILE_READ);
	if (fs < 0)
		fs = fopen("id1/gfx/shell/kb_act.lst", FILE_READ);

	if (fs >= 0) {
		while ((line = fgets(fs))) {
			if (g_kb_count >= UIOPT_KB_MAX)
				break;

			if (tokenize_console(line) != 2)
				continue;

			if (argv(0) == "blank") {
				g_kb_cmd[g_kb_count] = "";
				g_kb_desc[g_kb_count] = argv(1);
				g_kb_count++;
				continue;
			}

			if (argv(0) == "+voicerecord") {
				g_kb_cmd[g_kb_count] = "+voip";
			} else {
				g_kb_cmd[g_kb_count] = argv(0);
			}

			g_kb_desc[g_kb_count] = argv(1);
			g_kb_count++;
		}

		fclose(fs);
	}

	if (g_kb_count <= 0i) {
		g_kb_count = 1i;
		g_kb_cmd[0] = "";
		g_kb_desc[0] = SRC_GAMEUI_MISSING_KB_ACT;
	}

	lst.SetItemCount(g_kb_count);
	g_uiopt_kb_list = lst;

	for (n = 0i; n < g_kb_count; n++)
		lst.SetItem(n, UI_Options_KbFormatRow(n));
}

static void
UI_Options_KbUseDefaults(void)
{
	filestream fs;
	string line;

	g_uiopt_kb_capture_row = -1;

	fs = fopen("cfg/config_default.cfg", FILE_READ);
	if (fs < 0)
		fs = fopen("id1/cfg/config_default.cfg", FILE_READ);
	if (fs >= 0) {
		UI_Options_Kb_ApplyConfigDefaultCfg(fs);
		UI_Options_KbRefreshRows();
		localcmd("cfg_save\n");
		return;
	}

	fs = fopen("gfx/shell/kb_def.lst", FILE_READ);
	if (fs < 0)
		fs = fopen("id1/gfx/shell/kb_def.lst", FILE_READ);
	if (fs < 0) {
		localcmd(sprintf(
			"echo ^2Options:^7 %s\n", SRC_GAMEUI_MISSING_DEFAULTS));
		return;
	}

	localcmd("unbindall\n");

	while ((line = fgets(fs))) {
		if (tokenize_console(line) == 2) {
			if (argv(1) == "+voicerecord") {
				localcmd(sprintf("bind \"%s\" \"+voip\"\n", argv(0)));
			} else {
				localcmd(sprintf("bind \"%s\" \"%s\"\n",
					argv(0), argv(1)));
			}
		}
	}

	fclose(fs);
	UI_Options_KbRefreshRows();
	localcmd("cfg_save\n");
}

void
UI_Options_ResetKeybindCapture(void)
{
	g_uiopt_kb_capture_row = -1;
	if (g_uiopt_kb_list)
		g_uiopt_kb_list.SetCaptureHighlightRow(-1);
}

static bool
UI_Options_KeybindCapture_MouseOverBindList(vector mousePos)
{
	vector winOrigin;

	if (!winOptions || !g_uiopt_kb_list)
		return false;

	winOrigin = winOptions.GetPos();
	return Util_MouseAbove(mousePos,
	    winOrigin + g_uiopt_kb_list.GetPos(), g_uiopt_kb_list.GetSize());
}

float
UI_Options_KeybindCapture(float evtype, float scanx, float chary, float devid)
{
	int row;
	string cmd;
	vector mousePos;

	if (g_uiopt_kb_capture_row < 0)
		return 0;
	if (evtype != IE_KEYDOWN)
		return 0;

	if (!winOptions || !winOptions.Visible()) {
		UI_Options_ResetKeybindCapture();
		return 0;
	}
	if (g_uiopt_active_tab != OPT_TAB_KEYBOARD || !g_uiopt_kb_list ||
	    !g_uiopt_kb_list.Visible()) {
		UI_Options_ResetKeybindCapture();
		return 0;
	}

	if (scanx >= 512 && scanx <= 523)
		return 0;
	if (scanx >= 600 && scanx <= 603)
		return 0;

	mousePos = g_vecMousePos;
	if (scanx >= K_MOUSE1 && scanx <= K_MOUSE5 &&
	    !UI_Options_KeybindCapture_MouseOverBindList(mousePos)) {
		return 0;
	}

	row = g_uiopt_kb_capture_row;

	if (row < 0i || row >= g_kb_count) {
		UI_Options_ResetKeybindCapture();
		return 0;
	}

	cmd = g_kb_cmd[row];

	if (scanx == K_ESCAPE) {
		UI_Options_ResetKeybindCapture();
		return 1;
	}

	if (scanx == K_BACKSPACE) {
		UI_Options_KbUnbindRow(row);
		UI_Options_KbRefreshRows();
		UI_Options_ResetKeybindCapture();
		UI_Options_MarkDirty();
		return 1;
	}

	if (scanx > 0) {
		float old0;
		float old1;

		if (!STRING_SET(cmd)) {
			UI_Options_ResetKeybindCapture();
			return 0;
		}

		tokenize(findkeysforcommand(cmd));
		old0 = stof(argv(0));
		old1 = stof(argv(1));

		UI_Options_KbUnbindRow(row);
		localcmd(sprintf("bind \"%s\" \"%s\"\n",
			keynumtostring(scanx), cmd));
		if (old1 >= 0 && old1 != scanx)
			localcmd(sprintf("bind \"%s\" \"%s\"\n",
				keynumtostring(old1), cmd));

		UI_Options_KbRefreshRows();
		UI_Options_ResetKeybindCapture();
		UI_Options_MarkDirty();
		return 1;
	}

	return 0;
}

void
UI_Options_MarkDirty(void)
{
	if (!g_iOptionsWindowInitialized)
		return;
	if (g_uiopt_restore)
		return;
	btnApply.Enable();
}

void
UI_Options_ClearApplyDisabled(void)
{
	if (!g_iOptionsWindowInitialized)
		return;
	btnApply.Disable();
}

static void
UI_Options_KbCaptureSnap(void)
{
	int n;

	for (n = 0i; n < g_kb_count; n++) {
		if (!STRING_SET(g_kb_cmd[n])) {
			s_snap_kb_k0[n] = -1;
			s_snap_kb_k1[n] = -1;
			continue;
		}
		tokenize(findkeysforcommand(g_kb_cmd[n]));
		s_snap_kb_k0[n] = stof(argv(0));
		s_snap_kb_k1[n] = stof(argv(1));
	}
}

static void
UI_Options_KbRestoreSnap(void)
{
	int n;

	for (n = 0i; n < g_kb_count; n++) {
		if (!STRING_SET(g_kb_cmd[n]))
			continue;
		UI_Options_KbUnbindRow(n);
		if (s_snap_kb_k0[n] >= 0 && STRING_SET(g_kb_cmd[n]))
			localcmd(sprintf("bind \"%s\" \"%s\"\n",
				keynumtostring(s_snap_kb_k0[n]), g_kb_cmd[n]));
		if (s_snap_kb_k1[n] >= 0 && STRING_SET(g_kb_cmd[n]))
			localcmd(sprintf("bind \"%s\" \"%s\"\n",
				keynumtostring(s_snap_kb_k1[n]), g_kb_cmd[n]));
	}
}

static void
UI_Options_CaptureSnapshot(void)
{
	s_snap_m_pitch = cvar("m_pitch");
	s_snap_m_filter = cvar("m_filter");
	s_snap_in_rawinput = cvar("in_rawinput");
	s_snap_joystick = cvar("joystick");
	s_snap_m_customaccel = cvar("m_customaccel");
	s_snap_hud_quickinfo = cvar("hud_quickinfo");
	s_snap_sensitivity = cvar("sensitivity");
	s_snap_volume = cvar("volume");
	s_snap_bgmvolume = cvar("bgmvolume");
	s_snap_loadas8bit = cvar("loadas8bit");
	s_snap_reverb = cvar("s_al_use_reverb");
	s_snap_vid_width = cvar("vid_width");
	s_snap_vid_height = cvar("vid_height");
	s_snap_vid_fs = cvar("vid_fullscreen");
	s_snap_gamma = cvar("gamma");
	s_snap_brightness = cvar("brightness");
	s_snap_voip_test = cvar("cl_voip_test");
	s_snap_voip_play = cvar("snd_voip_play");
	s_snap_voip_mic = cvar("snd_voip_micamp");
	s_snap_crosshair = cvar("crosshair");
	s_snap_crosshairsize = cvar("crosshairsize");
	s_snap_crosshairalpha = cvar("crosshairalpha");
	s_snap_crosshaircolor = cvar_string("crosshaircolor");
	s_snap_gl_smoothcrosshair = cvar("gl_smoothcrosshair");
	s_snap_player_name = STRING_SET(cvar_string("ui_name")) ?
		cvar_string("ui_name") : cvar_string("name");
	s_snap_res_item = lbxResolution.GetItem();
	UI_Options_KbCaptureSnap();
}

static void
UI_Options_RestoreSnapshot(void)
{
	cvar_set("m_pitch", ftos(s_snap_m_pitch));
	cvar_set("m_filter", s_snap_m_filter ? "1" : "0");
	cvar_set("in_rawinput", s_snap_in_rawinput ? "1" : "0");
	cvar_set("joystick", s_snap_joystick ? "1" : "0");
	cvar_set("m_customaccel", s_snap_m_customaccel ? "1" : "0");
	cvar_set("hud_quickinfo", s_snap_hud_quickinfo ? "1" : "0");
	cvar_set("sensitivity", ftos(s_snap_sensitivity));
	cvar_set("volume", ftos(s_snap_volume));
	cvar_set("bgmvolume", ftos(s_snap_bgmvolume));
	cvar_set("loadas8bit", s_snap_loadas8bit ? "1" : "0");
	cvar_set("s_al_use_reverb", s_snap_reverb ? "1" : "0");
	cvar_set("cl_voip_test", s_snap_voip_test ? "1" : "0");
	cvar_set("snd_voip_play", ftos(s_snap_voip_play));
	cvar_set("snd_voip_micamp", ftos(s_snap_voip_mic));
	cvar_set("crosshair", ftos(s_snap_crosshair));
	cvar_set("crosshairsize", ftos(s_snap_crosshairsize));
	cvar_set("crosshairalpha", ftos(s_snap_crosshairalpha));
	cvar_set("crosshaircolor", s_snap_crosshaircolor);
	cvar_set("gl_smoothcrosshair", s_snap_gl_smoothcrosshair ? "1" : "0");
	cvar_set("name", s_snap_player_name);
	cvar_set("ui_name", s_snap_player_name);
	localcmd(sprintf("seta gamma %f; seta vid_gamma %f\n",
		s_snap_gamma, s_snap_gamma));
	localcmd(sprintf("seta brightness %f; seta vid_brightness %f\n",
		s_snap_brightness, s_snap_brightness));
	UI_Options_KbRestoreSnap();
}

static void
UI_Options_KbUpdateButtons(void)
{
	int s;

	if (!g_uiopt_kb_list)
		return;
	s = g_uiopt_kb_list.GetSelected();

	if (s >= 0i && s < g_kb_count && STRING_SET(g_kb_cmd[s])) {
		btnKbChange.Enable();
		btnKbClear.Enable();
	} else {
		btnKbChange.Disable();
		btnKbClear.Disable();
	}
}

static void
UI_Options_OnKbListSel(void)
{
	int s;
	int n;

	if (!g_uiopt_kb_list)
		return;
	s = g_uiopt_kb_list.GetSelected();
	if (s >= 0i && s < g_kb_count && !STRING_SET(g_kb_cmd[s])) {
		for (n = s + 1; n < g_kb_count; n++) {
			if (STRING_SET(g_kb_cmd[n])) {
				g_uiopt_kb_list.SetSelected(n);
				break;
			}
		}
		if (n >= g_kb_count) {
			for (n = s - 1; n >= 0i; n--) {
				if (STRING_SET(g_kb_cmd[n])) {
					g_uiopt_kb_list.SetSelected(n);
					break;
				}
			}
		}
	}
	UI_Options_KbUpdateButtons();
}

static void
UI_Options_RefreshWidgetsFromEngine(void)
{
	g_uiopt_restore = TRUE;

	txbPlayerName.SetText(
		STRING_SET(cvar_string("ui_name")) ?
		cvar_string("ui_name") : cvar_string("name"));

	cbReverseMouse.SetValue((cvar("m_pitch") < 0) ? 1 : 0);
	cbMouseFilter.SetValue(cvar("m_filter") ? 1 : 0);
	cbRawInput.SetValue(cvar("in_rawinput") ? 1 : 0);
	cbJoystick.SetValue(cvar("joystick") ? 1 : 0);
	cbMouseAccel.SetValue(cvar("m_customaccel") ? 1 : 0);
	cbHudQuickInfo.SetValue(cvar("hud_quickinfo") ? 1 : 0);
	sldSensitivity.SetValue(
		rint(bound(1.0f, cvar("sensitivity") * 10.0f, 120.0f)));

	sldVolume.SetValue(rint(bound(0.0f, cvar("volume") * 100.0f, 100.0f)));
	sldMusic.SetValue(rint(bound(0.0f, cvar("bgmvolume") * 100.0f, 100.0f)));
	cbHQSound.SetValue((!cvar("loadas8bit")) ? 1 : 0);
	cbReverb.SetValue(cvar("s_al_use_reverb") ? 1 : 0);

	UI_Options_MatchResolutionList(lbxResolution,
		cvar("vid_width"), cvar("vid_height"));
	cbFullscreen.SetValue((cvar("vid_fullscreen") > 0) ? 1 : 0);

	sldGamma.SetValue(
		rint(bound(0.0f, ((cvar("gamma") - 0.4f) / 3.6f), 1.0f) * 100.0f));

	sldBrightness.SetValue(
		rint(bound(0.0f, cvar("brightness") * 100.0f, 100.0f)));

	cbVoipTest.SetValue(cvar("cl_voip_test") ? 1 : 0);
	sldVoipPlay.SetValue(
		rint(bound(0.0f, cvar("snd_voip_play") * 100.0f, 100.0f)));
	sldVoipMic.SetValue(
		rint(bound(0.0f, cvar("snd_voip_micamp") * 50.0f, 250.0f)));

	UI_Options_KbRefreshRows();
	UI_Options_KbUpdateButtons();

	g_uiopt_restore = FALSE;
}

static void
UI_Options_Keyboard_Hide(void)
{
	lblKbHdrAction.Hide();
	lblKbHdrKey.Hide();
	lblKbHint.Hide();
	if (g_uiopt_kb_list)
		g_uiopt_kb_list.Hide();
	btnKbChange.Hide();
	btnKbClear.Hide();
	btnKbDefaults.Hide();
	lblKbDefaultsWarn.Hide();
	UI_Options_ResetKeybindCapture();
}

static void
UI_Options_Mouse_Hide(void)
{
	cbReverseMouse.Hide();
	cbMouseFilter.Hide();
	cbRawInput.Hide();
	cbJoystick.Hide();
	cbMouseAccel.Hide();
	cbHudQuickInfo.Hide();
	lblSensitivity.Hide();
	sldSensitivity.Hide();
}

static void
UI_Options_Audio_Hide(void)
{
	lblVolume.Hide();
	sldVolume.Hide();
	lblMusic.Hide();
	sldMusic.Hide();
	cbHQSound.Hide();
	cbReverb.Hide();
}

static void
UI_Options_Video_Hide(void)
{
	lblResolution.Hide();
	lbxResolution.Hide();
	cbFullscreen.Hide();
	lblGamma.Hide();
	sldGamma.Hide();
	lblBrightness.Hide();
	sldBrightness.Hide();
}

static void
UI_Options_Voice_Hide(void)
{
	lblVoiceHelp.Hide();
	cbVoipTest.Hide();
	lblVoipPlay.Hide();
	sldVoipPlay.Hide();
	lblVoipMic.Hide();
	sldVoipMic.Hide();
}

static void
UI_Options_Multiplayer_Hide(void)
{
	picPlayerModel.Hide();
	lblPlayerName.Hide();
	txbPlayerName.Hide();
	lblCrosshairHdr.Hide();
	cbCrosshair.Hide();
	lblCrossSize.Hide();
	sldCrossSize.Hide();
	lblCrossAlpha.Hide();
	sldCrossAlpha.Hide();
	lblCrossColR.Hide();
	lblCrossColG.Hide();
	lblCrossColB.Hide();
	sldCrossR.Hide();
	sldCrossG.Hide();
	sldCrossB.Hide();
	cbSmoothCross.Hide();
}

static void
UI_Options_Kb_PrimeSelection(void)
{
	int n;

	for (n = 0i; n < g_kb_count; n++) {
		if (STRING_SET(g_kb_cmd[n])) {
			if (g_uiopt_kb_list) {
				g_uiopt_kb_list.SetSelected(n);
				g_uiopt_kb_list.SetOffset(0i, FALSE);
			}
			return;
		}
	}
	if (g_uiopt_kb_list)
		g_uiopt_kb_list.SetSelected(-1);
}

static int
UI_Options_Kb_EffectiveRow(void)
{
	int n;
	int s;

	if (!g_uiopt_kb_list)
		return -1;
	s = g_uiopt_kb_list.GetSelected();
	if (s >= 0i && s < g_kb_count && STRING_SET(g_kb_cmd[s]))
		return s;

	for (n = 0i; n < g_kb_count; n++) {
		if (STRING_SET(g_kb_cmd[n]))
			return n;
	}

	return -1;
}

static void
UI_Options_Keyboard_Show(void)
{
	g_uiopt_active_tab = OPT_TAB_KEYBOARD;
	lblKbHdrAction.Show();
	lblKbHdrKey.Show();
	lblKbHint.Show();
	if (g_uiopt_kb_list)
		g_uiopt_kb_list.Show();
	btnKbChange.Show();
	btnKbClear.Show();
	btnKbDefaults.Show();
	lblKbDefaultsWarn.Hide();
	g_uiopt_defaults_deadline = 0;
	UI_Options_KbRefreshRows();
	UI_Options_Kb_PrimeSelection();
	UI_Options_ResetKeybindCapture();
	UI_Options_KbUpdateButtons();
	UI_Options_Mouse_Hide();
	UI_Options_Audio_Hide();
	UI_Options_Video_Hide();
	UI_Options_Voice_Hide();
	UI_Options_Multiplayer_Hide();
}

static void
UI_Options_Mouse_Show(void)
{
	g_uiopt_active_tab = OPT_TAB_MOUSE;
	cbReverseMouse.Show();
	cbMouseFilter.Show();
	cbRawInput.Show();
	cbJoystick.Show();
	cbMouseAccel.Show();
	cbHudQuickInfo.Show();
	lblSensitivity.Show();
	sldSensitivity.Show();
	UI_Options_Keyboard_Hide();
	UI_Options_Audio_Hide();
	UI_Options_Video_Hide();
	UI_Options_Voice_Hide();
	UI_Options_Multiplayer_Hide();
}

static void
UI_Options_Audio_Show(void)
{
	g_uiopt_active_tab = OPT_TAB_AUDIO;
	lblVolume.Show();
	sldVolume.Show();
	lblMusic.Show();
	sldMusic.Show();
	cbHQSound.Show();
	cbReverb.Show();
	UI_Options_Keyboard_Hide();
	UI_Options_Mouse_Hide();
	UI_Options_Video_Hide();
	UI_Options_Voice_Hide();
	UI_Options_Multiplayer_Hide();
}

static void
UI_Options_Video_Show(void)
{
	g_uiopt_active_tab = OPT_TAB_VIDEO;
	lblResolution.Show();
	lbxResolution.Show();
	cbFullscreen.Show();
	lblGamma.Show();
	sldGamma.Show();
	lblBrightness.Show();
	sldBrightness.Show();
	UI_Options_Keyboard_Hide();
	UI_Options_Mouse_Hide();
	UI_Options_Audio_Hide();
	UI_Options_Voice_Hide();
	UI_Options_Multiplayer_Hide();
}

static void
UI_Options_Voice_Show(void)
{
	g_uiopt_active_tab = OPT_TAB_VOICE;
	lblVoiceHelp.Show();
	cbVoipTest.Show();
	lblVoipPlay.Show();
	sldVoipPlay.Show();
	lblVoipMic.Show();
	sldVoipMic.Show();
	UI_Options_Keyboard_Hide();
	UI_Options_Mouse_Hide();
	UI_Options_Audio_Hide();
	UI_Options_Video_Hide();
	UI_Options_Multiplayer_Hide();
}

static void
UI_Options_Multiplayer_Show(void)
{
	g_uiopt_active_tab = OPT_TAB_MULTIPLAYER;
	picPlayerModel.Show();
	lblPlayerName.Show();
	txbPlayerName.Show();
	lblCrosshairHdr.Show();
	cbCrosshair.Show();
	lblCrossSize.Show();
	sldCrossSize.Show();
	lblCrossAlpha.Show();
	sldCrossAlpha.Show();
	lblCrossColR.Show();
	lblCrossColG.Show();
	lblCrossColB.Show();
	sldCrossR.Show();
	sldCrossG.Show();
	sldCrossB.Show();
	cbSmoothCross.Show();
	UI_Options_Keyboard_Hide();
	UI_Options_Mouse_Hide();
	UI_Options_Audio_Hide();
	UI_Options_Video_Hide();
	UI_Options_Voice_Hide();
}

static void
UI_Options_Options_Cancel(void)
{
	UI_Options_ResetKeybindCapture();
	g_uiopt_restore = TRUE;
	UI_Options_RestoreSnapshot();
	UI_Options_RefreshWidgetsFromEngine();
	g_uiopt_restore = FALSE;
	UI_Options_ClearApplyDisabled();
	winOptions.Hide();
}

static void
UI_Options_KB_OnDbl(vguiList L, int idx)
{
	if (idx >= 0i && idx < g_kb_count && STRING_SET(g_kb_cmd[idx])) {
		g_uiopt_kb_capture_row = idx;
		if (g_uiopt_kb_list)
			g_uiopt_kb_list.SetCaptureHighlightRow(idx);
		UI_Options_MarkDirty();
	}
}

static void
UI_Options_Btn_KbChange(void)
{
	int s = UI_Options_Kb_EffectiveRow();

	if (s < 0i)
		return;

	if (g_uiopt_kb_list) {
		g_uiopt_kb_list.SetSelected(s);
		g_uiopt_kb_list.SetCaptureHighlightRow(s);
	}
	g_uiopt_kb_capture_row = s;
	UI_Options_MarkDirty();
}

static void
UI_Options_Btn_KbClear(void)
{
	int s = UI_Options_Kb_EffectiveRow();

	if (s < 0i)
		return;

	g_uiopt_kb_capture_row = -1;
	if (g_uiopt_kb_list) {
		g_uiopt_kb_list.SetSelected(s);
		g_uiopt_kb_list.SetCaptureHighlightRow(-1);
	}
	UI_Options_KbUnbindRow(s);
	UI_Options_KbRefreshRows();
	UI_Options_MarkDirty();
}

static void
UI_Options_Btn_KbUseDefaults(void)
{
	if (g_uiopt_defaults_deadline <= 0 || time > g_uiopt_defaults_deadline) {
		g_uiopt_defaults_deadline = time + 4.0f;
		lblKbDefaultsWarn.SetTitle(sprintf("%s\n%s\n\n%s",
			SRC_GAMEUI_KEYBOARDSETTINGS,
			SRC_GAMEUI_KEYBOARDSETTINGSTEXT,
			SRC_GAMEUI_USEDEFAULTS_CONFIRM));
		lblKbDefaultsWarn.Show();
		return;
	}

	g_uiopt_defaults_deadline = 0;
	lblKbDefaultsWarn.Hide();
	UI_Options_KbUseDefaults();
	UI_Options_MarkDirty();
}

static void
UI_Options_Apply_NoVideo(void)
{
	string playerName = txbPlayerName.GetText();

	cvar_set("name", playerName);
	cvar_set("ui_name", playerName);

	if (cbReverseMouse.GetValue()) {
		cvar_set("m_pitch", ftos(-fabs(cvar("m_pitch"))));
	} else {
		cvar_set("m_pitch", ftos(fabs(cvar("m_pitch"))));
	}
	cvar_set("m_filter", cbMouseFilter.GetValue() ? "1" : "0");
	cvar_set("in_rawinput", cbRawInput.GetValue() ? "1" : "0");
	cvar_set("joystick", cbJoystick.GetValue() ? "1" : "0");
	cvar_set("m_customaccel", cbMouseAccel.GetValue() ? "1" : "0");
	cvar_set("hud_quickinfo", cbHudQuickInfo.GetValue() ? "1" : "0");

	cvar_set("loadas8bit", cbHQSound.GetValue() ? "0" : "1");
	cvar_set("s_al_use_reverb", cbReverb.GetValue() ? "1" : "0");

	cvar_set("cl_voip_test", cbVoipTest.GetValue() ? "1" : "0");

	cvar_set("crosshair", cbCrosshair.GetValue() ? "1" : "0");
	cvar_set("crosshairsize", ftos((float)sldCrossSize.GetValue()));
	cvar_set("crosshairalpha",
		ftos((float)sldCrossAlpha.GetValue() / 100.0f));
	cvar_set("crosshaircolor", sprintf("%i %i %i",
		sldCrossR.GetValue(), sldCrossG.GetValue(), sldCrossB.GetValue()));
	cvar_set("gl_smoothcrosshair", cbSmoothCross.GetValue() ? "1" : "0");

	localcmd("cfg_save\n");
}

static void
UI_Options_ApplyVideo(void)
{
	string res;
	string wstr;
	string hstr;

	res = lbxResolution.GetItem();
	if (STRING_SET(res)) {
		tokenizebyseparator(res, "x");
		wstr = argv(0);
		tokenizebyseparator(argv(1), " ");
		hstr = argv(0);
		if (STRING_SET(wstr) && STRING_SET(hstr)) {
			localcmd(sprintf("vid_width %s\nvid_height %s\n", wstr, hstr));
		}
	}
	localcmd(sprintf("vid_fullscreen %s\n",
		cbFullscreen.GetValue() ? "1" : "0"));
	localcmd("vid_restart\n");
}

static void
UI_Options_Apply_Full(void)
{
	UI_Options_Apply_NoVideo();
	UI_Options_ApplyVideo();
	g_uiopt_restore = TRUE;
	UI_Options_CaptureSnapshot();
	UI_Options_RefreshWidgetsFromEngine();
	g_uiopt_restore = FALSE;
	UI_Options_ClearApplyDisabled();
}

static void
UI_Options_Options_OK(void)
{
	UI_Options_Apply_Full();
	UI_Options_ResetKeybindCapture();
	winOptions.Hide();
}

static string
UI_Options_ResNth(int idx)
{
	switch ( idx ) {
	case 0:	return "640x480 (4:3)";
	case 1:	return "800x600 (4:3)";
	case 2:	return "1024x768 (4:3)";
	case 3:	return "1280x960 (4:3)";
	case 4:	return "1600x1200 (4:3)";
	case 5:	return "1280x1024 (5:4)";
	case 6:	return "1280x720 (16:9)";
	case 7:	return "1366x768 (16:9)";
	case 8:	return "1600x900 (16:9)";
	case 9:	return "1920x1080 (16:9)";
	case 10:	return "2560x1440 (16:9)";
	case 11:	return "3840x2160 (16:9)";
	case 12:	return "1280x800 (16:10)";
	case 13:	return "1440x900 (16:10)";
	case 14:	return "1680x1050 (16:10)";
	case 15:	return "1920x1200 (16:10)";
	case 16:	return "2560x1600 (16:10)";
	case 17:	return "960x720 (4:3)";
	case 18:	return "1152x864 (4:3)";
	case 19:	return "1440x1080 (4:3)";
	case 20:	return "2048x1536 (4:3)";
	case 21:	return "856x480 (16:9)";
	case 22:	return "1024x576 (16:9)";
	case 23:	return "2048x1152 (16:9)";
	case 24:	return "4096x2304 (16:9)";
	case 25:	return "1024x640 (16:10)";
	case 26:	return "1152x720 (16:10)";
	case 27:	return "2304x1440 (16:10)";
	case 28:	return "1800x1440 (5:4)";
	case 29:	return "2560x2048 (5:4)";
	case 30:	return "852x480 (16:9)";
	case 31:	return "720x480";
	case 32:	return "720x576";
	default:	return "640x480 (4:3)";
	}
}

void
OptScrollbar_Sensitivity(void)
{
	float v = (float)((vguiSlider)self).GetValue();
	cvar_set("sensitivity", ftos(v / 10.0f));
	if (!g_uiopt_restore)
		UI_Options_MarkDirty();
}

void
OptScrollbar_Volume(void)
{
	cvar_set("volume", ftos((float)((vguiSlider)self).GetValue() / 100.0f));
	if (!g_uiopt_restore)
		UI_Options_MarkDirty();
}

void
OptScrollbar_Music(void)
{
	cvar_set("bgmvolume", ftos((float)((vguiSlider)self).GetValue() / 100.0f));
	if (!g_uiopt_restore)
		UI_Options_MarkDirty();
}

void
OptScrollbar_Gamma(void)
{
	float t = (float)((vguiSlider)self).GetValue() / 100.0f;
	float g = 0.4f + t * 3.6f;
	localcmd(sprintf("seta gamma %f; seta vid_gamma %f\n", g, g));
	if (!g_uiopt_restore)
		UI_Options_MarkDirty();
}

void
OptScrollbar_Brightness(void)
{
	float b = (float)((vguiSlider)self).GetValue() / 100.0f;
	localcmd(sprintf("seta brightness %f; seta vid_brightness %f\n", b, b));
	if (!g_uiopt_restore)
		UI_Options_MarkDirty();
}

void
OptScrollbar_VoipPlayback(void)
{
	localcmd(sprintf("seta snd_voip_play %f\n",
		(float)((vguiSlider)self).GetValue() / 100.0f));
	if (!g_uiopt_restore)
		UI_Options_MarkDirty();
}

void
OptScrollbar_VoipMic(void)
{
	float v = (float)((vguiSlider)self).GetValue() / 50.0f;
	if (v < 0)
		v = 0;
	localcmd(sprintf("seta snd_voip_micamp %f\n", v));
	if (!g_uiopt_restore)
		UI_Options_MarkDirty();
}

static void
UI_Options_MatchResolutionList(vguiListBox lbx, float vw, float vh)
{
	int i;

	for (i = 0i; i < UIOPT_NUM_RESOLUTIONS; i++) {
		string label = UI_Options_ResNth(i);
		tokenizebyseparator(label, "x");
		if (argv(0) && stof(argv(0)) == vw) {
			tokenizebyseparator(argv(1), " ");
			if (argv(0) && stof(argv(0)) == vh) {
				lbx.SelectionComplete(label);
				return;
			}
		}
	}
}

void UI_Options_Show ( void )
{
	int resIdx;

	if ( !g_iOptionsWindowInitialized ) {
		UI_Options_ResetKeybindCapture();
		g_iOptionsWindowInitialized = TRUE;
		winOptions = spawn( vguiWindow );
		winOptions.SetTitle( SRC_GAMEUI_OPTIONS );
		winOptions.SetSize( [UIOPT_DLG_W, UIOPT_DLG_H] );
		winOptions.SetIcon( "gfx/icon16/cog" );

		tabKeyboard = spawn( vguiButton );
		tabKeyboard.SetTitle( SRC_GAMEUI_KEYBOARD );
		tabKeyboard.SetIcon( "gfx/icon16/keyboard" );
		tabKeyboard.SetPos( [UIOPT_MAR, UIOPT_TAB_Y] );
		tabKeyboard.SetSize( [UIOPT_TAB_W, UIOPT_TAB_H] );
		tabKeyboard.SetFunc( UI_Options_Keyboard_Show );

		tabMouse = spawn( vguiButton );
		tabMouse.SetTitle( SRC_GAMEUI_MOUSE );
		tabMouse.SetIcon( "gfx/icon16/mouse" );
		tabMouse.SetPos( tabKeyboard.GetPos() + [UIOPT_TAB_W + UIOPT_TAB_GAP, 0] );
		tabMouse.SetSize( [UIOPT_TAB_W, UIOPT_TAB_H] );
		tabMouse.SetFunc( UI_Options_Mouse_Show );

		tabAudio = spawn( vguiButton );
		tabAudio.SetTitle( SRC_GAMEUI_AUDIO );
		tabAudio.SetIcon( "gfx/icon16/sound" );
		tabAudio.SetPos( tabMouse.GetPos() + [UIOPT_TAB_W + UIOPT_TAB_GAP, 0] );
		tabAudio.SetSize( [UIOPT_TAB_W, UIOPT_TAB_H] );
		tabAudio.SetFunc( UI_Options_Audio_Show );

		tabVideo = spawn( vguiButton );
		tabVideo.SetTitle( SRC_GAMEUI_VIDEO );
		tabVideo.SetIcon( "gfx/icon16/monitor" );
		tabVideo.SetPos( tabAudio.GetPos() + [UIOPT_TAB_W + UIOPT_TAB_GAP, 0] );
		tabVideo.SetSize( [UIOPT_TAB_W, UIOPT_TAB_H] );
		tabVideo.SetFunc( UI_Options_Video_Show );

		tabVoice = spawn( vguiButton );
		tabVoice.SetTitle( SRC_GAMEUI_VOICE );
		tabVoice.SetIcon( "gfx/icon16/telephone" );
		tabVoice.SetPos( tabVideo.GetPos() + [UIOPT_TAB_W + UIOPT_TAB_GAP, 0] );
		tabVoice.SetSize( [UIOPT_TAB_W, UIOPT_TAB_H] );
		tabVoice.SetFunc( UI_Options_Voice_Show );

		tabMultiplayer = spawn( vguiButton );
		tabMultiplayer.SetTitle( SRC_GAMEUI_MULTIPLAYER );
		tabMultiplayer.SetIcon( "gfx/icon16/vcard" );
		tabMultiplayer.SetPos( tabVoice.GetPos() + [UIOPT_TAB_W + UIOPT_TAB_GAP, 0] );
		tabMultiplayer.SetSize( [UIOPT_TAB_W, UIOPT_TAB_H] );
		tabMultiplayer.SetFunc( UI_Options_Multiplayer_Show );

		btnOK = spawn( vguiButton );
		btnOK.SetTitle(SRC_GAMEUI_OK);
		btnOK.SetPos([260, UIOPT_FOOT_Y]);
		btnOK.SetSize([72,24]);
		btnOK.SetFunc( UI_Options_Options_OK );

		btnCancel = spawn( vguiButton );
		btnCancel.SetTitle(SRC_GAMEUI_CANCEL);
		btnCancel.SetPos( btnOK.GetPos() + [btnOK.GetWidth() + 8, 0] );
		btnCancel.SetSize([72,24]);
		btnCancel.SetFunc( UI_Options_Options_Cancel );

		btnApply = spawn( vguiButton );
		btnApply.SetTitle( SRC_GAMEUI_APPLY );
		btnApply.SetPos( btnCancel.GetPos() + [btnCancel.GetWidth() + 8, 0] );
		btnApply.SetSize([72,24]);
		btnApply.SetFunc( UI_Options_Apply_NoVideo );

		lblKbHdrAction = spawn( vguiLabel );
		lblKbHdrAction.SetTitle( SRC_GAMEUI_ACTION );
		lblKbHdrAction.SetPos( [UIOPT_MAR + 8, UIOPT_SHEET_TOP] );
		lblKbHdrAction.SetSize( [300, 16] );
		lblKbHdrAction.Hide();

		lblKbHdrKey = spawn( vguiLabel );
		lblKbHdrKey.SetTitle( SRC_GAMEUI_KEYBUTTON );
		lblKbHdrKey.SetPos( [328, UIOPT_SHEET_TOP] );
		lblKbHdrKey.SetSize( [280, 16] );
		lblKbHdrKey.Hide();

		lstKeyBinds = spawn( vguiList );
		lstKeyBinds.SetPos( [12, UIOPT_SHEET_TOP + 12] );
		lstKeyBinds.SetSize( [UIOPT_KB_LIST_W, UIOPT_KB_LIST_H] );
		lstKeyBinds.CallOnDoubleClick( UI_Options_KB_OnDbl );
		lstKeyBinds.CallOnSelectionChanged( UI_Options_OnKbListSel );
		UI_Options_KbLoadIntoList( lstKeyBinds );
		lstKeyBinds.CallRowAllowed( UI_Options_Kb_RowBindable );

		btnKbChange = spawn( vguiButton );
		btnKbChange.SetTitle( SRC_GAMEUI_SETNEWKEY );
		btnKbChange.SetPos( [310, UIOPT_BTN_ROW_Y] );
		btnKbChange.SetSize( [84, UIOPT_BTN_H] );
		btnKbChange.SetFunc( UI_Options_Btn_KbChange );

		btnKbClear = spawn( vguiButton );
		btnKbClear.SetTitle( SRC_GAMEUI_CLEARKEY );
		btnKbClear.SetPos( [408, UIOPT_BTN_ROW_Y] );
		btnKbClear.SetSize( [84, UIOPT_BTN_H] );
		btnKbClear.SetFunc( UI_Options_Btn_KbClear );

		btnKbDefaults = spawn( vguiButton );
		btnKbDefaults.SetTitle( SRC_GAMEUI_USEDEFAULTS );
		btnKbDefaults.SetPos( [12, UIOPT_BTN_ROW_Y] );
		btnKbDefaults.SetSize( [105, UIOPT_BTN_H] );
		btnKbDefaults.SetFunc( UI_Options_Btn_KbUseDefaults );

		lblKbHint = spawn( vguiLabel );
		lblKbHint.SetTitle( SRC_GAMEUI_KEYBIND_HINT );
		lblKbHint.SetPos( [12, UIOPT_HINT_Y] );
		lblKbHint.SetSize( [UIOPT_KB_LIST_W, 36] );

		lblKbDefaultsWarn = spawn( vguiLabel );
		lblKbDefaultsWarn.SetTitle( "" );
		lblKbDefaultsWarn.SetPos( [12, UIOPT_BTN_ROW_Y - 22] );
		lblKbDefaultsWarn.SetSize( [UIOPT_KB_LIST_W, 18] );
		lblKbDefaultsWarn.Hide();

		cbReverseMouse = spawn( vguiCheckbox );
		cbReverseMouse.SetTitle( SRC_GAMEUI_REVERSEMOUSE );
		cbReverseMouse.SetPos( [30, UIOPT_SHEET_TOP + 32] );

		cbMouseFilter = spawn( vguiCheckbox );
		cbMouseFilter.SetTitle( SRC_GAMEUI_MOUSEFILTER );
		cbMouseFilter.SetPos( [30, UIOPT_SHEET_TOP + 56] );

		cbJoystick = spawn( vguiCheckbox );
		cbJoystick.SetTitle( SRC_GAMEUI_JOYSTICK );
		cbJoystick.SetPos( [30, UIOPT_SHEET_TOP + 80] );

		cbRawInput = spawn( vguiCheckbox );
		cbRawInput.SetTitle( SRC_GAMEUI_MOUSERAW );
		cbRawInput.SetPos( [30, UIOPT_SHEET_TOP + 104] );

		cbMouseAccel = spawn( vguiCheckbox );
		cbMouseAccel.SetTitle( SRC_GAMEUI_MOUSECUSTOMACCEL );
		cbMouseAccel.SetPos( [30, UIOPT_SHEET_TOP + 128] );

		cbHudQuickInfo = spawn( vguiCheckbox );
		cbHudQuickInfo.SetTitle( SRC_GAMEUI_HUDQUICKINFO );
		cbHudQuickInfo.SetPos( [30, UIOPT_SHEET_TOP + 152] );

		lblSensitivity = spawn( vguiLabel );
		lblSensitivity.SetTitle( SRC_GAMEUI_MOUSE_SENSITIVITY );
		lblSensitivity.SetPos( [34, UIOPT_SHEET_TOP + 200] );
		lblSensitivity.SetSize( [164, 24] );

		sldSensitivity = spawn( vguiSlider );
		sldSensitivity.SetPos( [34, UIOPT_SHEET_TOP + 222] );
		sldSensitivity.SetSize( [272, UIOPT_SLIDER_H] );
		sldSensitivity.SetStep( 1 );
		sldSensitivity.SetMin( 0 );
		sldSensitivity.SetMax( 120 );
		sldSensitivity.CallOnChange( OptScrollbar_Sensitivity );

		lblVolume = spawn( vguiLabel );
		lblVolume.SetTitle( SRC_GAMEUI_SOUNDVOLUME );
		lblVolume.SetPos( [42, UIOPT_SHEET_TOP + 14] );
		lblVolume.SetSize( [160, 24] );

		sldVolume = spawn( vguiSlider );
		sldVolume.SetPos( [40, UIOPT_SHEET_TOP + 37] );
		sldVolume.SetSize( [420, UIOPT_SLIDER_H] );
		sldVolume.SetStep( 1 );
		sldVolume.SetMin( 0 );
		sldVolume.SetMax( 100 );
		sldVolume.CallOnChange( OptScrollbar_Volume );

		lblMusic = spawn( vguiLabel );
		lblMusic.SetTitle( SRC_GAMEUI_MUSICVOLUME );
		lblMusic.SetPos( [40, UIOPT_SHEET_TOP + 76] );
		lblMusic.SetSize( [140, 24] );

		sldMusic = spawn( vguiSlider );
		sldMusic.SetPos( [40, UIOPT_SHEET_TOP + 98] );
		sldMusic.SetSize( [420, UIOPT_SLIDER_H] );
		sldMusic.SetStep( 1 );
		sldMusic.SetMin( 0 );
		sldMusic.SetMax( 100 );
		sldMusic.CallOnChange( OptScrollbar_Music );

		cbHQSound = spawn( vguiCheckbox );
		cbHQSound.SetTitle( SRC_GAMEUI_SOUNDQUALITY_HIGH );
		cbHQSound.SetPos( [40, UIOPT_SHEET_TOP + 140] );

		cbReverb = spawn( vguiCheckbox );
		cbReverb.SetTitle( SRC_GAMEUI_ENVIRONMENTAL_AUDIO );
		cbReverb.SetPos( [40, UIOPT_SHEET_TOP + 168] );

		lblResolution = spawn( vguiLabel );
		lblResolution.SetTitle( SRC_GAMEUI_RESOLUTION );
		lblResolution.SetPos( [40, UIOPT_SHEET_TOP + 50] );
		lblResolution.SetSize( [80, 24] );

		lbxResolution = spawn( vguiListBox );
		lbxResolution.SetPos( [140, UIOPT_SHEET_TOP + 50] );
		lbxResolution.SetSize( [180, 120] );
		lbxResolution.SetItemCount(UIOPT_NUM_RESOLUTIONS);
		for (resIdx = 0i; resIdx < UIOPT_NUM_RESOLUTIONS; resIdx++)
			lbxResolution.AddItem(UI_Options_ResNth(resIdx));

		cbFullscreen = spawn( vguiCheckbox );
		cbFullscreen.SetTitle( SRC_GAMEUI_FULLSCREEN );
		cbFullscreen.SetPos( [140, UIOPT_SHEET_TOP + 116] );

		lblBrightness = spawn( vguiLabel );
		lblBrightness.SetTitle( SRC_GAMEUI_BRIGHTNESS );
		lblBrightness.SetPos( [40, UIOPT_SHEET_TOP + 242] );
		lblBrightness.SetSize( [80, 24] );

		sldBrightness = spawn( vguiSlider );
		sldBrightness.SetPos( [140, UIOPT_SHEET_TOP + 242] );
		sldBrightness.SetSize( [300, UIOPT_SLIDER_H] );
		sldBrightness.SetStep( 1 );
		sldBrightness.SetMin( 0 );
		sldBrightness.SetMax( 100 );
		sldBrightness.CallOnChange( OptScrollbar_Brightness );

		lblGamma = spawn( vguiLabel );
		lblGamma.SetTitle( SRC_GAMEUI_GAMMA );
		lblGamma.SetPos( [40, UIOPT_SHEET_TOP + 283] );
		lblGamma.SetSize( [80, 24] );

		sldGamma = spawn( vguiSlider );
		sldGamma.SetPos( [140, UIOPT_SHEET_TOP + 283] );
		sldGamma.SetSize( [300, UIOPT_SLIDER_H] );
		sldGamma.SetStep( 1 );
		sldGamma.SetMin( 0 );
		sldGamma.SetMax( 100 );
		sldGamma.CallOnChange( OptScrollbar_Gamma );

		lblVoiceHelp = spawn( vguiLabel );
		lblVoiceHelp.SetTitle(
			sprintf("%s  %s", SRC_GAMEUI_VOICE_RECV,
				SRC_GAMEUI_VOICE_XMIT) );
		lblVoiceHelp.SetPos( [40, UIOPT_SHEET_TOP + 8] );
		lblVoiceHelp.SetSize( [420, 32] );

		cbVoipTest = spawn( vguiCheckbox );
		cbVoipTest.SetTitle( SRC_GAMEUI_VOICE_LOOPBACK );
		cbVoipTest.SetPos( [40, UIOPT_SHEET_TOP + 44] );

		lblVoipPlay = spawn( vguiLabel );
		lblVoipPlay.SetTitle( SRC_GAMEUI_VOICE_RECV );
		lblVoipPlay.SetPos( [40, UIOPT_SHEET_TOP + 72] );
		lblVoipPlay.SetSize( [160, 24] );

		sldVoipPlay = spawn( vguiSlider );
		sldVoipPlay.SetPos( [40, UIOPT_SHEET_TOP + 96] );
		sldVoipPlay.SetSize( [420, UIOPT_SLIDER_H] );
		sldVoipPlay.SetStep( 1 );
		sldVoipPlay.SetMin( 0 );
		sldVoipPlay.SetMax( 100 );
		sldVoipPlay.CallOnChange( OptScrollbar_VoipPlayback );

		lblVoipMic = spawn( vguiLabel );
		lblVoipMic.SetTitle( SRC_GAMEUI_VOICE_XMIT );
		lblVoipMic.SetPos( [40, UIOPT_SHEET_TOP + 138] );
		lblVoipMic.SetSize( [160, 24] );

		sldVoipMic = spawn( vguiSlider );
		sldVoipMic.SetPos( [40, UIOPT_SHEET_TOP + 162] );
		sldVoipMic.SetSize( [420, UIOPT_SLIDER_H] );
		sldVoipMic.SetStep( 1 );
		sldVoipMic.SetMin( 0 );
		sldVoipMic.SetMax( 250 );
		sldVoipMic.CallOnChange( OptScrollbar_VoipMic );

		picPlayerModel = spawn( vguiPic );
		picPlayerModel.SetPos( [32, UIOPT_SHEET_TOP + 16] );
		picPlayerModel.SetSize( [164, 200] );
		picPlayerModel.SetBorder(4);

		lblPlayerName = spawn( vguiLabel );
		lblPlayerName.SetTitle( SRC_GAMEUI_PLAYERNAME );
		lblPlayerName.SetPos( [230, UIOPT_SHEET_TOP + 10] );
		lblPlayerName.SetSize( [140, 24] );

		txbPlayerName = spawn( vguiTextBox );
		txbPlayerName.SetPos( [230, UIOPT_SHEET_TOP + 34] );
		txbPlayerName.SetSize( [250, 24] );

		lblCrosshairHdr = spawn( vguiLabel );
		lblCrosshairHdr.SetTitle( SRC_GAMEUI_CROSSHAIR_HDR );
		lblCrosshairHdr.SetPos( [230, UIOPT_SHEET_TOP + 64] );

		cbCrosshair = spawn( vguiCheckbox );
		cbCrosshair.SetTitle( SRC_GAMEUI_CROSSHAIR_ENABLE );
		cbCrosshair.SetPos( [230, UIOPT_SHEET_TOP + 86] );

		lblCrossSize = spawn( vguiLabel );
		lblCrossSize.SetTitle( SRC_GAMEUI_CROSSHAIR_SCALE );
		lblCrossSize.SetPos( [230, UIOPT_SHEET_TOP + 112] );
		lblCrossSize.SetSize( [120, 24] );

		sldCrossSize = spawn( vguiSlider );
		sldCrossSize.SetPos( [230, UIOPT_SHEET_TOP + 136] );
		sldCrossSize.SetSize( [250, UIOPT_SLIDER_H] );
		sldCrossSize.SetStep( 1 );
		sldCrossSize.SetMin( 0 );
		sldCrossSize.SetMax( 120 );

		lblCrossAlpha = spawn( vguiLabel );
		lblCrossAlpha.SetTitle( SRC_GAMEUI_CROSSHAIR_ALPHA );
		lblCrossAlpha.SetPos( [230, UIOPT_SHEET_TOP + 176] );
		lblCrossAlpha.SetSize( [120, 24] );

		sldCrossAlpha = spawn( vguiSlider );
		sldCrossAlpha.SetPos( [230, UIOPT_SHEET_TOP + 200] );
		sldCrossAlpha.SetSize( [250, UIOPT_SLIDER_H] );
		sldCrossAlpha.SetStep( 1 );
		sldCrossAlpha.SetMin( 0 );
		sldCrossAlpha.SetMax( 100 );

		lblCrossColR = spawn( vguiLabel );
		lblCrossColR.SetTitle( SRC_GAMEUI_CROSSHAIR_RED );
		lblCrossColR.SetPos( [230, UIOPT_SHEET_TOP + 232] );
		lblCrossColR.SetSize( [40, 24] );

		lblCrossColG = spawn( vguiLabel );
		lblCrossColG.SetTitle( SRC_GAMEUI_CROSSHAIR_GREEN );
		lblCrossColG.SetPos( [230, UIOPT_SHEET_TOP + 270] );
		lblCrossColG.SetSize( [40, 24] );

		lblCrossColB = spawn( vguiLabel );
		lblCrossColB.SetTitle( SRC_GAMEUI_CROSSHAIR_BLUE );
		lblCrossColB.SetPos( [230, UIOPT_SHEET_TOP + 308] );
		lblCrossColB.SetSize( [40, 24] );

		sldCrossR = spawn( vguiSlider );
		sldCrossR.SetPos( [272, UIOPT_SHEET_TOP + 256] );
		sldCrossR.SetSize( [208, UIOPT_SLIDER_H] );
		sldCrossR.SetStep( 1 );
		sldCrossR.SetMin( 0 );
		sldCrossR.SetMax( 255 );

		sldCrossG = spawn( vguiSlider );
		sldCrossG.SetPos( [272, UIOPT_SHEET_TOP + 294] );
		sldCrossG.SetSize( [208, UIOPT_SLIDER_H] );
		sldCrossG.SetStep( 1 );
		sldCrossG.SetMin( 0 );
		sldCrossG.SetMax( 255 );

		sldCrossB = spawn( vguiSlider );
		sldCrossB.SetPos( [272, UIOPT_SHEET_TOP + 332] );
		sldCrossB.SetSize( [208, UIOPT_SLIDER_H] );
		sldCrossB.SetStep( 1 );
		sldCrossB.SetMin( 0 );
		sldCrossB.SetMax( 255 );

		cbSmoothCross = spawn( vguiCheckbox );
		cbSmoothCross.SetTitle( SRC_GAMEUI_CROSSHAIR_SMOOTH );
		cbSmoothCross.SetPos( [230, UIOPT_SHEET_TOP + 370] );

		winOptions.Add( lblKbHdrAction );
		winOptions.Add( lblKbHdrKey );
		winOptions.Add( lstKeyBinds );
		winOptions.Add( lblKbHint );
		winOptions.Add( btnKbChange );
		winOptions.Add( btnKbClear );
		winOptions.Add( btnKbDefaults );
		winOptions.Add( lblKbDefaultsWarn );
		winOptions.Add( cbReverseMouse );
		winOptions.Add( cbMouseFilter );
		winOptions.Add( cbRawInput );
		winOptions.Add( cbJoystick );
		winOptions.Add( cbMouseAccel );
		winOptions.Add( cbHudQuickInfo );
		winOptions.Add( lblSensitivity );
		winOptions.Add( sldSensitivity );
		winOptions.Add( lblVolume );
		winOptions.Add( sldVolume );
		winOptions.Add( lblMusic );
		winOptions.Add( sldMusic );
		winOptions.Add( cbHQSound );
		winOptions.Add( cbReverb );
		winOptions.Add( lblResolution );
		winOptions.Add( lbxResolution );
		winOptions.Add( cbFullscreen );
		winOptions.Add( lblGamma );
		winOptions.Add( sldGamma );
		winOptions.Add( lblBrightness );
		winOptions.Add( sldBrightness );
		winOptions.Add( lblVoiceHelp );
		winOptions.Add( cbVoipTest );
		winOptions.Add( lblVoipPlay );
		winOptions.Add( sldVoipPlay );
		winOptions.Add( lblVoipMic );
		winOptions.Add( sldVoipMic );
		winOptions.Add( picPlayerModel );
		winOptions.Add( lblPlayerName );
		winOptions.Add( txbPlayerName );
		winOptions.Add( lblCrosshairHdr );
		winOptions.Add( cbCrosshair );
		winOptions.Add( lblCrossSize );
		winOptions.Add( sldCrossSize );
		winOptions.Add( lblCrossAlpha );
		winOptions.Add( sldCrossAlpha );
		winOptions.Add( lblCrossColR );
		winOptions.Add( lblCrossColG );
		winOptions.Add( lblCrossColB );
		winOptions.Add( sldCrossR );
		winOptions.Add( sldCrossG );
		winOptions.Add( sldCrossB );
		winOptions.Add( cbSmoothCross );

		g_uiDesktop.Add( winOptions );
		winOptions.Add( btnOK );
		winOptions.Add( btnCancel );
		winOptions.Add( btnApply );
		winOptions.Add( tabKeyboard );
		winOptions.Add( tabMouse );
		winOptions.Add( tabAudio );
		winOptions.Add( tabVideo );
		winOptions.Add( tabVoice );
		winOptions.Add( tabMultiplayer );

		UI_Options_Keyboard_Show();
	}

	txbPlayerName.SetText(
		STRING_SET(cvar_string( "ui_name" )) ?
		cvar_string( "ui_name" ) : cvar_string( "name" ) );

	cbReverseMouse.SetValue( (cvar( "m_pitch" ) < 0) ? 1 : 0 );
	cbMouseFilter.SetValue( cvar("m_filter") ? 1 : 0 );
	cbRawInput.SetValue( cvar("in_rawinput") ? 1 : 0 );
	cbJoystick.SetValue( cvar("joystick") ? 1 : 0 );
	sldSensitivity.SetValue(rint(bound(1.0f, cvar("sensitivity") * 10.0f, 120.0f)));

	sldVolume.SetValue(rint(bound(0.0f, cvar("volume") * 100.0f, 100.0f)));
	sldMusic.SetValue(rint(bound(0.0f, cvar("bgmvolume") * 100.0f, 100.0f)));
	cbHQSound.SetValue( (!cvar("loadas8bit")) ? 1 : 0 );
	cbReverb.SetValue( cvar("s_al_use_reverb") ? 1 : 0 );

	UI_Options_MatchResolutionList(lbxResolution, cvar("vid_width"), cvar("vid_height"));
	cbFullscreen.SetValue( (cvar("vid_fullscreen") > 0) ? 1 : 0 );

	sldGamma.SetValue(
		rint(
			bound(0.0f, ((cvar("gamma") - 0.4f) / 3.6f), 1.0f) *
			100.0f
		));

	sldBrightness.SetValue(rint(bound(0.0f, cvar("brightness") * 100.0f, 100.0f)));

	cbVoipTest.SetValue(cvar("cl_voip_test") ? 1 : 0);
	sldVoipPlay.SetValue(
		rint(bound(0.0f, cvar("snd_voip_play") * 100.0f, 100.0f)));
	sldVoipMic.SetValue(
		rint(bound(0.0f, cvar("snd_voip_micamp") * 50.0f, 250.0f)));

	UI_Options_KbRefreshRows();

	g_uiopt_restore = TRUE;
	UI_Options_CaptureSnapshot();
	g_uiopt_restore = FALSE;

	winOptions.Show();
	winOptions.SetPos( ( g_vidsize / 2 ) - ( winOptions.GetSize() / 2 ) );
}

float
UI_Options_HandleMenuKeys(float evtype, float scanx, float chary, float devid)
{
	if (evtype != IE_KEYDOWN)
		return 0;
	if (!g_iOptionsWindowInitialized || !winOptions.Visible())
		return 0;
	if (g_uiopt_active_tab != OPT_TAB_KEYBOARD)
		return 0;
	if (g_uiopt_kb_capture_row >= 0)
		return 0;
	if (!g_uiopt_kb_list || !g_uiopt_kb_list.Visible())
		return 0;

	if (scanx == K_ENTER) {
		UI_Options_Btn_KbChange();
		return 1;
	}
	if (scanx == K_DEL) {
		UI_Options_Btn_KbClear();
		return 1;
	}
	return 0;
}
