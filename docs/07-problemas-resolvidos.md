# 7. Problemas encontrados e soluções

Em ordem cronológica. Cada item: **sintoma → causa → solução**.

### 1. Kernel original sem opções Halium
`/proc/config.gz` do stock: sem `SYSVIPC`, `USER_NS`, `FHANDLE`, `AUTOFS4_FS`, `VT`, `APPARMOR`…
→ kernel próprio a partir da LineageOS + `kernel/halium.config`.

### 2. Recovery Samsung sem fastbootd
`adb reboot fastboot` voltava ao Android (`reboot,fastboot`). → Lineage Recovery.

### 3. Download Mode: handshake falha / some depois de 2 s
Sessão já usada, cabo ou porta frontal (`error -71`). → Entrar de novo no modo a cada tentativa; porta traseira.

### 4. Não existe GSI do Ubuntu Touch que boote no kernel original
Desde o Halium 9 é `boot.img` próprio + rootfs. → Montamos tudo (cap. 9).

### 5. `VBMETA … Verification failed` no primeiro boot
vbmeta da LineageOS com flags alteradas; o bootloader Samsung não aceita só desligar as flags.

### 6. Bootloop "no sign info"
vbmeta vazio sem assinatura: o bootloader rejeita até a recovery; tela piscando em loop.
→ Entrar no Download Mode durante o loop (**Vol− + Vol+** com cabo; ou Vol−+Power e trocar para Vol−+Vol+),
gravar o vbmeta **Samsung original** num tar `--AP` (cap. 2). Na tela azul *"An error has occurred…"* a gravação
só limpa o erro quando termina com o reinício normal (sem `--no-reboot`).

### 7. Download Mode recusa vbmeta/boot próprios (`LOKE FAIL`)
→ Gravar boot/vbmeta/dtbo pelo **fastbootd** ou com `dd` na recovery.

### 8. "Failed to boot" no initramfs (telnet 192.168.2.15:23)
`Halium rootfs is` (vazio): o cmdline do `boot.img` (com `systempart=`) é **ignorado** pelo bootloader, e o
initramfs não mapeia partições dinâmicas. → rootfs em `/data/rootfs.img` e o container em `/data/android-rootfs.img`.

### 9. Watchdog reinicia o aparelho no shell do initramfs (~4 min)
Transferências longas pela rede USB eram cortadas. → Enviar comprimido (gzip, 1,26 GB em vez de 4,8 GB).

### 10. `run-init: opening console: No such device` / `No init found`
O bootloader passa `console=ram`, driver inexistente → sem `/dev/console`. → `console=tty0` em `CONFIG_CMDLINE`.

### 11. Panic em `systemd-journald` (`usercopy_abort ← put_cmsg ← unix_dgram_recvmsg`)
Bug Samsung em `call_int_hook` com AppArmor (cap. 3, patch 0001). Lido em `/sys/fs/pstore/dmesg-ramoops-0`
e `/proc/last_kmsg` pela recovery.

### 12. LineageOS: vendor Android 16 incompatível com Droidian api33
`phoc`: `library "libapexsupport.so" not found` → SEGV. → vendor/odm Samsung A13 (cap. 5).

### 13. Phosh rodando mas tela preta
`DECON:ERR:decon_ioctl:invalid command : 0x45a046d1` a cada quadro. Decodificação: tipo `F`, nº 209
(`S3CFB_WIN_CONFIG`), tamanho `0x5a0` = 1440. DWARF do driver: kernel esperava 1448. Comparando com o kernel
stock do Note10 (mesmo Exynos 9825): LineageOS adicionou `u32 fps`. → patch 0002.

### 14. Bluetooth (`bluebinder.service` falha) — em aberto
`waitforservice +(init.svc.*bt*|init.svc.*bluetooth*)` nunca satisfaz: o HAL de Bluetooth do vendor não sobe no
container. Próximo passo: logcat do container (`sudo lxc-attach -n android -- logcat`).

## Como pegar logs

- **Crash do kernel**: recovery → `cat /sys/fs/pstore/dmesg-ramoops-0`, `cat /proc/last_kmsg`.
- **Initramfs falhou**: rede RNDIS "Failed to boot", `tools/halium_sh.py 'dmesg | grep initrd'`.
- **Sistema de pé**: SSH + `sudo journalctl -b`.
