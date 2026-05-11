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
Tab order and grouping follow Valve GameUI OptionsDialog (+ OptionsSub*)
in source-engine/gameui — adapted to FTEQW client cvars.
Reference: OptionsDialog.cpp (Keyboard, Mouse, Audio, Video, Voice, Multiplayer)
*/

#define UIOPT_NUM_RESOLUTIONS 33

#define UIOPT_KB_MAX 128

int g_iOptionsWindowInitialized;

var string autocvar_ui_name = "Player";

int g_uiopt_kb_capture_row;
vguiList g_uiopt_kb_list;

static int g_kb_count;
static string g_kb_cmd[UIOPT_KB_MAX];
static string g_kb_desc[UIOPT_KB_MAX];

static void
UI_Options_KbUnbindRow(int row)
{
	float k0;
	float k1;

	if (row < 0i || row >= g_kb_count)
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
UI_Options_KbLoadIntoList(vguiList lst)
{
	filestream fs;
	string line;
	int n;

	g_kb_count = 0i;
	fs = fopen("gfx/shell/kb_act.lst", FILE_READ);
	if (fs < 0)
		fs = fopen("id1/gfx/shell/kb_act.lst", FILE_READ);

	if (fs >= 0) {
		while ((line = fgets(fs))) {
			if (g_kb_count >= UIOPT_KB_MAX)
				break;

			if (tokenize_console(line) != 2)
				continue;

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
		g_kb_desc[0] = "Missing gfx/shell/kb_act.lst";
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

	fs = fopen("gfx/shell/kb_def.lst", FILE_READ);
	if (fs < 0)
		fs = fopen("id1/gfx/shell/kb_def.lst", FILE_READ);
	if (fs < 0) {
		localcmd("echo ^2Options:^7 Missing gfx/shell/kb_def.lst\n");
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
}

float
UI_Options_KeybindCapture(float evtype, float scanx, float chary, float devid)
{
	int row;
	string cmd;

	if (g_uiopt_kb_capture_row < 0)
		return 0;
	if (evtype != IE_KEYDOWN)
		return 0;

	if (scanx >= 512 && scanx <= 523)
		return 0;
	if (scanx >= 600 && scanx <= 603)
		return 0;

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
		return 1;
	}

	if (scanx > 0) {
		if (!STRING_SET(cmd)) {
			UI_Options_ResetKeybindCapture();
			return 0;
		}

		UI_Options_KbUnbindRow(row);
		localcmd(sprintf("bind \"%s\" \"%s\"\n",
			keynumtostring(scanx), cmd));
		UI_Options_KbRefreshRows();
		UI_Options_ResetKeybindCapture();
		return 1;
	}

	return 0;
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
}

void
OptScrollbar_Volume(void)
{
	cvar_set("volume", ftos((float)((vguiSlider)self).GetValue() / 100.0f));
}

void
OptScrollbar_Music(void)
{
	cvar_set("bgmvolume", ftos((float)((vguiSlider)self).GetValue() / 100.0f));
}

void
OptScrollbar_Gamma(void)
{
	float t = (float)((vguiSlider)self).GetValue() / 100.0f;
	float g = 0.4f + t * 3.6f;
	localcmd(sprintf("seta gamma %f; seta vid_gamma %f\n", g, g));
}

void
OptScrollbar_Brightness(void)
{
	float b = (float)((vguiSlider)self).GetValue() / 100.0f;
	localcmd(sprintf("seta brightness %f; seta vid_brightness %f\n", b, b));
}

void
OptScrollbar_VoipPlayback(void)
{
	localcmd(sprintf("seta snd_voip_play %f\n",
		(float)((vguiSlider)self).GetValue() / 100.0f));
}

void
OptScrollbar_VoipMic(void)
{
	float v = (float)((vguiSlider)self).GetValue() / 50.0f;
	if (v < 0)
		v = 0;
	localcmd(sprintf("seta snd_voip_micamp %f\n", v));
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
	static vguiList lstKeyBinds;
	static vguiButton btnKbChange;
	static vguiButton btnKbClear;
	static vguiButton btnKbDefaults;

	static vguiCheckbox cbReverseMouse;
	static vguiCheckbox cbMouseFilter;
	static vguiCheckbox cbRawInput;
	static vguiCheckbox cbJoystick;
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

	static void Keyboard_Hide ( void ) {
		lblKbHdrAction.Hide();
		lblKbHdrKey.Hide();
		lstKeyBinds.Hide();
		btnKbChange.Hide();
		btnKbClear.Hide();
		btnKbDefaults.Hide();
		UI_Options_ResetKeybindCapture();
	}
	static void Mouse_Hide ( void ) {
		cbReverseMouse.Hide();
		cbMouseFilter.Hide();
		cbRawInput.Hide();
		cbJoystick.Hide();
		lblSensitivity.Hide();
		sldSensitivity.Hide();
	}
	static void Audio_Hide ( void ) {
		lblVolume.Hide();
		sldVolume.Hide();
		lblMusic.Hide();
		sldMusic.Hide();
		cbHQSound.Hide();
		cbReverb.Hide();
	}
	static void Video_Hide ( void ) {
		lblResolution.Hide();
		lbxResolution.Hide();
		cbFullscreen.Hide();
		lblGamma.Hide();
		sldGamma.Hide();
		lblBrightness.Hide();
		sldBrightness.Hide();
	}
	static void Voice_Hide ( void ) {
		lblVoiceHelp.Hide();
		cbVoipTest.Hide();
		lblVoipPlay.Hide();
		sldVoipPlay.Hide();
		lblVoipMic.Hide();
		sldVoipMic.Hide();
	}
	static void Multiplayer_Hide ( void ) {
		picPlayerModel.Hide();
		lblPlayerName.Hide();
		txbPlayerName.Hide();
	}

	static void Kb_PrimeSelection(void) {
		int n;

		for (n = 0i; n < g_kb_count; n++) {
			if (STRING_SET(g_kb_cmd[n])) {
				lstKeyBinds.SetSelected(n);
				lstKeyBinds.SetOffset(0i, FALSE);
				return;
			}
		}
		lstKeyBinds.SetSelected(-1);
	}

	static int Kb_EffectiveRow(void) {
		int n;
		int s;

		s = lstKeyBinds.GetSelected();
		if (s >= 0i && s < g_kb_count && STRING_SET(g_kb_cmd[s]))
			return s;

		for (n = 0i; n < g_kb_count; n++) {
			if (STRING_SET(g_kb_cmd[n]))
				return n;
		}

		return -1;
	}

	static void Keyboard_Show ( void ) {
		lblKbHdrAction.Show();
		lblKbHdrKey.Show();
		lstKeyBinds.Show();
		btnKbChange.Show();
		btnKbClear.Show();
		btnKbDefaults.Show();
		UI_Options_KbRefreshRows();
		Kb_PrimeSelection();
		UI_Options_ResetKeybindCapture();
		Mouse_Hide();
		Audio_Hide();
		Video_Hide();
		Voice_Hide();
		Multiplayer_Hide();
	}
	static void Mouse_Show ( void ) {
		cbReverseMouse.Show();
		cbMouseFilter.Show();
		cbRawInput.Show();
		cbJoystick.Show();
		lblSensitivity.Show();
		sldSensitivity.Show();
		Keyboard_Hide();
		Audio_Hide();
		Video_Hide();
		Voice_Hide();
		Multiplayer_Hide();
	}
	static void Audio_Show ( void ) {
		lblVolume.Show();
		sldVolume.Show();
		lblMusic.Show();
		sldMusic.Show();
		cbHQSound.Show();
		cbReverb.Show();
		Keyboard_Hide();
		Mouse_Hide();
		Video_Hide();
		Voice_Hide();
		Multiplayer_Hide();
	}
	static void Video_Show ( void ) {
		lblResolution.Show();
		lbxResolution.Show();
		cbFullscreen.Show();
		lblGamma.Show();
		sldGamma.Show();
		lblBrightness.Show();
		sldBrightness.Show();
		Keyboard_Hide();
		Mouse_Hide();
		Audio_Hide();
		Voice_Hide();
		Multiplayer_Hide();
	}
	static void Voice_Show ( void ) {
		lblVoiceHelp.Show();
		cbVoipTest.Show();
		lblVoipPlay.Show();
		sldVoipPlay.Show();
		lblVoipMic.Show();
		sldVoipMic.Show();
		Keyboard_Hide();
		Mouse_Hide();
		Audio_Hide();
		Video_Hide();
		Multiplayer_Hide();
	}
	static void Multiplayer_Show ( void ) {
		picPlayerModel.Show();
		lblPlayerName.Show();
		txbPlayerName.Show();
		Keyboard_Hide();
		Mouse_Hide();
		Audio_Hide();
		Video_Hide();
		Voice_Hide();
	}

	static void Options_Cancel ( void ) {
		UI_Options_ResetKeybindCapture();
		winOptions.Hide();
	}
	static void KB_OnDbl(vguiList L, int idx) {
		if (idx >= 0i && idx < g_kb_count && STRING_SET(g_kb_cmd[idx]))
			g_uiopt_kb_capture_row = idx;
	}
	static void Btn_KbChange(void) {
		int s = Kb_EffectiveRow();

		if (s < 0i)
			return;

		lstKeyBinds.SetSelected(s);
		g_uiopt_kb_capture_row = s;
	}
	static void Btn_KbClear(void) {
		int s = Kb_EffectiveRow();

		if (s < 0i)
			return;

		g_uiopt_kb_capture_row = -1;
		lstKeyBinds.SetSelected(s);
		UI_Options_KbUnbindRow(s);
		UI_Options_KbRefreshRows();
	}
	static void Btn_KbUseDefaults(void) {
		UI_Options_KbUseDefaults();
	}
	static void Options_Apply_NoVideo(void) {
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

		cvar_set("loadas8bit", cbHQSound.GetValue() ? "0" : "1");
		cvar_set("s_al_use_reverb", cbReverb.GetValue() ? "1" : "0");

		cvar_set("cl_voip_test", cbVoipTest.GetValue() ? "1" : "0");

		localcmd("cfg_save\n");
	}
	static void Options_ApplyVideo ( void ) {
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
		localcmd(sprintf("vid_fullscreen %s\n", cbFullscreen.GetValue() ? "1" : "0"));
		localcmd("vid_restart\n");
	}
	static void Options_OK ( void ) {
		Options_Apply_NoVideo();
		Options_ApplyVideo();
		Options_Cancel();
	}

	if ( !g_iOptionsWindowInitialized ) {
		UI_Options_ResetKeybindCapture();
		g_iOptionsWindowInitialized = TRUE;
		winOptions = spawn( vguiWindow );
		winOptions.SetTitle( "Options" );
		winOptions.SetSize( '512 406' );
		winOptions.SetIcon( "gfx/icon16/cog" );

		tabKeyboard = spawn( vguiButton );
		tabKeyboard.SetTitle( "Keyboard" );
		tabKeyboard.SetIcon( "gfx/icon16/keyboard" );
		tabKeyboard.SetPos( [4,32] );
		tabKeyboard.SetSize( [78,22] );
		tabKeyboard.SetFunc( Keyboard_Show );

		tabMouse = spawn( vguiButton );
		tabMouse.SetTitle( "Mouse" );
		tabMouse.SetIcon( "gfx/icon16/mouse" );
		tabMouse.SetPos( tabKeyboard.GetPos() + [82,0] );
		tabMouse.SetSize( [78,22] );
		tabMouse.SetFunc( Mouse_Show );

		tabAudio = spawn( vguiButton );
		tabAudio.SetTitle( "Audio" );
		tabAudio.SetIcon( "gfx/icon16/sound" );
		tabAudio.SetPos( tabMouse.GetPos() + [82,0] );
		tabAudio.SetSize( [78,22] );
		tabAudio.SetFunc( Audio_Show );

		tabVideo = spawn( vguiButton );
		tabVideo.SetTitle( "Video" );
		tabVideo.SetIcon( "gfx/icon16/monitor" );
		tabVideo.SetPos( tabAudio.GetPos() + [82,0] );
		tabVideo.SetSize( [78,22] );
		tabVideo.SetFunc( Video_Show );

		tabVoice = spawn( vguiButton );
		tabVoice.SetTitle( "Voice" );
		tabVoice.SetIcon( "gfx/icon16/telephone" );
		tabVoice.SetPos( tabVideo.GetPos() + [82,0] );
		tabVoice.SetSize( [78,22] );
		tabVoice.SetFunc( Voice_Show );

		tabMultiplayer = spawn( vguiButton );
		tabMultiplayer.SetTitle( "Multi" );
		tabMultiplayer.SetIcon( "gfx/icon16/vcard" );
		tabMultiplayer.SetPos( tabVoice.GetPos() + [82,0] );
		tabMultiplayer.SetSize( [78,22] );
		tabMultiplayer.SetFunc( Multiplayer_Show );

		btnOK = spawn( vguiButton );
		btnOK.SetTitle("OK");
		btnOK.SetPos([267,373]);
		btnOK.SetSize([72,24]);
		btnOK.SetFunc( Options_OK );

		btnCancel = spawn( vguiButton );
		btnCancel.SetTitle("Cancel");
		btnCancel.SetPos( btnOK.GetPos() + [btnOK.GetWidth() + 8, 0] );
		btnCancel.SetSize([72,24]);
		btnCancel.SetFunc( Options_Cancel );

		btnApply = spawn( vguiButton );
		btnApply.SetTitle( "Apply" );
		btnApply.SetPos( btnCancel.GetPos() + [btnCancel.GetWidth() + 8, 0] );
		btnApply.SetSize([72,24]);
		btnApply.SetFunc( Options_Apply_NoVideo );

		lblKbHdrAction = spawn( vguiLabel );
		lblKbHdrAction.SetTitle( "Action" );
		lblKbHdrAction.SetPos( [16, 56] );
		lblKbHdrAction.SetSize( [240, 16] );

		lblKbHdrKey = spawn( vguiLabel );
		lblKbHdrKey.SetTitle( "Key / button" );
		lblKbHdrKey.SetPos( [300, 56] );
		lblKbHdrKey.SetSize( [200, 16] );

		lstKeyBinds = spawn( vguiList );
		lstKeyBinds.SetPos( [12, 74] );
		lstKeyBinds.SetSize( [488, 246] );
		lstKeyBinds.CallOnDoubleClick( KB_OnDbl );
		UI_Options_KbLoadIntoList( lstKeyBinds );

		btnKbChange = spawn( vguiButton );
		btnKbChange.SetTitle( "Change key" );
		btnKbChange.SetPos( [12, 328] );
		btnKbChange.SetSize( [156, 22] );
		btnKbChange.SetFunc( Btn_KbChange );

		btnKbClear = spawn( vguiButton );
		btnKbClear.SetTitle( "Clear binding" );
		btnKbClear.SetPos( [176, 328] );
		btnKbClear.SetSize( [156, 22] );
		btnKbClear.SetFunc( Btn_KbClear );

		btnKbDefaults = spawn( vguiButton );
		btnKbDefaults.SetTitle( "Use defaults" );
		btnKbDefaults.SetPos( [340, 328] );
		btnKbDefaults.SetSize( [160, 22] );
		btnKbDefaults.SetFunc( Btn_KbUseDefaults );

		cbReverseMouse = spawn( vguiCheckbox );
		cbReverseMouse.SetTitle( "Reverse mouse (invert look)" );
		cbReverseMouse.SetPos( [12, 72] );

		cbMouseFilter = spawn( vguiCheckbox );
		cbMouseFilter.SetTitle( "Mouse filter (m_filter)" );
		cbMouseFilter.SetPos( [12, 94] );

		cbRawInput = spawn( vguiCheckbox );
		cbRawInput.SetTitle( "Raw mouse input (in_rawinput)" );
		cbRawInput.SetPos( [12, 116] );

		cbJoystick = spawn( vguiCheckbox );
		cbJoystick.SetTitle( "Joystick (joystick)" );
		cbJoystick.SetPos( [12, 138] );

		lblSensitivity = spawn( vguiLabel );
		lblSensitivity.SetTitle( "Sensitivity" );
		lblSensitivity.SetPos( [12, 168] );
		lblSensitivity.SetSize( [120,16] );

		sldSensitivity = spawn( vguiSlider );
		sldSensitivity.SetPos( [180, 164] );
		sldSensitivity.SetSize( [310, 22] );
		sldSensitivity.SetStep( 1 );
		sldSensitivity.SetMin( 0 );
		sldSensitivity.SetMax( 120 );
		sldSensitivity.CallOnChange( OptScrollbar_Sensitivity );

		lblVolume = spawn( vguiLabel );
		lblVolume.SetTitle( "Sound volume" );
		lblVolume.SetPos( [12,72] );

		sldVolume = spawn( vguiSlider );
		sldVolume.SetPos( [180, 62] );
		sldVolume.SetSize( [310, 22] );
		sldVolume.SetStep( 1 );
		sldVolume.SetMin( 0 );
		sldVolume.SetMax( 100 );
		sldVolume.CallOnChange( OptScrollbar_Volume );

		lblMusic = spawn( vguiLabel );
		lblMusic.SetTitle( "Music volume (bgmvolume)" );
		lblMusic.SetPos( [12,118] );

		sldMusic = spawn( vguiSlider );
		sldMusic.SetPos( [180, 110] );
		sldMusic.SetSize( [310, 22] );
		sldMusic.SetStep( 1 );
		sldMusic.SetMin( 0 );
		sldMusic.SetMax( 100 );
		sldMusic.CallOnChange( OptScrollbar_Music );

		cbHQSound = spawn( vguiCheckbox );
		cbHQSound.SetTitle( "High quality sound (~loadas8bit 0)" );
		cbHQSound.SetPos( [12,172] );

		cbReverb = spawn( vguiCheckbox );
		cbReverb.SetTitle( "Environmental reverb (OpenAL)" );
		cbReverb.SetPos( [12,194] );

		lblResolution = spawn( vguiLabel );
		lblResolution.SetTitle( "Resolution" );
		lblResolution.SetPos( [12,72] );
		lbxResolution = spawn( vguiListBox );
		lbxResolution.SetPos( [12,92] );
		lbxResolution.SetSize( [200,22] );
		lbxResolution.SetItemCount(UIOPT_NUM_RESOLUTIONS);
		for (resIdx = 0i; resIdx < UIOPT_NUM_RESOLUTIONS; resIdx++)
			lbxResolution.AddItem(UI_Options_ResNth(resIdx));

		cbFullscreen = spawn( vguiCheckbox );
		cbFullscreen.SetTitle( "Fullscreen (vid_fullscreen 1)" );
		cbFullscreen.SetPos( [230,92] );

		lblGamma = spawn( vguiLabel );
		lblGamma.SetTitle( "Gamma" );
		lblGamma.SetPos( [12,138] );

		sldGamma = spawn( vguiSlider );
		sldGamma.SetPos( [110, 132] );
		sldGamma.SetSize( [200, 22] );
		sldGamma.SetStep( 1 );
		sldGamma.SetMin( 0 );
		sldGamma.SetMax( 100 );
		sldGamma.CallOnChange( OptScrollbar_Gamma );

		lblBrightness = spawn( vguiLabel );
		lblBrightness.SetTitle( "Brightness / glare" );
		lblBrightness.SetPos( [230,138] );

		sldBrightness = spawn( vguiSlider );
		sldBrightness.SetPos( [318, 132] );
		sldBrightness.SetSize( [182, 22] );
		sldBrightness.SetStep( 1 );
		sldBrightness.SetMin( 0 );
		sldBrightness.SetMax( 100 );
		sldBrightness.CallOnChange( OptScrollbar_Brightness );

		lblVoiceHelp = spawn( vguiLabel );
		lblVoiceHelp.SetTitle(
			"FTE VOIP (snd_voip_*): mirrors Source Receive / Mic emphasis." );
		lblVoiceHelp.SetPos( [12,72] );
		lblVoiceHelp.SetSize( [480, 32] );

		cbVoipTest = spawn( vguiCheckbox );
		cbVoipTest.SetTitle( "Voice loopback test (cl_voip_test)" );
		cbVoipTest.SetPos( [12,108] );

		lblVoipPlay = spawn( vguiLabel );
		lblVoipPlay.SetTitle( "Others speak volume (snd_voip_play)" );
		lblVoipPlay.SetPos( [12,138] );

		sldVoipPlay = spawn( vguiSlider );
		sldVoipPlay.SetPos( [220, 132] );
		sldVoipPlay.SetSize( [270, 22] );
		sldVoipPlay.SetStep( 1 );
		sldVoipPlay.SetMin( 0 );
		sldVoipPlay.SetMax( 100 );
		sldVoipPlay.CallOnChange( OptScrollbar_VoipPlayback );

		lblVoipMic = spawn( vguiLabel );
		lblVoipMic.SetTitle( "Mic gain (snd_voip_micamp)" );
		lblVoipMic.SetPos( [12,180] );

		sldVoipMic = spawn( vguiSlider );
		sldVoipMic.SetPos( [220, 172] );
		sldVoipMic.SetSize( [270, 22] );
		sldVoipMic.SetStep( 1 );
		sldVoipMic.SetMin( 0 );
		sldVoipMic.SetMax( 250 );
		sldVoipMic.CallOnChange( OptScrollbar_VoipMic );

		picPlayerModel = spawn( vguiPic );
		picPlayerModel.SetPos( [265, 87] );
		picPlayerModel.SetSize( [190, 160] );
		picPlayerModel.SetBorder(4);

		lblPlayerName = spawn( vguiLabel );
		lblPlayerName.SetTitle( "Player name" );
		lblPlayerName.SetPos( [12, 82] );

		txbPlayerName = spawn( vguiTextBox );
		txbPlayerName.SetPos( [12, 102] );
		txbPlayerName.SetSize( [220,24] );

		winOptions.Add( lblKbHdrAction );
		winOptions.Add( lblKbHdrKey );
		winOptions.Add( lstKeyBinds );
		winOptions.Add( btnKbChange );
		winOptions.Add( btnKbClear );
		winOptions.Add( btnKbDefaults );
		winOptions.Add( cbReverseMouse );
		winOptions.Add( cbMouseFilter );
		winOptions.Add( cbRawInput );
		winOptions.Add( cbJoystick );
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

		Keyboard_Show();
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

	winOptions.Show();
	winOptions.SetPos( ( g_vidsize / 2 ) - ( winOptions.GetSize() / 2 ) );
}
