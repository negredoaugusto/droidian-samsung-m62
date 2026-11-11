#!/usr/bin/env bash
# Monta out/boot.img do Ubuntu Touch para o Galaxy M62 (f62) a partir do kernel local.
set -euo pipefail
UT=${WORKDIR:-$HOME/m62-work}/ubuntu-touch
K=${WORKDIR:-$HOME/m62-work}/kernel-exynos9820/out
DL=$UT/downloads
source "$UT/samsung-m62/deviceinfo"
mkdir -p "$UT/out"

python3 -I "$UT/tools/mkbootimg_v2.py" \
  --kernel "$K/arch/arm64/boot/$deviceinfo_kernel_image_name" \
  --ramdisk "$DL/halium-boot-ramdisk.img" \
  --dtb "$UT/samsung-m62/$deviceinfo_bootimg_prebuilt_dtb" \
  --cmdline "$deviceinfo_kernel_cmdline" \
  --header_version "$deviceinfo_bootimg_header_version" \
  --base "$deviceinfo_flash_offset_base" \
  --kernel_offset "$deviceinfo_flash_offset_kernel" \
  --ramdisk_offset "$deviceinfo_flash_offset_ramdisk" \
  --second_addr_zero \
  --tags_offset "$deviceinfo_flash_offset_tags" \
  --dtb_offset "$deviceinfo_flash_offset_dtb" \
  --pagesize "$deviceinfo_flash_pagesize" \
  --os_version "$deviceinfo_bootimg_os_version" \
  --os_patch_level "$deviceinfo_bootimg_os_patch_level" \
  -o "$UT/out/boot.img"

size=$(stat -c %s "$UT/out/boot.img")
echo "boot.img: $size bytes (partição: $deviceinfo_bootimg_partition_size)"
[ "$size" -le "$deviceinfo_bootimg_partition_size" ] || { echo "ERRO: não cabe na partição BOOT"; exit 1; }
python3 -I "$UT/tools/bootimg_info.py" "$UT/out/boot.img"
sha256sum "$UT/out/boot.img" | tee "$UT/out/boot.img.sha256"
