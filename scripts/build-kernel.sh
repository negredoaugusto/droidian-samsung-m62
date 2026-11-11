#!/usr/bin/env bash
# Build do kernel LineageOS exynos9820-f62 com o fragmento Halium/Ubuntu Touch.
# Uso:  build-kernel.sh config   -> gera out/.config e verifica as opções
#       build-kernel.sh build    -> compila Image + dtb (log em out/build.log)
set -euo pipefail

K=${WORKDIR:-$HOME/m62-work}/kernel-exynos9820
UT=${WORKDIR:-$HOME/m62-work}/ubuntu-touch
NDK=${NDK:-$HOME/Android/Sdk/ndk/28.2.13676358}/toolchains/llvm/prebuilt/linux-x86_64/bin
BC=${WORKDIR:-$HOME/m62-work}/tools/bc/pkg/usr/bin

export PATH="$NDK:$BC:$PATH"
export ARCH=arm64 SUBARCH=arm64
MK=(make -C "$K" O="$K/out" ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang LD=ld.lld
    CROSS_COMPILE=aarch64-linux-gnu- CLANG_TRIPLE=aarch64-linux-gnu-)

REQUIRED=(SYSVIPC FHANDLE USER_NS AUTOFS4_FS VT VT_CONSOLE SECURITY_APPARMOR
          DEFAULT_SECURITY_APPARMOR BINFMT_MISC IKCONFIG IKCONFIG_PROC POSIX_MQUEUE
          IPC_NS PID_NS NET_NS UTS_NS CGROUP_DEVICE CGROUP_FREEZER DEVTMPFS)

verify() {
  local bad=0
  for o in "${REQUIRED[@]}"; do
    if grep -q "^CONFIG_$o=y" "$K/out/.config"; then printf "  OK      %s\n" "$o"
    else printf "  FALTA   %s  (%s)\n" "$o" "$(grep -E "CONFIG_$o[ =]" "$K/out/.config" || echo ausente)"; bad=1; fi
  done
  grep '^CONFIG_DEFAULT_SECURITY=' "$K/out/.config"
  return $bad
}

case "${1:-}" in
  config)
    mkdir -p "$K/out"
    "${MK[@]}" exynos9820-f62_defconfig
    (cd "$K" && scripts/kconfig/merge_config.sh -m -O out out/.config "$UT/halium.config" ${EXTRA_FRAG:-})
    "${MK[@]}" olddefconfig
    echo "== Verificação das opções Ubuntu Touch"
    verify && echo "== Config OK" || { echo "== Há opções faltando (dependências do Kconfig)"; exit 1; }
    ;;
  build)
    [ -f "$K/out/.config" ] || { echo "Rode 'config' primeiro"; exit 1; }
    echo "Compilando com $(nproc) threads... log: $K/out/build.log"
    if "${MK[@]}" -j"$(nproc)" > "$K/out/build.log" 2>&1; then
      echo "== Build OK"; ls -lh "$K/out/arch/arm64/boot/"Image* 2>/dev/null
      find "$K/out/arch/arm64/boot/dts" -name '*.dtb' | head
    else
      echo "== Build FALHOU. Últimas linhas de erro:"; grep -nE "error:|Error [0-9]" "$K/out/build.log" | tail -20; exit 1
    fi
    ;;
  *) echo "uso: $0 config|build"; exit 1;;
esac
