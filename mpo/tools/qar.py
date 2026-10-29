import sys,struct,re
def strcode(s):
    i=0
    for c in s.encode():
        i=((i>>19)|(i<<5))&0xffffffff; i=(i+c)&0xffffff
    return i
def toc(d):
    t=struct.unpack_from("<I",d,len(d)-4)[0]; n=struct.unpack_from("<I",d,t)[0]
    ents=[struct.unpack_from("<II",d,t+4+8*i) for i in range(n)]
    names=d[t+4+8*n:len(d)-4].split(b"\0")
    names=[x.decode() for x in names if x]
    return ents,names
if __name__=="__main__":
    d=open(sys.argv[1],'rb').read(); ents,names=toc(d)
    byhash={strcode(n.rsplit('.',1)[0]):n for n in names}
    off=0; hit=0
    for h,sz in ents:
        n=byhash.get(h&0xffffff,'?'); hit+= n!='?'
        print(f"{off:08x} {sz:7d} {h:08x} {n}"); off+=sz
    print("matched",hit,"of",len(ents), "names",len(names))

def blocks(d):
    ents,names=toc(d); by={strcode(n.rsplit('.',1)[0]):n for n in names}
    off=0; out=[]
    for h,sz in ents:
        out.append((by.get(h&0xffffff,'%08x'%h),off,sz)); off=(off+sz+0x7f)&~0x7f
    return out
