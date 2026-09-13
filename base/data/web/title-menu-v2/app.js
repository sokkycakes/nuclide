/* Title menu v2 — Figma flash-pixel look (node 127:66). Same cmds as v1. */
(function () {
  /* Focus bar tops: CREATE 529, JOIN 553, SETTINGS 577, QUIT 600 (24px rows). */
  var ITEM_Y = [529, 553, 577, 600];
  var REF_H = 768;
  /* Classic Quake menu chrome via FTE localsound (stem; engine picks .wav/.ogg/…). */
  var SND_NAV = "misc/menu1";
  var SND_OK = "misc/menu2";
  var SND_BACK = "misc/menu3";

  var TRANSITION_MS = 180;
  var reduceMotion = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  var transitionMs = reduceMotion ? 0 : TRANSITION_MS;

  var stage = document.getElementById("stage");
  var titleChrome = document.getElementById("title-chrome");
  var focusBar = document.getElementById("focus-bar");
  var items = Array.prototype.slice.call(document.querySelectorAll(".menu-item"));
  var selected = 0;
  var joinDialog = document.getElementById("join-dialog");
  var joinList = document.getElementById("join-list");
  var joinConnect = document.getElementById("join-connect");
  var selectedAddr = null;
  var joinOpen = false;
  var transitioning = true;

  function q(req) {
    if (typeof window.fte_query !== "function") return null;
    try { return window.fte_query(req); } catch (e) { return null; }
  }
  function cbuf(cmd) {
    if (!cmd) return false;
    return q("cbuf:" + cmd) === "ok";
  }
  function localsound(sample) {
    if (!sample) return;
    q("localsound:" + sample);
  }

  function afterTransition(fn) {
    window.setTimeout(fn, transitionMs);
  }

  function setTitleHidden(hidden) {
    titleChrome.classList.toggle("is-hidden", hidden);
    titleChrome.setAttribute("aria-hidden", hidden ? "true" : "false");
  }

  function setDialogAvailable(available) {
    joinDialog.classList.toggle("is-hidden", !available);
    joinDialog.setAttribute("aria-hidden", available ? "false" : "true");
  }

  function focusJoinField() {
    var el = document.getElementById("join-addr");
    if (!el || el.offsetParent === null || typeof el.focus !== "function") return;
    el.focus();
    if (typeof el.select === "function") el.select();
  }
  function setFocusY(index) {
    focusBar.style.setProperty("--focus-y", "calc(100% * " + ITEM_Y[index] + " / " + REF_H + ")");
  }

  function select(index, playNav) {
    if (index < 0) index = 0;
    if (index >= items.length) index = items.length - 1;
    if (index === selected) {
      setFocusY(selected);
      return;
    }
    selected = index;
    stage.setAttribute("data-selected", String(selected));
    items.forEach(function (el, i) {
      var on = i === selected;
      el.classList.toggle("is-selected", on);
      el.setAttribute("aria-selected", on ? "true" : "false");
    });
    setFocusY(selected);
    if (playNav !== false) localsound(SND_NAV);
  }

  function openJoin(create) {
    document.getElementById("join-title").textContent = create ? "Create Lobby" : "Join Lobby";
    document.getElementById("create-options").style.display = create ? "block" : "none";
    Array.prototype.forEach.call(joinDialog.querySelectorAll(".join-lan, .join-addr, .join-code"), function (el) {
      el.style.display = create ? "none" : "";
    });
    if (transitioning || joinOpen) return;
    transitioning = true;
    joinOpen = true;
    selectedAddr = null;
    joinConnect.disabled = true;
    if (!create) refreshLan();
    setTitleHidden(true);
    afterTransition(function () {
      joinDialog.classList.remove("hidden");
      joinDialog.offsetWidth;
      setDialogAvailable(true);
      if (!create) window.setTimeout(focusJoinField, 0);
      afterTransition(function () { transitioning = false; });
    });
  }

  function closeJoin(playBack) {
    if (transitioning || !joinOpen) return;
    transitioning = true;
    if (playBack !== false) localsound(SND_BACK);
    setDialogAvailable(false);
    afterTransition(function () {
      joinDialog.classList.add("hidden");
      joinOpen = false;
      setTitleHidden(false);
      afterTransition(function () { transitioning = false; });
    });
  }

  function leaveTitle(cmd) {
    if (transitioning || !cmd) return;
    transitioning = true;
    localsound(SND_OK);
    setTitleHidden(true);
    cbuf(cmd);
    if (cmd === "menu_options") {
      afterTransition(function () {
        setTitleHidden(false);
        transitioning = false;
      });
    }
  }

  function escapeHtml(s) {
    return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;");
  }

  function renderLan(rows) {
    var html = "";
    var i, r, shown = 0;
    for (i = 0; i < rows.length; i++) {
      r = rows[i];
      if (!r || !r.addr) continue;
      if (r.lobby === false && rows.some(function (x) { return x && x.lobby; }))
        continue;
      html += "<li data-addr=\"" + escapeHtml(r.addr) + "\">" +
        escapeHtml(r.name || r.addr) +
        " <span style=\"color:#888\">" + escapeHtml(r.map || "") +
        " · " + (r.players || 0) + "/" + (r.max || 0) +
        (r.lobby ? " · LOBBY" : "") + "</span></li>";
      shown++;
    }
    joinList.innerHTML = shown
      ? html
      : "<li class=\"is-empty\">No LAN lobbies found — try Address join (127.0.0.1:27501)</li>";
    selectedAddr = null;
    joinConnect.disabled = true;
  }

  function refreshLan() {
    q("hostcache_refresh");
    var raw = q("gethostcache");
    var rows = [];
    try { rows = JSON.parse(raw || "[]"); } catch (e) { rows = []; }
    if (!Array.isArray(rows)) rows = [];
    renderLan(rows);
  }

  function joinAddr(addr) {
    if (!addr || transitioning || !joinOpen) return;
    transitioning = true;
    if (q("lobby_join:" + addr) !== "ok") {
      transitioning = false;
      return;
    }
    localsound(SND_OK);
    setDialogAvailable(false);
    cbuf("menu_webcore_lobby");
  }

  function joinCode() {
    var el = document.getElementById("join-code");
    var code = el && el.value ? el.value.replace(/\s+/g, "") : "";
    if (!code) return;
    joinAddr(code);
  }

  function joinSelected() {
    if (!selectedAddr) return;
    joinAddr(selectedAddr);
  }

  function activate() {
    var el = items[selected];
    if (!el || transitioning || joinOpen) return;
    if (el.getAttribute("data-action") === "create-lobby") {
      openJoin(true);
      return;
    }
    if (el.getAttribute("data-action") === "join-lobby") {
      localsound(SND_OK);
      openJoin();
      return;
    }
    leaveTitle(el.getAttribute("data-cmd"));
  }

  items.forEach(function (el, i) {
    el.addEventListener("mouseenter", function () { if (!joinOpen && !transitioning) select(i); });
    el.addEventListener("click", function () {
      if (transitioning || joinOpen) return;
      select(i, false);
      activate();
    });
  });

  joinList.addEventListener("click", function (e) {
    if (transitioning || !joinOpen) return;
    var li = e.target;
    while (li && li !== joinList && li.tagName !== "LI") li = li.parentNode;
    if (!li || !li.getAttribute("data-addr")) return;
    selectedAddr = li.getAttribute("data-addr");
    Array.prototype.forEach.call(joinList.querySelectorAll("li"), function (n) {
      n.classList.toggle("is-selected", n === li);
    });
    joinConnect.disabled = false;
    localsound(SND_NAV);
  });

  function createLobby(online) {
    if (cbuf(online ? "lobby_create_online" : "lobby_create_lan")) {
      cbuf("menu_webcore_lobby");
    }
  }
  document.getElementById("create-online").addEventListener("click", function () { createLobby(true); });
  document.getElementById("create-lan").addEventListener("click", function () { createLobby(false); });

  document.getElementById("join-refresh").addEventListener("click", function () {
    if (!transitioning && joinOpen) refreshLan();
  });
  joinConnect.addEventListener("click", joinSelected);
  document.getElementById("join-addr-go").addEventListener("click", function () {
    var el = document.getElementById("join-addr");
    joinAddr(el && el.value ? el.value.replace(/\s+/g, "") : "");
  });
  document.getElementById("join-code-go").addEventListener("click", joinCode);
  document.getElementById("join-code").addEventListener("keydown", function (e) {
    if (e.key === "Enter") {
      if (!transitioning && joinOpen) joinCode();
      e.preventDefault();
    }
  });
  Array.prototype.forEach.call(document.querySelectorAll("[data-join-close]"), function (el) {
    el.addEventListener("click", closeJoin);
  });

  document.addEventListener("keydown", function (e) {
    var key = e.key;
    if (transitioning) {
      if (key === "Enter" || key === " " || key === "Escape" || key.indexOf("Arrow") === 0) e.preventDefault();
      return;
    }
    if (joinOpen) {
      if (key === "Escape") { closeJoin(); e.preventDefault(); }
      return;
    }
    if (key === "ArrowUp" || key === "w" || key === "W") {
      select(selected - 1);
      e.preventDefault();
    } else if (key === "ArrowDown" || key === "s" || key === "S") {
      select(selected + 1);
      e.preventDefault();
    } else if (key === "Enter" || key === " ") {
      activate();
      e.preventDefault();
    }
  });

  document.addEventListener("wheel", function (e) {
    if (joinOpen || transitioning) return;
    if (e.deltaY > 0) select(selected + 1);
    else if (e.deltaY < 0) select(selected - 1);
  }, { passive: true });

  select(0, false);
  window.setTimeout(function () {
    setTitleHidden(false);
    afterTransition(function () { transitioning = false; });
  }, 0);
})();
