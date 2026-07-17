# BaseMod Wireframe — Source Mapping

Wireframes derived from Alien Swarm SDK (`sourcesdk_reference/AlienSwarm/src/game/client/swarm/gameui/swarm/`).
Layout control IDs come from `FindChildByName` / `LoadControlSettings` references; `.res` files ship inside game VPKs as `Resource/UI/BaseModUI/<PanelName>.res`.

## State machine (`CBaseModPanel`)

| `WINDOW_TYPE` | Panel class | `.res` file | Wireframe view |
|---|---|---|---|
| `WT_MAINMENU` | `MainMenu` | `MainMenu.res` | `#view-mainmenu` |
| `WT_GAMESETTINGS` | `GameSettings` | `GameSettings.res` | `#view-gamesettings` |
| `WT_GAMELOBBY` | `GameLobby` | `GameLobby.res` / `TeamLobby.res` | `#view-gamelobby` |
| `WT_LOADINGPROGRESS` | `LoadingProgress` | `LoadingProgress.res` | `#view-loading` |
| `WT_INGAMEMAINMENU` | `InGameMainMenu` | `InGameMainMenu.res` | `#view-ingame-menu` |
| `WT_VOTEOPTIONS` | `VoteOptions` | `VoteOptions.res` | `#view-vote` |
| `WT_INGAMECHAPTERSELECT` | `InGameChapterSelect` | `InGameChapterSelect.res` | `#view-chapter-select` |
| `WT_INGAMEDIFFICULTYSELECT` | `InGameDifficultySelect` | `InGameDifficultySelect.res` | `#view-difficulty-select` |
| `WT_GENERICCONFIRMATION` | `GenericConfirmation` | `GenericConfirmation.res` | `#view-confirm` (overlay) |
| `WT_OPTIONS` | `Options` | `Options.res` | `#view-options` |
| `WT_AUDIOVIDEO` | `AudioVideo` | `AudioVideo.res` | `#view-audiovideo` |

## Priority stack (`WINDOW_PRIORITY`)

Overlays stack like the engine: `WPRI_NORMAL` screens hide behind `WPRI_MESSAGE` (confirm) and `WPRI_LOADINGPLAQUE`.

## Primary navigation flow

```
OpenFrontScreen → WT_MAINMENU
  BtnCoOp / CreateGame → WT_GAMESETTINGS → CreateSession → WT_GAMELOBBY
  BtnStartGame (lobby) → Start → WT_LOADINGPROGRESS → (game)
  ESC in-game → WT_INGAMEMAINMENU
    BtnCallAVote → WT_VOTEOPTIONS
      ChangeScenario → WT_INGAMECHAPTERSELECT
      ChangeDifficulty → WT_INGAMEDIFFICULTYSELECT
    ExitToMainMenu → WT_GENERICCONFIRMATION → CloseAllWindows → WT_MAINMENU
```

## Key commands (from `OnCommand`)

### MainMenu (`vmainmenu.cpp`)
- `SoloPlay` — offline practice / single mission
- `CreateGame` — opens game settings for host
- `FlmCampaignFlyout`, `FlmOptionsFlyout` — flyout submenus
- `StatsAndAchievements`, `QuitGame`, `Addons`

### GameSettings (`vgamesettings.cpp`)
- `Create` / `BtnStartLobby` — create match session → lobby
- `DrpDifficulty`, `DrpStartingMission`, `DrpGameAccess`, `DrpFriendlyFire`, `DrpOnslaught`

### GameLobby (`vgamelobby.cpp`)
- `StartGame`, `ChangeGameSettings`, `GameAccess_*`, `BtnVoiceButton`
- Player slots: `PlayerItem.res` (`DrpPlayer`, `BtnDropButton`, `LblPlayerVoiceStatus`)

### InGameMainMenu (`vingamemainmenu.cpp`)
- `ReturnToGame`, `ExitToMainMenu`, `ChangeChapter`, `ChangeDifficulty`, `RestartScenario`, `ReturnToLobby`, `BtnCallAVote`

### VoteOptions (`vvoteoptions.cpp`)
- `ChangeScenario`, `ChangeDifficulty`, `RestartScenario`
