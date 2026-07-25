/* Quake Live in-game menu canvas demo
   Layout coords match QL's 640x480 UI virtual screen from ui/ingame*.menu */

(() => {
  const canvas = document.getElementById("c");
  const ctx = canvas.getContext("2d");
  const toastEl = document.getElementById("toast");

  const W = 640;
  const H = 480;
  const FOCUS = "rgb(255, 191, 0)";

  const A = {
    bg: load("assets/backscreen.jpg"),
    logo: load("assets/backscreenlogo.png"),
    cursor: load("assets/3_cursor3.png"),
    btnBack: load("assets/button_back.png"),
    // frame shell
    frametl: load("assets/score/frametl.png"),
    framet: load("assets/score/framet.png"),
    frametr: load("assets/score/frametr.png"),
    framel: load("assets/score/framel.png"),
    framem: load("assets/score/framem.png"),
    framer: load("assets/score/framer.png"),
    framebl: load("assets/score/framebl.png"),
    frameb: load("assets/score/frameb.png"),
    framebr: load("assets/score/framebr.png"),
    // score inset
    scoretl: load("assets/score/scoretl3.png"),
    scoretm: load("assets/score/scoretm3.png"),
    scoretr: load("assets/score/scoretr3.png"),
    scorel: load("assets/score/scorel.png"),
    scorem: load("assets/score/scorem.png"),
    scorer: load("assets/score/scorer.png"),
    scorebl: load("assets/score/scorebl.png"),
    scoreb: load("assets/score/scoreb.png"),
    scorebr: load("assets/score/scorebr.png"),
    // tabs / nav
    btn: load("assets/score/btn.png"),
    btno: load("assets/score/btno.png"),
    arrow: load("assets/score/arrow.png"),
    navbarl: load("assets/score/navbarl.png"),
    navbarm: load("assets/score/navbarm.png"),
    navbarr: load("assets/score/navbarr.png"),
    navleft: load("assets/score/navleft.png"),
    navlefty: load("assets/score/navlefty.png"),
    navright: load("assets/score/navright.png"),
    navrighty: load("assets/score/navrighty.png"),
    navrightb: load("assets/score/navrightb.png"),
    bigred: load("assets/score/bigred.png"),
    // popup box corners
    boxtl: load("assets/menu/boxtl.png"),
    boxtr: load("assets/menu/boxtr.png"),
    boxbl: load("assets/menu/boxbl.png"),
    boxbr: load("assets/menu/boxbr.png"),
    fade: load("assets/menu/fade.png"),
    // warmup / joingame (intro.smenu)
    logo2: load("assets/score/logo2.png"),
    gtbox: load("assets/score/gtbox.png"),
    bgfill: load("assets/score/bgfill2.png"),
    bgfillRed: load("assets/score/bgfill2_red.png"),
    bgfillO1: load("assets/score/bgfill2o1.jpg"),
    bgfillO2: load("assets/score/bgfill2o2.jpg"),
    bgfillO6: load("assets/score/bgfill2o6.jpg"),
    bgfillO7: load("assets/score/bgfill2o7.jpg"),
    adtl: load("assets/score/adtl.png"),
    adtm: load("assets/score/adtm.png"),
    adtr: load("assets/score/adtr.png"),
    adbr: load("assets/score/adbr.png"),
    ad2x1: load("assets/ad2x1.jpg"),
    scoretlA: load("assets/score/scoretl.png"),
    scoretl2: load("assets/score/scoretl2.png"),
    scoretmA: load("assets/score/scoretm.png"),
    scoretr2: load("assets/score/scoretr2.png"),
    specl: load("assets/score/specl.png"),
    specm: load("assets/score/specm.png"),
    specflip: load("assets/score/specflip.png"),
    fight: load("assets/fight.png"),
    warmupShot: load("assets/qzwarmup.jpg"),
    iconCA: load("assets/ca.png"),
  };

  function load(src) {
    const img = new Image();
    img.src = src;
    img.onerror = () => console.warn("missing asset", src);
    return img;
  }

  const TABS = [
    { id: "about", label: "CURRENT MATCH", x: 72 },
    { id: "controls", label: "CONTROLS", x: 167 },
    { id: "options", label: "GAME SETTINGS", x: 262 },
    { id: "vote", label: "CALL VOTE", x: 357 },
  ];

  const PLAYERS = [
    { name: "You", ready: false, team: "spec" },
    { name: "Bob", ready: true, team: "red" },
    { name: "Alice", ready: true, team: "blue" },
    { name: "Kane", ready: false, team: "red" },
    { name: "Nova", ready: true, team: "blue" },
    { name: "Rex", ready: false, team: "spec" },
  ];

  const state = {
    view: "warmup", // "warmup" | "esc"
    open: false, // esc menu open
    tab: "about",
    popup: null, // null | "join" | "leave" | "quitConfirm" | "restartConfirm"
    hover: null,
    mx: 320,
    my: 240,
    teamMode: false, // false = Duel header (matches QL screenshot); toggle in-panel
    status: "Warmup view · Esc menu · 1/2 switch views",
    flash: 0,
    // warmup match director (demo)
    phase: "waiting", // waiting | countdown | fight | live
    countdown: 10,
    phaseT: 0,
    showJoinPanel: true,
    myReady: false,
    myTeam: "spec", // spec | red | blue | free
  };

  const hits = [];

  function toast(msg) {
    state.status = msg;
    toastEl.textContent = msg;
    state.flash = 1;
  }

  const fonts = {
    16: { meta: null, pages: [], ready: false },
    24: { meta: null, pages: [], ready: false },
    48: { meta: null, pages: [], ready: false },
  };

  function loadFont(size, pageCount) {
    const f = fonts[size];
    const meta = (window.QL_FONTS && window.QL_FONTS[size]) || null;
    if (!meta) {
      console.warn("missing embedded font meta", size);
      f.ready = true; // don't block forever
      return;
    }
    f.meta = meta;
    let left = pageCount;
    for (let p = 0; p < pageCount; p++) {
      const img = new Image();
      img.src = `assets/fonts/fontimage_${p}_${size}.png`;
      img.onload = img.onerror = () => {
        left--;
        if (left <= 0) f.ready = true;
      };
      f.pages[p] = img;
    }
  }
  loadFont(16, 1);
  loadFont(24, 2);
  loadFont(48, 6);

  function ready() {
    const imgsOk = Object.values(A).every((img) => img.complete);
    const fontsOk = fonts[16].ready && fonts[24].ready && fonts[48].ready;
    return imgsOk && fontsOk;
  }

  function drawImage(img, x, y, w, h, alpha = 1) {
    if (!img.complete || !img.naturalWidth) return;
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.drawImage(img, x, y, w, h);
    ctx.restore();
  }

  /** 9-slice stretch: corners stay, edges/mid tile-stretch */
  function nineSlice(imgs, x, y, w, h, corner = 40, alpha = 0.9) {
    const [tl, t, tr, l, m, r, bl, b, br] = imgs;
    const cw = corner;
    const midW = Math.max(0, w - cw * 2);
    const midH = Math.max(0, h - cw * 2);
    drawImage(tl, x, y, cw, cw, alpha);
    drawImage(t, x + cw, y, midW, cw, alpha);
    drawImage(tr, x + w - cw, y, cw, cw, alpha);
    drawImage(l, x, y + cw, cw, midH, alpha);
    drawImage(m, x + cw, y + cw, midW, midH, alpha);
    drawImage(r, x + w - cw, y + cw, cw, midH, alpha);
    drawImage(bl, x, y + h - cw, cw, cw, alpha);
    drawImage(b, x + cw, y + h - cw, midW, cw, alpha);
    drawImage(br, x + w - cw, y + h - cw, cw, cw, alpha);
  }

  function scoreInset(x, y, w, h) {
    const tl = 20, side = 10, bot = 10;
    drawImage(A.scoretl, x, y, tl, tl);
    drawImage(A.scoretm, x + tl, y, w - tl * 2, tl);
    drawImage(A.scoretr, x + w - tl, y, tl, tl);
    drawImage(A.scorel, x, y + tl, side, h - tl - bot);
    drawImage(A.scorem, x + side, y + tl, w - side * 2, h - tl - bot);
    drawImage(A.scorer, x + w - side, y + tl, side, h - tl - bot);
    drawImage(A.scorebl, x, y + h - bot, side, bot);
    drawImage(A.scoreb, x + side, y + h - bot, w - side * 2, bot);
    drawImage(A.scorebr, x + w - side, y + h - bot, side, bot);
  }

  /** Map UI `size` (approx px capital height) → Quake font + useScale. */
  function pickFont(size) {
    if (size >= 28) return { font: fonts[48], useScale: size / 34 };
    if (size >= 12) return { font: fonts[24], useScale: size / 18 };
    return { font: fonts[16], useScale: size / 11 };
  }

  /** Q3 textscale → useScale (textscale * glyphScale). */
  function scaleFromTextscale(textscale, fontSize) {
    const f = fonts[fontSize];
    if (!f.meta) return textscale;
    return textscale * f.meta.glyphScale;
  }

  function normalizeGlyphs(str) {
    return String(str)
      .replace(/[●]/g, "*")
      .replace(/[○]/g, "o")
      .replace(/[»]/g, ">")
      .replace(/[«]/g, "<")
      .replace(/[✓]/g, "v")
      .replace(/[·]/g, "-")
      .replace(/[—–]/g, "-")
      .replace(/[…]/g, "...")
      .replace(/[“”]/g, '"')
      .replace(/[‘’]/g, "'");
  }

  function measureQ(str, useScale, font) {
    let w = 0;
    const s = normalizeGlyphs(str);
    for (let i = 0; i < s.length; i++) {
      const g = font.meta.glyphs[s.charCodeAt(i) & 255];
      w += (g ? g.xSkip : 8) * useScale;
    }
    return w;
  }

  /**
   * Quake bitmap text (aero). Matches Q3 Text_Paint metrics.
   * - `scale`: Q3 menu textscale (preferred when known)
   * - `size`: approx capital pixel height (fallback for older calls)
   * - `fontSize`: 16|24|48 when using scale
   * - baseline "q3": y is Q3 paint Y (default when scale set)
   * - baseline "top": y is top of capital A
   * - baseline "middle": y is vertical center of capital A
   */
  function text(str, x, y, opts = {}) {
    const {
      size = 12,
      scale = null,
      fontSize = 24,
      color = "#fff",
      align = "left",
      baseline = scale != null ? "q3" : "alphabetic",
      alpha = 1,
    } = opts;

    let font;
    let useScale;
    if (scale != null) {
      font = fonts[fontSize];
      useScale = scaleFromTextscale(scale, fontSize);
    } else {
      ({ font, useScale } = pickFont(size));
    }

    // Fallback to system font if bitmaps not ready
    if (!font || !font.meta || !font.ready) {
      ctx.save();
      ctx.globalAlpha = alpha;
      ctx.fillStyle = color;
      ctx.font = `${size}px "Segoe UI Condensed","Arial Narrow",sans-serif`;
      ctx.textAlign = align;
      ctx.textBaseline = baseline === "q3" ? "alphabetic" : baseline;
      ctx.fillText(String(str), x, y);
      ctx.restore();
      return;
    }

    const s = normalizeGlyphs(str);
    const gA = font.meta.glyphs[65];
    const capTop = (gA ? gA.top : 18) * useScale;
    const capH = (gA ? gA.h : 18) * useScale;

    // Convert caller's y into Q3 paint Y
    let paintY = y;
    if (baseline === "top") paintY = y + capTop;
    else if (baseline === "middle") paintY = y + capTop - capH / 2;
    else if (baseline === "alphabetic") paintY = y;
    // "q3" → y is already paint Y

    let drawX = x;
    const width = measureQ(s, useScale, font);
    if (align === "center") drawX = x - width / 2;
    else if (align === "right") drawX = x - width;

    // Parse css color → rgba for tinted glyph draw
    ctx.save();
    ctx.globalAlpha = alpha;

    // Draw into a 1-glyph buffer then tint (white atlas → color)
    if (!text._buf) {
      text._buf = document.createElement("canvas");
      text._bctx = text._buf.getContext("2d");
    }
    const b = text._buf;
    const bctx = text._bctx;

    let cx = drawX;
    for (let i = 0; i < s.length; i++) {
      const code = s.charCodeAt(i) & 255;
      const g = font.meta.glyphs[code];
      if (!g || g.iw <= 0 || g.ih <= 0) {
        cx += (g ? g.xSkip : 8) * useScale;
        continue;
      }
      const page = font.pages[g.page] || font.pages[0];
      if (!page || !page.complete || !page.naturalWidth) {
        cx += g.xSkip * useScale;
        continue;
      }
      const pw = page.naturalWidth;
      const ph = page.naturalHeight;
      const sx = g.s * pw;
      const sy = g.t * ph;
      const sw = Math.max(1, (g.s2 - g.s) * pw);
      const sh = Math.max(1, (g.t2 - g.t) * ph);
      const dw = g.iw * useScale;
      const dh = g.ih * useScale;
      const dx = cx;
      const dy = paintY - g.top * useScale;

      b.width = Math.max(1, Math.ceil(dw));
      b.height = Math.max(1, Math.ceil(dh));
      bctx.clearRect(0, 0, b.width, b.height);
      bctx.drawImage(page, sx, sy, sw, sh, 0, 0, b.width, b.height);
      bctx.globalCompositeOperation = "source-in";
      bctx.fillStyle = color;
      bctx.fillRect(0, 0, b.width, b.height);
      bctx.globalCompositeOperation = "source-over";
      ctx.drawImage(b, dx, dy);

      cx += g.xSkip * useScale;
    }
    ctx.restore();
  }

  function hit(id, x, y, w, h, onClick, cursor = true) {
    hits.push({ id, x, y, w, h, onClick, cursor });
    return state.hover === id;
  }

  function pointIn(mx, my, r) {
    return mx >= r.x && mx <= r.x + r.w && my >= r.y && my <= r.y + r.h;
  }

  function drawBackdrop() {
    drawImage(A.bg, 0, 0, W, H);
    // soft fake gameplay vignette so chrome reads
    const g = ctx.createRadialGradient(320, 220, 40, 320, 240, 420);
    g.addColorStop(0, "rgba(20,30,40,0.15)");
    g.addColorStop(1, "rgba(0,0,0,0.55)");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);

    // deco fake HUD bits so it feels "in match"
    text("SPECTATOR", 20, 24, { size: 11, color: "#9aa3b2", alpha: 0.7 });
    text("dm_campgrounds", 20, 40, { size: 10, color: "#6d7788", alpha: 0.7 });
    text("Bob  12", 560, 28, { size: 14, color: "#ff6b5a", align: "right", bold: true });
    text("Alice  9", 560, 48, { size: 14, color: "#6fb6ff", align: "right", bold: true });
  }

  function drawClosedHint() {
    text("Press ESC for GAME MENU", 320, 450, {
      scale: 0.22,
      fontSize: 16,
      align: "center",
      color: "#fff",
      alpha: 0.55 + Math.sin(performance.now() / 500) * 0.15,
      baseline: "q3",
    });
  }

  function drawShell() {
    // dim
    ctx.fillStyle = "rgba(0,0,0,0.25)";
    ctx.fillRect(0, 0, W, H);

    // logo
    drawImage(A.logo, 200, 18, 240, 60);

    // top title strip only (frametl / framet / frametr) — 62,90 516×40
    drawImage(A.frametl, 62, 90, 40, 40, 0.9);
    drawImage(A.framet, 102, 90, 436, 40, 0.9);
    drawImage(A.frametr, 538, 90, 40, 40, 0.9);
    drawImage(A.arrow, 69, 95, 10, 10);
    // ingame.menu: GAME MENU textscale .2, rect 82 104
    text("GAME MENU", 82, 104, { scale: 0.2, fontSize: 16, color: "#ccc", baseline: "q3" });

    // tabs — textscale .18, textalign 1, textalignx 40, textaligny 14
    for (const tab of TABS) {
      const hovered = hit(
        `tab:${tab.id}`,
        tab.x,
        108,
        94,
        25,
        () => {
          state.tab = tab.id;
          state.popup = null;
          toast(`Opened ${tab.label}`);
        }
      );
      const active = state.tab === tab.id;
      drawImage(A.btn, tab.x, 108, 94, 25, 0.25);
      if (active) drawImage(A.btno, tab.x, 108, 94, 25, 1);
      else if (hovered) drawImage(A.btno, tab.x, 108, 94, 25, 0.35);
      // label rects are tab.x+7, 108, 80x20 with center at +40,+14
      text(tab.label, tab.x + 7 + 40, 108 + 14, {
        scale: 0.18,
        fontSize: 16,
        align: "center",
        baseline: "q3",
        color: hovered && !active ? FOCUS : "#fff",
      });
    }
  }

  function drawBottomNav() {
    // navbar strip
    drawImage(A.navbarl, 33, 382, 20, 40, 1);
    drawImage(A.navbarm, 53, 382, 532, 40, 1);
    drawImage(A.navbarr, 585, 382, 20, 40, 1);

    // ad placeholder
    ctx.fillStyle = "rgba(0,0,0,0.75)";
    ctx.fillRect(218, 373, 204, 54);
    ctx.strokeStyle = "rgba(255,255,255,0.12)";
    ctx.strokeRect(220.5, 375.5, 199, 49);
    text("AD 4x1", 320, 400, { scale: 0.2, fontSize: 16, align: "center", color: "#666", baseline: "q3" });

    const leaveHot = hit("leave", 38, 391, 80, 20, () => {
      state.popup = "leave";
      toast("Leave Match popup");
    });
    drawImage(leaveHot ? A.navlefty : A.navleft, 38, 391, 80, 20);
    // ingame.menu / about: LEAVE MATCH textscale .2, rect 62 404
    text("LEAVE MATCH", 62, 404, {
      scale: 0.2,
      fontSize: 16,
      color: leaveHot ? FOCUS : "#fff",
      baseline: "q3",
    });

    const retHot = hit("return", 520, 391, 80, 20, () => {
      state.open = false;
      state.popup = null;
      toast("Returned to match");
    });
    drawImage(retHot ? A.navrighty : A.navright, 520, 391, 80, 20);
    // RETURN TO MATCH textalign 2, rect 574 404
    text("RETURN TO MATCH", 574, 404, {
      scale: 0.2,
      fontSize: 16,
      color: retHot ? FOCUS : "#fff",
      align: "right",
      baseline: "q3",
    });
  }

  function panelFrame(bodyH) {
    // content panel under tabs (ingame_about: mid body + bottom cap, no top)
    // bodyH = mid section height before the 20px bottom cap
    const y = 129;
    const midH = bodyH;
    drawImage(A.framel, 62, y, 40, midH, 0.9);
    drawImage(A.framem, 102, y, 436, midH, 0.9);
    drawImage(A.framer, 538, y, 40, midH, 0.9);
    drawImage(A.framebl, 62, y + midH, 40, 20, 0.9);
    drawImage(A.frameb, 102, y + midH, 436, 20, 0.9);
    drawImage(A.framebr, 538, y + midH, 40, 20, 0.9);
    // score inset (about panel uses ~387×118)
    const insetH = Math.min(118, midH + 10);
    scoreInset(71, y, 387, insetH);
    return y;
  }

  function drawAbout() {
    // ingame_about.menu rect origin y=129; item rects are local
    const y0 = 129;
    panelFrame(107);

    text("ABOUT THIS MATCH", 78, y0 + 12, { scale: 0.18, fontSize: 16, baseline: "q3" });
    text("Campgrounds  -  Clan Arena", 86, y0 + 34, { scale: 0.2, fontSize: 24, baseline: "q3" });
    text("Timelimit 10  -  Roundlimit 8", 95, y0 + 52, {
      scale: 0.2,
      fontSize: 24,
      color: "#999",
      baseline: "q3",
    });
    text("Players 6/16  -  Warmup", 95, y0 + 70, {
      scale: 0.2,
      fontSize: 24,
      color: "#999",
      baseline: "q3",
    });
    text("Server: localdemo  -  Rules: stock", 95, y0 + 88, {
      scale: 0.2,
      fontSize: 24,
      color: "#999",
      baseline: "q3",
    });
    text("Map: dm_campgrounds", 95, y0 + 106, {
      scale: 0.2,
      fontSize: 24,
      color: "#999",
      baseline: "q3",
    });

    if (state.teamMode) {
      const rows = [
        { id: "joinRed", label: "JOIN RED", img: A.navright, by: 6, ty: 20, cmd: "team red" },
        { id: "joinBlue", label: "JOIN BLUE", img: A.navrightb, by: 36, ty: 50, cmd: "team blue" },
        { id: "autoJoin", label: "AUTO JOIN", img: A.navrighty, by: 66, ty: 80, cmd: "team free" },
        { id: "spectate", label: "SPECTATE", img: A.navrighty, by: 96, ty: 110, cmd: "team s" },
      ];
      for (const row of rows) {
        const hx = 485;
        const hy = y0 + row.by;
        const hot = hit(row.id, hx, hy, 80, 20, () => {
          toast(`exec "${row.cmd}"`);
          state.open = false;
          state.popup = null;
        });
        drawImage(row.img, hx, hy, 80, 20);
        // textalign 2 → right edge at rect.x (539), not rect.x+w
        text(row.label, 539, y0 + row.ty, {
          scale: 0.2,
          fontSize: 16,
          align: "right",
          color: hot ? FOCUS : "#fff",
          baseline: "q3",
        });
      }
    } else {
      const hx = 463;
      const hy = y0 + 63;
      const hot = hit("joinMatch", hx, hy, 103, 24, () => {
        toast('exec "team a" - JOIN MATCH');
        state.open = false;
      });
      drawImage(A.bigred, hx, hy, 103, 24);
      // gogogo: textscale .25, rect 549 80, textalign 2 → right edge at 549
      text("JOIN MATCH", 549, y0 + 80, {
        scale: 0.25,
        fontSize: 24,
        align: "right",
        color: hot ? FOCUS : "#fff",
        baseline: "q3",
      });
    }

    const tog = hit("toggleMode", 78, y0 + 108, 140, 14, () => {
      state.teamMode = !state.teamMode;
      toast(state.teamMode ? "Team gametype UI" : "FFA / CA join UI");
    });
    text(state.teamMode ? "[demo] show FFA join" : "[demo] show team join", 78, y0 + 118, {
      scale: 0.16,
      fontSize: 16,
      color: tog ? FOCUS : "#666",
      baseline: "q3",
    });
  }

  function drawControls() {
    const y0 = 129;
    panelFrame(154);
    text("CONTROLS", 78, y0 + 12, { scale: 0.18, fontSize: 16, baseline: "q3" });

    const cats = ["MOVEMENT", "WEAPONS", "LOOK", "MISC"];
    cats.forEach((c, i) => {
      const x = 80 + i * 110;
      const active = i === 0;
      const hot = hit(`ctrlcat:${i}`, x, y0 + 36, 100, 18, () => toast(`Controls: ${c}`));
      if (active) {
        ctx.fillStyle = "rgba(40,40,40,0.85)";
        ctx.fillRect(x, y0 + 36, 100, 18);
      }
      text(c, x + 50, y0 + 48, {
        scale: 0.18,
        fontSize: 16,
        align: "center",
        color: active ? "#ff6644" : hot ? FOCUS : "#999",
        baseline: "q3",
      });
    });

    const binds = [
      ["Forward", "W"],
      ["Back", "S"],
      ["Left", "A"],
      ["Right", "D"],
      ["Jump", "SPACE"],
      ["Crouch", "C"],
    ];
    binds.forEach(([name, key], i) => {
      const rowY = y0 + 70 + i * 16;
      text(name, 95, rowY + 12, { scale: 0.2, fontSize: 16, color: "#ccc", baseline: "q3" });
      const hot = hit(`bind:${i}`, 320, rowY, 160, 14, () => toast(`Rebind ${name}`));
      ctx.fillStyle = hot ? "rgba(255,191,0,0.15)" : "rgba(0,0,0,0.35)";
      ctx.fillRect(320, rowY, 160, 14);
      text(key, 400, rowY + 12, {
        scale: 0.2,
        fontSize: 16,
        align: "center",
        color: hot ? FOCUS : "#fff",
        baseline: "q3",
      });
    });
  }

  function drawOptions() {
    const y0 = 129;
    panelFrame(194);
    text("GAME SETTINGS", 78, y0 + 12, { scale: 0.18, fontSize: 16, baseline: "q3" });

    const opts = [
      { label: "Crosshair", value: "Style 2" },
      { label: "Crosshair Size", value: "####--" },
      { label: "FOV", value: "110" },
      { label: "Mouse Sensitivity", value: "4.2" },
      { label: "Show FPS", value: "On" },
      { label: "Weapon Bar", value: "On" },
      { label: "Blood", value: "On" },
      { label: "Simple Items", value: "Off" },
    ];
    opts.forEach((o, i) => {
      const rowY = y0 + 40 + i * 18;
      const hot = hit(`opt:${i}`, 90, rowY, 420, 16, () => toast(`Toggled ${o.label}`));
      text(o.label, 95, rowY + 12, {
        scale: 0.2,
        fontSize: 16,
        color: hot ? FOCUS : "#ddd",
        baseline: "q3",
      });
      text(o.value, 480, rowY + 12, {
        scale: 0.2,
        fontSize: 16,
        align: "right",
        color: "#aaa",
        baseline: "q3",
      });
    });
  }

  function drawVote() {
    const y0 = 129;
    panelFrame(214);
    // ingame_callvote: CALL VOTE OPTIONS textscale .18, rect 78 12
    text("CALL VOTE OPTIONS", 78, y0 + 12, { scale: 0.18, fontSize: 16, baseline: "q3" });

    text("Map Options", 90, y0 + 40, { scale: 0.18, fontSize: 16, color: "#ccc", baseline: "q3" });
    const votes = [
      { label: "map dm_campgrounds", y: 47 },
      { label: "Restart Map", y: 67 },
      { label: "Next Map", y: 87 },
      { label: "Shuffle Teams", y: 107 },
      { label: "kick Bob", y: 140 },
      { label: "timelimit 15", y: 160 },
      { label: "g_doWarmup 0", y: 180 },
      { label: "Call Vote", y: 200 },
    ];
    votes.forEach((v, i) => {
      const x = i < 4 ? 90 : 320;
      const rowY = y0 + (i < 4 ? v.y : 47 + (i - 4) * 20);
      const hot = hit(`vote:${i}`, x, rowY, 200, 16, () => {
        toast(`callvote ${v.label}`);
        state.open = false;
      });
      ctx.fillStyle = hot ? "rgba(255,191,0,0.18)" : "rgba(0,0,0,0.35)";
      ctx.fillRect(x, rowY, 200, 16);
      text(v.label, x + 8, rowY + 12, {
        scale: 0.2,
        fontSize: 16,
        color: hot ? FOCUS : "#eee",
        baseline: "q3",
      });
    });
  }

  function drawPopupBox(x, y, w, h) {
    // dark fill + fade + 4 corners (128x128 style from ingame_join)
    ctx.fillStyle = "rgba(0,0,0,0.8)";
    ctx.fillRect(x + 4, y + 10, w - 8, h - 20);
    drawImage(A.fade, x + 5, y + 14, w - 10, h - 26, 0.35);
    drawImage(A.boxtl, x, y, 64, 64);
    drawImage(A.boxtr, x + w - 64, y, 64, 64);
    drawImage(A.boxbl, x, y + h - 64, 64, 64);
    drawImage(A.boxbr, x + w - 64, y + h - 64, 64, 64);
  }

  function drawJoinPopup() {
    // ingame_join.menu — textscale .25, textalign 1, textalignx 64, textaligny 18
    const x = 121;
    const y = 78;
    const w = 128;
    const h = 128;
    drawPopupBox(x, y, w, h);

    const items = [
      { label: "Auto TEAM", cy: 20, cmd: "team free" },
      { label: "Team RED", cy: 40, cmd: "team red" },
      { label: "Team BLUE", cy: 60, cmd: "team blue" },
      { label: "Spectate", cy: 80, cmd: "team s" },
    ];
    for (const it of items) {
      const hot = hit(
        `joinpop:${it.label}`,
        x,
        y + it.cy,
        w,
        20,
        () => {
          toast(`exec "cmd ${it.cmd}"`);
          state.popup = null;
          state.open = false;
        }
      );
      text(it.label, x + 64, y + it.cy + 18, {
        scale: 0.25,
        fontSize: 24,
        align: "center",
        color: hot ? FOCUS : "#fff",
        baseline: "q3",
      });
    }
  }

  function drawLeavePopup() {
    // ingame_leave.menu — same textscale .25 / aligny 18 pattern
    const x = 121;
    const y = 238;
    const w = 128;
    const h = 128;
    drawPopupBox(x, y, w, h);

    if (state.popup === "leave") {
      const items = [
        { label: "Return to Game", cy: 30, action: () => { state.open = false; state.popup = null; toast("Returned to game"); } },
        { label: "Restart", cy: 50, action: () => { state.popup = "restartConfirm"; } },
        { label: "Quit", cy: 70, action: () => { state.popup = "quitConfirm"; } },
      ];
      for (const it of items) {
        const hot = hit(`leave:${it.label}`, x, y + it.cy, w, 20, it.action);
        text(it.label, x + 64, y + it.cy + 18, {
          scale: 0.25,
          fontSize: 24,
          align: "center",
          color: hot ? FOCUS : "#fff",
          baseline: "q3",
        });
      }
    } else {
      const isQuit = state.popup === "quitConfirm";
      text("Want to", x + 64, y + 33 + 18, {
        scale: 0.25,
        fontSize: 24,
        align: "center",
        baseline: "q3",
      });
      text(isQuit ? "Quit Game?" : "Restart Map?", x + 64, y + 50 + 18, {
        scale: 0.25,
        fontSize: 24,
        align: "center",
        baseline: "q3",
      });

      const yesHot = hit("confirmYes", x + 18, y + 80, 40, 20, () => {
        toast(isQuit ? "uiScript quit" : 'exec "map_restart"');
        state.open = false;
        state.popup = null;
      });
      const noHot = hit("confirmNo", x + 70, y + 80, 40, 20, () => {
        state.popup = "leave";
      });

      drawImage(A.btnBack, x + 18, y + 80, 40, 20);
      drawImage(A.btnBack, x + 70, y + 80, 40, 20);
      ctx.fillStyle = yesHot ? "rgba(26,94,26,0.85)" : "rgba(94,26,26,0.85)";
      ctx.fillRect(x + 18, y + 80, 40, 20);
      ctx.fillStyle = noHot ? "rgba(26,94,26,0.85)" : "rgba(94,26,26,0.85)";
      ctx.fillRect(x + 70, y + 80, 40, 20);
      // textaligny 15 on 20px buttons
      text("Yes", x + 38, y + 80 + 15, {
        scale: 0.25,
        fontSize: 24,
        align: "center",
        baseline: "q3",
      });
      text("No", x + 90, y + 80 + 15, {
        scale: 0.25,
        fontSize: 24,
        align: "center",
        baseline: "q3",
      });
    }
  }

  function readyCount() {
    return PLAYERS.filter((p) => p.ready && p.team !== "spec").length;
  }

  function playingCount() {
    return PLAYERS.filter((p) => p.team !== "spec").length;
  }

  function tickWarmup(dt) {
    state.phaseT += dt;
    if (state.phase === "waiting") {
      if (readyCount() >= 4 && playingCount() >= 4) {
        state.phase = "countdown";
        state.countdown = 10;
        state.phaseT = 0;
        toast("Countdown started");
      }
    } else if (state.phase === "countdown") {
      if (state.phaseT >= 1) {
        state.phaseT = 0;
        state.countdown -= 1;
        if (state.countdown <= 0) {
          state.phase = "fight";
          state.phaseT = 0;
          state.showJoinPanel = false;
          toast("FIGHT!");
        }
      }
    } else if (state.phase === "fight") {
      if (state.phaseT >= 1.4) {
        state.phase = "live";
        state.phaseT = 0;
      }
    }
  }

  function setMyTeam(team) {
    state.myTeam = team;
    PLAYERS[0].team = team === "free" ? "red" : team;
    if (team === "spec") {
      state.myReady = false;
      PLAYERS[0].ready = false;
      PLAYERS[0].team = "spec";
      state.showJoinPanel = true;
      toast('exec "team s"');
    } else {
      state.myReady = true;
      PLAYERS[0].ready = true;
      state.showJoinPanel = false; // joingame menu closes after join
      toast(`exec "team ${team === "free" ? "a" : team === "red" ? "r" : "b"}"`);
    }
  }

  function drawWarmupCenterHud() {
    // QL-style CG warmup banner (not menu chrome — drawn over world)
    if (state.phase === "waiting" || state.phase === "countdown") {
      const pulse = 0.85 + Math.sin(performance.now() / 280) * 0.15;
      text("WARMUP", 320, 70, {
        size: 42,
        align: "center",
        bold: true,
        color: "#ffe566",
        alpha: pulse,
      });

      if (state.phase === "waiting") {
        text("Waiting for players to ready up", 320, 100, {
          size: 13,
          align: "center",
          color: "#c8c8c8",
        });
        text(`${readyCount()} / 4 ready   ·   ${playingCount()} in match`, 320, 118, {
          size: 11,
          align: "center",
          color: "#8a93a3",
        });
        if (state.myTeam === "spec") {
          text("Join a team to play", 320, 140, {
            size: 12,
            align: "center",
            color: FOCUS,
          });
        } else if (!state.myReady) {
          text("Press F3 / click READY", 320, 140, {
            size: 12,
            align: "center",
            color: FOCUS,
          });
        } else {
          text("You are READY", 320, 140, {
            size: 12,
            align: "center",
            color: "#7dff9a",
          });
        }
      } else {
        // big countdown number
        const n = Math.max(1, state.countdown);
        text(String(n), 320, 145, {
          size: 96,
          align: "center",
          bold: true,
          color: n <= 3 ? "#ff5533" : "#fff",
          alpha: 0.95,
        });
        text("Match starting…", 320, 195, {
          size: 12,
          align: "center",
          color: "#bbb",
        });
      }
    } else if (state.phase === "fight") {
      // fight splash — QL uses a shader; we have fight.png (narrow) so also paint text
      const a = Math.min(1, state.phaseT * 3) * Math.max(0, 1 - (state.phaseT - 0.9) * 2);
      drawImage(A.fight, 64, 80, 512, 128, a * 0.9);
      text("FIGHT!", 320, 150, {
        size: 64,
        align: "center",
        bold: true,
        color: "#ff3300",
        alpha: a,
      });
    } else if (state.phase === "live") {
      text("LIVE", 320, 36, {
        size: 14,
        align: "center",
        color: "#7dff9a",
        alpha: 0.7,
        bold: true,
      });
      text("Warmup ended · press 1 to reset demo phase", 320, 52, {
        size: 10,
        align: "center",
        color: "#666",
      });
    }

    // mini ready roster strip (top-right)
    if (state.phase === "waiting" || state.phase === "countdown") {
      let y = 56;
      text("READY", 620, y, { size: 9, align: "right", color: "#888" });
      y += 14;
      const rows = PLAYERS.filter((p) => p.team !== "spec");
      for (const p of rows.slice(0, 8)) {
        const col = p.team === "red" ? "#ff6b5a" : p.team === "blue" ? "#6fb6ff" : "#ccc";
        text(`${p.ready ? "●" : "○"} ${p.name}`, 620, y, {
          size: 10,
          align: "right",
          color: p.ready ? col : "#666",
        });
        y += 13;
      }
    }
  }

  function drawJoinGamePanel() {
    // intro.smenu / joingame_menu — the match warmup join chrome
    const y0 = -10; // menu rect offset in intro.smenu

    // Offscreen for Q3-style color modulate + bgfill shader composite
    if (!drawJoinGamePanel._tint) {
      drawJoinGamePanel._tint = document.createElement("canvas");
      drawJoinGamePanel._tintCtx = drawJoinGamePanel._tint.getContext("2d");
      drawJoinGamePanel._fill = document.createElement("canvas");
      drawJoinGamePanel._fillCtx = drawJoinGamePanel._fill.getContext("2d");
    }
    const tintBuf = drawJoinGamePanel._tint;
    const tintCtx = drawJoinGamePanel._tintCtx;
    const fillBuf = drawJoinGamePanel._fill;
    const fillCtx = drawJoinGamePanel._fillCtx;

    function drawModulated(img, x, y, w, h, r, g, b, a) {
      if (!img.complete || !img.naturalWidth) return;
      tintBuf.width = Math.max(1, Math.round(w));
      tintBuf.height = Math.max(1, Math.round(h));
      tintCtx.clearRect(0, 0, tintBuf.width, tintBuf.height);
      tintCtx.globalCompositeOperation = "source-over";
      tintCtx.drawImage(img, 0, 0, tintBuf.width, tintBuf.height);
      tintCtx.globalCompositeOperation = "source-in";
      tintCtx.fillStyle = `rgb(${r | 0},${g | 0},${b | 0})`;
      tintCtx.fillRect(0, 0, tintBuf.width, tintBuf.height);
      tintCtx.globalCompositeOperation = "source-over";
      ctx.save();
      ctx.globalAlpha = a;
      ctx.drawImage(tintBuf, x, y, w, h);
      ctx.restore();
    }

    /** ui_hud.shader bgfill[_red]: base + additive scrolls + rotating orbs */
    function drawBgfillShader(x, y, w, h, team) {
      const base = team ? A.bgfillRed : A.bgfill;
      if (!base.complete || !base.naturalWidth) return;
      fillBuf.width = Math.max(1, Math.round(w));
      fillBuf.height = Math.max(1, Math.round(h));
      const fw = fillBuf.width;
      const fh = fillBuf.height;
      fillCtx.clearRect(0, 0, fw, fh);
      fillCtx.globalCompositeOperation = "source-over";
      fillCtx.globalAlpha = 1;
      fillCtx.drawImage(base, 0, 0, fw, fh);

      const t = performance.now() / 1000;

      if (A.bgfillO1.complete && A.bgfillO1.naturalWidth) {
        fillCtx.save();
        fillCtx.globalCompositeOperation = "lighter";
        fillCtx.globalAlpha = 0.5;
        const scroll = ((team ? -0.3 : 0.1) * t * fw) % fw;
        fillCtx.drawImage(A.bgfillO1, scroll, 0, fw, fh);
        fillCtx.drawImage(A.bgfillO1, scroll - fw, 0, fw, fh);
        fillCtx.restore();
      }
      if (A.bgfillO2.complete && A.bgfillO2.naturalWidth) {
        fillCtx.save();
        fillCtx.globalCompositeOperation = "lighter";
        fillCtx.globalAlpha = 0.4;
        const scroll = ((team ? -0.22 : -0.18) * t * fw) % fw;
        fillCtx.drawImage(A.bgfillO2, scroll, 0, fw, fh);
        fillCtx.drawImage(A.bgfillO2, scroll - fw, 0, fw, fh);
        fillCtx.restore();
      }

      function drawOrb(img, rotSpeed, alpha) {
        if (!img.complete || !img.naturalWidth) return;
        fillCtx.save();
        fillCtx.globalCompositeOperation = "lighter";
        fillCtx.globalAlpha = alpha;
        fillCtx.translate(fw * 0.22, fh * 0.55);
        fillCtx.rotate((rotSpeed * t * Math.PI) / 180);
        const s = Math.max(fw, fh) * 1.7;
        fillCtx.drawImage(img, -s / 2, -s / 2, s, s);
        fillCtx.restore();
      }
      drawOrb(A.bgfillO6, -25, 0.32);
      drawOrb(A.bgfillO7, -18, 0.26);

      ctx.drawImage(fillBuf, x, y, w, h);
    }

    function drawGametypeTabs(x, y, w, h) {
      // hashed strip, darkened (menu backcolor 0 0 0 0.4)
      drawModulated(A.gtbox, x, y, w, h, 55, 58, 64, 0.5);

      const labels = state.teamMode
        ? ["TDM", "Timelimit: 10", "Frag Limit: 0"]
        : ["Duel", "Timelimit: 5", "Frag Limit: 10"];
      const tabW = [78, 110, 118];
      let tx = x + 4;
      for (let i = 0; i < 3; i++) {
        const tw = tabW[i];
        const skew = 6;
        ctx.beginPath();
        ctx.moveTo(tx + skew, y - 1);
        ctx.lineTo(tx + tw, y - 1);
        ctx.lineTo(tx + tw - skew, y + h + 1);
        ctx.lineTo(tx, y + h + 1);
        ctx.closePath();
        ctx.fillStyle = "rgba(48, 52, 58, 0.75)";
        ctx.fill();
        ctx.strokeStyle = "rgba(170, 170, 170, 0.2)";
        ctx.stroke();
        text(labels[i], tx + tw / 2, y + h / 2, {
          scale: 0.18,
          fontSize: 16,
          align: "center",
          baseline: "middle",
          color: "#e8e8e8",
        });
        tx += tw + 6;
      }
    }

    // outer frame
    drawImage(A.frametl, 62, 74 + y0, 40, 40, 0.9);
    drawImage(A.framet, 102, 74 + y0, 436, 40, 0.9);
    drawImage(A.frametr, 538, 74 + y0, 40, 40, 0.9);
    drawImage(A.framel, 62, 114 + y0, 40, 210, 0.9);
    drawImage(A.framem, 102, 114 + y0, 436, 210, 0.9);
    drawImage(A.framer, 538, 114 + y0, 40, 210, 0.9);
    drawImage(A.framebl, 62, 324 + y0, 40, 20, 0.9);
    drawImage(A.frameb, 102, 324 + y0, 436, 20, 0.9);
    drawImage(A.framebr, 538, 324 + y0, 40, 20, 0.9);

    // title = CG_MAP_NAME — inside top frame strip (intro.smenu rect 82 88)
    text("MATCH WARMUP - Campgrounds", 82, 88 + y0, {
      scale: 0.2,
      fontSize: 16,
      color: "#ccc",
      baseline: "q3",
    });

    // header: shader fill + faint orange Q + gray info tabs + ad chrome
    drawBgfillShader(83, 94 + y0, 322, 75, state.teamMode);
    // logo2: backcolor 0.91 0.37 0.01 0.15
    drawModulated(A.logo2, 68, 91 + y0, 111, 101, 232, 94, 3, 0.18);
    drawImage(A.arrow, 69, 79 + y0, 10, 10);
    drawGametypeTabs(78, 96 + y0, 323, 11);

    drawImage(A.adtl, 50, 93 + y0, 40, 80);
    drawImage(A.adtm, 90, 93 + y0, 160, 80);
    drawImage(A.adtr, 250, 93 + y0, 320, 80);
    drawImage(A.adbr, 250, 173 + y0, 320, 20);

    // right box: Quake Live wordmark (ad2x1), matching screenshot
    ctx.fillStyle = "rgba(0,0,0,0.9)";
    ctx.fillRect(407, 95 + y0, 160, 80);
    drawImage(A.ad2x1, 407, 95 + y0, 160, 80);

    // Exact intro.smenu text coords (textscale / rect.y) — Q3 paint Y
    text("Welcome to Quake Live", 77, 127 + y0, {
      scale: 0.35,
      fontSize: 24,
      baseline: "q3",
    });
    text("Unranked Match", 80, 143 + y0, {
      scale: 0.24,
      fontSize: 24,
      color: "#b3b3b3",
      baseline: "q3",
    });
    text("This game is hosted by Quake Live", 80, 164 + y0, {
      scale: 0.24,
      fontSize: 24,
      color: FOCUS,
      baseline: "q3",
    });

    // about inset
    drawImage(A.scoretlA, 71, 185 + y0, 160, 20);
    drawImage(A.scoretl2, 231, 185 + y0, 80, 20);
    drawImage(A.scoretmA, 311, 185 + y0, 107, 20);
    drawImage(A.scoretr2, 418, 185 + y0, 40, 20);
    drawImage(A.scorel, 71, 205 + y0, 10, 88);
    drawImage(A.scorem, 81, 205 + y0, 367, 88);
    drawImage(A.scorer, 448, 205 + y0, 10, 88);
    drawImage(A.scorebl, 71, 293 + y0, 10, 10);
    drawImage(A.scoreb, 81, 293 + y0, 367, 10);
    drawImage(A.scorebr, 448, 293 + y0, 10, 10);

    // ABOUT tab label — sits in orange scoretl (menu: rect 78 197, scale .18)
    text("ABOUT THIS MATCH", 78, 197 + y0, {
      scale: 0.18,
      fontSize: 16,
      baseline: "q3",
    });
    if (state.teamMode) {
      text("This is a Team Deathmatch game", 86, 218 + y0, { scale: 0.2, fontSize: 24, baseline: "q3" });
      text("Eliminate the other team!", 95, 236 + y0, { scale: 0.2, fontSize: 24, color: "#999", baseline: "q3" });
      text("First team to reach the Frag Limit wins.", 95, 249 + y0, {
        scale: 0.2,
        fontSize: 24,
        color: "#999",
        baseline: "q3",
      });
      text("If time runs out, highest score wins.", 95, 262 + y0, {
        scale: 0.2,
        fontSize: 24,
        color: "#999",
        baseline: "q3",
      });
      text("Warmup until enough players are ready.", 95, 275 + y0, {
        scale: 0.2,
        fontSize: 24,
        color: "#999",
        baseline: "q3",
      });
      text("Server: localdemo", 95, 288 + y0, { scale: 0.2, fontSize: 24, color: "#999", baseline: "q3" });
    } else {
      text("This is a 1 vs 1 Duel game", 86, 218 + y0, { scale: 0.2, fontSize: 24, baseline: "q3" });
      text("Defeat your opponent!", 95, 236 + y0, { scale: 0.2, fontSize: 24, color: "#999", baseline: "q3" });
      text("First player to reach the Frag Limit wins.", 95, 249 + y0, {
        scale: 0.2,
        fontSize: 24,
        color: "#999",
        baseline: "q3",
      });
      text("If time runs out, the player with the highest score wins.", 95, 262 + y0, {
        scale: 0.2,
        fontSize: 24,
        color: "#999",
        baseline: "q3",
      });
      text("If the time limit is hit and there is a tie a Sudden Death round begins.", 95, 275 + y0, {
        scale: 0.2,
        fontSize: 24,
        color: "#999",
        baseline: "q3",
      });
      text("Server: localdemo", 95, 288 + y0, { scale: 0.2, fontSize: 24, color: "#999", baseline: "q3" });
    }

    // bottom nav: LEAVE MATCH | status | SPECTATE  (intro.smenu 99/320/539 @ 326)
    hit("wLeave", 73, 312 + y0, 80, 20, () => toast("disconnect"));
    drawImage(A.navlefty, 73, 312 + y0, 80, 20);
    text("LEAVE MATCH", 99, 326 + y0, {
      scale: 0.2,
      fontSize: 16,
      color: "#ccc",
      baseline: "q3",
    });
    text(
      state.myTeam === "spec" ? "Join Match to Begin Playing" : "Warmup - free fire until ready",
      320,
      326 + y0,
      { scale: 0.2, fontSize: 16, align: "center", color: FOCUS, baseline: "q3" }
    );
    hit("wSpecNav", 485, 312 + y0, 80, 20, () => setMyTeam("spec"));
    drawImage(A.navrighty, 485, 312 + y0, 80, 20);
    text("SPECTATE", 539, 326 + y0, {
      scale: 0.2,
      fontSize: 16,
      align: "right",
      color: "#ccc",
      baseline: "q3",
    });

    // spectator strip — timer | player ticker | count  (intro.smenu @ 360)
    drawImage(A.specl, 71, 346 + y0, 80, 20, 0.5);
    drawImage(A.specm, 151, 346 + y0, 338, 20, 0.5);
    drawImage(A.specflip, 489, 346 + y0, 80, 20, 0.5);
    text("0:00", 96, 360 + y0, { scale: 0.22, fontSize: 16, color: "#bababa", baseline: "q3" });
    const tickNames = PLAYERS.map((p) => p.name).join("   ");
    text(tickNames || "—", 320, 360 + y0, {
      scale: 0.2,
      fontSize: 16,
      align: "center",
      color: "#999",
      baseline: "q3",
    });
    text("2/16 Players", 529, 360 + y0, {
      scale: 0.2,
      fontSize: 16,
      align: "center",
      color: "#999",
      baseline: "q3",
    });

    // join buttons (warmup) — menu textaligny ~18 into 20px rows
    if (state.teamMode) {
      const rows = [
        { id: "wJoinRed", label: "JOIN RED", img: A.navright, y: 206, team: "red" },
        { id: "wJoinBlue", label: "JOIN BLUE", img: A.navrightb, y: 236, team: "blue" },
        { id: "wAuto", label: "AUTO JOIN", img: A.navrighty, y: 266, team: "free" },
      ];
      for (const row of rows) {
        const hy = row.y + y0;
        const hot = hit(row.id, 485, hy, 80, 20, () => setMyTeam(row.team));
        drawImage(row.img, 485, hy, 80, 20);
        text(row.label, 539, hy + 18, {
          scale: 0.2,
          fontSize: 16,
          align: "right",
          color: hot || state.myTeam === row.team ? FOCUS : "#fff",
          baseline: "q3",
        });
      }
    } else {
      const hy = 272 + y0;
      const hot = hit("wJoinMatch", 464, hy, 103, 24, () => setMyTeam("free"));
      drawImage(A.bigred, 464, hy, 103, 24);
      text("JOIN MATCH", 550, hy + 18, {
        scale: 0.25,
        fontSize: 24,
        align: "right",
        color: hot ? FOCUS : "#fff",
        baseline: "q3",
      });
    }

    // ready toggle (above bottom nav — nav owns 312–326)
    if (state.myTeam !== "spec") {
      const readyHot = hit("wReady", 78, 290 + y0, 100, 18, () => {
        state.myReady = !state.myReady;
        PLAYERS[0].ready = state.myReady;
        toast(state.myReady ? "readyup" : "notready");
      });
      ctx.fillStyle = state.myReady ? "rgba(30,120,50,0.8)" : "rgba(80,30,30,0.8)";
      ctx.fillRect(78, 290 + y0, 100, 18);
      text(state.myReady ? "READY" : "CLICK TO READY", 128, 299 + y0, {
        scale: 0.18,
        fontSize: 16,
        align: "center",
        color: readyHot ? FOCUS : "#fff",
        baseline: "q3",
      });
    }

    // demo toggles
    const tog = hit("wToggleTeam", 200, 290 + y0, 140, 16, () => {
      state.teamMode = !state.teamMode;
      toast(state.teamMode ? "Team warmup UI" : "FFA warmup UI");
    });
    text(state.teamMode ? "[demo] FFA buttons" : "[demo] team buttons", 200, 298 + y0, {
      scale: 0.16,
      fontSize: 16,
      color: tog ? FOCUS : "#555",
      baseline: "q3",
    });
  }

  function drawViewTabs() {
    // outside-chrome view switcher drawn in-canvas top-left
    const tabs = [
      { id: "warmup", label: "1 WARMUP", x: 8 },
      { id: "esc", label: "2 ESC MENU", x: 88 },
    ];
    for (const t of tabs) {
      const on = state.view === t.id;
      const hot = hit(`view:${t.id}`, t.x, 4, 76, 16, () => {
        state.view = t.id;
        state.open = t.id === "esc";
        state.popup = null;
        toast(t.id === "warmup" ? "Warmup / join match UI" : "Esc in-game menu");
      });
      ctx.fillStyle = on ? "rgba(255,191,0,0.25)" : hot ? "rgba(255,255,255,0.1)" : "rgba(0,0,0,0.45)";
      ctx.fillRect(t.x, 4, 76, 16);
      text(t.label, t.x + 38, 14, {
        scale: 0.16,
        fontSize: 16,
        align: "center",
        color: on || hot ? FOCUS : "#9aa3b2",
        baseline: "q3",
      });
    }
  }

  // 3_cursor3.png is 32x32; the arrow tip (hotspot) is at ~18,18 — not 0,0
  const CURSOR_HOT_X = 18;
  const CURSOR_HOT_Y = 18;
  const CURSOR_SIZE = 32;

  function drawCursor() {
    drawImage(
      A.cursor,
      state.mx - CURSOR_HOT_X,
      state.my - CURSOR_HOT_Y,
      CURSOR_SIZE,
      CURSOR_SIZE
    );
  }

  function canvasPoint(e) {
    const r = canvas.getBoundingClientRect();
    // Map CSS pixels → virtual 640x480 (handles letterboxing / non-uniform scale)
    const x = ((e.clientX - r.left) / r.width) * W;
    const y = ((e.clientY - r.top) / r.height) * H;
    return {
      x: Math.max(0, Math.min(W, x)),
      y: Math.max(0, Math.min(H, y)),
    };
  }

  let lastT = performance.now();

  function frame() {
    const now = performance.now();
    const dt = Math.min(0.05, (now - lastT) / 1000);
    lastT = now;

    hits.length = 0;
    drawBackdrop();
    drawViewTabs();

    if (state.view === "warmup") {
      tickWarmup(dt);
      drawWarmupCenterHud();
      if (state.showJoinPanel && state.phase !== "fight" && state.phase !== "live") {
        drawJoinGamePanel();
      } else if (state.phase === "live") {
        text("Press 1 to replay warmup · Esc for GAME MENU", 320, 450, {
          size: 12,
          align: "center",
          color: "#888",
        });
      }
    } else {
      // esc menu view
      if (!state.open) {
        drawClosedHint();
      } else {
        drawShell();
        if (state.tab === "about") drawAbout();
        else if (state.tab === "controls") drawControls();
        else if (state.tab === "options") drawOptions();
        else if (state.tab === "vote") drawVote();
        drawBottomNav();
        if (state.popup === "join") drawJoinPopup();
        if (state.popup === "leave" || state.popup === "quitConfirm" || state.popup === "restartConfirm") {
          drawLeavePopup();
        }
      }
    }

    if (state.flash > 0) state.flash = Math.max(0, state.flash - 0.01);
    text(state.status, 320, 468, {
      scale: 0.18,
      fontSize: 16,
      align: "center",
      color: state.flash > 0 ? FOCUS : "#7a8494",
      alpha: 0.9,
      baseline: "q3",
    });

    drawCursor();
    requestAnimationFrame(frame);
  }

  canvas.addEventListener("mousemove", (e) => {
    const p = canvasPoint(e);
    state.mx = p.x;
    state.my = p.y;
    let found = null;
    for (let i = hits.length - 1; i >= 0; i--) {
      if (pointIn(p.x, p.y, hits[i])) {
        found = hits[i].id;
        break;
      }
    }
    state.hover = found;
  });

  canvas.addEventListener("click", (e) => {
    const p = canvasPoint(e);
    for (let i = hits.length - 1; i >= 0; i--) {
      const h = hits[i];
      if (pointIn(p.x, p.y, h)) {
        h.onClick();
        return;
      }
    }
    // out-of-bounds click closes popups (QL outOfBoundsClick)
    if (state.popup) {
      state.popup = null;
      toast("Popup closed");
    }
  });

  window.addEventListener("keydown", (e) => {
    if (e.key === "1") {
      state.view = "warmup";
      state.open = false;
      state.popup = null;
      state.phase = "waiting";
      state.countdown = 10;
      state.phaseT = 0;
      state.showJoinPanel = true;
      state.myTeam = "spec";
      state.myReady = false;
      PLAYERS[0].team = "spec";
      PLAYERS[0].ready = false;
      toast("Warmup view (reset)");
      return;
    }
    if (e.key === "2") {
      state.view = "esc";
      state.open = true;
      state.popup = null;
      toast("Esc menu view");
      return;
    }
    if (e.key === "Escape") {
      e.preventDefault();
      if (state.popup) {
        state.popup = null;
        toast("Popup closed");
      } else if (state.view === "warmup") {
        state.view = "esc";
        state.open = true;
        toast("GAME MENU");
      } else {
        state.open = !state.open;
        if (!state.open) {
          state.view = "warmup";
          toast("Back to warmup");
        } else {
          toast("GAME MENU");
        }
      }
    } else if (e.key === "j" || e.key === "J") {
      if (state.view === "esc" && state.open) {
        state.popup = "join";
        toast("Join team popup (ingame_join)");
      }
    } else if (e.key === "l" || e.key === "L") {
      if (state.view === "esc" && state.open) {
        state.popup = "leave";
        toast("Leave popup (ingame_leave)");
      }
    } else if (e.key === "F3" || e.key === "r" || e.key === "R") {
      if (state.view === "warmup" && state.myTeam !== "spec") {
        state.myReady = !state.myReady;
        PLAYERS[0].ready = state.myReady;
        toast(state.myReady ? "readyup" : "notready");
      }
    }
  });

  // wait a tick for images, then run
  const boot = () => {
    if (!ready()) {
      requestAnimationFrame(boot);
      return;
    }
    toast("Warmup UI · join a team + ready (need 4) · 1/2 views");
    requestAnimationFrame(frame);
  };
  boot();
})();
