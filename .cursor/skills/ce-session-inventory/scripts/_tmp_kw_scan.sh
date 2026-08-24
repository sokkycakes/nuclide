#!/usr/bin/env bash
set -euo pipefail
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8
PYTHON="/c/Users/sokky/AppData/Local/Programs/Python/Python38/python.exe"
cd "/c/Users/sokky/Documents/Godot/bulwark_proto_funny/nuclide/.cursor/skills/ce-session-inventory"
OUT="/tmp/nuclide_kw_out.jsonl"
LIST="/tmp/nuclide_sessions_30.txt"
KEYWORDS="Beaumont,airdash,air_dash,airstall,air_stall,airdodge,air_dodge,stiletto,movement_kit"
: > "$OUT"
batch=()
n=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  wf=$(cygpath -w "$f")
  batch+=("$wf")
  if [ "${#batch[@]}" -ge 8 ]; then
    n=$((n+1))
    "$PYTHON" scripts/extract-metadata.py --cwd-filter nuclide --keyword "$KEYWORDS" "${batch[@]}" >> "$OUT" || true
    echo "batch $n done" >&2
    batch=()
  fi
done < "$LIST"
if [ "${#batch[@]}" -gt 0 ]; then
  n=$((n+1))
  "$PYTHON" scripts/extract-metadata.py --cwd-filter nuclide --keyword "$KEYWORDS" "${batch[@]}" >> "$OUT" || true
  echo "batch $n done" >&2
fi
echo "DONE" >&2
wc -l "$OUT"
