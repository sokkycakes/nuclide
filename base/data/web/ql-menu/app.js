/* Quake Live in-game menu canvas demo
   Layout coords match QL's 640x480 UI virtual screen from ui/ingame*.menu */

(() => {
  const canvas = document.getElementById("c");
  const ctx = canvas.getContext("2d", { alpha: true });
  const toastEl = document.getElementById("toast");

  const W = 640;
  const H = 480;
  const FOCUS = "rgb(255, 191, 0)";

  /* Letterbox 640×480 into the host view using clientWidth/Height.
     Avoid CSS vw/vh — WebCore often resolves those to 0 (blank canvas in-game). */
  function layoutCanvas() {
    const aw = document.documentElement.clientWidth || window.innerWidth || 0;
    const ah = document.documentElement.clientHeight || window.innerHeight || 0;
    if (aw <= 0 || ah <= 0) return;
    const scale = Math.min(aw / W, ah / H);
    const dw = Math.max(1, Math.floor(W * scale));
    const dh = Math.max(1, Math.floor(H * scale));
    canvas.style.width = dw + "px";
    canvas.style.height = dh + "px";
    canvas.style.left = Math.floor((aw - dw) / 2) + "px";
    canvas.style.top = Math.floor((ah - dh) / 2) + "px";
  }
  layoutCanvas();
  window.addEventListener("resize", layoutCanvas);

  /* WebCore: fte:// Image()/img decode often yields naturalWidth=0 for canvas.
     data: URLs decode in-process (same as @font-face in fonts.css). Packed in
     assets-data.js — relative fte paths remain a browser-dev fallback. */
  const preload = document.createElement("div");
  preload.id = "ql-preload";
  preload.setAttribute("aria-hidden", "true");
  preload.style.cssText =
    "position:absolute;left:-10000px;top:0;width:512px;height:512px;overflow:hidden;opacity:1;pointer-events:none";
  document.body.appendChild(preload);

  function load(src) {
    const img = document.createElement("img");
    img.alt = "";
    const packed = window.QL_ASSETS && window.QL_ASSETS[src];
    img.src = packed || src;
    img.style.cssText = "display:block;max-width:128px;max-height:128px";
    img.onerror = () => {
      img.dataset.failed = "1";
      console.warn("missing asset", src);
    };
    preload.appendChild(img);
    return img;
  }

  const A = {
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

  const TABS = [
    { id: "about", label: "CURRENT MATCH", x: 72 },
    { id: "controls", label: "CONTROLS", x: 167 },
    { id: "options", label: "GAME SETTINGS", x: 262 },
    { id: "vote", label: "CALL VOTE", x: 357 },
  ];

  let PLAYERS = [
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
  const demoMode = typeof window.fte_query !== "function";
  const wantArena = new URLSearchParams(window.location.search).get("mode") === "arena";
  /* Live engine: ?mode=arena + fte_query. Browser: same URL, fixture snapshot. */
  const arenaMode = wantArena;
  const arenaFixture = demoMode && wantArena;
  let arenaSnapshot = null;
  let arenaLastPoll = 0;

  const ARENA_FIXTURE_HEROES = [
    { id: "hero_collier", name: "hero_collier" },
    { id: "hero_beaumont", name: "hero_beaumont" },
    { id: "hero_vagrant", name: "hero_vagrant" },
    { id: "hero_skipstream", name: "hero_skipstream" },
    { id: "hero_angel", name: "hero_angel" },
    { id: "hero_motionblue", name: "hero_motionblue" },
    { id: "hero_archstiletto", name: "hero_archstiletto" },
  ];

  /** Browser-only stand-in for webcore_arena_snapshot / getarena. */
  function makeArenaFixture(kind) {
    const base = {
      active: true,
      phase: "WARMUP",
      round: "Round 0 / 3",
      map: "duel_alley",
      readyCount: 0,
      players: ["", ""],
      heroes: ARENA_FIXTURE_HEROES.map((h) => ({ ...h })),
      local: { state: 0, hero: "", needsHero: false, joining: false },
    };
    if (kind === "hero") {
      /* Auto Assign in progress — must pick a hero */
      base.local = { state: 0, hero: "", needsHero: true, joining: true };
    } else if (kind === "armed") {
      /* Hero chosen, not yet in the ready queue — shows READY UP */
      base.local = { state: 0, hero: "hero_collier", needsHero: false, joining: false };
    } else if (kind === "ready") {
      /* Already queued */
      base.local = { state: 1, hero: "hero_collier", needsHero: false, joining: false };
      base.readyCount = 1;
      base.players = ["You (0)", ""];
    } else if (kind === "spectate") {
      base.local = { state: 2, hero: "hero_collier", needsHero: false, joining: false };
      base.readyCount = 1;
      base.players = ["Bob (0)", "Alice (0)"];
    } else {
      /* waiting — connected, not joining */
      base.local = { state: 0, hero: "", needsHero: false, joining: false };
    }
    return base;
  }

  if (arenaFixture) {
    arenaSnapshot = makeArenaFixture("waiting");
    state.status = "Arena fixture · 1 wait · 2 hero · 3 ready-up · 4 queued · 5 spec";
  }

  /** Send a console command to the engine (noop in standalone browser). */
  function cbuf(cmd) {
    if (demoMode) return false;
    try { return window.fte_query("cbuf:" + cmd) === "ok"; }
    catch (e) { return false; }
  }

  function arenaAction(action) {
    if (!arenaMode) return false;
    if (arenaFixture) {
      const a = arenaSnapshot || makeArenaFixture("waiting");
      const local = { ...(a.local || {}) };
      if (action === "close") {
        toast("ESC (fixture — no engine close)");
        return true;
      }
      if (action.indexOf("hero:") === 0) {
        local.hero = action.slice(5);
        local.needsHero = false;
        local.joining = false;
        local.state = 0;
        a.local = local;
        arenaSnapshot = a;
        toast("Hero set — press READY UP");
        return true;
      }
      if (action === "join" || action === "play") {
        local.joining = true;
        local.needsHero = true;
        local.hero = "";
        local.state = 0;
        a.local = local;
        arenaSnapshot = a;
        toast("JOIN → choose hero");
        return true;
      }
      if (action === "choosehero") {
        local.joining = true;
        local.needsHero = true;
        local.state = 0;
        a.local = local;
        arenaSnapshot = a;
        toast("CHOOSE HERO");
        return true;
      }
      if (action === "spectate") {
        local.state = 2;
        local.joining = false;
        local.needsHero = false;
        a.local = local;
        arenaSnapshot = a;
        toast("SPECTATE");
        return true;
      }
      if (action === "ready") {
        if (!local.hero) {
          toast("Pick a hero first");
          return false;
        }
        local.state = 1;
        local.needsHero = false;
        local.joining = false;
        a.local = local;
        a.readyCount = Math.max(1, Number(a.readyCount) || 0);
        arenaSnapshot = a;
        toast("READY — in queue");
        return true;
      }
      if (action === "unready") {
        local.state = 0;
        local.joining = false;
        a.local = local;
        a.readyCount = Math.max(0, (Number(a.readyCount) || 1) - 1);
        arenaSnapshot = a;
        toast("NOT READY — press READY UP");
        return true;
      }
      toast(action);
      return true;
    }
    try {
      const reply = window.fte_query("arena_action:" + action);
      const result = JSON.parse(reply || "");
      if (result && result.ok === true) {
        /* Plugin closes on spectate; belt-and-suspenders for leave-queue. */
        if (action === "spectate") {
          try { window.fte_query("arena_action:close"); } catch (e) { /* ignore */ }
        }
        toast(action.replace("hero:", "SELECT "));
        return true;
      }
    } catch (e) { /* bridge may disappear while the menu is closing */ }
    toast("Action unavailable");
    return false;
  }

  function syncArena(now) {
    if (!arenaMode || now < arenaLastPoll) return;
    arenaLastPoll = now + 120;
    if (arenaFixture) {
      if (!arenaSnapshot) arenaSnapshot = makeArenaFixture("waiting");
      return;
    }
    try {
      const raw = window.fte_query("getarena");
      const snapshot = raw ? JSON.parse(raw) : null;
      arenaSnapshot = snapshot && typeof snapshot === "object" && !Array.isArray(snapshot) ? snapshot : null;
    } catch (e) {
      arenaSnapshot = null;
    }
  }

  // Set dark background for standalone browser; transparent for WebCore
  if (demoMode) {
    document.body.style.background =
      "radial-gradient(1200px 700px at 50% 20%, #1a2230 0%, #0a0c10 60%)";
  }

  function toast(msg) {
    state.status = msg;
    if (toastEl) toastEl.textContent = msg;
    state.flash = 1;
  }

  // Canvas text uses CSS @font-face faces from fonts.css — not QL bitmap atlases.
  let menuFontReady = false;
  if (document.fonts && document.fonts.load) {
    Promise.all([
      document.fonts.load('12px "standard_07_57"'),
      document.fonts.load('12px "hooge_05_57"'),
    ])
      .then(() => {
        menuFontReady = true;
      })
      .catch(() => {
        menuFontReady = true;
      });
  } else {
    menuFontReady = true;
  }

  function ready() {
    const imgsOk = Object.values(A).every((img) => img.complete && img.naturalWidth > 0);
    return imgsOk && menuFontReady;
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

  // Former QL bitmap glyphScale — keeps relative sizes when callers pass textscale.
  const QL_GLYPH_SCALE = { 16: 3, 24: 2, 48: 1 };

  function resolveTextPx(opts) {
    const { size = 12, scale = null, fontSize = 24 } = opts;
    if (scale != null) {
      const gs = QL_GLYPH_SCALE[fontSize] || 2;
      return Math.max(8, Math.round(fontSize * scale * gs));
    }
    return Math.max(8, Math.round(size));
  }

  /**
   * Canvas text (not QL bitmap atlases).
   * - `font`: CSS family name (default standard_07_57; e.g. hooge_05_57)
   * - `scale` + `fontSize`: map old Q3 textscale → px via former glyphScale
   * - `size`: direct px when scale omitted
   * - baseline "q3": treated as alphabetic (former paint Y)
   */
  function text(str, x, y, opts = {}) {
    const {
      font = "standard_07_57",
      color = "#fff",
      align = "left",
      baseline = opts.scale != null ? "q3" : "alphabetic",
      alpha = 1,
    } = opts;
    const px = resolveTextPx(opts);
    const s = normalizeGlyphs(str);

    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.fillStyle = color;
    ctx.font = `${px}px "${font}", monospace`;
    ctx.textAlign = align;
    if (baseline === "top") ctx.textBaseline = "top";
    else if (baseline === "middle") ctx.textBaseline = "middle";
    else ctx.textBaseline = "alphabetic"; // q3 / alphabetic
    ctx.fillText(s, x, y);
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
    ctx.clearRect(0, 0, W, H);
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
          if (!demoMode) {
            if (tab.id === "controls" || tab.id === "options") { cbuf("menu_options"); return; }
            if (tab.id === "vote") { cbuf("menu_callvote"); return; }
          }
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
      if (demoMode) { toast("Returned to match"); return; }
      cbuf("webcore_closemenu");
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
          if (demoMode) { toast(`exec "${row.cmd}"`); return; }
          cbuf(row.cmd);
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
        { label: "Return to Game", cy: 30, action: () => { state.open = false; state.popup = null; if (!demoMode) cbuf("webcore_closemenu"); } },
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
        if (demoMode) { toast(isQuit ? "disconnect" : "map_restart"); state.popup = null; return; }
        cbuf(isQuit ? "disconnect" : "map_restart");
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
    if (!demoMode) return; // phase machine is demo-only; real game state comes from server
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
      if (demoMode) { toast("SPECTATE"); return; }
      cbuf("team s");
    } else {
      state.myReady = true;
      PLAYERS[0].ready = true;
      state.showJoinPanel = false;
      const cmd = team === "free" ? "team a" : team === "red" ? "team r" : "team b";
      if (demoMode) { toast("JOIN " + cmd.slice(5).toUpperCase()); return; }
      cbuf(cmd);
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
          font: "hooge_05_57",
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
    hit("wLeave", 73, 312 + y0, 80, 20, () => { if (demoMode) { toast("LEAVE MATCH"); return; } cbuf("disconnect"); });
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
        if (demoMode) {
          state.myReady = !state.myReady;
          PLAYERS[0].ready = state.myReady;
          toast(state.myReady ? "readyup" : "notready");
          return;
        }
        cbuf("ready");
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

  /**
   * Warmup join-row styling (intro.smenu):
   * - chip: navright 80×20, label right-aligned at x+54 (leaves arrow clear)
   * - join: bigred 103×24, label at x+86 (same as JOIN MATCH on warmup)
   */
  function drawArenaButton(id, label, x, y, onClick, opts = {}) {
    const kind = opts.kind || "chip";
    const active = !!opts.active;
    const w = kind === "join" ? 103 : 80;
    const h = kind === "join" ? 24 : 20;
    const textX = x + (kind === "join" ? 86 : 54);
    const textScale = kind === "join" ? 0.25 : 0.2;
    const textFont = kind === "join" ? 24 : 16;
    const hot = hit(id, x, y, w, h, onClick);
    const art =
      opts.img ||
      (kind === "join" ? A.bigred : active || hot ? A.navrighty : A.navright);
    drawImage(art, x, y, w, h);
    text(label, textX, y + 18, {
      scale: textScale,
      fontSize: textFont,
      align: "right",
      color: hot || active ? FOCUS : "#fff",
      baseline: "q3",
    });
  }

  function arenaHeroLabel(hero) {
    const raw = String((hero && (hero.name || hero.id)) || "");
    return raw.replace(/^hero_/i, "");
  }

  function drawArenaSelector() {
    const a = arenaSnapshot;
    drawBackdrop();
    if (!a || !a.active) {
      text("Waiting for arena state…", 320, 235, { size: 16, align: "center", color: "#bbb" });
      return;
    }

    const phase = String(a.phase || "WARMUP");
    const local = a.local || {};
    const playerState = Number(local.state || 0);
    const needsHero = !!local.needsHero;
    const heroName = local.hero || "No hero selected";
    const players = (Array.isArray(a.players) ? a.players.filter(Boolean) : []).slice(0, 2);
    const canReady = playerState === 0 && !!local.hero && !needsHero;
    /* Inset from score panel right edge (68+504=572): chips end ~24px in. */
    const chipX = 468;
    const joinX = 445;

    scoreInset(68, 58, 504, 332);
    text("DUEL ARENA", 84, 88, { scale: 0.35, fontSize: 24, color: "#fff", baseline: "q3" });
    text(String(a.map || "unknown").toUpperCase(), 84, 108, { scale: 0.2, fontSize: 16, color: FOCUS, baseline: "q3" });
    text(phase, 550, 88, { scale: 0.26, fontSize: 24, align: "right", color: phase === "LIVE" ? "#7dff9a" : FOCUS, baseline: "q3" });
    text(String(a.round || "Warmup"), 550, 108, { scale: 0.18, fontSize: 16, align: "right", color: "#aaa", baseline: "q3" });

    text("CURRENT DUEL", 92, 145, { scale: 0.18, fontSize: 16, color: "#aaa", baseline: "q3" });
    if (players.length) {
      players.forEach((name, i) => {
        text(name, 105, 170 + i * 24, { scale: 0.24, fontSize: 24, color: i ? "#ff8a78" : "#9ecfff", baseline: "q3" });
      });
    } else {
      text("Waiting for competitors", 105, 170, { scale: 0.22, fontSize: 24, color: "#777", baseline: "q3" });
    }
    text(`${Number(a.readyCount || 0)} queued and ready`, 92, 232, { scale: 0.2, fontSize: 16, color: "#bbb", baseline: "q3" });
    text(`YOUR STATUS: ${needsHero ? "CHOOSE A HERO" : playerState === 1 ? "READY" : playerState === 2 ? "SPECTATING" : playerState === 3 ? "COMPETING" : canReady ? "PRESS READY UP" : "WAITING"}`, 92, 258, { scale: 0.2, fontSize: 16, color: needsHero || canReady ? FOCUS : "#ddd", baseline: "q3" });
    text(`HERO: ${heroName}`, 92, 280, { scale: 0.2, fontSize: 16, color: "#aaa", baseline: "q3" });

    if (needsHero) {
      const heroGridX = 300;
      const heroColStep = 88; /* 80px chip + 8px gutter */
      text("SELECT YOUR HERO", heroGridX, 145, { scale: 0.2, fontSize: 16, color: FOCUS, baseline: "q3" });
      const heroes = (Array.isArray(a.heroes) ? a.heroes : []).slice(0, 8);
      heroes.forEach((hero, i) => {
        const col = i % 2;
        const row = Math.floor(i / 2);
        drawArenaButton(
          `hero:${hero.id}`,
          arenaHeroLabel(hero),
          heroGridX + col * heroColStep,
          160 + row * 28,
          () => arenaAction(`hero:${hero.id}`),
          { active: local.hero === hero.id, img: local.hero === hero.id ? A.navrighty : A.navright }
        );
      });
      const heroRows = Math.ceil(heroes.length / 2);
      drawArenaButton("spectate", "SPECTATE", chipX, 160 + heroRows * 28 + 8, () => arenaAction("spectate"), {
        img: A.navrighty,
      });
    } else {
      let by = 206;
      if (playerState === 2) {
        /* Pure spectator — re-enter via the join/hero path */
        drawArenaButton("play", "JOIN QUEUE", joinX, by, () => arenaAction("play"), { kind: "join" });
      } else if (playerState === 1 || playerState === 3) {
        /* Queued or live competitor: change hero and/or leave to non-competing spectate. */
        drawArenaButton("choosehero", "CHOOSE HERO", chipX, by, () => arenaAction("choosehero"), {
          img: A.navright,
        });
        by += 30;
        drawArenaButton("leaveQueue", "LEAVE QUEUE", chipX, by, () => arenaAction("spectate"), {
          img: A.navrighty,
        });
      } else if (canReady) {
        /* Hero chosen, not queued yet */
        drawArenaButton("ready", "READY UP", joinX, by, () => arenaAction("ready"), { kind: "join" });
        by += 30;
        drawArenaButton("choosehero", "CHOOSE HERO", chipX, by, () => arenaAction("choosehero"), {
          img: A.navright,
        });
        by += 30;
        drawArenaButton("leaveQueue", "LEAVE QUEUE", chipX, by, () => arenaAction("spectate"), {
          img: A.navrighty,
        });
      } else {
        drawArenaButton("join", "JOIN MATCH", joinX, by, () => arenaAction("join"), { kind: "join" });
        by += 30;
        drawArenaButton("spectate", "SPECTATE", chipX, by, () => arenaAction("spectate"), { img: A.navrighty });
      }
    }

    text(state.status, 320, 342, {
      scale: 0.18,
      fontSize: 16,
      align: "center",
      color: state.flash > 0 ? FOCUS : "#aeb8c6",
      alpha: 0.9,
      baseline: "q3",
    });
    text("ESC  BACK", 532, 368, { scale: 0.18, fontSize: 16, align: "right", color: "#999", baseline: "q3" });
  }

  let lastT = performance.now();

  function frame() {
    const now = performance.now();
    layoutCanvas();
    if (arenaMode) {
      hits.length = 0;
      syncArena(now);
      if (state.flash > 0) state.flash = Math.max(0, state.flash - 0.01);
      drawArenaSelector();
      drawCursor();
      requestAnimationFrame(frame);
      return;
    }
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
    if (arenaFixture) {
      if (e.key === "1") {
        arenaSnapshot = makeArenaFixture("waiting");
        toast("Fixture: waiting");
        return;
      }
      if (e.key === "2") {
        arenaSnapshot = makeArenaFixture("hero");
        toast("Fixture: choose hero");
        return;
      }
      if (e.key === "3") {
        arenaSnapshot = makeArenaFixture("armed");
        toast("Fixture: press READY UP");
        return;
      }
      if (e.key === "4") {
        arenaSnapshot = makeArenaFixture("ready");
        toast("Fixture: queued");
        return;
      }
      if (e.key === "5") {
        arenaSnapshot = makeArenaFixture("spectate");
        toast("Fixture: spectate");
        return;
      }
    }
    if (e.key === "1") {
      if (arenaMode) return;
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
      if (arenaMode) return;
      state.view = "esc";
      state.open = true;
      state.popup = null;
      toast("Esc menu view");
      return;
    }
    if (e.key === "Escape") {
      if (arenaMode) {
        e.preventDefault();
        arenaAction("close");
        return;
      }
      if (!demoMode) {
        // In WebCore: esc menu → close; warmup → let engine handle
        if (state.view === "esc" && state.open) {
          e.preventDefault();
          state.open = false;
          cbuf("webcore_closemenu");
        }
        return;
      }
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
      if (!demoMode) return;
      if (state.view === "esc" && state.open) {
        state.popup = "join";
        toast("Join team popup (ingame_join)");
      }
    } else if (e.key === "l" || e.key === "L") {
      if (!demoMode) return;
      if (state.view === "esc" && state.open) {
        state.popup = "leave";
        toast("Leave popup (ingame_leave)");
      }
    } else if (e.key === "F3" || e.key === "r" || e.key === "R") {
      if (!demoMode) return;
      if (state.view === "warmup" && state.myTeam !== "spec") {
        state.myReady = !state.myReady;
        PLAYERS[0].ready = state.myReady;
        toast(state.myReady ? "readyup" : "notready");
      }
    }
  });

  // wait a tick for images, then run (cap wait so a hung Image never blanks WebCore forever)
  const bootStarted = performance.now();
  const boot = () => {
    layoutCanvas();
    if (!ready() && performance.now() - bootStarted < 8000) {
      requestAnimationFrame(boot);
      return;
    }
    toast("Warmup UI · join a team + ready (need 4) · 1/2 views");
    {
      const decoded = Object.values(A).filter((img) => img.naturalWidth > 0).length;
      const total = Object.values(A).length;
      if (decoded < total) {
        console.warn("ql-menu: decoded", decoded, "/", total, "assets");
        toast(`Assets ${decoded}/${total} — check WebCore image log`);
      }
    }
    requestAnimationFrame(frame);
  };
  boot();
})();
