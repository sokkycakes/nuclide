#!/usr/bin/env bash
set -euo pipefail
QCC="/c/Users/sokky/Documents/Godot/bulwark_proto_funny/nuclide/Tools/fteqw-release-win64-c781d13/fteqcc64.exe"
NUC="/c/Users/sokky/Documents/Godot/bulwark_proto_funny/nuclide"
CF="-I${NUC}/src/common"

echo "== client =="
cd "${NUC}/base/src/client" && "${QCC}" ${CF} -I../shared progs.src

echo "== hud =="
cd "${NUC}/base/src/hud" && "${QCC}" ${CF} progs.src

echo "== server =="
cd "${NUC}/base/src/server" && "${QCC}" ${CF} progs.src

echo "== menu (base) =="
cd "${NUC}/base/src/menu" && "${QCC}" ${CF} progs.src

echo "== rules =="
mkdir -p "${NUC}/base/progs"
cd "${NUC}/base/src/rules"
for f in deathmatch.src singleplayer.src invasion.src domination.src lastmanstanding.src teamdm.src; do
  "${QCC}" ${CF} "$f"
done

echo "== maps =="
cd "${NUC}/base/src/maps"
for f in demo.src lqdm1.src lqdm3.src lqdm4.src lqdm6.src lqdm7.src lqdm8.src lqdm9.src lqdm10.src stiletto_dev.src; do
  "${QCC}" "$f"
done

echo "== menu-vgui (standalone) =="
mkdir -p "${NUC}/platform/data.pk3dir"
cd "${NUC}/src/menu-vgui" && "${QCC}" progs.src

echo "== menu-fn =="
cd "${NUC}/src/menu-fn" && "${QCC}" progs.src

echo "ALL_OK"
