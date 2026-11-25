#!/bin/sh
# Puts Valve's libsteam_api.so (Steamworks SDK redistributable, Linux x64)
# into OUT, for Steam Input in Bulwark and the launcher. Neither links
# against it; both load it at run time and fall back to SDL without it.
#   tools/fetch_steam_api.sh OUT
# STEAM_API_LIB=/path/to/sdk/redistributable_bin/linux64/libsteam_api.so uses
# a file from your own Steamworks SDK instead of downloading.
#
# The SDK download needs a Steamworks partner login, so CI takes the same
# file from the steamworks.js npm package (MIT wrapper; the library inside
# is Valve's redistributable, unchanged). Both the package and the library
# are checked against pinned SHA-256 sums.
set -eu
OUT=$1
PKG_URL=https://registry.npmjs.org/steamworks.js/-/steamworks.js-0.4.0.tgz
PKG_SHA256=877815e99217ff4ffa560476bc1bd27fc5f7bfebd6319e7d21f3cd601b131943
LIB_SHA256=0ed3199107e021fa27e19a642148514ca5337563569c48fc094c27f907dd47a7
mkdir -p "$OUT"
if [ -n "${STEAM_API_LIB:-}" ]; then
	cp "$STEAM_API_LIB" "$OUT/libsteam_api.so"
	echo "libsteam_api.so from $STEAM_API_LIB"
	exit 0
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
curl -fsSL --retry 3 -o "$TMP/pkg.tgz" "$PKG_URL"
echo "$PKG_SHA256  $TMP/pkg.tgz" | sha256sum -c - >/dev/null
tar -C "$TMP" -xzf "$TMP/pkg.tgz" package/dist/linux64/libsteam_api.so
echo "$LIB_SHA256  $TMP/package/dist/linux64/libsteam_api.so" | sha256sum -c - >/dev/null
cp "$TMP/package/dist/linux64/libsteam_api.so" "$OUT/libsteam_api.so"
echo "libsteam_api.so (Steamworks redistributable, sha256 $LIB_SHA256)"
