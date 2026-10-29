# MGS Portable Ops menus on Bulwark

A port of Metal Gear Solid: Portable Ops' menu code onto a CSQC runtime that
plays the game's own `.la2` layouts. No game data is in git: run the converter
on your own ISO extraction.

- `tools/`: decoders (zar/dar, qar, txp, la2, fcx) and `mpo2bw.py`, which
  writes textures (PNG), one `.lay` text file per layout and the stage's
  string tables into a game dir:
  `python3 -I tools/mpo2bw.py <unpacked stage dir> r_main01 <game dir>`
- `src/`: the CSQC. `lay.qc` is the layout runtime (the game's play / stop /
  is-playing / root show / node show / set text API), `text.qc` the string
  tables, `pause.qc` the pause menu ported from BOOT.BIN, `main.qc` the entry
  points. Build with `fteqcc -src mpo/src`; the output is `mpo/csprogs.dat`.

Test: put `csprogs.dat` in the game dir and run
`bulwark -game base -game valve -game <game dir> +map ai`, then press P.
Up/Down move, Enter selects (prints which submenu would open), P or
Backspace closes. `mpo_pause` toggles it from the console.

QC note: in fteqcc `r = a || b` parses as `(r = a) || b`; always parenthesise
logical expressions on the right of an assignment.
