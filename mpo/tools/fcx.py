# fcx.py: MPO stage text tables (minifont.fcx).
# u32 magic 0x4531e19c, u32 -1, u32 script offset, u32 0x14, u32 string base,
# u32 end; from 0x1c an array of u32 (0x80000000 | offset from string base) up
# to the string base; NUL-terminated strings. The script at h[2] registers
# tables as "0e <u16 first string> 06 <u24 table hash>".
import struct, sys, re
def load(path):
    d = open(path, 'rb').read(); h = struct.unpack_from('<6I', d, 0)
    base = h[4] + 8; n = (base - 0x1c) // 4
    offs = [struct.unpack_from('<I', d, 0x1c + 4*i)[0] & 0x7fffffff for i in range(n)]
    strs = [d[base + o: d.index(b"\0", base + o)].decode('latin-1') for o in offs]
    tabs = {}
    for m in re.finditer(rb'\x0e(..)\x06(...)', d[h[2]:], re.S):
        tabs[int.from_bytes(m.group(2), 'little')] = struct.unpack('<H', m.group(1))[0]
    return strs, tabs
def text(fcx, table, idx):
    strs, tabs = fcx
    return strs[tabs[table] + idx] if table in tabs and tabs[table] + idx < len(strs) else None
if __name__ == '__main__':
    strs, tabs = load(sys.argv[1])
    for hsh, s in sorted(tabs.items(), key=lambda x: x[1]): print('table %06x starts %d' % (hsh, s))
    for i, s in enumerate(strs): print(i, repr(s))
