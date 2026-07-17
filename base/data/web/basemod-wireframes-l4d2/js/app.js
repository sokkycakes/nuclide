/**
 * Command routing — L4D2 MainMenu::OnCommand behavior from gameui.dll decomp.
 */

(function init() {
  const panel = new BaseModPanel();
  window.__baseModPanel = panel;

  /** Carousel soft-lock commands → flyout panel names (MainMenu::OnCommand @ 0x10068220) */
  const SOFT_LOCK_FLYOUT = {
    VersusSoftLock: 'FlmVersusFlyout',
    SurvivalCheck: 'FlmSurvivalFlyout',
    ScavengeCheck: 'FlmScavengeFlyout',
  };

  /** Prefix → match KeyValues Options.action (decomp) */
  const MATCH_PREFIX = {
    QuickMatch_: 'quickmatch',
    QuickMatchServer_: 'quickmatch',
    CustomMatch_: 'custommatch',
    FriendsMatch_: 'friendsmatch',
    GroupServer_: 'groupserver',
  };

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

  function stripPrefix(cmd, prefix) {
    return cmd.startsWith(prefix) ? cmd.slice(prefix.length) : null;
  }

  function flyoutExists(name) {
    const view = document.querySelector('.panel.view:not(.hidden)') || document.getElementById('view-mainmenu');
    return !!view?.querySelector(`[data-flyout="${name}"]`);
  }

  function openFlyout(name) {
    panel.flyoutOpen = name;
    refresh({ type: 'flyout', open: name });
  }

  function closeFlyout() {
    panel.flyoutOpen = null;
    refresh({ type: 'flyout', open: null });
  }

  function setGameModeHighlight(cmd) {
    const block = document.getElementById('BtnGameModes');
    if (!block) return;
    const modeCmds = new Set([
      'FlmCampaignFlyout', 'FlmRealismFlyout', 'VersusSoftLock', 'SurvivalCheck', 'ScavengeCheck', 'SoloPlay',
    ]);
    if (!modeCmds.has(cmd) && !cmd.startsWith('Flm') && cmd !== 'SoloPlay') return;
    block.querySelectorAll('.hybrid-btn').forEach(btn => {
      btn.classList.toggle('active', btn.dataset.cmd === cmd);
    });
  }

  function matchSettingsKv(action, mode, extra = '') {
    if (action === 'quickmatch') {
      return `System { network LIVE } Game { mode ${mode} } Options { action quickmatch ${extra} }`;
    }
    if (action === 'custommatch') {
      return `System { network LIVE } Game { mode ${mode} } Options { action custommatch }`;
    }
    if (action === 'groupserver') {
      return (mode ? `Game { mode ${mode} } ` : 'Game { } ') + 'Options { action groupserver }';
    }
    return `Game { mode ${mode} }`;
  }

  function startQuickMatch(mode, server) {
    const serverOpt = server ? ` server ${server}` : '';
    const kv = matchSettingsKv('quickmatch', mode, serverOpt.trim());
    panel.matchDraft = { action: 'quickmatch', mode, server: server || 'any' };
    closeFlyout();
    panel._notify({ type: 'matchmaking', settings: kv, draft: panel.matchDraft });
    panel.openGenericPopup(
      'Quick Match',
      `${kv}\n\nMatchFramework would search and join a lobby.`,
    );
  }

  function openGameSettingsForMatch(action, mode) {
    panel.matchDraft = { action, mode };
    closeFlyout();
    if (mode) {
      panel._pendingMode = mode;
    }
    panel.openWindow(WINDOW_TYPE.WT_GAMESETTINGS, WINDOW_TYPE.WT_MAINMENU, true);
    panel._notify({
      type: 'matchDraft',
      settings: matchSettingsKv(action, mode),
      draft: panel.matchDraft,
    });
  }

  function handleMatchCommand(cmd) {
    for (const [prefix, action] of Object.entries(MATCH_PREFIX)) {
      const suffix = stripPrefix(cmd, prefix);
      if (suffix === null) continue;

      if (prefix === 'QuickMatch_') {
        panel.matchDraft = { action: 'quickmatch', mode: suffix };
        if (flyoutExists('FlmQuickMatchFlyout')) {
          openFlyout('FlmQuickMatchFlyout');
        } else {
          startQuickMatch(suffix, null);
        }
        return true;
      }

      if (prefix === 'QuickMatchServer_') {
        const server = suffix;
        const mode = panel.matchDraft?.mode || 'coop';
        startQuickMatch(mode, server === 'any' ? null : server);
        return true;
      }

      if (prefix === 'CustomMatch_') {
        openGameSettingsForMatch('custommatch', suffix);
        return true;
      }

      if (prefix === 'FriendsMatch_') {
        panel.matchDraft = { action: 'friendsmatch', mode: suffix };
        closeFlyout();
        panel._notify({
          type: 'openWindow',
          wt: 'WT_ALLGAMESEARCHRESULTS',
          settings: `Game { mode ${suffix} }`,
        });
        panel.openGenericPopup(
          'Friends Games',
          `Browse friends-only lobbies for mode "${suffix}".\n(WT 0x1d — AllGameSearchResults)`,
        );
        return true;
      }

      if (prefix === 'GroupServer_') {
        panel.matchDraft = { action: 'groupserver', mode: suffix };
        closeFlyout();
        setGameModeHighlight('VersusSoftLock');
        panel._notify({
          type: 'openWindow',
          wt: 'WT_STEAMGROUPSERVERS',
          settings: matchSettingsKv('groupserver', suffix),
        });
        panel.openGenericPopup(
          'Steam Group Server',
          `${matchSettingsKv('groupserver', suffix)}\n\nOpens group server browser (WT 0x23).`,
        );
        return true;
      }
    }
    return false;
  }

  function handleMainMenuCommand(cmd) {
    if (handleMatchCommand(cmd)) return true;

    if (SOFT_LOCK_FLYOUT[cmd]) {
      setGameModeHighlight(cmd);
      openFlyout(SOFT_LOCK_FLYOUT[cmd]);
      return true;
    }

    if (cmd === 'SoloPlay') {
      closeFlyout();
      setGameModeHighlight(cmd);
      panel.createSession({
        'system/network': 'offline',
        'game/mode': 'coop',
        'game/mission': 'c1m1_hotel',
        'game/difficulty': 'normal',
      });
      panel.openWindow(WINDOW_TYPE.WT_GAMELOBBY, WINDOW_TYPE.WT_MAINMENU);
      return true;
    }

    if (cmd === 'FlmExtrasFlyoutCheck') {
      openFlyout('FlmExtrasFlyout_Simple');
      return true;
    }

    if (cmd === 'PlayChallenge') {
      closeFlyout();
      panel.openGenericPopup('Challenge Mode', 'ChooseChallengeMode / holdout mutation flyout.');
      return true;
    }
    if (cmd === 'DeveloperCommentary') {
      closeFlyout();
      panel._notify({ type: 'matchmaking', settings: 'System { network offline } Game { mode coop } Options { play commentary }' });
      panel.openGenericPopup('Commentary', 'Offline commentary session.');
      return true;
    }
    if (cmd === 'Credits') {
      closeFlyout();
      panel.openGenericPopup('Credits', 'Offline credits roll (System offline, play credits).');
      return true;
    }

    if (cmd.startsWith('Leaderboards_')) {
      const mode = stripPrefix(cmd, 'Leaderboards_');
      closeFlyout();
      panel.openGenericPopup('Leaderboards', `Survival leaderboards for "${mode}" (WT 0x28).`);
      return true;
    }

    if (cmd.startsWith('Flm') && cmd.endsWith('Flyout')) {
      setGameModeHighlight(cmd);
      panel.flyoutOpen = panel.flyoutOpen === cmd ? null : cmd;
      refresh({ type: 'flyout', open: panel.flyoutOpen });
      return true;
    }

    if (cmd === 'StatsAndAchievements') {
      closeFlyout();
      setGameModeHighlight(cmd);
      panel._notify({ type: 'openWindow', wt: 'WT_ACHIEVEMENTS' });
      panel.openGenericPopup('Stats & Achievements', 'Would open WT_ACHIEVEMENTS.');
      return true;
    }

    if (cmd === 'QuitGame') {
      closeFlyout();
      panel.openGenericPopup('Quit Game', 'Are you sure you want to quit?', () => {
        panel._notify({ type: 'quit', text: 'engine->Quit()' });
      });
      return true;
    }

    if (cmd === 'SeeAll') {
      closeFlyout();
      panel._notify({ type: 'openWindow', wt: 'WT_ALLGAMESEARCHRESULTS', settings: 'Game { }' });
      panel.openGenericPopup('Quick Join', 'Would open WT_ALLGAMESEARCHRESULTS (See All).');
      return true;
    }

    const optionsWindows = {
      AudioVideo: 'WT_AUDIOVIDEO',
      Video: 'WT_VIDEO',
      Audio: 'WT_AUDIO',
      KeyboardMouse: 'WT_KEYBOARDMOUSE',
      MultiplayerSettings: 'WT_MULTIPLAYER',
      CloudSettings: 'WT_CLOUD',
    };
    if (optionsWindows[cmd]) {
      closeFlyout();
      panel._notify({ type: 'openWindow', wt: optionsWindows[cmd] });
      panel.openGenericPopup('Options', `Would open ${optionsWindows[cmd]} (${cmd}).`);
      return true;
    }

    return false;
  }

  function handleCommand(cmd, el) {
    logCmd(cmd);

    if (cmd === 'NavigateBack' || cmd === 'Back') {
      panel.navigateBack();
      return;
    }
    if (cmd === 'CloseFlyout') {
      closeFlyout();
      return;
    }
    if (cmd === 'ResetDemo') {
      panel.matchDraft = null;
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

    if (wt === WINDOW_TYPE.WT_MAINMENU || wt === WINDOW_TYPE.WT_NONE) {
      if (handleMainMenuCommand(cmd)) return;
    }

    if (wt === WINDOW_TYPE.WT_GAMESETTINGS) {
      if (cmd === 'Create') {
        const settings = readSettings();
        if (panel.matchDraft?.mode) {
          settings['game/mode'] = panel.matchDraft.mode;
        }
        if (panel.matchDraft?.action === 'custommatch') {
          settings['system/network'] = 'LIVE';
        }
        panel.createSession(settings);
        panel.matchDraft = null;
        panel.openWindow(WINDOW_TYPE.WT_GAMELOBBY, WINDOW_TYPE.WT_GAMESETTINGS);
        PanelRenderer.appendChat('System: Session created.');
        return;
      }
    }

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
        panel.openGenericPopup('Leave Lobby', 'Leave this lobby?', () => {
          panel.session = null;
          panel.matchDraft = null;
          panel.closeAllWindows(1);
          panel.openFrontScreen();
        });
        return;
      }
      if (cmd === 'VoiceToggle') {
        PanelRenderer.appendChat('You: (voice toggled)');
        return;
      }
      if (cmd === 'InviteFriends' || cmd === 'InviteUI_friends') {
        panel.openGenericPopup('Invite', 'Steam invite overlay (InviteUI_friends).');
        return;
      }
    }

    if (wt === WINDOW_TYPE.WT_INGAMEMAINMENU) {
      if (cmd === 'ReturnToGame') {
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
        panel.openGenericPopup('Restart', 'callvote RestartGame?', () => {
          panel._notify({ type: 'vote', text: 'callvote RestartGame' });
        });
        return;
      }
      if (cmd === 'ReturnToLobby') {
        panel.openGenericPopup('Return to Lobby', 'callvote ReturnToLobby?', () => panel.leaveGame());
        return;
      }
      if (cmd === 'GoIdle') {
        panel.closeWindow(WINDOW_TYPE.WT_INGAMEMAINMENU);
        PanelRenderer.appendChat('You went idle.');
        refresh({ type: 'idle' });
        return;
      }
      if (cmd === 'ExitToMainMenu') {
        panel.openGenericPopup('Leave Game', 'Exit to main menu?', () => panel.leaveGame());
        return;
      }
      if (cmd === 'AudioVideo') {
        panel.openGenericPopup('Audio / Video', 'WT_AUDIOVIDEO from pause menu.');
        return;
      }
      if (cmd.startsWith('Flm') && cmd.endsWith('Flyout')) {
        panel.flyoutOpen = panel.flyoutOpen === cmd ? null : cmd;
        refresh({ type: 'flyout', open: panel.flyoutOpen });
        return;
      }
    }

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

    if (cmd === 'VoteChapter' && el?.dataset.value) {
      panel.openGenericPopup('Vote', `callvote ChangeScenario ${el.dataset.value}`, () => {
        panel.navigateBack();
        panel.navigateBack();
      });
      return;
    }
    if (cmd === 'VoteDifficulty' && el?.dataset.value) {
      panel.openGenericPopup('Vote', `callvote ChangeDifficulty ${el.dataset.value}`, () => {
        panel.navigateBack();
        panel.navigateBack();
      });
      return;
    }

    panel._notify({ type: 'unhandled', cmd, wt });
  }

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

  panel.openFrontScreen();
  refresh({ type: 'init' });
})();
