# Wiki Log

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
