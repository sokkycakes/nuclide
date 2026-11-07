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

/* Native MenuQC property sheet. Layout reference: this install's original
 * valve/resource/OptionsSub{Keyboard,Mouse,Audio,Video,Voice,Multiplayer}.res.
 * Cvar names belong to FTE, not to Valve's renderer/input/audio backends.
 * All edits are staged. Only changed, supported settings/bindings are applied.
 * The sheet owns its controls because this revision's Slider and ListBox
 * implementations are unfinished. Other VGUI users are left independent.
 */

#define UIO_W 504
#define UIO_H 448
#define UIO_SETTINGS 80
#define UIO_KEYS 1024
#define UIO_ACTIONS 128
#define UIO_HITS 96
#define UIO_POPUP_ROWS 9
#define UIO_KEY_ROWS 12

enum { UIO_KEYBOARD, UIO_MOUSE, UIO_AUDIO, UIO_VIDEO, UIO_VOICE, UIO_MULTI, UIO_MULTI_ADVANCED };
enum { UIO_CHECK, UIO_SLIDER, UIO_CHOICE, UIO_TEXT, UIO_COLOR };
enum { UIO_H_TAB, UIO_H_SETTING, UIO_H_ROW, UIO_H_APPLY, UIO_H_OK,
       UIO_H_CANCEL, UIO_H_BIND, UIO_H_CLEAR, UIO_H_DEFAULTS,
       UIO_H_MIC, UIO_H_SCROLLUP, UIO_H_SCROLLDOWN,
       UIO_H_ADVANCED, UIO_H_ADV_OK, UIO_H_ADV_CANCEL, UIO_H_ADV_SCROLL };

typedef struct {
    int page;
    int kind;
    string key;
    string title;
    string value;
    string original;
    string labels;
    string values;
    float low;
    float high;
    float step;
    vector pos;
    vector size;
    bool supported;
    bool unavailable;
} uioSetting_t;

typedef struct {
    int kind;
    int index;
    vector pos;
    vector size;
    bool enabled;
} uioHit_t;

uioSetting_t g_uio[UIO_SETTINGS];
int g_uioCount;
uioHit_t g_uioHits[UIO_HITS];
int g_uioHitCount;
int g_uioPage;
var int g_uioPressed = -1;
var int g_uioFocus = -1;
var int g_uioSlider = -1;
var int g_uioPopup = -1;
int g_uioPopupOffset;
int g_uioPopupSelection;
int g_uioTextCursor;
bool g_uioSelectAll;
bool g_uioCtrl;
bool g_uioShift;
string g_uioStatus;
vector g_uioOrigin;
string g_uioBind[UIO_KEYS];
string g_uioBindOriginal[UIO_KEYS];
string g_uioAction[UIO_ACTIONS];
string g_uioActionLabel[UIO_ACTIONS];
int g_uioActionCount;
int g_uioKeyRow;
int g_uioKeyColumn;
int g_uioKeyOffset;
var int g_uioCapture = -1;
var int g_uioLastRow = -1;
float g_uioLastClick;
bool g_uioDefaultsConfirm;
bool g_uioVideoPending;
bool g_uioCloseAfterApply;
float g_uioVideoDeadline;
string g_uioOldWidth;
string g_uioOldHeight;
string g_uioOldFullscreen;
string g_uioOldVsync;
bool g_uioMicTesting;
string g_uioMicOldTest;
string g_uioMicOldPlay;
string g_uioMicOldGain;
int g_uioResolution;
int g_uioModel;
int g_uioSpray;
int g_uioSprayColor;
var int g_uioNameLimit = 63;
bool g_uioMPAdvanced;

void UIOMP_Create(void);
void UIOMP_Draw(void);
void UIOMP_DrawAdvanced(void);
void UIOMP_OpenAdvanced(void);
void UIOMP_CloseAdvanced(bool);
void UIOMP_ScrollAdvanced(int);
void UIOMP_DrawColor(int);
bool UIOMP_Supported(int);
string UIOMP_ReadSetting(int);
string UIOMP_ColorToEngine(float);
bool UIOMP_ApplySpray(void);
void UIOMP_ReloadImages(void);
void UIOMP_RestoreSavedSpray(void);

void UI_Options_Show(void);
void Locale_ParseFile(string pathToFile);
void UIO_Cancel(void);
void UIO_StopMic(void);
void UIO_RevertVideo(void);
void UIO_Draw(void);
bool UIO_Input(float, float, float, float);

class uioOptionsWindow : vguiWindow
{
    virtual void Draw(void);
    virtual bool Input(float, float, float, float);
    virtual void Reposition(void);
    virtual void NowHidden(void);
};

uioOptionsWindow g_uioWindow;

/* MenuQC declares min/max as variadic after the first float argument.
 * Passing an int as argument two preserves its integer bit pattern.
 * Typed helpers ensure counts, offsets and selections are converted correctly. */
float UIO_Min(float a, float b) { return a < b ? a : b; }
float UIO_Max(float a, float b) { return a > b ? a : b; }
string UIO_Part(string text, int n)
{
    int count = tokenizebyseparator(text, "|");
    return (n >= 0 && n < count) ? argv(n) : "";
}

int UIO_Parts(string text)
{
    return tokenizebyseparator(text, "|");
}

int UIO_Find(string key)
{
    for (int i = 0; i < g_uioCount; i++)
        if (g_uio[i].key == key)
            return i;
    return -1;
}

bool UIO_Available(string key)
{
    float flags = cvar_type(key);
    return (flags & CVAR_TYPEFLAG_EXISTS) && !(flags &
        (CVAR_TYPEFLAG_READONLY | CVAR_TYPEFLAG_PRIVATE));
}

bool UIO_IsMode(int i)
{
    return g_uio[i].key == "$resolution" || g_uio[i].key == "vid_fullscreen"
        || g_uio[i].key == "vid_vsync";
}

bool UIO_Dirty(void)
{
    for (int i = 0; i < g_uioCount; i++)
        if (g_uio[i].supported && g_uio[i].value != g_uio[i].original)
            return true;
    for (int k = 0; k < UIO_KEYS; k++)
        if (g_uioBind[k] != g_uioBindOriginal[k])
            return true;
    return false;
}

void UIO_Set(int i, string value)
{
    if (i < 0 || i >= g_uioCount)
        return;
    if (!g_uio[i].supported)
        return;
    if (g_uio[i].value == value)
        return;
    UIO_StopMic();
    g_uio[i].value = value;
    g_uioStatus = "Changes are not saved until you choose Apply or OK.";
}

int UIO_Add(int page, int kind, string key, string title,
    vector pos, vector size, float low, float high, float step)
{
    if (g_uioCount >= UIO_SETTINGS)
        error("Options setting limit exceeded");
    int i = g_uioCount++;
    g_uio[i].page = page;
    g_uio[i].kind = kind;
    g_uio[i].key = key;
    g_uio[i].title = title;
    g_uio[i].pos = pos;
    g_uio[i].size = size;
    g_uio[i].low = low;
    g_uio[i].high = high;
    g_uio[i].step = step;
    return i;
}

void UIO_AddChoice(int i, string label, string value)
{
    int n = UIO_Parts(g_uio[i].values);
    for (int j = 0; j < n; j++)
        if (UIO_Part(g_uio[i].values, j) == value)
            return;
    if (n >= 96)
        return;
    if (n) {
        g_uio[i].labels = strcat(g_uio[i].labels, "|", label);
        g_uio[i].values = strcat(g_uio[i].values, "|", value);
    } else {
        g_uio[i].labels = label;
        g_uio[i].values = value;
    }
}

int UIO_SelectedChoice(int i)
{
    int n = UIO_Parts(g_uio[i].values);
    for (int j = 0; j < n; j++)
        if (UIO_Part(g_uio[i].values, j) == g_uio[i].value)
            return j;
    return -1;
}

string UIO_ChoiceLabel(int i)
{
    int selected = UIO_SelectedChoice(i);
    if (selected >= 0)
        return UIO_Part(g_uio[i].labels, selected);
    return sprintf("Custom (%s)", g_uio[i].value);
}

string UIO_ReadSetting(int i)
{
    if (g_uio[i].kind == UIO_COLOR || g_uio[i].key == "$spray" || g_uio[i].key == "$spraycolor")
        return UIOMP_ReadSetting(i);
    if (g_uio[i].key == "$resolution") {
        vector pixels = getproperty(VF_SCREENPSIZE);
        float w = cvar("vid_width"), h = cvar("vid_height");
        if (w <= 0) w = pixels[0];
        if (h <= 0) h = pixels[1];
        return sprintf("%dx%d", w, h);
    }
    return cvar_string(g_uio[i].key);
}

string UIO_Command(string command)
{
    /* FTE's voice transport is exposed by +voip. */
    if (command == "+voicerecord") return "+voip";
    if (command == "snapshot") return "screenshot";
    return command;
}

void UIO_AddAction(string command, string label)
{
    if (g_uioActionCount >= UIO_ACTIONS) return;
    command = UIO_Command(command);
    if (command)
        for (int existing = 0; existing < g_uioActionCount; existing++)
            if (g_uioAction[existing] == command) return;
    g_uioAction[g_uioActionCount] = command;
    g_uioActionLabel[g_uioActionCount] = localize(label);
    g_uioActionCount++;
}

void UIO_LoadActions(void)
{
    /* Original GoldSrc localization resources are UTF-16. The build helper
     * exports just the action labels as UTF-8 for this QC text parser. */
    if (fileExists("resource/options_keys_english.txt"))
        Locale_ParseFile("resource/options_keys_english.txt");
    filestream f = fopen("scripts/kb_act.lst", FILE_READ);
    if (f < 0) f = fopen("gfx/shell/kb_act.lst", FILE_READ);
    g_uioActionCount = 0;
    if (f >= 0) {
        string line;
        while ((line = fgets(f))) {
            if (tokenize_console(line) < 2) continue;
            string command = argv(0), label = argv(1);
            if (command == "blank") {
                if (substring(label, 0, 1) == "=") continue;
                command = "";
            }
            UIO_AddAction(command, label);
        }
        fclose(f);
    }
    if (g_uioActionCount == 0) {
        UIO_AddAction("", "Movement");
        UIO_AddAction("+forward", "Move forward");
        UIO_AddAction("+back", "Move backward");
        UIO_AddAction("+moveleft", "Step left");
        UIO_AddAction("+moveright", "Step right");
        UIO_AddAction("+jump", "Jump");
        UIO_AddAction("+duck", "Duck");
        UIO_AddAction("", "Combat and communication");
        UIO_AddAction("+attack", "Primary attack");
        UIO_AddAction("+attack2", "Secondary attack");
        UIO_AddAction("+reload", "Reload");
        UIO_AddAction("+use", "Use");
        UIO_AddAction("+showscores", "Scoreboard");
        UIO_AddAction("+voip", "Push to talk");
        UIO_AddAction("messagemode", "Chat");
        UIO_AddAction("toggleconsole", "Developer console");
    }
    g_uioKeyRow = 0;
    while (g_uioKeyRow < g_uioActionCount - 1 && !g_uioAction[g_uioKeyRow])
        g_uioKeyRow++;
}

int UIO_BoundKey(int row, int column)
{
    if (row < 0 || row >= g_uioActionCount) return -1;
    if (!g_uioAction[row]) return -1;
    for (int k = 0; k < UIO_KEYS; k++) {
        if (g_uioBind[k] == g_uioAction[row]) {
            if (column == 0) return k;
            column--;
        }
    }
    return -1;
}

void UIO_LoadSnapshot(void)
{
    for (int i = 0; i < g_uioCount; i++) {
        g_uio[i].supported = UIOMP_Supported(i);
        g_uio[i].value = g_uio[i].supported ? UIO_ReadSetting(i) : "";
        g_uio[i].original = g_uio[i].value;
    }
    UIO_AddChoice(g_uioResolution, g_uio[g_uioResolution].value,
        g_uio[g_uioResolution].value);
    if (g_uio[g_uioModel].value)
        UIO_AddChoice(g_uioModel, g_uio[g_uioModel].value, g_uio[g_uioModel].value);
    for (int k = 0; k < UIO_KEYS; k++) {
        g_uioBind[k] = getkeybind(k, 0, 0);
        g_uioBindOriginal[k] = g_uioBind[k];
    }
    g_uioStatus = "";
}

void UIO_CreateSettings(void)
{
    int i;
    UIO_Add(UIO_MOUSE, UIO_CHECK, "m_pitch", "Reverse mouse", [32,86], [420,22], 0,0,0);
    UIO_Add(UIO_MOUSE, UIO_CHECK, "m_filter", "Mouse filter", [32,118], [420,22], 0,0,0);
    UIO_Add(UIO_MOUSE, UIO_CHECK, "in_rawinput", "Raw mouse input", [32,150], [420,22], 0,0,0);
    UIO_Add(UIO_MOUSE, UIO_CHECK, "joystick", "Enable joystick / controller", [32,182], [420,22], 0,0,0);
    UIO_Add(UIO_MOUSE, UIO_SLIDER, "sensitivity", "Mouse sensitivity", [36,248], [424,24], 0.1,20,0.1);
    UIO_Add(UIO_MOUSE, UIO_SLIDER, "m_accel", "Mouse acceleration (0 = off)", [36,318], [424,24], 0,1,0.01);

    UIO_Add(UIO_AUDIO, UIO_SLIDER, "volume", "Sound effects volume", [36,100], [424,24], 0,1,0.01);
    UIO_Add(UIO_AUDIO, UIO_SLIDER, "bgmvolume", "Music volume", [36,174], [424,24], 0,1,0.01);
    i = UIO_Add(UIO_AUDIO, UIO_CHOICE, "loadas8bit", "Sound quality", [36,250], [260,24], 0,0,0);
    UIO_AddChoice(i,"High (16-bit)","0"); UIO_AddChoice(i,"Low (8-bit)","1");
    UIO_Add(UIO_AUDIO, UIO_CHECK, "s_al_use_reverb", "Environmental audio (OpenAL)", [36,300], [424,22],0,0,0);

    g_uioResolution = UIO_Add(UIO_VIDEO, UIO_CHOICE, "$resolution", "Resolution", [30,96], [216,24],0,0,0);
    string modes = "640x480|800x600|1024x768|1280x720|1280x800|1280x960|1280x1024|1366x768|1440x900|1600x900|1600x1200|1680x1050|1920x1080|1920x1200|2560x1440|2560x1600|3440x1440|3840x2160";
    for (int n = 0; n < 18; n++) {
        string mode = UIO_Part(modes,n);
        UIO_AddChoice(g_uioResolution,mode,mode);
    }
    i = UIO_Add(UIO_VIDEO, UIO_CHOICE, "vid_fullscreen", "Display mode", [262,96], [212,24],0,0,0);
    UIO_AddChoice(i,"Windowed","0"); UIO_AddChoice(i,"Fullscreen","1"); UIO_AddChoice(i,"Borderless desktop","2");
    i = UIO_Add(UIO_VIDEO, UIO_CHOICE, "gl_texturemode", "Texture filtering", [30,174], [216,24],0,0,0);
    UIO_AddChoice(i,"Nearest / pixel sharp","GL_NEAREST");
    UIO_AddChoice(i,"Bilinear","GL_LINEAR_MIPMAP_NEAREST");
    UIO_AddChoice(i,"Trilinear","GL_LINEAR_MIPMAP_LINEAR");
    i = UIO_Add(UIO_VIDEO, UIO_CHOICE, "vid_vsync", "Vertical sync", [262,174], [212,24],0,0,0);
    UIO_AddChoice(i,"Off","0"); UIO_AddChoice(i,"On","1"); UIO_AddChoice(i,"Adaptive","-1");
    UIO_Add(UIO_VIDEO, UIO_SLIDER, "gamma", "Gamma", [36,252], [424,24],0.5,2,0.05);
    UIO_Add(UIO_VIDEO, UIO_SLIDER, "brightness", "Brightness", [36,318], [424,24],0,0.5,0.01);

    UIO_Add(UIO_VOICE, UIO_SLIDER, "cl_voip_play", "Receive volume (0 = muted)", [36,100], [424,24],0,2,0.05);
    UIO_Add(UIO_VOICE, UIO_SLIDER, "cl_voip_micamp", "Microphone gain", [36,166], [424,24],0,4,0.1);
    UIO_Add(UIO_VOICE, UIO_SLIDER, "cl_voip_ducking", "Game volume while others speak", [36,232], [424,24],0,1,0.05);
    UIO_Add(UIO_VOICE, UIO_CHECK, "cl_voip_noisefilter", "Reduce microphone noise", [36,278], [424,22],0,0,0);
    UIO_Add(UIO_VOICE, UIO_CHECK, "cl_voip_autogain", "Automatic microphone gain", [36,310], [424,22],0,0,0);

    UIOMP_Create();
}

void UIO_Text(vector pos, vector size, string text, bool dim)
{
    font_s font = g_fntDefault;
    font.vecColor = [1,1,1];
    if (dim) font.vecColor *= 0.5;
    font.hexColor = Font_RGBtoHex(font.vecColor);
    Font_DrawField(g_uioOrigin + pos, size, text, font, AF_LEFT | AF_TOP);
}

void UIO_Rect(vector pos, vector size, vector color, float alpha)
{
    drawfill(g_uioOrigin + pos,size,color,alpha);
}

void UIO_Line(vector pos, vector size, string text, bool dim)
{
    font_s font = g_fntDefault;
    font.vecColor = [1,1,1];
    if (dim) font.vecColor *= 0.5;
    vector absolute = g_uioOrigin + pos;
    drawsetcliparea(absolute[0], absolute[1], size[0], size[1]);
    Font_DrawText(absolute,text,font);
    drawresetcliparea();
}

string UIO_KeyLabel(int key)
{
    if (key < 0) return "---";
    string label = keynumtostring(key);
    switch (label) {
    case "UPARROW": return "Up arrow";
    case "DOWNARROW": return "Down arrow";
    case "LEFTARROW": return "Left arrow";
    case "RIGHTARROW": return "Right arrow";
    case "APOSTROPHE": return "'";
    case "SEMICOLON": return ";";
    case "MWHEELUP": return "Wheel up";
    case "MWHEELDOWN": return "Wheel down";
    case "BACKSPACE": return "Backspace";
    default: return label;
    }
}

void UIO_Outline(vector pos, vector size, vector color)
{
    UIO_Rect(pos,[size[0],1],color,1);
    UIO_Rect(pos+[0,size[1]-1],[size[0],1],color,1);
    UIO_Rect(pos,[1,size[1]],color,1);
    UIO_Rect(pos+[size[0]-1,0],[1,size[1]],color,1);
}

bool UIO_Over(vector pos, vector size)
{
    return Util_MouseAbove(g_vecMousePos,g_uioOrigin+pos,size);
}

void UIO_Hit(int kind, int index, vector pos, vector size, bool enabled)
{
    if (g_uioHitCount >= UIO_HITS) return;
    int h = g_uioHitCount++;
    g_uioHits[h].kind=kind; g_uioHits[h].index=index;
    g_uioHits[h].pos=pos; g_uioHits[h].size=size;
    g_uioHits[h].enabled=enabled;
}

void UIO_Button(int kind, int index, vector pos, vector size, string text, bool enabled)
{
    int h = g_uioHitCount;
    vguiTheme theme = g_uioWindow.GetTheme();
    VGUIDrawState_t state = VGUI_STATE_NORMAL;
    if (!enabled) state = VGUI_STATE_DISABLED;
    else if (h == g_uioPressed) state = VGUI_STATE_ACTIVE;
    else if (UIO_Over(pos,size)) state = VGUI_STATE_HOVER;
    theme.DrawButton(g_uioOrigin+pos,size,state);
    if (size[0]<30) UIO_Line(pos+[3,5],size-[4,5],text,!enabled);
    else UIO_Text(pos+[8,6],size-[12,6],text,!enabled);
    if (h == g_uioFocus && enabled)
        UIO_Outline(pos+[2,2],size-[4,4],[0.8,0.7,0.35]);
    UIO_Hit(kind,index,pos,size,enabled);
}

void UIO_DrawSetting(int i)
{
    if (g_uio[i].kind == UIO_COLOR) { UIOMP_DrawColor(i); return; }
    vector p = g_uio[i].pos, s = g_uio[i].size;
    bool enabled = g_uio[i].supported;
    bool focused = g_uioFocus == g_uioHitCount;
    string title = g_uio[i].title;
    bool noModels=i==g_uioModel && g_uio[i].unavailable;
    if (!enabled && !noModels) title = strcat(title," (unavailable)");
    if (g_uio[i].kind == UIO_CHECK) {
        bool checked = g_uio[i].key == "m_pitch" ? stof(g_uio[i].value) < 0 : stof(g_uio[i].value) != 0;
        UIO_Rect(p+[0,3],[14,14],[0,0,0],0.5);
        UIO_Outline(p+[0,3],[14,14],[0.55,0.55,0.55]);
        if (checked) UIO_Text(p+[3,3],[12,14],"x",!enabled);
        UIO_Text(p+[24,4],s-[24,0],title,!enabled);
    } else {
        if (title) UIO_Line(p-[0,22],[s[0],20],title,!enabled);
        if (g_uio[i].kind == UIO_SLIDER) {
            float value = stof(g_uio[i].value);
            float track = s[0]-64;
            float ratio = bound(0,(value-g_uio[i].low)/(g_uio[i].high-g_uio[i].low),1);
            UIO_Rect(p+[0,10],[track,4],[0,0,0],0.7);
            UIO_Rect(p+[0,11],[track*ratio,2],[0.65,0.66,0.54],1);
            vguiTheme theme = g_uioWindow.GetTheme();
            theme.DrawButton(g_uioOrigin+p+[ratio*(track-10),2],[10,20],
                enabled ? VGUI_STATE_NORMAL : VGUI_STATE_DISABLED);
            string number;
            if (g_uio[i].step>=1) number=sprintf("%.0f",value);
            else if (g_uio[i].step>=0.1) number=sprintf("%.1f",value);
            else number=sprintf("%.2f",value);
            UIO_Line(p+[track+12,5],[54,20],number,!enabled);
        } else {
            UIO_Rect(p,s,[0,0,0],0.4);
            UIO_Outline(p,s,[0.4,0.4,0.4]);
            string text = g_uio[i].kind == UIO_CHOICE ? UIO_ChoiceLabel(i) : g_uio[i].value;
            if (!enabled) text = noModels ? "None installed" : "Not supported by this build";
            vector textsize = s-[18,6];
            if (g_uio[i].kind == UIO_CHOICE) {
                textsize[0]-=20;
                UIO_Text(p+[s[0]-18,6],[16,18],"v",!enabled);
            }
            if (g_uio[i].kind == UIO_TEXT && focused && g_uioSelectAll)
                UIO_Rect(p+[4,3],s-[8,6],[0.35,0.4,0.3],1);
            UIO_Line(p+[7,6],textsize,text,!enabled);
            if (g_uio[i].kind == UIO_TEXT && focused && (rint(time*2)&1)) {
                float cx = Font_StringWidth(substring(text,0,g_uioTextCursor),FALSE,g_fntDefault);
                UIO_Rect(p+[7+UIO_Min(cx,s[0]-12),4],[1,15],[1,1,1],1);
            }
        }
    }
    if (focused && enabled) UIO_Outline(p-[2,2],s+[4,4],[0.8,0.7,0.35]);
    UIO_Hit(UIO_H_SETTING,i,p,s,enabled);
}

void UIO_KeyEnsureVisible(void)
{
    if (g_uioKeyRow < g_uioKeyOffset) g_uioKeyOffset=g_uioKeyRow;
    if (g_uioKeyRow >= g_uioKeyOffset+UIO_KEY_ROWS) g_uioKeyOffset=g_uioKeyRow-UIO_KEY_ROWS+1;
    g_uioKeyOffset=bound(0,g_uioKeyOffset,UIO_Max(0,g_uioActionCount-UIO_KEY_ROWS));
}

void UIO_DrawKeys(void)
{
    UIO_Rect([24,76],[456,260],[0,0,0],0.4);
    UIO_Outline([24,76],[456,260],[0.45,0.45,0.45]);
    UIO_Text([32,80],[228,18],"Action",false);
    UIO_Text([272,80],[98,18],"Key / button",false);
    UIO_Text([378,80],[96,18],"Alternate",false);
    UIO_Rect([24,96],[456,1],[0.4,0.4,0.4],1);
    for (int r=0; r<UIO_KEY_ROWS; r++) {
        int row=r+g_uioKeyOffset;
        if (row>=g_uioActionCount) break;
        vector pos=[26,98+r*19];
        bool bindable=!!g_uioAction[row];
        if (row==g_uioKeyRow && bindable) {
            UIO_Rect(pos,[438,19],[0.35,0.39,0.3],1);
            UIO_Outline([g_uioKeyColumn ? 374 : 268,pos[1]],[g_uioKeyColumn ? 90 : 106,19],
                g_uioCapture>=0 ? [1,0.6,0.15] : [0.68,0.7,0.6]);
        }
        UIO_Line(pos+[6,3],[232,18],g_uioActionLabel[row],!bindable);
        if (bindable) {
            for (int col=0; col<2; col++) {
                int key=UIO_BoundKey(row,col);
                string text=UIO_KeyLabel(key);
                if (g_uioCapture==row && col==g_uioKeyColumn) text="Press key...";
                UIO_Line([col ? 380 : 274,pos[1]+3],[col ? 80 : 98,18],text,false);
            }
            UIO_Hit(UIO_H_ROW,row,pos,[438,19],true);
        }
    }
    UIO_Button(UIO_H_SCROLLUP,0,[464,98],[14,20],"^",g_uioKeyOffset>0);
    UIO_Button(UIO_H_SCROLLDOWN,0,[464,314],[14,20],"v",g_uioKeyOffset<g_uioActionCount-UIO_KEY_ROWS);
    float fraction=(float)UIO_KEY_ROWS/UIO_Max(UIO_KEY_ROWS,g_uioActionCount);
    float thumb=UIO_Max(20,194*fraction);
    float offset=(194-thumb)*g_uioKeyOffset/UIO_Max(1,g_uioActionCount-UIO_KEY_ROWS);
    UIO_Rect([468,118+offset],[6,thumb],[0.55,0.58,0.5],1);
    UIO_Button(UIO_H_DEFAULTS,0,[24,344],[120,24],"Use defaults",true);
    UIO_Button(UIO_H_BIND,0,[248,344],[110,24],"Change key",true);
    UIO_Button(UIO_H_CLEAR,0,[370,344],[110,24],"Clear key",UIO_BoundKey(g_uioKeyRow,g_uioKeyColumn)>=0);
    UIO_Text([24,376],[456,22],g_uioCapture>=0 ? "Press a key or mouse button. Escape cancels capture."
        : "Select a key column. Enter / double-click changes it; Delete clears.",false);
}

vector UIO_PopupPos(void)
{
    vector p=g_uio[g_uioPopup].pos;
    int rows=UIO_Min(UIO_POPUP_ROWS,UIO_Parts(g_uio[g_uioPopup].values));
    p[1]+=g_uio[g_uioPopup].size[1]+1;
    if (p[1]+rows*22+4>404) p[1]=g_uio[g_uioPopup].pos[1]-rows*22-4;
    return p;
}

void UIO_DrawPopup(void)
{
    if (g_uioPopup<0) return;
    vector p=UIO_PopupPos();
    int count=UIO_Parts(g_uio[g_uioPopup].values);
    int rows=UIO_Min(UIO_POPUP_ROWS,count);
    vector size=[g_uio[g_uioPopup].size[0],rows*22+4];
    UIO_Rect(p,size,[0.12,0.14,0.11],1);
    UIO_Outline(p,size,[0.7,0.72,0.65]);
    for (int row=0; row<rows; row++) {
        int index=row+g_uioPopupOffset;
        vector rp=p+[2,2+row*22];
        if (UIO_Over(rp,[size[0]-4,22]) || index==g_uioPopupSelection)
            UIO_Rect(rp,[size[0]-4,22],[0.35,0.39,0.3],1);
        UIO_Line(rp+[6,5],[size[0]-18,20],UIO_Part(g_uio[g_uioPopup].labels,index),false);
    }
    if (count>rows) UIO_Text(p+[size[0]-16,size[1]-18],[14,14],"v",false);
}

void UIO_DrawModal(void)
{
    if (!g_uioVideoPending && !g_uioDefaultsConfirm) return;
    UIO_Rect([0,28],[UIO_W,UIO_H-28],[0,0,0],0.65);
    UIO_Rect([56,148],[392,150],[0.2,0.23,0.18],1);
    UIO_Outline([56,148],[392,150],[0.7,0.72,0.65]);
    if (g_uioVideoPending) {
        UIO_Text([76,166],[352,28],"Keep these display settings?",false);
        UIO_Text([76,198],[352,38],sprintf("Reverting automatically in %d seconds.",ceil(UIO_Max(0,g_uioVideoDeadline-time))),false);
        UIO_Rect([80,252],[144,26],[0.35,0.4,0.3],1);
        UIO_Text([92,258],[126,20],"Keep settings",false);
        UIO_Rect([274,252],[144,26],[0.3,0.33,0.27],1);
        UIO_Text([288,258],[126,20],"Revert",false);
    } else {
        UIO_Text([76,166],[352,28],"Restore default key bindings?",false);
        UIO_Text([76,198],[352,44],"This edits the key list. Apply saves it; Cancel still discards it.",false);
        UIO_Rect([80,252],[144,26],[0.35,0.4,0.3],1);
        UIO_Text([92,258],[126,20],"Use defaults",false);
        UIO_Rect([274,252],[144,26],[0.3,0.33,0.27],1);
        UIO_Text([288,258],[126,20],"Cancel",false);
    }
}

void UIO_Draw(void)
{
    g_uioOrigin=g_uioWindow.GetPos();
    g_uioHitCount=0;
    for (int tab=0; tab<6; tab++) {
        vector p=[12+tab*80,30];
        UIO_Button(UIO_H_TAB,tab,p,[78,26],UIO_Part("Keyboard|Mouse|Audio|Video|Voice|Multiplayer",tab),true);
        if (tab==g_uioPage) UIO_Rect(p+[1,24],[76,2],[0.85,0.77,0.45],1);
    }
    UIO_Outline([12,58],[480,344],[0.37,0.4,0.34]);
    if (g_uioPage==UIO_KEYBOARD) UIO_DrawKeys();
    else if (g_uioPage==UIO_MULTI) UIOMP_Draw();
    else {
        for (int i=0; i<g_uioCount; i++)
            if (g_uio[i].page==g_uioPage) UIO_DrawSetting(i);
        if (g_uioPage==UIO_VIDEO)
            UIO_Text([30,370],[444,26],"Display changes require confirmation. Borderless uses desktop size.",true);
        if (g_uioPage==UIO_AUDIO)
            UIO_Text([36,352],[424,36],"Sound quality takes effect on newly loaded sounds.",true);
        if (g_uioPage==UIO_VOICE) {
            UIO_Button(UIO_H_MIC,0,[36,350],[156,24],g_uioMicTesting ? "Stop microphone test" : "Test microphone",
                UIO_Available("cl_voip_test") && UIO_Available("cl_voip_micamp"));
            UIO_Text([208,348],[256,44],"Local playback only. Set push-to-talk on the Keyboard tab.",true);
        }
    }
    UIO_Rect([12,405],[480,1],[0.37,0.4,0.34],1);
    UIO_Button(UIO_H_OK,0,[252,414],[72,24],"OK",true);
    UIO_Button(UIO_H_CANCEL,0,[332,414],[72,24],"Cancel",true);
    UIO_Button(UIO_H_APPLY,0,[412,414],[80,24],"Apply",UIO_Dirty());
    UIO_Text([18,415],[222,25],g_uioStatus == "Player name is required." ? g_uioStatus :
        (UIO_Dirty() ? "Unsaved changes" : "Settings are up to date"),true);
    if (g_uioMPAdvanced) UIOMP_DrawAdvanced();
    UIO_DrawPopup();
    UIO_DrawModal();
}

void UIO_StopMic(void)
{
    if (!g_uioMicTesting) return;
    cvar_set("cl_voip_test",g_uioMicOldTest);
    cvar_set("cl_voip_play",g_uioMicOldPlay);
    cvar_set("cl_voip_micamp",g_uioMicOldGain);
    g_uioMicTesting=false;
}

void UIO_ToggleMic(void)
{
    if (g_uioMicTesting) { UIO_StopMic(); return; }
    if (!UIO_Available("cl_voip_test")) return;
    g_uioMicOldTest=cvar_string("cl_voip_test");
    g_uioMicOldPlay=cvar_string("cl_voip_play");
    g_uioMicOldGain=cvar_string("cl_voip_micamp");
    cvar_set("cl_voip_play",g_uio[UIO_Find("cl_voip_play")].value);
    cvar_set("cl_voip_micamp",g_uio[UIO_Find("cl_voip_micamp")].value);
    cvar_set("cl_voip_test","1");
    g_uioMicTesting=true;
}

void UIO_SetPage(int page)
{
    if (g_uioMPAdvanced) UIOMP_CloseAdvanced(false);
    UIO_StopMic();
    g_uioPage=bound(0,page,5);
    g_uioCapture=-1;
    g_uioPopup=-1;
    g_uioSlider=-1;
    g_uioFocus=-1;
    g_uioPressed=-1;
    g_uioSelectAll=false;
}

void UIO_Save(void)
{
    /* No arbitrary filename: cfg_save without arguments is allowed from MenuQC. */
    localcmd("cfg_save\n");
}

void UIO_KeepVideo(void)
{
    if (!g_uioVideoPending) return;
    g_uioVideoPending=false;
    UIO_LoadSnapshot();
    UIO_Save();
    if (g_uioCloseAfterApply) g_uioWindow.Hide();
}

void UIO_RevertVideo(void)
{
    if (!g_uioVideoPending) return;
    g_uioVideoPending=false;
    cvar_set("vid_width",g_uioOldWidth);
    cvar_set("vid_height",g_uioOldHeight);
    cvar_set("vid_fullscreen",g_uioOldFullscreen);
    cvar_set("vid_vsync",g_uioOldVsync);
    for (int i=0; i<g_uioCount; i++)
        if (UIO_IsMode(i)) g_uio[i].value=g_uio[i].original;
    g_uioCloseAfterApply=false;
    g_uioStatus="Previous display settings restored.";
    localcmd("vid_restart\n");
    UIO_Save();
}

void UIO_Apply(bool closeAfter)
{
    UIO_StopMic();
    g_uioPopup=-1;
    if (g_uioVideoPending) return;
    if (!UIO_Dirty()) {
        if (closeAfter) g_uioWindow.Hide();
        return;
    }
    int name=UIO_Find("name");
    if (g_uio[name].supported && !g_uio[name].value) {
        UIO_SetPage(UIO_MULTI);
        g_uioStatus="Player name is required.";
        return;
    }
    if (!UIOMP_ApplySpray()) return;
    bool videoChange=false;
    for (int i=0; i<g_uioCount; i++)
        if (UIO_IsMode(i) && g_uio[i].supported && g_uio[i].value!=g_uio[i].original)
            videoChange=true;
    if (videoChange) {
        g_uioOldWidth=cvar_string("vid_width");
        g_uioOldHeight=cvar_string("vid_height");
        g_uioOldFullscreen=cvar_string("vid_fullscreen");
        g_uioOldVsync=cvar_string("vid_vsync");
    }
    for (int i=0; i<g_uioCount; i++) {
        if (!g_uio[i].supported || g_uio[i].value==g_uio[i].original) continue;
        if (g_uio[i].key=="$resolution") {
            if (tokenizebyseparator(g_uio[i].value,"x") == 2) {
                string width=argv(0), height=argv(1);
                cvar_set("vid_width",width); cvar_set("vid_height",height);
            }
        } else if (g_uio[i].kind==UIO_COLOR) {
            cvar_set(g_uio[i].key,UIOMP_ColorToEngine(stof(g_uio[i].value)));
        } else if (g_uio[i].key!="$spray" && g_uio[i].key!="$spraycolor") {
            cvar_set(g_uio[i].key,g_uio[i].value);
            if (g_uio[i].page==UIO_MULTI_ADVANCED)
                localcmd(sprintf("seta %s %S\n",g_uio[i].key,g_uio[i].value));
            /* Unlike the other controls, FTE's raw-input cvar is not archived
             * by default. Save the explicit toggle for the next launch. */
            if (g_uio[i].key=="in_rawinput")
                localcmd(sprintf("seta in_rawinput %i\n",(int)(stof(g_uio[i].value)!=0)));
        }
        if (!UIO_IsMode(i)) g_uio[i].original=g_uio[i].value;
    }
    for (int k=0; k<UIO_KEYS; k++) {
        if (g_uioBind[k]==g_uioBindOriginal[k]) continue;
        setkeybind(k,g_uioBind[k],0,0);
        g_uioBindOriginal[k]=g_uioBind[k];
    }
    if (videoChange) {
        g_uioVideoPending=true;
        g_uioVideoDeadline=time+15;
        g_uioCloseAfterApply=closeAfter;
        localcmd("vid_restart\n");
        return;
    }
    UIO_Save();
    g_uioStatus="Settings saved.";
    if (closeAfter) g_uioWindow.Hide();
}

void UIO_Cancel(void)
{
    UIO_StopMic();
    UIO_RevertVideo();
    g_uioCapture=-1;
    g_uioPopup=-1;
    g_uioSlider=-1;
    g_uioDefaultsConfirm=false;
    if (g_uioWindow) g_uioWindow.Hide();
}

void UIO_Defaults(void)
{
    filestream f=fopen("scripts/kb_def.lst",FILE_READ);
    if (f<0) f=fopen("gfx/shell/kb_def.lst",FILE_READ);
    if (f<0) { g_uioStatus="No default key file was found for this game."; return; }
    /* Preserve unrelated binds. Do not run unbindall or execute a config file. */
    for (int k=0; k<UIO_KEYS; k++) {
        for (int row=0; row<g_uioActionCount; row++) {
            if (g_uioAction[row] && g_uioBind[k]==g_uioAction[row]) {
                g_uioBind[k]="";
                break;
            }
        }
    }
    string line;
    while ((line=fgets(f))) {
        if (tokenize_console(line)<2) continue;
        string keyname=argv(0), command=argv(1);
        int key=stringtokeynum(keyname);
        if (key<=0 || key>=UIO_KEYS || key==K_ESCAPE) continue;
        command=UIO_Command(command);
        for (int row=0; row<g_uioActionCount; row++) {
            if (g_uioAction[row] && command==g_uioAction[row]) {
                g_uioBind[key]=command;
                break;
            }
        }
    }
    fclose(f);
    g_uioStatus="Default bindings loaded into the list. Apply saves them.";
}

void UIO_ClearKey(void)
{
    int key=UIO_BoundKey(g_uioKeyRow,g_uioKeyColumn);
    if (key>=0) g_uioBind[key]="";
}

void UIO_CaptureKey(int key)
{
    if (key==K_ESCAPE) { g_uioCapture=-1; return; }
    if (key<=0 || key>=UIO_KEYS) return;
    if (g_uioBind[key]=="toggleconsole") {
        g_uioStatus="The console key is reserved. Choose another key.";
        return;
    }
    int previous=UIO_BoundKey(g_uioCapture,g_uioKeyColumn);
    if (previous>=0) g_uioBind[previous]="";
    g_uioBind[key]=g_uioAction[g_uioCapture];
    g_uioCapture=-1;
    g_uioStatus="Key binding changed. Apply saves it.";
}

void UIO_SliderFromMouse(int i)
{
    float track=g_uio[i].size[0]-(g_uio[i].kind==UIO_COLOR ? 0 : 64);
    float x=g_vecMousePos[0]-g_uioOrigin[0]-g_uio[i].pos[0];
    float ratio=bound(0,(x-5)/UIO_Max(1,track-10),1);
    float value=g_uio[i].low+ratio*(g_uio[i].high-g_uio[i].low);
    value=g_uio[i].low+rint((value-g_uio[i].low)/g_uio[i].step)*g_uio[i].step;
    UIO_Set(i,ftos(bound(g_uio[i].low,value,g_uio[i].high)));
}

void UIO_ActivateSetting(int i)
{
    if (g_uio[i].kind==UIO_CHECK) {
        float old=stof(g_uio[i].value);
        if (g_uio[i].key=="m_pitch") UIO_Set(i,ftos(old ? -old : -0.022));
        else UIO_Set(i,old ? "0" : "1");
    } else if (g_uio[i].kind==UIO_CHOICE) {
        if (!UIO_Parts(g_uio[i].values)) return;
        g_uioPopup=i;
        g_uioPopupSelection=UIO_Max(0,UIO_SelectedChoice(i));
        g_uioPopupOffset=bound(0,g_uioPopupSelection,UIO_Max(0,UIO_Parts(g_uio[i].values)-UIO_POPUP_ROWS));
    } else if (g_uio[i].kind==UIO_TEXT) {
        g_uioTextCursor=strlen(g_uio[i].value);
        g_uioSelectAll=true;
    }
}

void UIO_ActivateHit(int h)
{
    if (h<0 || h>=g_uioHitCount) return;
    if (!g_uioHits[h].enabled) return;
    int index=g_uioHits[h].index;
    switch (g_uioHits[h].kind) {
    case UIO_H_TAB: UIO_SetPage(index); break;
    case UIO_H_SETTING: UIO_ActivateSetting(index); break;
    case UIO_H_APPLY: UIO_Apply(false); break;
    case UIO_H_OK: UIO_Apply(true); break;
    case UIO_H_CANCEL: UIO_Cancel(); break;
    case UIO_H_BIND: g_uioCapture=g_uioKeyRow; break;
    case UIO_H_CLEAR: UIO_ClearKey(); break;
    case UIO_H_DEFAULTS: g_uioDefaultsConfirm=true; break;
    case UIO_H_MIC: UIO_ToggleMic(); break;
    case UIO_H_ADVANCED: UIOMP_OpenAdvanced(); break;
    case UIO_H_ADV_OK: UIOMP_CloseAdvanced(true); break;
    case UIO_H_ADV_CANCEL: UIOMP_CloseAdvanced(false); break;
    case UIO_H_ADV_SCROLL: UIOMP_ScrollAdvanced(index); break;
    case UIO_H_SCROLLUP: g_uioKeyOffset=UIO_Max(0,g_uioKeyOffset-1); break;
    case UIO_H_SCROLLDOWN: g_uioKeyOffset=UIO_Min(UIO_Max(0,g_uioActionCount-UIO_KEY_ROWS),g_uioKeyOffset+1); break;
    case UIO_H_ROW:
        g_uioKeyRow=index;
        g_uioKeyColumn=(g_vecMousePos[0]-g_uioOrigin[0]>=374) ? 1 : 0;
        if (g_uioLastRow==index && time-g_uioLastClick<0.35) g_uioCapture=index;
        g_uioLastRow=index; g_uioLastClick=time;
        break;
    }
}

bool UIO_EditText(int i, float key, float ch)
{
    string text=g_uio[i].value;
    int len=strlen(text);
    if (g_uioCtrl && (key==97 || key==65)) { g_uioSelectAll=true; return true; }
    if (key==K_LEFTARROW) { g_uioTextCursor=UIO_Max(0,g_uioTextCursor-1); g_uioSelectAll=false; return true; }
    if (key==K_RIGHTARROW) { g_uioTextCursor=UIO_Min(len,g_uioTextCursor+1); g_uioSelectAll=false; return true; }
    if (key==K_HOME) { g_uioTextCursor=0; g_uioSelectAll=false; return true; }
    if (key==K_END) { g_uioTextCursor=len; g_uioSelectAll=false; return true; }
    if (key==K_BACKSPACE || key==K_DEL) {
        if (g_uioSelectAll) { UIO_Set(i,""); g_uioTextCursor=0; }
        else if (key==K_BACKSPACE && g_uioTextCursor>0) {
            UIO_Set(i,strcat(substring(text,0,g_uioTextCursor-1),substring(text,g_uioTextCursor,-1)));
            g_uioTextCursor--;
        } else if (key==K_DEL && g_uioTextCursor<len)
            UIO_Set(i,strcat(substring(text,0,g_uioTextCursor),substring(text,g_uioTextCursor+1,-1)));
        g_uioSelectAll=false;
        return true;
    }
    if (!g_uioCtrl && ch>=32 && ch!=127) {
        if (g_uioSelectAll) { text=""; len=0; g_uioTextCursor=0; }
        int limit = g_uio[i].key=="name" ? g_uioNameLimit : 31;
        if (len<limit) {
            UIO_Set(i,strcat(substring(text,0,g_uioTextCursor),chr2str(ch),substring(text,g_uioTextCursor,-1)));
            g_uioTextCursor++;
        }
        g_uioSelectAll=false;
        return true;
    }
    return false;
}

void UIO_NavigateKeys(int direction)
{
    int row=g_uioKeyRow;
    while (true) {
        row+=direction;
        if (row<0 || row>=g_uioActionCount) break;
        if (g_uioAction[row]) break;
    }
    if (row>=0 && row<g_uioActionCount) g_uioKeyRow=row;
    UIO_KeyEnsureVisible();
}

bool UIO_Input(float type, float key, float ch, float device)
{
    g_uioOrigin=g_uioWindow.GetPos();
    if (g_uioVideoPending || g_uioDefaultsConfirm) {
        if (type==IE_KEYUP && key==K_MOUSE1)
            if (UIO_Over([UIO_W-24,4],[20,20])) { UIO_Cancel(); return true; }
        if (type==IE_KEYDOWN && (key==K_ESCAPE || key==K_ENTER)) {
            bool accept=key==K_ENTER;
            if (g_uioVideoPending) { if (accept) UIO_KeepVideo(); else UIO_RevertVideo(); }
            else { g_uioDefaultsConfirm=false; if (accept) UIO_Defaults(); }
        } else if (type==IE_KEYUP && key==K_MOUSE1) {
            if (UIO_Over([80,252],[144,26])) {
                if (g_uioVideoPending) UIO_KeepVideo();
                else { g_uioDefaultsConfirm=false; UIO_Defaults(); }
            } else if (UIO_Over([274,252],[144,26])) {
                if (g_uioVideoPending) UIO_RevertVideo();
                else g_uioDefaultsConfirm=false;
            }
        }
        return true;
    }
    if (g_uioCapture>=0) {
        if (type==IE_KEYDOWN) UIO_CaptureKey(key);
        return true;
    }
    if (g_uioPopup>=0) {
        int count=UIO_Parts(g_uio[g_uioPopup].values);
        int rows=UIO_Min(UIO_POPUP_ROWS,count);
        vector p=UIO_PopupPos();
        if (type==IE_KEYDOWN) {
            if (key==K_ESCAPE) { g_uioPopup=-1; return true; }
            if (key==K_MWHEELDOWN || key==K_MWHEELUP) {
                g_uioPopupOffset=bound(0,g_uioPopupOffset+(key==K_MWHEELDOWN ? 1 : -1),UIO_Max(0,count-rows));
                return true;
            }
            if (key==K_DOWNARROW || key==K_UPARROW) {
                g_uioPopupSelection=bound(0,g_uioPopupSelection+(key==K_DOWNARROW ? 1 : -1),count-1);
                if (g_uioPopupSelection<g_uioPopupOffset) g_uioPopupOffset=g_uioPopupSelection;
                if (g_uioPopupSelection>=g_uioPopupOffset+rows) g_uioPopupOffset=g_uioPopupSelection-rows+1;
            }
            if (key==K_ENTER) {
                UIO_Set(g_uioPopup,UIO_Part(g_uio[g_uioPopup].values,g_uioPopupSelection));
                g_uioPopup=-1;
                return true;
            }
            if (key==K_MOUSE1 && !UIO_Over(p,[g_uio[g_uioPopup].size[0],rows*22+4])) g_uioPopup=-1;
        } else if (type==IE_KEYUP && key==K_MOUSE1) {
            if (UIO_Over(p,[g_uio[g_uioPopup].size[0],rows*22+4])) {
                int row=floor((g_vecMousePos[1]-g_uioOrigin[1]-p[1]-2)/22);
                row=bound(0,row,rows-1)+g_uioPopupOffset;
                UIO_Set(g_uioPopup,UIO_Part(g_uio[g_uioPopup].values,row));
            }
            g_uioPopup=-1;
        }
        return true;
    }
    if (g_uioSlider>=0) {
        if (type==IE_MOUSEABS || type==IE_MOUSEDELTA) UIO_SliderFromMouse(g_uioSlider);
        if (type==IE_KEYUP && key==K_MOUSE1) { g_uioSlider=-1; g_uioPressed=-1; }
        return true;
    }
    if (g_uioMPAdvanced && type==IE_KEYDOWN) {
        if (key==K_ESCAPE) { UIOMP_CloseAdvanced(false); return true; }
        if (key==K_MWHEELUP || key==K_MWHEELDOWN) {
            UIOMP_ScrollAdvanced(key==K_MWHEELDOWN ? 1 : -1); return true;
        }
    }
    if (type==IE_KEYDOWN && key==K_ESCAPE) { UIO_Cancel(); return true; }
    if (type==IE_KEYDOWN && key==K_TAB) {
        if (g_uioHitCount<=0) return true;
        int direction=g_uioShift ? -1 : 1;
        for (int n=0; n<g_uioHitCount; n++) {
            g_uioFocus=(g_uioFocus+direction+g_uioHitCount)%g_uioHitCount;
            if (g_uioHits[g_uioFocus].enabled) break;
        }
        if (g_uioHits[g_uioFocus].kind==UIO_H_SETTING) {
            int tabSetting=g_uioHits[g_uioFocus].index;
            if (g_uio[tabSetting].kind==UIO_TEXT) { g_uioTextCursor=strlen(g_uio[tabSetting].value); g_uioSelectAll=true; }
        }
        return true;
    }
    if (type==IE_KEYDOWN && g_uioFocus>=0 && g_uioFocus<g_uioHitCount)
    if (g_uioHits[g_uioFocus].kind==UIO_H_SETTING) {
        int i=g_uioHits[g_uioFocus].index;
        if (g_uio[i].kind==UIO_TEXT)
            if (UIO_EditText(i,key,ch)) return true;
        if ((g_uio[i].kind==UIO_SLIDER || g_uio[i].kind==UIO_COLOR) && (key==K_LEFTARROW || key==K_RIGHTARROW)) {
            float value=stof(g_uio[i].value)+(key==K_RIGHTARROW ? g_uio[i].step : -g_uio[i].step);
            UIO_Set(i,ftos(bound(g_uio[i].low,value,g_uio[i].high)));
            return true;
        }
    }
    if (type==IE_KEYDOWN && g_uioPage==UIO_KEYBOARD) {
        if (key==K_MWHEELUP || key==K_MWHEELDOWN) {
            g_uioKeyOffset=bound(0,g_uioKeyOffset+(key==K_MWHEELDOWN ? 3 : -3),UIO_Max(0,g_uioActionCount-UIO_KEY_ROWS));
            return true;
        }
        bool listFocus=g_uioFocus<0;
        if (g_uioFocus>=0 && g_uioFocus<g_uioHitCount)
            listFocus=g_uioHits[g_uioFocus].kind==UIO_H_ROW;
        if (listFocus) {
            if (key==K_UPARROW || key==K_DOWNARROW) { UIO_NavigateKeys(key==K_DOWNARROW ? 1 : -1); return true; }
            if (key==K_PGUP || key==K_PGDN) {
                for (int n=0;n<UIO_KEY_ROWS;n++) UIO_NavigateKeys(key==K_PGDN ? 1 : -1);
                return true;
            }
            if (key==K_HOME || key==K_END) {
                g_uioKeyRow=key==K_HOME ? 0 : g_uioActionCount-1;
                if (!g_uioAction[g_uioKeyRow]) UIO_NavigateKeys(key==K_HOME ? 1 : -1);
                UIO_KeyEnsureVisible(); return true;
            }
            if (key==K_LEFTARROW || key==K_RIGHTARROW) { g_uioKeyColumn=key==K_RIGHTARROW ? 1 : 0; return true; }
            if (key==K_DEL) { UIO_ClearKey(); return true; }
            if (key==K_ENTER) { g_uioCapture=g_uioKeyRow; return true; }
        }
    }
    if (type==IE_KEYDOWN && (key==K_ENTER || key==K_SPACE) && g_uioFocus>=0) {
        UIO_ActivateHit(g_uioFocus); return true;
    }
    if (type==IE_KEYDOWN && key==K_MOUSE1) {
        g_uioPressed=-1;
        for (int h=g_uioHitCount-1; h>=0; h--) {
            if (!UIO_Over(g_uioHits[h].pos,g_uioHits[h].size)) continue;
            if (!g_uioHits[h].enabled) return true;
            g_uioPressed=h; g_uioFocus=h; g_uioSelectAll=false;
            if (g_uioHits[h].kind==UIO_H_SETTING) {
                int clickSetting=g_uioHits[h].index;
                if (g_uio[clickSetting].kind==UIO_SLIDER || g_uio[clickSetting].kind==UIO_COLOR) { g_uioSlider=clickSetting; UIO_SliderFromMouse(clickSetting); }
            }
            return true;
        }
        g_uioFocus=-1;
    } else if (type==IE_KEYUP && key==K_MOUSE1) {
        int h=g_uioPressed;
        g_uioPressed=-1;
        if (h>=0 && h<g_uioHitCount)
        if (UIO_Over(g_uioHits[h].pos,g_uioHits[h].size)) {
            UIO_ActivateHit(h); return true;
        }
    }
    return g_uioMPAdvanced;
}

void uioOptionsWindow::Draw(void)
{
    super::Draw();
    UIO_Draw();
    if (g_uioStatus) {
        /* A short status line is drawn below the sheet when screen room permits. */
        if (g_vidsize[1]>=UIO_H+60)
            UIO_Text([12,UIO_H+5],[480,22],g_uioStatus,false);
    }
}

bool uioOptionsWindow::Input(float type, float key, float ch, float device)
{
    if (UIO_Input(type,key,ch,device)) return true;
    return super::Input(type,key,ch,device);
}

void uioOptionsWindow::Reposition(void)
{
    SetPos([UIO_Max(0,floor((g_vidsize[0]-UIO_W)/2)),UIO_Max(0,floor((g_vidsize[1]-UIO_H)/2))]);
}

void uioOptionsWindow::NowHidden(void)
{
    if (g_uioMPAdvanced) UIOMP_CloseAdvanced(false);
    UIO_StopMic();
    UIO_RevertVideo();
    g_uioCapture=-1; g_uioPopup=-1; g_uioSlider=-1;
    g_uioDefaultsConfirm=false;
}

void UI_Options_Show(void)
{
    if (!g_uioWindow) {
        g_uioWindow=spawn(uioOptionsWindow);
        g_uioWindow.SetTitle("Options");
        g_uioWindow.SetIcon("gfx/icon16/cog");
        g_uioWindow.SetSize([UIO_W,UIO_H]);
        g_uioWindow.SetStyleMask(vguiWindowTitled | vguiWindowClosable | vguiWindowMovable);
        g_uiDesktop.Add(g_uioWindow);
        UIO_CreateSettings();
        UIO_LoadActions();
    } else if (g_uioWindow.Visible()) {
        g_uioWindow.Focus();
        return;
    }
    UIO_SetPage(UIO_KEYBOARD);
    UIO_LoadSnapshot();
    g_uioWindow.Reposition();
    g_uioWindow.Show();
}

void UI_Options_Frame(void)
{
    if (g_uioVideoPending && time>=g_uioVideoDeadline) UIO_RevertVideo();
}

/* Called before the general menu's Escape handler. */
bool UI_Options_InputEvent(float type, float key, float ch, float device)
{
    if (type==IE_KEYDOWN || type==IE_KEYUP) {
        if (key==stringtokeynum("CTRL") || key==stringtokeynum("RCTRL"))
            g_uioCtrl=type==IE_KEYDOWN;
        if (key==stringtokeynum("SHIFT") || key==stringtokeynum("RSHIFT"))
            g_uioShift=type==IE_KEYDOWN;
    }
    if (!g_uioWindow) return false;
    if (!g_uioWindow.Visible()) return false;
    if (g_uioCapture<0 && type==IE_KEYDOWN && getkeybind(key,0,0)=="toggleconsole") return false;
    if (g_uioCapture>=0 || g_uioPopup>=0 || g_uioVideoPending || g_uioDefaultsConfirm || g_uioMPAdvanced ||
        (type==IE_KEYDOWN && key==K_ESCAPE))
        return g_uioWindow.Input(type,key,ch,device);
    return false;
}

void UI_Options_Close(void)
{
    if (g_uioWindow) UIO_Cancel();
}

#include "ui_options_multiplayer.qc"

#ifdef LAB_OPTIONS_TEST
#include "ui_options_tests.qc"
#endif
