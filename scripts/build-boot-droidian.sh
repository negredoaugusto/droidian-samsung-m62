#!/usr/bin/env bash
# Gera boot.img (kernel + initramfs Droidian recomprimido em XZ) + footer AVB e o vbmeta coerente.
# Requer: kernel compilado (scripts/build-kernel.sh com EXTRA_FRAG=kernel/droidian.config),
#         $WORKDIR/lineage-f62/vbmeta.img (LineageOS f62) e o DTB extraído do boot.img da LineageOS.
set -euo pipefail
WORKDIR=${WORKDIR:-$HOME/m62-work}; REPO=$(cd "$(dirname "$0")/.." && pwd)
K=$WORKDIR/kernel-exynos9820/out/arch/arm64/boot/Image
INITRD=$WORKDIR/droidian/initramfs-pkg/usr/lib/aarch64-linux-gnu/halium-generic-initramfs/initrd.img-halium-generic
OUT=$WORKDIR/droidian/out; mkdir -p "$OUT"
DTB=$OUT/f62.dtb
[ -f "$DTB" ] || python3 -I "$REPO/tools/bootimg_info.py" "$WORKDIR/lineage-f62/boot.img" "$DTB"
# o initramfs gzip (16,7 MB) não cabe junto do kernel na BOOT (61.865.984 bytes): recomprime em XZ (~11,8 MB)
zcat "$INITRD" | xz --check=crc32 --lzma2=preset=9e,dict=32MiB -T1 > "$OUT/initrd-droidian.xz"
python3 -I "$REPO/tools/mkbootimg_v2.py" --kernel "$K" --ramdisk "$OUT/initrd-droidian.xz" --dtb "$DTB" \
  --cmdline "" --header_version 2 --base 0x10000000 --kernel_offset 0x8000 --ramdisk_offset 0x1000000 \
  --second_addr_zero --tags_offset 0x100 --dtb_offset 0x1f00000 --pagesize 2048 \
  --os_version 13 --os_patch_level 2024-11 -o "$OUT/boot.img"
python3 -I "$REPO/tools/avb_boot.py" "$OUT/boot.img" "$WORKDIR/lineage-f62/vbmeta.img" 61865984 \
  "$OUT/boot-avb.img" "$OUT/vbmeta-droidian.img"
md5sum "$OUT/boot-avb.img" "$OUT/vbmeta-droidian.img" | tee "$OUT/MD5SUMS"
