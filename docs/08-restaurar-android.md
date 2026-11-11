# 8. Voltar ao Android original

Firmware oficial baixado no cap. 1 (`BL_`, `AP_`, `CP_`, `CSC_`). No Download Mode:

```bash
samloader verify-md5 BL_*.tar.md5 AP_*.tar.md5 CP_*.tar.md5 CSC_*.tar.md5
samloader flash --BL BL_*.tar.md5 --AP AP_*.tar.md5 --CP CP_*.tar.md5 --CSC CSC_*.tar.md5
```

- `CSC_` apaga os dados; `HOME_CSC_` mantém (aqui os dados são do Droidian, use `CSC_`).
- Use **o mesmo firmware que estava no aparelho** (aqui `M625FXXS7CXK2`) para não ter problema de binário/rollback.
- A EFS não é tocada; o backup do cap. 1 é para o caso de corrupção.

## Alternativa: LineageOS

Com a Lineage Recovery ainda instalada: *Factory reset → Format data*, *Apply update → Apply from ADB* e
`adb sideload lineage-23.2-…-f62-signed.zip`. Isso também regrava boot, dtbo, vbmeta e o vendor da LineageOS.
