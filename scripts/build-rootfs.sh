#!/usr/bin/env bash
# Monta out/rootfs.img (Ubuntu Touch 24.04-2.x + Halium 13 + overlay f62) SEM root:
# tudo roda dentro de uma sessão fakeroot e a imagem ext4 é gerada com `mkfs.ext4 -d`.
# Reproduz prepare-fake-ota.sh + system-image-from-ota.sh das halium-generic-adaptation-build-tools.
set -euo pipefail
UT=${WORKDIR:-$HOME/m62-work}/ubuntu-touch
DL=$UT/downloads
OUT=$UT/out
W=$OUT/stage                      # $W/system = raiz da imagem
source "$UT/samsung-m62/deviceinfo"

if [ "${INSIDE_FAKEROOT:-}" != 1 ]; then
  (cd "$DL" && md5sum -c MD5SUMS.jenkins) || { echo "MD5 não confere com o Jenkins"; exit 1; }
  rm -rf "$W"; mkdir -p "$W/system"
  INSIDE_FAKEROOT=1 exec fakeroot -- "$0" "$@"
fi

echo "== 1/6 rootfs Ubuntu Touch"
tar xpzf "$DL/ubuntu-touch-android9plus-rootfs-arm64.tar.gz" --numeric-owner -C "$W/system"

echo "== 2/6 ajustes de depuração (iguais ao prepare-fake-ota devel)"
printf 'start on startup\nexec /usr/sbin/sshd -D -o PasswordAuthentication=yes -o PermitEmptyPasswords=yes\n' > "$W/system/etc/init/ssh.override"
printf 'start on startup\nexec /bin/bash /usr/bin/usb-tethering\n' > "$W/system/etc/init/usb-tethering.conf"
printf 'ADBD_SECURE=0\n' > "$W/system/etc/default/adbd"

echo "== 3/6 Halium 13 genérico (container Android)"
xzcat "$DL/halium_halium_arm64.tar.xz" | tar --numeric-owner -xf - -C "$W"
[ -e "$W/system/var/lib/lxc/android/system.img" ] && mv "$W/system/var/lib/lxc/android/system.img" "$W/system/var/lib/lxc/android/android-rootfs.img"
ls -l "$W/system/var/lib/lxc/android/"

echo "== 4/6 overlay do f62 (modo overlaystore -> /opt/halium-overlay)"
mkdir -p "$W/system/opt/halium-overlay"
cp -a "$UT/samsung-m62/overlay/system/." "$W/system/opt/halium-overlay/"
chown -R 0:0 "$W/system/opt/halium-overlay"

echo "== 5/6 version / channel.ini"
mkdir -p "$W/system/etc/system-image/config.d"
cat > "$W/system/etc/system-image/channel.ini" <<EOF
[service]
base: system-image.ubports.com
http_port: 80
https_port: 443
channel: 24.04-2.x/arm64/android9plus/daily
device: $deviceinfo_codename
EOF
ln -sf ../client.ini "$W/system/etc/system-image/config.d/00_default.ini"
ln -sf ../channel.ini "$W/system/etc/system-image/config.d/01_channel.ini"
chmod 755 "$W/system"
rm -rf "$W/partitions"

echo "== 6/6 gerando ext4 ($deviceinfo_system_partition_size)"
rm -f "$OUT/rootfs.img"
mkfs.ext4 -q -F -b "$deviceinfo_rootfs_image_sector_size" -O ^orphan_file -L rootfs \
  -d "$W/system" "$OUT/rootfs.img" "$deviceinfo_system_partition_size"
e2fsck -fn "$OUT/rootfs.img" | tail -2
ls -lh "$OUT/rootfs.img"
