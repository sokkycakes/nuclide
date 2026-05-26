/* =====================================================================
   Halo 3 main menu - logic layer.

   This file implements the engine-side behavior that lives outside the
   H3EK tags (input dispatch, list focus, online/offline state, screen
   navigation table). All data is pulled from data.json which is itself
   sourced from the exported tag XML in export_xml/ui/ui/halox/...

   Page model
   ----------
   The current state is reduced to:
     * `currentPage` - "main_menu" or "pregame_lobby"
     * `lobbyMode`   - one of "campaign", "matchmaking", "multiplayer",
                       "mapeditor", "theater" when on the lobby page
     * `activeList`  - the ListController whose rows receive input
   ===================================================================== */

(async function () {
  "use strict";

  const $  = (sel, ctx = document) => ctx.querySelector(sel);
  const $$ = (sel, ctx = document) => Array.from(ctx.querySelectorAll(sel));

  // ---------------------------------------------------------------------
  // ?slow URL param: scale every transition animation up so the 333 ms
  // hold + 333 ms motion phases are catchable in screenshots / debugging.
  // ?slow      -> 5x  (3330 ms)
  // ?slow=N    -> Nx  (666 * N ms)
  // Must run SYNCHRONOUSLY before any layout/paint kicks off the intro
  // animation, so the very first frame already uses the slowed duration.
  // ---------------------------------------------------------------------
  const slowParam  = new URLSearchParams(location.search).get("slow");
  const slowMo     = slowParam !== null;
  const slowFactor = slowMo ? (parseFloat(slowParam) || 5) : 1;
  const SLOW_MS    = Math.round(666 * slowFactor);
  if (slowMo) {
    const style = document.createElement("style");
    style.textContent = `
      .page--main-menu.is-entering,
      .page--main-menu.is-initial,
      .page--main-menu.is-leaving,
      .page--main-menu.is-entering .menu-panel,
      .page--main-menu.is-initial   .menu-panel,
      .page--main-menu.is-leaving   .menu-panel,
      .page--lobby.is-entering,
      .page--lobby.is-leaving,
      .page--lobby.is-entering .lobby-panel,
      .page--lobby.is-leaving  .lobby-panel,
      .delayd-fade-in { animation-duration: ${SLOW_MS}ms !important; }
    `;
    document.head.appendChild(style);
    console.warn(`[slowMo] factor=${slowFactor}x  duration=${SLOW_MS}ms`);
  }
  const TRANSITION_MS = SLOW_MS;

  // ---------------------------------------------------------------------
  // Load tag-derived data
  // ---------------------------------------------------------------------
  let data;
  try {
    const res = await fetch("data.json?t=" + Date.now());
    data = await res.json();
  } catch (err) {
    console.error("Failed to load data.json:", err);
    document.body.innerHTML =
      "<pre style='color:red;padding:2em'>Failed to load data.json. " +
      "Serve this folder over http (e.g. `python -m http.server`) — " +
      "file:// blocks fetch().</pre>";
    return;
  }

  // ---------------------------------------------------------------------
  // ListController: shared row-focus + ghost-trail state machine for
  // both the main menu list (split across header + body) and the lobby
  // list (single <ul>).
  //
  // Rows are built ONCE on construction and persisted. setFocus() only
  // toggles the --focused class on the right row; the previously-focused
  // row stays in the DOM so its CSS `transition: opacity 120ms linear`
  // can run to completion. That asymmetric transition (instant on,
  // 120ms off) is what produces the ElDewrito "ghost trail".
  // ---------------------------------------------------------------------
  function ListController(opts) {
    const {
      items,                         // [{ id, label, value?, disabled?, ... }]
      wraps,                         // bool
      itemClass,                     // CSS class for each <li>
      buildRowContent,               // (li, item) -> void; populate <li>
      mount,                         // (li, index) -> void; insert <li> into DOM
      clearMounts,                   // () -> void; clear all hosts before build
      onConfirm,                     // (item) -> void
    } = opts;

    const rowEls = [];
    let focus = 0;

    function makeRow(i) {
      const item = items[i];
      const li = document.createElement("li");
      li.className = itemClass;
      if (item.disabled) li.classList.add(itemClass + "--disabled");
      li.dataset.index = i;
      li.dataset.id    = item.id;
      li.setAttribute("role", "option");
      buildRowContent(li, item);

      li.addEventListener("click", () => {
        if (i === focus) confirm();
        else setFocus(i);
      });
      // Only update focus on real mouse movement, not first-page-load
      // hover; otherwise the cursor's resting position steals focus.
      li.addEventListener("mousemove", () => {
        if (focus !== i) setFocus(i);
      });
      return li;
    }

    function build() {
      clearMounts();
      rowEls.length = 0;
      for (let i = 0; i < items.length; i++) {
        const li = makeRow(i);
        rowEls[i] = li;
        mount(li, i);
      }
      applyFocus();
    }

    function applyFocus() {
      for (let i = 0; i < rowEls.length; i++) {
        rowEls[i].classList.toggle(itemClass + "--focused", i === focus);
      }
      $("#dbg-focus").textContent = `${focus} (${items[focus].id})`;
    }

    function setFocus(i) {
      if (focus === i) return;
      focus = i;
      applyFocus();
    }

    function moveFocus(delta) {
      let next;
      if (wraps) next = (focus + delta + items.length) % items.length;
      else       next = Math.max(0, Math.min(items.length - 1, focus + delta));
      setFocus(next);
    }

    function confirm() {
      const item = items[focus];
      if (item.disabled) {
        const row = rowEls[focus];
        if (row) {
          row.animate(
            [
              { transform: "translateX(0)" },
              { transform: "translateX(-6px)" },
              { transform: "translateX(6px)" },
              { transform: "translateX(0)" },
            ],
            { duration: 200, easing: "ease-out" }
          );
        }
        return;
      }
      onConfirm(item);
    }

    return {
      build, applyFocus, setFocus, moveFocus, confirm,
      reset() { focus = 0; applyFocus(); },
      get focus() { return focus; },
      get items() { return items; },
      get rowEls() { return rowEls; },
    };
  }

  // ---------------------------------------------------------------------
  // MAIN MENU list (items[0] -> #menu-primary header, items[1..] -> body)
  // The engine prunes rows by game state (RESUME SOLO GAME requires a save,
  // PLAY THE BETA was the Recon/ODST promo, QUIT TO XBOX DASHBOARD is Xbox-
  // only). We mirror that by filtering items with hidden_by_default = true.
  // ---------------------------------------------------------------------
  $("#title-logo").src       = data.right_group_chrome.title_bitmap;
  $("#bungie-logo").src      = data.right_group_chrome.bungie_bitmap;
  $("#build-text").textContent   = "build 12070.07.10.18.2128.delta";
  $("#version-text").textContent = "version 1.0";

  const primaryEl = $("#menu-primary");
  const mainListEl = $("#mainmenu-list");

  const mainList = ListController({
    items: data.list.items.filter((it) => !it.hidden_by_default),
    wraps: data.list.wraps,
    itemClass: "mainmenu-list__item",
    buildRowContent: (li, item) => { li.textContent = item.label; },
    mount: (li, i) => {
      if (i === 0) primaryEl.appendChild(li);
      else         mainListEl.appendChild(li);
    },
    clearMounts: () => {
      primaryEl.innerHTML  = "";
      mainListEl.innerHTML = "";
    },
    onConfirm: (item) => navigateTo(item.destination),
  });

  // ---------------------------------------------------------------------
  // PREGAME LOBBY list (shared template, populated per-mode on entry).
  // ---------------------------------------------------------------------
  const lobbyListEl  = $("#lobby-list");
  const lobbyTitleEl = $("#lobby-title");
  const lobbyStatusEl = $("#lobby-status");
  const lobbyGameNameEl = $("#lobby-game-name");
  const lobbyButtonKeysEl = $("#lobby-button-keys");
  const lobbyPreviewGametypeEl = $(".lobby-preview__gametype");
  const screenEl = $("#screen");
  const pageMain = $('.page[data-page="main_menu"]');
  const pageLobby = $('.page[data-page="pregame_lobby"]');

  let lobbyList = null;  // ListController instance, rebuilt on each enter
  let lobbyMode = null;  // active mode key

  function buildLobbyList(mode) {
    const cfg = data.pregame_lobbies.modes[mode];
    lobbyTitleEl.textContent      = cfg.title;
    lobbyStatusEl.textContent     = cfg.lobby_status;
    lobbyGameNameEl.textContent   = cfg.game_name;
    pageLobby.dataset.showPreview = String(!!cfg.show_preview);

    // Gametype label inside the preview = the value of whichever item
    // selects the level/variant/map/film/hopper for this mode. Skips
    // switch_lobby (no value) and select_network_mode (a global toggle).
    const previewTargets = ["level", "variant", "map", "film", "hopper"];
    const gameItem = cfg.items.find(it => previewTargets.includes(it.target));
    lobbyPreviewGametypeEl.textContent = (gameItem && gameItem.value) || cfg.title;

    lobbyList = ListController({
      items: cfg.items,
      wraps: true,
      itemClass: "lobby-list__item",
      // Retail H3 lobby renders rows as "LABEL: VALUE" inline on one line
      // ("HOST SETTINGS: OFFLINE", "MAP: VALHALLA"), both halves at the
      // same color/size, plus a thin separator line ABOVE the primary
      // action row (START GAME / FIND GAME / EDIT MAP / PLAY FILM) that
      // visually splits "settings" from "action". The ": " between label
      // and value is drawn by the .lobby-list__value::before pseudo so
      // flex layout can't collapse its whitespace.
      buildRowContent: (li, item) => {
        if (item.id === "start_game") {
          li.classList.add("lobby-list__item--separated");
        }
        const name = document.createElement("span");
        name.className = "lobby-list__name";
        name.textContent = item.label;
        li.appendChild(name);
        if (item.value) {
          const val = document.createElement("span");
          val.className = "lobby-list__value";
          val.textContent = item.value;
          li.appendChild(val);
        }
      },
      mount: (li) => lobbyListEl.appendChild(li),
      clearMounts: () => { lobbyListEl.innerHTML = ""; },
      onConfirm: (item) => {
        // Lobby-internal navigation. switch_lobby pops back to main menu;
        // start_game runs a no-op "starting" overlay; everything else opens
        // a stub for the submenu (variant picker, map picker, etc.).
        if (item.id === "switch_lobby") {
          back();
          return;
        }
        if (item.id === "start_game") {
          openOverlay({
            title: "STARTING GAME",
            tag: `mode=${mode} -> ${data.pregame_lobbies.modes[mode].game_name}`,
          });
          return;
        }
        openOverlay({
          title: (item.label + (item.target ? " (" + item.target + ")" : "")).toUpperCase(),
          tag: `${cfg.datasource}.dsrc -> ${item.id}`,
        });
      },
    });
    lobbyList.build();
  }

  // ---------------------------------------------------------------------
  // ROSTER (16-slot nameplate column).
  // Mirrors ui\halox\common\roster\roster.grup -> roster.lst3 (16 slots @
  // 32px pitch) + roster.skn3 (per-slot skin). Slot internals are named
  // after the skin widgets so future hookup to a real "roster" datasource
  // can fan out to the right DOM nodes:
  //
  //   .roster-slot__base         <-> base_color / base_color_hilite
  //   .roster-slot__emblem       <-> player_emblem / player_emblem_hilite
  //   .roster-slot__name         <-> name / name_hilite
  //   .roster-slot__service-tag  <-> service_tag
  //   .roster-slot__rank-tray    <-> rank_tray / rank_tray_hilite
  //   .roster-slot__skill        <-> skill_level / skill_level_hilite
  //   .roster-slot__exp          <-> experience / experience_hilite
  //   .roster-slot__party-bar    <-> party_bar_player
  //   .roster-slot__ring         <-> ring_of_light (speaking)
  //   .roster-slot__rings        <-> outer_ring + middle_ring (searching)
  //   .roster-slot__empty-prompt <-> press_a_to_join text widget
  //
  // The bounds (top, left) for each sub-element are driven from CSS using
  // data.pregame_lobbies.template.roster.skin_elements as the source of
  // truth — see style.css.
  // ---------------------------------------------------------------------
  const ROSTER_SLOT_COUNT = 16;
  const rosterListEl  = $("#lobby-roster-list");
  const playersCountEl = $("#lobby-players-count");
  const playersMaxEl   = $("#lobby-players-max");

  // Placeholder seed: only the local player slot starts filled. The rest
  // show "PRESS A TO JOIN" until a real roster datasource binds.
  const initialRoster = [
    { name: "Player 1", serviceTag: "PL1", state: "filled", focused: true, leader: true },
  ];

  // Counts non-empty slots to drive the players_in_game text widget
  // (pregame_lobby_template.grup index=1). Engine pumps "X / 16" at
  // runtime; we mirror that by re-counting on every roster change.
  function updatePlayerCount() {
    if (!playersCountEl || !playersMaxEl) return;
    const filled = rosterListEl
      ? rosterListEl.querySelectorAll('.roster-slot:not([data-state="empty"])').length
      : 0;
    playersCountEl.textContent = String(filled);
    playersMaxEl.textContent   = String(ROSTER_SLOT_COUNT);
  }

  function buildRosterSlots() {
    if (!rosterListEl) return;
    rosterListEl.innerHTML = "";
    for (let i = 0; i < ROSTER_SLOT_COUNT; i++) {
      const seed = initialRoster[i];
      const li = document.createElement("li");
      li.className = "roster-slot";
      li.dataset.index    = String(i);
      li.dataset.state    = seed ? (seed.state || "filled") : "empty";
      li.dataset.focused  = String(!!(seed && seed.focused));
      li.dataset.leader   = String(!!(seed && seed.leader));
      li.dataset.speaking = "false";

      // Only the elements with real source artwork (the nameplate strip
      // base) and source text (name, service_tag, press_a_to_join) render.
      // emblem / rank_tray / skill_level / experience / party_bar /
      // ring_of_light / outer_ring / middle_ring all map to bitmap-driven
      // widgets that need real artwork swapped in — see
      // data.json#pregame_lobbies.template.roster.exported_bitmaps for
      // the sprite sheets when we're ready to wire them up.
      li.innerHTML = `
        <span class="roster-slot__base"        aria-hidden="true"></span>
        <span class="roster-slot__name">${seed ? seed.name : ""}</span>
        <span class="roster-slot__service-tag">${seed ? (seed.serviceTag || "") : ""}</span>
        <span class="roster-slot__empty-prompt">PRESS A TO JOIN</span>
      `;
      rosterListEl.appendChild(li);
    }
    updatePlayerCount();
  }

  // ---------------------------------------------------------------------
  // Button-key bottom prompts (offline/online state + per-screen sets)
  // ---------------------------------------------------------------------
  let online = false;

  function renderButtonKeys(barEl, prompts) {
    barEl.innerHTML = "";
    for (const p of prompts) {
      const wrap  = document.createElement("span");
      wrap.className = "button-key";
      const glyph = document.createElement("span");
      glyph.className = "button-key__glyph";
      glyph.dataset.glyph = p.glyph;
      glyph.textContent = p.glyph;
      const lbl   = document.createElement("span");
      lbl.textContent = p.label;
      wrap.appendChild(glyph);
      wrap.appendChild(lbl);
      barEl.appendChild(wrap);
    }
  }

  function renderMainButtonKeys() {
    const which = online ? "main_menu_online" : "main_menu_offline";
    renderButtonKeys($("#button-keys"), data.button_keys[which]);
  }

  function renderLobbyButtonKeys() {
    renderButtonKeys(lobbyButtonKeysEl, data.pregame_lobbies.template.button_keys);
  }

  // ---------------------------------------------------------------------
  // Page router with tag-driven screen transitions
  //
  // Engine model (from data.screen_transitions, sourced from
  // mainmenu_slide_up.wacd / lobby_slide.wacd):
  //   * outgoing screen plays `transition-from`
  //   * incoming screen plays `transition-to`
  //   * both run CONCURRENTLY for one 666 ms beat
  //
  // We mirror that here. Both pages are visible during the transition
  // window; the CSS classes .is-leaving on the outgoing page and
  // .is-entering on the incoming page drive the right keyframes
  // (main = vertical 38.89cqh, lobby = horizontal 42.19cqw). Input is
  // locked while `transitioning` is true to keep focus state coherent.
  // (slow-mode toggle and TRANSITION_MS are set at the top of this IIFE.)

  const pageEls = {
    main_menu:     pageMain,
    pregame_lobby: pageLobby,
  };

  let currentPage   = "main_menu";
  let activeList    = mainList;
  let transitioning = false;

  // Clear the one-shot .is-initial class once the first main-menu enter
  // animation has finished, so subsequent navigation doesn't keep
  // re-triggering it. Listen for the page-level fade animation (fires
  // on pageMain itself) - panel/child animations bubble through too but
  // we only want the page's own end event.
  pageMain.addEventListener("animationend", function onIntroEnd(ev) {
    if (!pageMain.classList.contains("is-initial")) return;
    if (ev.target !== pageMain) return;
    pageMain.classList.remove("is-initial");
    pageMain.removeEventListener("animationend", onIntroEnd);
  });

  function playAnimation(rootEl, className) {
    // Each page wrapper now drives an opacity animation on itself plus a
    // transform animation on its panel. All animations share the same
    // 666 ms duration and end together, so we just resolve when the
    // page-level animation fires animationend (or when the safety
    // timeout trips in case prefers-reduced-motion suppresses it).
    return new Promise((resolve) => {
      rootEl.classList.remove(className);
      void rootEl.offsetWidth;                  // force reflow / restart
      rootEl.classList.add(className);

      if (slowMo) {
        const cs = getComputedStyle(rootEl);
        console.warn(
          `[anim] ${rootEl.dataset.page}.${className} ` +
          `duration=${cs.animationDuration} name=${cs.animationName}`
        );
      }

      let done = false;
      function finish() {
        if (done) return;
        done = true;
        rootEl.removeEventListener("animationend", onEnd);
        resolve();
      }
      function onEnd(ev) {
        // Only resolve on the page wrapper's own opacity animation -
        // ignore inner panel/transform animations to avoid resolving
        // mid-transition.
        if (ev.target !== rootEl) return;
        finish();
      }
      rootEl.addEventListener("animationend", onEnd);
      setTimeout(finish, TRANSITION_MS + 150);  // safety net
    });
  }

  async function showPage(targetPage, opts = {}) {
    if (transitioning) return;
    if (targetPage === currentPage) return;

    const fromPage = currentPage;
    const fromEl   = pageEls[fromPage];
    const toEl     = pageEls[targetPage];
    if (!fromEl || !toEl) return;

    transitioning = true;

    // Populate the target page BEFORE making it visible, so its enter
    // keyframes start from a fully-rendered state offscreen.
    if (targetPage === "pregame_lobby") {
      lobbyMode = opts.mode;
      screenEl.dataset.lobbyMode = opts.mode;
      buildLobbyList(opts.mode);
      renderLobbyButtonKeys();
    } else if (targetPage === "main_menu") {
      lobbyMode = null;
      screenEl.dataset.lobbyMode = "";
    }

    // Both pages on-screen at once during the 666 ms window. The enter
    // keyframes start the incoming panel offscreen so there's no flash.
    toEl.hidden = false;

    // Engine runs both clips concurrently.
    await Promise.all([
      playAnimation(fromEl, "is-leaving"),
      playAnimation(toEl,   "is-entering"),
    ]);

    // Tear down: hide outgoing page, strip animation classes so the next
    // navigation starts from a clean state.
    fromEl.hidden = true;
    fromEl.classList.remove("is-leaving");
    toEl.classList.remove("is-entering");

    currentPage = targetPage;
    screenEl.dataset.screen = targetPage;
    $("#dbg-screen").textContent = targetPage;

    if (targetPage === "main_menu") {
      activeList = mainList;
      mainList.applyFocus();
    } else if (targetPage === "pregame_lobby") {
      activeList = lobbyList;
    }

    transitioning = false;
  }

  // ---------------------------------------------------------------------
  // Destination dispatch
  // ---------------------------------------------------------------------
  function navigateTo(destination) {
    if (destination === "_quit") {
      // Engine-side: real Halo quits to dashboard. Mockup just dims.
      document.documentElement.style.transition = "opacity 600ms ease";
      document.documentElement.style.opacity = "0";
      setTimeout(() => {
        document.documentElement.style.opacity = "1";
        document.documentElement.style.transition = "";
      }, 1200);
      return;
    }

    if (destination.startsWith("pregame_lobby_")) {
      const mode = destination.slice("pregame_lobby_".length);
      if (data.pregame_lobbies.modes[mode]) {
        showPage("pregame_lobby", { mode });
        $("#dbg-nav").textContent = destination;
        return;
      }
    }

    // Unmodelled destination (start_menu, campaign_select_difficulty, etc.):
    // show the stub overlay so it's clear which tag we'd navigate to.
    const tag = data.navigation_table[destination] || "(no widget tag - engine-side)";
    openOverlay({
      title: destination.replace(/_/g, " ").toUpperCase(),
      tag:   tag + ".scn3",
    });
    $("#dbg-nav").textContent = destination;
  }

  function openOverlay({ title, tag }) {
    $("#overlay-title").textContent = title;
    $("#overlay-tag").textContent   = tag;
    $("#submenu-overlay").hidden    = false;
  }

  function closeOverlay() {
    $("#submenu-overlay").hidden = true;
    $("#dbg-nav").textContent    = "-";
  }

  function back() {
    if (!$("#submenu-overlay").hidden) {
      closeOverlay();
      return;
    }
    if (currentPage === "pregame_lobby") {
      showPage("main_menu");
      return;
    }
    // main_menu has the "B-Back shouldn't dispose screen" flag - do nothing.
  }

  // ---------------------------------------------------------------------
  // Keyboard input - routes to whichever list is active
  // ---------------------------------------------------------------------
  document.addEventListener("keydown", (e) => {
    // Backtick always works (debug toggle is useful mid-transition too).
    if (e.key === "`") {
      $("#debug").hidden = !$("#debug").hidden;
      return;
    }
    // Swallow input while a screen transition is in flight - otherwise
    // arrow keys / Enter race against the page swap and focus drifts to
    // the wrong list.
    if (transitioning) { e.preventDefault(); return; }

    switch (e.key) {
      case "ArrowUp":
      case "w":
      case "W":      activeList.moveFocus(-1);  e.preventDefault(); break;
      case "ArrowDown":
      case "s":
      case "S":      activeList.moveFocus(+1);  e.preventDefault(); break;
      case "Enter":
      case "a":
      case "A":
      case " ":      activeList.confirm();      e.preventDefault(); break;
      case "Escape":
      case "b":
      case "B":      back();                    e.preventDefault(); break;
      case "x":
      case "X":
        navigateTo("start_menu_settings");
        break;
      case "y":
      case "Y":
        if (currentPage === "pregame_lobby") {
          openOverlay({
            title: "ROSTER",
            tag: "ui\\halox\\common\\roster\\roster.grup",
          });
        } else if (online) {
          navigateTo("start_menu_hq");
        }
        break;
    }
  });

  $("#submenu-overlay").addEventListener("click", closeOverlay);

  $("#dbg-online").addEventListener("change", (e) => {
    online = e.target.checked;
    renderMainButtonKeys();
  });

  // ---------------------------------------------------------------------
  // Initial render
  // ---------------------------------------------------------------------
  mainList.build();
  renderMainButtonKeys();
  // Roster is the same 16-slot skin across every game mode, so we build
  // it once at init instead of rebuilding inside showPage/buildLobbyList.
  buildRosterSlots();
  $("#dbg-screen").textContent = currentPage;

  console.info("Loaded H3 main menu data:", data);
  console.info("Pregame lobby modes:", Object.keys(data.pregame_lobbies.modes));
})();
