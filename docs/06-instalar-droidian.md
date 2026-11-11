# 6. Instalar o Droidian

## Ordem completa a partir do aparelho com bootloader desbloqueado

1. Lineage Recovery instalada (cap. 2) e backup da EFS feito (cap. 1).
2. Instale a LineageOS 23.2 uma vez (`Factory reset → Format data`, `Apply update → Apply from ADB`,
   `adb sideload lineage-23.2-…-f62-signed.zip`). Isso deixa **dtbo/vbmeta/partições** num estado conhecido —
   o nosso vbmeta pressupõe o dtbo desse build.
3. Grave vendor/odm Samsung originais (cap. 5).
4. Compile o kernel e gere boot/vbmeta (caps. 3 e 4).
5. Baixe o Droidian (release estável, api33):

```bash
mkdir -p $WORKDIR/droidian/downloads && cd $WORKDIR/droidian/downloads
B=https://github.com/droidian-images/droidian/releases/download/droidian/101.20261023
curl -LO $B/SHA256SUMS
curl -LO $B/droidian-OFFICIAL-phosh-phone-rootfs-api33-arm64-101.20261023_20261022.zip
curl -LO $B/droidian-devtools-api33-arm64_20261022.zip
grep -E "rootfs-api33|devtools-api33" SHA256SUMS | sha256sum -c
```

   E o initramfs (`linux-initramfs-halium-generic_…arm64.deb` do repositório Droidian, confira o SHA256 do
   `Packages.gz`), extraído em `$WORKDIR/droidian/initramfs-pkg`.

6. Na recovery: *Advanced → Enable ADB*, então:

```bash
scripts/install-droidian-from-recovery.sh
adb reboot
```

O script: formata `/data` em **ext4**, envia `rootfs.img` e `android-rootfs.img`, aumenta o rootfs para 8 GB
(como o instalador oficial), aplica o `devtools` (openssh etc. instalados no 1º boot via *systemd offline update*)
e grava boot/vbmeta com verificação.

> O zip oficial é feito para TWRP. A estrutura dele é só `data/rootfs.img` + um link
> `/data/android-rootfs.img → /halium-system/var/lib/lxc/android/android-rootfs.img`. Aqui copiamos o arquivo de
> verdade, que o initramfs encontra com certeza.

## Primeiro boot

- ~1,5 min até o SSH responder; o 1º boot instala os pacotes do devtools e **reinicia sozinho**.
- Rede USB: o PC recebe IP por DHCP; o aparelho é `10.15.19.82`.
- SSH: `ssh droidian@10.15.19.82` (senha `1234`; ou coloque sua chave em `/home/droidian/.ssh/authorized_keys`
  antes, montando o rootfs na recovery).
- Desbloqueio da tela: `1234`. **Troque com `passwd`.**
- Se a tela apagar depois do logo, aperte **Power** uma vez.

## Verificações úteis

```bash
systemctl is-active phosh; systemctl --failed
getprop ro.vendor.build.version.sdk                 # 33
sudo dmesg | grep -c "decon_ioctl:invalid command"  # ~1 (não centenas)
sudo journalctl -b _COMM=phoc | grep -E "HWC Version|GL renderer|Output"
```

Saída esperada do `phoc`: `HWC Version=2000001`, `width: 1080, height: 2400`, `GL renderer: Mali-G76`,
`Phosh ready`.
