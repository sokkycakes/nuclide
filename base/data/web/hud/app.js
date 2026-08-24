/* FTEQW WebCore Canvas HUD ? Implementation Plan
   Reference canvas 1440x1080 (true 4:3). CSQC letterboxes into HUDMins/HUDSize. */

'use strict';

// ============================================================
// Constants & Layout
// ============================================================
var DESIGN_HEIGHT = 1080;
var DESIGN_WIDTH = 1440;

var HUD_LAYOUT = {
  ring:        { anchorX: 'center', anchorY: 'center',  width: 1386, height: 1386, offsetX: 0,   offsetY: 0    },
  matchHeader: { anchorX: 'center', anchorY: 'top',     width: 756,  height: 317,  offsetX: 0,   offsetY: 0    },
  centerStatus:{ anchorX: 'center', anchorY: 'center',  width: 400,  height: 360,  offsetX: 0,   offsetY: 0    },
  crosshair:   { anchorX: 'center', anchorY: 'center',  width: 50,   height: 50,   offsetX: 0,   offsetY: 0    },
  resourcePnl: { anchorX: 'left',   anchorY: 'bottom',  width: 546,  height: 261,  offsetX: 0,   offsetY: -93   },
  telemetry:   { anchorX: 'center', anchorY: 'bottom',  width: 413,  height: 118,  offsetX: 0,   offsetY: -54   }
};

var CLUSTER_COLORS = {
  ring:        'rgba(255,200,100,0.3)',
  matchHeader: 'rgba(100,200,255,0.3)',
  centerStatus:'rgba(200,100,255,0.3)',
  crosshair:   'rgba(255,100,100,0.5)',
  resourcePnl: 'rgba(100,255,100,0.3)',
  telemetry:   'rgba(255,255,100,0.3)'
};

// ============================================================
// HudState
// ============================================================
var HudState = {
  visible: true,
  matchTimeSeconds: 0,
  playerOne:  { name: 'P1', score: 0, teamColor: '#3698e2', gaugeType: 'drive', gaugeValue: 0, gaugeMax: 1000, connected: true },
  playerTwo:  { name: 'P2', score: 0, teamColor: '#e23636', gaugeType: 'drive', gaugeValue: 0, gaugeMax: 1000, connected: true },
  ammoCurrent: 0,
  ammoMax: 0,
  health: 100,
  healthMax: 100,
  healthVisualState: 'normal',
  resource: 50,
  resourceMax: 100,
  resourceCount: 0,
  resourceAtMax: false,
  resourceType: 'drive',
  abilityCharges: 3,
  abilityChargeMax: 3,
  reloadSeconds: 0,
  speed: 0,
  cooldowns: []
};

// ============================================================
// HudSettings
// ============================================================
var HudSettings = {
  hudScale: 1,
  crosshairScale: 1,
  crosshairOpacity: 1,
  // FTE owns the gameplay crosshair via the `crosshair` console cvar.
  showCrosshair: false,
  showDecorativeRing: true,
  showTelemetry: true,
  showCenterStatus: true,
  debug: false
};

// ============================================================
// Canvas Setup
// ============================================================
var canvas = document.getElementById('game-hud');
var ctx = canvas.getContext('2d');
ctx.imageSmoothingEnabled = true;
var viewportW = 0;
var viewportH = 0;
var canvasScale = 1;
var dpr = 1;
var fps = 60;
var frameCount = 0;
var lastFpsTime = 0;

var prevVPW = 0;
var prevVPH = 0;

function layoutCanvas() {
  // Fill the host viewport with CSS sizing (avoid vw/vh ? WebCore often resolves those to 0).
  var aw = document.documentElement.clientWidth || window.innerWidth || 0;
  var ah = document.documentElement.clientHeight || window.innerHeight || 0;
  if (aw <= 0 || ah <= 0) return;
  // no-op if viewport hasn't changed (called every frame via resizeCanvas)
  if (aw === prevVPW && ah === prevVPH) return;
  prevVPW = aw;
  prevVPH = ah;
  canvas.style.width = aw + 'px';
  canvas.style.height = ah + 'px';
  canvas.style.left = '0px';
  canvas.style.top = '0px';
  viewportW = aw;
  viewportH = ah;
  dpr = Math.max(2, window.devicePixelRatio || 1);
  canvas.width = Math.round(aw * dpr);
  canvas.height = Math.round(ah * dpr);
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  canvasScale = viewportH / DESIGN_HEIGHT;
  staticBgDirty = true;
}
var resizeCanvas = layoutCanvas;

// ============================================================
// Anchor Helper
// ============================================================
/* Fill-only tint: multiply light pixels; leave near-black stroke alone. */
var _hpTintCache = {};
function tintHpFill(img, size, br, bg, bb) {
  size = Math.max(1, Math.round(size));
  var key = size + '_' + br + '_' + bg + '_' + bb;
  if (_hpTintCache[key]) return _hpTintCache[key];
  var c = document.createElement('canvas');
  c.width = size;
  c.height = size;
  var x = c.getContext('2d');
  x.drawImage(img, 0, 0, size, size);
  var id = x.getImageData(0, 0, size, size);
  var d = id.data;
  for (var i = 0; i < d.length; i += 4) {
    if (d[i + 3] < 8) continue;
    var lum = (d[i] + d[i + 1] + d[i + 2]) / 3;
    if (lum < 48) continue;
    d[i] = Math.round(d[i] / 255 * br);
    d[i + 1] = Math.round(d[i + 1] / 255 * bg);
    d[i + 2] = Math.round(d[i + 2] / 255 * bb);
  }
  x.putImageData(id, 0, 0);
  _hpTintCache[key] = c;
  return c;
}

/* Godot hp.gd: shake_intensity 10, shake_duration 0.5; red while timer > 80%. */
var HP_SHAKE_INTENSITY = 10;
var HP_SHAKE_DURATION = 0.5;
var hpShakeTimer = 0;
var hpShakeOx = 0;
var hpShakeOy = 0;
var hpShakeFlashRed = false;
var _prevHudHealth = null;
var _lastHpShakeTick = 0;

function startHpShake() {
  hpShakeTimer = HP_SHAKE_DURATION;
}

function updateHpShake(now) {
  if (!_lastHpShakeTick) _lastHpShakeTick = now;
  var dt = Math.min(0.1, (now - _lastHpShakeTick) / 1000);
  _lastHpShakeTick = now;
  if (hpShakeTimer <= 0) {
    hpShakeTimer = 0;
    hpShakeOx = 0;
    hpShakeOy = 0;
    hpShakeFlashRed = false;
    return;
  }
  hpShakeTimer -= dt;
  if (hpShakeTimer <= 0) {
    hpShakeTimer = 0;
    hpShakeOx = 0;
    hpShakeOy = 0;
    hpShakeFlashRed = false;
    return;
  }
  var progress = hpShakeTimer / HP_SHAKE_DURATION;
  var intensity = HP_SHAKE_INTENSITY * progress;
  hpShakeOx = (Math.random() * 2 - 1) * intensity;
  hpShakeOy = (Math.random() * 2 - 1) * intensity;
  hpShakeFlashRed = hpShakeTimer > HP_SHAKE_DURATION * 0.8;
}

function drawHpIcon(img, x, y, size, preferBlue) {
  if (!img || !img.complete || img.naturalWidth <= 0) return false;
  if (hpShakeFlashRed) {
    ctx.drawImage(tintHpFill(img, size, 255, 0, 0), x, y);
  } else if (hpShakeTimer > 0) {
    /* Godot forces white during post-flash shake (suppresses full-HP blue). */
    ctx.drawImage(img, x, y, size, size);
  } else if (preferBlue) {
    ctx.drawImage(tintHpFill(img, size, 77, 153, 255), x, y);
  } else {
    ctx.drawImage(img, x, y, size, size);
  }
  return true;
}

function calcAnchorPos(layout) {
  var scale = canvasScale * HudSettings.hudScale;
  var sw = layout.width * scale;
  var sh = layout.height * scale;
  var ox = layout.offsetX * scale;
  var oy = layout.offsetY * scale;
  var x = 0, y = 0;
  switch (layout.anchorX) {
    case 'left':   x = ox; break;
    case 'center': x = (viewportW - sw) / 2 + ox; break;
    case 'right':  x = viewportW - sw + ox; break;
  }
  switch (layout.anchorY) {
    case 'top':    y = oy; break;
    case 'center': y = (viewportH - sh) / 2 + oy; break;
    case 'bottom': y = viewportH - sh + oy; break;
  }
  return { x: x, y: y, w: sw, h: sh, scale: scale };
}

// ============================================================
// Debug Drawing
// ============================================================
function drawDebugCluster(name, layout) {
  var r = calcAnchorPos(layout);
  ctx.fillStyle = CLUSTER_COLORS[name];
  ctx.fillRect(r.x, r.y, r.w, r.h);
  ctx.strokeStyle = 'rgba(255,255,255,0.6)';
  ctx.lineWidth = 1;
  ctx.strokeRect(r.x, r.y, r.w, r.h);
  var cx = r.x + r.w / 2;
  var cy = r.y + r.h / 2;
  ctx.strokeStyle = 'rgba(255,255,255,0.8)';
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.moveTo(cx - 8, cy); ctx.lineTo(cx + 8, cy);
  ctx.moveTo(cx, cy - 8); ctx.lineTo(cx, cy + 8);
  ctx.stroke();
  ctx.fillStyle = '#fff';
  ctx.font = (12 * canvasScale) + 'px sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  ctx.fillText(name + ' [' + Math.round(r.w) + 'x' + Math.round(r.h) + ']', cx, r.y + 4);
  ctx.font = (9 * canvasScale) + 'px sans-serif';
  ctx.fillStyle = 'rgba(255,255,255,0.7)';
  ctx.textBaseline = 'bottom';
  ctx.fillText(layout.anchorX + '/' + layout.anchorY, cx, r.y + r.h - 2);
}

// ============================================================
// AssetLoader ? DOM <img> preloader with data: URIs (like ql-menu)
// WebCore new Image() with fte:// paths often yields naturalWidth=0.
// Forced image decode via decode() to avoid lazy-decode hitches.
// ============================================================
var AssetLoader = {
  images: {},
  loaded: false,
  manifest: [
    { key: 'hudring' },
    { key: 'star' },
    { key: 'timeIndicator' },
    { key: 'hpFull' },
    { key: 'hpLow' },
    { key: 'hpDead' },
    { key: 'exIndicator' },
    { key: 'abilityPip' },
    { key: 'union' },
    { key: 'circlesExt' },
    { key: 'circlesExt1' },
    { key: 'deployedCode' },
    { key: 'deblur' }
  ],
  load: function (onDone) {
    var self = this;
    var remaining = this.manifest.length;
    var missing = [];
    var preload = document.getElementById('hud-preload');
    if (!preload) {
      preload = document.createElement('div');
      preload.id = 'hud-preload';
      preload.setAttribute('aria-hidden', 'true');
      preload.style.cssText = 'position:absolute;left:-10000px;top:0;width:512px;height:512px;overflow:hidden;opacity:1;pointer-events:none';
      document.body.appendChild(preload);
    }
    this.manifest.forEach(function (entry) {
      var img = document.createElement('img');
      img.alt = '';
      img.style.cssText = 'display:block;max-width:128px;max-height:128px';
      var packed = window.HUD_ASSETS && window.HUD_ASSETS[entry.key];
      img.src = packed || 'assets/' + entry.key + '.png';
      // Force decode before marking as loaded ? avoids decode hitches mid-game
      var decoded = (img.decode && img.decode()) || Promise.resolve();
      decoded.then(function () {
        if (!self.images[entry.key]) {
          self.images[entry.key] = img;
          remaining--;
          if (remaining === 0) { self.loaded = true; if (onDone) onDone(missing); }
        }
      }).catch(function () {
        // decode() failed ? fall back: image still loads, just won't be forced
        if (!self.images[entry.key]) {
          self.images[entry.key] = img;
          remaining--;
          if (remaining === 0) { self.loaded = true; if (onDone) onDone(missing); }
        }
      });
      img.onerror = function () {
        // only count if decode() didn't already handle it
        if (!self.images[entry.key]) {
          missing.push(entry.key);
          remaining--;
          if (remaining === 0) { self.loaded = true; if (onDone) onDone(missing); }
        }
      };
      preload.appendChild(img);
    });
  }
};

// ============================================================
// Static Canvas Cache ? pre-render expensive static layers once.
// Rebuilt on resize. Avoids re-compositing ~7MB ring every frame.
// ============================================================
var staticBgCanvas = null;
var staticBgCtx = null;
var staticBgDirty = true;

function ensureStaticBg() {
  var w = canvas.width;
  var h = canvas.height;
  if (!staticBgCanvas || staticBgCanvas.width !== w || staticBgCanvas.height !== h) {
    staticBgCanvas = document.createElement('canvas');
    staticBgCanvas.width = w;
    staticBgCanvas.height = h;
    staticBgCtx = staticBgCanvas.getContext('2d');
    staticBgCtx.imageSmoothingEnabled = true;
    staticBgDirty = true;
  }
  if (staticBgDirty && AssetLoader.loaded) {
    staticBgDirty = false;
    // clear before redraw ? prevents additive accumulation if rebuild fires
    staticBgCtx.clearRect(0, 0, staticBgCanvas.width, staticBgCanvas.height);
    // match the main canvas transform
    staticBgCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
    // pre-render decorative ring (largest static image)
    var r = calcAnchorPos(HUD_LAYOUT.ring);
    var img = AssetLoader.images.hudring;
    if (img && img.complete && img.naturalWidth > 0) {
      staticBgCtx.globalAlpha = 0.5;
      staticBgCtx.drawImage(img, r.x, r.y, r.w, r.h);
      staticBgCtx.globalAlpha = 1;
    } else {
      var cx = r.x + r.w / 2, cy = r.y + r.h / 2;
      var radius = Math.min(r.w, r.h) / 2;
      staticBgCtx.strokeStyle = 'rgba(255,200,100,0.25)';
      staticBgCtx.lineWidth = 2;
      staticBgCtx.beginPath();
      staticBgCtx.arc(cx, cy, radius, 0, Math.PI * 2);
      staticBgCtx.stroke();
    }
  }
}

// ============================================================
// Renderers
// ============================================================
function drawDecorativeRing(layout) {
  if (!HudSettings.showDecorativeRing) return;
  var r = calcAnchorPos(layout);
  // ring image is pre-rendered onto staticBgCanvas ? only draw dynamic speedometer text here.
  var speedStr = String(Math.min(Math.max(0, Math.floor(HudState.speed)), 999));
  while (speedStr.length < 3) speedStr = '0' + speedStr;
  ctx.globalAlpha = 0.54;
  ctx.fillStyle = '#d9e0e5';
  ctx.strokeStyle = 'rgba(0,0,0,0.5)';
  ctx.lineWidth = Math.max(1, 3 * canvasScale);
  ctx.font = Math.round(32 * canvasScale) + 'px "Iosevka Charon Mono Medium"';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.strokeText(speedStr, viewportW / 2, 928 * canvasScale);
  ctx.fillText(speedStr, viewportW / 2, 928 * canvasScale);
  ctx.globalAlpha = 1;
}

function drawStarPath(cx, cy, outerR) {
  var innerR = outerR * 0.382;
  ctx.beginPath();
  for (var i = 0; i < 10; i++) {
    var ang = -Math.PI / 2 + i * Math.PI / 5;
    var rad = (i % 2 === 0) ? outerR : innerR;
    var x = cx + Math.cos(ang) * rad;
    var y = cy + Math.sin(ang) * rad;
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  }
  ctx.closePath();
}

function drawCrosshair(layout) {
  if (!HudSettings.showCrosshair) return;
  var r = calcAnchorPos(layout);
  var s = HudSettings.crosshairScale;
  var cx = r.x + r.w / 2;
  var cy = r.y + r.h / 2;
  var outerR = (Math.min(r.w, r.h) * s) / 2;
  ctx.save();
  ctx.globalAlpha = HudSettings.crosshairOpacity;
  drawStarPath(cx, cy, outerR);
  ctx.fillStyle = '#f4f4f4';
  ctx.strokeStyle = '#111111';
  ctx.lineJoin = 'round';
  ctx.lineWidth = Math.max(2, 2.5 * canvasScale * s);
  ctx.fill();
  ctx.stroke();
  ctx.restore();
}

function drawMatchHeader(layout) {
  var r = calcAnchorPos(layout);
  var p1 = HudState.playerOne;
  var p2 = HudState.playerTwo;
  var tf = AssetLoader.images.timeIndicator;
  if (tf && tf.complete && tf.naturalWidth > 0) {
    var tiW = 248 * r.scale;
    var tiH = 164 * r.scale;
    ctx.drawImage(tf, r.x + 254 * r.scale, r.y + 17 * r.scale, tiW, tiH);
  }
  var mins = Math.floor(HudState.matchTimeSeconds / 60);
  var secs = HudState.matchTimeSeconds % 60;
  var timerStr = (mins < 10 ? '0' : '') + mins + ':' + (secs < 10 ? '0' : '') + secs;
  var timerCx = r.x + r.w * 0.5;
  var timerCy = r.y + r.h * 0.38;
  ctx.fillStyle = '#fff';
  ctx.font = Math.round(28 * canvasScale) + 'px "Trade Gothic Next LT Pro BdCn"';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(timerStr, timerCx, timerCy);
  var scoreSize = Math.round(75.965 * r.scale);
  ctx.font = scoreSize + 'px "Helvetica Neue 97 Black Condensed"';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#c7c7c7';
  ctx.strokeStyle = 'rgba(0,0,0,0.5)';
  ctx.lineWidth = Math.max(1, 4 * r.scale);
  ctx.textAlign = 'right';
  ctx.strokeText(String(p1.score), r.x + 300 * r.scale, r.y + 115.5 * r.scale);
  ctx.fillText(String(p1.score), r.x + 300 * r.scale, r.y + 115.5 * r.scale);
  ctx.textAlign = 'left';
  ctx.strokeText(String(p2.score), r.x + 461 * r.scale, r.y + 115.38 * r.scale);
  ctx.fillText(String(p2.score), r.x + 461 * r.scale, r.y + 115.38 * r.scale);
  // left nameplate: 159.843x34.817 at (140, 152) within objectiveHud
  var npx1 = r.x + 140 * r.scale;
  var npy1 = r.y + 152 * r.scale;
  var npw1 = 159.843 * r.scale;
  var nph = 34.817 * r.scale;
  var grad1 = ctx.createLinearGradient(npx1, npy1, npx1, npy1 + nph);
  grad1.addColorStop(0, 'rgba(54,152,226,0.95)');
  grad1.addColorStop(1, 'rgba(20,86,143,0.95)');
  ctx.fillStyle = grad1;
  ctx.fillRect(npx1, npy1, npw1, nph);
  ctx.fillStyle = 'rgba(248,130,130,1)';
  ctx.fillRect(npx1, npy1, npw1, nph);
  var nameSize = 14.813 * r.scale;
  ctx.font = nameSize + 'px "Trade Gothic Next LT Pro BdCn"';
  ctx.textBaseline = 'top';
  ctx.fillStyle = '#fff';
  ctx.textAlign = 'left';
  ctx.fillText(p1.name, r.x + 152.66 * r.scale, r.y + 161.5 * r.scale);
  // right nameplate: 160.635x34.817 at (461, 152) within objectiveHud
  var npx2 = r.x + 461 * r.scale;
  var npy2 = r.y + 152 * r.scale;
  var npw2 = 160.635 * r.scale;
  var grad2 = ctx.createLinearGradient(npx2, npy2, npx2, npy2 + nph);
  grad2.addColorStop(0, 'rgba(54,152,226,0.95)');
  grad2.addColorStop(1, 'rgba(20,86,143,0.95)');
  ctx.fillStyle = grad2;
  ctx.fillRect(npx2, npy2, npw2, nph);
  ctx.textAlign = 'right';
  ctx.fillText(p2.name, r.x + (461 + 160.635 - 12.02) * r.scale, r.y + 161.5 * r.scale);
  // mini ex gauges (ability pips) below right nameplate
  var pipImg = AssetLoader.images.abilityPip;
  var mps = 20.574 * r.scale;
  var mpy = r.y + 202.25 * r.scale;
  var mpx = [471.29, 493.45, 514.81];
  for (var i = 0; i < 3; i++) {
    var px = r.x + mpx[i] * r.scale;
    if (pipImg && pipImg.complete && pipImg.naturalWidth > 0) {
      ctx.drawImage(pipImg, px - mps / 2, mpy - mps / 2, mps, mps);
    } else {
      ctx.fillStyle = 'rgba(255,255,255,0.3)';
      ctx.fillRect(px - mps / 2, mpy - mps / 2, mps, mps);
    }
  }
}

function drawCenterStatus(layout) {
  if (!HudSettings.showCenterStatus) return;
  var r = calcAnchorPos(layout);
  var s = canvasScale;
  var state = HudState.healthVisualState;
  var shakeX = hpShakeOx * r.scale;
  var shakeY = hpShakeOy * r.scale;
  if (state === 'dead') {
    var di = AssetLoader.images.hpDead;
    var ds = 50.865 * r.scale;
    var dx = r.x + 174.62 * r.scale + shakeX;
    var dy = r.y + 231.13 * r.scale + shakeY;
    if (!drawHpIcon(di, dx, dy, ds, false)) {
      ctx.fillStyle = '#f00'; ctx.fillRect(dx, dy, ds, ds);
    }
  } else if (state === 'low') {
    var li = AssetLoader.images.hpLow;
    /* Same slot/size as full HP — Figma hpLow placeholder is 36x37 @ (182,240). */
    var ls = 35 * r.scale;
    var lx = r.x + 182 * r.scale + shakeX;
    var ly = r.y + 240 * r.scale + shakeY;
    if (!drawHpIcon(li, lx, ly, ls, false)) {
      ctx.fillStyle = '#ff0'; ctx.fillRect(lx, ly, ls, ls);
    }
  } else {
    var hi = AssetLoader.images.hpFull;
    var hs = 35 * r.scale;
    var hx = r.x + 182 * r.scale + shakeX;
    var hy = r.y + 240 * r.scale + shakeY;
    var preferBlue = Math.round(HudState.health) > 0 && Math.round(HudState.health) >= HudState.healthMax;
    if (!drawHpIcon(hi, hx, hy, hs, preferBlue)) {
      ctx.fillStyle = '#0f0'; ctx.fillRect(hx, hy, hs, hs);
    }
  }
  // primary clip ammo: 04b09 33.3px at (254.5, 228.5)
  var ammoSize = Math.round(33.3 * r.scale);
  ctx.font = ammoSize + 'px "04b09"';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#fff';
  ctx.fillText(Math.round(HudState.ammoCurrent) + '|', r.x + 254.5 * r.scale, r.y + 228.5 * r.scale);
  // reserve ammo: 04b09 16px at (283, 224)
  var resSize = Math.round(16 * r.scale);
  ctx.font = resSize + 'px "04b09"';
  ctx.fillText(Math.round(HudState.ammoMax), r.x + 283 * r.scale, r.y + 224 * r.scale);
  var pipImg = AssetLoader.images.abilityPip;
  var pipS = 17.37 * r.scale;
  var pipCount = Math.min(HudState.abilityCharges, HudState.abilityChargeMax);
  // triangular arrangement per Figma, centers at (149.66,223.51), (144.71,243.05), (163.27,236.24)
  var pipPositions = [
    { x: r.x + 149.66 * r.scale, y: r.y + 223.51 * r.scale },
    { x: r.x + 144.71 * r.scale, y: r.y + 243.05 * r.scale },
    { x: r.x + 163.27 * r.scale, y: r.y + 236.24 * r.scale }
  ];
  for (var i = 0; i < 3; i++) {
    var p = pipPositions[i];
    ctx.save();
    ctx.translate(p.x, p.y);
    ctx.rotate(-Math.PI / 4);
    ctx.globalAlpha = i < pipCount ? 0.7 : 0.2;
    if (pipImg && pipImg.complete && pipImg.naturalWidth > 0) {
      ctx.drawImage(pipImg, -pipS / 2, -pipS / 2, pipS, pipS);
    } else {
      ctx.fillStyle = i < pipCount ? 'rgba(255,255,255,0.7)' : 'rgba(255,255,255,0.2)';
      ctx.fillRect(-pipS / 2, -pipS / 2, pipS, pipS);
    }
    ctx.globalAlpha = 1;
    ctx.restore();
  }
  if (HudState.reloadSeconds > 0) {
    ctx.font = Math.round(20 * r.scale) + 'px "Iosevka Charon Mono Bold"';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillStyle = '#e5e5eb';
    ctx.fillText(HudState.reloadSeconds.toFixed(1), r.x + 267 * r.scale, r.y + 241 * r.scale);
  }
}

function drawResourcePanel(layout) {
  var r = calcAnchorPos(layout);
  var s = canvasScale;
  var res = HudState;
  var exInd = AssetLoader.images.exIndicator;
  if (exInd && exInd.complete && exInd.naturalWidth > 0) {
    ctx.drawImage(exInd, 71 * canvasScale, 954 * canvasScale, 86 * canvasScale, 33 * canvasScale);
  }
  var uni = AssetLoader.images.union;
  if (uni && uni.complete && uni.naturalWidth > 0) {
    var us = canvasScale;
    ctx.drawImage(uni, 63 * us, 921.7 * us, 482 * us, 31.6 * us);
  }
  // draw EX gauge number and MAX text on top
  var countSize = Math.round(96 * canvasScale);
  ctx.font = countSize + 'px "Helvetica Neue 97 Black Condensed Oblique"';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillStyle = '#fff';
  ctx.strokeStyle = 'rgba(0,0,0,0.5)';
  ctx.lineWidth = Math.max(1, 4 * canvasScale);
  ctx.strokeText(String(res.resourceCount), 304 * canvasScale, 945.5 * canvasScale);
  ctx.fillText(String(res.resourceCount), 304 * canvasScale, 945.5 * canvasScale);
  if (res.resourceAtMax) {
    ctx.font = Math.round(36 * canvasScale) + 'px "Helvetica Neue 97 Black Condensed Oblique"';
    ctx.strokeText('MAX', 467 * canvasScale, 917 * canvasScale);
    ctx.fillText('MAX', 467 * canvasScale, 917 * canvasScale);
  }
}

function drawTelemetry(layout) {
  if (!HudSettings.showTelemetry) return;
  var r = calcAnchorPos(layout);
  var s = canvasScale;
  var cdData = HudState.cooldowns;
  var icons = [AssetLoader.images.circlesExt1, AssetLoader.images.deployedCode, AssetLoader.images.deblur];
  var iconKeys = ['circlesExt1', 'deployedCode', 'deblur'];
  var cxPositions = [146, 206, 266];
  var ci = 20 * s;
  for (var i = 0; i < Math.min(cdData.length, 3); i++) {
    var cd = cdData[i];
    var cx = r.x + cxPositions[i] * s;
    var cy = r.y + 39 * s;
    // circular background
    ctx.save();
    ctx.beginPath();
    ctx.arc(cx, cy, ci / 2, 0, Math.PI * 2);
    ctx.closePath();
    ctx.clip();
    var icon = icons[i];
    if (icon && icon.complete && icon.naturalWidth > 0) {
      ctx.globalAlpha = cd.ready ? 1 : 0.5;
      ctx.drawImage(icon, cx - ci / 2, cy - ci / 2, ci, ci);
      ctx.globalAlpha = 1;
    } else {
      ctx.fillStyle = cd.ready ? 'rgba(100,255,100,0.3)' : 'rgba(255,200,100,0.3)';
      ctx.fillRect(cx - ci / 2, cy - ci / 2, ci, ci);
    }
    ctx.restore();
    // circular border
    ctx.strokeStyle = 'rgba(255,255,255,0.2)';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(cx, cy, ci / 2, 0, Math.PI * 2);
    ctx.stroke();
    // countdown text
    if (!cd.ready) {
      ctx.fillStyle = '#e5e5eb';
      ctx.font = Math.round(11 * s) + 'px "Helvetica Neue 97 Black Condensed"';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(cd.value > 0 ? (cd.value < 10 ? cd.value.toFixed(1) : String(Math.round(cd.value))) : '', cx, cy + 2 * s);
    }
  }
}

// ============================================================
// Main Render Loop
// ============================================================
function render() {
  resizeCanvas();
  updateHpShake(performance.now());
  ctx.clearRect(0, 0, viewportW, viewportH);
  if (!HudState.visible) return;

  // Draw pre-rendered static background (ring + other static elements)
  ensureStaticBg();
  if (staticBgCanvas) ctx.drawImage(staticBgCanvas, 0, 0, viewportW, viewportH);

  // Dynamic elements (text, bars, timers) drawn every frame
  drawDecorativeRing(HUD_LAYOUT.ring);
  drawMatchHeader(HUD_LAYOUT.matchHeader);
  drawCenterStatus(HUD_LAYOUT.centerStatus);
  drawCrosshair(HUD_LAYOUT.crosshair);
  drawResourcePanel(HUD_LAYOUT.resourcePnl);
  drawTelemetry(HUD_LAYOUT.telemetry);

  if (HudSettings.debug) {
    drawDebugCluster('ring', HUD_LAYOUT.ring);
    drawDebugCluster('matchHeader', HUD_LAYOUT.matchHeader);
    drawDebugCluster('centerStatus', HUD_LAYOUT.centerStatus);
    drawDebugCluster('crosshair', HUD_LAYOUT.crosshair);
    drawDebugCluster('resourcePnl', HUD_LAYOUT.resourcePnl);
    drawDebugCluster('telemetry', HUD_LAYOUT.telemetry);
    ctx.fillStyle = 'rgba(0,0,0,0.5)';
    ctx.fillRect(0, 0, 240, 80 * canvasScale);
    ctx.fillStyle = '#aaa';
    ctx.font = (10 * canvasScale) + 'px monospace';
    ctx.textAlign = 'left';
    ctx.textBaseline = 'top';
    ctx.fillText('Canvas HUD - Phase 1-8', 4, 4);
    ctx.fillText('Viewport: ' + viewportW + 'x' + viewportH + ' scale:' + canvasScale.toFixed(3), 4, 18 * canvasScale + 4);
    ctx.fillText('Assets: ' + (AssetLoader.loaded ? 'loaded' : 'loading'), 4, 36 * canvasScale + 4);
    ctx.fillText('FPS: ' + fps.toFixed(0), 4, 54 * canvasScale + 4);
  }
}

// ============================================================
// FTE Engine Bridge
// ============================================================
function fteQuery(cmd) {
  if (typeof fte_query !== 'function') return null;
  try { return fte_query(cmd); } catch (e) { return null; }
}

function cvarNum(name, fallback) {
  var raw = fteQuery('cvar:' + name);
  if (raw === '' || raw == null) raw = fteQuery('get_cvar ' + name);
  var n = parseFloat(raw);
  return isNaN(n) ? fallback : n;
}

function queryHud() {
  var raw = fteQuery('gethud');
  if (!raw) {
    raw = fteQuery('getstats');
    if (!raw) return null;
    try {
      var stats = JSON.parse(raw);
      return { health: typeof stats[0] === 'number' ? stats[0] : 100, ammo: typeof stats[3] === 'number' ? stats[3] : 0, ammoCurrent: 0, ammoMax: 0, timer: '00:00', speed: 0, charges: 0, scoreLeft: 0, scoreRight: 0, player1: '', player2: '' };
    } catch (e) { return null; }
  }
  try { return JSON.parse(raw); } catch (e) { return null; }
}

function applyHudData(data) {
  if (!data) return;
  if (typeof data.health === 'number') {
    if (_prevHudHealth != null && data.health < _prevHudHealth) startHpShake();
    HudState.health = data.health;
    _prevHudHealth = data.health;
  }
  if (typeof data.healthMax === 'number') HudState.healthMax = Math.max(1, data.healthMax);
  if (typeof data.ammoCurrent === 'number') HudState.ammoCurrent = Math.max(0, Math.round(data.ammoCurrent));
  if (typeof data.ammoMax === 'number') HudState.ammoMax = Math.max(0, Math.round(data.ammoMax));
  else if (typeof data.ammo === 'number') HudState.ammoMax = Math.max(0, Math.round(data.ammo));
  if (typeof data.charges === 'number') HudState.abilityCharges = Math.max(0, Math.min(HudState.abilityChargeMax, Math.round(data.charges)));
  if (data.timer) {
    var parts = data.timer.split(':');
    HudState.matchTimeSeconds = parseInt(parts[0]) * 60 + parseInt(parts[1]);
  }
  if (typeof data.speed === 'number') HudState.speed = data.speed;
  if (data.scoreLeft != null) HudState.playerOne.score = data.scoreLeft;
  if (data.scoreRight != null) HudState.playerTwo.score = data.scoreRight;
  if (data.exLevel != null) HudState.resourceCount = data.exLevel;
  if (data.reload != null) HudState.reloadSeconds = Math.max(0, Number(data.reload) || 0);
  if (data.player1 != null) HudState.playerOne.name = data.player1;
  if (data.player2 != null) HudState.playerTwo.name = data.player2;
  var hpRound = Math.round(HudState.health);
  if (hpRound <= 0) HudState.healthVisualState = 'dead';
  else if (hpRound === 1) HudState.healthVisualState = 'low';
  else HudState.healthVisualState = 'normal';
}

window.WebCoreHud_Receive = function (data) {
  applyHudData(data);
};

function refreshState() {
  applyHudData(queryHud());

  var drive = cvarNum('webcore_hud_drive', -1);
  var driveMax = Math.max(1, cvarNum('webcore_hud_drive_max', 1000));
  if (drive >= 0) { HudState.resource = drive; HudState.resourceMax = driveMax; HudState.resourceAtMax = drive >= driveMax; }

  var clip = cvarNum('webcore_hud_clip', -1);
  var reserve = cvarNum('webcore_hud_ammo_max', -1);
  if (clip >= 0) HudState.ammoCurrent = Math.round(clip);
  if (reserve >= 0) HudState.ammoMax = Math.round(reserve);

  HudState.reloadSeconds = Math.max(0, cvarNum('webcore_hud_reload', HudState.reloadSeconds));

  HudState.cooldowns = [];
  for (var i = 0; i < 3; i++) {
    var cd = cvarNum('webcore_hud_cooldown_' + i, -1);
    if (cd >= 0) HudState.cooldowns.push({ id: 'cd' + i, value: cd, maximum: 10, ready: cd <= 0, visible: true });
  }

}

// ============================================================
// Init ? wait for fonts + assets (like ql-menu)
// ============================================================
var hudFontReady = false;
if (document.fonts && document.fonts.load) {
  Promise.all([
    document.fonts.load('12px "04b09"'),
    document.fonts.load('12px "Helvetica Neue 97 Black Condensed"'),
    document.fonts.load('12px "Helvetica Neue 97 Black Condensed Oblique"'),
    document.fonts.load('12px "Iosevka Charon Mono Bold"'),
    document.fonts.load('12px "Iosevka Charon Mono Medium"'),
    document.fonts.load('12px "Trade Gothic Next LT Pro BdCn"'),
  ]).then(function () { hudFontReady = true; })
    .catch(function () { hudFontReady = true; });
} else {
  hudFontReady = true;
}

function allReady() {
  return AssetLoader.loaded && hudFontReady;
}

function boot() {
  resizeCanvas();
  refreshState();
  if (!allReady()) { setTimeout(boot, 16); return; }
  render();
}

AssetLoader.load(function (missing) {
  if (missing.length > 0) {
    if (HudSettings.debug) console.warn('Canvas HUD: missing assets:', missing);
  }
  // trigger first render if already booted
  if (hudFontReady) render();
});

window.addEventListener('resize', function () { resizeCanvas(); });

boot();
(function tick(now) {
  frameCount++;
  if (!lastFpsTime) lastFpsTime = now;
  if (now - lastFpsTime >= 1000) {
    fps = frameCount * 1000 / (now - lastFpsTime);
    frameCount = 0;
    lastFpsTime = now;
  }
  refreshState();
  render();
  requestAnimationFrame(tick);
})(performance.now());
