#!/bin/sh
# Builds the playtest launcher.
#   ./build.sh linux     -> out/linux/playtest-launcher      (needs SDL2 dev files, libcurl headers)
#   ./build.sh windows   -> out/windows/playtest-launcher.exe (mingw-w64; SDL2 is linked in statically)
# Windows needs the SDL2 mingw dev package; set SDL2_MINGW to its x86_64-w64-mingw32 folder
# or let the script download it into .deps/.
set -eu
cd "$(dirname "$0")"
TARGET=${1:-linux}
SDL_VER=2.30.10
mkdir -p out/gen
python3 tools/embed_font.py out/gen/font_data.c src/fonts/DejaVuSans.ttf src/fonts/DejaVuSans-Bold.ttf
SRC="src/main.c src/update.c src/json.c src/sha256.c src/platform.c out/gen/font_data.c"
CFLAGS="-O2 -std=gnu11 -Wall -Wno-unused-function -Wno-format-truncation -Isrc"
VERSION=${LAUNCHER_VERSION:-dev}
case "$TARGET" in
linux)
	mkdir -p out/linux
	cc $CFLAGS -DPL_VERSION="\"$VERSION\"" $(sdl2-config --cflags) $SRC src/net_curl.c \
		-o out/linux/playtest-launcher \
		-Wl,-rpath,'$ORIGIN/lib' -Wl,-rpath,'$ORIGIN/game/lib' \
		$(sdl2-config --libs) -ldl -lm -lpthread
	strip out/linux/playtest-launcher
	echo "built out/linux/playtest-launcher"
	;;
windows)
	if [ -z "${SDL2_MINGW:-}" ]; then
		SDL2_MINGW=.deps/SDL2-$SDL_VER/x86_64-w64-mingw32
		if [ ! -f "$SDL2_MINGW/lib/libSDL2.a" ]; then
			mkdir -p .deps
			curl -fsSL -o .deps/sdl.tgz "https://github.com/libsdl-org/SDL/releases/download/release-$SDL_VER/SDL2-devel-$SDL_VER-mingw.tar.gz"
			tar -C .deps -xzf .deps/sdl.tgz
		fi
	fi
	mkdir -p out/windows
	x86_64-w64-mingw32-windres src/launcher.rc -O coff -o out/gen/launcher_res.o
	x86_64-w64-mingw32-gcc $CFLAGS -DPL_VERSION="\"$VERSION\"" -I"$SDL2_MINGW/include/SDL2" -Dmain=SDL_main \
		$SRC src/net_winhttp.c out/gen/launcher_res.o \
		-o out/windows/playtest-launcher.exe \
		-static -mwindows -L"$SDL2_MINGW/lib" -lmingw32 -lSDL2main -lSDL2 \
		-lwinhttp -lsetupapi -lwinmm -limm32 -lversion -lole32 -loleaut32 -lgdi32 -luser32 -lshell32 -luuid -lcfgmgr32 -lm
	x86_64-w64-mingw32-strip out/windows/playtest-launcher.exe
	echo "built out/windows/playtest-launcher.exe"
	;;
*) echo "usage: $0 linux|windows" >&2; exit 2 ;;
esac
