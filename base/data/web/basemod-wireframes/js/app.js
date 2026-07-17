/**
 * Command routing — mirrors OnCommand handlers in BaseMod UI panels.
 */

(function init() {
  const panel = new BaseModPanel();

  function refresh(event) {
    PanelRenderer.render(panel, event);
  }

  panel.onChange(refresh);

  function logCmd(cmd) {
    panel._notify({ type: 'cmd', cmd });
  }

  function readSettings() {
    return PanelRenderer.collectSettingsFromUI();
  }

  /** Route commands like MainMenu::OnCommand / GameLobby::OnCommand */
  function handleCommand(cmd, el) {
    logCmd(cmd);

    // Global
    if (cmd === 'NavigateBack' || cmd === 'Back') {
      panel.navigateBack();
      return;
    }
    if (cmd === 'CloseFlyout') {
      panel.flyoutOpen = null;
      refresh({ type: 'flyout', open: null });
      return;
    }
    if (cmd === 'ResetDemo') {
      panel.leaveGame();
      panel.closeAllWindows(3);
      panel.openFrontScreen();
      document.getElementById('ProgressFill').style.width = '0%';
      document.getElementById('ChatLog').innerHTML = '';
      return;
    }
    if (cmd === 'ConfirmOk') {
      const cb = panel.confirmCallback;
      panel.closeWindow(WINDOW_TYPE.WT_GENERICCONFIRMATION);
      panel.confirmCallback = null;
      cb?.onOk?.();
      refresh({ type: 'confirmOk' });
      return;
    }
    if (cmd === 'ConfirmCancel') {
      const cb = panel.confirmCallback;
      panel.closeWindow(WINDOW_TYPE.WT_GENERICCONFIRMATION);
      panel.confirmCallback = null;
      cb?.onCancel?.();
      refresh({ type: 'confirmCancel' });
      return;
    }

    const wt = panel.getActiveWindowType();

    // Flyout toggles
    if (cmd.startsWith('Flm') && cmd !== 'FlmExtrasFlyoutCheck') {
      panel.flyoutOpen = panel.flyoutOpen === cmd ? null : cmd;
      refresh({ type: 'flyout', open: panel.flyoutOpen });
      return;
    }

    // --- Main menu (vmainmenu.cpp) ---
    if (wt === WINDOW_TYPE.WT_MAINMENU || wt === WINDOW_TYPE.WT_NONE) {
      if (cmd === 'SoloPlay') {
        panel.createSession({
          'system/network': 'offline',
          'game/mode': 'single_mission',
          'game/mission': 'asi-jac1-landingbay_pract',
          'game/difficulty': 'normal',
        });
        panel.openWindow(WINDOW_TYPE.WT_GAMELOBBY, WINDOW_TYPE.WT_MAINMENU);
        return;
      }
      if (cmd === 'CreateGame') {
        panel.openWindow(WINDOW_TYPE.WT_GAMESETTINGS, WINDOW_TYPE.WT_MAINMENU);
        return;
      }
      if (cmd.startsWith('CustomMatch_')) {
        const mode = cmd.replace('CustomMatch_', '');
        panel.openWindow(WINDOW_TYPE.WT_GAMESETTINGS, WINDOW_TYPE.WT_MAINMENU, true, { mode });
        return;
      }
      if (cmd === 'StatsAndAchievements') {
        panel.openGenericPopup('Achievements', 'Achievements screen (WT_ACHIEVEMENTS) not wired in wireframe.');
        return;
      }
      if (cmd === 'Addons') {
        panel.openGenericPopup('Addons', 'Addons list (WT_ADDONS) not wired in wireframe.');
        return;
      }
      if (cmd === 'QuitGame') {
        panel.openGenericPopup('Quit Game', 'Are you sure you want to quit?', () => {
          panel._notify({ type: 'quit', text: 'Would call engine->Quit()' });
        });
        return;
      }
      if (cmd === 'AudioVideo') {
        panel.openWindow(WINDOW_TYPE.WT_AUDIOVIDEO, WINDOW_TYPE.WT_MAINMENU);
        return;
      }
      if (cmd === 'KeyboardMouse' || cmd === 'MultiplayerSettings' || cmd === 'CloudSettings') {
        panel.openGenericPopup('Options', `Would open standalone dialog for: ${cmd}`);
        return;
      }
      if (cmd === 'SeeAll') {
        panel.openGenericPopup('Quick Join', 'Would open WT_ALLGAMESEARCHRESULTS with friend lobbies.');
        return;
      }
    }

    // --- Game settings (vgamesettings.cpp) ---
    if (wt === WINDOW_TYPE.WT_GAMESETTINGS) {
      if (cmd === 'Create' || cmd === 'SelectMission') {
        const settings = readSettings();
        panel.createSession(settings);
        panel.openWindow(WINDOW_TYPE.WT_GAMELOBBY, WINDOW_TYPE.WT_GAMESETTINGS);
        PanelRenderer.appendChat('System: Session created.');
        return;
      }
    }

    // --- Game lobby (vgamelobby.cpp) ---
    if (wt === WINDOW_TYPE.WT_GAMELOBBY) {
      if (cmd === 'StartGame') {
        panel.startGame();
        PanelRenderer.runLoadingSimulation(panel, refresh);
        return;
      }
      if (cmd === 'ChangeGameSettings') {
        panel.openWindow(WINDOW_TYPE.WT_GAMESETTINGS, WINDOW_TYPE.WT_GAMELOBBY);
        return;
      }
      if (cmd === 'LeaveLobby') {
        panel.openGenericPopup('Leave Lobby', 'Leave this lobby and return to main menu?', () => {
          panel.session = null;
          panel.closeAllWindows(1);
          panel.openFrontScreen();
        });
        return;
      }
      if (cmd === 'VoiceToggle') {
        PanelRenderer.appendChat('You: (voice toggled)');
        return;
      }
      if (cmd === 'InviteFriends') {
        panel.openGenericPopup('Invite', 'Would open Steam invite overlay.');
        return;
      }
    }

    // --- In-game pause (vingamemainmenu.cpp) ---
    if (wt === WINDOW_TYPE.WT_INGAMEMAINMENU) {
      if (cmd === 'ReturnToGame' || cmd === 'gameui_hide') {
        panel.closeWindow(WINDOW_TYPE.WT_INGAMEMAINMENU);
        refresh({ type: 'gameui_hide' });
        return;
      }
      if (cmd === 'CallVote') {
        panel.openWindow(WINDOW_TYPE.WT_VOTEOPTIONS, WINDOW_TYPE.WT_INGAMEMAINMENU, false);
        return;
      }
      if (cmd === 'ChangeChapter') {
        panel.openWindow(WINDOW_TYPE.WT_INGAMECHAPTERSELECT, WINDOW_TYPE.WT_INGAMEMAINMENU, false);
        return;
      }
      if (cmd === 'ChangeDifficulty') {
        panel.openWindow(WINDOW_TYPE.WT_INGAMEDIFFICULTYSELECT, WINDOW_TYPE.WT_INGAMEMAINMENU, false);
        return;
      }
      if (cmd === 'RestartScenario') {
        panel.openGenericPopup('Restart', 'callvote RestartGame — restart current scenario?', () => {
          panel._notify({ type: 'vote', text: 'callvote RestartGame' });
        });
        return;
      }
      if (cmd === 'ReturnToLobby') {
        panel.openGenericPopup('Return to Lobby', 'callvote ReturnToLobby?', () => {
          panel.leaveGame();
        });
        return;
      }
      if (cmd === 'GoIdle') {
        panel.closeWindow(WINDOW_TYPE.WT_INGAMEMAINMENU);
        PanelRenderer.appendChat('You went idle (go_away_from_keyboard).');
        refresh({ type: 'idle' });
        return;
      }
      if (cmd === 'ExitToMainMenu') {
        panel.openGenericPopup('Leave Game', 'Exit to main menu? Session will close.', () => {
          panel.leaveGame();
        });
        return;
      }
      if (cmd === 'AudioVideo') {
        panel.openWindow(WINDOW_TYPE.WT_AUDIOVIDEO, WINDOW_TYPE.WT_INGAMEMAINMENU, false);
        return;
      }
    }

    // --- Vote options (vvoteoptions.cpp) ---
    if (wt === WINDOW_TYPE.WT_VOTEOPTIONS) {
      if (cmd === 'ChangeScenario') {
        panel.openWindow(WINDOW_TYPE.WT_INGAMECHAPTERSELECT, WINDOW_TYPE.WT_VOTEOPTIONS, false);
        return;
      }
      if (cmd === 'ChangeDifficulty') {
        panel.openWindow(WINDOW_TYPE.WT_INGAMEDIFFICULTYSELECT, WINDOW_TYPE.WT_VOTEOPTIONS, false);
        return;
      }
      if (cmd === 'RestartScenario') {
        panel.openGenericPopup('Vote', 'callvote RestartGame', () => {
          panel.closeWindow(WINDOW_TYPE.WT_VOTEOPTIONS);
          panel.closeWindow(WINDOW_TYPE.WT_INGAMEMAINMENU);
          refresh({ type: 'voteRestart' });
        });
        return;
      }
    }

    // --- Chapter / difficulty vote picks ---
    if (cmd === 'VoteChapter' && el?.dataset.value) {
      panel.openGenericPopup('Vote Started', `callvote ChangeScenario ${el.dataset.value}`, () => {
        panel.navigateBack();
        panel.navigateBack();
      });
      return;
    }
    if (cmd === 'VoteDifficulty' && el?.dataset.value) {
      panel.openGenericPopup('Vote Started', `callvote ChangeDifficulty ${el.dataset.value}`, () => {
        panel.navigateBack();
        panel.navigateBack();
      });
      return;
    }

    // --- Options sub-nav ---
    if (cmd === 'OpenGameOptions') {
      panel.openGenericPopup('Game Options', 'WT_GAMEOPTIONS');
      return;
    }
    if (cmd === 'OpenAudioVideo') {
      panel.openWindow(WINDOW_TYPE.WT_AUDIOVIDEO, wt);
      return;
    }
    if (cmd === 'OpenController') {
      panel.openGenericPopup('Controller', 'WT_CONTROLLER');
      return;
    }
    if (cmd === 'OpenAudio' || cmd === 'OpenVideo') {
      panel.openGenericPopup(cmd, `Would open WT_${cmd.replace('Open', '').toUpperCase()}`);
      return;
    }

    panel._notify({ type: 'unhandled', cmd, wt });
  }

  // ESC / pause toggle
  function togglePause() {
    if (!panel.inGame) return;
    if (panel.getActiveWindowType() === WINDOW_TYPE.WT_INGAMEMAINMENU) {
      handleCommand('ReturnToGame');
    } else if (panel.activeWindow[4] === WINDOW_TYPE.WT_NONE) {
      panel.openWindow(WINDOW_TYPE.WT_INGAMEMAINMENU, null, false);
    }
  }

  document.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-cmd]');
    if (!btn) return;
    e.preventDefault();
    handleCommand(btn.dataset.cmd, btn);
  });

  document.getElementById('ChatInput')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && e.target.value.trim()) {
      PanelRenderer.appendChat(`You: ${e.target.value.trim()}`);
      e.target.value = '';
    }
  });

  document.getElementById('BtnEsc')?.addEventListener('click', togglePause);
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      e.preventDefault();
      if (panel.flyoutOpen) {
        handleCommand('CloseFlyout');
      } else if (panel.activeWindow[4] !== WINDOW_TYPE.WT_NONE) {
        handleCommand('ConfirmCancel');
      } else {
        togglePause();
        if (panel.getActiveWindowType() !== WINDOW_TYPE.WT_NONE &&
            panel.getActiveWindowType() !== WINDOW_TYPE.WT_INGAMEMAINMENU) {
          panel.navigateBack();
        }
      }
    }
  });

  // Boot: OpenFrontScreen → WT_MAINMENU
  panel.openFrontScreen();
  refresh({ type: 'init' });
})();
