/* QuakeC adaptation of Valve's BaseModUI title menu.
 * Behavioral references: vmainmenu.cpp, vhybridbutton.cpp, vflyoutmenu.cpp,
 * vfooterpanel.cpp and basemodframe.cpp in the supplied Alien Swarm SDK.
 * Authored geometry, navigation, styles, text and commands come from the
 * original Xbox resources; FTE service substitutions live in commands.qc.
 */
#define L4D_MAX_BUTTONS 96
#define L4D_MAX_FLYOUTS 8

class l4dHybridButton:vguiControl
{
public:
    void l4dHybridButton(void);
    virtual void Draw(void);
    string fieldName;
    string text;
    string helpText;
    string disabledHelpText;
    string command;
    string navUp;
    string navDown;
    string navLeft;
    string navRight;
    vector boundsPos;
    vector boundsSize;
    vector textInset;
    bool shown;
    bool available;
    int scope;
    int style;
    int activation;
    int id;
};

typedef struct {
    l4dResource resource;
    string fieldName;
    string initialFocus;
    vector pos;
    vector size;
    bool expandUp;
    int fromButton;
} l4dFlyout_t;

l4dHybridButton g_l4dButtons[L4D_MAX_BUTTONS];
l4dFlyout_t g_l4dFlyouts[L4D_MAX_FLYOUTS];
int g_l4dButtonCount, g_l4dFlyoutCount;
var int g_l4dFocus = -1;
var int g_l4dOpen = -1;
var int g_l4dPressed = -1;
float g_l4dPressedKey;
vector g_l4dOrigin, g_l4dExtent, g_l4dLastMouse;
vector g_l4dPointer;
float g_l4dScale, g_l4dPixel;
bool g_l4dLoaded, g_l4dController, g_l4dReady;
string g_l4dHelp, g_l4dLastAction, g_l4dNoticeTitle, g_l4dNoticeText;
bool g_l4dNotice;
l4dResource g_l4dScheme, g_l4dMain, g_l4dFooter;
hashtable g_l4dLocale;
float g_l4dMainFont, g_l4dMediumFont, g_l4dBoldFont;
float g_l4dMainHeight, g_l4dMediumHeight, g_l4dBoldHeight;
vector g_l4dGlyphPos[256], g_l4dGlyphSize[256], g_l4dGlyphABC[256];
float g_l4dNextSound;

void L4D_RunCommand(string command);
bool L4D_HasModal(void);
void L4D_OpenFlyout(int index, int from);

void l4dHybridButton::l4dHybridButton(void)
{
    shown = true;
    available = true;
    scope = -1;
    activation = 2; /* ACTIVATE_ONRELEASED on Xbox. */
}

string L4D_Text(string token)
{
    if (substring(token,0,1) != "#") return token;
    return (string)hash_get(g_l4dLocale, strtolower(token), token, EV_STRING);
}

void L4D_LoadLocale(string filename)
{
    filestream file = fopen(strcat("resource/l4d360/locale/",filename), FILE_READ);
    if (file < 0) return;
    string line;
    while ((line = fgets(file))) {
        int count = tokenize_console(line);
        if (count < 2 || substring(argv(0),0,2) == "//") continue;
        string key = argv(0), value = argv(1);
        bool apply = true;
        if (count > 2) {
            string condition = strtoupper(argv(2));
            if (condition == "[$WIN32]" || condition == "[$!X360]") apply = false;
        }
        if (apply) hash_add(g_l4dLocale, strtolower(strcat("#",key)), value, EV_STRING | HASH_REPLACE);
    }
    fclose(file);
}

vector L4D_Point(vector point)
{
    return g_l4dOrigin + point * g_l4dScale;
}

void L4D_Fill(vector pos, vector size, vector color, float alpha)
{
    if (size[0] <= 0 || size[1] <= 0 || alpha <= 0) return;
    drawfill(L4D_Point(pos), size * g_l4dScale, color, alpha);
}

void L4D_Fade(vector pos, vector size, vector color, float from, float to)
{
    /* DrawFilledRectFade: raster-aligned strips avoid seams at fractional scale. */
    vector at = L4D_Point(pos);
    vector end = at + size * g_l4dScale;
    float step = max(g_l4dPixel, 0.25);
    for (float x = at[0]; x < end[0]; x += step) {
        float t = bound(0, (x + step * 0.5 - at[0]) / max(end[0]-at[0],step), 1);
        drawfill([x,at[1]], [min(step,end[0]-x),end[1]-at[1]], color, from + (to-from)*t);
    }
}

float L4D_Width(string text, float font, float height)
{
    drawfont = font;
    float result = stringwidth(text, false, [height,height]);
    drawfont = 0;
    return result;
}

void L4D_DrawText(vector pos, string text, float font, float height, vector color, float alpha)
{
    drawfont = font;
    drawstring(L4D_Point(pos), text, [height,height] * g_l4dScale, color, alpha, 0);
    drawfont = 0;
}

string L4D_Ellipsis(string text, float font, float height, float width)
{
    if (L4D_Width(text,font,height) <= width) return text;
    while (strlen(text) && L4D_Width(strcat(text,"..."),font,height) > width)
        text = substring(text,0,strlen(text)-1);
    return strcat(text,"...");
}

void L4D_GlowText(vector pos, string text, float font, float height, vector color, float alpha)
{
    /* FTE lacks VGUI's blurred-font face. Sample the same glyph at a symmetric
     * radius of three authored pixels; the donor's glow timing/alpha is retained. */
    for (int y = -3; y <= 3; y++) for (int x = -3; x <= 3; x++) {
        float weight = pow(2.718281828,-(x*x+y*y)/4.5) / 13.65;
        L4D_DrawText(pos+[x,y],text,font,height,color,alpha*weight);
    }
}

void L4D_Sound(string name)
{
    if (name == "focus" && time < g_l4dNextSound) return;
    if (name == "focus") g_l4dNextSound = time + 0.08;
    string sound = strcat("l4d360/menu_",name,".wav");
    if (fileExists(strcat("sound/",sound))) localsound(sound);
}

int L4D_FindButton(string name, int scope)
{
    for (int i=0;i<g_l4dButtonCount;i++)
        if (g_l4dButtons[i].scope == scope && g_l4dButtons[i].fieldName == name) return i;
    return -1;
}

vector L4D_ButtonPos(int id)
{
    l4dHybridButton button = g_l4dButtons[id];
    if (button.scope >= 0) return g_l4dFlyouts[button.scope].pos + button.boundsPos;
    return button.boundsPos;
}

void L4D_SetFocus(int id, bool sound)
{
    /* QuakeC boolean expressions do not necessarily short-circuit. */
    if (id < 0 || id >= g_l4dButtonCount) return;
    if (!g_l4dButtons[id].shown) return;
    if (id != g_l4dFocus && sound) L4D_Sound("focus");
    g_l4dFocus = id;
    l4dHybridButton button = g_l4dButtons[id];
    g_l4dHelp = L4D_Text(button.available ? button.helpText : button.disabledHelpText);
}

void L4D_CloseFlyout(bool sound)
{
    if (g_l4dOpen < 0) return;
    int from = g_l4dFlyouts[g_l4dOpen].fromButton;
    g_l4dOpen = -1;
    L4D_SetFocus(from,false);
    if (sound) L4D_Sound("back");
}

void L4D_Navigate(int direction)
{
    if (g_l4dFocus < 0) return;
    int current = g_l4dFocus;
    int scope = g_l4dButtons[current].scope;
    /* Follow the resource's links, including through hidden Xbox/PC controls. */
    for (int attempt=0;attempt<g_l4dButtonCount;attempt++) {
        l4dHybridButton button = g_l4dButtons[current];
        string next = direction == 0 ? button.navUp : direction == 1 ? button.navDown :
                      direction == 2 ? button.navLeft : button.navRight;
        if (next == "") return;
        current = L4D_FindButton(next,scope);
        if (current < 0) return;
        if (g_l4dButtons[current].shown) { L4D_SetFocus(current,true); return; }
    }
}

void L4D_Activate(int id)
{
    if (id < 0 || id >= g_l4dButtonCount) return;
    l4dHybridButton button = g_l4dButtons[id];
    if (!button.available) { L4D_Sound("invalid"); return; }
    for (int i=0;i<g_l4dFlyoutCount;i++) {
        if (button.command == g_l4dFlyouts[i].fieldName) {
            L4D_Sound("accept");
            L4D_OpenFlyout(i,id);
            return;
        }
    }
    string command = button.command;
    L4D_CloseFlyout(false); /* donor closes and restores parent before OnCommand */
    L4D_Sound("accept");
    L4D_RunCommand(command);
}

void L4D_OpenFlyout(int index, int from)
{
    if (index < 0 || index >= g_l4dFlyoutCount || from < 0 || from >= g_l4dButtonCount) return;
    if (g_l4dOpen == index) { L4D_CloseFlyout(false); return; }
    L4D_CloseFlyout(false);
    l4dHybridButton button = g_l4dButtons[from];
    g_l4dFlyouts[index].fromButton = from;
    g_l4dFlyouts[index].pos = button.boundsPos + [button.boundsSize[0],0];
    if (g_l4dFlyouts[index].expandUp)
        g_l4dFlyouts[index].pos[1] -= g_l4dFlyouts[index].size[1] - button.boundsSize[1];
    g_l4dOpen = index;
    int initial = L4D_FindButton(g_l4dFlyouts[index].initialFocus,index);
    bool findInitial = initial < 0;
    if (initial >= 0) findInitial = !g_l4dButtons[initial].shown;
    if (findInitial)
        for (int i=0;i<g_l4dButtonCount;i++)
            if (g_l4dButtons[i].scope == index && g_l4dButtons[i].shown) { initial = i; break; }
    L4D_SetFocus(initial,false);
}

void l4dHybridButton::Draw(void)
{
    if (!shown) return;
    bool focused = id == g_l4dFocus;
    bool open = false;
    if (g_l4dOpen >= 0) open = g_l4dFlyouts[g_l4dOpen].fromButton == id;
    vector pos = L4D_ButtonPos(id);
    vector size = boundsSize;
    vector clipPos = L4D_Point(pos), clipSize = size*g_l4dScale;
    drawsetcliparea(clipPos[0],clipPos[1],clipSize[0],clipSize[1]);
    float font = style == 1 ? g_l4dMainFont : g_l4dMediumFont;
    float height = style == 1 ? g_l4dMainHeight : g_l4dMediumHeight;
    /* Restore the L4D grayscale constants retained in comments in the Swarm
     * donor; Swarm replaced these with its own blue game-specific palette. */
    vector color = available ? [125,125,125]/255 : [65,74,96]/255;
    if (open) color = [200,200,200]/255;
    if (focused) color = available ? [1,1,1] : [182,189,194]/255;
    float border = 2*g_l4dPixel/g_l4dScale;
    if (open) {
        L4D_Fade(pos,size,[0,0,0],0,1);
        float wide = min(size[0]-2*textInset[0], L4D_Width(L4D_Text(text),font,height))+40;
        L4D_Fade(pos+[textInset[0],0],[wide*0.25,size[1]],[0,0,0],0,150/255);
        L4D_Fade(pos+[textInset[0]+wide*0.25,0],[wide*0.75,size[1]],[0,0,0],150/255,0);
        L4D_Fade(pos,[size[0],border],[0,0,0],0,1);
        L4D_Fade(pos+[0,size[1]-border],[size[0],border],[0,0,0],0,1);
    }
    /* PaintButtonEx clamps measured textWide before its ellipsis comparison.
     * These main/flyout styles consequently print the full string and let
     * VGUI's panel scissor clip it. Do not introduce earlier shortening. */
    string label = L4D_Text(text);
    vector textPos = pos + textInset;
    float textAlpha = 1;
    if (focused && !available) textAlpha = 64.0/255.0;
    L4D_DrawText(textPos,label,font,height,color,textAlpha);
    if (focused || open) {
        float glow = focused ? 60+30*sin(time*4) : 30;
        vector glowColor = available ? [1,1,1] : color;
        L4D_GlowText(textPos,label,font,height,glowColor,available ? glow/255 : 1);
    }
    drawresetcliparea();
}

void L4D_DrawFlyout(void)
{
    if (g_l4dOpen < 0) return;
    vector pos = g_l4dFlyouts[g_l4dOpen].pos, size = g_l4dFlyouts[g_l4dOpen].size;
    float half = size[0]*0.5, quarter = size[0]*0.25;
    float border = 2*g_l4dPixel/g_l4dScale;
    L4D_Fill(pos,[half,size[1]],[0,0,0],1);
    L4D_Fade(pos+[half,0],[quarter,size[1]],[0,0,0],1,220/255);
    L4D_Fade(pos+[half+quarter,0],[quarter,size[1]],[0,0,0],220/255,0);
    L4D_Fade(pos,[size[0],border],[0,0,0],1,0);
    L4D_Fade(pos+[0,size[1]-border],[size[0],border],[0,0,0],1,0);
    float originalTall = g_l4dButtons[g_l4dFlyouts[g_l4dOpen].fromButton].boundsSize[1];
    if (g_l4dFlyouts[g_l4dOpen].expandUp)
        L4D_Fill(pos,[border,size[1]-originalTall+border],[0,0,0],1);
    else L4D_Fill(pos+[0,originalTall-border],[border,size[1]-originalTall+border],[0,0,0],1);
    for (int i=0;i<g_l4dButtonCount;i++) if (g_l4dButtons[i].scope == g_l4dOpen) g_l4dButtons[i].Draw();
}

void L4D_LoadButtons(l4dResource resource, int scope)
{
    string children = resource.Get("@");
    int cursor = 0;
    while (cursor < strlen(children)) {
        int end = strstrofs(children,";",cursor);
        if (end < 0) break;
        string name = substring(children,cursor,end-cursor);
        cursor = end+1;
        string prefix = strcat(name,"/");
        string type = resource.Get(strcat(prefix,"ControlName"));
        if (type != "L4D360HybridButton" && type != "BaseModHybridButton") continue;
        if (g_l4dButtonCount >= L4D_MAX_BUTTONS) { print("L4D360: too many buttons\n"); return; }
        l4dHybridButton button = spawn(l4dHybridButton);
        button.id = g_l4dButtonCount;
        g_l4dButtons[g_l4dButtonCount++] = button;
        button.scope = scope;
        button.fieldName = resource.Get(strcat(prefix,"fieldName"),name);
        button.text = resource.Get(strcat(prefix,"labelText"));
        button.helpText = resource.Get(strcat(prefix,"tooltiptext"));
        button.disabledHelpText = resource.Get(strcat(prefix,"disabled_tooltiptext"),button.helpText);
        button.command = resource.Get(strcat(prefix,"command"));
        button.navUp = resource.Get(strcat(prefix,"navUp"));
        button.navDown = resource.Get(strcat(prefix,"navDown"));
        button.navLeft = resource.Get(strcat(prefix,"navLeft"));
        button.navRight = resource.Get(strcat(prefix,"navRight"));
        button.shown = resource.Number(strcat(prefix,"visible"),1) != 0;
        button.available = resource.Number(strcat(prefix,"enabled"),1) != 0;
        if (resource.Get(strcat(prefix,"EnableCondition")) == "Never") button.available = false;
        button.activation = (int)resource.Number(strcat(prefix,"ActivationType"),2);
        button.boundsPos = [resource.Number(strcat(prefix,"xpos"),0),resource.Number(strcat(prefix,"ypos"),0)];
        button.boundsSize = [resource.Number(strcat(prefix,"wide"),0),resource.Number(strcat(prefix,"tall"),0)];
        string style = resource.Get(strcat(prefix,"style"),"DefaultButton");
        button.style = (int)g_l4dScheme.Number(strcat("BaseSettings/",style,".Style"),0);
        button.textInset = [g_l4dScheme.Number(strcat("BaseSettings/",style,".TextInsetX"),0),
                           g_l4dScheme.Number(strcat("BaseSettings/",style,".TextInsetY"),0)];
        if (scope == -1 && resource.Number(strcat(prefix,"tabPosition"),0) == 1) L4D_SetFocus(button.id,false);
    }
}

void L4D_ReloadFonts(void)
{
    g_l4dMainHeight = g_l4dScheme.Number("Fonts/MainBold/1/tall",20);
    g_l4dMediumHeight = g_l4dScheme.Number("Fonts/DefaultMedium/1/tall",16);
    g_l4dBoldHeight = g_l4dScheme.Number("Fonts/DefaultBold/1/tall",18);
    string sizes = "14 16 18 20 24 27 30 32 36 40 48 54 60 64 72 80";
    g_l4dMainFont = loadfont("l4d360_main","resource/l4d360/fonts/TGB.ttf",sizes,-1,0,0);
    g_l4dMediumFont = g_l4dMainFont;
    g_l4dBoldFont = g_l4dMainFont;
}

void L4D_Init(void)
{
    if (g_l4dLoaded) return;
    g_l4dScheme = spawn(l4dResource);
    g_l4dMain = spawn(l4dResource);
    g_l4dFooter = spawn(l4dResource);
    if (!g_l4dScheme.Load("resource/l4d360/l4d360uischeme.res") ||
        !g_l4dMain.Load("resource/l4d360/ui/mainmenu.res") ||
        !g_l4dFooter.Load("resource/l4d360/ui/footerpanel.res")) return;
    g_l4dLocale = hash_createtab(4096,EV_STRING);
    L4D_LoadLocale("gameui_english.txt");
    L4D_LoadLocale("valve_english.txt");
    L4D_LoadLocale("l4d360ui_english.txt");
    L4D_ReloadFonts();
    L4D_LoadButtons(g_l4dMain,-1);
    string children = g_l4dMain.Get("@");
    int cursor = 0;
    while (cursor < strlen(children)) {
        int end = strstrofs(children,";",cursor);
        if (end < 0) break;
        string name = substring(children,cursor,end-cursor);
        cursor = end+1;
        string prefix = strcat(name,"/");
        if (g_l4dMain.Get(strcat(prefix,"ControlName")) != "FlyoutMenu") continue;
        if (g_l4dFlyoutCount >= L4D_MAX_FLYOUTS) break;
        int id = g_l4dFlyoutCount++;
        l4dResource resource = spawn(l4dResource);
        resource.Load(strcat("resource/l4d360/ui/",L4D_Leaf(g_l4dMain.Get(strcat(prefix,"ResourceFile")))));
        g_l4dFlyouts[id].resource = resource;
        g_l4dFlyouts[id].fieldName = name;
        g_l4dFlyouts[id].initialFocus = g_l4dMain.Get(strcat(prefix,"InitialFocus"));
        g_l4dFlyouts[id].expandUp = g_l4dMain.Number(strcat(prefix,"ExpandUp"),0) != 0;
        g_l4dFlyouts[id].size = [resource.Number("PnlBackground/wide",150),resource.Number("PnlBackground/tall",60)];
        L4D_LoadButtons(resource,id);
    }
    filestream glyphs = fopen("resource/l4d360/buttons.metrics",FILE_READ);
    string line;
    if (glyphs >= 0) {
        while ((line=fgets(glyphs))) {
            if (tokenize_console(line) != 2) continue;
            int ch = (int)stof(argv(0));
            string numbers = argv(1);
            if (ch < 0 || ch > 255 || tokenize_console(numbers) != 7) continue;
            g_l4dGlyphPos[ch] = [stof(argv(0)),stof(argv(1))];
            g_l4dGlyphSize[ch] = [stof(argv(2)),stof(argv(3))];
            g_l4dGlyphABC[ch] = [stof(argv(4)),stof(argv(5)),stof(argv(6))];
        }
        fclose(glyphs);
    }
    g_l4dLastMouse = getmousepos();
    g_l4dController = true;
    g_l4dLoaded = true;
    print(sprintf("L4D360: loaded %i buttons and %i flyouts from Xbox resources\n",g_l4dButtonCount,g_l4dFlyoutCount));
}

bool L4D_Active(void)
{
    return autocvar_ui_l4d360 != 0 && g_l4dLoaded && (clientstate() != 2 || cvar("_background") != 0);
}

void L4D_Layout(void)
{
    g_l4dScale = g_vidsize[1]/480;
    g_l4dExtent = [min(g_vidsize[0]/g_l4dScale,480*16/9),480];
    g_l4dOrigin = [(g_vidsize[0]-g_l4dExtent[0]*g_l4dScale)/2,0];
    vector physical = getproperty(VF_SCREENPSIZE);
    g_l4dPixel = physical[0] > 0 ? g_vidsize[0]/physical[0] : 1;
}

bool L4D_Inside(vector point, vector pos, vector size)
{
    return point[0] >= pos[0] && point[1] >= pos[1] && point[0] < pos[0]+size[0] && point[1] < pos[1]+size[1];
}

int L4D_Hit(vector mouse)
{
    vector point = (mouse-g_l4dOrigin)/g_l4dScale;
    /* Flyout goes above its source and other main-menu controls. */
    for (int pass=0;pass<2;pass++) {
        int scope = pass == 0 ? g_l4dOpen : -1;
        if (pass == 0 && scope < 0) continue;
        for (int i=0;i<g_l4dButtonCount;i++)
            if (g_l4dButtons[i].scope == scope && g_l4dButtons[i].shown &&
                L4D_Inside(point,L4D_ButtonPos(i),g_l4dButtons[i].boundsSize)) return i;
    }
    return -1;
}

void L4D_FooterButton(vector pos, int ch, string token, bool right)
{
    if (right) pos[0] = g_l4dExtent[0]-pos[0];
    string text = L4D_Text(token);
    float wide = L4D_Width(text,g_l4dBoldFont,g_l4dBoldHeight);
    if (right) pos[0] = min(pos[0],g_l4dExtent[0]*0.95-wide);
    /* The L4D scheme predates Swarm's GameUIButtonsTiny: use its Mini size. */
    float scale = g_l4dScheme.Number("Fonts/GameUIButtonsMini/1/scalex",0.65);
    vector size = g_l4dGlyphSize[ch]*scale;
    vector at = pos - [size[0]+5*g_l4dPixel/g_l4dScale,size[1]*0.5];
    if (size[0] > 0) drawsubpic(L4D_Point(at),size*g_l4dScale,"resource/l4d360/images/buttons_32.png",
        g_l4dGlyphPos[ch]/256,g_l4dGlyphSize[ch]/256,[1,1,1],1,0);
    L4D_DrawText(pos-[0,g_l4dBoldHeight*0.5],text,g_l4dBoldFont,g_l4dBoldHeight,[1,1,1],1);
}

void L4D_DrawFooter(void)
{
    float y = L4D_Coord(g_l4dFooter.Get("FooterPanel/ypos","r100"),g_l4dExtent[1]);
    float tall = g_l4dFooter.Number("FooterPanel/tall",70);
    /* MainMenu::SetFooterState disables help; retain the 0.75 minimal footer. */
    float top = y+tall*0.25;
    float body = tall*0.75;
    L4D_Fill([0,top],[g_l4dExtent[0],body],[0,0,0],225/255);
    L4D_FooterButton([100,y+58], 'A', "#L4D360UI_Select",false);
    if (g_l4dOpen >= 0 || g_l4dNotice)
        L4D_FooterButton([225,y+58], 'B', "#L4D360UI_Cancel",false);
    else L4D_FooterButton([240,y+58], 'X', "#L4D360UI_MainMenu_SeeAll",true);
}

void L4D_DrawNotice(void)
{
    if (!g_l4dNotice) return;
    L4D_Fill([0,0],g_l4dExtent,[0,0,0],0.55);
    float x = max(60,(g_l4dExtent[0]-520)*0.5);
    L4D_Fill([0,130],[g_l4dExtent[0],155],[0,0,0],0.88);
    L4D_DrawText([x,146],g_l4dNoticeTitle,g_l4dMainFont,24,[200,200,200]/255,1);
    /* Word wrapping at the actual screen width, without overflow into the footer. */
    string remaining = g_l4dNoticeText;
    float y = 186;
    while (remaining != "" && y < 275) {
        int cut = strlen(remaining);
        while (cut > 1 && L4D_Width(substring(remaining,0,cut),g_l4dMediumFont,16)>g_l4dExtent[0]-2*x) cut--;
        if (cut < strlen(remaining)) {
            int space = cut;
            while (space > 0 && substring(remaining,space,1) != " ") space--;
            if (space > 0) cut = space;
        }
        L4D_DrawText([x,y],substring(remaining,0,cut),g_l4dMediumFont,16,[1,1,1],1);
        remaining = substring(remaining,cut,-1);
        if (substring(remaining,0,1) == " ") remaining = substring(remaining,1,-1);
        y += 20;
    }
}

void L4D_MouseMove(vector mouse)
{
    g_l4dPointer = mouse;
    if (!L4D_HasModal() && !g_l4dNotice) {
        if (vlen(mouse-g_l4dLastMouse)>0.25) {
            int hit = L4D_Hit(mouse);
            g_l4dController = false;
            if (hit >= 0)
                if (g_l4dOpen < 0 || g_l4dButtons[hit].scope == g_l4dOpen) L4D_SetFocus(hit,true);
        }
    }
    g_l4dLastMouse = mouse;
}

void L4D_Draw(void)
{
    L4D_Layout();
    drawfill([0,0],g_vidsize,[0,0,0],1);
    string background = g_l4dExtent[0]/480 >= 1.5999 ? "backgroundstreet_widescreen" : "backgroundstreet";
    drawpic(L4D_Point([0,0]),strcat("resource/l4d360/images/",background,".png"),g_l4dExtent*g_l4dScale,[1,1,1],1);
    L4D_MouseMove(getmousepos());
    for (int i=0;i<g_l4dButtonCount;i++) if (g_l4dButtons[i].scope == -1) g_l4dButtons[i].Draw();
    /* Xbox ApplySchemeSettings makes the first local profile label visible. */
    vector labelPos = [L4D_Coord(g_l4dMain.Get("LblPlayer1GamerTag/xpos"),g_l4dExtent[0]),
                       L4D_Coord(g_l4dMain.Get("LblPlayer1GamerTag/ypos"),g_l4dExtent[1])];
    string profile = strreplace("%s1",cvar_string("name"),L4D_Text("#L4D360UI_MainMenu_LocalProfilePlayer1"));
    L4D_DrawText(labelPos,L4D_Ellipsis(profile,g_l4dMediumFont,16,300),g_l4dMediumFont,16,[125,125,125]/255,1);
    L4D_DrawFlyout();
    L4D_DrawNotice();
    L4D_DrawFooter();
    g_l4dReady = true;
}

bool L4D_Input(float event, float key, float character, float device)
{
    if (!L4D_Active()) return false;
    /* FTE delivers mouse movement in the same virtual coordinates as drawing.
     * Retain it for subsequent button events; an OS cursor warp is only a hint. */
    if (event == IE_MOUSEABS) { L4D_MouseMove([key,character]); return true; }
    if (event == IE_MOUSEDELTA) { L4D_MouseMove(g_l4dPointer+[key,character]); return true; }
    if (event != IE_KEYDOWN && event != IE_KEYUP) return true;
    bool down = event == IE_KEYDOWN;
    if (g_l4dNotice) {
        if (down && (key == K_ESCAPE || key == K_GP_B || key == K_ENTER || key == K_GP_A)) {
            g_l4dNotice = false; g_l4dPressed = -1; L4D_Sound("back");
        }
        return true;
    }
    if (down && (key == K_ESCAPE || key == K_GP_B || key == K_MOUSE2)) {
        if (g_l4dOpen >= 0) L4D_CloseFlyout(true);
        /* MainMenu::OnKeyCodePressed consumes controller B at the root. */
        else if (key == K_ESCAPE) L4D_RunCommand("QuitGame");
        g_l4dPressed = -1;
        return true;
    }
    if (down && (key == K_UPARROW || key == K_GP_DPAD_UP || key == K_GP_LTHUMB_UP)) { g_l4dController = true; L4D_Navigate(0); return true; }
    if (down && (key == K_DOWNARROW || key == K_GP_DPAD_DOWN || key == K_GP_LTHUMB_DOWN)) { g_l4dController = true; L4D_Navigate(1); return true; }
    if (down && (key == K_LEFTARROW || key == K_GP_DPAD_LEFT || key == K_GP_LTHUMB_LEFT)) { g_l4dController = true; L4D_Navigate(2); return true; }
    if (down && (key == K_RIGHTARROW || key == K_GP_DPAD_RIGHT || key == K_GP_LTHUMB_RIGHT)) { g_l4dController = true; L4D_Navigate(3); return true; }
    if (down && key == K_GP_X && g_l4dOpen < 0) { L4D_RunCommand("SeeAll"); return true; }
    bool accept = key == K_MOUSE1 || key == K_ENTER || key == K_SPACE || key == K_GP_A;
    if (!accept) return true;
    if (down) {
        if (g_l4dPressed >= 0) return true;
        int selectedIndex = g_l4dFocus;
        if (key == K_MOUSE1) {
            selectedIndex = L4D_Hit(g_l4dPointer);
            if (selectedIndex < 0) { L4D_CloseFlyout(false); return true; }
            if (g_l4dOpen >= 0)
                if (g_l4dButtons[selectedIndex].scope < 0 && selectedIndex != g_l4dFlyouts[g_l4dOpen].fromButton)
                    L4D_CloseFlyout(false);
            L4D_SetFocus(selectedIndex,false);
        }
        if (selectedIndex < 0) return true;
        g_l4dPressed = selectedIndex; g_l4dPressedKey = key;
        /* Source's mouse/keyboard type 0 captures a press, then clicks on
         * release. Its controller type 0 explicitly clicks on both edges. */
        if (g_l4dButtons[selectedIndex].activation == 1)
            L4D_Activate(selectedIndex);
        else if (key == K_GP_A && g_l4dButtons[selectedIndex].activation == 0)
            L4D_Activate(selectedIndex);
    } else if (g_l4dPressed >= 0 && key == g_l4dPressedKey) {
        int releasedIndex = g_l4dPressed;
        g_l4dPressed = -1;
        bool same = key == K_MOUSE1 ? L4D_Hit(g_l4dPointer) == releasedIndex : g_l4dFocus == releasedIndex;
        if (same && g_l4dButtons[releasedIndex].activation != 1) L4D_Activate(releasedIndex);
    }
    return true;
}
