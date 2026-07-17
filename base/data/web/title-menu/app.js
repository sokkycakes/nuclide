/* Title menu — WebCore port of engine/ui/title_menu.slint
   Actions match Slint callbacks (menu_maps / menu_newmulti / menu_options / quit). */
(function () {
  var ITEM_Y = [443, 483, 514, 545]; /* Figma px on 768-tall ref */
  var FOCUS_OFFSET = 3;
  var REF_H = 768;

  var stage = document.getElementById("stage");
  var focusBar = document.getElementById("focus-bar");
  var items = Array.prototype.slice.call(document.querySelectorAll(".menu-item"));
  var selected = 0;

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
    }
  });

  document.addEventListener("wheel", function (e) {
    if (e.deltaY > 0) select(selected + 1);
    else if (e.deltaY < 0) select(selected - 1);
  }, { passive: true });

  select(0);
})();
