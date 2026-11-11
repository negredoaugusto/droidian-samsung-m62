import struct, sys, hashlib
d = open(sys.argv[1], 'rb').read()
if d[-64:-60] == b'AVBf':   # footer: vbmeta embutido no fim da partição
    _, _, orig, vb_off, vb_sz = struct.unpack_from('>4sIIQQQ'[:1] + 'IIQQQ', d, len(d)-64)[0:5] if False else (0,0,*struct.unpack_from('>QQQ', d, len(d)-64+12))
    print(f"footer: original_image_size={orig} vbmeta_offset={vb_off} size={vb_sz}"); d = d[vb_off:vb_off+vb_sz]
assert d[:4] == b'AVB0'
f = struct.unpack_from('>4sIIQQIQQQQQQQQQQQII', d, 0)
_, maj, mnr, auth, aux, alg, h_off, h_sz, s_off, s_sz, pk_off, pk_sz, pkm_off, pkm_sz, de_off, de_sz, rb, flags, rbl = f
print(f"libavb {maj}.{mnr} alg={alg} auth={auth} aux={aux} flags={flags} rollback={rb} release={d[128:176].rstrip(b'\0')}")
A = d[256+auth: 256+auth+aux]
pk = A[pk_off:pk_off+pk_sz]; print(f"pubkey {pk_sz}B sha1={hashlib.sha1(pk).hexdigest()}")
p = de_off
while p < de_off + de_sz:
    tag, nfb = struct.unpack_from('>QQ', A, p); body = A[p+16:p+16+nfb]
    if tag == 2:   # hash
        isz, halg, plen, slen, dlen, fl = struct.unpack_from(">Q32sIIII", body, 0)
        o = 8+32+16+60; name = body[o:o+plen].decode(); salt = body[o+plen:o+plen+slen]; dig = body[o+plen+slen:o+plen+slen+dlen]
        print(f"  HASH  {name}: size={isz} alg={halg.rstrip(b'\0').decode()} salt={salt.hex()[:16]}.. digest={dig.hex()[:16]}..")
    elif tag == 4: # chain
        rbl2, plen, kl, fl = struct.unpack_from('>IIII', body, 0); name = body[16+60:16+60+plen].decode()
        print(f"  CHAIN {name}: rollback_loc={rbl2} key={kl}B")
    elif tag == 1: # hashtree
        print(f"  HASHTREE (len {nfb})")
    elif tag == 0:
        print(f"  PROPERTY {body[16:16+struct.unpack_from('>Q',body,0)[0]].decode()}")
    else: print(f"  tag {tag}")
    p += 16 + nfb
