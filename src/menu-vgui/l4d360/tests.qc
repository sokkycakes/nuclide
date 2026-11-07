#ifdef LAB_L4D360_TEST
int g_l4dTestCount, g_l4dTestFailed;
bool g_l4dReadinessReported;
float Menu_InputEvent(float event, float key, float character, float device);

void L4D_TestAssert(bool passed, string description)
{
    g_l4dTestCount++;
    if (!passed) g_l4dTestFailed++;
    print(sprintf("L4D360_TEST %s: %s\n",passed ? "PASS" : "FAIL",description));
}

void L4D_TestKey(float key)
{
    Menu_InputEvent(IE_KEYDOWN,key,0,0);
    Menu_InputEvent(IE_KEYUP,key,0,0);
}

void L4D_TestMouse(vector authored)
{
    vector point=L4D_Point(authored);
    Menu_InputEvent(IE_MOUSEABS,point[0],point[1],0);
}

void L4D_TestReset(void)
{
    UI_Options_Close();
    for (vguiWidget child=g_uiDesktop.m_next;child;child=child.m_next) child.Hide();
    g_l4dNotice = false;
    g_l4dPressed = -1;
    L4D_CloseFlyout(false);
    L4D_SetFocus(L4D_FindButton("BtnCoOp",-1),false);
    g_l4dLastMouse = getmousepos();
}

void L4D_TestBehavior(void)
{
    L4D_TestReset();
    int coop = L4D_FindButton("BtnCoOp",-1);
    int options = L4D_FindButton("BtnOptions",-1);
    int extras = L4D_FindButton("BtnExtras",-1);
    int mainCount=0;
    for (int i=0;i<g_l4dButtonCount;i++) if (g_l4dButtons[i].scope==-1 && g_l4dButtons[i].shown) mainCount++;
    L4D_TestAssert(mainCount==6,"Xbox main menu has six controls");
    L4D_TestAssert(L4D_FindButton("BtnQuit",-1)==-1,"WIN32-only block is excluded");
    L4D_TestAssert(g_l4dButtons[coop].boundsPos==[100,100] && g_l4dButtons[coop].boundsSize==[180,20],"main geometry matches original resource");
    L4D_TestAssert(g_l4dButtons[options].command=="FlmOptionsFlyout","X360 scalar override selects Options flyout");
    L4D_TestAssert(L4D_Text("#L4D360UI_MainMenu_CoOp")!="#L4D360UI_MainMenu_CoOp","original localization loaded");
    L4D_TestKey(K_GP_DPAD_UP);
    L4D_TestAssert(g_l4dFocus==extras,"D-pad wraps through authored navUp link");
    L4D_TestKey(K_DOWNARROW);
    L4D_TestAssert(g_l4dFocus==coop,"keyboard and controller share focus");
    L4D_Input(IE_KEYDOWN,K_GP_A,0,0);
    L4D_TestAssert(g_l4dOpen>=0,"press-activated main button opens immediately");
    L4D_TestAssert(g_l4dFlyouts[g_l4dOpen].pos==[280,100],"flyout attaches at source button right edge");
    L4D_TestAssert(g_l4dFlyouts[g_l4dOpen].size==[180,65],"English conditional flyout dimensions");
    L4D_TestAssert(g_l4dButtons[g_l4dFocus].fieldName=="BtnQuickMatch","InitialFocus applied on opening");
    L4D_Input(IE_KEYUP,K_GP_A,0,0);
    L4D_TestAssert(!L4D_HasModal() && g_l4dOpen>=0,"opening key release does not activate child");
    int before = g_l4dFocus;
    L4D_TestKey(K_GP_B);
    L4D_TestAssert(g_l4dOpen==-1 && g_l4dFocus==coop,"Back closes flyout and restores source focus");
    L4D_TestKey(K_GP_A);
    L4D_TestAssert(g_l4dFocus==before,"reopening starts at InitialFocus");
    L4D_CloseFlyout(false);
    L4D_SetFocus(extras,false);
    L4D_TestKey(K_ENTER);
    L4D_TestAssert(g_l4dButtons[g_l4dFocus].fieldName=="BtnCommentary","Xbox Extras initially selects commentary");
    L4D_TestAssert(g_l4dFlyouts[g_l4dOpen].size==[156,45],"Xbox Extras omits PC-only movie row");
    L4D_TestKey(K_UPARROW);
    L4D_TestAssert(g_l4dButtons[g_l4dFocus].fieldName=="BtnCredits","navigation skips hidden movie button");
    L4D_TestKey(K_DOWNARROW);
    L4D_TestAssert(g_l4dButtons[g_l4dFocus].fieldName=="BtnCommentary","hidden-link wrap works in both directions");
    L4D_CloseFlyout(false);
    L4D_SetFocus(options,false);
    L4D_TestKey(K_ENTER);
    L4D_Input(IE_KEYDOWN,K_ENTER,0,0);
    L4D_TestAssert(!L4D_HasModal(),"release-activated flyout item waits for release");
    L4D_Input(IE_KEYUP,K_ENTER,0,0);
    L4D_TestAssert(g_l4dLastAction=="AudioVideo" && L4D_HasModal(),"AudioVideo dispatch opens existing Options");
    L4D_TestAssert(g_l4dOpen==-1 && g_l4dFocus==options,"command dispatch closes flyout and retains return focus");
    UI_Options_Close();
    L4D_TestAssert(!L4D_HasModal(),"Options closes without leaving a modal blocker");
    L4D_TestAssert(L4D_Hit(L4D_Point([105,105]))==coop,"mouse hit coordinates use same proportional transform");
    L4D_TestAssert(L4D_Hit(L4D_Point([99,105]))!=coop,"mouse hit bounds do not extend left of button");
    L4D_TestAssert(L4D_Coord("r100",480)==380 && L4D_Coord("f0",640)==640,"Source right/fill coordinates");
    L4D_TestAssert(clientstate()!=2,"title runs without loading a background map");
    L4D_TestReset();
    L4D_SetFocus(-1,false);
    L4D_TestAssert(g_l4dFocus==coop,"invalid focus does not access a negative array index");
    L4D_TestKey(K_GP_B);
    L4D_TestAssert(!L4D_HasModal() && g_l4dFocus==coop,"root controller B is consumed without opening Quit");
    Menu_InputEvent(IE_KEYUP,K_ENTER,0,0);
    L4D_TestAssert(g_l4dOpen==-1,"an unmatched release cannot activate a control");
    g_l4dButtons[coop].available=false;
    L4D_TestKey(K_GP_A);
    L4D_TestAssert(g_l4dOpen==-1 && !L4D_HasModal(),"disabled controls do not dispatch");
    g_l4dButtons[coop].available=true;
    L4D_TestKey(K_SPACE);
    L4D_TestAssert(g_l4dOpen>=0,"Space activates through the real menu input route");
    L4D_TestKey(K_GP_B);
    int solo=L4D_FindButton("BtnPlaySolo",-1);
    L4D_SetFocus(solo,false);
    Menu_InputEvent(IE_KEYDOWN,K_ENTER,0,0);
    L4D_TestAssert(L4D_HasModal() && g_l4dPressed==-1,"press-activated dialog clears the title press latch");
    Menu_InputEvent(IE_KEYUP,K_ENTER,0,0);
    L4D_TestKey(K_DOWNARROW);
    L4D_TestAssert(g_l4dFocus==solo && L4D_HasModal(),"dialog input does not navigate the title underneath");
    L4D_TestKey(K_ESCAPE);
    L4D_TestAssert(!L4D_HasModal() && g_l4dFocus==solo,"dialog cancel retains the launching title focus");
    L4D_SetFocus(coop,false);
    L4D_TestKey(K_ENTER);
    L4D_TestAssert(g_l4dOpen>=0,"title activation works after a modal returns");
    L4D_TestReset();
    L4D_TestKey(K_ESCAPE);
    L4D_TestAssert(L4D_HasModal(),"desktop Escape opens the existing quit confirmation");
    L4D_TestKey(K_GP_B);
    L4D_TestAssert(!L4D_HasModal(),"controller B cancels the quit confirmation");
    cvar_set("ui_l4d360","0");
    L4D_TestAssert(!L4D_Active() && g_uiClassicDesktop.m_next!=__NULL__,"classic desktop remains available");
    cvar_set("ui_l4d360","1");
    L4D_TestAssert(L4D_Active(),"title can be re-enabled without restarting");
    L4D_TestReset();
}

void L4D_RunTests(string cmd)
{
    tokenize_console(cmd);
    string action=argv(1), target=argv(2);
    if (action=="ready") {
        if (!g_l4dReadinessReported) {
            print(sprintf("L4D360_STARTUP ready=%g active=%i enabled=%g client=%g keydest=%g loaded=%g\n",g_l4dReady,g_active,autocvar_ui_l4d360,clientstate(),getkeydest(),g_l4dLoaded));
            g_l4dReadinessReported=true;
        }
        cvar_set("lab_l4d360_ready",g_l4dReady ? "1" : "0");
        return;
    }
    if (action=="behavior") L4D_TestBehavior();
    else if (action=="mouse") {
        L4D_TestReset();
        L4D_TestMouse([105,105]);
        L4D_TestAssert(g_l4dPointer==L4D_Point([105,105]),"mouse motion event reaches the authored button");
        L4D_TestKey(K_MOUSE1);
        L4D_TestAssert(g_l4dOpen>=0,"mouse press uses authored bounds through Menu_InputEvent");
        L4D_TestMouse([300,110]);
        Menu_InputEvent(IE_KEYDOWN,K_MOUSE1,0,0);
        L4D_TestAssert(!L4D_HasModal() && g_l4dOpen>=0,"mouse flyout activation waits for release");
        L4D_TestMouse([500,300]);
        Menu_InputEvent(IE_KEYUP,K_MOUSE1,0,0);
        L4D_TestAssert(!L4D_HasModal(),"dragging off a flyout item cancels its release activation");
        L4D_TestKey(K_MOUSE1);
        L4D_TestAssert(g_l4dOpen==-1,"outside mouse press closes the flyout");
        L4D_MouseMove(getmousepos());
        L4D_TestReset();
    } else if (action=="renderer") {
        L4D_TestAssert(g_l4dReady && L4D_Active(),"title survives a real renderer restart");
        L4D_TestAssert(L4D_Width("PLAY CAMPAIGN",g_l4dMainFont,g_l4dMainHeight)>50,"title font metrics survive renderer restart");
        L4D_TestKey(K_ENTER);
        L4D_TestAssert(g_l4dOpen>=0,"input still opens a flyout after renderer restart");
        L4D_TestReset();
    }
    else if (action=="reset") L4D_TestReset();
    else if (action=="focus") { L4D_TestReset(); L4D_SetFocus(L4D_FindButton(target,-1),false); }
    else if (action=="open") { L4D_TestReset(); L4D_Activate(L4D_FindButton(target,-1)); }
    else if (action=="inspect") {
        print(sprintf("L4D360_CANVAS %.3f %.3f scale %.4f origin %.3f %.3f\n",g_l4dExtent[0],g_l4dExtent[1],g_l4dScale,g_l4dOrigin[0],g_l4dOrigin[1]));
        for (int i=0;i<g_l4dButtonCount;i++) {
            l4dHybridButton button=g_l4dButtons[i];
            if (button.scope!=-1) continue;
            vector pos=L4D_Point(button.boundsPos), size=button.boundsSize*g_l4dScale;
            print(sprintf("L4D360_RECT %s %.3f %.3f %.3f %.3f\n",button.fieldName,pos[0],pos[1],size[0],size[1]));
        }
    } else if (action=="summary") {
        print(sprintf("L4D360_TEST_ASSERTIONS %i\nL4D360_TEST_FAILURES %i\n",g_l4dTestCount,g_l4dTestFailed));
    }
}
#endif
