---
title: "FTEQCC virtual ReceiveEntity dispatch causes CSQC player underreads"
date: 2026-07-18
type: fix
severity: critical
module: "CSQC player replication"
category: networking-protocol
affected_runtime: FTEQW-CSQC
tags:
  - fteqw
  - quakec
  - csqc
  - networking
  - virtual-dispatch
  - lobby
problem_type: runtime_error
status: resolved
---

# FTEQCC virtual `ReceiveEntity` dispatch causes CSQC player underreads

## Summary

The lobby-to-game transition exposed a state-dependent CSQC player replication failure. Player updates initially decoded correctly, then began consuming only part of each sized entity payload:

```text
244/244
64/64
64/64
13/64
13/64 ...
```

The server and client received identical bytes. The failure occurred because the `ENT_PLAYER` dispatcher called the virtual method `ncPlayer::ReceiveEntity(float,float)`, whose signature collided with the inherited `ncSpectator::ReceiveEntity(float,float)`. FTEQCC dispatch eventually stopped invoking the player decoder even though the entity still reported `classname=ncPlayer` and `declclass=hero_collier`.

The fix was to give the fixed `ENT_PLAYER` wire decoder a unique, nonvirtual name: `ReceivePlayerEntity(float,float)`.

## Symptoms

The first full player update and the first two delta updates consumed their complete sized payloads. Every later delta update underread at the same boundary:

```text
CSQC underread entity 1
payload: 64 bytes
consumed: 13 bytes
```

An illegible-server-message disconnect was also observed during the wider startup investigation, but it must not be assumed to follow from this warning: FTE's sized CSQC parser skips the unread remainder of a length-delimited entity payload. This document covers the proven player underread. The lobby appeared responsible because it reliably reached the map transition that activated player replication, but the lobby transport did not corrupt the payload.

Visible class state was misleading:

```text
classname=ncPlayer
declclass=hero_collier
```

Those strings remained correct while the effective virtual receiver changed.

## Impact and scope

This affected the special `ENT_PLAYER` receive path in `src/client/entities.qc`. That discriminator has one fixed wire schema: the schema written by `ncPlayer::SendEntity` and read by the player decoder.

This document does **not** establish that all virtual `ReceiveEntity` methods are unsafe. The specific hazard is using one inherited virtual signature for classes that interpret the same changed-mask bits as different payload schemas.

Hero names such as `hero_collier` are entityDefs, not QC subclasses overriding the player decoder. There was no legitimate polymorphic extension point to preserve for this path.

## Reproduction

The reliable reproduction was the lobby-to-game handoff:

1. Start FTEQW with `+game base` and create a LAN lobby with `lobby_create_lan`.
2. Ready the lobby and allow the countdown to start the configured map.
3. Let the local `hero_collier` player receive repeated full and delta `ENT_PLAYER` updates.
4. At the CSQC sized-entity boundary, record the announced payload size and the bytes consumed by `CSQC_Ent_Update`.

Before the fix, the sequence settled into a permanent underread after three successful updates:

```text
244/244
64/64
64/64
13/64
13/64 ...
```

The delayed onset matters. A smoke test that validates only the initial full update will miss the problem.

## Root cause

The original dispatcher code was equivalent to:

```qc
case ENT_PLAYER:
    ncPlayer pl = (ncPlayer)self;
    /* setup and prediction omitted */
    float changed = readfloat();
    pl.ReceiveEntity(new, changed);
    break;
```

`ncPlayer` derives from `ncSpectator`, and both classes used the signature:

```qc
virtual void ReceiveEntity(float,float);
```

The network discriminator already determines the schema, but the final decoder selection was delegated to FTEQCC virtual dispatch. After several updates, dispatch no longer entered `ncPlayer::ReceiveEntity`. The generic dispatcher still selected `ENT_PLAYER` and returned normally, leaving most of the sized payload unread.

`classname` and `declclass` did not expose the active virtual target. They are ordinary visible entity state, not proof of FTEQCC's effective method dispatch metadata.

## Evidence

### Sender and transport were correct

Native boundary probes captured the SSQC payload before packet insertion and the identical bytes at the CSQC sized-entity boundary. Payload size and changed mask matched on both sides.

The delta changed mask was `397322` (`0x6100a`). The mask is written with `WriteFloat`, so its four on-wire bytes must be decoded as an IEEE-754 float before integer flag interpretation.

### The player receiver stopped being entered

Bounded QC checkpoint globals were read immediately after `PR_ExecuteProgram`. The dispatcher counter continued advancing, but the `ncPlayer` receiver counter froze after its third invocation:

```text
consumed=244/244  player_reads=1  receiver_complete=yes
consumed=64/64    player_reads=2  receiver_complete=yes
consumed=64/64    player_reads=3  receiver_complete=yes
consumed=13/64    player_reads=3  receiver_complete=stale
```

At the short reads:

- `ClientGame_EntityUpdate` returned false;
- the generic dispatcher selected `ENT_PLAYER`;
- `Entity_EntityUpdate` completed normally;
- `msg_badread` remained false;
- `ncPlayer::ReceiveEntity` was not entered.

This isolated the fault to the final method dispatch.

### The nonvirtual A/B test exposed the inherited receiver

Changing only `ncPlayer::ReceiveEntity` from `virtual` to `nonvirtual` did **not** fix the bug. It made every delta consume `18/64` instead.

That byte count identified `ncSpectator::ReceiveEntity`:

- 1 byte: `ENT_PLAYER` discriminator;
- 4 bytes: player changed mask;
- 12 bytes: spectator velocity selected by bit 1;
- 1 byte: spectator mode selected by bit 3.

The relevant inherited flag layout is in `src/shared/game/Spectator.h`:

```qc
typedef enumflags
{
    SPECFL_ORIGIN,
    SPECFL_VELOCITY,
    SPECFL_TARGET,
    SPECFL_MODE,
    SPECFL_FLAGS,
    SPECFL_TYPE,
} ncSpectatorFlags_t;
```

Interpreting the player mask `0x6100a` as spectator flags selects `SPECFL_VELOCITY` and `SPECFL_MODE`, exactly accounting for the 13 bytes consumed by the spectator receiver after the five-byte player wrapper.

This proved that changing the qualifier while retaining the inherited signature could expose the base virtual instead of forcing the player implementation.

## What did not work

### Rebuilding only to rule out stale DATs

A coherent rebuild was necessary to rule out stale bytecode, but fresh `progs.dat` and `csprogs.dat` reproduced the failure. Rebuilding was diagnostic, not the fix.

### Blaming the lobby transport

The same payload bytes arrived at both serialization boundaries. The lobby only made the transition reproducible; it was not truncating or rewriting CSQC data.

### Bypassing prediction

Temporarily bypassing `Predict_EntityUpdate(pl, new)` produced the same sequence:

```text
244/244, 64/64, 64/64, 13/64 ...
```

Prediction replay was restored immediately and removed from the suspect list.

### Blaming the game-specific dispatcher override

Instrumentation showed `ClientGame_EntityUpdate` returned false and the generic `ENT_PLAYER` branch completed on every affected update.

### Marking the player method nonvirtual without renaming it

The inherited signature still controlled resolution. The client consistently invoked the spectator reader and consumed `18/64`.

## Solution

Use a unique nonvirtual decoder for the fixed player wire schema.

Declaration in `src/shared/game/Player.h`:

```qc
nonvirtual void ReceivePlayerEntity(float,float);
```

Definition in `src/shared/game/Player.qc`:

```qc
void
ncPlayer::ReceivePlayerEntity(float isNew, float flChanged)
{
    /* Existing player payload reader. */
}
```

Direct call in `src/client/entities.qc`:

```qc
case ENT_PLAYER:
    ncPlayer pl = (ncPlayer)self;
    /* setup and prediction omitted */
    float changed = readfloat();
    pl.ReceivePlayerEntity(new, changed);
    break;
```

The production change is intentionally small: one declaration rename, one definition rename, and one call-site rename.

## Why this works

`ENT_PLAYER` already identifies the wire schema. A uniquely named nonvirtual method makes decoder selection agree with protocol selection:

```text
ENT_PLAYER -> ReceivePlayerEntity -> player payload schema
```

There is no inherited virtual lookup and no chance for the changed mask to be interpreted using spectator flags.

Gameplay behavior remains polymorphic where appropriate. Only the protocol-fixed player decoder is direct.

## Verification

The exact lobby create/ready/map transition was rerun with bounded sender and receiver traces. After the fix:

```text
244/244
64/64 x 15
```

All 16 captured player updates consumed their complete payloads:

- no CSQC underreads;
- no CSQC overreads;
- no illegible server message;
- the player receiver entered and completed on every update.

The final clean client QC and engine builds completed successfully. The engine build used ccache as required. Temporary QC globals, native packet probes, trace files, and helper launchers were removed after verification.

## Diagnostic guidance for similar failures

When a sized CSQC entity begins underreading only after several successful updates:

1. Capture the same payload at the SSQC writer and CSQC reader boundaries.
2. Record `ENT_*`, payload size, changed mask, consumed bytes, callback return, and `msg_badread`.
3. Account for wrapper bytes before interpreting the read count. Nuclide's player wrapper consumes one discriminator byte and one four-byte changed mask.
4. Add bounded counters at each dispatch layer. An advancing dispatcher counter with a frozen class-receiver counter indicates bypassed or changed method dispatch.
5. Do not use `classname` or `declclass` as proof of the virtual target.
6. Temporarily isolate prediction or game overrides one at a time; restore each immediately when exonerated.
7. If making a derived method nonvirtual selects a base reader, stop changing qualifiers and remove the inherited signature collision with a unique method name.
8. Remove all instrumentation and coherently rebuild affected VMs after the root cause is fixed.

## Prevention

For each fixed `ENT_*` discriminator:

- treat the discriminator as the authority for decoder selection;
- avoid inherited virtual decoder names when base and derived classes use different flag layouts;
- use a unique nonvirtual decoder when no legitimate subclass override exists;
- when rebuilding `csprogs.dat` for this rename, **do not** stash or exclude the companion weapon/viewmodel readiness changes in `Player.qc` / `Weapon.qc` / `View.qc` / `viewmodel.qc` — correct `ENT_PLAYER` decoding surfaces half-ready weapon edicts that those layers guard (see `csqc-viewmodel-invisible-after-arena-spectate.md`);
- verify subclass claims against QC class declarations, not entityDef names;
- add byte-count checks to reproduction traces before changing wire fields;
- rebuild both QC VMs after shared class-layout, include-order, enum, or virtual declaration changes.

## Related documentation

- [Solutions index](../README.md)
- [Networking](../../../Documentation/Networking.md)
- [Lobby implementation notes](../../notes/2026-07-17-lobby-plan003-implementation.md)
- [Mapless WebCore lobby plan](../../plans/2026-07-17-003-feat-mapless-webcore-lobby-plan.md)
- [Spectator target cycling notes](../../deferred/spectator-target-cycling.md)
- Player dispatcher: `src/client/entities.qc`
- Player declaration: `src/shared/game/Player.h`
- Player serializer/decoder: `src/shared/game/Player.qc`
- Spectator flag schema: `src/shared/game/Spectator.h`
- Spectator serializer/decoder: `src/shared/game/Spectator.qc`
