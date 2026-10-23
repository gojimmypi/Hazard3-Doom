# Hazard3-Doom Inventory

This manifest identifies every Git-tracked file under `bootloader-serv/scripts/`,
except the generated `INVENTORY.*` manifest files themselves.
Ignored and untracked local files are intentionally not inventoried.

It is intended to support integrity verification, reproducibility, release
auditing, and exact identification of tracked artifacts. A hash identifies
the bytes in a file; it does not by itself establish provenance or intent.

Project version: v0.2.1

Git source: current index (`git ls-files --cached`)

Files inventoried: 9

Total bytes: 42647

## Verification

```bash
(cd bootloader-serv/scripts && sha256sum -c INVENTORY.sha256)
```

The `component` column is an identification aid. Any entry marked `REVIEW`
should be identified before a public release.

| Path | Bytes | SHA-256 | Component | Kind |
|---|---:|---|---|---|
| `compare-ulx5m-btn2-netlists.py` | 8003 | `010326df0b50eaca84f7d1172982d83faf253946496829159a57ff59b3eb8dc9` | REVIEW | File |
| `package.sh` | 492 | `134a0592d281c45bb151305cc949a1300067e3caf95696c8f835c77ed4e07f6e` | REVIEW | Shell script |
| `preserve-ulx5m-btn2-candidate.sh` | 5443 | `334eb15755dc8acb76661f18bf36fd858ed7f085b68913133802ab2333aa03a3` | REVIEW | Shell script |
| `rebuild-ulx5m-btn2-dfu-baseline.sh` | 5740 | `19622073639160754896f95950ff1202c8d9e76e75fe4772c811305cad71b7ff` | REVIEW | Shell script |
| `report-ulx5m-btn2-sweeps.sh` | 2293 | `f75099c1da71f9e281f8cd324eb62640b71ac4db2e9ab4987ab407a9bed2d209` | REVIEW | Shell script |
| `sweep-ulx5m-btn2-dfu-quad-asyncreset-serv.sh` | 5522 | `dfdce98c9df03a5e87400fc6c8fc7b1684d5f4aac5ab23dd75ef14afaa71bd08` | REVIEW | Shell script |
| `sweep-ulx5m-btn2-dfu-quad-regreset-serv.sh` | 5504 | `fc97e4e090f1674c872b480d9fbaef54c3e764c96871076e23b93026b3816a86` | REVIEW | Shell script |
| `sweep-ulx5m-btn2-dfu-quad-serv.sh` | 5437 | `ddccd87c166d82c58e9cba5d4a1a5ee7b28214d1c3f150a9c86109411b3f5ca0` | REVIEW | Shell script |
| `sweep-ulx5m-serv.sh` | 4213 | `9d19a1eae0175b2876a157db768c94fe2b9f04f5e24fb0cca40d38698a0066d1` | REVIEW | Shell script |
