/**
 * View rendering helpers — sync DOM to BaseModPanel state.
 */

const PanelRenderer = {
  hideAllViews() {
    document.querySelectorAll('.panel.view, .overlay').forEach(el => el.classList.add('hidden'));
    document.querySelectorAll('.flyout').forEach(el => el.classList.add('hidden'));
  },

  showView(wt) {
    const meta = WINDOW_META[wt];
    if (!meta) return;
    const el = document.getElementById(meta.viewId);
    if (el) el.classList.remove('hidden');
  },

  render(panel, event) {
    this.hideAllViews();

    // Show active windows by priority (loading + normal + message can coexist visually)
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
      const flyout = document.querySelector(`[data-flyout="${panel.flyoutOpen}"]`);
      flyout?.classList.remove('hidden');
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
  },

  syncSettingsToUI(settings) {
    document.querySelectorAll('[data-setting]').forEach(el => {
      const key = el.dataset.setting;
      const val = settings[key];
      if (val !== undefined && el.tagName === 'SELECT') {
        for (const opt of el.options) {
          if (opt.value === val || opt.text === val) {
            el.value = opt.value;
            break;
          }
        }
      }
    });
  },

  collectSettingsFromUI() {
    const settings = {
      'system/network': 'LIVE',
      'system/access': 'friends',
      'game/mode': 'coop',
      'game/difficulty': 'normal',
      'game/mission': 'asi-jac1-landingbay_01',
      'game/campaign': 'jacob',
    };
    document.querySelectorAll('#view-gamesettings [data-setting]').forEach(el => {
      settings[el.dataset.setting] = el.value;
    });
    return settings;
  },

  renderLobby(session) {
    const list = document.getElementById('PlayersList');
    if (!list) return;
    list.innerHTML = '';
    session.players.forEach((p, i) => {
      const slot = document.createElement('div');
      slot.className = 'player-slot' + (i === 0 ? ' focused' : '');
      slot.dataset.playerId = p.id;
      slot.innerHTML = `
        <div class="slot-name">DrpPlayer / BtnDropButton — ${p.name}</div>
        <div class="slot-meta">LblPlayerVoiceStatus: ${p.empty ? '—' : p.voice} · ${p.character || '—'}</div>
      `;
      slot.addEventListener('click', () => {
        list.querySelectorAll('.player-slot').forEach(s => s.classList.remove('focused'));
        slot.classList.add('focused');
      });
      list.appendChild(slot);
    });

    const mission = session.settings['game/mission'] || 'unknown';
    const diff = session.settings['game/difficulty'] || 'normal';
    const line0 = document.getElementById('LblSummaryLine0');
    const line1 = document.getElementById('LblSummaryLine1');
    const line2 = document.getElementById('LblSummaryLine2');
    if (line0) line0.textContent = `LblSummaryLine0 — Jacob's Rest`;
    if (line1) line1.textContent = `LblSummaryLine1 — ${mission}`;
    if (line2) line2.textContent = `LblSummaryLine2 — ${diff}`;
  },

  updateFooter(panel) {
    const wt = panel.getActiveWindowType();
    const footerA = document.getElementById('footer-a');
    const footerB = document.getElementById('footer-b');
    const footerX = document.getElementById('footer-x');
    const footerY = document.getElementById('footer-y');

    footerX.classList.add('hidden');
    footerY.classList.add('hidden');

    switch (wt) {
      case WINDOW_TYPE.WT_MAINMENU:
        footerA.textContent = 'Select';
        footerB.textContent = 'Back';
        break;
      case WINDOW_TYPE.WT_GAMELOBBY:
        footerA.textContent = 'Select';
        footerB.textContent = 'Back';
        footerX.textContent = 'Kick';
        footerX.classList.remove('hidden');
        break;
      case WINDOW_TYPE.WT_INGAMEMAINMENU:
        footerA.textContent = 'Select';
        footerB.textContent = 'Back';
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

    if (stateEl) {
      stateEl.textContent = panel.getActiveWindowType();
    }

    if (stackEl) {
      stackEl.innerHTML = '<strong>Stack:</strong><br>' +
        (panel.stack.length
          ? panel.stack.map(s => s.wt).join(' → ')
          : '(empty)');
      stackEl.innerHTML += `<br><strong>inGame:</strong> ${panel.inGame}`;
      stackEl.innerHTML += `<br><strong>flyout:</strong> ${panel.flyoutOpen || 'none'}`;
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
        p = 100;
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
