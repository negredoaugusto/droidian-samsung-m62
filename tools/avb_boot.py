#!/usr/bin/env python3
"""Replica a estrutura AVB do LineageOS f62 para um boot.img próprio (sem assinatura RSA, alg=0):
  1) boot.img + vbmeta de footer (hash descriptor 'boot') + AVBf footer, preenchido até o tamanho da partição;
  2) cópia do vbmeta.img da Lineage com o hash descriptor 'boot' atualizado (tamanho + digest).
Uso: avb_boot.py <boot.img> <lineage-vbmeta.img> <partition_size> <out-boot.img> <out-vbmeta.img>"""
import hashlib, struct, sys

boot_in, vb_in, part_size, boot_out, vb_out = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5]
img = open(boot_in, 'rb').read()
vb = bytearray(open(vb_in, 'rb').read())
assert vb[:4] == b'AVB0' and struct.unpack_from('>I', vb, 28)[0] == 0, 'esperado vbmeta Lineage alg=0'

# --- localizar o hash descriptor 'boot' no vbmeta Lineage
auth, aux = struct.unpack_from('>QQ', vb, 12)
de_off, de_sz = struct.unpack_from('>QQ', vb, 96)
A0 = 256 + auth
p = de_off; loc = None
while p < de_off + de_sz:
    tag, n = struct.unpack_from('>QQ', vb, A0 + p)
    if tag == 2:
        b = A0 + p + 16
        isz, halg, pl, sl, dl, fl = struct.unpack_from('>Q32sIIII', vb, b)
        if vb[b+116:b+116+pl] == b'boot':
            loc = (b, pl, sl, dl, halg)
    p += 16 + n
assert loc, 'descriptor boot não encontrado'
b, pl, sl, dl, halg = loc
assert halg.rstrip(b'\0') == b'sha256' and dl == 32
salt = bytes(vb[b+116+pl:b+116+pl+sl])
digest = hashlib.sha256(salt + img).digest()

# --- 2) vbmeta principal: atualizar image_size e digest (mesmos tamanhos -> nenhum offset muda)
struct.pack_into('>Q', vb, b, len(img))
vb[b+116+pl+sl:b+116+pl+sl+dl] = digest
open(vb_out, 'wb').write(vb)

# --- 1) vbmeta de footer com um único hash descriptor 'boot'
body = struct.pack('>Q32sIIII', len(img), b'sha256', 4, len(salt), 32, 0) + b'\0' * 60 + b'boot' + salt + digest
body += b'\0' * ((8 - len(body) % 8) % 8)
desc = struct.pack('>QQ', 2, len(body)) + body
auxblk = desc + b'\0' * ((64 - len(desc) % 64) % 64)
hdr = b'AVB0' + struct.pack('>IIQQI', 1, 0, 0, len(auxblk), 0)
hdr += struct.pack('>10Q', 0, 0, 0, 0, len(desc), 0, len(desc), 0, 0, len(desc))
hdr += struct.pack('>QII', 0, 0, 0) + b'avbtool 1.3.0'.ljust(48, b'\0') + b'\0' * 80
assert len(hdr) == 256
footer_vb = hdr + auxblk

vb_offset = (len(img) + 4095) // 4096 * 4096
out = img.ljust(vb_offset, b'\0') + footer_vb
footer = b'AVBf' + struct.pack('>IIQQQ', 1, 0, len(img), vb_offset, len(footer_vb)) + b'\0' * 28
assert len(footer) == 64 and len(out) + 64 <= part_size, 'não cabe na partição'
out = out.ljust(part_size - 64, b'\0') + footer
open(boot_out, 'wb').write(out)
print(f"boot: {len(img)} B -> {boot_out} ({len(out)} B, footer vbmeta @ {vb_offset})")
print(f"digest boot = {digest.hex()}")
