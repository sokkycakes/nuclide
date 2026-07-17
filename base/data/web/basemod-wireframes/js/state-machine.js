/**
 * BaseModPanel state machine — mirrors CBaseModPanel window stack behavior.
 */

const WINDOW_TYPE = {
  WT_NONE: 'WT_NONE',
  WT_MAINMENU: 'WT_MAINMENU',
  WT_GAMESETTINGS: 'WT_GAMESETTINGS',
  WT_GAMELOBBY: 'WT_GAMELOBBY',
  WT_LOADINGPROGRESS: 'WT_LOADINGPROGRESS',
  WT_INGAMEMAINMENU: 'WT_INGAMEMAINMENU',
  WT_VOTEOPTIONS: 'WT_VOTEOPTIONS',
  WT_INGAMECHAPTERSELECT: 'WT_INGAMECHAPTERSELECT',
  WT_INGAMEDIFFICULTYSELECT: 'WT_INGAMEDIFFICULTYSELECT',
  WT_GENERICCONFIRMATION: 'WT_GENERICCONFIRMATION',
  WT_OPTIONS: 'WT_OPTIONS',
  WT_AUDIOVIDEO: 'WT_AUDIOVIDEO',
};

const WINDOW_PRIORITY = {
  WPRI_NONE: 0,
  WPRI_BKGNDSCREEN: 1,
  WPRI_NORMAL: 2,
  WPRI_WAITSCREEN: 3,
  WPRI_MESSAGE: 4,
  WPRI_LOADINGPLAQUE: 5,
  WPRI_TOPMOST: 6,
};

const WINDOW_META = {
  [WINDOW_TYPE.WT_MAINMENU]: { viewId: 'view-mainmenu', priority: WINDOW_PRIORITY.WPRI_NORMAL },
  [WINDOW_TYPE.WT_GAMESETTINGS]: { viewId: 'view-gamesettings', priority: WINDOW_PRIORITY.WPRI_NORMAL },
  [WINDOW_TYPE.WT_GAMELOBBY]: { viewId: 'view-gamelobby', priority: WINDOW_PRIORITY.WPRI_NORMAL },
  [WINDOW_TYPE.WT_LOADINGPROGRESS]: { viewId: 'view-loading', priority: WINDOW_PRIORITY.WPRI_LOADINGPLAQUE },
  [WINDOW_TYPE.WT_INGAMEMAINMENU]: { viewId: 'view-ingame-menu', priority: WINDOW_PRIORITY.WPRI_NORMAL },
  [WINDOW_TYPE.WT_VOTEOPTIONS]: { viewId: 'view-vote', priority: WINDOW_PRIORITY.WPRI_NORMAL },
  [WINDOW_TYPE.WT_INGAMECHAPTERSELECT]: { viewId: 'view-chapter-select', priority: WINDOW_PRIORITY.WPRI_NORMAL },
  [WINDOW_TYPE.WT_INGAMEDIFFICULTYSELECT]: { viewId: 'view-difficulty-select', priority: WINDOW_PRIORITY.WPRI_NORMAL },
  [WINDOW_TYPE.WT_GENERICCONFIRMATION]: { viewId: 'view-confirm', priority: WINDOW_PRIORITY.WPRI_MESSAGE },
  [WINDOW_TYPE.WT_OPTIONS]: { viewId: 'view-options', priority: WINDOW_PRIORITY.WPRI_NORMAL },
  [WINDOW_TYPE.WT_AUDIOVIDEO]: { viewId: 'view-audiovideo', priority: WINDOW_PRIORITY.WPRI_NORMAL },
};

class BaseModPanel {
  constructor() {
    this.stack = [];
    this.activeWindow = {};
    for (let p = 0; p <= WINDOW_PRIORITY.WPRI_TOPMOST; p++) {
      this.activeWindow[p] = WINDOW_TYPE.WT_NONE;
    }
    this.session = null;
    this.inGame = false;
    this.confirmCallback = null;
    this.listeners = [];
    this.flyoutOpen = null;
  }

  onChange(fn) {
    this.listeners.push(fn);
  }

  _notify(msg) {
    for (const fn of this.listeners) fn(msg);
  }

  getActiveWindowType() {
    for (let p = WINDOW_PRIORITY.WPRI_TOPMOST; p >= WINDOW_PRIORITY.WPRI_NORMAL; p--) {
      if (this.activeWindow[p] !== WINDOW_TYPE.WT_NONE) {
        return this.activeWindow[p];
      }
    }
    return WINDOW_TYPE.WT_NONE;
  }

  openWindow(wt, caller = null, hidePrevious = true, params = {}) {
    const meta = WINDOW_META[wt];
    if (!meta) {
      this._notify({ type: 'warn', text: `Unknown window: ${wt}` });
      return null;
    }

    if (hidePrevious && meta.priority === WINDOW_PRIORITY.WPRI_NORMAL) {
      const current = this.getActiveWindowType();
      if (current !== WINDOW_TYPE.WT_NONE && current !== wt && meta.priority === WINDOW_PRIORITY.WPRI_NORMAL) {
        if (WINDOW_META[current]?.priority === WINDOW_PRIORITY.WPRI_NORMAL) {
          this.stack.push({ wt: current, caller: wt, params: {} });
        }
      }
    }

    this.activeWindow[meta.priority] = wt;
    this._notify({ type: 'open', wt, caller, params });
    return wt;
  }

  closeWindow(wt) {
    const meta = WINDOW_META[wt];
    if (meta) {
      this.activeWindow[meta.priority] = WINDOW_TYPE.WT_NONE;
    }
    this._notify({ type: 'close', wt });
  }

  closeAllWindows(policyFlags = 0) {
    const EVEN_MSGS = 1;
    const EVEN_LOADING = 2;

    if (policyFlags & EVEN_MSGS) {
      this.activeWindow[WINDOW_PRIORITY.WPRI_MESSAGE] = WINDOW_TYPE.WT_NONE;
      this.confirmCallback = null;
    }
    if (policyFlags & EVEN_LOADING) {
      this.activeWindow[WINDOW_PRIORITY.WPRI_LOADINGPLAQUE] = WINDOW_TYPE.WT_NONE;
    }

    this.activeWindow[WINDOW_PRIORITY.WPRI_NORMAL] = WINDOW_TYPE.WT_NONE;
    this.stack = [];
    this.flyoutOpen = null;
    this._notify({ type: 'closeAll', policyFlags });
  }

  navigateBack() {
    if (this.activeWindow[WINDOW_PRIORITY.WPRI_MESSAGE] !== WINDOW_TYPE.WT_NONE) {
      this.closeWindow(WINDOW_TYPE.WT_GENERICCONFIRMATION);
      return;
    }

    if (this.flyoutOpen) {
      this.flyoutOpen = null;
      this._notify({ type: 'flyout', open: null });
      return;
    }

    if (this.stack.length > 0) {
      const prev = this.stack.pop();
      this.activeWindow[WINDOW_PRIORITY.WPRI_NORMAL] = WINDOW_TYPE.WT_NONE;
      this.openWindow(prev.wt, null, false, prev.params);
      this._notify({ type: 'navBack', wt: prev.wt });
      return;
    }

    const active = this.getActiveWindowType();
    if (active === WINDOW_TYPE.WT_INGAMEMAINMENU) {
      this.closeWindow(WINDOW_TYPE.WT_INGAMEMAINMENU);
      this._notify({ type: 'gameui_hide' });
      return;
    }

    this.openFrontScreen();
  }

  openFrontScreen() {
    if (this.inGame) {
      this._notify({ type: 'warn', text: 'OpenFrontScreen ignored during active game' });
      return;
    }
    this.closeAllWindows(1);
    this.openWindow(WINDOW_TYPE.WT_MAINMENU, null, false);
  }

  openGenericPopup(title, message, onOk, onCancel = null) {
    this.confirmCallback = { onOk, onCancel };
    this.openWindow(WINDOW_TYPE.WT_GENERICCONFIRMATION, null, false, { title, message });
  }

  createSession(settings) {
    this.session = {
      settings: { ...settings },
      players: [
        { id: 1, name: 'You (Host)', voice: 'idle', character: 'Sarge' },
        { id: 2, name: '[ Empty Slot ]', empty: true },
        { id: 3, name: '[ Empty Slot ]', empty: true },
        { id: 4, name: '[ Empty Slot ]', empty: true },
      ],
      state: 'lobby',
    };
    this._notify({ type: 'session', session: this.session });
  }

  startGame() {
    if (!this.session) return;
    this.session.state = 'loading';
    this.closeAllWindows(1);
    this.openWindow(WINDOW_TYPE.WT_LOADINGPROGRESS, null, false);
    this._notify({ type: 'startGame' });
  }

  finishLoading() {
    this.session.state = 'ingame';
    this.inGame = true;
    this.closeWindow(WINDOW_TYPE.WT_LOADINGPROGRESS);
    this._notify({ type: 'inGame', inGame: true });
  }

  leaveGame() {
    this.inGame = false;
    this.session = null;
    this.closeAllWindows(3);
    this.openFrontScreen();
    this._notify({ type: 'leaveGame' });
  }
}

window.BaseModPanel = BaseModPanel;
window.WINDOW_TYPE = WINDOW_TYPE;
window.WINDOW_META = WINDOW_META;
