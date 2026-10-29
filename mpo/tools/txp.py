import struct
from PIL import Image
def unswizzle(data, wbytes, h):
    # PSP GE swizzle: 16-byte x 8-row blocks
    out = bytearray(len(data)); bw = wbytes // 16; i = 0
    for by in range(0, h, 8):
        for bx in range(bw):
            for r in range(8):
                y = by + r
                if y >= h: i += 16; continue
                o = y * wbytes + bx * 16
                out[o:o+16] = data[i:i+16]; i += 16
    return bytes(out)
def textures(blk):
    """blk = one txp block. Yields (index, w, h, fmt, rgba Image)."""
    ntex, toff = struct.unpack_from("<II", blk, 8)
    for i in range(ntex):
        b0, b1, b2, b3, fmt, doff, poff = struct.unpack_from("<4BIII", blk, toff + 16*i)
        w = b0 | ((b1 & 0xf) << 8); h = b2 | ((b3 & 0xf) << 8)
        f = fmt & 0xffff; swz = (fmt >> 16) & 0xff
        bpp = {4: 4, 5: 8}.get(f)
        if not bpp: yield i, w, h, fmt, None; continue
        wb = w * bpp // 8; raw = blk[doff:doff + wb*h]
        if (fmt >> 16) & 2:
            # flag 0x20000: u32 length, then a zlib stream holding the pixels
            import zlib
            n = struct.unpack_from("<I", blk, doff)[0]
            raw = zlib.decompress(blk[doff + 4:doff + 4 + n])
        npal = 16 if bpp == 4 else 256
        pal = [tuple(blk[poff+4*k:poff+4*k+4]) for k in range(npal)]
        yield i, w, h, fmt, (raw, wb, pal, bpp)
def to_image(w, h, raw, wb, pal, bpp, swz=False):
    if swz: raw = unswizzle(raw, wb, h)
    px = []
    for y in range(h):
        row = raw[y*wb:(y+1)*wb]
        if bpp == 8: idx = row
        else: idx = [v for b in row for v in (b & 15, b >> 4)]
        for x in range(w):
            r, g, b, a = pal[idx[x]]
            px.append((r, g, b, min(255, a*2)))
    im = Image.new("RGBA", (w, h)); im.putdata(px); return im
