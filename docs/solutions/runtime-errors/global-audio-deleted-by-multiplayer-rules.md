---
title: Nonpositional audio removed as an NPC during multiplayer initialization
date: 2026-09-14
category: runtime-errors
tags: [godot, ftew, audio, multiplayer, startup]
---

## Symptoms

The AudioStreamPlayer exported correctly and its converted WAV contained real stereo audio, but `neden_1` had no music in normal play. Earlier tests loaded a map after startup and successfully exercised the decoder and controls. That did not reproduce a direct editor launch.

## Causes and fixes

1. `ambient_generic` inherits `ncTalkMonster`. Its parent initialization sets `FL_MONSTER`. Deathmatch, duel and other multiplayer rules call `Util_RemoveAllMonsters()` after map entity initialization, and that removed the nonpositional speaker before clients received it. The `_nonpositional` path now clears `FL_MONSTER` and disables damage during Respawn. Other ambient modes retain their existing behavior.
2. The launcher supplied `webcore_menu_enabled 0`, but the engine had no implementation for that setting. Startup could queue the title background map over the requested world and switch the rules to singleplayer. That also explains why delayed-map audio tests missed the multiplayer cleanup. The maintained installer now registers the switch, prevents menu pushes while disabled, and suppresses automatic title startup in `WebcoreMenu_Frame`. Its default remains enabled for ordinary game launches.

## Verification

`python Tools/stiletto/test_audio_launch.py --map neden_1` uses the editor's direct command-line map launch with explicit deathmatch rules. It verifies that the requested map remains loaded and that the music channel advances with nonzero decoded sample levels. The full playback/control fixture now also explicitly selects deathmatch instead of inheriting startup menu rules.

Rebuild the isolated client engine and both editor gamecode files, then restart the playtest. No audio conversion or scene-property changes are needed for this fix.

Follow-up: disabling menus also disabled Escape/pause and returning to the title screen. Editor launches now keep menus enabled and guard title requests during game loading instead; see [editor playtest menus disabled](editor-playtest-menus-disabled.md). The cold-start regression uses menus enabled.
