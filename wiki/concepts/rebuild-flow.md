---
title: Rebuild Flow
created: 2026-07-17
updated: 2026-07-17
type: concept
tags: [build, windows, engine, progs]
sources: [raw/articles/agents-md.md]
confidence: high
---

# Rebuild Flow

## Progs (QuakeC)

From nuclide root:

```bash
make game GAME=base
```

On Windows without `make` in PATH, use WSL bash for make, or:

```text
fteqcc.exe -srcfile base/src/server/progs.src
```

Outputs: `base/progs.dat`, `base/csprogs.dat`, `base/menu.dat`.

## Engine (FTE C)

From the active [[fteqw-workspace]]:

```bash
bash build_m_rel_ccache.sh
```

If CEF plugin changed: `cmd /c fteqw\rebuild_cef_plugin.bat`.

Copy to [[nuclide]] root:

```powershell
$src = "..\fteqw\engine\release"   # adjust to actual build-of-record
Copy-Item -LiteralPath "$src\fteqw64.exe" -Destination "fteqw64.exe" -Force
Copy-Item -LiteralPath "$src\fteplug_cef_x64.dll" -Destination "fteplug_cef_x64.dll" -Force
```

Prefer the workspace tree paths from [[fteqw-workspace]], not ad-hoc copies.

## Related

- [[nuclide]]
- [[fteqw-workspace]]
- [[webcore]]
