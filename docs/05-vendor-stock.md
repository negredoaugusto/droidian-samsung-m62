# 5. Vendor Samsung original (Android 13)

## Por quê

O Droidian publica rootfs só até **api33** (Android 13). Se a LineageOS 23.2 foi instalada, o vendor passa a ser
**Android 16** (`ro.vendor.build.version.sdk=36`): o compositor é AIDL (`vendor.hwcomposer-3`) e as bibliotecas
gráficas exigem `libapexsupport.so`, que o container Halium 13 não tem. Resultado: `phoc` dá **SEGV** ao carregar o
backend hwcomposer.

Com o vendor Samsung original (API 33: `composer@2.2`, `mapper@4.0`, `hwcomposer.exynos9825.so`) o container e o
vendor batem.

## Extrair do firmware

`tools/super_extract.py` lê o `super.img` sparse (magic `ED26FF3A`) e os metadados LP sem `lpunpack`/`simg2img`:

```bash
cd firmware-stock && mkdir -p extract && cd extract
tar -xf ../AP_*.tar.md5 super.img.lz4 && lz4 -dq super.img.lz4 super.sparse.img
python3 $REPO/tools/super_extract.py super.sparse.img . list
python3 $REPO/tools/super_extract.py super.sparse.img stock-parts vendor odm
debugfs -R "cat /build.prop" stock-parts/vendor.img | grep -E "version.sdk|fingerprint"   # sdk=33
```

## Gravar (fastbootd da Lineage Recovery)

As partições lógicas não são verificadas pelo bootloader no boot, então boot/vbmeta continuam valendo.

```bash
fastboot flash vendor stock-parts/vendor.img
fastboot flash odm    stock-parts/odm.img
```

> Para usar a LineageOS de novo, reinstale o zip dela (ele regrava o vendor dela).
