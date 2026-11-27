# Lobby UI

This is the in-engine implementation of [Figma frame 72:2](https://www.figma.com/design/zPN8CD2bkg3IHbvJsTcNfA/H3-Main-Menu--Web-Mockup-?node-id=72-2).
FTE loads `fte://data/web/lobby-menu/index.html` through the existing Create/Join Lobby flow.

## Editing the UI

Edit the components in `src/` and the layout in `style.css`. Run `npm ci` once, then `npm run build` in this directory. Commit the generated `app.js` along with source changes. The game needs only the built files and assets; Node, npm, and a development server are not required at runtime.

`app.js` is a generated Preact bundle, not the source file to edit.

| Figma group | Component | Responsibility |
| --- | --- | --- |
| bgPanel | `main.jsx` / `style.css` | Translucent panel behind the left-side lobby content |
| mapPreview | `MapPreview.jsx` | Map name and authoritative match settings |
| List – Lobby Menu | `LobbyMenu.jsx` | Settings rows and Start/Cancel/Ready action |
| playerListSmall / rosterInfo | `PlayerRoster.jsx` | Room-code copying, player count, keyed player rows |
| chat | `ChatPanel.jsx` | Draft input, sending, message list, scroll position |
| Child settings panels | `SettingsDialog.jsx` | Map/ruleset choices, limits, ready state, server information |
| Repeated controls | `Button.jsx` | Button and settings-row primitives |
| guestLock | `GuestLock.jsx` | Guest-only cover over the four disabled settings rows |

The Figma groups become composed components; repeated controls become reusable widgets. Text and rectangles remain live HTML/CSS, not a flattened image. The Escape-key and guest-lock artwork are exported assets.

`main.jsx` composes the screen, polls session state, and owns dialog selection. `model.js` normalizes the snapshot. `bridge.js` is the only source module that speaks `fte_query`. `navigation.js` handles keyboard focus independently of rendering. Player names and chat use text nodes, never interpreted HTML.

## Layout and fonts

The design is authored at 960 × 720. `LobbyStage` scales uniformly to fit the viewport and stays centered, including ultrawide and portrait windows. Pixel measurements in CSS are design coordinates. The white Figma canvas becomes transparent over the engine background.

Figma `bgPanel` (`109:18`) is the 544 × 693 backing at `(39, 14)`. Its dark gray fill fades from transparent to 70% opacity over the top 4.8077%, stays steady through 95%, then fades out at the bottom. It sits behind the map preview, controls, chat, and footer. The roster is separate, and areas outside the panel remain transparent.

Trade Gothic Next LT Pro BdCn is reused from the shipped HUD assets. Inter Regular/Bold are included under `assets/fonts/` with their OFL license. The Windows plugin registers these **loose TTF files privately in the game process** using `AddFontResourceExW(FR_PRIVATE)`, so no system font installation or CSS `@font-face` is needed. Keep the fonts loose when packaging; they must resolve through `NativePath(FS_GAMEONLY)`. The Escape asset is embedded in the JS bundle because deferred `fte://` image decoding is unreliable in this WinCairo host.

Figma's placeholder strings are replaced with live values. Six-character room codes fit in the same block with a smaller size. The Escape hint says **Leave**, matching its actual action. Guest players see Ready/Unready where the host sees Start Game. The current player's nameplate also toggles readiness.

Guests see Figma `guestLock` (`109:10`) over Lobby options, Ruleset, Map, and Server type. All four rows are native disabled buttons, so mouse and keyboard cannot activate them. Ready/Unready, the roster, chat, and Leave remain available. Losing host authority closes any open settings dialog. The lock SVG is the exact Figma asset, embedded in the bundle; its label uses the existing `ql-menu/assets/standard_07_57.ttf`, privately registered by the plugin (family name `standard 07_57`).

The lobby's five list rows reuse the active `title-menu-v2` treatment: shipped `standard 07_57` at 16px, white text, a 24px `#bfbfbf` focus bar with 100ms easing, and `#404040` selected text. Mouse hover, arrow keys, W/S, and wheel move the selection; Tab can leave the list for chat and roster. `misc/menu1` plays once on selection changes, `misc/menu2` on activation, and `misc/menu3` when a dialog is dismissed. Sounds go through the existing engine `localsound` bridge. The four settings rows use the title menu's 24px spacing; Start/Ready and the guest lock retain their design positions. Unavailable host rows are skipped.

## Engine contract

- `getlobby` returns the existing session state plus `uiVersion`, `max`, `canChat`, and `settings` (ruleset, server type, time limit, frag limit).
- `getlobbychat` returns the latest ten messages, with stable local message IDs, seat, sender name, and text.
- Existing actions remain `ready`, `unready`, `start`, `cancel`, `setmap:<id>`, and `close`.
- Added actions are `setruleset:<id>`, `setlimits:<minutes>:<frags>`, and `chat:<UTF-8 hex>`.
- The engine retains authority over host-only settings and state transitions. A bridge acknowledgement means a command was queued; the next snapshot supplies the resulting state.
- Chat is limited to 240 UTF-8 bytes. Hex encoding keeps chat text separate from console command syntax. The host validates the sender and relays messages to the other guests.
- The selected ruleset becomes `g_gametype` before map load. Time and frag limits are applied before map load too.

Hosting options (Bulwark; `getlobby` carries them when the engine has them):

- `settings` adds `hostname`, `maxplayers`, `bots` (a number, or -1 for fill), `public`, `password` (whether there is one) and, for the host only, `passwordText`. `settings.servertype` is `LISTEN SERVER` or `DEDICATED SERVER`.
- `hosting` (`{serverTypes, maxSeats, online, onlineConfigured}`) says what the engine can host. Without it (FTE's lobby plugin) the Server type row opens the old listen-only dialog, and nothing else changes.
- The Server type row opens **Server settings**: Listen/Dedicated, server name, max players, password, bots (count or Fill) and public listing, applied with `setserver:<listen|dedicated>:<max>:<bots|fill>:<public 0|1>:<name hex>:<password hex>` (UTF-8 hex, empty for none). A refusal comes back as `{"ok":false,"error":...}` and is shown.
- A guest turned away for a password gets `needPassword` and `joinTarget`; the page asks for the password and sends `joinpass:<hex>`, or Leave.
- `warning` (an online lobby without Bulwark Live, for example) shows on the status line when nothing else does.
- The engine applies them when the game starts: `hostname`, `maxplayers`/`sv_playerslots`, `sv_password` (guests connect with it), `sv_public`, and bots through `bot_minClients` (rulesets marked `seatbots` in `base/scripts/lobby.txt` get `arena_bots` instead). Dedicated starts the engine's dedicated server on the host's computer and everyone joins it. The map and ruleset lists come from `getlobby` (`maps`, `rulesets`: `[{id, name}]`) when the engine sends them (Bulwark builds them from `base/scripts/lobby.txt` and the maps that are shipped); otherwise the page uses `MAPS` and `RULESETS` in `model.js`. Keep those fallbacks in step with `base/scripts/lobby.txt`, and list only maps that exist as `base/maps/<id>.bsp`. The reusable BaseMod controller in `interaction.js` is retained for existing consumers, but this page's view state belongs to its Preact components.

## Verification

From the Nuclide root:

```text
python Tools/test_webcore_lobby.py
powershell -File Tools/test_lobby_ui_engine.ps1
```

The first test renders the actual shipped bundle in `ftewebcore.dll`, sends native mouse/key events, and checks typing, chat, map/ruleset actions, modal behavior, guest permissions, asset decoding, and letterboxing. It writes native-renderer captures under `_lobby_diag/figma-port/`.

The second launches three isolated local game processes, verifies shared chat/settings and countdown/cancellation, and checks the gameplay handoff. It closes only those test processes. Engine/plugin sources are in the canonical `workspace/fteqw/_worktrees/webcore-cpu-renderer` tree; restart the game after updating those binaries.
