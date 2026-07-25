/* BaseMod-style interaction primitives shared by WebCore menu pages.
 * One flyout may be open at a time; cancelling it restores its anchor.
 * Full-screen child views remember their caller and return to the lobby. */
(function (root) {
  "use strict";

  function setClass(el, name, enabled) {
    if (!el || !el.classList) return;
    if (enabled) el.classList.add(name);
    else el.classList.remove(name);
  }

  function setHidden(el, hidden) {
    if (!el) return;
    el.hidden = !!hidden;
    setClass(el, "hidden", !!hidden);
    if (el.setAttribute) el.setAttribute("aria-hidden", hidden ? "true" : "false");
  }

  function focusElement(el, onFocus) {
    if (!el) return;
    if (typeof el.focus === "function") el.focus();
    if (onFocus) onFocus(el);
  }

  function createBaseModController(options) {
    options = options || {};
    var flyouts = {};
    var activeFlyout = null;
    var view = "lobby";
    var viewCaller = null;

    function closeFlyout(restoreFocus) {
      var current = activeFlyout ? flyouts[activeFlyout] : null;
      if (!current) return false;
      setHidden(current.panel, true);
      setClass(current.anchor, "active", false);
      activeFlyout = null;
      if (options.onFlyoutChange) options.onFlyoutChange(null);
      if (restoreFocus) focusElement(current.anchor, options.onFocus);
      return true;
    }

    function openFlyout(id, anchor, preferred) {
      var next = flyouts[id];
      var choice;
      if (!next || !anchor) return false;
      if (activeFlyout === id) return closeFlyout(true);
      closeFlyout(false);
      next.anchor = anchor;
      activeFlyout = id;
      setClass(anchor, "active", true);
      setHidden(next.panel, false);
      choice = preferred || next.items[0] || null;
      if (options.onFlyoutChange) options.onFlyoutChange(id);
      focusElement(choice, options.onFocus);
      return true;
    }

    function registerFlyout(id, panel, items) {
      flyouts[id] = { panel: panel, items: items || [], anchor: null };
      setHidden(panel, true);
    }

    function openView(nextView, caller) {
      if (!nextView || nextView === view) return false;
      closeFlyout(false);
      view = nextView;
      viewCaller = caller || null;
      if (options.onViewChange) options.onViewChange(view, viewCaller);
      return true;
    }

    function returnToLobby() {
      if (view === "lobby") return false;
      view = "lobby";
      if (options.onViewChange) options.onViewChange(view, viewCaller);
      focusElement(viewCaller, options.onFocus);
      viewCaller = null;
      return true;
    }

    function cancel() {
      if (closeFlyout(true)) return true;
      if (returnToLobby()) return true;
      if (options.onCancel) options.onCancel();
      return !!options.onCancel;
    }

    return {
      registerFlyout: registerFlyout,
      openFlyout: openFlyout,
      closeFlyout: closeFlyout,
      openView: openView,
      returnToLobby: returnToLobby,
      cancel: cancel,
      activeFlyoutId: function () { return activeFlyout; },
      activeView: function () { return view; }
    };
  }

  root.WebCoreBaseMod = root.WebCoreBaseMod || {};
  root.WebCoreBaseMod.createBaseModController = createBaseModController;
  if (typeof module !== "undefined" && module.exports)
    module.exports = { createBaseModController: createBaseModController };
})(typeof window !== "undefined" ? window : globalThis);
