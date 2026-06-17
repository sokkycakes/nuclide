#!/usr/bin/env python3
"""
cso_mdl_decrypt.py - Decrypt Counter-Strike Online / Nexon GoldSrc .mdl models.

CSO/Nexon ship GoldSrc studio models whose header version field is 20 or 21.
These are NOT a different struct layout - the studiohdr is identical to stock
GoldSrc v10. Only two regions are encrypted with Matthew Kwan's ICE block
cipher (level 4, 32-byte key):

  * each texture's pixel+palette block: (width*height) + 768 bytes
  * each submodel's vertex positions:   numVerts * 12 bytes

This tool decrypts those regions in place and rewrites the version field to 10
so the result loads in any stock GoldSrc engine (and in FTE's gl_hlmdl.c, which
requires version == 10).

The ICE cipher and the encrypted-region layout are ported from NARTools
(Da_FileServer / SmilexGamer, GPL-3.0): NARToolLib/Ice.cs + ModelHelper.cs.

Usage:
    python cso_mdl_decrypt.py MODEL.mdl                 # -> MODEL.decrypted.mdl
    python cso_mdl_decrypt.py MODEL.mdl -o out_dir      # -> out_dir/MODEL.mdl
    python cso_mdl_decrypt.py models_dir -o out_dir     # recurse a folder
    python cso_mdl_decrypt.py MODEL.mdl --inplace       # overwrite in place

Exit code is non-zero if any requested file failed to decrypt.
"""

import argparse
import os
import struct
import sys

# --- Nexon model keys (chosen by header version) -----------------------------

VERSION20_KEY = bytes([
    0x32, 0xA6, 0x21, 0xE0, 0xAB, 0x6B, 0xF4, 0x2C,
    0x93, 0xC6, 0xF1, 0x96, 0xFB, 0x38, 0x75, 0x68,
    0xBA, 0x70, 0x13, 0x86, 0xE0, 0xB3, 0x71, 0xF4,
    0xE3, 0x9B, 0x07, 0x22, 0x0C, 0xFE, 0x88, 0x3A,
])
VERSION21_KEY = bytes([
    0x22, 0x7A, 0x19, 0x6F, 0x7B, 0x86, 0x7D, 0xE0,
    0x8C, 0xC6, 0xF1, 0x96, 0xFB, 0x38, 0x75, 0x68,
    0x88, 0x7A, 0x78, 0x86, 0x78, 0x86, 0x67, 0x70,
    0xD9, 0x91, 0x07, 0x3A, 0x14, 0x74, 0xFE, 0x22,
])

IDST_MAGIC = 0x54534449  # "IDST" little-endian


# --- ICE block cipher (Matthew Kwan), ported from NARTools Ice.cs ------------

_SMOD = (
    (333, 313, 505, 369),
    (379, 375, 319, 391),
    (361, 445, 451, 397),
    (397, 425, 395, 505),
)
_SXOR = (
    (0x83, 0x85, 0x9b, 0xcd),
    (0xcc, 0xa7, 0xad, 0x41),
    (0x4b, 0x2e, 0xd4, 0x33),
    (0xea, 0xcb, 0x2e, 0x04),
)
_PBOX = (
    0x00000001, 0x00000080, 0x00000400, 0x00002000,
    0x00080000, 0x00200000, 0x01000000, 0x40000000,
    0x00000008, 0x00000020, 0x00000100, 0x00004000,
    0x00010000, 0x00800000, 0x04000000, 0x20000000,
    0x00000004, 0x00000010, 0x00000200, 0x00008000,
    0x00020000, 0x00400000, 0x08000000, 0x10000000,
    0x00000002, 0x00000040, 0x00000800, 0x00001000,
    0x00040000, 0x00100000, 0x02000000, 0x80000000,
)
_KEY_ROTATION = (0, 1, 2, 3, 2, 1, 3, 0, 1, 3, 2, 0, 3, 1, 0, 2)

_MASK32 = 0xFFFFFFFF
_SBOX = None  # lazily built [4][1024]


def _gf_multiply(a, b, m):
    res = 0
    while b != 0:
        if b & 1:
            res ^= a
        a <<= 1
        b >>= 1
        if a >= 256:
            a ^= m
    return res


def _gf_exp7(b, m):
    if b == 0:
        return 0
    x = _gf_multiply(b, b, m)
    x = _gf_multiply(b, x, m)
    x = _gf_multiply(x, x, m)
    x = _gf_multiply(b, x, m)
    return x


def _perm32(x):
    res = 0
    pbox = 0
    while x != 0:
        if x & 1:
            res |= _PBOX[pbox]
        pbox += 1
        x >>= 1
    return res & _MASK32


def _build_sbox():
    global _SBOX
    if _SBOX is not None:
        return
    sbox = [[0] * 1024 for _ in range(4)]
    for i in range(1024):
        col = (i >> 1) & 0xff
        row = (i & 0x1) | ((i & 0x200) >> 8)
        sbox[0][i] = _perm32(_gf_exp7(col ^ _SXOR[0][row], _SMOD[0][row]) << 24)
        sbox[1][i] = _perm32(_gf_exp7(col ^ _SXOR[1][row], _SMOD[1][row]) << 16)
        sbox[2][i] = _perm32(_gf_exp7(col ^ _SXOR[2][row], _SMOD[2][row]) << 8)
        sbox[3][i] = _perm32(_gf_exp7(col ^ _SXOR[3][row], _SMOD[3][row]))
    _SBOX = sbox


class Ice:
    """ICE cipher. ``n`` is the key level (CSO uses n=4 -> 32-byte key)."""

    def __init__(self, n, key):
        _build_sbox()
        if n == 0:
            self.size = 1
            self.rounds = 8
        else:
            self.size = n
            self.rounds = n << 4
        self.ks = [[0, 0, 0] for _ in range(self.rounds)]
        self._set_key(key)

    def _build_schedule(self, key_builder, n, kr_offset):
        for i in range(8):
            kr = _KEY_ROTATION[kr_offset + i]
            idx = n + i
            self.ks[idx][0] = 0
            self.ks[idx][1] = 0
            self.ks[idx][2] = 0
            for j in range(15):
                for k in range(4):
                    pos = (kr + k) & 3
                    cur = key_builder[pos]
                    bit = cur & 1
                    slot = j % 3
                    self.ks[idx][slot] = ((self.ks[idx][slot] << 1) | bit) & _MASK32
                    key_builder[pos] = ((cur >> 1) | ((bit ^ 1) << 15)) & 0xFFFF

    def _set_key(self, key):
        if self.rounds == 8:
            if len(key) != 8:
                raise ValueError("Key size is not valid.")
            kb = [0, 0, 0, 0]
            for i in range(4):
                kb[3 - i] = (key[i << 1] << 8) | key[(i << 1) + 1]
            self._build_schedule(kb, 0, 0)
        else:
            if len(key) != (self.size << 3):
                raise ValueError("Key size is not valid.")
            for i in range(self.size):
                pos = i << 3
                kb = [0, 0, 0, 0]
                for j in range(4):
                    kb[3 - j] = (key[pos + (j << 1)] << 8) | key[pos + (j << 1) + 1]
                self._build_schedule(kb, pos, 0)
                self._build_schedule(kb, self.rounds - 8 - pos, 8)

    def _transform(self, value, idx):
        tl = ((value >> 16) & 0x3ff) | (((value >> 14) | (value << 18)) & 0xffc00)
        tr = (value & 0x3ff) | ((value << 2) & 0xffc00)
        ks = self.ks[idx]
        al = ks[2] & (tl ^ tr)
        ar = al ^ tr
        al ^= tl
        al ^= ks[0]
        ar ^= ks[1]
        return (_SBOX[0][al >> 10] | _SBOX[1][al & 0x3ff]
                | _SBOX[2][ar >> 10] | _SBOX[3][ar & 0x3ff]) & _MASK32

    def encrypt_block(self, data, off):
        l = (data[off] << 24) | (data[off + 1] << 16) | (data[off + 2] << 8) | data[off + 3]
        r = (data[off + 4] << 24) | (data[off + 5] << 16) | (data[off + 6] << 8) | data[off + 7]
        for i in range(0, self.rounds, 2):
            l = (l ^ self._transform(r, i)) & _MASK32
            r = (r ^ self._transform(l, i + 1)) & _MASK32
        data[off + 0] = (r >> 24) & 0xFF
        data[off + 1] = (r >> 16) & 0xFF
        data[off + 2] = (r >> 8) & 0xFF
        data[off + 3] = r & 0xFF
        data[off + 4] = (l >> 24) & 0xFF
        data[off + 5] = (l >> 16) & 0xFF
        data[off + 6] = (l >> 8) & 0xFF
        data[off + 7] = l & 0xFF

    def decrypt_block(self, data, off):
        l = (data[off] << 24) | (data[off + 1] << 16) | (data[off + 2] << 8) | data[off + 3]
        r = (data[off + 4] << 24) | (data[off + 5] << 16) | (data[off + 6] << 8) | data[off + 7]
        for i in range(self.rounds - 1, 0, -2):
            l = (l ^ self._transform(r, i)) & _MASK32
            r = (r ^ self._transform(l, i - 1)) & _MASK32
        data[off + 0] = (r >> 24) & 0xFF
        data[off + 1] = (r >> 16) & 0xFF
        data[off + 2] = (r >> 8) & 0xFF
        data[off + 3] = r & 0xFF
        data[off + 4] = (l >> 24) & 0xFF
        data[off + 5] = (l >> 16) & 0xFF
        data[off + 6] = (l >> 8) & 0xFF
        data[off + 7] = l & 0xFF


# --- region decryptor, ported from NARTools ModelHelper.cs --------------------

class ModelError(Exception):
    pass


class NotEncrypted(Exception):
    pass


def _transform_chunk(ice, data, offset, length):
    """Replicate ModelHelper.TransformChunk exactly.

    Decrypts in <=1024-byte blocks; bails out on the first non-8-aligned
    remainder, leaving the tail untouched (Nexon's encryptor did the same, so
    those tail bytes were never encrypted)."""
    while length > 0:
        templen = length if length <= 1024 else 1024
        if (templen & 7) != 0 or templen == 0:
            return
        end = offset + templen
        if end > len(data):
            return
        for blk in range(offset, end, 8):
            ice.decrypt_block(data, blk)
        length -= templen
        offset += templen


def _rd_i32(data, off):
    return struct.unpack_from("<i", data, off)[0]


def decrypt_model_bytes(data, out_version=10):
    """Decrypt a CSO v20/v21 model buffer in place (bytearray).

    Returns the detected encrypted version (20 or 21). Raises NotEncrypted for
    plain models and ModelError for malformed input."""
    if len(data) < 244:
        raise ModelError("file smaller than studio header (244 bytes)")
    if _rd_i32(data, 0) != IDST_MAGIC:
        raise ModelError('bad magic (not "IDST")')

    version = _rd_i32(data, 4)
    if version == 20:
        ice = Ice(4, VERSION20_KEY)
    elif version == 21:
        ice = Ice(4, VERSION21_KEY)
    else:
        raise NotEncrypted("version %d is not an encrypted CSO model" % version)

    filesize_field = _rd_i32(data, 72)
    if filesize_field < len(data):
        # Mirror NARTools' sanity guard but don't hard-fail: warn and proceed.
        sys.stderr.write(
            "  warning: header filesize %d < actual %d (continuing)\n"
            % (filesize_field, len(data)))

    # Rewrite version so the output loads as stock GoldSrc v10.
    struct.pack_into("<i", data, 4, out_version)

    # Textures: numtextures @180, textureindex @184; 80-byte entries.
    num_tex = _rd_i32(data, 180)
    tex_index = _rd_i32(data, 184)
    i = 0
    while i < num_tex and tex_index >= 0:
        base = tex_index
        if base + 80 > len(data):
            break
        width = _rd_i32(data, base + 68)
        height = _rd_i32(data, base + 72)
        index = _rd_i32(data, base + 76)
        if width >= 0 and height >= 0 and index >= 0:
            length = (width * height) + 768
            if 0 <= index <= len(data):
                if index + length > len(data):
                    length = len(data) - index
                _transform_chunk(ice, data, index, length)
        i += 1
        tex_index += 80

    # Body parts: numbodyparts @204, bodypartindex @208; 76-byte entries.
    num_bp = _rd_i32(data, 204)
    bp_index = _rd_i32(data, 208)
    i = 0
    while i < num_bp and bp_index >= 0:
        base = bp_index
        if base + 76 > len(data):
            break
        num_models = _rd_i32(data, base + 64)
        model_index = _rd_i32(data, base + 72)  # +64 nummodels, +68 base (skip), +72 index
        if model_index >= 0:
            j = 0
            mi = model_index
            while j < num_models and mi >= 0:
                if mi + 112 > len(data):
                    break
                num_verts = _rd_i32(data, mi + 80)
                verts_index = _rd_i32(data, mi + 88)  # +80 numverts, +84 skip, +88 index
                if verts_index >= 0:
                    length = num_verts * 12
                    if 0 <= verts_index <= len(data):
                        if verts_index + length > len(data):
                            length = len(data) - verts_index
                        _transform_chunk(ice, data, verts_index, length)
                j += 1
                mi += 112
        i += 1
        bp_index += 76

    return version


# --- CLI ---------------------------------------------------------------------

def _gather_inputs(paths):
    files = []
    for p in paths:
        if os.path.isdir(p):
            for root, _, names in os.walk(p):
                for name in names:
                    if name.lower().endswith(".mdl"):
                        files.append(os.path.join(root, name))
        else:
            files.append(p)
    return files


def _output_path(in_path, out_dir, inplace, roots):
    if inplace:
        return in_path
    if out_dir:
        # Preserve filename; if the input came from a scanned dir, mirror its
        # relative path under out_dir.
        rel = None
        for r in roots:
            if os.path.isdir(r):
                try:
                    candidate = os.path.relpath(in_path, r)
                except ValueError:
                    continue
                if not candidate.startswith(".."):
                    rel = candidate
                    break
        if rel is None:
            rel = os.path.basename(in_path)
        return os.path.join(out_dir, rel)
    stem, ext = os.path.splitext(in_path)
    return stem + ".decrypted" + ext


def main(argv=None):
    ap = argparse.ArgumentParser(description="Decrypt CSO/Nexon GoldSrc .mdl models (v20/v21).")
    ap.add_argument("paths", nargs="+", help=".mdl files or directories to scan")
    ap.add_argument("-o", "--out", help="output directory (preserves filenames)")
    ap.add_argument("--inplace", action="store_true", help="overwrite inputs in place")
    ap.add_argument("--version", type=int, default=10, dest="out_version",
                    help="version to stamp into the decrypted header (default 10)")
    args = ap.parse_args(argv)

    if args.inplace and args.out:
        ap.error("--inplace and --out are mutually exclusive")

    inputs = _gather_inputs(args.paths)
    if not inputs:
        sys.stderr.write("no .mdl files found\n")
        return 1

    ok = skipped = failed = 0
    for in_path in inputs:
        try:
            with open(in_path, "rb") as f:
                data = bytearray(f.read())
        except OSError as e:
            sys.stderr.write("FAIL %s: %s\n" % (in_path, e))
            failed += 1
            continue

        try:
            ver = decrypt_model_bytes(data, out_version=args.out_version)
        except NotEncrypted as e:
            print("skip %s (%s)" % (in_path, e))
            skipped += 1
            continue
        except ModelError as e:
            sys.stderr.write("FAIL %s: %s\n" % (in_path, e))
            failed += 1
            continue

        out_path = _output_path(in_path, args.out, args.inplace, args.paths)
        out_parent = os.path.dirname(os.path.abspath(out_path))
        try:
            if out_parent and not os.path.isdir(out_parent):
                os.makedirs(out_parent, exist_ok=True)
            with open(out_path, "wb") as f:
                f.write(data)
        except OSError as e:
            sys.stderr.write("FAIL %s: %s\n" % (in_path, e))
            failed += 1
            continue

        print("ok   %s (v%d) -> %s" % (in_path, ver, out_path))
        ok += 1

    print("\ndone: %d decrypted, %d skipped, %d failed" % (ok, skipped, failed))
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
