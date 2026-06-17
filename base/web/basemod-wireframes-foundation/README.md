# Alien Swarm BaseMod UI Wireframe

Browser-playable wireframe of the Alien Swarm / L4D-style **BaseModUI** menu flow. Layout control IDs match `Resource/UI/BaseModUI/*.res` names referenced in the Alien Swarm SDK source; behavior mirrors `CBaseModPanel::OpenWindow` and panel `OnCommand` handlers.

## Run locally

From this directory:

```bash
# Python 3
python -m http.server 8080

# Or Node
npx --yes serve .
```

Open **http://localhost:8080** (or open `index.html` directly — ES modules not required).

## Try the flow

1. **Main Menu** — Co-op flyout → Start Campaign → Game Settings → Create lobby
2. **Lobby** — Start Game → loading bar → in-game HUD stub
3. Press **ESC** — pause menu (InGameMainMenu.res)
4. **Call a Vote** → VoteOptions → Change Scenario / Difficulty
5. **Exit to Main Menu** — confirmation dialog → back to main menu

The debug panel (right) shows active `WINDOW_TYPE`, navigation stack, and event log.

## Source references

- SDK: `sourcesdk_reference/AlienSwarm/src/game/client/swarm/gameui/swarm/`
- Mapping doc: [MAPPING.md](./MAPPING.md)

## Notes

- `.res` layout files ship inside game VPKs, not in the SDK checkout; wireframe regions are inferred from `FindChildByName` / `LoadControlSettings` calls in the C++ panel code.
- Visuals are intentionally minimal (dashed boxes, monospace labels).
