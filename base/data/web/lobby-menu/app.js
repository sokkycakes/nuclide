(function () {
  var POLL_MS = 250;
  var lastRevision = -1;
  var snapshotClock = { serverTime: 0, receivedAt: 0 };
  var lastPlayersKey = "";
  var currentSnapshot = null;
  var actionStatus = "";
  var leaveConfirmOpen = false;
  var focusedControl = null;

  var leaderEl = document.getElementById("LblLeaderLine");
  var posterEl = document.getElementById("ImgLevelImage");
  var line0 = document.getElementById("LblSummaryLine0");
  var line1 = document.getElementById("LblSummaryLine1");
  var line2 = document.getElementById("LblSummaryLine2");
  var accessEl = document.getElementById("LblGameAccess");
  var countdownEl = document.getElementById("CountdownLine");
  var statusEl = document.getElementById("StatusLine");
  var playersEl = document.getElementById("PlayersList");
  var workingEl = document.getElementById("WorkingAnim");
  var btnStart = document.getElementById("BtnStartGame");
  var btnReady = document.getElementById("BtnReady");
  var btnCancel = document.getElementById("BtnCancel");
  var btnLeave = document.getElementById("BtnLeaveLobby");
  var btnMap = document.getElementById("BtnChangeMap");
  var footerX = document.getElementById("footer-x");
  var footerA = document.getElementById("footer-a");
  var footerB = document.getElementById("footer-b");
  var lobbyView = document.getElementById("view-gamelobby");
  var settingsView = document.getElementById("view-settings");
  var leaveConfirm = document.getElementById("LeaveConfirm");
  var btnSettingsBack = document.getElementById("BtnSettingsBack");
  var btnConfirmLeave = document.getElementById("BtnConfirmLeave");
  var btnCancelLeave = document.getElementById("BtnCancelLeave");
  var btnLeaveBackdrop = document.getElementById("LeaveConfirmBackdrop");
  var mapChoices = Array.prototype.slice.call(document.querySelectorAll(".map-choice"));
  var baseMod = window.WebCoreBaseMod;
  var controller;

  function q(req) {
    if (typeof window.fte_query !== "function") return null;
    try { return window.fte_query(req); } catch (e) { return null; }
  }

  function cbuf(cmd) {
    return q("cbuf:" + cmd) === "ok";
  }

  function lobbyAction(action) {
    var via = q("lobby_action:" + action);
    if (via === "ok" || via === "{\"ok\":true}") return true;
    if (via) {
      try { return !!JSON.parse(via).ok; } catch (e) { /* not JSON */ }
    }
    return false;
  }

  function announce(text) {
    actionStatus = text || "";
    setText(statusEl, actionStatus);
  }

  function runAction(action, successText) {
    if (!lobbyAction(action)) {
      announce("Lobby action was rejected.");
      return false;
    }
    announce(successText || "Updating lobby…");
    setTimeout(refresh, 0);
    return true;
  }

  function setText(el, text) {
    var next = text == null ? "" : String(text);
    if (el.textContent !== next) el.textContent = next;
  }

  function clearNode(node) {
    while (node.firstChild) node.removeChild(node.firstChild);
  }

  function textEl(tag, text, className) {
    var el = document.createElement(tag);
    if (className) el.className = className;
    el.textContent = text == null ? "" : String(text);
    return el;
  }

  function parseReadyName(name) {
    var raw = String(name || "");
    if (raw.indexOf("[READY]") === 0) {
      return { name: raw.slice(7).replace(/^\s+/, ""), ready: true };
    }
    return { name: raw, ready: false };
  }

  function normalizeLegacy(data) {
    var names = Array.isArray(data.players) ? data.players : [];
    var players = [];
    var i, parsed, hostName = data.host || "";
    for (i = 0; i < names.length; i++) {
      if (!names[i]) continue;
      parsed = parseReadyName(names[i]);
      players.push({
        seat: players.length,
        name: parsed.name,
        host: parsed.name === hostName || (players.length === 0 && !!hostName),
        ready: parsed.ready,
        connected: true
      });
    }
    return {
      active: !!data.active,
      revision: data.revision != null ? data.revision : 0,
      isHost: !!data.isHost,
      localSeat: data.localSeat != null ? data.localSeat : -1,
      phase: data.phase || "",
      status: data.status || data.state || "",
      error: data.error || "",
      map: data.map || "",
      countdownEnd: data.countdownEnd || 0,
      serverTime: data.serverTime || 0,
      canReady: data.canReady != null ? !!data.canReady : !!data.active,
      canStart: data.canStart != null ? !!data.canStart : false,
      canCancel: data.canCancel != null ? !!data.canCancel : false,
      canChangeMap: data.canChangeMap != null ? !!data.canChangeMap : false,
      canLeave: data.canLeave != null ? !!data.canLeave : !!data.active,
      players: players,
      room: data.room || "",
      count: data.count || players.length,
      max: data.max || 0,
      transport: data.transport || data.network || ""
    };
  }

  function normalizeSnapshot(data) {
    if (!data || typeof data !== "object") return null;
    if (Array.isArray(data.players) && data.players.length &&
        typeof data.players[0] === "object" && data.players[0] != null) {
      return {
        active: !!data.active,
        revision: data.revision != null ? data.revision : 0,
        isHost: !!data.isHost,
        localSeat: data.localSeat != null ? data.localSeat : -1,
        phase: data.phase || "",
        status: data.status || "",
        error: data.error || "",
        map: data.map || "",
        countdownEnd: data.countdownEnd || 0,
        serverTime: data.serverTime || 0,
        canReady: !!data.canReady,
        canStart: !!data.canStart,
        canCancel: !!data.canCancel,
        canChangeMap: !!data.canChangeMap,
        canLeave: data.canLeave !== false,
        players: data.players,
        room: data.roomCode || data.room || "",
        count: data.players.length,
        max: data.max || 0,
        transport: data.transport || data.network || ""
      };
    }
    return normalizeLegacy(data);
  }

  function setButton(btn, enabled, selected) {
    if (!btn) return;
    btn.disabled = !enabled;
    btn.classList.toggle("is-disabled", !enabled);
    btn.classList.toggle("active", !!selected);
  }

  function formatCountdown(snapshot) {
    if (!snapshot.countdownEnd) return "";
    var base = snapshotClock.serverTime;
    var elapsed = base > 0 ? (Date.now() - snapshotClock.receivedAt) / 1000 : 0;
    var now = base > 0 ? base + elapsed : 0;
    var remain = Math.max(0, Math.ceil(snapshot.countdownEnd - now));
    if (!remain && snapshot.phase !== "COUNTDOWN") return "";
    return remain > 0 ? "Starting in " + remain + "…" : "Starting…";
  }

  function hostName(players) {
    var i, p;
    for (i = 0; i < players.length; i++) {
      p = players[i];
      if (p && p.host) return p.name || "Host";
    }
    return players[0] && players[0].name ? players[0].name : "—";
  }

  function accessLabel(snapshot) {
    var t = String(snapshot.transport || "").toLowerCase();
    if (t.indexOf("ice") >= 0 || t.indexOf("online") >= 0) {
      return snapshot.room ? ("Online · " + snapshot.room) : "Online";
    }
    if (t.indexOf("lan") >= 0 || t.indexOf("udp") >= 0) return "LAN";
    if (snapshot.room) return "Online · " + snapshot.room;
    return "LAN / Local";
  }

  function playersKey(players, localSeat) {
    var parts = [String(localSeat)];
    var i, p;
    for (i = 0; i < players.length; i++) {
      p = players[i] || {};
      parts.push([
        p.seat, p.name || "", p.host ? 1 : 0, p.ready ? 1 : 0,
        p.connected === false ? 0 : 1
      ].join(":"));
    }
    return parts.join("|");
  }

  function renderPlayers(players, localSeat) {
    var key = playersKey(players, localSeat);
    if (key === lastPlayersKey) return;
    lastPlayersKey = key;

    clearNode(playersEl);
    if (!players.length) {
      playersEl.appendChild(textEl("div", "Waiting for players…", "player-slot is-empty"));
      return;
    }
    players.forEach(function (p) {
      var slot = document.createElement("div");
      slot.className = "player-slot";
      if (p.seat === localSeat) slot.className += " focused";
      slot.appendChild(textEl("div", p.name || "Player", "slot-name"));

      var meta = document.createElement("div");
      meta.className = "slot-meta";
      if (p.host) {
        meta.appendChild(textEl("span", "HOST", "tag-host"));
        if (p.ready || p.connected === false) meta.appendChild(document.createTextNode(" · "));
      }
      if (p.ready) {
        meta.appendChild(textEl("span", "READY", "tag-ready"));
        if (p.connected === false) meta.appendChild(document.createTextNode(" · "));
      }
      if (p.connected === false) meta.appendChild(document.createTextNode("…"));
      if (!p.host && !p.ready && p.connected !== false)
        meta.textContent = "Seat " + (p.seat != null ? p.seat : "?");
      slot.appendChild(meta);
      playersEl.appendChild(slot);
    });
  }

  function render(snapshot) {
    var phase = (snapshot.phase || "").toUpperCase();
    var map = snapshot.map || "—";
    var countdown = formatCountdown(snapshot);
    var players = snapshot.players || [];
    var leader = hostName(players);
    var count = snapshot.count || players.length;
    var max = snapshot.max || 0;

    setText(leaderEl, "Leader: " + leader);
    setText(posterEl, map);
    setText(line0, "Map — " + map);
    setText(line1, "Players — " + count + (max ? (" / " + max) : ""));
    setText(line2, "Phase — " + (phase || snapshot.status || "WAITING"));
    setText(accessEl, accessLabel(snapshot));

    if (countdown || phase === "COUNTDOWN") {
      setText(countdownEl, countdown || snapshot.status || "Countdown…");
      countdownEl.classList.remove("hidden");
    } else {
      setText(countdownEl, "");
      countdownEl.classList.add("hidden");
    }

    currentSnapshot = snapshot;
    setText(statusEl, snapshot.error || actionStatus || snapshot.status || "");
    workingEl.classList.toggle("hidden", phase !== "JOINING" && phase !== "CLOSING" && phase !== "STARTING");

    renderPlayers(players, snapshot.localSeat);

    var local = null;
    players.some(function (p) {
      if (p.seat === snapshot.localSeat) { local = p; return true; }
      return false;
    });

    setButton(btnReady, snapshot.canReady, local && local.ready);
    setText(btnReady, local && local.ready ? "Unready" : "Ready");

    setButton(btnStart, snapshot.isHost, false);
    btnStart.classList.toggle("hidden", !snapshot.isHost);

    setButton(btnCancel, snapshot.canCancel, false);
    btnCancel.classList.toggle("hidden", !snapshot.isHost || !snapshot.canCancel);

    setButton(btnMap, snapshot.canChangeMap && snapshot.isHost, false);
    if (btnMap) btnMap.classList.toggle("hidden", !(snapshot.isHost && snapshot.canChangeMap));

    mapChoices.forEach(function (choice) {
      var selected = choice.getAttribute("data-map") === map;
      choice.disabled = !(snapshot.isHost && snapshot.canChangeMap);
      choice.setAttribute("aria-selected", selected ? "true" : "false");
    });

    setButton(btnLeave, true, false);
    footerX.classList.toggle("hidden", !snapshot.isHost);
    syncFooter();
    if (!focusedControl || !isVisibleControl(focusedControl)) deferFocus(focusControls()[0]);
  }

  function refresh() {
    var raw = q("getlobby");
    if (!raw) return;
    var data;
    try { data = JSON.parse(raw); } catch (e) {
      setText(statusEl, "Lobby snapshot parse error");
      return;
    }
    var snapshot = normalizeSnapshot(data);
    if (!snapshot) return;
    snapshotClock.serverTime = snapshot.serverTime || 0;
    snapshotClock.receivedAt = Date.now();
    if (snapshot.revision !== lastRevision) {
      lastRevision = snapshot.revision;
      actionStatus = "";
    }
    render(snapshot);
  }

  function setHidden(el, hidden) {
    if (!el) return;
    el.classList.toggle("hidden", !!hidden);
    el.setAttribute("aria-hidden", hidden ? "true" : "false");
  }

  function isVisibleControl(el) {
    var node = el;
    while (node && node !== document.body) {
      if (node.classList && node.classList.contains("hidden")) return false;
      node = node.parentNode;
    }
    return !!el && !el.disabled;
  }

  function focusControls() {
    var root = controller && controller.activeView() === "settings" ? settingsView : lobbyView;
    return Array.prototype.slice.call(root.querySelectorAll(".hybrid-btn"))
      .filter(isVisibleControl);
  }

  function setFocusedControl(el) {
    if (!el || !isVisibleControl(el)) return;
    Array.prototype.forEach.call(document.querySelectorAll(".hybrid-btn.is-focused"), function (item) {
      item.classList.remove("is-focused");
    });
    focusedControl = el;
    el.classList.add("is-focused");
    if (typeof el.focus === "function") el.focus();
  }

  function deferFocus(el) {
    setTimeout(function () { setFocusedControl(el); }, 0);
  }

  function moveFocus(delta) {
    var controls = focusControls();
    var index;
    if (!controls.length) return false;
    index = controls.indexOf(focusedControl);
    index = (index + delta + controls.length) % controls.length;
    setFocusedControl(controls[index]);
    return true;
  }

  function syncFooter() {
    if (leaveConfirmOpen) {
      setText(footerA, "Leave");
      setText(footerB, "Stay");
    } else if (controller && controller.activeView() === "settings") {
      setText(footerA, "Select");
      setText(footerB, "Back");
    } else {
      setText(footerA, "Select");
      setText(footerB, "Leave");
    }
  }

  function showView(view) {
    setHidden(lobbyView, view !== "lobby");
    setHidden(settingsView, view !== "settings");
    syncFooter();
  }

  function openLeaveConfirm() {
    leaveConfirmOpen = true;
    setHidden(leaveConfirm, false);
    syncFooter();
    setFocusedControl(btnCancelLeave);
  }

  function closeLeaveConfirm() {
    leaveConfirmOpen = false;
    setHidden(leaveConfirm, true);
    syncFooter();
    setFocusedControl(btnLeave);
  }

  function leaveLobby() {
    if (!runAction("close", "Leaving lobby…")) return;
    if (!cbuf("menu_webcore_title")) cbuf("menu_webcore");
  }

  function openSettings() {
    if (!currentSnapshot || !currentSnapshot.isHost || !currentSnapshot.canChangeMap) return;
    if (controller.openView("settings", btnMap)) {
      deferFocus(mapChoices.filter(isVisibleControl)[0] || btnSettingsBack);
    }
  }

  function chooseMap(choice) {
    var map = choice.getAttribute("data-map");
    if (!map || !currentSnapshot || !currentSnapshot.canChangeMap) return;
    if (runAction("setmap:" + map, "Changing map…")) controller.returnToLobby();
  }

  if (!baseMod || !baseMod.createBaseModController)
    throw new Error("BaseMod interaction controller failed to load");
  controller = baseMod.createBaseModController({
    onFocus: setFocusedControl,
    onViewChange: function (view) { showView(view); },
    onCancel: openLeaveConfirm
  });

  btnReady.addEventListener("click", function () {
    var local = currentSnapshot && (currentSnapshot.players || []).filter(function (p) {
      return p.seat === currentSnapshot.localSeat;
    })[0];
    runAction(local && local.ready ? "unready" : "ready", local && local.ready ? "Not ready." : "Ready.");
  });
  btnStart.addEventListener("click", function () { runAction("start", "Starting lobby…"); });
  btnCancel.addEventListener("click", function () { runAction("cancel", "Countdown cancelled."); });
  btnLeave.addEventListener("click", openLeaveConfirm);
  btnMap.addEventListener("click", openSettings);
  btnSettingsBack.addEventListener("click", function () { controller.returnToLobby(); });
  btnConfirmLeave.addEventListener("click", leaveLobby);
  btnCancelLeave.addEventListener("click", closeLeaveConfirm);
  btnLeaveBackdrop.addEventListener("click", closeLeaveConfirm);

  mapChoices.forEach(function (choice) {
    choice.addEventListener("click", function () { chooseMap(choice); });
  });
  Array.prototype.forEach.call(document.querySelectorAll(".hybrid-btn"), function (btn) {
    btn.addEventListener("mouseenter", function () { setFocusedControl(btn); });
  });

  document.addEventListener("keydown", function (e) {
    var key = e.key;
    if (key === "Escape") {
      if (leaveConfirmOpen) closeLeaveConfirm();
      else controller.cancel();
      e.preventDefault();
      return;
    }
    if (leaveConfirmOpen) {
      if (key === "Enter" || key === " ") leaveLobby();
      e.preventDefault();
      return;
    }
    if (key === "ArrowUp" || key === "ArrowLeft" || key === "w" || key === "W") {
      moveFocus(-1);
      e.preventDefault();
    } else if (key === "ArrowDown" || key === "ArrowRight" || key === "s" || key === "S" || key === "Tab") {
      moveFocus(1);
      e.preventDefault();
    } else if (key === "Enter" || key === " " || key === "Spacebar") {
      if (focusedControl && isVisibleControl(focusedControl)) focusedControl.click();
      e.preventDefault();
    }
  });

  Array.prototype.forEach.call(document.querySelectorAll(".click-shield"), function (shield) {
    function eat(e) { e.preventDefault(); e.stopPropagation(); }
    shield.addEventListener("mousedown", eat);
    shield.addEventListener("mouseup", eat);
    shield.addEventListener("click", eat);
  });

  setInterval(refresh, POLL_MS);
  refresh();
})();
