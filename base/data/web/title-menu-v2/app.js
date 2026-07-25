/* Title menu v2 — Figma flash-pixel look (node 127:66). Same cmds as v1. */
(function () {
  /* Focus bar tops: CREATE 529, JOIN 553, SETTINGS 577, QUIT 600 (24px rows). */
  var ITEM_Y = [529, 553, 577, 600];
  var REF_H = 768;
  /* Classic Quake menu chrome via FTE localsound (stem; engine picks .wav/.ogg/…). */
  var SND_NAV = "misc/menu1";
  var SND_OK = "misc/menu2";
  var SND_BACK = "misc/menu3";

  var stage = document.getElementById("stage");
  var focusBar = document.getElementById("focus-bar");
  var items = Array.prototype.slice.call(document.querySelectorAll(".menu-item"));
  var selected = 0;
  var joinDialog = document.getElementById("join-dialog");
  var joinList = document.getElementById("join-list");
  var joinConnect = document.getElementById("join-connect");
  var selectedAddr = null;
  var joinOpen = false;

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

  function openJoin() {
    joinOpen = true;
    joinDialog.classList.remove("hidden");
    joinDialog.setAttribute("aria-hidden", "false");
    selectedAddr = null;
    joinConnect.disabled = true;
    refreshLan();
  }

  function closeJoin(playBack) {
    if (!joinOpen) return;
    joinOpen = false;
    joinDialog.classList.add("hidden");
    joinDialog.setAttribute("aria-hidden", "true");
    if (playBack !== false) localsound(SND_BACK);
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
    if (!addr) return;
    if (q("lobby_join:" + addr) === "ok") {
      localsound(SND_OK);
      closeJoin(false);
      cbuf("menu_webcore_lobby");
    }
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
    if (!el) return;
    localsound(SND_OK);
    if (el.getAttribute("data-action") === "join-lobby") {
      openJoin();
      return;
    }
    cbuf(el.getAttribute("data-cmd"));
  }

  items.forEach(function (el, i) {
    el.addEventListener("mouseenter", function () { if (!joinOpen) select(i); });
    el.addEventListener("click", function () {
      select(i, false);
      activate();
    });
  });

  joinList.addEventListener("click", function (e) {
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

  document.getElementById("join-refresh").addEventListener("click", refreshLan);
  joinConnect.addEventListener("click", joinSelected);
  document.getElementById("join-addr-go").addEventListener("click", function () {
    var el = document.getElementById("join-addr");
    joinAddr(el && el.value ? el.value.replace(/\s+/g, "") : "");
  });
  document.getElementById("join-code-go").addEventListener("click", joinCode);
  document.getElementById("join-code").addEventListener("keydown", function (e) {
    if (e.key === "Enter") { joinCode(); e.preventDefault(); }
  });
  Array.prototype.forEach.call(document.querySelectorAll("[data-join-close]"), function (el) {
    el.addEventListener("click", closeJoin);
  });

  document.addEventListener("keydown", function (e) {
    var key = e.key;
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
    if (joinOpen) return;
    if (e.deltaY > 0) select(selected + 1);
    else if (e.deltaY < 0) select(selected - 1);
  }, { passive: true });

  select(0, false);
})();
