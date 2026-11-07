/* Included after the shared Options test helpers, only in test builds. */
void UIOMP_TestPalette(void)
{
    void *data=memalloc(1078);
    int shade=0x004080c0;
    for (int i=0;i<256;i++) UIOMP_WriteInt(data,54+i*4,shade);
    UIO_Assert(UIOMP_ReadInt(data,54+160*4)==shade,"bitmap reads support unaligned palette offsets");
    UIOMP_RemapPalette(data,160,191,0);
    UIOMP_RemapPalette(data,192,223,170);
    bool unchanged=true, upper=true, lower=true;
    for (int n=0;n<256;n++) {
        int actual=UIOMP_ReadInt(data,54+n*4);
        if (n>=160 && n<=191) upper=upper && actual==0x00c04040;
        else if (n>=192 && n<=223) lower=lower && actual==0x004040c0;
        else unchanged=unchanged && actual==shade;
    }
    UIO_Assert(upper,"upper palette becomes red while preserving saturation and brightness");
    UIO_Assert(lower,"lower palette independently becomes blue");
    UIO_Assert(unchanged,"portrait remapping leaves every other palette entry untouched");
    memfree(data);
    UIO_Assert(UIOMP_ColorToEngine(0)=="0xff0000" && UIOMP_ColorToEngine(170)=="0x0000ff" &&
        UIOMP_ColorToEngine(255)=="0xff0000","hue sliders encode FTE RGB colors including the wrapped red endpoint");
    UIO_Assert(stof(UIOMP_ColorFromEngine("0xff0000"))==0 && stof(UIOMP_ColorFromEngine("0x0000ff"))==170,
        "saved FTE colors reopen at the matching slider hues");
}

void UIOMP_TestColorApply(void)
{
    string oldTop=cvar_string("topcolor"), oldBottom=cvar_string("bottomcolor");
    UIO_Set(UIO_Find("topcolor"),"85"); UIO_Set(UIO_Find("bottomcolor"),"85");
    UIO_Apply(false);
    UIO_Set(UIO_Find("topcolor"),"0"); UIO_Set(UIO_Find("bottomcolor"),"170");
    UIO_Apply(false);
    UIO_Assert(cvar_string("topcolor")=="0xff0000" && cvar_string("bottomcolor")=="0x0000ff" &&
        getlocaluserinfo(0,"topcolor")=="0xff0000" && getlocaluserinfo(0,"bottomcolor")=="0x0000ff",
        "Apply publishes both player colors in FTE's RGB userinfo format");
    UIO_Cancel(); UI_Options_Show(); UIO_SetPage(UIO_MULTI);
    UIO_Assert(stof(g_uio[UIO_Find("topcolor")].value)==0 && stof(g_uio[UIO_Find("bottomcolor")].value)==170,
        "reopening Multiplayer restores the applied slider hues");
    UIO_Set(UIO_Find("topcolor"),"85"); UIO_Cancel();
    UIO_Assert(cvar_string("topcolor")=="0xff0000","Cancel preserves the previously applied player color");
    cvar_set("topcolor",oldTop); cvar_set("bottomcolor",oldBottom);
    UI_Options_Show(); UIO_SetPage(UIO_MULTI);
}

void UIOMP_TestRestoreSpray(void)
{
    cvar_set("_cl_playerspray",g_uioTestSprayFile);
    cvar_set("_cl_spraycolor",g_uioTestSprayColor);
    setlocaluserinfoblob(0,"spray",g_uioTestSprayBlob,g_uioTestSprayBytes);
    setlocaluserinfo(0,"spraycolor",g_uioTestSprayColorInfo);
    setlocaluserinfo(0,"spraytype",g_uioTestSprayTypeInfo);
    /* Apply queues archive commands. Restore after those commands as well as
     * immediately, so the next test frame sees the exact original state. */
    localcmd(sprintf("seta _cl_playerspray %S\nseta _cl_spraycolor %S\n",g_uioTestSprayFile,g_uioTestSprayColor));
}

void UIOMP_Test(void)
{
    UIO_Assert(g_uiompLayoutLoaded,"Multiplayer loads Sven's original resource layout");
    vector modelpos=UIOMP_Pos("ModelImage",[0,0]), spraypos=UIOMP_Pos("LogoImage",[0,0]);
    UIO_Assert(g_uio[UIO_Find("name")].pos[0]<modelpos[0] && modelpos[0]+UIOMP_Size("ModelImage",[0,0])[0]<spraypos[0],
        "Sven's player, model portrait, and spray columns do not overlap");
    int hidden=UIOMP_RectIndex("CrosshairImage");
    UIO_Assert(hidden>=0 && !g_uiompRects[hidden].visible && g_uio[UIO_Find("crosshair")].page==UIO_MULTI_ADVANCED,
        "crosshair controls follow Sven into Advanced rather than covering the portrait");
    UIO_Assert(g_uioNameLimit==63,"player name length comes from Sven's NameEntry");
    int name=UIO_Find("name");
    string oldName=g_uio[name].value;
    UIO_Set(name,""); g_uioTextCursor=0; g_uioSelectAll=false;
    for (int n=0;n<70;n++) UIO_EditText(name,97,97);
    UIO_Assert(strlen(g_uio[name].value)==63 && cvar_string("name")==oldName,"typing respects the 63-character limit and stays staged");
    UIO_Set(name,oldName);

    int top=UIO_Find("topcolor");
    string oldTop=g_uio[top].value;
    string oldEngineTop=cvar_string("topcolor");
    UIO_TestClick(g_uio[top].pos+[12,12]);
    UIO_Assert(g_uio[top].value!=oldTop && cvar_string("topcolor")==oldEngineTop,"player color slider changes only the staged palette");
    if (g_uio[g_uioModel].supported) {
        string portrait=UIOMP_ModelPortrait(g_uio[g_uioModel].value,stof(g_uio[top].value),0);
        UIO_Assert(portrait!="","the installed player model has a working portrait preview");
        UIO_Assert(!checkbuiltin(r_uploadimage) || portrait=="uiomp/portrait","the installed portrait uses the recolored texture");
    }
    UIO_Set(top,oldTop);

    UIO_Assert(UIO_SelectedChoice(g_uioSprayColor)>=0,"spray color has a visible default selection");
    UIO_Assert(UIO_Parts(g_uio[g_uioSpray].values)>1,"the spray picker finds installed image files");
    string oldSpray=g_uio[g_uioSpray].value, oldColor=g_uio[g_uioSprayColor].value;
    string selected=UIO_Part(g_uio[g_uioSpray].values,1);
    string newColor=oldColor=="255 120 24" ? "255 255 255" : "255 120 24";
    int oldBytes=getlocaluserinfoblob(0,"spray",__NULL__,0);
    string oldInfoColor=getlocaluserinfo(0,"spraycolor");
    UIO_Set(g_uioSpray,selected); UIO_Set(g_uioSprayColor,newColor);
    UIO_Assert(UIO_Dirty() && getlocaluserinfoblob(0,"spray",__NULL__,0)==oldBytes &&
        getlocaluserinfo(0,"spraycolor")==oldInfoColor,"spray image and tint remain staged before Apply");
    UIO_Apply(false);
    filestream file=fopen(selected,FILE_READ);
    int expectedSize=file>=0 ? fsize(file) : 0;
    if (file>=0) fclose(file);
    UIO_Assert(expectedSize>0 && getlocaluserinfoblob(0,"spray",__NULL__,0)==expectedSize && !UIO_Dirty(),
        "Apply sends the selected spray bytes through Nuclide's player-info blob");
    vector expectedColor=strtolower(substring(selected,-4,4))==".bmp" ? stov(newColor)/255 : [1,1,1];
    /* Player info stores the vector as decimal text, with finite precision. */
    bool tintMatches=vlen(stov(getlocaluserinfo(0,"spraycolor"))-expectedColor)<0.00001;
    if (!tintMatches || cvar_string("_cl_playerspray")!=selected || cvar_string("_cl_spraycolor")!=newColor)
        print(sprintf("OPTIONS_SPRAY_STATE file=%S expected=%S tint=%S expected=%v savedColor=%S\n",
            cvar_string("_cl_playerspray"),selected,getlocaluserinfo(0,"spraycolor"),expectedColor,cvar_string("_cl_spraycolor")));
    UIO_Assert(tintMatches &&
        cvar_string("_cl_playerspray")==selected && cvar_string("_cl_spraycolor")==newColor,
        "Apply preserves full-color sprays and saves the monochrome tint preference");
    UIO_Set(g_uioSpray,"logos/does-not-exist.bmp");
    UIO_Apply(false);
    UIO_Assert(getlocaluserinfoblob(0,"spray",__NULL__,0)==expectedSize &&
        cvar_string("_cl_playerspray")==selected && UIO_Dirty(),"a missing spray cannot overwrite the working selection");
    UIO_Cancel();
    UIOMP_TestRestoreSpray();
    UI_Options_Show(); UIO_SetPage(UIO_MULTI);
    UIO_Assert(g_uio[g_uioSpray].value==oldSpray && g_uio[g_uioSprayColor].value==oldColor && !UIO_Dirty(),
        "Cancel and restoration leave the original Multiplayer preferences intact");
}

bool UIOMP_RunTest(string test)
{
    if (test=="mp_palette") { UIOMP_TestPalette(); return true; }
    if (test=="mp_colors") { UIOMP_TestColorApply(); return true; }
    if (test=="mp") { UIOMP_Test(); return true; }
    if (test=="mp_advanced_open") {
        UIO_TestClick(UIOMP_Pos("Advanced",[377,324])+[30,12]);
        UIO_Assert(g_uioMPAdvanced,"Sven's Advanced button opens the options dialog through mouse input");
        return true;
    }
    if (test=="mp_advanced_cancel" || test=="mp_advanced_ok") {
        int crosshair=UIO_Find("crosshair");
        string original=g_uio[crosshair].value;
        int before=g_uiompAdvancedOffset;
        UI_Options_InputEvent(IE_KEYDOWN,K_MWHEELDOWN,0,0);
        UIO_Assert(g_uiompAdvancedOffset>before,"mouse wheel scrolls Sven's Advanced options");
        UI_Options_InputEvent(IE_KEYDOWN,K_MWHEELUP,0,0);
        int unsupported=UIO_Find("hud_weaponautoswitch");
        float oldFlags=cvar_type("hud_weaponautoswitch");
        UIO_Set(unsupported,"2");
        UIO_Assert(!g_uio[unsupported].supported && !UIO_Dirty() && cvar_type("hud_weaponautoswitch")==oldFlags,
            "Sven-only controls are disabled without inventing engine settings");
        UIO_TestClick(g_uio[crosshair].pos+[32,12]);
        UIO_Assert(g_uio[crosshair].value!=original && cvar_string("crosshair")==original,
            "Advanced checkbox edits stay in the parent Options transaction");
        bool keep=test=="mp_advanced_ok";
        UIO_TestClick(keep ? [320,371] : [402,371]);
        UIO_Assert(!g_uioMPAdvanced && g_uioWindow.Visible(),"Advanced footer closes only the child dialog");
        UIO_Assert(keep ? g_uio[crosshair].value!=original : g_uio[crosshair].value==original,
            keep ? "Advanced OK keeps staged edits for the main Apply button" : "Advanced Cancel discards child-dialog edits");
        UIO_Cancel();
        UIO_Assert(cvar_string("crosshair")==original,"main Cancel discards Advanced edits without changing the engine");
        UI_Options_Show(); UIO_SetPage(UIO_MULTI);
        return true;
    }
    if (test=="mp_fixture" || test=="mp_fixture_blue") {
        if (fileExists("models/player/gordon/gordon.bmp")) UIO_Set(g_uioModel,"gordon");
        UIO_Set(UIO_Find("topcolor"),test=="mp_fixture" ? "0" : "170");
        UIO_Set(UIO_Find("bottomcolor"),test=="mp_fixture" ? "170" : "0");
        if (fileExists("logos/lambda.bmp")) UIO_Set(g_uioSpray,"logos/lambda.bmp");
        else UIO_Set(g_uioSpray,UIO_Part(g_uio[g_uioSpray].values,1));
        UIO_Set(g_uioSprayColor,test=="mp_fixture" ? "255 120 24" : "0 167 255");
        if (fileExists("models/player/gordon/gordon.bmp")) {
            string portrait=UIOMP_ModelPortrait("gordon",stof(g_uio[UIO_Find("topcolor")].value),stof(g_uio[UIO_Find("bottomcolor")].value));
            UIO_Assert(portrait=="uiomp/portrait","the rendered Gordon fixture uses the palette-remapped texture");
            vector pos=g_uioOrigin+UIOMP_Pos("ModelImage",[177,136]), size=UIOMP_Size("ModelImage",[154,200]);
            print(sprintf("OPTIONS_PORTRAIT_RECT %g %g %g %g\n",pos[0]/g_vidsize[0],pos[1]/g_vidsize[1],size[0]/g_vidsize[0],size[1]/g_vidsize[1]));
        }
        return true;
    }
    if (test=="mp_fixture_cancel") { UIO_Cancel(); return true; }
    return false;
}
