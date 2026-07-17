/* Pause menu — WebCore port of engine/ui/draft/pause_draft.slint */
(function () {
  /* Panel-relative item tops on 720 ref (panel_y 59 + item offsets). */
  var ITEM_Y = [67, 98, 130, 162, 193, 225];
  var REF_H = 720;

  var stage = document.getElementById("stage");
  var focusBar = document.getElementById("focus-bar");
  var items = Array.prototype.slice.call(document.querySelectorAll(".menu-item"));
  var selected = 0;

  function setFocusY(index) {
    focusBar.style.setProperty("--focus-y", "calc(100% * " + ITEM_Y[index] + " / " + REF_H + ")");
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

  function cbuf(cmd) {
    if (!cmd || typeof window.fte_query !== "function") return false;
    try {
      return window.fte_query("cbuf:" + cmd) === "ok";
    } catch (e) {
      return false;
    }
  }

  function activate() {
    var el = items[selected];
    if (!el) return;
    var multi = el.getAttribute("data-cmds");
    if (multi) {
      multi.split(",").forEach(function (cmd) { cbuf(cmd.trim()); });
      return;
    }
    cbuf(el.getAttribute("data-cmd"));
  }

  items.forEach(function (el, i) {
    el.addEventListener("mouseenter", function () { select(i); });
    el.addEventListener("click", function () {
      select(i);
      activate();
    });
  });

  document.addEventListener("keydown", function (e) {
    var key = e.key;
    if (key === "ArrowUp" || key === "w" || key === "W") {
      select(selected - 1);
      e.preventDefault();
    } else if (key === "ArrowDown" || key === "s" || key === "S") {
      select(selected + 1);
      e.preventDefault();
    } else if (key === "Enter" || key === " ") {
      activate();
      e.preventDefault();
    } else if (key === "Escape") {
      cbuf("webcore_closemenu");
      e.preventDefault();
    }
  });

  document.addEventListener("wheel", function (e) {
    if (e.deltaY > 0) select(selected + 1);
    else if (e.deltaY < 0) select(selected - 1);
  }, { passive: true });

  select(0);
})();
