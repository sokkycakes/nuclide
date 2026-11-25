#!/bin/bash
# Steam Input in the launcher, against a stand-in libsteam_api
# (tests/mock_steam_api.c; Steam can't sign in on a build machine).
#   tests/steam_input.sh        uses out/linux/playtest-launcher (needs xvfb-run)
# Covers: a non-Steam-game launch with Steam running starts ISteamInput as
# app 480 with the launcher's action manifest, a Steam Deck moves the focus,
# prompts follow what is bound on the Deck, Steam's copy of the pad in SDL
# is ignored; without Steam the launcher reads SDL with that pad's prompts.
set -u
HERE=$(cd "$(dirname "$0")/.." && pwd)
LAUNCHER=$HERE/out/linux/playtest-launcher
WORK=$(mktemp -d /tmp/playtest-steam.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
FAILS=0
pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }
expect() { if grep -qF -- "$3" "$WORK/$2"; then pass "$1"; else fail "$1 (no \"$3\" in $2)"; sed 's/^/    /' "$WORK/$2" | tail -20; fi; }

cc -shared -fPIC -O1 -o "$WORK/libsteam_api.so" "$HERE/tests/mock_steam_api.c" || exit 1
mkdir -p "$WORK/client"
cp "$LAUNCHER" "$WORK/client/launcher"
# nothing answers on this port: the launcher ends up offline with nothing installed
cat > "$WORK/client/launcher.json" <<'EOF'
{"title": "Test Game", "manifest_url": "http://127.0.0.1:9/manifest.json", "install_dir": "game"}
EOF
# a shortcut's CGameID: (crc | 0x80000000) << 32 | type 2 << 24
SHORTCUT_ID=15386537552735371264

run() { # run <name> [VAR=value...]; launcher script in $WORK/<name>.txt
	local name=$1; shift
	(cd "$WORK/client" && env -i PATH="$PATH" HOME="$WORK" SDL_AUDIODRIVER=dummy MOCK_STEAM_LOG="$WORK/$name.mock" "$@" \
		timeout 120 xvfb-run -a -s "-screen 0 1280x720x24" ./launcher --test-script "$WORK/$name.txt" > "$WORK/$name.log" 2>&1)
}

# 1. Non-Steam game, Steam running, a Steam Deck
cat > "$WORK/deck.mock.txt" <<'EOF'
connect 7 14
origins ui_select 333
origins ui_back 334
origins ui_down 345
EOF
cat > "$WORK/deck.txt" <<'EOF'
wait error 60
expect_steam_input 1
expect_pad
sleep 500
expect_prompt select steamdeck/south
expect_prompt back steamdeck/east
expect_focus check
sleep 4000
expect_focus verify
# Steam's virtual gamepad as SDL sees it: the same Deck, so not read twice
press dpdown
sleep 300
expect_focus verify
EOF
: > "$WORK/deck.mock"
run deck SteamGameId=$SHORTCUT_ID BW_STEAM_API_LIB="$WORK/libsteam_api.so" MOCK_STEAM_SCRIPT="$WORK/deck.mock.txt" &
# the Deck presses down once the launcher has settled (the stand-in reads
# lines added to its script while it runs)
for i in $(seq 1 600); do grep -q "ok: focus check" "$WORK/deck.log" 2>/dev/null && break; sleep 0.1; done
printf 'press 7 ui_down\nwait 4\nrelease 7 ui_down\n' >> "$WORK/deck.mock.txt"
wait
expect "launcher script passes" deck.log "TEST RESULT: PASS"
expect "non-Steam game: Steam API started as app 480" deck.mock "init appid=480 gameid=480"
expect "launcher manifest loaded" deck.mock "sets=1 actions=9"
expect "launcher action set active" deck.mock "activate 7 Launcher"
expect "status names the launch" deck.log "ISteamInput on app 480 (non-Steam game)"
expect "manifest written beside the game" deck.log "game/.launcher/steam_input/steam_input_manifest.vdf"

# 2. Steam isn't running: SDL, with the pad's own prompts
printf 'wait error 60\nexpect_steam_input 0\nexpect_prompt select xbox/south\npress dpdown\nsleep 200\nexpect_focus verify\n' > "$WORK/nosteam.txt"
: > "$WORK/nosteam.mock"
run nosteam MOCK_STEAM_RUNNING=0 BW_STEAM_API_LIB="$WORK/libsteam_api.so"
expect "SDL path passes" nosteam.log "TEST RESULT: PASS"
expect "says Steam isn't running" nosteam.log "Steam isn't running"

# 3. No libsteam_api at all
printf 'wait error 60\nexpect_steam_input 0\nexpect_pad\n' > "$WORK/nolib.txt"
: > "$WORK/nolib.mock"
run nolib SteamGameId=$SHORTCUT_ID BW_STEAM_API_LIB="$WORK/none.so"
expect "no library passes" nolib.log "TEST RESULT: PASS"
expect "says there is no libsteam_api" nolib.log "no libsteam_api"

echo "steam input: $FAILS failed"
[ "$FAILS" = 0 ]
