# Solutions

This directory contains durable write-ups for solved implementation and runtime problems. Solution documents should preserve the symptoms, eliminated hypotheses, root cause, minimal fix, verification evidence, and regression-prevention guidance.

Use descriptive lowercase filenames. Add a category subdirectory when it improves navigation; reserve dated filenames for chronological plans and implementation notes.

## Runtime errors

- [FTEQCC virtual `ReceiveEntity` dispatch causes CSQC player underreads](runtime-errors/fteqcc-virtual-receiveentity-csqc-underread.md) — an inherited virtual method collision caused `ENT_PLAYER` payloads to be decoded using the wrong schema after a lobby-to-game transition.