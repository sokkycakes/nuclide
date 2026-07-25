from pathlib import Path
from playwright.sync_api import sync_playwright

PAGE = Path(__file__).with_name("index.html").as_uri()
SNAPSHOT_SCRIPT = """
window.__snapshot = {
  active: true, revision: 1, isHost: true, localSeat: 0,
  phase: "WAITING", status: "Waiting for players", map: "envtest",
  countdownEnd: 0, serverTime: 1000, canReady: true, canStart: false,
  canCancel: false, canChangeMap: true, canLeave: true,
  roomCode: "NUC1", max: 4, transport: "ice/online",
  players: [{ seat: 0, name: "Host Player", host: true, ready: false, connected: true }]
};
window.__actions = [];
window.fte_query = function (request) {
  if (request === "getlobby") return JSON.stringify(window.__snapshot);
  if (request.indexOf("lobby_action:") === 0) {
    window.__actions.push(request);
    return '{"ok":true}';
  }
  if (request.indexOf("cbuf:") === 0) return "ok";
  return null;
};
"""


def focused_control(page):
    return page.evaluate(
        "document.activeElement && (document.activeElement.id || document.activeElement.dataset.map)"
    )


with sync_playwright() as playwright:
    browser = playwright.chromium.launch(headless=True)
    page = browser.new_page(viewport={"width": 1920, "height": 1080})
    page.add_init_script(SNAPSHOT_SCRIPT)
    page.goto(PAGE)
    page.wait_for_timeout(400)

    assert focused_control(page) == "BtnChangeMap", "lobby should focus its first enabled control"
    assert not page.locator("#BtnStartGame").is_disabled(), "host Start must ignore ready-state gating"
    page.locator("#BtnStartGame").click()
    assert page.evaluate("window.__actions") == ["lobby_action:start"]

    page.locator("#BtnChangeMap").click()
    page.wait_for_timeout(0)
    assert page.locator("#view-settings").is_visible()
    assert focused_control(page) == "envtest", "settings should focus the first map choice"

    browser.close()

print("app.playwright.test.py: all tests passed")
