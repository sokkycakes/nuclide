/* Live HUD via fte_query("gethud") ΓÇö mirrors cl_slint_hud.c SyncProperties. */

(function () {
  var AMMO_PIPS = [
    [737.28, 583.94, 28.72],
    [757.16, 574.09, 28.72],
    [740.07, 563.59, 28.72],
    [758.75, 552.12, 28.72],
    [778.63, 542.07, 28.72],
    [761.35, 531.76, 28.72]
  ];
  var CHARGE_PIPS = [
    [681.63, 566.63, 17.37],
    [667.69, 555.32, 17.37],
    [666, 540, 17.37]
  ];
  var LEFT_ABILITY = [[592.99, 143.64], [621, 143.64], [648, 143.64]];
  var RIGHT_ABILITY = [[772, 143.64], [800, 143.64], [827, 143.64]];
  var LEFT_DRIVE = [480, 520, 560, 600, 640];
  var RIGHT_DRIVE = [775, 815, 855, 895, 935];

  function pct(x, axis) {
    return "calc(100% * " + x + " / " + (axis === "y" ? 1080 : 1440) + ")";
  }

  function makePips(hostId, positions, sizeFixed) {
    var host = document.getElementById(hostId);
    if (!host) return [];
    host.innerHTML = "";
    var els = [];
    for (var i = 0; i < positions.length; i++) {
      var p = positions[i];
      var el = document.createElement("div");
      el.className = "pip";
      el.style.left = pct(p[0], "x");
      el.style.top = pct(p[1], "y");
      var sz = sizeFixed || p[2] || 26;
      el.style.width = pct(sz, "x");
      el.style.height = pct(sz, "x");
      host.appendChild(el);
      els.push(el);
    }
    return els;
  }

  function makeDrive(hostId, xs) {
    var host = document.getElementById(hostId);
    if (!host) return;
    host.innerHTML = "";
    for (var i = 0; i < xs.length; i++) {
      var el = document.createElement("div");
      el.className = "drive-pip";
      el.style.left = pct(xs[i], "x");
      el.style.top = pct(147.64, "y");
      el.style.width = pct(34, "x");
      el.style.height = pct(8, "y");
      host.appendChild(el);
    }
  }

  var ammoPips = makePips("pips-ammo", AMMO_PIPS);
  var chargePips = makePips("pips-charges", CHARGE_PIPS);
  makePips("pips-left-ability", LEFT_ABILITY.map(function (p) {
    return [p[0], p[1], 26];
  }));
  makePips("pips-right-ability", RIGHT_ABILITY.map(function (p) {
    return [p[0], p[1], 26];
  }));
  makeDrive("drive-left", LEFT_DRIVE);
  makeDrive("drive-right", RIGHT_DRIVE);

  function setFilled(els, n) {
    for (var i = 0; i < els.length; i++) {
      if (i < n) els[i].classList.remove("is-empty");
      else els[i].classList.add("is-empty");
    }
  }

  function setText(id, value) {
    var el = document.getElementById(id);
    if (el && el.textContent !== String(value)) el.textContent = String(value);
  }

  function setHp(health) {
    var dead = health <= 0;
    var low = health > 0 && health <= 25;
    var full = health > 25;
    var el;
    el = document.getElementById("hp-full");
    if (el) el.classList.toggle("is-hidden", !full);
    el = document.getElementById("hp-low");
    if (el) el.classList.toggle("is-hidden", !low);
    el = document.getElementById("hp-dead");
    if (el) el.classList.toggle("is-hidden", !dead);
  }

  function pad3(n) {
    n = Math.max(0, Math.floor(n));
    if (n > 999) n = 999;
    var s = String(n);
    while (s.length < 3) s = "0" + s;
    return s;
  }

  function queryHud() {
    if (typeof fte_query !== "function") return null;
    try {
      var raw = fte_query("gethud");
      if (!raw) {
        raw = fte_query("getstats");
        if (!raw) return null;
        var stats = JSON.parse(raw);
        return {
          health: typeof stats[0] === "number" ? stats[0] : 100,
          ammo: typeof stats[3] === "number" ? stats[3] : 0,
          charges: 3,
          timer: "00:00",
          speed: 0
        };
      }
      return JSON.parse(raw);
    } catch (e) {
      return null;
    }
  }

  function cvarNum(name, fallback) {
    if (typeof fte_query !== "function") return fallback;
    try {
      var raw = fte_query("cvar:" + name);
      if (raw === "" || raw == null) raw = fte_query("get_cvar " + name);
      var n = parseFloat(raw);
      return isNaN(n) ? fallback : n;
    } catch (e) {
      return fallback;
    }
  }

  function refresh() {
    var data = queryHud();
    var health = 100;
    var ammo = 0;
    var charges = 3;
    var drive = cvarNum("webcore_hud_drive", -1);
    var driveMax = Math.max(1, cvarNum("webcore_hud_drive_max", 1000));
    var ex = cvarNum("webcore_hud_ex", -1);
    var guard = cvarNum("webcore_hud_guard", 0) > 0;

    if (data) {
      if (typeof data.health === "number") health = data.health;
      if (typeof data.ammo === "number") ammo = data.ammo;
      if (typeof data.charges === "number") charges = data.charges;
      if (data.timer) setText("timer", data.timer);
      if (typeof data.speed === "number") setText("speedo", pad3(data.speed));
      if (data.scoreLeft != null) setText("score-left", data.scoreLeft);
      if (data.scoreRight != null) setText("score-right", data.scoreRight);
      if (data.exLevel != null) setText("ex-level", data.exLevel);
      if (data.reload != null) setText("reload", data.reload);
      if (data.player1 != null) setText("player1-name", data.player1);
      if (data.player2 != null) setText("player2-name", data.player2);
    }

    /* Authoritative Groove meters from CSQC-published cvars when present. */
    if (ex >= 0) setText("ex-level", Math.round(ex));
    if (drive >= 0) {
      var drivePips = Math.round((drive / driveMax) * 5);
      setFilled(document.querySelectorAll("#drive-left .drive-pip"), drivePips);
      setFilled(document.querySelectorAll("#drive-right .drive-pip"), drivePips);
    }

    var stage = document.getElementById("stage");
    if (stage) stage.classList.toggle("is-guarding", guard);

    setHp(health);
    setFilled(ammoPips, ammo);
    setFilled(chargePips, charges);
  }

  setInterval(refresh, 50);
  refresh();
})();
