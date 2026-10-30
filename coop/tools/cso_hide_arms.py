#!/usr/bin/env python3
# Copyright (c) 2026 sokky
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF MIND, USE, DATA OR PROFITS, WHETHER
# IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
# OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

"""Hides the arms of a Counter-Strike Online view model.

CSO v_ models (GoldSrc studio, version 10) keep the arms in a body part
named "hands", one model per arm set. This sets every one of those models
to no meshes, so only the weapon draws. The heroes' guns are drawn without
arms (coop/decls/def/hero_weapons.def).

usage: cso_hide_arms.py <in.mdl> <out.mdl>
"""

import struct
import sys

HEADER_BODYPARTS = 204	# numbodyparts, then bodypartindex
BODYPART_SIZE = 76	# name[64] nummodels base modelindex
MODEL_SIZE = 112	# name[64] type boundingradius nummesh meshindex ...
MODEL_NUMMESH = 72


def hide_arms(data):
	data = bytearray(data)

	if data[:4] != b"IDST" or struct.unpack_from("<i", data, 4)[0] != 10:
		raise ValueError("not a GoldSrc studio model")

	count, index = struct.unpack_from("<ii", data, HEADER_BODYPARTS)
	hidden = 0

	for i in range(count):
		part = index + i * BODYPART_SIZE
		name = bytes(data[part:part + 64]).split(b"\0")[0].decode("latin-1")

		if name.lower() != "hands":
			continue

		models = struct.unpack_from("<i", data, part + 64)[0]
		modelIndex = struct.unpack_from("<i", data, part + 72)[0]

		for m in range(models):
			struct.pack_into("<i", data, modelIndex + m * MODEL_SIZE + MODEL_NUMMESH, 0)
			hidden += 1

	if not hidden:
		raise ValueError("no \"hands\" body part")

	return bytes(data), hidden


def main():
	if len(sys.argv) != 3:
		sys.exit(__doc__.strip().splitlines()[-1])

	with open(sys.argv[1], "rb") as f:
		data, hidden = hide_arms(f.read())

	with open(sys.argv[2], "wb") as f:
		f.write(data)

	print("%s: hid %d arm models" % (sys.argv[2], hidden))


if __name__ == "__main__":
	main()
