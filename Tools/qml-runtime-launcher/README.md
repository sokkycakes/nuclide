# Nuclide QML Runtime Launcher

A Windows launcher template for an editable QML frontend with all Qt runtime
files tucked into a sibling `runtime/` directory.

The visible entry point is a tiny, non-Qt `NuclideLauncher.exe`. It starts
`runtime/qml.exe app/main.qml`. This matters on Windows: an EXE linked to Qt
needs `Qt6*.dll` before its `main()` runs, so it cannot relocate those DLLs into
a subdirectory by calling `AddDllDirectory()` from inside `main()`.

## Release layout

```text
NuclideLauncher/
├── NuclideLauncher.exe   # the only EXE a playtester launches
├── app/
│   └── main.qml          # editable QML frontend
└── runtime/
    ├── qml.exe           # Qt's generic QML interpreter
    ├── Qt6*.dll
    ├── plugins/
    │   └── platforms/qwindows.dll
    ├── qml/
    └── qt.conf
```

The bootstrap deliberately has no Qt dependency. Because `qml.exe` lives in
`runtime/`, Windows resolves its Qt DLL imports there automatically. `qt.conf`
sets the local plugin and QML module paths.

## Build the bootstrap

Only a Windows C compiler and CMake are required for this part; Qt is **not**
needed to build the bootstrap.

From this directory in a Visual Studio developer shell:

```powershell
cmake -S . -B build
cmake --build build --config Release
```

For a single-config generator, the output is usually
`build/NuclideLauncher.exe`. For Visual Studio generators it is normally
`build/Release/NuclideLauncher.exe`; copy it to `build/NuclideLauncher.exe` or
pass a matching `-BuildDirectory` to the packaging script.

## Package a private Qt runtime

No system-wide Qt installation is required. By default the packaging script:

1. downloads the pinned Qt 6.8.0 MSVC 2022 x64 component archives directly
   from Qt's public package repository;
2. verifies every archive against its Qt-hosted SHA-1 checksum;
3. downloads the standalone `7zr.exe` extractor from 7-Zip's official site;
4. caches the kit and downloads in `.qt-cache/` (ignored by Git); and
5. uses the kit's `qml.exe` and `windeployqt.exe` to create the private runtime
   below `dist/runtime/`.

It needs only Windows PowerShell and network access for the one-time download.
It does **not** require Python, `aqtinstall`, or a system-wide Qt installation:

```powershell
.\scripts\package-runtime.ps1
```

The downloaded components include Qt Base, Declarative/Quick Controls, Tools,
SVG, and the Qt-provided graphics fallback libraries. Repeat runs reuse
`.qt-cache/`. Pass `-RefreshQt` to discard and redownload the cached Qt archives
and extracted kit. The cached standalone `7zr.exe` is retained.

For offline builds or CI with a pre-provisioned kit, retain the explicit override:

```powershell
.\scripts\package-runtime.ps1 -QtBin 'C:\Qt\6.8.0\msvc2022_64\bin'
```

The script copies `qml.exe`, `app/`, and the compiled bootstrap to `dist/`, then
uses `windeployqt` to collect only the needed DLLs, plugins, QML imports, and,
when discoverable, the MSVC runtime beneath `dist/runtime/`. If `windeployqt`
cannot find the compiler runtime, the script prints a warning. Such a package
requires the current x64 Microsoft Visual C++ Redistributable on the target PC;
the Qt runtime itself remains private and needs no installation.

Start the packaged application with:

```powershell
.\dist\NuclideLauncher.exe
```

## Next step: real updater behavior

`app/main.qml` is an intentionally visual prototype. It simulates an update and
has no download, hash validation, replacement, or engine-launch code yet. For a
real playtester updater, keep the QML UI external and add a small native helper
(or a dedicated updater executable) that owns HTTP downloads, SHA-256
verification, atomic file replacement, and launching `engine/fteqw64.exe`.

The QML runtime is a good UI host, but it should not be trusted with updater
privileges or package validation on its own.

## Qt licensing

This uses Qt's open-source packages. Before distributing a release, include the
applicable Qt LGPL license notices and allow replacement of the loose Qt runtime
libraries in `runtime/`. Review the Qt licensing terms for the exact Qt version
you ship.
