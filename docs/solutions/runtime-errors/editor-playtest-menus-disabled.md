---
title: Editor playtests disabled pause and title menus
date: 2026-09-14
category: runtime-errors
tags: [godot, ftew, webcore, menu, startup]
---

## Cause

The editor launcher and lab launcher passed `webcore_menu_enabled 0` to prevent startup from replacing the requested world with the title backdrop. Once the engine implemented that switch, it also disabled every menu push: Escape could not open pause or return from the disconnected console to the title menu.

## Fix

Both launchers now pass `webcore_menu_enabled 1`. The maintained engine installer guards title requests while a server is running or loading, the client is signing on, or a connection is in progress. A local map is already the requested destination before the client reaches `ca_active`; title startup must not enqueue a background map during that interval. Pause requests remain available. Once disconnected, title requests can load the normal backdrop again.

The explicit menu-disable switch remains available for diagnostic callers. It should not be used for normal editor playtests.

## Verification

The cold-start audio regression now runs with menus enabled. `test_audio_launch.py --engine fteqw-world-menu-test.exe --map neden_1` passed: the requested map remained loaded, music advanced with nonzero sample levels, and the process exited normally. An interactive run subsequently loaded both the pause page and the title page after disconnecting. Computer Use was stopped by a physical Escape press before the final console-close check completed.

Rebuilt and installed `fteqw-world.exe`. Already-running clients retain the old executable until restarted.
