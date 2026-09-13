# Wiki Log

## [2026-09-12] update | title-menu list treatment in lobby

Reused the active `title-menu-v2` list styling for Lobby options, Ruleset, Map,
Server type, and Start/Ready: standard 07_57 font, sliding light-gray focus bar,
dark selected text, engine navigation/confirm/back sounds, and mouse/keyboard/
wheel selection. Guest-only settings stay locked and inactive. Native WebCore
tests check focus movement, colors, actions, sounds, and guest restrictions.

## [2026-09-12] update | Figma lobby bgPanel

Added Figma `bgPanel` (`109:18`) behind the lobby's left-side content at design
coordinates `(39, 56)`, size `544 × 613`, with `rgba(61,61,61,.76)` fill. The
roster and outer canvas remain transparent. Rebuilt the WebCore bundle and
checked native rendering and the existing host/guest interactions.

## [2026-09-12] update | lobby guestLock

Implemented Figma `109:10` as a reusable `GuestLock` component over the four
settings rows for active non-host clients. Those buttons are disabled for mouse
and keyboard; Ready/Unready, chat, roster, and Leave remain usable. Losing host
authority closes an open settings dialog; becoming host restores access. Reused
the exact Figma SVG and shipped standard 07_57 font, adding private registration
of that font to the WebCore plugin. Updated native interaction checks cover the
guest lock and role transitions.

## [2026-09-12] implement | Figma lobby UI

Ported Figma frame `72:2` to `base/data/web/lobby-menu/` using reusable Preact
components, a centered 960 × 720 stage, shipped fonts, and a generated local
bundle. Added live chat and host ruleset/time/frag controls to the existing engine
session bridge. Chat uses bounded UTF-8 hex commands, sender validation, and host
relay. Fixed sender-specific reliable-message deduplication, borrowed map-string
lifetime, and same-machine IPv4 gameplay endpoint selection during integration.
The canonical engine and WebCore plugin were rebuilt and deployed locally.

Verified native WebCore rendering/input, guest permissions, dialog navigation,
connection recovery, assets, and 4:3/16:9 layout. Three actual local engine clients
exchanged chat/settings and entered `envtest` with TEAMDM, 12-minute and 25-frag
limits. See `docs/verification/2026-09-12-figma-lobby.md` and the lobby README.
Guest countdown/state replication was also fixed and verified through ready-up,
countdown, host cancellation, and a subsequent successful explicit Start.
Periodic synchronization includes countdown state for recovery after missed
transitions; the final three-client check also verifies no gameplay starts early.
Dedicated hosting remains unavailable; internet/NAT traversal was not exercised.

## [2026-07-24] document | player IQM animation

Added `Documentation/Models/IQM.md` (export, hero `act_*`, skeletal vs CSO,
CSQC `declclass`, torso `skel_build` guard, oneshot crouch/jump). Linked from
`Documentation/Models.md`. Seeded wiki concept [[player-iqm-animation]];
noted empty `""` entityDef hazard on [[entitydef]]. Updated `AGENTS.md`
Player IQM fact to match numeric acts + CSQC resolve.

## [2026-07-17] create | wiki

Initialized project LLM wiki at `wiki/` for Hermes + Cursor shared context.
Ingested `AGENTS.md` → `raw/articles/agents-md.md`.
Seeded entity/concept pages from standing preferences and workspace facts.

## [2026-07-22] investigate | arena viewmodel close transition

Prevented `arena_enter` from re-running free-play spawn after READY UP and
invalidated the client viewmodel model-index cache across transient active-weapon
replication gaps; the runtime issue persisted. Added opt-in transition-only
`cl_viewmodelDebug` tracing to identify the live draw suppressor. The trace
confirmed client `activeweapon` changed from the live weapon entnum to zero when
input resumed. `ProcessInput()` rejection tracing did not fire, ruling out that
path. Made WebCore `arena_action:close` side-effect free (no `cmd arena_enter`),
rebuilt/deployed `fteplug_webcore_x64.dll`, and added opt-in `g_weaponDebug`
logging at `MakeTempSpectator()` and authoritative `PLAYER_WEAPON` publication
to distinguish server teardown from a CSQC-only reset. Runtime logs showed the
server published `0 → 180` and never `180 → 0`, proving CSQC prediction locally
clobbered the numeric reference. `ReceivePlayerEntity()` now snapshots explicit
`PLAYER_WEAPON` updates into `activeweapon_net`; `PredictPreFrame()` restores an
unexpected local zero from that authoritative snapshot before save/rollback.
Plugin tests pass; server and client QC targets compile successfully.
OKF bundle initialized at `wiki/okf/` for hermes-okf memory provider.
