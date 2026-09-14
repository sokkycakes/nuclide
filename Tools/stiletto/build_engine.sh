#!/usr/bin/env bash
set -eu
export PATH="/c/msys64/mingw64/bin:/c/msys64/usr/bin:$PATH"
# Run from MSYS2 bash. Uses the existing ccache/MinGW toolchain, with isolated
# object output and no dependency on the old Slint/Skia UI build.
TASK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FTE_ROOT="$TASK_ROOT/../workspace/fteqw/_worktrees/webcore-cpu-renderer"
export PATH="/c/msys64/mingw64/bin:/c/msys64/usr/bin:$PATH"
export CC="/c/Users/sokky/AppData/Local/Microsoft/WinGet/Links/ccache.exe gcc"
export CXX="/c/Users/sokky/AppData/Local/Microsoft/WinGet/Links/ccache.exe g++"
export CCACHE_DIR="$TASK_ROOT/worldsrc/build/ccache"
mkdir -p "$TASK_ROOT/worldsrc/build"
TARGET=m-rel
BINARY=fteqw64.exe
OUTPUT=fteqw-world.exe
if [ "${1:-}" = "--server" ]; then
    TARGET=sv-rel
    BINARY=fteqwsv64.exe
    OUTPUT=fteqw-world-server.exe
fi
make -C "$FTE_ROOT/engine" -j8 "$TARGET" FTE_TARGET=win64 \
    BASE_DIR=. ARCH=x86_64-w64-mingw32 NATIVE_ABSBASE_DIR="$FTE_ROOT/engine" \
    RELEASE_DIR=release-world \
    HAVE_SLINT_UI= HAVE_GRIDA_UI= USE_OPUS=0 USE_SPEEX=0 USE_VORBISFILE=0 \
    LINK_FREETYPE=0 LINK_PNG=0 LINK_JPEG=0 LINK_ZLIB=0 \
    CFLAGS="-DNO_GNUTLS" > "$TASK_ROOT/worldsrc/build/engine-$TARGET-build.log" 2>&1
cp "$FTE_ROOT/engine/release-world/$BINARY" "$TASK_ROOT/$OUTPUT"
echo "Built isolated runtime: $TASK_ROOT/$OUTPUT"
