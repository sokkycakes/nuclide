// Batch port of remaining major BaseMod windows (from Source V*.h)

class VAchievements : CBaseModFrame { void VAchievements(void); };
class VGameLobby : CBaseModFrame { void VGameLobby(void); };
class VGameOptions : CBaseModFrame { void VGameOptions(void); };
class VGameSettings : CBaseModFrame { void VGameSettings(void); };
class VFoundPublicGames : CBaseModFrame { void VFoundPublicGames(void); };
class VAllGameSearchResults : CBaseModFrame { void VAllGameSearchResults(void); };
class VSignInDialog : CBaseModFrame { void VSignInDialog(void); };
class VAttractScreen : CBaseModFrame { void VAttractScreen(void); };
class VPasswordEntry : CBaseModFrame { void VPasswordEntry(void); };
class VAddons : CBaseModFrame { void VAddons(void); };
class VCustomCampaigns : CBaseModFrame { void VCustomCampaigns(void); };
class VDownloads : CBaseModFrame { void VDownloads(void); };
class VDownloadCampaign : CBaseModFrame { void VDownloadCampaign(void); };
class VJukebox : CBaseModFrame { void VJukebox(void); };
class VLeaderboard : CBaseModFrame { void VLeaderboard(void); };
class VControllerOptions : CBaseModFrame { void VControllerOptions(void); };
class VControllerOptionsSticks : CBaseModFrame { void VControllerOptionsSticks(void); };
class VControllerOptionsButtons : CBaseModFrame { void VControllerOptionsButtons(void); };
class VCloud : CBaseModFrame { void VCloud(void); };
class VSteamCloudConfirmation : CBaseModFrame { void VSteamCloudConfirmation(void); };
class VVoteOptions : CBaseModFrame { void VVoteOptions(void); };
class VInGameDifficultySelect : CBaseModFrame { void VInGameDifficultySelect(void); };
class VInGameChapterSelect : CBaseModFrame { void VInGameChapterSelect(void); };
class VInGameKickPlayerList : CBaseModFrame { void VInGameKickPlayerList(void); };
class VMultiplayer : CBaseModFrame { void VMultiplayer(void); };
class VSinglePlayer : CBaseModFrame { void VSinglePlayer(void); };
class VSearchingForLiveGames : CBaseModFrame { void VSearchingForLiveGames(void); };
class VFoundGroupGames : CBaseModFrame { void VFoundGroupGames(void); };
class VGetLegacyData : CBaseModFrame { void VGetLegacyData(void); };
class VAddonAssociation : CBaseModFrame { void VAddonAssociation(void); };
class VSteamGroupsServers : CBaseModFrame { void VSteamGroupsServers(void); };

void VAchievements::VAchievements(void) { m_WindowType = WT_ACHIEVEMENTS; }
void VGameLobby::VGameLobby(void) { m_WindowType = WT_GAMELOBBY; }
void VGameOptions::VGameOptions(void) { m_WindowType = WT_GAMEOPTIONS; }
void VGameSettings::VGameSettings(void) { m_WindowType = WT_GAMESETTINGS; }
void VFoundPublicGames::VFoundPublicGames(void) { m_WindowType = WT_FOUNDPUBLICGAMES; }
void VAllGameSearchResults::VAllGameSearchResults(void) { m_WindowType = WT_ALLGAMESEARCHRESULTS; }
void VSignInDialog::VSignInDialog(void) { m_WindowType = WT_SIGNINDIALOG; }
void VAttractScreen::VAttractScreen(void) { m_WindowType = WT_ATTRACTSCREEN; }
void VPasswordEntry::VPasswordEntry(void) { m_WindowType = WT_PASSWORDENTRY; }
void VAddons::VAddons(void) { m_WindowType = WT_ADDONS; }
void VCustomCampaigns::VCustomCampaigns(void) { m_WindowType = WT_CUSTOMCAMPAIGNS; }
void VDownloads::VDownloads(void) { m_WindowType = WT_DOWNLOADS; }
void VDownloadCampaign::VDownloadCampaign(void) { m_WindowType = WT_DOWNLOADCAMPAIGN; }
void VJukebox::VJukebox(void) { m_WindowType = WT_JUKEBOX; }
void VLeaderboard::VLeaderboard(void) { m_WindowType = WT_LEADERBOARD; }
void VControllerOptions::VControllerOptions(void) { m_WindowType = WT_CONTROLLER; }
void VControllerOptionsSticks::VControllerOptionsSticks(void) { m_WindowType = WT_CONTROLLER_STICKS; }
void VControllerOptionsButtons::VControllerOptionsButtons(void) { m_WindowType = WT_CONTROLLER_BUTTONS; }
void VCloud::VCloud(void) { m_WindowType = WT_CLOUD; }
void VSteamCloudConfirmation::VSteamCloudConfirmation(void) { m_WindowType = WT_STEAMCLOUDCONFIRM; }
void VVoteOptions::VVoteOptions(void) { m_WindowType = WT_VOTEOPTIONS; }
void VInGameDifficultySelect::VInGameDifficultySelect(void) { m_WindowType = WT_INGAMEDIFFICULTYSELECT; }
void VInGameChapterSelect::VInGameChapterSelect(void) { m_WindowType = WT_INGAMECHAPTERSELECT; }
void VInGameKickPlayerList::VInGameKickPlayerList(void) { m_WindowType = WT_INGAMEKICKPLAYERLIST; }
void VMultiplayer::VMultiplayer(void) { m_WindowType = WT_MULTIPLAYER; }
void VSinglePlayer::VSinglePlayer(void) { m_WindowType = WT_SINGLEPLAYER; }
void VSearchingForLiveGames::VSearchingForLiveGames(void) { m_WindowType = WT_SEARCHINGFORLIVEGAMES; }
void VFoundGroupGames::VFoundGroupGames(void) { m_WindowType = WT_FOUNDPUBLICGAMES; }
void VGetLegacyData::VGetLegacyData(void) { m_WindowType = WT_GETLEGACYDATA; }
void VAddonAssociation::VAddonAssociation(void) { m_WindowType = WT_ADDONASSOCIATION; }
void VSteamGroupsServers::VSteamGroupsServers(void) { m_WindowType = WT_STEAMGROUPSERVERS; }
