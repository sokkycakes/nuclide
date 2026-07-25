const assert = require("assert");
const { createBaseModController } = require("./interaction.js");

function control(id) {
  const classes = new Set();
  return {
    id,
    disabled: false,
    hidden: false,
    classList: {
      add: (name) => classes.add(name),
      remove: (name) => classes.delete(name),
      contains: (name) => classes.has(name)
    },
    focus() { this.focused = true; }
  };
}

(function testFlyoutsAreExclusiveAndRestoreTheirAnchorFocus() {
  const mapAnchor = control("map-anchor");
  const accessAnchor = control("access-anchor");
  const mapFlyout = control("map-flyout");
  const accessFlyout = control("access-flyout");
  const mapChoice = control("map-envtest");
  const accessChoice = control("access-lan");
  const focused = [];

  const controller = createBaseModController({
    onFocus: (item) => focused.push(item.id)
  });
  controller.registerFlyout("maps", mapFlyout, [mapChoice]);
  controller.registerFlyout("access", accessFlyout, [accessChoice]);

  assert.strictEqual(controller.openFlyout("maps", mapAnchor), true);
  assert.strictEqual(controller.activeFlyoutId(), "maps");
  assert.strictEqual(mapAnchor.classList.contains("active"), true);
  assert.strictEqual(mapFlyout.hidden, false);
  assert.strictEqual(focused.pop(), "map-envtest");

  assert.strictEqual(controller.openFlyout("access", accessAnchor), true);
  assert.strictEqual(controller.activeFlyoutId(), "access");
  assert.strictEqual(mapAnchor.classList.contains("active"), false);
  assert.strictEqual(mapFlyout.hidden, true);
  assert.strictEqual(accessAnchor.classList.contains("active"), true);

  assert.strictEqual(controller.cancel(), true);
  assert.strictEqual(controller.activeFlyoutId(), null);
  assert.strictEqual(accessAnchor.classList.contains("active"), false);
  assert.strictEqual(accessFlyout.hidden, true);
  assert.strictEqual(accessAnchor.focused, true);
})();

(function testCancelFallsBackToTheActiveChildViewThenTheLobby() {
  const transitions = [];
  const controller = createBaseModController({
    onViewChange: (view, caller) => transitions.push([view, caller && caller.id])
  });
  const caller = control("map-anchor");

  controller.openView("settings", caller);
  assert.strictEqual(controller.activeView(), "settings");
  assert.strictEqual(controller.cancel(), true);
  assert.strictEqual(controller.activeView(), "lobby");
  assert.strictEqual(caller.focused, true);
  assert.deepStrictEqual(transitions, [["settings", "map-anchor"], ["lobby", "map-anchor"]]);
})();

console.log("interaction.test.js: all tests passed");
