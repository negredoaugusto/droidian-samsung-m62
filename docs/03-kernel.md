# 3. Compilar o kernel

Base: kernel oficial da LineageOS para a família Exynos 9820/9825 (tem `exynos9820-f62_defconfig`).

```bash
cd $WORKDIR
git clone --depth 1 -b lineage-23.2 https://github.com/LineageOS/android_kernel_samsung_exynos9820 kernel-exynos9820
cd kernel-exynos9820
git apply $REPO/kernel/patches/0001-security-call_int_hook-keep-default-return-value.patch
git apply $REPO/kernel/patches/0002-dpu20-decon-remove-fps-from-win_config_data-for-stock-HWC.patch
```

## Toolchain (sem sudo)

O `scripts/build-kernel.sh` usa o **clang 19 + ld.lld do NDK r28** (`LLVM=1 LLVM_IAS=1`). É uma versão próxima da
usada pela LineageOS; o clang mais novo do sistema tende a gerar erros neste kernel 4.14.

## Configuração

O script aplica `exynos9820-f62_defconfig` + `kernel/halium.config` (+ fragmento extra opcional) e confere 19 opções:

```bash
mkdir -p $WORKDIR/ubuntu-touch && cp $REPO/kernel/halium.config $WORKDIR/ubuntu-touch/
EXTRA_FRAG=$REPO/kernel/droidian.config $REPO/scripts/build-kernel.sh config
$REPO/scripts/build-kernel.sh build        # ~2 min incremental, log em out/build.log
```

### O que os fragmentos fazem

`halium.config` — requisitos do Halium/LXC/systemd que o defconfig da LineageOS não tem:
`SYSVIPC`, `FHANDLE`, `USER_NS`, `AUTOFS4_FS`, `VT`/`VT_CONSOLE`, `SECURITY_APPARMOR` (padrão), `BINFMT_MISC`,
`IKCONFIG_PROC`, namespaces e cgroups.

`droidian.config`:

```
CONFIG_CMDLINE="androidboot.boot_devices=13d60000.ufs console=tty0 droidian.lvm.prefer cgroup_disable=schedtune systemd.journald.forward_to_kmsg=yes log_buf_len=8M"
CONFIG_DEVTMPFS_MOUNT=y
CONFIG_VT_HW_CONSOLE_BINDING=y
CONFIG_SECURITY_SELINUX_BOOTPARAM=y
# CONFIG_KALLSYMS_ALL is not set
```

- O **cmdline tem que ir no kernel**: o bootloader Samsung ignora o cmdline do `boot.img` (veja cap. 7).
  `CONFIG_CMDLINE_EXTEND=y` já vem no defconfig. O port Droidian do Galaxy S9 faz o mesmo (`console=tty0 droidian.lvm.prefer`).
- `KALLSYMS_ALL=n` economiza ~1 MB: o kernel cru (48,5 MB) + initramfs Droidian precisam caber nos 61,9 MB da BOOT.
  Os nomes de funções continuam nos logs de crash.

## Os dois patches

### 0001 — `call_int_hook` (security/security.c)

A Samsung inseriu `RC = security_integrity_current();` no macro, **sobrescrevendo o valor padrão** (`IRC`). Quando
nenhum LSM implementa o hook (AppArmor não implementa `secid_to_secctx`), o resultado vira `0` = sucesso, com
`secdata` não inicializado. O `systemd-journald` recebe `SCM_SECURITY` e o kernel copia de um ponteiro lixo →
`usercopy: Kernel memory exposure attempt detected from null address (offset 1, size 127)` → panic.
O patch mantém `IRC` quando a verificação de integridade passa (comportamento do Linux upstream).

### 0002 — `decon_win_config_data` (drivers/video/fbdev/exynos/dpu20/decon.h)

A LineageOS acrescentou `u32 fps` à estrutura para o HWC do próprio vendor (Android 16). O HWC do vendor **Samsung
original** manda `S3CFB_WIN_CONFIG` (`_IOW('F', 209, …)`) com **1440 bytes**: 8 + 7×200 + 32. Com o campo extra o
kernel espera 1448 e recusa todo quadro (`DECON:ERR:decon_ioctl:invalid command : 0x45a046d1`).
O patch remove o campo; confira com o DWARF:

```bash
llvm-dwarfdump --name=decon_win_config_data out/drivers/video/fbdev/exynos/dpu20/decon_core.o | grep byte_size
# DW_AT_byte_size (0x05a0)  ← 1440
```

> Use este kernel **com o vendor Samsung original (Android 13)**. Com o vendor da LineageOS seria preciso o campo de volta.
