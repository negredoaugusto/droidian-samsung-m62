#!/usr/bin/env bash
# Grava boot e vbmeta a partir do shell de depuração do initramfs Halium (192.168.2.15:23).
# Identifica as partições por PARTNAME e só grava se o tamanho bater com a PIT.
set -euo pipefail
UT=${WORKDIR:-$HOME/m62-work}/ubuntu-touch
SH="python3 -I $UT/tools/halium_sh.py"
declare -A IMG=([boot]=$UT/out/boot-avb.img [vbmeta]=$UT/out/vbmeta-ut.img)
declare -A PSIZE=([boot]=61865984 [vbmeta]=65536)

echo "[$(date +%T)] aguardando o shell do initrd..."
for i in $(seq 1 200); do timeout 2 bash -c '</dev/tcp/192.168.2.15/23' 2>/dev/null && break; sleep 2; done
sleep 2

for p in boot vbmeta; do
  dev=$($SH "for u in /sys/class/block/sd*/uevent; do grep -q '^PARTNAME=$p\$' \$u && basename \$(dirname \$u); done" 8 | grep -oE '^sd[a-z][0-9]+$' | head -1)
  [ -n "$dev" ] || { echo "partição $p não encontrada"; exit 1; }
  sz=$($SH "echo \$((\$(cat /sys/class/block/$dev/size)*512))" 6 | grep -oE '^[0-9]+$' | head -1)
  echo "$p -> /dev/$dev ($sz bytes)"
  [ "$sz" = "${PSIZE[$p]}" ] || { echo "TAMANHO NÃO CONFERE para $p (esperado ${PSIZE[$p]}) — abortando"; exit 1; }
  n=$(stat -c %s "${IMG[$p]}"); want=$(head -c "$n" "${IMG[$p]}" | md5sum | cut -d' ' -f1)
  [ -e /dev/$dev ] 2>/dev/null || true
  $SH "(nc -l -p 5556 > /tmp/$p.img) </dev/null >/dev/null 2>&1 & sleep 1" 6 >/dev/null; sleep 1
  python3 -I -c "
import socket,sys,time
for i in range(20):
    try: s=socket.create_connection(('192.168.2.15',5556),timeout=30); break
    except OSError: time.sleep(0.5)
else: sys.exit('listener indisponível')
s.sendall(open(sys.argv[1],'rb').read()); s.shutdown(socket.SHUT_WR); s.close()" "${IMG[$p]}"
  sleep 2
  got=$($SH "md5sum /tmp/$p.img" 20 | grep -oE '^[0-9a-f]{32}' | head -1)
  [ "$got" = "$want" ] || { echo "MD5 do upload não confere ($got != $want)"; exit 1; }
  $SH "dd if=/tmp/$p.img of=/dev/$dev bs=1M conv=fsync 2>&1 | tail -1; sync" 30
  back=$($SH "dd if=/dev/$dev bs=$n count=1 2>/dev/null | md5sum" 30 | grep -oE '^[0-9a-f]{32}' | head -1)
  [ "$back" = "$want" ] && echo "[$(date +%T)] $p GRAVADO E VERIFICADO ($back)" || { echo "LEITURA DE VOLTA NÃO CONFERE em $p ($back)"; exit 1; }
done
echo "[$(date +%T)] reiniciando"; $SH 'sync; (sleep 1; reboot -f) </dev/null >/dev/null 2>&1 & sleep 0' 4 >/dev/null
