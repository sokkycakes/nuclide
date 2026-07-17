# Window → L4D2 .res mapping

L4D2 ships BaseMod UI under `resource/ui/l4d360ui/` (Alien Swarm uses `Resource/UI/BaseModUI/`). Same `CBaseModFrame` / `LoadControlSettings` pattern.

| `WINDOW_TYPE` | L4D2 `.res` | Notes |
|---|---|---|
| `WT_MAINMENU` | `mainmenu.res` | `BtnGameModes` carousel, `BtnOptions`, flyouts |
| `WT_GAMESETTINGS` | `gamesettings_coopcreate.res` | Other modes: `gamesettings_*create.res` |
| `WT_GAMELOBBY` | `gamelobby.res` | Team mode: `teamlobby.res` |
| `WT_LOADINGPROGRESS` | `loadingprogress.res` | `Poster`, `ProTotalProgress` |
| `WT_INGAMEMAINMENU` | `ingamemainmenu.res` | Pause menu |
| `WT_VOTEOPTIONS` | `voteoptions.res` | |
| `WT_INGAMECHAPTERSELECT` | `ingamechapterselect.res` | |
| `WT_INGAMEDIFFICULTYSELECT` | `ingamedifficultyselect.res` | |
| `WT_GENERICCONFIRMATION` | `genericconfirmation.res` | Dynamic text uses JS fallback overlay |

## Flyouts (overlay)

| Command | `.res` |
|---|---|
| `FlmCampaignFlyout` | `campaignflyout.res` |
| `FlmOptionsFlyout` | `optionsflyout.res` |

Extracted files live in [`res/`](./res/). Offline JSON manifests in [`js/manifests/`](./js/manifests/) — regenerate with [`scripts/res_to_manifest.py`](./scripts/res_to_manifest.py) after re-extract.

Foundation hand-wired mapping (SDK-inferred): [`../basemod-wireframes-foundation/MAPPING.md`](../basemod-wireframes-foundation/MAPPING.md).
