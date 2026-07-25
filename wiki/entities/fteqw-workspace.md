---
title: FTEQW Workspace
created: 2026-07-17
updated: 2026-07-17
type: entity
tags: [engine, reference-tree, webcore, lobby]
sources: [raw/articles/agents-md.md]
confidence: high
---

# FTEQW Workspace

Canonical engine tree for active WebCore / lobby work:

`C:\Users\sokky\Documents\Godot\bulwark_proto_funny\workspace\fteqw`

Do **not** use other nearby `fteqw` copies unless explicitly redirected.

## Common subtrees

- WebCore menu work: `workspace/fteqw/_worktrees/webcore-cpu-renderer/`
- Menu host: `m_webcore_menu.c`
- Lobby session C: `engine/common/lobby_session.c` / `.h` (+ backends)

## Related

- [[nuclide]] — runtime that consumes built `fteqw64.exe`
- [[webcore]] — plugin + host DLL
- [[lobby-session]] — mapless pre-game session direction
- [[rebuild-flow]] — build + copy into nuclide root
