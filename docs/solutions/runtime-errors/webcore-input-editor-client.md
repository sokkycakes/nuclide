---
title: WebCore Join Lobby fields receive keys but do not edit
date: 2026-09-11
category: runtime-errors
tags: [webcore, input, clipboard, lobby]
---

## Symptoms and cause

The Room Code control in both `base/data/web/title-menu/` and `title-menu-v2/`
could receive focus and keyboard events, but its value remained empty.
Changing CSS selection rules or focusing the input did not complete editing.

The FTE WebCore host created its page with `pageConfigurationWithEmptyClients`.
The empty editor client has a no-op keyboard handler and rejects editing policy
requests. Embedders must supply an editor client that invokes WebCore insertion
and editing commands. There is no automatic default text insertion beneath that
empty client.

An intermediate fix also sent combined `KeyDown` events. This Windows port's
`PlatformKeyboardEvent::disambiguateKeyDownEvent` is unimplemented: Windows expects
separate `RawKeyDown` and `Char` events. The combined path produced two keydowns
and no keypress in a DLL test.

## Fix

The host at `../workspace/webcore-fte/Tools/FTE/host/fte_render_harness.cpp` now
installs an FTE-specific editor client, permits editing/selection, calls native
text insertion for printable characters, and executes editing commands for
selection movement, deletion, and Ctrl+A/C/X/V. It preserves separate Windows
events and suppresses character dispatch if the preceding keydown was handled.
Ctrl-letter control characters are normalized to useful DOM key names.

The shared EmptyEditorClient stays unchanged. There is no deferred JavaScript
value assignment and no blanket script clipboard permission. Native clipboard
commands use the existing Windows pasteboard implementation.

## Build and deployment

From the Nuclide root, run `Tools/build_webcore_host.cmd` with the existing
Visual Studio Build Tools installation. This is the local incremental host
build profile for `C:\w\wc-fte`; it uses the cached WebCore libraries and response
files. It excludes the obsolete FontCascade stub, whose implementation is
already in WebCore.lib, and does not use `/force:multiple`.

Copy the verified `C:\w\wc-fte\bin\ftewebcore.dll` to `nuclide/ftewebcore.dll`.
A running game must restart to load the new DLL. Keep the ICU resources beside
the executable as described in `webcore-hud-icu-data-missing.md`.

## Verification

Run `python Tools/test_webcore_input.py` to test the installed DLL. Set
`FTEWEBCORE_DLL` to test an alternate build. The test loads both actual menu pages
through the native resource callback, clicks the Room Code field using native
mouse input, and submits native keyboard events. It checks typing, Backspace,
Delete, selection/replacement, Ctrl+A/C/X/V, read-only and disabled fields,
cancelled keydown/keypress/beforeinput/paste, Unicode, and maxlength behavior.
Clipboard data is preserved in memory and restored; unsupported clipboard
formats cause the test to stop before modifying the clipboard.

Keep bridge diagnostic requests short: `fte_query` rejects requests whose
maximum UTF-8 buffer exceeds 4096 bytes. An unbounded event log made the test
appear to stop receiving answers after more keys; it was a test-report limit.

On 2026-09-11 both menu input scenarios and the existing timer, font-face, and
transparent-startup runtime tests passed. This verifies the native host and
shipped pages; remote multiplayer connectivity is a separate test.
