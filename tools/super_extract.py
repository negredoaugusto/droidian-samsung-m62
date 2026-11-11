#!/usr/bin/env python3
"""Extrai partições lógicas de um super.img Android (sparse ou raw) sem lpunpack/simg2img.
Uso: super_extract.py <super.img> <saida_dir> <part1> [part2 ...]   (ou 'list' para listar)"""
import os, struct, sys

def open_raw(path):
    """Devolve uma função read_at(offset, size) sobre a imagem lógica (descomprime sparse em memória de índice)."""
    f = open(path, 'rb')
    hdr = f.read(28)
    magic, maj, mnr, fhs, chs, blk, tblk, tchunk, _ = struct.unpack('<IHHHHIIII', hdr)
    if magic != 0xED26FF3A:
        return lambda off, n: (f.seek(off), f.read(n))[1], os.path.getsize(path)
    f.seek(fhs)
    chunks = []  # (out_start, out_len, type, file_off, fill)
    out = 0
    for _ in range(tchunk):
        ctype, _, csz, ttot = struct.unpack('<HHII', f.read(chs)); pos = f.tell()
        n = csz * blk
        if ctype == 0xCAC1:   chunks.append((out, n, 'raw', pos, None)); f.seek(pos + n)
        elif ctype == 0xCAC2: chunks.append((out, n, 'fill', None, f.read(4)))
        elif ctype == 0xCAC3: chunks.append((out, n, 'zero', None, None))
        elif ctype == 0xCAC4: f.seek(pos + 4); continue
        else: raise ValueError(f'chunk desconhecido {ctype:#x}')
        out += n
    import bisect
    starts = [c[0] for c in chunks]
    def read_at(off, n):
        res = bytearray()
        while n > 0:
            i = bisect.bisect_right(starts, off) - 1
            cs, cl, t, fo, fill = chunks[i]
            k = min(n, cs + cl - off)
            if t == 'raw': f.seek(fo + off - cs); res += f.read(k)
            elif t == 'fill': res += (fill * (k // 4 + 2))[(off - cs) % 4:(off - cs) % 4 + k]
            else: res += bytes(k)
            off += k; n -= k
        return bytes(res)
    return read_at, tblk * blk

read_at, total = open_raw(sys.argv[1])
geo = read_at(4096, 4096)
gmagic, gsize = struct.unpack_from('<II', geo, 0)
assert gmagic == 0x616C4467, 'geometria LP não encontrada'
meta_max, slots, lbs = struct.unpack_from('<III', geo, 40)
md = read_at(4096 + 4096 * 2, meta_max)
mmagic, maj, mnr, hsize = struct.unpack_from('<IHHI', md, 0)
assert mmagic == 0x414C5030, 'cabeçalho de metadados LP inválido'
tables_size = struct.unpack_from('<I', md, 44)[0]
tbl = lambda i: struct.unpack_from('<III', md, 80 + 12 * i)   # partitions, extents, groups, block_devices
(p_off, p_n, p_sz), (e_off, e_n, e_sz) = tbl(0), tbl(1)
T = hsize
exts = [struct.unpack_from('<QIQI', md, T + e_off + i * e_sz) for i in range(e_n)]
parts = {}
for i in range(p_n):
    b = T + p_off + i * p_sz
    name = md[b:b+36].rstrip(b'\0').decode(); attr, fe, ne, grp = struct.unpack_from('<IIII', md, b + 36)
    parts[name] = exts[fe:fe + ne]

if sys.argv[3:] == ['list'] or len(sys.argv) < 4:
    print(f'super lógico: {total} bytes, LP v{maj}.{mnr}')
    for n, ex in parts.items():
        print(f'  {n:16s} {sum(e[0] for e in ex) * 512:>12d} bytes  {len(ex)} extent(s)')
    sys.exit()

os.makedirs(sys.argv[2], exist_ok=True)
for name in sys.argv[3:]:
    ex = parts[name]; outp = os.path.join(sys.argv[2], name + '.img')
    with open(outp, 'wb') as o:
        for nsec, ttype, tdata, tsrc in ex:
            assert tsrc == 0, 'extent em outro block device'
            n = nsec * 512
            if ttype == 1: o.write(bytes(n)); continue
            off = tdata * 512
            while n > 0:
                k = min(n, 64 << 20); o.write(read_at(off, k)); off += k; n -= k
    print(f'{outp}: {os.path.getsize(outp)} bytes')
