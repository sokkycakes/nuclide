# Project LLM Wiki + OKF

Shared knowledge for **Hermes** and **Cursor** working this repo in parallel.

## Two layers

| Layer | Path | Purpose |
|-------|------|---------|
| **LLM wiki** (Karpathy / Hermes `llm-wiki` skill) | `wiki/` | Curated, interlinked markdown about systems, prefs, paths |
| **OKF bundle** (hermes-okf memory) | `wiki/okf/` | Agent session memory: decisions, observations, snapshots |

Hermes config (machine-local):

- `WIKI_PATH` → this `wiki/` directory (`%HERMES_HOME%\.env`)
- `memory.provider: hermes-okf` with `bundle_path` → `wiki/okf/`

## Hermes session habit

1. Orient: read `SCHEMA.md`, `index.md`, recent `log.md`
2. Search wiki before grepping the whole tree for settled facts
3. Ingest new decisions/docs into wiki pages; append `log.md`
4. OKF memory runs automatically once the provider is active

## CLI checks

```powershell
hermes memory status
# Provider should be hermes-okf ← active

$py = "$env:LOCALAPPDATA\hermes\hermes-agent\venv\Scripts\python.exe"
& $py -m hermes_okf.cli search --path wiki/okf "lobby"
& $py -m hermes_okf.cli context --path wiki/okf "WebCore HUD"
```

## Seeded from

- `AGENTS.md` → `raw/articles/agents-md.md` plus entity/concept pages under `entities/`, `concepts/`, `comparisons/`
