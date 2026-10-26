#!/bin/sh
# Headless co-op run on Bulwark: loads coop_arena with N bots and prints
# coop_status every few seconds.
#   usage: coop/tests/run.sh path/to/bulwark-ded [bots] [seconds] [extra args...]
# Run from the nuclide root. COOP_ARGS adds settings, e.g. "+set coop_survival 1".
# Half-Life's own models and sounds aren't in the repo: put a copy of the
# game's valve/models and valve/sound in a game dir next to valve/ and coop/
# and name it with COOP_HLDATA (e.g. COOP_BASEDIR=/tmp/run COOP_HLDATA=hldata).
# Without them monsters can't animate, so they never attack.
set -e
BULWARK=${1:?usage: run.sh path/to/bulwark-ded [bots] [seconds]}
BOTS=${2:-4}
SECS=${3:-60}
shift 3 2>/dev/null || shift $#
NAMES="Barney Gina Gordon Helmet Robo Scientist Zombie Recon Shephard Gman"
i=0
while [ $i -lt "$BOTS" ]; do
	set -- "$@" +sv addBot $(echo $NAMES | cut -d' ' -f$((i % 10 + 1)))
	i=$((i + 1))
done
# the server runs at 72 frames a second; a status line every 10 seconds
FRAMES=$((SECS * 72))
STATUS=""
t=10
while [ $t -le "$SECS" ]; do
	STATUS="$STATUS +wait 720 +sv coop_status"
	t=$((t + 10))
done
HLDATA=""
[ -n "$COOP_HLDATA" ] && HLDATA="-game $COOP_HLDATA"
exec "$BULWARK" -basedir "${COOP_BASEDIR:-.}" $HLDATA -game valve -game coop -frames "$FRAMES" \
	+exec default_coop.cfg +set coop_waveDelay 3 $COOP_ARGS +map coop_arena +wait 60 "$@" $STATUS
