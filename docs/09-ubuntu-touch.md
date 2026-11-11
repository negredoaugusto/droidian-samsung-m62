# 9. Tentativa com Ubuntu Touch (24.04 + Halium 13)

Feita antes do Droidian, com a mesma base de kernel. Chegou até o **systemd 255 do Ubuntu 24.04 rodando** e à
rede USB do UBports (`1209:0004`, ping em 10.15.19.82), mas o sistema reiniciava ~50 s depois e a investigação
parou quando o objetivo mudou para o Droidian.

## Como foi montado

- Adaptação em `ubuntu-touch/samsung-m62/` (`deviceinfo` + overlay mínimo: `gbinder ApiLevel=33`, grid units).
- `scripts/build-boot.sh`: boot com o initramfs Halium do UBports
  (`initramfs-tools-halium` continuous, `initrd.img-touch-arm64`).
- `scripts/build-rootfs.sh`: **sem root**, dentro de `fakeroot`, junta o rootfs `ubuntu-touch-android9plus-rootfs-arm64`
  (24.04-2.x), o genérico `halium_halium_arm64.tar.xz` (Halium 13, Jenkins UBports) e o overlay, e gera o ext4 com
  `mkfs.ext4 -d` (reproduz `prepare-fake-ota.sh` + `system-image-from-ota.sh`). MD5 dos artefatos conferidos contra
  os *fingerprints* do Jenkins.
- Instalação final que funcionou: `/data/rootfs.img` + `/data/android-rootfs.img` (gravar no `system` lógico não
  serve, o initramfs não mapeia o `super`).

## O que faltou

Descobrir a causa dos reinícios após ~50 s (provavelmente outro panic; os patches 0001 e 0002 e o vendor A13 que
vieram depois podem ter resolvido). Os scripts estão aqui para quem quiser retomar.
