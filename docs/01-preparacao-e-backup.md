# 1. Preparação e backup

## Requisitos no PC (Linux)

- `adb` e `fastboot` (Android SDK platform-tools)
- Android NDK r28 (clang 19 + `ld.lld`) — usado para compilar o kernel **sem sudo**
- `bc` (o kernel precisa para gerar `timeconst.h`); sem sudo dá para extrair o pacote oficial do Arch e conferir o SHA256 pelo banco do pacman
- `python3`, `bsdtar`, `lz4`, `xz`, `e2fsprogs` (`debugfs`, `mkfs.ext4`, `e2fsck`)
- [`samloader-rs`](https://github.com/topjohnwu/samloader-rs/releases) — conversa com o Download Mode (substitui Odin/heimdall)

Defina a pasta de trabalho usada pelos scripts:

```bash
export WORKDIR=$HOME/m62-work
export NDK=$HOME/Android/Sdk/ndk/28.2.13676358
```

## Verificar o aparelho

```bash
adb devices -l                       # model:SM_M625F device:m62
adb shell getprop ro.build.PDA       # M625FXXS7CXK2 (firmware Android 13 exigido pela LineageOS)
adb shell getprop ro.boot.flash.locked   # 0 = desbloqueado
adb shell getprop ro.boot.verifiedbootstate  # orange
adb shell getprop ro.boot.dynamic_partitions # true (super)
```

O M62 é **A-only** com **partições dinâmicas** (`super` contém system/vendor/product/odm).

## Desbloquear o bootloader (se ainda não fez)

Configurações → Opções do desenvolvedor → **Desbloqueio OEM**. Depois, com o aparelho desligado,
segure **Vol− + Vol+** e conecte o cabo → na tela azul, **segure Vol+** (Device unlock mode). Isso apaga tudo.

## Backup da EFS (IMEI) — faça antes de tudo

O firmware oficial **não** restaura a EFS. Com a Lineage Recovery instalada (capítulo 2), em `adb root`:

```bash
mkdir -p backup-efs && cd backup-efs
for p in efs sec_efs cpefs persistent keystorage param up_param steady misc; do
  adb exec-out "dd if=/dev/block/by-name/$p bs=4096 2>/dev/null" > $p.img
  echo "$p: $(adb shell "dd if=/dev/block/by-name/$p bs=4096 2>/dev/null | sha256sum" | cut -d' ' -f1) / $(sha256sum < $p.img | cut -d' ' -f1)"
done
```

Os dois hashes de cada linha devem ser iguais. **Guarde essa pasta fora do PC e nunca publique** (contém o IMEI).
O código de região (CSC) fica em `sec_efs`: `debugfs -R "cat /imei/mps_code.dat" sec_efs.img` → `ZTO`.

## Baixar o firmware original (para restaurar depois)

```bash
samloader check-update -m SM-M625F -r ZTO          # M625FXXS7CXK2/...
samloader download -m SM-M625F -r ZTO -d firmware-stock
```

Ele traz `BL_`, `AP_`, `CP_`, `CSC_`/`HOME_CSC_` (`.tar.md5`). O `AP` contém `super.img.lz4` (vendor Android 13
usado no capítulo 5) e o `vbmeta.img` assinado pela Samsung (usado para sair de bootloop, capítulo 7).

## USB: dica importante

Use uma porta **traseira** da placa-mãe. A porta frontal deu `error -71` (falha elétrica) o tempo todo, e o
Download Mode cai se o cabo mexer.
