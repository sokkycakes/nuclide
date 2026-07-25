---
title: Lobby Session
created: 2026-07-17
updated: 2026-07-17
type: concept
tags: [lobby, session, lan, menu, webcore]
sources: [raw/articles/agents-md.md]
confidence: medium
---

# Lobby Session

Prefer pre-game **lobby/menu sessions** that do **not** force loading a gameplay map when FTE lobby/session APIs can avoid it (mapless / serverless until start).

## Active plans / docs (nuclide)

- `docs/brainstorms/2026-07-17-serverless-lobby-session-requirements.md`
- `docs/plans/2026-07-17-002-feat-serverless-lobby-session-plan.md`
- `docs/plans/2026-07-17-003-feat-mapless-webcore-lobby-plan.md`
- `docs/brainstorms/2026-07-17-webcore-lobby-ui-requirements.md`

Engine C lives in [[fteqw-workspace]] (and often the webcore worktree). UI under `base/data/web/lobby-menu/` and title-menu Create/Join flows — see [[webcore-ui]].

## Related

- [[webcore]]
- [[webcore-ui]]
- [[fteqw-workspace]]
- [[nuclide]]
