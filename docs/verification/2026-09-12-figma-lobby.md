# Figma lobby integration — 2026-09-12

Implemented frame `72:2` from the H3 Main Menu mockup in the existing WebCore
lobby page. The Figma MCP successfully returned design context with the connected
Starter/View account; an expired paid membership did not block this read.

## Delivered

- Reusable Preact views for map summary, menu, roster, chat, and settings dialogs.
- Measured 960 × 720 layout with uniform centered scaling and transparent canvas.
- Inter Regular/Bold and existing Trade Gothic loaded privately by the Windows
  plugin; no CSS font loading and no system font installation.
- Live player count/readiness, chat, map/ruleset/limit controls, Start/Cancel,
  room-code copying where a code exists, and Leave confirmation.
- Engine-side validation and synchronized settings; selected match settings are
  applied before gameplay begins.

The entire generated UI bundle is approximately 29 KB. `app.js` is build output;
the source and build instructions are in `base/data/web/lobby-menu/README.md`.

## Validation

`Tools/test_webcore_lobby.py` passed using the actual `ftewebcore.dll`, real UI
assets, and native mouse/keyboard events. It checks chat typing/Enter, safe modal
navigation, map/ruleset actions, guest readiness/permissions, exact Escape asset
decoding, initial focus, connection recovery without a changed revision, and
letterboxing at 960 × 720 and 1920 × 1080. Guest countdown display and unique
controls within the guest options dialog also pass.

Canonical `plugins/webcore/tests/test-win.cmd` passed, including valid new bridge
commands, malformed command rejection, and query sizing without side effects.
The compiler reports existing warnings.

`Tools/test_lobby_ui_engine.ps1` passed with three actual engine processes. All
three received all three chat messages and synchronized TEAMDM / 12 / 25 settings.
The selected map remained `envtest`; both guests initialized client gameplay and
the host's status listed all three connected players. All three also observed a
live countdown and its cancellation before the final explicit Start. Artifacts:
`_lobby_diag/figma-port/lobby_ui_20260912_043356/`.
The final run also confirms no gameplay initializes before Start. The test
disables update prompts and the title-background map for its own processes and
closes only those processes. It does not save game configuration.

## Scope and remaining limits

Only listen-server hosting is available. The map list retains the existing four
choices; no map-thumbnail artwork was supplied for the gray preview panel.
Figma placeholder strings become actual state, and Escape says Leave to match
its action. LAN does not supply an online room code, so that field displays a
dash. Chat retains the latest ten messages per client.

The three-client test exercises same-machine LAN. Internet room-code joining,
NAT traversal, controller input, and non-Windows font handling were not verified
by this change. Guest countdown replication now applies the host's state and a
relative remaining duration, avoiding comparisons between independently started
engine clocks. Periodic full synchronization also includes this state to recover
missed transitions. The host remains authoritative over the actual start time.

The rebuilt engine and plugin are installed in the Nuclide root. Source changes
also live in the canonical sibling
`workspace/fteqw/_worktrees/webcore-cpu-renderer` tree, so a Nuclide-only commit
will not include them. `2026-09-12-figma-lobby-engine.patch` records this task's
engine changes against its initial source snapshot for review/portability; it is
not a patch against a pristine upstream checkout. Keep the loose TTF assets when
packaging. Restart the game to load the new binaries.
