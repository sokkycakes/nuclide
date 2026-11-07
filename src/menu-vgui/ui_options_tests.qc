/* Included only with -DLAB_OPTIONS_TEST. Never part of the release menu. */
int g_uioTestFailures;
int g_uioTestAssertions;
string g_uioTestOriginal[UIO_SETTINGS];
string g_uioTestBinds[UIO_KEYS];
string g_uioTestWidth;
string g_uioTestHeight;
string g_uioTestFullscreen;
string g_uioTestVsync;
vector g_uioTestPixels;
void *g_uioTestSprayBlob;
int g_uioTestSprayBytes;
string g_uioTestSprayColorInfo;
string g_uioTestSprayTypeInfo;
string g_uioTestSprayFile;
string g_uioTestSprayColor;
string g_uioTestTopColor;
string g_uioTestBottomColor;
void UIO_Assert(bool condition, string label)
{
    print(sprintf("OPTIONS_TEST %s: %s\n",condition ? "PASS" : "FAIL",label));
    g_uioTestAssertions++;
    if (!condition) g_uioTestFailures++;
}

void UIO_TestClick(vector relative)
{
    g_vecMousePos=g_uioWindow.GetPos()+relative;
    g_uioWindow.Input(IE_KEYDOWN,K_MOUSE1,0,0);
    g_uioWindow.Input(IE_KEYUP,K_MOUSE1,0,0);
}

void UIO_TestRestoreBinds(void)
{
    for (int k=0;k<UIO_KEYS;k++)
        if (getkeybind(k,0,0)!=g_uioTestBinds[k])
            setkeybind(k,g_uioTestBinds[k],0,0);
}

void UIO_TestLayout(void)
{
    int tabs=0, footers=0, bad=0, pageControls=0;
    for (int h=0;h<g_uioHitCount;h++) {
        vector p=g_uioHits[h].pos, s=g_uioHits[h].size;
        if (p[0]<0 || p[1]<0 || p[0]+s[0]>UIO_W || p[1]+s[1]>UIO_H) bad++;
        if (g_uioHits[h].kind==UIO_H_TAB) tabs++;
        if (g_uioHits[h].kind==UIO_H_APPLY || g_uioHits[h].kind==UIO_H_OK || g_uioHits[h].kind==UIO_H_CANCEL) footers++;
        if (g_uioHits[h].kind==UIO_H_SETTING) {
            pageControls++;
            if (g_uio[g_uioHits[h].index].page!=g_uioPage) bad++;
        }
    }
    if (tabs!=6 || footers!=3 || bad!=0)
        print(sprintf("OPTIONS_LAYOUT_STATE page=%i hits=%i tabs=%i footers=%i outside=%i\n",
            g_uioPage,g_uioHitCount,tabs,footers,bad));
    UIO_Assert(tabs==6 && footers==3 && bad==0,sprintf("page %i controls fit the sheet with six tabs and three footer buttons",g_uioPage));
    UIO_Assert(g_uioPage==UIO_KEYBOARD || pageControls>=4,sprintf("page %i has its own working controls",g_uioPage));
    bool readable=true;
    for (int r=0;r<g_uioActionCount;r++)
        if (substring(g_uioActionLabel[r],0,1)=="#") readable=false;
    UIO_Assert(readable,"keyboard action labels resolved to readable text");
}

void UIO_TestMouse(void)
{
    int sensitivity=UIO_Find("sensitivity");
    string original=cvar_string("sensitivity");
    UIO_TestClick(g_uio[sensitivity].pos+[110,12]);
    UIO_Assert(g_uio[sensitivity].value!=original && cvar_string("sensitivity")==original,"slider drag stages a change without changing the engine");
    int inverse=UIO_Find("m_pitch");
    string oldPitch=g_uio[inverse].value;
    UIO_TestClick(g_uio[inverse].pos+[80,10]);
    UIO_Assert(stof(g_uio[inverse].value)==-stof(oldPitch),"reverse mouse checkbox toggles the pitch sign");
    UIO_TestClick([368,426]);
    UIO_Assert(!g_uioWindow.Visible() && cvar_string("sensitivity")==original && cvar_string("m_pitch")==oldPitch,"Cancel discards all staged mouse changes");
    UI_Options_Show(); UIO_SetPage(UIO_MOUSE);
    UIO_TestClick(g_uio[sensitivity].pos+[160,12]);
    string expected=g_uio[sensitivity].value;
    UIO_Apply(false);
    UIO_Assert(cvar_string("sensitivity")==expected && !UIO_Dirty(),"Apply commits a slider change and resets the dirty state");
    UIO_Set(sensitivity,"3.7");
    UIO_Cancel();
    UIO_Assert(cvar_string("sensitivity")==expected,"Cancel after Apply keeps the applied value");
    cvar_set("sensitivity",original);
    UI_Options_Show(); UIO_SetPage(UIO_MOUSE);
    bool supported=g_uio[inverse].supported;
    g_uio[inverse].supported=false;
    UIO_Set(inverse,"-0.04");
    UIO_Assert(g_uio[inverse].value==oldPitch,"unsupported settings reject changes");
    g_uio[inverse].supported=supported;
}

void UIO_TestKeys(void)
{
    g_uioWindow.Input(IE_KEYDOWN,K_MWHEELDOWN,0,0);
    UIO_Assert(g_uioKeyOffset>0,"mouse wheel scrolls the keyboard action list");
    g_uioWindow.Input(IE_KEYDOWN,K_MWHEELUP,0,0);
    UIO_Assert(g_uioKeyOffset==0,"keyboard list scrolls back to its first row");
    int row=-1;
    for (int r=0;r<g_uioActionCount;r++)
        if (g_uioAction[r]=="+jump") row=r;
    UIO_Assert(row>=0,"jump action available for rebinding");
    if (row<0) return;
    int key=stringtokeynum("F11"), sentinel=stringtokeynum("F12");
    setkeybind(key,"echo OPTIONS_KEY_CONFLICT",0,0);
    setkeybind(sentinel,"echo OPTIONS_UNRELATED",0,0);
    UIO_LoadSnapshot();
    g_uioKeyRow=row; g_uioKeyColumn=1;
    g_uioCapture=row;
    UI_Options_InputEvent(IE_KEYDOWN,K_ESCAPE,0,0);
    UIO_Assert(g_uioCapture==-1 && g_uioWindow.Visible(),"Escape cancels key capture without closing Options");
    g_uioCapture=row;
    UI_Options_InputEvent(IE_KEYDOWN,key,0,0);
    UIO_Assert(g_uioBind[key]=="+jump" && getkeybind(key,0,0)=="echo OPTIONS_KEY_CONFLICT","rebinding an occupied alternate key stays staged");
    UIO_Cancel();
    UIO_Assert(getkeybind(key,0,0)=="echo OPTIONS_KEY_CONFLICT","Cancel preserves the displaced key's original command");
    UI_Options_Show();
    g_uioKeyRow=row; g_uioKeyColumn=1; g_uioCapture=row;
    UI_Options_InputEvent(IE_KEYDOWN,key,0,0);
    UIO_Apply(false);
    UIO_Assert(getkeybind(key,0,0)=="+jump" && getkeybind(sentinel,0,0)=="echo OPTIONS_UNRELATED","Apply updates the selected key and preserves unrelated custom bindings");
    UIO_Defaults();
    UIO_Assert(g_uioBind[sentinel]=="echo OPTIONS_UNRELATED" && getkeybind(key,0,0)=="+jump","Use defaults stages changes without unbindall or early application");
    UIO_Cancel();
    UIO_Assert(getkeybind(key,0,0)=="+jump","Cancel discards unapplied default bindings");
    UIO_TestRestoreBinds();
    UI_Options_Show();
}

void UIO_TestAudio(void)
{
    int volume=UIO_Find("volume");
    string old=cvar_string("volume");
    string fs=cvar_string("vid_fullscreen");
    UIO_TestClick(g_uio[volume].pos+[210,12]);
    UIO_Assert(cvar_string("volume")==old && g_uio[volume].value!=old,"sound volume stays staged until Apply");
    UIO_Apply(false);
    UIO_Assert(cvar_string("volume")==g_uio[volume].value && cvar_string("vid_fullscreen")==fs && !g_uioVideoPending,"audio Apply leaves the display mode untouched");
    cvar_set("volume",old);
    UIO_LoadSnapshot();
}

void UIO_TestPopup(void)
{
    string old=g_uio[g_uioResolution].value;
    UIO_TestClick(g_uio[g_uioResolution].pos+[80,12]);
    UIO_Assert(g_uioPopup==g_uioResolution,"resolution dropdown opens through mouse input");
    UI_Options_InputEvent(IE_KEYDOWN,K_ESCAPE,0,0);
    UIO_Assert(g_uioPopup==-1 && g_uioWindow.Visible(),"Escape closes the dropdown without closing Options");
    UIO_TestClick(g_uio[g_uioResolution].pos+[80,12]);
    UI_Options_InputEvent(IE_KEYDOWN,K_UPARROW,0,0);
    UI_Options_InputEvent(IE_KEYDOWN,K_ENTER,0,0);
    UIO_Assert(g_uioPopup==-1 && g_uio[g_uioResolution].value!=old && !g_uioVideoPending,"dropdown keyboard selection stages a resolution without a restart");
    UIO_Set(g_uioResolution,old);
    UIO_TestClick(g_uio[g_uioResolution].pos+[80,12]);
    UIO_Assert(g_uioPopupSelection==UIO_SelectedChoice(g_uioResolution),"dropdown retains the current selection when reopened");
    vector pos=UIO_PopupPos();
    string first=UIO_Part(g_uio[g_uioResolution].values,g_uioPopupOffset);
    UIO_TestClick(pos+[30,12]);
    UIO_Assert(g_uio[g_uioResolution].value==first && g_uioPopup==-1,"dropdown mouse selection returns the chosen value");
    UIO_Set(g_uioResolution,old);
}

void UIO_TestName(void)
{
    int name=UIO_Find("name");
    string old=cvar_string("name");
    UIO_TestClick(g_uio[name].pos+[100,12]);
    g_uioWindow.Input(IE_KEYDOWN,76,76,0);
    g_uioWindow.Input(IE_KEYDOWN,97,97,0);
    g_uioWindow.Input(IE_KEYDOWN,98,98,0);
    UIO_Assert(g_uio[name].value=="Lab" && cvar_string("name")==old,"focused name field replaces its selection and stages typed text");
    g_uioWindow.Input(IE_KEYDOWN,K_LEFTARROW,0,0);
    g_uioWindow.Input(IE_KEYDOWN,88,88,0);
    UIO_Assert(g_uio[name].value=="LaXb","text cursor navigation inserts at the selected position");
    UIO_Set(name,"");
    UIO_Apply(false);
    UIO_Assert(g_uioWindow.Visible() && cvar_string("name")==old && g_uioStatus=="Player name is required.","empty player names are rejected without changing the engine");
    UIO_Set(name,"Lab \"Test\"; name");
    UIO_Apply(false);
    UIO_Assert(cvar_string("name")=="Lab \"Test\"; name","player name punctuation is assigned as data, not executed as commands");
    cvar_set("name",old);
    UIO_LoadSnapshot();
}

void UIO_TestVoice(void)
{
    int mic=UIO_Find("cl_voip_micamp"), play=UIO_Find("cl_voip_play");
    string old=cvar_string("cl_voip_micamp");
    UIO_Assert(mic>=0 && play>=0,"voice controls use the engine's cl_voip cvars");
    UIO_TestClick(g_uio[mic].pos+[100,12]);
    UIO_Assert(cvar_string("cl_voip_micamp")==old,"microphone gain edits do not start capture or change the engine");
    /* Exercise cleanup using gain-only preview state; never open a microphone. */
    g_uioMicOldTest=cvar_string("cl_voip_test");
    g_uioMicOldPlay=cvar_string("cl_voip_play");
    g_uioMicOldGain=old;
    cvar_set("cl_voip_micamp","0.2");
    g_uioMicTesting=true;
    UIO_StopMic();
    UIO_Assert(!g_uioMicTesting && cvar_string("cl_voip_micamp")==old,"leaving microphone test restores the previous gain");
    UIO_LoadSnapshot();
}

void UIO_TestRestore(void)
{
    UIO_Cancel();
    for (int i=0;i<g_uioCount;i++)
        if (substring(g_uio[i].key,0,1)!="$" && g_uio[i].supported)
            cvar_set(g_uio[i].key,g_uioTestOriginal[i]);
    cvar_set("_cl_playerspray",g_uioTestSprayFile);
    cvar_set("_cl_spraycolor",g_uioTestSprayColor);
    cvar_set("topcolor",g_uioTestTopColor);
    cvar_set("bottomcolor",g_uioTestBottomColor);
    setlocaluserinfoblob(0,"spray",g_uioTestSprayBlob,g_uioTestSprayBytes);
    setlocaluserinfo(0,"spraycolor",g_uioTestSprayColorInfo);
    setlocaluserinfo(0,"spraytype",g_uioTestSprayTypeInfo);
    UIO_TestRestoreBinds();
    cvar_set("vid_width",g_uioTestWidth);
    cvar_set("vid_height",g_uioTestHeight);
    cvar_set("vid_fullscreen",g_uioTestFullscreen);
    cvar_set("vid_vsync",g_uioTestVsync);
    localcmd("vid_restart\n");
}

#include "ui_options_multiplayer_tests.qc"

void UIO_RunTestCommand(string command)
{
    int argc=tokenize_console(command);
    string test=argv(1);
    if (UIOMP_RunTest(test)) return;
    if (test=="ready") {
        /* Background-map connection/loading can consume waits without drawing
         * the dialog. Let the engine config poll for a real Options frame.
         * Do not exec the suite from MenuQC: its command buffer must stay
         * separate from the vid_restart commands issued by the controls. */
        UI_Options_Show();
        g_active=true;
        setkeydest(KEY_MENU);
        /* clientstate()==1 is a valid disconnected title screen in MenuQC. */
        bool ready=g_uioHitCount>0;
        cvar_set("lab_options_ready",ready ? "1" : "0");
        if (ready) print("OPTIONS_TEST_READY\n");
        return;
    }
    if (test=="summary") {
        print(sprintf("OPTIONS_TEST_TOTAL_ASSERTIONS %i\n",g_uioTestAssertions));
        print(sprintf("OPTIONS_TEST_TOTAL_FAILURES %i\n",g_uioTestFailures));
        return;
    }
    if (test=="inspect") {
        for (int i=0;i<g_uioCount;i++)
            print(sprintf("OPTIONS_SETTING %s supported=%i value=%s\n",g_uio[i].key,(int)g_uio[i].supported,g_uio[i].value));
        UIO_Assert(g_uioActionCount>10,"game keyboard action list loaded");
        UIO_Assert(g_uioCount>=25,"all property pages populated");
    }
    if (test=="begin") {
        g_uioTestTopColor=cvar_string("topcolor");
        g_uioTestBottomColor=cvar_string("bottomcolor");
        for (int i=0;i<g_uioCount;i++) g_uioTestOriginal[i]=g_uio[i].supported ? UIO_ReadSetting(i) : "";
        g_uioTestSprayFile=cvar_string("_cl_playerspray");
        g_uioTestSprayColor=cvar_string("_cl_spraycolor");
        g_uioTestSprayColorInfo=getlocaluserinfo(0,"spraycolor");
        g_uioTestSprayTypeInfo=getlocaluserinfo(0,"spraytype");
        g_uioTestSprayBytes=getlocaluserinfoblob(0,"spray",__NULL__,0);
        if (g_uioTestSprayBlob) memfree(g_uioTestSprayBlob);
        g_uioTestSprayBlob=memalloc(g_uioTestSprayBytes+1);
        getlocaluserinfoblob(0,"spray",g_uioTestSprayBlob,g_uioTestSprayBytes);
        for (int k=0;k<UIO_KEYS;k++) g_uioTestBinds[k]=getkeybind(k,0,0);
        g_uioTestWidth=cvar_string("vid_width");
        g_uioTestHeight=cvar_string("vid_height");
        g_uioTestFullscreen=cvar_string("vid_fullscreen");
        g_uioTestVsync=cvar_string("vid_vsync");
        g_uioTestPixels=getproperty(VF_SCREENPSIZE);
        print("OPTIONS_TEST_BEGIN\n");
    }
    if (test=="layout") UIO_TestLayout();
    if (test=="keys") UIO_TestKeys();
    if (test=="mouse") UIO_TestMouse();
    if (test=="audio") UIO_TestAudio();
    if (test=="popup") UIO_TestPopup();
    if (test=="voice") UIO_TestVoice();
    if (test=="name") UIO_TestName();
    if (test=="button_stage") {
        int setting=UIO_Find("sensitivity");
        UIO_TestClick(g_uio[setting].pos+[200,12]);
        UIO_Assert(UIO_Dirty(),"mouse input makes Apply available on the next rendered frame");
    }
    if (test=="button_apply") {
        string expected=g_uio[UIO_Find("sensitivity")].value;
        UIO_TestClick([448,426]);
        UIO_Assert(cvar_string("sensitivity")==expected && !UIO_Dirty(),"the visible Apply button commits through native mouse input");
        UIO_TestClick([287,426]);
        UIO_Assert(!g_uioWindow.Visible(),"the visible OK button closes a clean settings sheet");
    }
    if (test=="video_start") {
        UIO_Set(g_uioResolution,"800x600");
        UIO_Apply(false);
        UIO_Assert(g_uioVideoPending,"changing resolution creates a confirmation transaction");
    }
    if (test=="video_changed") {
        vector pixels=getproperty(VF_SCREENPSIZE);
        UIO_Assert(g_uioVideoPending && g_uioWindow.Visible() && pixels[0]==800 && pixels[1]==600,"actual renderer restart preserves the confirmation dialog at 800x600");
    }
    if (test=="video_revert") UI_Options_InputEvent(IE_KEYDOWN,K_ESCAPE,0,0);
    if (test=="video_restored") {
        vector pixels=getproperty(VF_SCREENPSIZE);
        UIO_Assert(!g_uioVideoPending && pixels==g_uioTestPixels,"Revert restores the previous actual display dimensions");
    }
    if (test=="video_keep") UI_Options_InputEvent(IE_KEYDOWN,K_ENTER,0,0);
    if (test=="video_kept") {
        UIO_Assert(!g_uioVideoPending && !UIO_Dirty() && g_uio[g_uioResolution].original=="800x600","Keep settings commits the confirmed display mode");
        UIO_Set(g_uioResolution,"640x480"); UIO_Apply(false);
    }
    if (test=="video_timeout") {
        UIO_Assert(g_uioVideoPending,"second display change is awaiting confirmation");
        g_uioVideoDeadline=time-1; UI_Options_Frame();
    }
    if (test=="video_timeout_check") {
        vector pixels=getproperty(VF_SCREENPSIZE);
        UIO_Assert(!g_uioVideoPending && pixels[0]==800 && pixels[1]==600,"confirmation timeout restores the last confirmed mode");
        UIO_Set(g_uioResolution,"640x480"); UIO_Apply(false);
    }
    if (test=="video_close") {
        UIO_TestClick([482,14]);
        UIO_Assert(!g_uioWindow.Visible() && !g_uioVideoPending,"closing Options rolls back an unconfirmed display mode");
    }
    if (test=="restore") UIO_TestRestore();
    if (test=="restored") {
        bool bindings=true, settings=true;
        for (int k=0;k<UIO_KEYS;k++) if (getkeybind(k,0,0)!=g_uioTestBinds[k]) bindings=false;
        for (int i=0;i<g_uioCount;i++)
            if (g_uio[i].key!="$resolution" && g_uio[i].supported)
                if (UIO_ReadSetting(i)!=g_uioTestOriginal[i]) settings=false;
        UIO_Assert(bindings && settings,"test run restores every original setting and binding");
        UIO_Assert(getproperty(VF_SCREENPSIZE)==g_uioTestPixels,"test run restores the original window size");
        UIO_Assert(getlocaluserinfoblob(0,"spray",__NULL__,0)==g_uioTestSprayBytes &&
            getlocaluserinfo(0,"spraycolor")==g_uioTestSprayColorInfo && getlocaluserinfo(0,"spraytype")==g_uioTestSprayTypeInfo,
            "test run restores the original spray data and tint");
        if (g_uioTestSprayBlob) { memfree(g_uioTestSprayBlob); g_uioTestSprayBlob=__NULL__; }
    }
}
