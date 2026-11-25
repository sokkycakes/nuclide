#!/bin/sh
# Builds the Bulwark engine for the Linux playtest build and lays it out the
# way the launcher runs it:
#   OUT/bulwark            the client (SDL2 and libstdc++ linked in)
#   OUT/bulwark-ded        the dedicated server (host-server.sh at the game
#                          root runs it; "bulwark -dedicated" does the same)
#   OUT/bwplug_*.so        engine plugins (loaded from next to the exe)
#   OUT/data/              engine data (Panorama ports of the web menus, fonts)
# Usage: tools/build_bulwark.sh /path/to/bulwark-engine OUT
# Needs the static SDL2 that ./build.sh linux builds into .deps/sdl-linux.
set -eu
SRC=$(cd "$1" && pwd)
OUT=$2
HERE=$(cd "$(dirname "$0")/.." && pwd)
SDL=$HERE/.deps/sdl-linux
[ -f "$SDL/lib/libSDL2.a" ] || { echo "run ./build.sh linux first (it builds SDL2)" >&2; exit 1; }
BUILD=$HERE/.deps/bulwark-build
cmake -S "$SRC" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release \
	-DSDL2_DIR="$SDL/lib/cmake/SDL2" \
	-DCMAKE_EXE_LINKER_FLAGS="-static-libstdc++ -static-libgcc" \
	-DCMAKE_SHARED_LINKER_FLAGS="-static-libstdc++ -static-libgcc" >/dev/null
cmake --build "$BUILD" -j"$(nproc)" --target bulwark bulwark-ded
# plugins are optional build targets; build whichever this tree has
for t in $(cd "$BUILD" && make help 2>/dev/null | sed -n 's/^\.\.\. \(bwplug_[A-Za-z0-9_]*\)$/\1/p'); do
	cmake --build "$BUILD" -j"$(nproc)" --target "$t"
done
mkdir -p "$OUT"
cp "$BUILD/bulwark" "$OUT/bulwark"
strip "$OUT/bulwark"
cp "$BUILD/bulwark-ded" "$OUT/bulwark-ded"
strip "$OUT/bulwark-ded"
for p in "$BUILD"/bwplug_*.so; do [ -f "$p" ] && cp "$p" "$OUT/" && strip "$OUT/$(basename "$p")"; done
rm -rf "$OUT/data"
cp -r "$SRC/data" "$OUT/data"
(cd "$SRC" && git rev-parse HEAD 2>/dev/null) > "$OUT/VERSION.txt" || true
echo "built $OUT ($(du -sh "$OUT" | cut -f1))"
# anything beyond libc/libm would have to be on every tester's machine
for exe in bulwark bulwark-ded; do
	if ldd "$OUT/$exe" | grep -v -E 'linux-vdso|libc\.so|libm\.so|ld-linux' | grep -q '=>'; then
		echo "warning: $exe links more than libc:" >&2; ldd "$OUT/$exe" >&2
	fi
done
