/**
 * Offline L4D2 .res manifests → layout hints on authored HTML (hybrid mode).
 * Default: foundation grid UX. Optional overlay: absolute positions from manifest.
 */

const VIEW_MANIFEST = {
  [WINDOW_TYPE.WT_MAINMENU]: 'mainmenu.res',
  [WINDOW_TYPE.WT_GAMESETTINGS]: 'gamesettings_coopcreate.res',
  [WINDOW_TYPE.WT_GAMELOBBY]: 'gamelobby.res',
  [WINDOW_TYPE.WT_LOADINGPROGRESS]: 'loadingprogress.res',
  [WINDOW_TYPE.WT_INGAMEMAINMENU]: 'ingamemainmenu.res',
  [WINDOW_TYPE.WT_VOTEOPTIONS]: 'voteoptions.res',
  [WINDOW_TYPE.WT_INGAMECHAPTERSELECT]: 'ingamechapterselect.res',
  [WINDOW_TYPE.WT_INGAMEDIFFICULTYSELECT]: 'ingamedifficultyselect.res',
  [WINDOW_TYPE.WT_GENERICCONFIRMATION]: 'genericconfirmation.res',
};

const FLYOUT_MANIFEST = {
  FlmCampaignFlyout: 'campaignflyout.res',
  FlmOptionsFlyout: 'optionsflyout.res',
};

const ManifestHints = {
  index: null,
  overlayEnabled: false,
  validation: [],

  async load() {
    if (this.index) return this.index;
    const resp = await fetch('js/manifests/index.json');
    this.index = await resp.json();
    return this.index;
  },

  getManifest(filename) {
    return this.index?.[filename] || null;
  },

  controlById(manifest, id) {
    if (!manifest) return null;
    return manifest.controls.find(c => c.id === id) || null;
  },

  /** Compare authored data-cmd to .res command for wired controls */
  validateView(viewEl) {
    const file = viewEl?.dataset?.manifest;
    if (!file) return [];
    const manifest = this.getManifest(file);
    if (!manifest) return [];

    const issues = [];
    viewEl.querySelectorAll('[data-cmd][id]').forEach(el => {
      const mc = this.controlById(manifest, el.id);
      if (!mc || !mc.command) return;
      if (mc.command !== el.dataset.cmd) {
        issues.push({ id: el.id, html: el.dataset.cmd, res: mc.command });
      }
    });
    return issues;
  },

  clearOverlay(surface) {
    if (!surface) return;
    surface.classList.remove('manifest-overlay-mode');
    surface.querySelectorAll('.manifest-positioned').forEach(el => {
      el.style.left = '';
      el.style.top = '';
      el.style.width = '';
      el.style.height = '';
      el.classList.remove('manifest-positioned');
    });
    surface.querySelectorAll('.manifest-ghost').forEach(el => el.remove());
  },

  applyOverlay(surface, manifest) {
    if (!surface || !manifest) return;
    const vw = manifest.viewport?.wide || 640;
    const vh = manifest.viewport?.tall || 480;

    surface.classList.add('manifest-overlay-mode');

    for (const c of manifest.controls) {
      if (!c.visible) continue;
      if (c.wide == null && c.tall == null && !c.command) continue;

      let el = surface.querySelector(`#${CSS.escape(c.id)}`);
      if (!el && c.command) {
        el = surface.querySelector(`[data-cmd="${c.command}"]`);
      }

      if (el) {
        el.classList.add('manifest-positioned');
        if (c.xpos != null) el.style.left = `${(c.xpos / vw) * 100}%`;
        if (c.ypos != null) el.style.top = `${(c.ypos / vh) * 100}%`;
        if (c.wide != null) el.style.width = `${(c.wide / vw) * 100}%`;
        if (c.tall != null) el.style.height = `${(c.tall / vh) * 100}%`;
      } else if (c.controlName && c.controlName !== 'Frame' && c.xpos != null) {
        const ghost = document.createElement('div');
        ghost.className = 'manifest-ghost';
        ghost.title = c.command || c.controlName;
        ghost.textContent = c.id;
        ghost.style.left = `${(c.xpos / vw) * 100}%`;
        ghost.style.top = `${(c.ypos / vh) * 100}%`;
        if (c.wide != null) ghost.style.width = `${(c.wide / vw) * 100}%`;
        if (c.tall != null) ghost.style.height = `${(c.tall / vh) * 100}%`;
        surface.appendChild(ghost);
      }
    }
  },

  async onViewShown(wt, flyoutOpen) {
    await this.load();
    document.querySelectorAll('.manifest-surface').forEach(s => this.clearOverlay(s));

    const manifestFile = VIEW_MANIFEST[wt];
    const viewMeta = WINDOW_META[wt];
    if (viewMeta) {
      const section = document.getElementById(viewMeta.viewId);
      const surface = section?.querySelector('.manifest-surface');
      const manifest = manifestFile ? this.getManifest(manifestFile) : null;
      this.validation = section ? this.validateView(section) : [];

      if (this.overlayEnabled && surface && manifest) {
        this.applyOverlay(surface, manifest);
      }

      const flyoutFile = flyoutOpen ? FLYOUT_MANIFEST[flyoutOpen] : null;
      if (this.overlayEnabled && flyoutOpen) {
        const activeView = document.querySelector('.panel.view:not(.hidden)');
        const flyout = activeView?.querySelector(`[data-flyout="${flyoutOpen}"]`);
        const fm = flyoutFile ? this.getManifest(flyoutFile) : null;
        if (flyout && fm) {
          flyout.classList.add('manifest-overlay-mode');
          this.applyOverlay(flyout, fm);
        }
      }
    }

    this.updateDebugPanel(manifestFile, flyoutOpen);
  },

  updateDebugPanel(manifestFile, flyoutOpen) {
    const el = document.getElementById('debug-manifest');
    if (!el) return;
    let html = manifestFile
      ? `<strong>.res:</strong> ${manifestFile}`
      : '<strong>.res:</strong> —';
    if (flyoutOpen) {
      html += `<br><strong>flyout:</strong> ${FLYOUT_MANIFEST[flyoutOpen] || flyoutOpen}`;
    }
    if (this.validation.length) {
      html += `<br><strong>cmd drift:</strong> ${this.validation.length}`;
      for (const v of this.validation.slice(0, 3)) {
        html += `<br><span class="warn">${v.id}: html=${v.html} res=${v.res}</span>`;
      }
    } else {
      html += '<br><span class="ok">commands match manifest</span>';
    }
    el.innerHTML = html;
  },

  initToggle() {
    const cb = document.getElementById('ToggleResOverlay');
    if (!cb) return;
    cb.addEventListener('change', () => {
      this.overlayEnabled = cb.checked;
      document.body.classList.toggle('manifest-overlay-on', cb.checked);
      const panel = window.__baseModPanel;
      if (panel) {
        this.onViewShown(panel.getActiveWindowType(), panel.flyoutOpen);
      }
    });
  },
};

window.ManifestHints = ManifestHints;
window.VIEW_MANIFEST = VIEW_MANIFEST;

document.addEventListener('DOMContentLoaded', () => {
  ManifestHints.load().then(() => ManifestHints.initToggle());
});
