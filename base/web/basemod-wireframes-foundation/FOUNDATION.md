# Foundation checkpoint

**Frozen baseline** — do not edit except to restore from.

This is a snapshot of the hand-wired Alien Swarm BaseMod wireframe (control IDs from SDK source, layout inferred from C++ `FindChildByName` calls). Use it as a revert target when experimenting on the L4D2 fork.

## Restore

```powershell
Copy-Item -LiteralPath "web\basemod-wireframes-foundation\*" `
  -Destination "web\basemod-wireframes\" -Recurse -Force
```

## Run

```bash
cd web/basemod-wireframes-foundation
python -m http.server 8080
```

## Sibling projects

| Directory | Purpose |
|---|---|
| `basemod-wireframes-foundation/` | This checkpoint (read-only baseline) |
| `basemod-wireframes/` | Original entry point (same as foundation at checkpoint time) |
| `basemod-wireframes-l4d2/` | Fork using extracted L4D2 `resource/ui/l4d360ui/*.res` layouts |
