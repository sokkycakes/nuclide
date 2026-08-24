---
title: "Duel map spawnpoints resolve to world origin on raw .map loads"
date: 2026-08-04
last_updated: 2026-08-05
category: runtime-errors
module: "Duel arena spawn initialization"
problem_type: runtime_error
component: development_workflow
severity: high
symptoms:
  - "Duel clients spawn at world origin (map center, up in the air) instead of an info_player_deathmatch point"
  - "Only raw .map loading fails; the compiled BSP works"
  - "Spawn entities exist with correct classname but runtime origin reads 0 0 0"
root_cause: config_error
resolution_type: code_fix
tags:
  - duel
  - spawnpoints
  - world-origin
  - raw-map
  - quakec
  - fteqw
  - tokenize
related:
  - docs/solutions/runtime-errors/csqc-remote-player-stuck-at-world-origin.md
---

# Duel map spawnpoints resolve to world origin on raw .map loads

## Problem

Loading `map duel_alley.map` directly (raw Quake map, no BSP) puts duel players at the world origin instead of at the two `info_player_deathmatch` spawn points. The compiled `duel_alley.bsp` behaves correctly. The failure was reproduced with a fresh `base/progs.dat` rebuild, so it is not a stale-artifact problem.

## Root Cause / Causal Chain

1. The map is authored in NetRadiant, which writes `// entity N` comments immediately before each entity block.
2. FTE's raw `.map` loader (`Terr_ReformEntitiesLump` in the engine) copies point-entity text into the entity lump **including those comments** — it is not a BSP compile pass, so nothing strips them.
3. The engine's `__fullspawndata` → `m_rawSpawnData` path replaces newlines with tabs.
4. QC-side `ncIO::GetSpawnString()` uses `tokenize(m_rawSpawnData)`. FTE's tokenizer treats `//` as a comment-start and skips to the next `\n`. Because the entity text has tabs instead of newlines, the comment swallows the entire remaining string and the tokenizer returns zero tokens.
5. `GetSpawnString("origin")` falls through to the entityDef lookup, which has no `origin` key, and returns `""`.
6. `ncSpawnPoint::Respawn()` runs `SetOriginUnstick(GetSpawnVector("origin"))`, producing `stov("")` → `(0,0,0)`, which **overwrites** the correctly engine-parsed origin field. `RestoreAngles()` later wipes the engine-parsed orientation the same way.

The BSP path works because q3map2 strips editor comments from the entity lump during compilation.

Evidence: a `SPAWNPROBE CheckSpawn` at entity-load time showed `__fullspawndata` containing `"origin" "16 -1040 -588"`, yet at spawn-selection time both the engine field and `GetSpawnVector("origin")` read `(0,0,0)`.

## Confirmed Fix

`src/shared/game/SpawnPoint.qc` — in `ncSpawnPoint::Respawn()`, fall back to the engine-parsed `origin` field when `GetSpawnVector("origin")` returns null:

```qc
vector spawnOrigin = GetSpawnVector("origin");
if (spawnOrigin == g_vec_null) {
    spawnOrigin = origin;
}
SetOriginUnstick(spawnOrigin);
```

The same tokenizer failure also wipes orientation: `ncEntity::RestoreAngles()` reads `GetSpawnString("angles")`/`GetSpawnFloat("angle")` through the identical broken path. The engine already converted the map's `"angle" "90"` key into the `angles` field (Quake anglehack), so `ncSpawnPoint::Respawn()` must keep that too:

```qc
vector spawnAngles = GetSpawnVector("angles");
if (spawnAngles == g_vec_null) {
    spawnAngles = angles;
}
SetAngles(spawnAngles);
```

This is deliberately minimal: the engine's own entity parser already sets `.origin` and `.angles` correctly from the map text; the bug was QC clobbering them with `(0,0,0)`.

Rebuild `base/progs.dat` (server) — the fix is in shared code compiled into it. A full engine process restart is required for the engine to pick up the new progs.

## What Did Not Fix It

- **Changing spawn Z only:** the origins were already correct in the file; placement was never reached.
- **Checking BSP presence:** a present `.bsp` does not change the raw `.map` load path.
- **`info_intermission` additions/removals:** the entities were already present; this was a value-corruption bug, not a missing-entity bug.
- **CRLF → LF line ending conversion:** the file was already LF-normalized (zero CR bytes). Not the cause.
- **Rebuilding progs alone:** the historical `Spawn_RepositionPlayersAtOrigin()` fix (commit `b496232`) was present and still did not help, because it retries the same broken `GetSpawnString("origin")` path.
- **Adding an engine-side raw `.map` parser fix:** not needed; the engine already parsed `.origin` correctly.

## Why This Works

`ncSpawnPoint::Respawn()` previously destroyed correct data. The fallbacks preserve the engine-parsed origin and orientation, so spawn selection finds a valid, non-zero position and `Spawn_PlaceAtSpot` teleports the player there, facing the intended direction. The compiled-BSP behavior is unchanged.

## Prevention

- When the tokenizer's `//` comment handling is the suspect, verify `m_rawSpawnData` contents at `CheckSpawn` time before changing map parsing or Z coordinates.
- Do not edit the raw `.map` parser as a first resort; the engine already produced a valid `.origin`.
- Add a regression check that asserts both `info_player_deathmatch` entities in `duel_alley.map` resolve to non-zero runtime origins on raw load (see `tools/check_duel_alley_spawns.py`).

## Related

- [Remote CSQC players stuck at world origin until movement](csqc-remote-player-stuck-at-world-origin.md) — a client-side replication issue; distinct from this server-side placement bug.
