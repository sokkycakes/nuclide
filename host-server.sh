#!/bin/sh
# Host a Stiletto Proto dedicated server (Linux playtest build, Bulwark).
# Settings are in base/server.cfg. Extra options are passed on, e.g.
#   ./host-server.sh -port 27600 +set g_gametype freezetag +map duel_alley
# Type commands into this terminal while it runs (status, map, kick, quit).
cd "$(dirname "$0")" || exit 1

# With no map on the command line, start server.cfg's first map
# (its startmap_dm alias) after the command line has run, as FTE does on
# its own. A "+exec" may start a map itself, so it is left alone too.
startmap="+startmap_dm"
for arg in "$@"; do
	case "$arg" in
	+map|+changelevel|+devmap|+spmap|+gamemap|+exec) startmap="" ;;
	esac
done

exec ./bulwark/bulwark-ded -basedir . -game base "$@" $startmap
