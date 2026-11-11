#!/usr/bin/env bash
# Instala o Droidian a partir da Lineage Recovery (Advanced -> Enable ADB) com adb root.
# ATENÇÃO: FORMATA /data (userdata) em ext4. Faça backup antes.
set -euo pipefail
WORKDIR=${WORKDIR:-$HOME/m62-work}; D=$WORKDIR/droidian; OUT=$D/out
ZIP=$(ls "$D"/downloads/droidian-OFFICIAL-phosh-phone-rootfs-api33-arm64-*.zip | head -1)
adb devices | grep -q recovery || { echo "Recovery com ADB não encontrada"; exit 1; }
adb root >/dev/null; sleep 2; adb wait-for-recovery

[ -f "$OUT/rootfs.img" ] || bsdtar -xOf "$ZIP" data/rootfs.img > "$OUT/rootfs.img"
[ -f "$OUT/android-rootfs.img" ] || debugfs -R "dump /var/lib/lxc/android/android-rootfs.img $OUT/android-rootfs.img" "$OUT/rootfs.img"

read -rp "Isto APAGA /data do celular. Digite SIM para continuar: " ok; [ "$ok" = SIM ] || exit 1
adb shell 'umount /data 2>/dev/null; mke2fs -F -t ext4 -L userdata /dev/block/by-name/userdata && mkdir -p /data && mount -t ext4 /dev/block/by-name/userdata /data'
adb push "$OUT/rootfs.img" /data/rootfs.img
adb push "$OUT/android-rootfs.img" /data/android-rootfs.img
adb shell 'e2fsck -fy /data/rootfs.img; resize2fs -f /data/rootfs.img 8G; sync'

# devtools (openssh-server etc.) instalados no 1º boot via systemd offline update
DT=$(ls "$D"/downloads/droidian-devtools-api33-arm64_*.zip 2>/dev/null | head -1 || true)
if [ -n "$DT" ]; then
  bsdtar -xOf "$DT" payload.tar > "$OUT/payload.tar"; adb push "$OUT/payload.tar" /data/payload.tar
  # o SELinux da recovery bloqueia loop em arquivos de /data: modo permissive até o próximo reboot
  adb shell 'setenforce 0; mkdir -p /r; L=$(losetup -f); losetup $L /data/rootfs.img && mount -t ext4 $L /r && tar -C /r -xf /data/payload.tar; sync; umount /r; losetup -d $L; rm /data/payload.tar'
fi

for p in boot vbmeta; do
  f=$OUT/$([ $p = boot ] && echo boot-avb.img || echo vbmeta-droidian.img)
  dev=$(adb shell readlink -f /dev/block/by-name/$p | tr -d '\r'); sz=$(adb shell blockdev --getsize64 "$dev" | tr -d '\r')
  case "$p:$sz" in boot:61865984|vbmeta:65536) ;; *) echo "tamanho inesperado de $p ($sz)"; exit 1;; esac
  adb push -q "$f" /tmp/img && adb shell "dd if=/tmp/img of=$dev bs=1M conv=fsync; sync"
  n=$(stat -c %s "$f"); [ "$(adb shell "dd if=$dev bs=$n count=1 2>/dev/null | md5sum" | cut -d' ' -f1)" = "$(md5sum < "$f" | cut -d' ' -f1)" ] \
    && echo "$p gravado e verificado" || { echo "falha na verificação de $p"; exit 1; }
done
echo "Pronto. adb reboot  →  Droidian (usuário droidian, senha 1234)"
