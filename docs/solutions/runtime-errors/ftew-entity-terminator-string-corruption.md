---
title: FTEW entity terminator must be written as a byte
date: 2026-09-13
category: runtime-errors
tags: [godot, ftew, serialization]
---

The live-editor export of `neden_1.ftew` failed with `FTEW: invalid entity section`. Its ENTS section ended in the three UTF-8 bytes EF BF BD (U+FFFD), where FTEW requires exactly one zero byte. An earlier headless export of the same scene ended correctly in 00. All geometry sections were valid.

`serialize_entities()` appended a NUL through a GDScript string literal before converting to UTF-8. That made the binary terminator vulnerable to text handling in the editor/reload path. It now encodes the entity text first and then calls `PackedByteArray.append(0)`. The native reader remains strict about missing or embedded terminators.

Validation: the saved malformed file is rejected by the native reader, the regenerated 176-mesh scene passes, and the exporter regression verifies exactly one trailing zero while preserving Unicode entity values. `test_format FILE --validate-only` validates arbitrary exports without the lab-specific regression assertions.

Already generated malformed worlds must be re-exported. No engine rebuild is needed for this fix.
