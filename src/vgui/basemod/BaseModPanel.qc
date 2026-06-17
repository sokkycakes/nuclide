// Nuclide QC port of Alien Swarm BaseModUI CBaseModPanel
// Full autonomous migration from src/vgui/basemod/basemodpanel.cpp/h

class CBaseModPanel : vguiWindow
{
	CBaseModFrame m_ActiveWindow;
	CBaseModFrame m_WindowStack[WT_WINDOW_COUNT];

	void CBaseModPanel(void);

	nonvirtual CBaseModFrame OpenWindow(WINDOW_TYPE wt, CBaseModFrame caller, bool hidePrevious = true);
	nonvirtual CBaseModFrame GetWindow(WINDOW_TYPE wt);
	nonvirtual void CloseAllWindows(int policy = 0);
	nonvirtual void RunFrame(void);
};

CBaseModPanel g_BaseModPanel;

void
CBaseModPanel::CBaseModPanel(void)
{
	g_BaseModPanel = this;
}

CBaseModFrame
CBaseModPanel::OpenWindow(WINDOW_TYPE wt, CBaseModFrame caller, bool hidePrevious)
{
	if (m_WindowStack[wt]) {
		return m_WindowStack[wt];
	}

	CBaseModFrame w;
	switch (wt) {
	case WT_MAINMENU: w = spawn(VMainMenu); break;
	case WT_INGAMEMAINMENU: w = spawn(VInGameMainMenu); break;
	case WT_GENERICCONFIRMATION: w = spawn(VGenericConfirmation); break;
	case WT_GENERICWAITSCREEN: w = spawn(VGenericWaitScreen); break;
	case WT_LOADINGPROGRESS: w = spawn(VLoadingProgress); break;
	case WT_TRANSITIONSCREEN: w = spawn(VTransitionScreen); break;
	case WT_OPTIONS: w = spawn(VOptions); break;
	case WT_AUDIO: w = spawn(VAudio); break;
	case WT_VIDEO: w = spawn(VVideo); break;
	case WT_KEYBOARDMOUSE: w = spawn(VKeyboardMouse); break;
	case WT_ACHIEVEMENTS: w = spawn(VAchievements); break;
	case WT_GAMELOBBY: w = spawn(VGameLobby); break;
	case WT_GAMEOPTIONS: w = spawn(VGameOptions); break;
	case WT_GAMESETTINGS: w = spawn(VGameSettings); break;
	case WT_FOUNDPUBLICGAMES: w = spawn(VFoundPublicGames); break;
	case WT_SIGNINDIALOG: w = spawn(VSignInDialog); break;
	case WT_ATTRACTSCREEN: w = spawn(VAttractScreen); break;
	case WT_PASSWORDENTRY: w = spawn(VPasswordEntry); break;
	case WT_ADDONS: w = spawn(VAddons); break;
	case WT_CUSTOMCAMPAIGNS: w = spawn(VCustomCampaigns); break;
	case WT_DOWNLOADS: w = spawn(VDownloads); break;
	case WT_DOWNLOADCAMPAIGN: w = spawn(VDownloadCampaign); break;
	case WT_JUKEBOX: w = spawn(VJukebox); break;
	case WT_LEADERBOARD: w = spawn(VLeaderboard); break;
	case WT_CONTROLLER: w = spawn(VControllerOptions); break;
	case WT_CONTROLLER_STICKS: w = spawn(VControllerOptionsSticks); break;
	case WT_CONTROLLER_BUTTONS: w = spawn(VControllerOptionsButtons); break;
	case WT_CLOUD: w = spawn(VCloud); break;
	case WT_STEAMCLOUDCONFIRM: w = spawn(VSteamCloudConfirmation); break;
	case WT_VOTEOPTIONS: w = spawn(VVoteOptions); break;
	case WT_INGAMEDIFFICULTYSELECT: w = spawn(VInGameDifficultySelect); break;
	case WT_INGAMECHAPTERSELECT: w = spawn(VInGameChapterSelect); break;
	case WT_INGAMEKICKPLAYERLIST: w = spawn(VInGameKickPlayerList); break;
	case WT_MULTIPLAYER: w = spawn(VMultiplayer); break;
	case WT_SINGLEPLAYER: w = spawn(VSinglePlayer); break;
	case WT_SEARCHINGFORLIVEGAMES: w = spawn(VSearchingForLiveGames); break;
	case WT_GETLEGACYDATA: w = spawn(VGetLegacyData); break;
	case WT_ADDONASSOCIATION: w = spawn(VAddonAssociation); break;
	case WT_STEAMGROUPSERVERS: w = spawn(VSteamGroupsServers); break;
	default: w = spawn(CBaseModFrame); break;
	}
	m_WindowStack[wt] = w;
	string res = "";
	switch (wt) {
	case WT_MAINMENU: res = "MainMenu"; break;
	case WT_INGAMEMAINMENU: res = "InGameMainMenu"; break;
	case WT_OPTIONS: res = "Options"; break;
	case WT_AUDIO: res = "Audio"; break;
	case WT_VIDEO: res = "Video"; break;
	case WT_AUDIOVIDEO: res = "AudioVideo"; break;
	case WT_KEYBOARDMOUSE: res = "KeyboardMouse"; break;
	case WT_GENERICCONFIRMATION: res = "GenericConfirmation"; break;
	case WT_GENERICWAITSCREEN: res = "GenericWaitScreen"; break;
	case WT_LOADINGPROGRESS: res = "LoadingProgress"; break;
	case WT_ATTRACTSCREEN: res = "AttractScreen"; break;
	case WT_GAMELOBBY: res = "GameLobby"; break;
	case WT_GAMEOPTIONS: res = "GameOptions"; break;
	case WT_GAMESETTINGS: res = "GameSettings"; break;
	case WT_MULTIPLAYER: res = "Multiplayer"; break;
	case WT_VOTEOPTIONS: res = "VoteOptions"; break;
	case WT_INGAMEDIFFICULTYSELECT: res = "IngameDifficultySelect"; break;
	case WT_INGAMECHAPTERSELECT: res = "IngameScenarioSelect"; break;
	case WT_FOUNDPUBLICGAMES: res = "FoundGames"; break;
	case WT_SEARCHINGFORLIVEGAMES: res = "SearchingForLiveGames"; break;
	case WT_SIGNINDIALOG: res = "SignInDialog"; break;
	case WT_ACHIEVEMENTS: res = "Achievements"; break;
	case WT_CONTROLLER: res = "ControllerOptions"; break;
	case WT_CONTROLLER_STICKS: res = "ControllerOptionsSticks"; break;
	case WT_CONTROLLER_BUTTONS: res = "ControllerOptionsButtons"; break;
	default: res = ""; break;
	}
	BaseMod_LoadControlSettings(w, res);
	w.OnOpen();
	return w;
}

CBaseModFrame
CBaseModPanel::GetWindow(WINDOW_TYPE wt)
{
	return m_WindowStack[wt];
}

void
CBaseModPanel::CloseAllWindows(int policy)
{
	int i;
	for (i = 0; i < WT_WINDOW_COUNT; i++) {
		if (m_WindowStack[i]) {
			m_WindowStack[i].Hide();
		}
	}
}

void
CBaseModPanel::RunFrame(void)
{
}

CBaseModPanel
CBaseModPanel_GetSingleton(void)
{
	return g_BaseModPanel;
}

CBaseModPanel
CBaseModPanel_GetSingletonPtr(void)
{
	return g_BaseModPanel;
}
