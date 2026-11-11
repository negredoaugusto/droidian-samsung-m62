import struct, sys
d = open(sys.argv[1], 'rb').read(4096)
assert d[:8] == b'ANDROID!', 'not a boot image'
ks, ka, rs, ra, ss, sa, ta, ps, ver, osv = struct.unpack_from('<10I', d, 8)
print(f"header_version={ver} pagesize={ps}")
if ver < 3:
    name = d[48:64].rstrip(b'\0').decode(errors='replace')
    cmd = d[64:576].rstrip(b'\0').decode(errors='replace')
    base = ka - 0x8000
    print(f"kernel_size={ks} ramdisk_size={rs} second_size={ss}")
    print(f"kernel_addr=0x{ka:08x} ramdisk_addr=0x{ra:08x} second_addr=0x{sa:08x} tags_addr=0x{ta:08x}")
    print(f"guess base=0x{base:08x} off_kernel=0x{ka-base:08x} off_ramdisk=0x{ra-base:08x} off_second=0x{sa-base:08x} off_tags=0x{ta-base:08x}")
    print(f"name='{name}' cmdline='{cmd}'")
    if ver >= 1:
        rdtbo_size, rdtbo_off, hsz = struct.unpack_from('<IQI', d, 1632)
        print(f"recovery_dtbo_size={rdtbo_size} header_size={hsz}")
    if ver == 2:
        dtb_size, dtb_addr = struct.unpack_from('<IQ', d, 1648)
        print(f"dtb_size={dtb_size} dtb_addr=0x{dtb_addr:x} off_dtb=0x{dtb_addr-base:x}")
a, b = osv >> 11, osv & 0x7ff
print(f"os_version={a>>14}.{(a>>7)&0x7f}.{a&0x7f} patch={2000+(b>>4)}-{b&0xf:02d}")

# --- extração de DTB (header v2) e verificação de tail
if len(sys.argv) > 2 and ver == 2:
    f = open(sys.argv[1], 'rb').read()
    pg = lambda n: (n + ps - 1) // ps * ps
    off = ps + pg(ks) + pg(rs) + pg(ss) + pg(rdtbo_size)
    open(sys.argv[2], 'wb').write(f[off:off + dtb_size])
    print(f"dtb extraído: offset={off} -> {sys.argv[2]} (magic={f[off:off+4].hex()})")
    end = off + pg(dtb_size)
    print(f"tail após imagem: {f[end:end+16]!r}  (tamanho total arquivo={len(f)}, fim lógico={end})")
