# Linux (Droidian) no Samsung Galaxy M62 — SM-M625F

Port experimental do **Droidian** (Debian GNU/Linux + interface **Phosh**) para o **Samsung Galaxy M62
(SM-M625F, Exynos 9825, codinome LineageOS `f62`)**, feito sobre o kernel da LineageOS com Halium 13.

> ⚠️ **Experimental.** Desbloquear o bootloader queima o eFuse de garantia (Knox) e apaga os dados.
> Siga por sua conta e risco. Tudo aqui foi testado em **um** aparelho, firmware `M625FXXS7CXK2` (Android 13, CSC ZTO/Brasil).

## Estado atual

| Item | Situação |
|---|---|
| Boot até a interface (Phosh, tela de bloqueio) | ✅ |
| Kernel 4.14 (LineageOS) com opções Halium/Droidian | ✅ |
| GPU Mali-G76 (OpenGL ES 3.2 via libhybris), tela 1080x2400 @ 60 Hz | ✅ |
| Rede USB + SSH (`droidian@10.15.19.82`) | ✅ |
| Container Android (Halium 13 / API 33) com vendor Samsung original | ✅ |
| Bluetooth | ❌ (`bluebinder` falha) |
| Toque, áudio, Wi-Fi, modem/chamadas, câmera, sensores | ❓ não testados ainda |

## Como funciona (arquitetura)

```
┌─────────────────────────────────────────────┐
│ Droidian (Debian trixie) — Phosh, apt, apps  │  /data/rootfs.img
├─────────────────────────────────────────────┤
│ libhybris  ⇄  container LXC Android (Halium 13) │  /data/android-rootfs.img
│                 └─ HALs do vendor Samsung A13   │  partições vendor/odm (stock)
├─────────────────────────────────────────────┤
│ Kernel Linux 4.14 (LineageOS + patches)      │  partição BOOT (+ initramfs Droidian)
├─────────────────────────────────────────────┤
│ Bootloader Samsung (desbloqueado, "orange") │  VBMETA estilo LineageOS (alg 0)
└─────────────────────────────────────────────┘
```

## Passo a passo (resumo)

Cada passo tem um capítulo detalhado em [`docs/`](docs/).

1. **[Preparação e backup](docs/01-preparacao-e-backup.md)** — desbloquear bootloader, baixar ferramentas, backup da EFS/IMEI.
2. **[Instalar a Lineage Recovery](docs/02-lineage-recovery.md)** — via Download Mode com `samloader-rs`.
3. **[Compilar o kernel](docs/03-kernel.md)** — kernel LineageOS `exynos9820` + fragmentos + 2 patches.
4. **[Montar boot.img e vbmeta](docs/04-boot-e-avb.md)** — header v2, DTB, footer AVB e vbmeta coerente.
5. **[Voltar o vendor Samsung Android 13](docs/05-vendor-stock.md)** — o Droidian precisa de vendor API 33.
6. **[Instalar o Droidian](docs/06-instalar-droidian.md)** — rootfs em `/data`, devtools, boot/vbmeta, primeiro boot.
7. **[Problemas encontrados e soluções](docs/07-problemas-resolvidos.md)** — o diário técnico de tudo que quebrou e por quê.
8. **[Voltar ao Android original](docs/08-restaurar-android.md)** — restaurar o firmware Samsung.
9. **[Tentativa com Ubuntu Touch](docs/09-ubuntu-touch.md)** — chegou ao systemd; ficou de lado em favor do Droidian.

## As 5 descobertas que fazem isto funcionar no M62

1. **O bootloader Samsung ignora o cmdline do `boot.img`.** Parâmetros (`console=tty0`, `droidian.lvm.prefer`…) vão
   em `CONFIG_CMDLINE` com `CONFIG_CMDLINE_EXTEND=y`.
2. **`console=tty0` é obrigatório**: o bootloader passa `console=ram`, que não existe no kernel; sem console o `run-init`
   do initramfs falha (“No init found”).
3. **Bug da Samsung em `security/security.c`** (`call_int_hook` sobrescreve o valor padrão com 0): com AppArmor,
   `security_secid_to_secctx()` devolve "sucesso" com ponteiro lixo → panic em `systemd-journald` (`usercopy_abort`).
   → [`kernel/patches/0001`](kernel/patches/).
4. **A LineageOS acrescentou `u32 fps` em `decon_win_config_data`**: o HWC do vendor Samsung envia
   `S3CFB_WIN_CONFIG` com 1440 bytes e o kernel esperava 1448 → nenhum quadro chegava à tela (`decon_ioctl: invalid command 0x45a046d1`).
   → [`kernel/patches/0002`](kernel/patches/).
5. **AVB/vbmeta no Samsung**: vbmeta vazio sem assinatura causa bootloop (“no sign info”); o que funciona é
   **o vbmeta da LineageOS (alg 0) com o hash do nosso boot** + o dtbo da LineageOS. Gravar vbmeta pelo Download Mode
   falha (`LOKE FAIL`); grave pelo fastbootd/recovery.

## Conteúdo do repositório

| Caminho | O que é |
|---|---|
| `kernel/halium.config` | Fragmento com as opções exigidas por Halium/Ubuntu Touch/Droidian |
| `kernel/droidian.config` | Fragmento extra do Droidian (cmdline embutido, `KALLSYMS_ALL=n` para caber na BOOT) |
| `kernel/patches/` | Os 2 patches do kernel |
| `scripts/build-kernel.sh` | `config` / `build` do kernel com clang 19 do NDK (sem sudo) |
| `scripts/build-boot-droidian.sh` | Gera `boot-avb.img` + `vbmeta-droidian.img` |
| `scripts/install-droidian-from-recovery.sh` | Instala o Droidian pela Lineage Recovery via ADB |
| `tools/mkbootimg_v2.py` | Gerador de boot.img v0–v2 (validado byte a byte contra o boot da LineageOS) |
| `tools/avb_boot.py` | Footer AVB + vbmeta com o hash do boot (formato LineageOS) |
| `tools/avb_info.py`, `tools/bootimg_info.py` | Leitores de vbmeta/footer AVB e de cabeçalho de boot.img (+ extração de DTB) |
| `tools/super_extract.py` | Extrai partições lógicas de `super.img` (sparse/raw) sem `lpunpack`/`simg2img` |
| `tools/halium_sh.py`, `tools/flash_from_initrd.sh` | Shell de depuração do initramfs Halium (telnet 192.168.2.15:23) |
| `ubuntu-touch/` | Adaptação (deviceinfo/overlay) da tentativa com Ubuntu Touch; scripts em `scripts/build-boot.sh`, `build-rootfs.sh`, `flash-ut.sh` |

**Não estão no repositório** (e não devem ser publicados): firmware/vendor Samsung (proprietários), backups da EFS
(contêm o IMEI), chaves SSH, imagens geradas.

## Créditos

LineageOS (kernel `android_kernel_samsung_exynos9820`, recovery, dtbo), Droidian (rootfs, initramfs, adaptação do
Exynos 9810 usada como referência), UBports/Halium (ferramentas e containers genéricos), topjohnwu (`samloader-rs`),
physwizz (kernel do Note10 baseado no stock, usado para comparar o driver de vídeo).

## Licença

Scripts e ferramentas deste repositório: MIT (veja `LICENSE`). Os patches de kernel seguem a licença do kernel Linux
(GPL-2.0).
