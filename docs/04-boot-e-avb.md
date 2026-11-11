# 4. boot.img e vbmeta

## Formato do boot do M62

Lido do `boot.img` da LineageOS com `tools/bootimg_info.py`:

| Campo | Valor |
|---|---|
| header | v2, pagesize 2048 |
| base / kernel / ramdisk / tags | `0x10000000` / `+0x8000` / `+0x01000000` / `+0x100` |
| DTB | `+0x01f00000`, 239.616 bytes, formato DT table (`d7b7ab1e`) |
| kernel | `Image` **sem compressão** (o boot original da Samsung também é cru) |
| partição BOOT | 61.865.984 bytes |

Extraia o DTB (vai dentro do nosso boot):

```bash
python3 tools/bootimg_info.py lineage-f62/boot.img f62.dtb
```

## Gerar o boot

`tools/mkbootimg_v2.py` é um gerador próprio (o `mkbootimg.py` externo não foi necessário). Ele foi validado
reconstruindo o `boot.img` da LineageOS **byte a byte**, inclusive o ID SHA-1.

O initramfs do Droidian (`linux-initramfs-halium-generic`, repositório `production.repo.droidian.org`, suíte trixie)
tem 16,7 MB em gzip — não cabe com o kernel. Recomprimido em **XZ** (`--check=crc32`, kernel tem `CONFIG_RD_XZ=y`)
fica com 11,8 MB e o boot total com 60,5 MB.

```bash
scripts/build-boot-droidian.sh
```

## AVB / vbmeta — o que funciona e o que não funciona no Samsung

O bootloader do M62 (desbloqueado, estado `orange`) roda o libavb e uma verificação Samsung própria.

| vbmeta gravado | Resultado |
|---|---|
| vbmeta da LineageOS com 1 byte alterado (`flags=3`) | erro "VBMETA … verification" → Download Mode |
| vbmeta vazio sem assinatura (`flags=2`, sem descritores) | **bootloop** "no sign info"; nem a recovery abre |
| vbmeta Samsung original (assinado) | recovery abre; o sistema próprio não |
| **vbmeta da LineageOS (alg 0) com o hash do NOSSO boot + dtbo da LineageOS** | ✅ boota |

Ou seja: replicamos a estrutura de uma instalação LineageOS. `tools/avb_boot.py`:

1. lê o descritor de hash `boot` do `vbmeta.img` da LineageOS (salt de 32 bytes);
2. calcula `sha256(salt + nosso_boot)` e regrava tamanho + digest no mesmo lugar (nenhum offset muda);
3. acrescenta ao `boot.img` um vbmeta de footer com o mesmo descritor e o footer `AVBf`, preenchendo até o tamanho da partição.

Validação: regenerar a partir do boot da LineageOS reproduz o `vbmeta.img` dela idêntico.

O dtbo gravado precisa ser o **dtbo da LineageOS do mesmo build** (o descritor `dtbo` do vbmeta confere o hash).
Confirme no aparelho:

```bash
adb shell 'dd if=/dev/block/by-name/dtbo bs=606208 count=1 | md5sum'; head -c 606208 dtbo.img | md5sum
```

## Gravar

Pela recovery (ADB root) ou pelo próprio Droidian (sudo), sempre conferindo o tamanho da partição e relendo:

```bash
dd if=boot-avb.img of=/dev/block/by-name/boot bs=1M conv=fsync      # 61865984 bytes
dd if=vbmeta-droidian.img of=/dev/block/by-name/vbmeta bs=1M conv=fsync  # partição de 65536 bytes
```

O `scripts/install-droidian-from-recovery.sh` faz isso com verificação por leitura de volta.
