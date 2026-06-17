/**
 * View rendering — foundation UX + optional L4D2 manifest overlay.
 */

const PanelRenderer = {
  hideAllViews() {
    document.querySelectorAll('.panel.view, .overlay').forEach(el => el.classList.add('hidden'));
    document.querySelectorAll('.flyout').forEach(el => el.classList.remove('manifest-overlay-mode'));
  },

  showView(wt) {
    const meta = WINDOW_META[wt];
    if (!meta) return;
    document.getElementById(meta.viewId)?.classList.remove('hidden');
  },

  render(panel, event) {
    this.hideAllViews();

    for (let p = 5; p >= 2; p--) {
      const wt = panel.activeWindow[p];
      if (wt && wt !== WINDOW_TYPE.WT_NONE) {
        this.showView(wt);
      }
    }

    if (panel.inGame && panel.getActiveWindowType() === WINDOW_TYPE.WT_NONE) {
      document.getElementById('hud-stub')?.classList.remove('hidden');
    } else {
      document.getElementById('hud-stub')?.classList.add('hidden');
    }

    if (panel.flyoutOpen) {
      const activeView = document.querySelector('.panel.view:not(.hidden)');
      activeView?.querySelector(`[data-flyout="${panel.flyoutOpen}"]`)?.classList.remove('hidden');
    }

    if (event?.type === 'open' && event.wt === WINDOW_TYPE.WT_GENERICCONFIRMATION) {
      document.getElementById('ConfirmTitle').textContent = event.params.title || 'Confirm';
      document.getElementById('ConfirmMessage').textContent = event.params.message || '';
    }

    if (panel.session) {
      this.renderLobby(panel.session);
      this.syncSettingsToUI(panel.session.settings);
    }

    this.updateFooter(panel);
    this.updateDebug(panel, event);

    const active = panel.getActiveWindowType();
    ManifestHints.onViewShown(active, panel.flyoutOpen);
  },

  syncSettingsToUI(settings) {
    document.querySelectorAll('[data-setting]').forEach(el => {
      const key = el.dataset.setting;
      const val = settings[key];
      if (val !== undefined && el.tagName === 'SELECT') {
        el.value = val;
      }
    });
  },

  collectSettingsFromUI() {
    const settings = {
      'system/network': 'LIVE',
      'system/access': 'friends',
      'game/mode': 'coop',
      'game/difficulty': 'normal',
      'game/mission': 'c1m1_hotel',
      'game/campaign': 'c1',
    };
    document.querySelectorAll('#view-gamesettings [data-setting]').forEach(el => {
      settings[el.dataset.setting] = el.value;
    });
    return settings;
  },

  renderLobby(session) {
    const list = document.getElementById('GplPlayers');
    if (!list) return;
    list.innerHTML = '';
    session.players.forEach((p, i) => {
      const slot = document.createElement('div');
      slot.className = 'player-slot' + (i === 0 ? ' focused' : '');
      slot.id = `PlayerItem${i}`;
      slot.innerHTML = `
        <div class="slot-name">DrpPlayer — ${p.name}</div>
        <div class="slot-meta">voice: ${p.empty ? '—' : p.voice}</div>
      `;
      slot.addEventListener('click', () => {
        list.querySelectorAll('.player-slot').forEach(s => s.classList.remove('focused'));
        slot.classList.add('focused');
      });
      list.appendChild(slot);
    });

    const mission = session.settings['game/mission'] || 'c1m1_hotel';
    const diff = session.settings['game/difficulty'] || 'normal';
    const l0 = document.getElementById('LblSummaryLine0');
    const l1 = document.getElementById('LblSummaryLine1');
    const l2 = document.getElementById('LblSummaryLine2');
    if (l0) l0.textContent = `Dead Center`;
    if (l1) l1.textContent = mission;
    if (l2) l2.textContent = diff;
  },

  updateFooter(panel) {
    const wt = panel.getActiveWindowType();
    const footerA = document.getElementById('footer-a');
    const footerB = document.getElementById('footer-b');
    const footerX = document.getElementById('footer-x');
    const footerY = document.getElementById('footer-y');

    footerX?.classList.add('hidden');
    footerY?.classList.add('hidden');

    switch (wt) {
      case WINDOW_TYPE.WT_GAMELOBBY:
        footerA.textContent = 'Select';
        footerB.textContent = 'Back';
        footerX.textContent = 'Kick';
        footerX?.classList.remove('hidden');
        break;
      case WINDOW_TYPE.WT_GENERICCONFIRMATION:
        footerA.textContent = 'OK';
        footerB.textContent = 'Cancel';
        break;
      default:
        footerA.textContent = 'Select';
        footerB.textContent = 'Back';
    }
  },

  updateDebug(panel, event) {
    const stateEl = document.getElementById('debug-state');
    const stackEl = document.getElementById('debug-stack');
    const logEl = document.getElementById('debug-log');

    if (stateEl) stateEl.textContent = panel.getActiveWindowType();

    if (stackEl) {
      stackEl.innerHTML =
        `<strong>Stack:</strong><br>${panel.stack.length ? panel.stack.map(s => s.wt).join(' → ') : '(empty)'}` +
        `<br><strong>inGame:</strong> ${panel.inGame}` +
        `<br><strong>flyout:</strong> ${panel.flyoutOpen || 'none'}`;
    }

    if (event && logEl) {
      const entry = document.createElement('div');
      entry.className = 'entry';
      entry.textContent = `[${new Date().toLocaleTimeString()}] ${JSON.stringify(event)}`;
      logEl.prepend(entry);
      while (logEl.children.length > 40) logEl.lastChild.remove();
    }
  },

  runLoadingSimulation(panel, onProgress) {
    const fill = document.getElementById('ProgressFill');
    const text = document.getElementById('LoadingText');
    let p = 0;
    if (text) text.textContent = 'Loading map...';

    const tick = () => {
      p += 4 + Math.random() * 8;
      if (p >= 100) {
        if (fill) fill.style.width = '100%';
        setTimeout(() => {
          panel.finishLoading();
          onProgress({ type: 'inGame' });
        }, 400);
        return;
      }
      if (fill) fill.style.width = p + '%';
      if (text) text.textContent = `Loading map... ${Math.floor(p)}%`;
      setTimeout(tick, 120);
    };
    tick();
  },

  appendChat(text) {
    const log = document.getElementById('ChatLog');
    if (!log) return;
    const msg = document.createElement('div');
    msg.className = 'msg';
    msg.textContent = text;
    log.appendChild(msg);
    log.scrollTop = log.scrollHeight;
  },
};

window.PanelRenderer = PanelRenderer;
