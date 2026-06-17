# Lobby mode registration (MenuQC)

Mods define lobby game modes and team layouts in MenuQC `m_init`. The engine exposes two builtins (see `fteextensions.qc`):

| Builtin | Purpose |
|---------|---------|
| `lobby_registermode(id, name, start_cmds)` | Register one mode. `start_cmds` is semicolon-separated console lines executed when the host starts the game (before `map`). |
| `lobby_addteam(mode_id, team_id, team_name, max_slots, is_spectator)` | Add a team to a mode. `is_spectator` is non-zero for spectator slots. |

## Example (`menu.src` / mod `m_init`)

```qc
void() m_init =
{
    // ... existing init ...

    lobby_registermode("DUEL", "Duel", "deathmatch 1; timelimit 10");
    lobby_addteam("DUEL", "player", "Players", 2, 0);
    lobby_addteam("DUEL", "spectator", "Spectators", 14, 1);
};
```

## Timing

- Modes are registered when `menu.dat` loads and `m_init` runs.
- The engine clears the registry in `Lobby_Init()`; each menu load repopulates it.
- If the lobby opens before `m_init` (e.g. console `lobby_create_offline` very early), the engine synthesizes a fallback mode from `lobby_defaultruleset` (default: `DUEL`) with `player` (1) + `spectator` (15).

## Rebuild `menu.dat`

From `fteqw/quakec/menusys`:

```bash
fteqcc -srcfile menu.src -o ../menu.dat
```

Copy `menu.dat` into the mod gamedir (e.g. nuclide root or `id1/`). FTEQW loads `menu.dat` automatically when present.

## Slint lobby UI

The host picks the mode in the RULESET row; the value stored is the mode **id** (`DUEL`, not the display name). Team columns in the roster follow `lobby_addteam` definitions for the active ruleset.
