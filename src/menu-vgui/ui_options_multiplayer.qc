/* Sven Co-op Multiplayer property page adapter.
 * Uses the installed OptionsSubMultiplayer.res, copied by the import helper.
 * Data stays staged in the parent Options transaction. GoldSrc bitmap portraits
 * use the original indexed palette; no Sven game DLL or engine is loaded. */
#define UIOMP_RECTS 40
#define UIOMP_ADV_ROWS 4
#define UIOMP_MAX_SPRAY_BYTES 8192

typedef struct {
    string name;
    vector pos;
    vector size;
    bool visible;
} uiompRect_t;
uiompRect_t g_uiompRects[UIOMP_RECTS];
int g_uiompRectCount;
int g_uiompAdvancedFirst;
int g_uiompAdvancedCount;
int g_uiompAdvancedOffset;
string g_uiompAdvancedOriginal[UIO_SETTINGS];
string g_uiompModelCache;
string g_uiompModelImage;
bool g_uiompLayoutLoaded;

int UIOMP_RectIndex(string name)
{
    for (int i=0;i<g_uiompRectCount;i++)
        if (g_uiompRects[i].name==name) return i;
    return -1;
}

vector UIOMP_Pos(string name, vector fallback)
{
    int i=UIOMP_RectIndex(name);
    if (i<0) return fallback;
    /* The original content is 520 units wide. Fit its three columns into the
     * existing 480-unit page; preserve vertical positions below the six tabs. */
    return [12+floor(g_uiompRects[i].pos[0]*0.94),58+g_uiompRects[i].pos[1]];
}

vector UIOMP_Size(string name, vector fallback)
{
    int i=UIOMP_RectIndex(name);
    if (i<0) return fallback;
    return [floor(g_uiompRects[i].size[0]*0.94),g_uiompRects[i].size[1]];
}

void UIOMP_LoadLayout(void)
{
    filestream file=fopen("resource/sven-options/OptionsSubMultiplayer.res",FILE_READ);
    if (file<0) return;
    int depth=0, current=-1;
    string pending="", line;
    while ((line=fgets(file))) {
        int count=tokenize_console(line);
        if (!count) continue;
        string key=argv(0), value=argv(1);
        if (key=="{") {
            depth++;
            if (depth==2 && g_uiompRectCount<UIOMP_RECTS) {
                current=g_uiompRectCount++;
                g_uiompRects[current].name=pending;
                g_uiompRects[current].visible=true;
            }
        } else if (key=="}") {
            if (depth==2) current=-1;
            depth--;
        } else if (depth==1 && count==1) pending=key;
        else if (depth==2 && current>=0) {
            if (key=="xpos") g_uiompRects[current].pos[0]=stof(value);
            if (key=="ypos") g_uiompRects[current].pos[1]=stof(value);
            if (key=="wide") g_uiompRects[current].size[0]=stof(value);
            if (key=="tall") g_uiompRects[current].size[1]=stof(value);
            if (key=="visible") g_uiompRects[current].visible=stof(value)!=0;
            if (key=="maxchars" && g_uiompRects[current].name=="NameEntry")
                g_uioNameLimit=bound(1,stof(value),63);
        }
    }
    fclose(file);
    g_uiompLayoutLoaded=UIOMP_RectIndex("ModelImage")>=0 && UIOMP_RectIndex("SpraypaintList")>=0;
}

bool UIOMP_SafeKey(string key)
{
    if (!key || strlen(key)>64) return false;
    for (int n=0;n<strlen(key);n++)
        if (strstrofs("abcdefghijklmnopqrstuvwxyz_0123456789",substring(key,n,1))<0) return false;
    return true;
}

bool UIOMP_SprayPath(string path)
{
    if (substring(path,0,6)!="logos/" || strstrofs(path,"..")>=0 || strstrofs(path,"|")>=0) return false;
    string ext=strtolower(substring(path,-4,4));
    return ext==".bmp" || ext==".png" || ext==".tga" || ext==".jpg";
}

void UIOMP_LoadAdvanced(void)
{
    g_uiompAdvancedFirst=g_uioCount;
    filestream file=fopen("resource/sven-options/advanced.txt",FILE_READ);
    if (file>=0) {
        string line;
        while ((line=fgets(file))) {
            if (tokenize_console(line)!=9) continue;
            string key=argv(0), title=argv(1), kindName=argv(2);
            float low=stof(argv(3)), high=stof(argv(4)), step=stof(argv(5));
            string labels=argv(6), values=argv(7);
            bool unavailable=stof(argv(8))!=0;
            if (!UIOMP_SafeKey(key)) continue;
            int kind=kindName=="CHECK" ? UIO_CHECK : (kindName=="SLIDER" ? UIO_SLIDER : UIO_CHOICE);
            int i=UIO_Add(UIO_MULTI_ADVANCED,kind,key,title,[44,128],[390,22],low,high,step);
            g_uio[i].labels=labels; g_uio[i].values=values;
            g_uio[i].unavailable=unavailable;
        }
        fclose(file);
    }
    /* Keep the existing FTE-specific controls accessible under Advanced. */
    int rate=UIO_Add(UIO_MULTI_ADVANCED,UIO_CHOICE,"rate","Network: Connection rate",[44,128],[390,22],0,0,0);
    UIO_AddChoice(rate,"Limited (30000)","30000"); UIO_AddChoice(rate,"Broadband (50000)","50000");
    UIO_AddChoice(rate,"Fast (100000)","100000"); UIO_AddChoice(rate,"LAN (250000)","250000");
    UIO_Add(UIO_MULTI_ADVANCED,UIO_SLIDER,"crosshairsize","HUD: Crosshair size",[44,128],[390,22],1,32,1);
    g_uiompAdvancedCount=g_uioCount-g_uiompAdvancedFirst;
}

void UIOMP_Create(void)
{
    UIOMP_LoadLayout();
    UIO_Add(UIO_MULTI,UIO_TEXT,"name","Player name",UIOMP_Pos("NameEntry",[30,112]),UIOMP_Size("NameEntry",[131,24]),0,0,0);
    g_uioModel=UIO_Add(UIO_MULTI,UIO_CHOICE,"model","Player model",UIOMP_Pos("Player model",[30,162]),UIOMP_Size("Player model",[131,24]),0,0,0);
    searchhandle models=search_begin("models/player/*/*.mdl",SB_NAMESORT,TRUE);
    int modelCount=0;
    if (models>=0) {
        for (int n=0;n<search_getsize(models);n++) {
            string path=search_getfilename(models,n);
            if (tokenizebyseparator(path,"/")!=4) continue;
            string name=argv(2), leaf=argv(3);
            if (leaf==strcat(name,".mdl")) { UIO_AddChoice(g_uioModel,name,name); modelCount++; }
        }
        search_end(models);
    }
    g_uio[g_uioModel].unavailable=modelCount==0;
    vector colorsize=UIOMP_Size("Primary Color Slider",[131,39]); colorsize[1]=24;
    UIO_Add(UIO_MULTI,UIO_COLOR,"topcolor","Primary",UIOMP_Pos("Primary Color Slider",[30,210]),colorsize,0,255,1);
    UIO_Add(UIO_MULTI,UIO_COLOR,"bottomcolor","Secondary",UIOMP_Pos("Secondary Color Slider",[30,242]),colorsize,0,255,1);
    g_uioSpray=UIO_Add(UIO_MULTI,UIO_CHOICE,"$spray","Spraypaint image",UIOMP_Pos("SpraypaintList",[346,112]),UIOMP_Size("SpraypaintList",[120,24]),0,0,0);
    UIO_AddChoice(g_uioSpray,"None","$none");
    searchhandle sprays=search_begin("logos/*.*",SB_NAMESORT,TRUE);
    if (sprays>=0) {
        for (int n=0;n<search_getsize(sprays);n++) {
            string path=search_getfilename(sprays,n);
            if (!UIOMP_SprayPath(path) || strtolower(path)=="logos/remapped.bmp") continue;
            filestream file=fopen(path,FILE_READ);
            if (file<0) continue;
            int bytes=fsize(file); fclose(file);
            if (bytes<=0 || bytes>UIOMP_MAX_SPRAY_BYTES) continue;
            UIO_AddChoice(g_uioSpray,substring(path,6,strlen(path)-10),path);
        }
        search_end(sprays);
    }
    g_uioSprayColor=UIO_Add(UIO_MULTI,UIO_CHOICE,"$spraycolor","",UIOMP_Pos("SpraypaintColor",[346,144]),UIOMP_Size("SpraypaintColor",[120,24]),0,0,0);
    UIO_AddChoice(g_uioSprayColor,"White","255 255 255"); UIO_AddChoice(g_uioSprayColor,"Orange","255 120 24");
    UIO_AddChoice(g_uioSprayColor,"Yellow","255 180 24"); UIO_AddChoice(g_uioSprayColor,"Blue","0 60 255");
    UIO_AddChoice(g_uioSprayColor,"Ltblue","0 167 255"); UIO_AddChoice(g_uioSprayColor,"Green","0 167 0");
    UIO_AddChoice(g_uioSprayColor,"Red","255 43 0"); UIO_AddChoice(g_uioSprayColor,"Brown","123 73 0");
    UIO_AddChoice(g_uioSprayColor,"Ltgray","100 100 100"); UIO_AddChoice(g_uioSprayColor,"Dkgray","36 36 36");
    UIOMP_LoadAdvanced();
}

bool UIOMP_Supported(int i)
{
    if (g_uio[i].unavailable) return false;
    string key=g_uio[i].key;
    if (key=="$resolution") return UIO_Available("vid_width") && UIO_Available("vid_height");
    if (key=="$spray" || key=="$spraycolor")
        return checkbuiltin(setlocaluserinfoblob) && checkbuiltin(setlocaluserinfo);
    return UIO_Available(key);
}

vector UIOMP_HueRGB(float hue, float saturation, float brightness)
{
    float angle=bound(0,hue,255)*360/255;
    if (angle>=360) angle=0;
    return hsvToRGB(angle,saturation,brightness);
}

string UIOMP_ColorToEngine(float hue)
{
    vector rgb=UIOMP_HueRGB(hue,100,100);
    int packed=((int)rgb[0]<<16)|((int)rgb[1]<<8)|(int)rgb[2];
    /* FTE interprets decimal values as Quake palette choices. Explicit RGB
     * userinfo matches Nuclide's existing player-color customization. */
    return sprintf("0x%06x",(float)packed);
}

string UIOMP_ColorFromEngine(string color)
{
    /* Retain numeric hue values from earlier lab menu versions. */
    if (strtolower(substring(color,0,2))!="0x") return color;
    int packed=0;
    if (strlen(color)<3 || strlen(color)>8) return "0";
    for (int n=2;n<strlen(color);n++) {
        int digit=strstrofs("0123456789abcdef",strtolower(substring(color,n,1)));
        if (digit<0) return "0";
        packed=(packed<<4)|digit;
    }
    float red=(packed>>16)&255, green=(packed>>8)&255, blue=packed&255;
    float high=UIO_Max(red,UIO_Max(green,blue)), low=UIO_Min(red,UIO_Min(green,blue));
    float delta=high-low, hue=0;
    if (delta>0) {
        if (high==red) hue=(green-blue)/delta;
        else if (high==green) hue=2+(blue-red)/delta;
        else hue=4+(red-green)/delta;
        if (hue<0) hue+=6;
    }
    return ftos(rint(hue*255/6));
}

string UIOMP_ReadSetting(int i)
{
    if (g_uio[i].kind==UIO_COLOR) return UIOMP_ColorFromEngine(cvar_string(g_uio[i].key));
    if (g_uio[i].key=="$spray") {
        string value=cvar_string("_cl_playerspray");
        return value!="" ? value : "$none";
    }
    string color=cvar_string("_cl_spraycolor");
    return color!="" ? color : "255 255 255";
}

/* Used both on Apply and to restore the archived selection after launch. */
bool UIOMP_SetSpray(string path, string color)
{
    if (!checkbuiltin(setlocaluserinfoblob) || !checkbuiltin(setlocaluserinfo)) return false;
    if (path!="$none" && path!="") {
        if (!UIOMP_SprayPath(path)) return false;
        filestream file=fopen(path,FILE_READ);
        if (file<0) return false;
        int size=fsize(file);
        if (size<=0 || size>UIOMP_MAX_SPRAY_BYTES) { fclose(file); return false; }
        void *bytes=memalloc(size);
        int count=fread(file,bytes,size); fclose(file);
        if (count!=size) { memfree(bytes); return false; }
        setlocaluserinfoblob(0,"spray",bytes,size);
        memfree(bytes);
    } else setlocaluserinfoblob(0,"spray",__NULL__,0);
    vector tint=stov(color)/255;
    if (strtolower(substring(path,-4,4))!=".bmp") tint=[1,1,1];
    setlocaluserinfo(0,"spraycolor",sprintf("%v",tint));
    setlocaluserinfo(0,"spraytype",strtolower(substring(path,-4,4))==".bmp" ? "1" : "0");
    return true;
}

bool UIOMP_ApplySpray(void)
{
    if (!g_uio[g_uioSpray].supported) return true;
    if (g_uio[g_uioSpray].value==g_uio[g_uioSpray].original &&
        g_uio[g_uioSprayColor].value==g_uio[g_uioSprayColor].original) return true;
    string path=g_uio[g_uioSpray].value, color=g_uio[g_uioSprayColor].value;
    if (!UIOMP_SetSpray(path,color)) {
        g_uioStatus="Spray is missing or exceeds 8 KB. Choose another image.";
        return false;
    }
    if (path=="$none") path="";
    cvar_set("_cl_playerspray",path); cvar_set("_cl_spraycolor",color);
    localcmd(sprintf("seta _cl_playerspray %S\nseta _cl_spraycolor %S\n",path,color));
    return true;
}

void UIOMP_RestoreSavedSpray(void)
{
    string path=cvar_string("_cl_playerspray");
    string color=cvar_string("_cl_spraycolor");
    if (path!="") UIOMP_SetSpray(path,color!="" ? color : "255 255 255");
}

int UIOMP_ReadInt(void *data, int offset)
{
    int value=0;
    /* Offset the VM pointer explicitly: older runtimes ignore memcpy's
     * optional offsets, and BMP fields are not always four-byte aligned. */
    memcpy(&value,(void *)((int)data+offset),4);
    return value;
}

void UIOMP_WriteInt(void *data, int offset, int value)
{
    memcpy((void *)((int)data+offset),&value,4);
}

void UIOMP_RemapPalette(void *data, int first, int last, float hue)
{
    for (int i=first;i<=last;i++) {
        int entry=UIOMP_ReadInt(data,54+i*4);
        float red=(entry>>16)&255, green=(entry>>8)&255, blue=entry&255;
        float high=UIO_Max(red,UIO_Max(green,blue)), low=UIO_Min(red,UIO_Min(green,blue));
        vector rgb=UIOMP_HueRGB(hue,high ? 100*(high-low)/high : 0,100*high/255);
        int packed=((int)rgb[0]<<16)|((int)rgb[1]<<8)|(int)rgb[2];
        UIOMP_WriteInt(data,54+i*4,packed);
    }
}

string UIOMP_ModelPortrait(string name, float top, float bottom)
{
    if (name=="" || strstrofs(name,"/")>=0 || strstrofs(name,"\\")>=0 || strstrofs(name,"..")>=0) return "";
    string path=sprintf("models/player/%s/%s.bmp",name,name);
    string cache=sprintf("%s:%g:%g",path,top,bottom);
    if (cache==g_uiompModelCache) return g_uiompModelImage;
    g_uiompModelCache=cache; g_uiompModelImage="";
    if (!fileExists(path)) return "";
    g_uiompModelImage=path;
    if (!checkbuiltin(r_uploadimage)) return path;
    filestream file=fopen(path,FILE_READ);
    if (file<0) return "";
    int size=fsize(file);
    if (size<1078 || size>4194304) { fclose(file); return path; }
    void *data=memalloc(size);
    if (!data) { fclose(file); return path; }
    int count=fread(file,data,size); fclose(file);
    int width=UIOMP_ReadInt(data,18), height=UIOMP_ReadInt(data,22);
    bool valid=count==size && (UIOMP_ReadInt(data,0)&65535)==19778 && UIOMP_ReadInt(data,14)==40 &&
        ((UIOMP_ReadInt(data,28)&65535)==8) && UIOMP_ReadInt(data,30)==0 &&
        UIOMP_ReadInt(data,10)>=1078 && width>0 && width<=512 && height>0 && height<=512;
    if (valid) {
        int stride=(width+3)&~3;
        valid=UIOMP_ReadInt(data,10)<=size-stride*height && (UIOMP_ReadInt(data,26)&65535)==1;
    }
    if (valid) {
        /* GoldSrc's model portrait has separate shirt/pants palette ranges. */
        UIOMP_RemapPalette(data,160,191,top);
        UIOMP_RemapPalette(data,192,223,bottom);
        r_uploadimage("uiomp_portrait",width,height,data,size,0);
        shaderforname("uiomp/portrait","{\n{\nmap $rt:uiomp_portrait\nrgbGen vertex\n}\n}");
        g_uiompModelImage="uiomp/portrait";
    }
    memfree(data);
    return g_uiompModelImage;
}

void UIOMP_ReloadImages(void)
{
    g_uiompModelCache=""; g_uiompModelImage="";
}

void UIOMP_DrawColor(int i)
{
    vector p=g_uio[i].pos, s=g_uio[i].size;
    bool enabled=g_uio[i].supported;
    float value=bound(0,stof(g_uio[i].value),255);
    for (int n=0;n<32;n++) {
        vector color=UIOMP_HueRGB((float)n*255/31,100,100)/255;
        UIO_Rect(p+[n*s[0]/32,7],[s[0]/32+1,8],color,enabled ? 1 : 0.3);
    }
    vguiTheme theme=g_uioWindow.GetTheme();
    theme.DrawButton(g_uioOrigin+p+[value/255*(s[0]-10),2],[10,20],enabled ? VGUI_STATE_NORMAL : VGUI_STATE_DISABLED);
    UIO_Line(p+[0,23],[s[0],16],sprintf("%s: %i",g_uio[i].title,(int)value),!enabled);
    if (g_uioFocus==g_uioHitCount && enabled) UIO_Outline(p-[2,2],s+[4,4],[0.8,0.7,0.35]);
    UIO_Hit(UIO_H_SETTING,i,p,s,enabled);
}

void UIOMP_Draw(void)
{
    for (int i=0;i<g_uioCount;i++) if (g_uio[i].page==UIO_MULTI) UIO_DrawSetting(i);
    UIO_Line(UIOMP_Pos("Colors",[30,186]),[150,20],"Player colors",false);
    vector pos=UIOMP_Pos("ModelImage",[177,136]), size=UIOMP_Size("ModelImage",[154,200]);
    UIO_Rect(pos,size,[0,0,0],0.6);
    string portrait="";
    if (!g_uio[g_uioModel].unavailable)
        portrait=UIOMP_ModelPortrait(g_uio[g_uioModel].value,stof(g_uio[UIO_Find("topcolor")].value),stof(g_uio[UIO_Find("bottomcolor")].value));
    /* An empty QC string can have a nonzero string-table address. */
    if (portrait!="") drawpic(g_uioOrigin+pos,portrait,size,[1,1,1],1);
    else UIO_Text(pos+[10,70],size-[20,80],g_uio[g_uioModel].unavailable ? "No player models installed" : "No model portrait available",true);
    UIO_Outline(pos,size,[0.4,0.4,0.4]);
    pos=UIOMP_Pos("LogoImage",[346,176]); size=UIOMP_Size("LogoImage",[120,128]);
    UIO_Rect(pos,size,[0.04,0.04,0.04],1);
    string spray=g_uio[g_uioSpray].value;
    if (UIOMP_SprayPath(spray) && fileExists(spray)) {
        vector imageSize=drawgetimagesize(spray);
        if (imageSize[0]>0 && imageSize[1]>0) {
            float scale=UIO_Min((size[0]-8)/imageSize[0],(size[1]-8)/imageSize[1]);
            imageSize*=scale;
            vector color=strtolower(substring(spray,-4,4))==".bmp" ? stov(g_uio[g_uioSprayColor].value)/255 : [1,1,1];
            drawpic(g_uioOrigin+pos+(size-imageSize)/2,spray,imageSize,color,1);
        }
    } else UIO_Text(pos+[12,46],size-[24,46],"No spray selected",true);
    UIO_Outline(pos,size,[0.4,0.4,0.4]);
    UIO_Button(UIO_H_ADVANCED,0,UIOMP_Pos("Advanced",[377,324]),UIOMP_Size("Advanced",[94,24]),"Advanced...",true);
    UIO_Text([30,370],[444,28],"Choose a model and spray. Apply saves your changes.",true);
}

void UIOMP_OpenAdvanced(void)
{
    for (int i=g_uiompAdvancedFirst;i<g_uiompAdvancedFirst+g_uiompAdvancedCount;i++)
        g_uiompAdvancedOriginal[i]=g_uio[i].value;
    g_uiompAdvancedOffset=0;
    g_uioMPAdvanced=true;
    g_uioPopup=-1; g_uioPressed=-1; g_uioFocus=-1; g_uioSlider=-1;
}

void UIOMP_CloseAdvanced(bool keep)
{
    if (!keep)
        for (int i=g_uiompAdvancedFirst;i<g_uiompAdvancedFirst+g_uiompAdvancedCount;i++)
            g_uio[i].value=g_uiompAdvancedOriginal[i];
    g_uioMPAdvanced=false;
    g_uioPopup=-1; g_uioPressed=-1; g_uioFocus=-1; g_uioSlider=-1;
}

void UIOMP_ScrollAdvanced(int direction)
{
    g_uiompAdvancedOffset=bound(0,g_uiompAdvancedOffset+direction,UIO_Max(0,g_uiompAdvancedCount-UIOMP_ADV_ROWS));
    g_uioPopup=-1; g_uioPressed=-1; g_uioFocus=-1; g_uioSlider=-1;
}

void UIOMP_DrawAdvanced(void)
{
    UIO_Rect([0,28],[UIO_W,UIO_H-28],[0,0,0],0.7);
    UIO_Rect([24,70],[456,328],UI_MAINCOLOR,1);
    UIO_Outline([24,70],[456,328],[0.6,0.6,0.6]);
    UIO_Text([42,83],[420,20],"Advanced multiplayer options",false);
    /* Only the modal's controls participate in input while it is open. */
    g_uioHitCount=0;
    for (int row=0;row<UIOMP_ADV_ROWS;row++) {
        int i=g_uiompAdvancedFirst+g_uiompAdvancedOffset+row;
        if (i>=g_uiompAdvancedFirst+g_uiompAdvancedCount) break;
        g_uio[i].pos=[44,134+row*52];
        UIO_DrawSetting(i);
    }
    UIO_Text([44,321],[408,28],"Unavailable items require Sven-specific game features.",true);
    UIO_Button(UIO_H_ADV_SCROLL,-UIOMP_ADV_ROWS,[42,359],[26,24],"^",g_uiompAdvancedOffset>0);
    UIO_Button(UIO_H_ADV_SCROLL,UIOMP_ADV_ROWS,[74,359],[26,24],"v",g_uiompAdvancedOffset+UIOMP_ADV_ROWS<g_uiompAdvancedCount);
    UIO_Text([110,365],[164,20],sprintf("%i-%i of %i",(int)(g_uiompAdvancedOffset+1),(int)UIO_Min(g_uiompAdvancedOffset+UIOMP_ADV_ROWS,g_uiompAdvancedCount),g_uiompAdvancedCount),true);
    UIO_Button(UIO_H_ADV_OK,0,[290,359],[74,24],"OK",true);
    UIO_Button(UIO_H_ADV_CANCEL,0,[374,359],[74,24],"Cancel",true);
}
