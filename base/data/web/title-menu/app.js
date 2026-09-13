/* Title menu — Create Lobby / Join Lobby (WebCore). */
(function () {
  var ITEM_Y = [443, 483, 514, 545];
  var FOCUS_OFFSET = 3;
  var REF_H = 768;

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

  function focusJoinField() {
    var el = document.getElementById("join-addr");
    if (!el || el.offsetParent === null || typeof el.focus !== "function") return;
    el.focus();
    if (typeof el.select === "function") el.select();
  }

  function setFocusY(index) {
    var y = ITEM_Y[index] - FOCUS_OFFSET;
    focusBar.style.setProperty("--focus-y", "calc(100% * " + y + " / " + REF_H + ")");
  }

  function select(index) {
    if (index < 0) index = 0;
    if (index >= items.length) index = items.length - 1;
    selected = index;
    stage.setAttribute("data-selected", String(selected));
    items.forEach(function (el, i) {
      var on = i === selected;
      el.classList.toggle("is-selected", on);
      el.setAttribute("aria-selected", on ? "true" : "false");
    });
    setFocusY(selected);
  }

  function openJoin(create) {
    document.getElementById("join-title").textContent = create ? "Create Lobby" : "Join Lobby";
    document.getElementById("create-options").style.display = create ? "block" : "none";
    Array.prototype.forEach.call(joinDialog.querySelectorAll(".join-lan, .join-addr, .join-code"), function (el) {
      el.style.display = create ? "none" : "";
    });
    joinOpen = true;
    joinDialog.classList.remove("hidden");
    joinDialog.setAttribute("aria-hidden", "false");
    selectedAddr = null;
    joinConnect.disabled = true;
    if (!create) refreshLan();
    if (!create) window.setTimeout(focusJoinField, 0);
  }

  function closeJoin() {
    joinOpen = false;
    joinDialog.classList.add("hidden");
    joinDialog.setAttribute("aria-hidden", "true");
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
      /* Prefer lobby-flagged; still show others if none are flagged. */
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
    /* Engine QueryServers now probes 127.0.0.1:lobby_port and waits briefly. */
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
      closeJoin();
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
    if (el.getAttribute("data-action") === "create-lobby") {
      openJoin(true);
      return;
    }
    if (el.getAttribute("data-action") === "join-lobby") {
      openJoin();
      return;
    }
    cbuf(el.getAttribute("data-cmd"));
  }

  items.forEach(function (el, i) {
    el.addEventListener("mouseenter", function () { if (!joinOpen) select(i); });
    el.addEventListener("click", function () {
      select(i);
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
  });

  function createLobby(online) {
    if (cbuf(online ? "lobby_create_online" : "lobby_create_lan")) {
      cbuf("menu_webcore_lobby");
    }
  }
  document.getElementById("create-online").addEventListener("click", function () { createLobby(true); });
  document.getElementById("create-lan").addEventListener("click", function () { createLobby(false); });

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

  select(0);
})();
