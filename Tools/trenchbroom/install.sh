#!/bin/sh
# Copies the TrenchBroom game profiles into TrenchBroom's user games folder.
#
#   ./install.sh [games folder]
#
# The default folder is ~/.TrenchBroom/games. For another install (a
# Flatpak, or --portable), pass the folder that TrenchBroom's game list
# opens with its folder button. Profiles already there are replaced, except your
# CompilationProfiles.cfg and GameEngineProfiles.cfg, which TrenchBroom
# rewrites with your own paths: those are only copied the first time.
set -e
here=$(cd "$(dirname "$0")" && pwd)
dest=${1:-$HOME/.TrenchBroom/games}
mkdir -p "$dest"
for game in "$here"/games/*/; do
	name=$(basename "$game")
	mkdir -p "$dest/$name"
	for f in "$game"*; do
		base=$(basename "$f")
		case "$base" in
		CompilationProfiles.cfg|GameEngineProfiles.cfg)
			[ -e "$dest/$name/$base" ] && continue ;;
		esac
		cp "$f" "$dest/$name/"
	done
	echo "installed $name"
done
echo "into $dest. Restart TrenchBroom, then set each game's path in Preferences."
