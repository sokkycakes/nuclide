---
title: Online room-code join times out on the same PC
date: 2026-09-11
category: runtime-errors
tags: [lobby, ice, mdns, networking]
---

## Reproduction and cause

An online host registered with the broker and displayed a room code. A second
client on the same PC found it and exchanged ICE offers/answers, but remained
in JOINING until the host-response timeout. The failure preceded lobby admission
and gameplay startup.

ICE hides private addresses behind generated mDNS `.local` names by default.
The responder looked up the global client/server aliases using `cls.sockets`
or `svs.sockets`. A mapless lobby owns a separate socket collection, so its
advertised alias was not answered from the collection actually hosting it.
The pre-fix logs showed successful broker signaling and public candidates but
no resolved local candidates or connected ICE route.

## Fix

In the canonical `workspace/fteqw/_worktrees/webcore-cpu-renderer` engine:

- `engine/common/net_ice.c`: scope each mDNS alias to its ICE session. Answer
  queries only for a live session's alias, enumerating `ICE_PickConnection(con)`.
  This covers lobby-owned and gameplay sockets without enabling global private
  address exchange or disabling encrypted connections.
- `engine/common/lobby_session.c`: copy the joiner's name before `Lobby_Create`.
  Retaining an `InfoBuf_ValueForKey` temporary across initialization previously
  changed the joining player's displayed name to `envtest`.

Both sources were synchronized to `C:\bld\fteqw_src2\engine\common` and rebuilt
with the existing `C:\w\wc-fte\rebuild_menu_console.sh` profile. The installed
`nuclide/fteqw64.exe` matches its build output.

## Verification

`Tools/test_online_lobby.ps1` launches a hidden host and joining client with
separate working directories and console logs. It uses the public broker and
the actual generated room code, verifies both clients list two players with
their original names, and waits through a 12-second heartbeat stability check.
It stops only the processes it creates. Test logs live under `_lobby_diag/`.

Before the change, the same-PC test timed out. Afterward, the logs showed mDNS
answers, local ICE candidates, connected ICE state, a join request, and host
acceptance. The host and client both reached WAITING with two players. The
final test also verified that the original player names survive synchronization.

This establishes same-PC online lobby admission. Joining from another internet
connection and the subsequent start-game handoff are separate end-to-end tests.
