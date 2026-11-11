# 2. Instalar a Lineage Recovery

A recovery original da Samsung **não tem fastbootd** (`adb reboot fastboot` só reinicia o Android). A
**Lineage Recovery** do `f62` tem fastbootd, ADB root e é o caminho para gravar tudo depois.

## Baixar

```bash
curl -s https://download.lineageos.org/api/v2/devices/f62/builds | python3 -m json.tool | less
# baixe recovery.img, vbmeta.img, dtbo.img e boot.img do MESMO build e confira o sha256
```

O `recovery.img` tem exatamente o tamanho da partição RECOVERY (71.102.464 bytes) — bom sinal de que é o certo.

## Gravar pelo Download Mode

1. Desligue; segure **Vol− + Vol+** e conecte o cabo; na tela azul aperte **Vol+** (Continue).
2. `samloader print-pit` (só leitura) para testar a conexão. Se der `Failed to send handshake`, saia e entre no
   Download Mode de novo — **cada sessão do Download Mode só aceita uma conexão**.
3. Grave:

```bash
samloader flash --partition RECOVERY recovery.img --no-reboot
```

4. A tela continua em "Downloading…". Segure **Vol− + Power** até apagar e **na hora** troque para **Vol+ + Power**
   até aparecer a Lineage Recovery. Se o Android iniciar antes, ele restaura a recovery original.

## Usar a recovery

- **ADB**: *Advanced → Enable ADB* (volta a ficar desligado a cada reinício). Em seguida `adb root`.
- **fastbootd**: *Advanced → Enter fastboot*. `fastboot getvar is-userspace` → `yes`.
- O SELinux da recovery bloqueia `mount -o loop` de arquivos em `/data` (`I/O error`/`Invalid argument`):
  use `setenforce 0` antes (vale até reiniciar).

## Observações sobre o Download Mode do M62

- Gravar `RECOVERY` direto funciona. Gravar `VBMETA` (ou pacotes com vbmeta sem assinatura Samsung) **falha** com
  `LOKE returned general failure`. Depois de uma falha aparece a tela azul
  *"An error has occurred while updating the device software"* — ela some com uma gravação bem-sucedida.
- No `samloader`, a opção de pacote é `--AP` (maiúsculo).
- Para tirar o aparelho de um bootloop de vbmeta, grave o **vbmeta original assinado** dentro de um tar no slot AP:

```bash
tar -xf AP_*.tar.md5 vbmeta.img.lz4
tar -H ustar --owner=0 --group=0 -cf AP_vbmeta_stock.tar vbmeta.img.lz4
cp AP_vbmeta_stock.tar AP_vbmeta_stock.tar.md5 && md5sum -t AP_vbmeta_stock.tar >> AP_vbmeta_stock.tar.md5
samloader flash --AP AP_vbmeta_stock.tar.md5
```
