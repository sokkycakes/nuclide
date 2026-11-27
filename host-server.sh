#!/bin/sh
# Host a Stiletto Proto dedicated server (Linux playtest build, Bulwark).
# Settings are in base/server.cfg. Extra options are passed on, e.g.
#   ./host-server.sh -port 27600 +set g_gametype freezetag +map duel_alley
# Type commands into this terminal while it runs (status, map, kick, quit).
cd "$(dirname "$0")" || exit 1

# Once the command line has run, the server starts server.cfg's first map
# (its startmap_dm alias) if nothing started one, as stock FTE does.
exec ./bulwark/bulwark-ded -basedir . -game base "$@"
