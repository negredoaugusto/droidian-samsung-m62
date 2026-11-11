#!/usr/bin/env python3
"""Gerador mínimo de boot.img Android (header v0-v2), compatível com o layout do AOSP mkbootimg."""
import argparse, hashlib, re, struct

def os_version(ver, patch):
    a, b, c = (list(map(int, ver.split('.'))) + [0, 0])[:3]
    y, m = map(int, re.match(r'(\d{4})-(\d{2})', patch).groups())
    return ((a << 14) | (b << 7) | c) << 11 | ((y - 2000) << 4) | m

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--kernel', required=True); p.add_argument('--ramdisk', required=True)
    p.add_argument('--dtb'); p.add_argument('--cmdline', default='')
    p.add_argument('--header_version', type=int, default=2)
    for k, v in [('base', 0x10000000), ('kernel_offset', 0x8000), ('ramdisk_offset', 0x1000000),
                 ('second_offset', 0), ('tags_offset', 0x100), ('dtb_offset', 0x1f00000)]:
        p.add_argument('--' + k, type=lambda s: int(s, 0), default=v)
    p.add_argument('--second_addr_zero', action='store_true', help='grava second_addr=0 (como o boot LineageOS f62)')
    p.add_argument('--pagesize', type=int, default=2048)
    p.add_argument('--os_version', default='13'); p.add_argument('--os_patch_level', default='2024-11')
    p.add_argument('--size', type=int, help='preenche com zeros até este tamanho (tamanho da partição)')
    p.add_argument('-o', '--output', required=True)
    a = p.parse_args()

    kernel = open(a.kernel, 'rb').read(); ramdisk = open(a.ramdisk, 'rb').read()
    dtb = open(a.dtb, 'rb').read() if a.dtb else b''
    hv, ps = a.header_version, a.pagesize
    cmd = a.cmdline.encode()
    assert len(cmd) < 512 + 1024, 'cmdline longa demais'

    sha = hashlib.sha1()
    for blob in (kernel, ramdisk, b''):           # kernel, ramdisk, second
        sha.update(blob); sha.update(struct.pack('<I', len(blob)))
    if hv >= 1:
        sha.update(b''); sha.update(struct.pack('<I', 0))  # recovery_dtbo
    if hv >= 2:
        sha.update(dtb); sha.update(struct.pack('<I', len(dtb)))
    img_id = sha.digest().ljust(32, b'\0')

    second_addr = 0 if a.second_addr_zero else a.base + a.second_offset
    hdr = b'ANDROID!' + struct.pack('<10I', len(kernel), a.base + a.kernel_offset, len(ramdisk),
                                    a.base + a.ramdisk_offset, 0, second_addr, a.base + a.tags_offset,
                                    ps, hv, os_version(a.os_version, a.os_patch_level))
    hdr += b'\0' * 16                                   # name
    hdr += cmd[:512].ljust(512, b'\0')                  # cmdline
    hdr += img_id                                       # id
    hdr += cmd[512:].ljust(1024, b'\0')                 # extra_cmdline
    if hv >= 1:
        hdr += struct.pack('<IQI', 0, 0, {1: 1648, 2: 1660}.get(hv, 1660))
    if hv >= 2:
        hdr += struct.pack('<IQ', len(dtb), a.base + a.dtb_offset)

    pad = lambda b: b + b'\0' * ((ps - len(b) % ps) % ps)
    out = pad(hdr) + pad(kernel) + pad(ramdisk) + (pad(dtb) if hv >= 2 else b'')
    if a.size:
        assert len(out) <= a.size, f'imagem ({len(out)}) maior que a partição ({a.size})'
        out = out.ljust(a.size, b'\0')
    open(a.output, 'wb').write(out)
    print(f'{a.output}: {len(out)} bytes, id={img_id[:20].hex()}')

if __name__ == '__main__':
    main()
