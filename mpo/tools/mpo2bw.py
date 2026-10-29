#!/usr/bin/env python3
"""mpo2bw.py: convert MGS Portable Ops UI data for the Bulwark/FTE runtime.

usage: python3 -I mpo2bw.py <stage dir> <stage name> <game dir>

<stage dir> is an unpacked stage (zar.py output: the .qar and the .dar.d
folder with the .la2 layouts, plus minifont.fcx). Writes, under <game dir>:

  textures/mpo/<stage>/<txp>_<n>.png   every texture of every TXP block
  data/mpo/<stage>/<layout>.lay        one text file per layout (format below)
  data/mpo/<stage>/text.txt            the stage's string tables

.lay lines (all numbers decimal; positions and sizes in PSP pixels):
  tex <n> <image> <w> <h>              texture n (image path without .png)
  spr <n> <tex> <w> <h>                sprite n (1-based, as layout tag 7):
                                       crop (0,0,w,h) of texture <tex>
  col <n> <r> <g> <b> <a>              colour n, 0..1 (alpha 0x80 = 1);
                                       4-corner gradients are averaged
  uv <n> <u0> <v0> <u1> <v1>           UV rectangle n (layout tag 8), 0..1
  font <n> <hash>                      font n (1-based, as tag 24 byte 4)
  gl <font> <code> <u0> <u1> <v0> <v1> <adv> <h>
  blk <n> <tag> <args> ...             property block n (TLV block): a list
                                       of "<tag> <values>" groups, see below
  node <id> <parent> <hash> <blk>      node, its parent id, name hash, base
  anim <hash> <nchan>                  animation; then nchan of:
  ch <node id> <nkeys>                 channel; then nkeys of:
  key <frames> <blk>                   key: frames after the previous key

Block groups: v (shown), h (hidden), p x y (position, relative to the
parent), s w h (size), c n (colour), t n (sprite), u n (uv), x "str" (text),
f align font (text params), k n (scale, 1 = 100%), b n (blend flags, tag 9).
"""
import os, sys, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import qar, txp, la2, fcx
from PIL import Image

def tlv(blk):
    p = 4; out = []
    while p + 4 <= len(blk):
        tag, ln = struct.unpack_from('<HH', blk, p)
        if ln < 4 or tag == 0: break
        out.append((tag, blk[p+4:p+ln])); p += ln
    return out

def q(s):
    return '"' + s.replace('"', "'") + '"'

def block_line(blk):
    g = []
    for tag, v in tlv(blk):
        if tag == 1: g.append('v')
        elif tag == 2: g.append('h')
        elif tag == 3: x, y = struct.unpack_from('<hh', v, 8); g.append('p %g %g' % (x/16, y/16))
        elif tag == 5: w, h = struct.unpack_from('<hh', v, 4); g.append('s %g %g' % (w/16, h/16))
        elif tag == 6: g.append('c %d' % v[6])
        elif tag == 7: g.append('t %d' % struct.unpack_from('<I', v)[0])
        elif tag == 8: g.append('u %d' % struct.unpack_from('<I', v)[0])
        elif tag == 9: g.append('b %d' % struct.unpack_from('<H', v)[0])
        elif tag == 10: g.append('k %g' % (struct.unpack_from('<H', v, 2)[0] / 256 if len(v) >= 4 else 1))
        elif tag == 13:
            n = struct.unpack_from('<I', v)[0]; s = v[4:4+n].decode('latin-1')
            g.append('x ' + q(s))
        elif tag == 24: g.append('f %d %d' % (v[2], v[4]))
    return ' '.join(g)

def export_txp(blk, name, outdir, relbase):
    """Write every texture of a TXP block; return [(image, w, h)]."""
    res = []
    for i, w, h, fmt, t in txp.textures(blk):
        img = f'{relbase}/{name}_{i}'
        if t is not None:
            im = txp.to_image(w, h, *t, swz=True)
            im.save(os.path.join(outdir, f'{name}_{i}.png'))
        res.append((img, w, h))
    return res

def sprite_table(blk):
    """sprite hash -> (texture index, w, h) for one TXP block."""
    nt, tt = struct.unpack_from('<II', blk, 8)
    _, st = struct.unpack_from('<II', blk, 0x10)
    out = {}
    for i in range(nt):
        e = blk[st + 48*i: st + 48*i + 48]
        h = struct.unpack_from('<I', e, 4)[0]; w, hh = struct.unpack_from('<HH', e, 12)
        toff = struct.unpack_from('<I', e, 20)[0]
        out[h & 0xffffff] = ((toff - tt) // 16, w, hh)
    return out

def main(stage_dir, stage, game):
    qp = [f for f in os.listdir(stage_dir) if f.endswith('.qar')][0]
    qd = open(os.path.join(stage_dir, qp), 'rb').read()
    tdir = os.path.join(game, 'textures', 'mpo', stage); os.makedirs(tdir, exist_ok=True)
    ddir = os.path.join(game, 'data', 'mpo', stage); os.makedirs(ddir, exist_ok=True)
    txps = {}
    for n, o, s in qar.blocks(qd):
        if n.endswith('.txp'):
            base = n.rsplit('.', 1)[0]
            blk = qd[o:o+s]
            txps[qar.strcode(base)] = (base, export_txp(blk, base, tdir, f'textures/mpo/{stage}'), sprite_table(blk))
    dar = [f for f in os.listdir(stage_dir) if f.endswith('.dar.d')][0]
    for f in sorted(os.listdir(os.path.join(stage_dir, dar))):
        if not (f.startswith('lay_') and f.endswith('.la2')): continue
        d = open(os.path.join(stage_dir, dar, f), 'rb').read()
        H = la2.hdr(d); L = []
        # textures and sprites
        texid = {}; so = H[6]; nsp = struct.unpack_from('<I', d, so)[0]
        for i in range(nsp):
            sh, th = struct.unpack_from('<II', d, so + 4 + 8*i)
            if th not in txps: L.append(f'spr {i+1} -1 0 0'); continue
            base, texs, spt = txps[th]
            ti, w, h = spt.get(sh & 0xffffff, (0, 0, 0))
            key = (th, ti)
            if key not in texid:
                texid[key] = len(texid); img, tw, tht = texs[ti]
                L.append(f'tex {texid[key]} {img} {tw} {tht}')
            L.append(f'spr {i+1} {texid[key]} {w} {h}')
        co = H[7]; n = struct.unpack_from('<I', d, co)[0]; p = co + 4
        for i in range(n):
            tg, ln = struct.unpack_from('<HH', d, p)
            cs = [d[p+4+k*4: p+8+k*4] for k in range((ln - 4) // 4)] or [b'\xff\xff\xff\x80']
            r, g, b, a = (sum(c[j] for c in cs) / len(cs) for j in range(4))
            L.append('col %d %.4f %.4f %.4f %.4f' % (i, r/255, g/255, b/255, min(1, a/128))); p += ln
        if H[8]:
            uo = H[8]; n = struct.unpack_from('<I', d, uo)[0]; p = uo + 4
            for i in range(n):
                tg, ln = struct.unpack_from('<HH', d, p)
                u = struct.unpack_from('<4H', d, p + 4) if tg == 2 else (0, 0, 65535, 65535)
                L.append('uv %d %.5f %.5f %.5f %.5f' % ((i,) + tuple(x / 65535 for x in u))); p += ln
        for fi, (fh, gl) in enumerate(la2.fonts(d).items()):
            L.append(f'font {fi+1} {fh & 0xffffff}')
            for c, (u0, u1, v0, v1, adv, hh) in gl.items():
                L.append('gl %d %d %.5f %.5f %.5f %.5f %g %g' % (fi+1, c, u0/65536, u1/65536, v0/65536, v1/65536, adv/16, hh/16))
        ps, _ = la2.props(d); bid = {}
        for i, (o, b) in enumerate(ps):
            bid[o] = i; L.append(f'blk {i} ' + block_line(b))
        _, ns = la2.nodes(d)
        for x in ns:
            L.append(f'node {x["id"]} {x["parent"]} {x["hash"] & 0xffffff} {x["i"]}')
        for h, chans in la2.anims(d):
            L.append(f'anim {h & 0xffffff} {len(chans)}')
            for nid, keys in chans.items():
                L.append(f'ch {nid} {len(keys)}')
                for t, o in keys: L.append(f'key {t} {bid.get(o, -1)}')
        open(os.path.join(ddir, f[:-4] + '.lay'), 'w').write('\n'.join(L) + '\n')
        print(stage, f[:-4], len(L), 'lines')
    fp = os.path.join(stage_dir, 'minifont.fcx')
    if os.path.exists(fp):
        strs, tabs = fcx.load(fp); T = []
        for h, s in tabs.items(): T.append(f'tab {h} {s}')
        for i, s in enumerate(strs): T.append(f'str {i} ' + q(s.rstrip('\n')))
        open(os.path.join(ddir, 'text.txt'), 'w').write('\n'.join(T) + '\n')

if __name__ == '__main__':
    main(*sys.argv[1:4])
