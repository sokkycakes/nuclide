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
python3 tools/gen_steam_input.py out/gen/steam_input_data.c
SRC="src/main.c src/update.c src/json.c src/sha256.c src/platform.c src/input_steam.c src/steaminput.c out/gen/font_data.c out/gen/steam_input_data.c"
CFLAGS="-O2 -std=gnu11 -Wall -Wno-unused-function -Wno-format-truncation -Isrc"
VERSION=${LAUNCHER_VERSION:-dev}
case "$TARGET" in
linux)
	# SDL2 is built from source and linked in statically, so the launcher only
	# needs libc; SDL itself loads X11/Wayland/PulseAudio at run time.
	# SDL2_SYSTEM=1 links the system's libSDL2 instead.
	mkdir -p out/linux
	if [ "${SDL2_SYSTEM:-0}" = 1 ]; then
		SDL_CFLAGS=$(sdl2-config --cflags); SDL_LIBS=$(sdl2-config --libs)
	else
		PREFIX=$PWD/.deps/sdl-linux
		if [ ! -f "$PREFIX/lib/libSDL2.a" ]; then
			mkdir -p .deps
			[ -d .deps/SDL-src ] || { curl -fsSL -o .deps/sdl-src.tgz "https://github.com/libsdl-org/SDL/releases/download/release-$SDL_VER/SDL2-$SDL_VER.tar.gz" && tar -C .deps -xzf .deps/sdl-src.tgz && mv .deps/SDL2-$SDL_VER .deps/SDL-src; }
			cmake -S .deps/SDL-src -B .deps/sdl-build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
				-DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_STATIC_PIC=ON -DSDL_TEST=OFF -DSDL_RENDER_D3D=OFF >/dev/null
			cmake --build .deps/sdl-build -j"$(nproc)" >/dev/null
			cmake --install .deps/sdl-build >/dev/null
		fi
		SDL_CFLAGS="-I$PREFIX/include/SDL2 -D_REENTRANT"
		SDL_LIBS="$PREFIX/lib/libSDL2.a $(PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig pkg-config --static --libs-only-l sdl2 | sed 's/-lSDL2//')"
	fi
	cc $CFLAGS -DPL_VERSION="\"$VERSION\"" $SDL_CFLAGS $SRC src/net_curl.c \
		-o out/linux/playtest-launcher \
		-Wl,-rpath,'$ORIGIN/lib' $SDL_LIBS -ldl -lm -lpthread
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
