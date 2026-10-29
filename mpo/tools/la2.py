import struct, sys
def hdr(d):
    return struct.unpack_from("<12I", d, 4)
def nodes(d):
    o = hdr(d)[0]; n = struct.unpack_from("<I", d, o)[0]
    base = o + 4 + 40
    out = []
    for i in range(n):
        h, fl, k1, k2, nid, par, a, b, z = struct.unpack_from("<IHBBHHHHI", d, base + 20*i)
        out.append(dict(i=i, hash=h, fl=fl, k1=k1, k2=k2, id=nid, parent=par, a=a, b=b, z=z))
    return d[o+4:o+44], out
def props(d):
    o = hdr(d)[1]; n = struct.unpack_from("<I", d, o)[0]; p = o + 4; out = []
    for i in range(n):
        tag, ln = struct.unpack_from("<HH", d, p); blk = d[p:p+ln]; out.append((p, blk)); p += ln
    return out, p
def tlv(blk, depth=0):
    p = 4; s = []
    while p < len(blk):
        tag, ln = struct.unpack_from("<HH", blk, p)
        if ln < 4: s.append(f"!{tag}/{ln}"); break
        v = blk[p+4:p+ln]
        s.append(f"{tag}:{v.hex()}" if v else f"{tag}")
        p += ln
    return " ".join(s)
if __name__ == "__main__":
    d = open(sys.argv[1], "rb").read()
    h, ns = nodes(d)
    print("hdr", h.hex(" "))
    for x in ns: print(x)
    ps, end = props(d)
    print("props end", hex(end), "next sect", hex(hdr(d)[2]))
    for i, (p, b) in enumerate(ps): print(i, hex(p), tlv(b))

def fonts(d):
    o = hdr(d)[10]; n = struct.unpack_from("<I", d, o)[0]; p = o + 4; out = {}
    for f in range(n):
        h = struct.unpack_from("<I", d, p)[0]; ng = d[p+4]; p += 8; gl = {}
        for g in range(ng):
            adv, hh, u0, u1, v0, v1, c = struct.unpack_from("<HHHHHHI", d, p); p += 16
            gl[c] = (u0, u1, v0, v1, adv, hh)
        out[h] = gl
    return out

def anims(d):
    """H[3] lists (name hash, offset) of animations stored in H[2]. Each one:
    u32 channel count, u32 byte size, then channels: u16 node id, u16 key
    count, u32 byte length, then TLV keys (7 = start: u32 property-block
    offset; 8 = u32 time, u32 offset; 0 = end). Returns [(hash, {id: [(t, off)]})]."""
    H = hdr(d); o = H[3]; n = struct.unpack_from("<I", d, o)[0]; out = []
    for i in range(n):
        h, ao = struct.unpack_from("<II", d, o + 4 + 8*i)
        nch = struct.unpack_from("<I", d, ao)[0]; p = ao + 8; chans = {}
        for c in range(nch):
            nid, nk, ln = struct.unpack_from("<HHI", d, p); q = p + 8; keys = []
            while q < p + ln:
                tag, kl = struct.unpack_from("<HH", d, q)
                if tag == 7: keys.append((0, struct.unpack_from("<I", d, q + 4)[0]))
                elif tag == 8: keys.append(struct.unpack_from("<II", d, q + 4))
                if tag == 0 or kl < 4: break
                q += kl
            chans[nid] = keys; p += ln
        out.append((h, chans))
    return out
