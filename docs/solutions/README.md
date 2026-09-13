# Solutions

This directory contains durable write-ups for solved implementation and runtime problems. Solution documents should preserve the symptoms, eliminated hypotheses, root cause, minimal fix, verification evidence, and regression-prevention guidance.

Use descriptive lowercase filenames. Add a category subdirectory when it improves navigation; reserve dated filenames for chronological plans and implementation notes.

## Gameplay

- [Arena / Duel rules foundation](gameplay/arena-duel-rules-foundation.md) — Arena is the authoritative lifecycle/participation/result director; Duel sudden-death policy lives in hooks. In-engine regression still needs a live 1v1 walkthrough.

## Runtime errors

- [WebCore HUD map-load AV when ICU data is missing](runtime-errors/webcore-hud-icu-data-missing.md) — playtest drops that ship `ftewebcore.dll` without `resources/icudt67l.dat` access-violate a few seconds after any map load when the HUD parses `@font-face`.
- [FTEQCC virtual `ReceiveEntity` dispatch causes CSQC player underreads](runtime-errors/fteqcc-virtual-receiveentity-csqc-underread.md) — an inherited virtual method collision caused `ENT_PLAYER` payloads to be decoded using the wrong schema after a lobby-to-game transition.