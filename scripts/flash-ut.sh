#!/usr/bin/env bash
# Grava Ubuntu Touch (Halium 13) no Galaxy M62 a partir do fastbootd da Lineage Recovery.
# ATENÇÃO: substitui BOOT, VBMETA e SYSTEM e APAGA /data e /metadata.
# Restaurar: gravar o firmware original (BL/AP/CP/CSC) via samloader no Download Mode.
set -euo pipefail
O=${WORKDIR:-$HOME/m62-work}/ubuntu-touch/out
cd "$O" && sha256sum -c SHA256SUMS

fastboot devices | grep -q fastbootd || { echo "Aparelho não está em fastbootd"; exit 1; }
[ "$(fastboot getvar product 2>&1 | awk '/product:/{print $2}')" = f62 ] || { echo "Produto != f62"; exit 1; }

echo "== 1/4 boot";    fastboot flash boot   boot.img
echo "== 2/4 vbmeta";  fastboot flash vbmeta vbmeta-disabled.img
echo "== 3/4 system (rootfs Ubuntu Touch, ~4.5 GB)"; fastboot flash system rootfs.img
echo "== 4/4 reiniciando na recovery para formatar /data e /metadata em ext4"
fastboot reboot recovery
adb wait-for-recovery
adb shell 'umount /data 2>/dev/null; umount /metadata 2>/dev/null;
  mke2fs -F -t ext4 -L userdata /dev/block/by-name/userdata &&
  mke2fs -F -t ext4 -L metadata /dev/block/by-name/metadata && echo FORMAT_OK'
echo "Pronto. Para iniciar: adb reboot"
