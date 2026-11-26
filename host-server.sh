#!/bin/sh
# Host a Stiletto Proto dedicated server (Linux playtest build, Bulwark).
# Settings are in base/server.cfg. Extra options are passed on, e.g.
#   ./host-server.sh -port 27600 +set g_gametype freezetag +map duel_alley
# Type commands into this terminal while it runs (status, map, kick, quit).
cd "$(dirname "$0")" || exit 1

# Once the command line has run, start server.cfg's first map (its
# startmap_dm alias) if no map is running yet. Stock FTE does this itself.
# The check is on the server, not on these arguments, so a "+map", a
# "+startmap_dm" or a "+exec" of a cfg that starts a map all load one map,
# and a "+exec" of a cfg that only sets cvars still gets the first map.
# An older server.cfg that still has a plain "map" line and no startmap_dm
# alias is left to that line: Bulwark holds it until the command line has
# run and drops it when the command line starts a map.
if [ -f base/server.cfg ] && ! grep -Eq '^[[:space:]]*alias[[:space:]]+"?startmap_dm' base/server.cfg &&
	grep -Eq '^[[:space:]]*map[[:space:]]' base/server.cfg; then
	exec ./bulwark/bulwark-ded -basedir . -game base "$@"
fi

exec ./bulwark/bulwark-ded -basedir . -game base "$@" \
	+if '$mapname' == '""' then startmap_dm
