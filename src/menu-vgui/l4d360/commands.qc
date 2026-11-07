/* FTE service adapters for the original .res commands. */
bool L4D_HasModal(void)
{
    for (vguiWidget child=g_uiDesktop.m_next;child;child=child.m_next)
        if (child.Visible()) return true;
    return false;
}

bool L4D_ModalInput(float event, float key, float character, float device)
{
    if (!L4D_HasModal()) return false;
    if (event == IE_KEYDOWN && (key == K_ESCAPE || key == K_GP_B)) {
        vguiWidget last = __NULL__;
        for (vguiWidget child=g_uiDesktop.m_next;child;child=child.m_next)
            if (child.Visible()) last = child;
        if (last) last.Hide();
        g_l4dPressed = -1;
        L4D_Sound("back");
    } else g_uiDesktop.Input(event,key,character,device);
    return true;
}

void L4D_Notice(string title, string message)
{
    g_l4dNoticeTitle = title;
    g_l4dNoticeText = message;
    g_l4dNotice = true;
    g_l4dPressed = -1;
}

void L4D_RunCommand(string command)
{
    g_l4dLastAction = command;
    switch (command) {
    case "VersusSoftLock":
        for (int i=0;i<g_l4dFlyoutCount;i++)
            if (g_l4dFlyouts[i].fieldName == "FlmVersusFlyout")
                L4D_OpenFlyout(i,L4D_FindButton("BtnVersus",-1));
        break;
    case "SoloPlay":
        UI_NewGame_Show();
        break;
    case "QuickMatchCoOp":
    case "QuickMatchVersus":
    case "PlayCoopWithAnyone":
    case "PlayVersusWithAnyone":
    case "SeeAll":
        /* Joining one of FTE's compatible games remains an explicit choice. */
        UI_FindServers_Show();
        break;
    case "PlayCoopWithFriends":
    case "PlayVersusWithFriends":
        UI_CreateServer_Show();
        break;
    case "AudioVideo":
        UI_Options_Show(); UIO_SetPage(UIO_AUDIO);
        break;
    case "Controller":
        UI_Options_Show(); UIO_SetPage(UIO_KEYBOARD);
        break;
    case "OpenOptionsDialog":
        UI_Options_Show();
        break;
    case "QuitGame":
        UI_QuitGame_Show();
        break;
    case "Storage":
        L4D_Notice(L4D_Text("#L4D360UI_Storage"),
            "This game saves locally. Xbox storage-device selection is not available on this system.");
        break;
    case "StatsAndAchievements":
        L4D_Notice(L4D_Text("#L4D360UI_MainMenu_StatsAndAchievements"),
            "This game has not supplied statistics or achievements for this menu.");
        break;
    case "DeveloperCommentary":
        L4D_Notice(L4D_Text("#L4D360UI_Extras_Commentary"),
            "Developer commentary is not available for the current game.");
        break;
    case "Credits":
        L4D_Notice(L4D_Text("#L4D360UI_Extras_Credits"),
            "Original Left 4 Dead interface and Alien Swarm menu code: Valve. Nuclide framework: Vera Visions. Engine: FTE QuakeWorld.");
        break;
    default:
        print(sprintf("L4D360: unhandled title command %s\n",command));
        L4D_Sound("invalid");
        break;
    }
    /* A press-activated main item hands the release to its new dialog. */
    if (L4D_HasModal()) g_l4dPressed = -1;
}

/* The stock menu keeps the Xbox frames as authored. */
void L4D_FrameLoaded(string frame)
{
}
