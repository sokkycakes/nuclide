import sys, zlib, struct, os
def arc(data):
    n = struct.unpack_from("<I", data, 0)[0]; pos = 4; out = []
    for i in range(n):
        while pos < len(data) and data[pos] == 0: pos += 1
        if pos >= len(data): break
        z = data.find(b"\0", pos); name = data[pos:z].decode("ascii","replace")
        sp = (z + 1 + 3) & ~3; size = struct.unpack_from("<I", data, sp)[0]
        ds = (sp + 4 + 15) & ~15
        out.append((name, ds, data[ds:ds+size])); pos = ds + size
    return out
src, dst = sys.argv[1], sys.argv[2]
raw = open(src, "rb").read()
data = zlib.decompress(raw[4:])
os.makedirs(dst, exist_ok=True)
for name, off, d in arc(data):
    open(os.path.join(dst, name), "wb").write(d); print(f"{name:28s} {len(d):9d} @{off:#x}")
    if name.endswith(".dar"):
        sub = os.path.join(dst, name + ".d"); os.makedirs(sub, exist_ok=True)
        for n2, o2, d2 in arc(d):
            open(os.path.join(sub, n2), "wb").write(d2); print(f"   {n2:25s} {len(d2):9d}")
