#!/bin/bash
# End-to-end test of publish + launcher, driven through a virtual controller.
#   tests/e2e.sh linux     uses out/linux/playtest-launcher (needs xvfb-run)
#   tests/e2e.sh windows   uses out/windows/playtest-launcher.exe under wine (needs xvfb-run, wine)
# Covers: first install, launch with manifest args, delta update after a new
# publish, removed files, kept user config, repair of a corrupted file,
# launcher self-update, offline play, and resume after an interrupted download.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
TARGET=${1:-linux}
WORK=${WORK:-$(mktemp -d /tmp/playtest-e2e.XXXXXX)}
PORT=${PORT:-$((20000 + RANDOM % 20000))}
PUB="python3 $HERE/tools/publish.py"
FAILS=0
mkdir -p "$WORK"
cd "$WORK"
echo "work dir: $WORK  port: $PORT"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }

# run_in CLIENTDIR ARGS...: starts that client's launcher under a virtual X server
if [ "$TARGET" = windows ]; then
	LAUNCHER_SRC=$HERE/out/windows/playtest-launcher.exe
	EXE=Launcher.exe
	export W=$WORK EXE
	# wine is started from a clean environment: some CI/container variables crash it
	WINE_ENV='env -i PATH=/usr/bin:/bin HOME="$W" WINEPREFIX="$W/wineprefix" WINEDEBUG=-all SDL_AUDIODRIVER=dummy DISPLAY="${DISPLAY:-}" XAUTHORITY="${XAUTHORITY:-}"'
	run_in() { local d=$1; shift; timeout 240 xvfb-run -a -s "-screen 0 1280x720x24" bash -c "$WINE_ENV wine \"\$@\"" _ "$d/$EXE" "$@" 2>/dev/null | tr -d '\r'; }
	cat > fakegame.c <<'EOF'
#include <stdio.h>
int main(int argc, char **argv) { FILE *f = fopen("launched.txt", "w"); fprintf(f, "launched:"); for (int i = 1; i < argc; i++) fprintf(f, " %s", argv[i]); fprintf(f, "\n"); fclose(f); return 0; }
EOF
	mkdir -p src
	x86_64-w64-mingw32-gcc -O1 -o src/fakegame.exe fakegame.c
	bash -c "$WINE_ENV wineboot -i" >/dev/null 2>&1
else
	LAUNCHER_SRC=$HERE/out/linux/playtest-launcher
	EXE=launcher
	run_in() { local d=$1; shift; SDL_AUDIODRIVER=dummy timeout 240 xvfb-run -a -s "-screen 0 1280x720x24" "$d/$EXE" "$@" 2>&1; }
	mkdir -p src
	printf '#!/bin/sh\ncd "$(dirname "$0")"\necho "launched: $*" > launched.txt\n' > src/fakegame
	chmod +x src/fakegame
fi
run_launcher() { run_in client "$@"; }

# ---- game content v1
mkdir -p src/base/maps src/base/cfg rel
head -c 60000000 /dev/urandom > src/base/maps/big.bsp
python3 - <<'EOF'
import random
random.seed(1)
open('src/base/progs.dat', 'w').write('progs v1\n' * 50000)
open('src/base/cfg/default.cfg', 'w').write('bind w +forward\n')
open('src/base/empty.txt', 'w').write('')
for i in range(300):
    open(f'src/base/maps/m{i}.txt', 'w').write(('map %d ' % i) * random.randint(10, 3000))
# identical files (locale copies, placeholder textures) share one blob in the pack
import os
os.makedirs('src/base/dup', exist_ok=True)
for i in range(40):
    open(f'src/base/dup/same{i}.txt', 'w').write('same content\n' * 2000)
# an engine build per system: each client downloads only its own
for o in ('linux', 'windows'):
    os.makedirs(f'src/engine-{o}', exist_ok=True)
    open(f'src/engine-{o}/engine.txt', 'w').write(o * 100000)
EOF
cat > rules.json <<'EOF'
{"game": "test", "title": "Test Game", "include": ["**"], "exclude": ["launched.txt", "*.c"],
 "exec": ["fakegame"], "keep": ["base/cfg/*.cfg"],
 "only": {"linux": ["engine-linux/**"], "windows": ["engine-windows/**"]},
 "run": {"linux": {"exe": "fakegame", "args": ["-game", "base", "+map", "start"]},
         "windows": {"exe": "fakegame.exe", "args": ["-game", "base", "+map", "start"]}}}
EOF
$PUB --src src --rules rules.json --out rel/playtest --version v1 --notes "First build" --launcher-$TARGET "$LAUNCHER_SRC" >/dev/null 2>&1

python3 "$HERE/tools/test_server.py" rel --port "$PORT" > server.log 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 1

mkdir -p client
cp "$LAUNCHER_SRC" "client/$EXE"
cat > client/launcher.json <<EOF
{"title": "Test Game", "manifest_url": "http://127.0.0.1:$PORT/owner/repo/releases/download/playtest/manifest.json",
 "install_dir": "game", "close_on_play": false, "connections": 6}
EOF
stats() { curl -s "http://127.0.0.1:$PORT/stats" | python3 -c "import json,sys;print(json.load(sys.stdin)['bytes'])"; }
reset_stats() { curl -s "http://127.0.0.1:$PORT/reset-stats" >/dev/null; }

# ---- 1. first install with the controller, then play
cat > s1.txt <<'EOF'
wait ready 120
expect_local_version v1
expect_pad
expect_focus play
shot shot-ready.bmp
press dpdown
expect_focus check
press dpdown
expect_focus verify
press dpup
press dpup
expect_focus play
press a
sleep 1500
expect_launched
EOF
run_launcher --test-script s1.txt > s1.log
check "first install via controller" "grep -q 'TEST RESULT: PASS' s1.log"
check "game launched with manifest args" "grep -q 'launched: -game base +map start' client/game/launched.txt"
check "installed files match" "cmp -s src/base/maps/big.bsp client/game/base/maps/big.bsp && cmp -s src/base/maps/m7.txt client/game/base/maps/m7.txt && [ -f client/game/base/empty.txt ] && cmp -s src/base/dup/same0.txt client/game/base/dup/same39.txt"
OTHER=$([ "$TARGET" = linux ] && echo windows || echo linux)
check "only this system's engine files installed" "cmp -s src/engine-$TARGET/engine.txt client/game/engine-$TARGET/engine.txt && [ ! -e client/game/engine-$OTHER ]"

# ---- 2. new build: one changed file, one new, one removed; user edited a kept config
reset_stats
python3 -c "open('src/base/progs.dat','w').write('progs v2\n' * 50000)"
echo "new map" > src/base/maps/new.txt
rm src/base/maps/m5.txt
echo "bind w +jump" > client/game/base/cfg/default.cfg
$PUB --src src --rules rules.json --out rel/playtest --version v2 --notes "Fix lunge hitbox" >/dev/null 2>&1
reset_stats
cat > s2.txt <<'EOF'
wait ready 120
expect_local_version v2
EOF
run_launcher --test-script s2.txt > s2.log
check "update to v2" "grep -q 'TEST RESULT: PASS' s2.log"
check "changed file updated" "cmp -s src/base/progs.dat client/game/base/progs.dat"
check "new file added" "cmp -s src/base/maps/new.txt client/game/base/maps/new.txt"
check "removed file deleted" "[ ! -e client/game/base/maps/m5.txt ]"
check "user config kept" "grep -q jump client/game/base/cfg/default.cfg"
B=$(stats)
check "delta download is small ($B bytes, full build is 60 MB)" "[ $B -lt 1000000 ]"

# ---- 3. corrupt a file, repair through the menu
printf 'garbage' > client/game/base/maps/m9.txt
touch -d '2001-01-01' client/game/base/maps/m9.txt
cat > s3.txt <<'EOF'
wait ready 120
press dpdown
press dpdown
expect_focus verify
press a
sleep 300
wait ready 120
EOF
run_launcher --test-script s3.txt > s3.log
check "repair via controller" "grep -q 'TEST RESULT: PASS' s3.log"
check "corrupted file restored" "cmp -s src/base/maps/m9.txt client/game/base/maps/m9.txt"

# ---- 4. launcher self-update
cp "$LAUNCHER_SRC" newlauncher
printf 'self-update-test-padding' >> newlauncher   # different bytes, still a valid program
$PUB --src src --rules rules.json --out rel/playtest --version v3 --notes "New launcher" --launcher-$TARGET newlauncher >/dev/null 2>&1
cat > s4.txt <<'EOF'
wait ready 120
expect_local_version v3
EOF
run_launcher --test-script s4.txt > s4.log
sleep 3
check "launcher restarted after self-update" "grep -q 'restarting after self-update' s4.log && grep -q 'TEST RESULT: PASS' s4.log"
check "launcher binary replaced" "cmp -s newlauncher client/$EXE"
check "old launcher cleaned up" "[ ! -e client/$EXE.old ]"

# ---- 5. offline: server gone, installed game still plays
kill $SERVER; sleep 1
rm -f client/game/launched.txt
cat > s5.txt <<'EOF'
wait offline 60
expect_focus play
press start
sleep 1500
expect_launched
EOF
run_launcher --test-script s5.txt > s5.log
check "offline play" "grep -q 'TEST RESULT: PASS' s5.log && [ -f client/game/launched.txt ]"

# ---- 6. interrupted first install resumes
python3 "$HERE/tools/test_server.py" rel --port "$PORT" --rate 1000000 > server.log 2>&1 &
SERVER=$!
sleep 1
mkdir -p client2
cp client/$EXE client2/$EXE
cp client/launcher.json client2/launcher.json
reset_stats
cat > s6a.txt <<'EOF'
sleep 9000
quit
EOF
run_in client2 --test-script s6a.txt >/dev/null
FIRST=$(stats)
cat > s6b.txt <<'EOF'
wait ready 120
expect_local_version v3
EOF
reset_stats
run_in client2 --test-script s6b.txt > s6b.log
SECOND=$(stats)
check "resume finishes the install" "grep -q 'TEST RESULT: PASS' s6b.log && cmp -s src/base/maps/big.bsp client2/game/base/maps/big.bsp"
FULL=$(python3 -c "import json;print(sum(p['size'] for p in json.load(open('rel/playtest/manifest.json'))['packs']))")
check "resume skips finished chunks (full $FULL, first try $FIRST, second $SECOND bytes)" "[ $FIRST -gt 0 ] && [ $SECOND -lt $((FULL / 2)) ]"

# ---- 7. Steam non-Steam-game / SteamOS Game Mode: fullscreen, controller, game keeps Steam's process
rm -f client2/game/launched.txt
cat > s7.txt <<'EOF'
wait ready 120
expect_focus play
shot shot-steam.bmp
press a
EOF
if [ "$TARGET" = windows ]; then
	run_in client2 --steam --test-script s7.txt > s7.log
	check "steam mode: game started and waited on" "grep -q 'steam mode' s7.log && grep -q 'launched .*(attached)' s7.log && [ -f client2/game/launched.txt ]"
else
	SteamGameId=12345678 run_in client2 --test-script s7.txt > s7.log
	check "steam mode detected from SteamGameId, launcher replaced by the game" "grep -q 'steam mode' s7.log && grep -q '^exec ' s7.log && grep -q 'launched: -game base +map start' client2/game/launched.txt"
fi

# ---- 8. server answers some requests with 429 (GitHub rate limit): install still finishes
kill $SERVER 2>/dev/null; wait $SERVER 2>/dev/null
python3 "$HERE/tools/test_server.py" rel --port "$PORT" --fail-every 4 > server.log 2>&1 &
SERVER=$!
sleep 1
mkdir -p client3
cp client/$EXE client3/$EXE
cp client/launcher.json client3/launcher.json
reset_stats
printf 'wait ready 200\nexpect_local_version v3\n' > s8.txt
run_in client3 --test-script s8.txt > s8.log
R=$(curl -s "http://127.0.0.1:$PORT/stats" | python3 -c "import json,sys;print(json.load(sys.stdin)['refused'])")
check "install survives HTTP 429 ($R requests refused)" "[ $R -gt 0 ] && grep -q 'TEST RESULT: PASS' s8.log && cmp -s src/base/maps/big.bsp client3/game/base/maps/big.bsp && cmp -s src/base/dup/same0.txt client3/game/base/dup/same7.txt"

echo
if [ $FAILS -eq 0 ]; then echo "ALL PASSED ($TARGET)"; else echo "$FAILS FAILED ($TARGET); logs in $WORK"; fi
exit $FAILS
