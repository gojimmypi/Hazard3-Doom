# Hazard3-Doom Inventory

This manifest identifies every Git-tracked file under `bootloader-serv/tests/`,
except the generated `INVENTORY.*` manifest files themselves.
Ignored and untracked local files are intentionally not inventoried.

It is intended to support integrity verification, reproducibility, release
auditing, and exact identification of tracked artifacts. A hash identifies
the bytes in a file; it does not by itself establish provenance or intent.

Project version: v0.2.1

Git source: current index (`git ls-files --cached`)

Files inventoried: 20

Total bytes: 143928

## Verification

```bash
(cd bootloader-serv/tests && sha256sum -c INVENTORY.sha256)
```

The `component` column is an identification aid. Any entry marked `REVIEW`
should be identified before a public release.

| Path | Bytes | SHA-256 | Component | Kind |
|---|---:|---|---|---|
| `bootstrap-ulx5m-cfg-cmd.py` | 2006 | `7ae69665ed6fb48ef1e9e940cf4caf3d08137de32f216f16f415dd730bad58da` | REVIEW | File |
| `cfgcmd_codec.py` | 3969 | `26c9b4f4eade2ca8cc84de2291b92b3a3a79dccd630a89c549260907c30fac9f` | REVIEW | File |
| `derive-ulx5m-cfg-cmd.py` | 2259 | `a0a6cf084a6bd2f9916822554ea42e47fbb7b374d0d5fed121a3be7688cb41a5` | REVIEW | File |
| `qualify-ulx5m-bootloader.py` | 4960 | `86e58536e5d594fc7fb01ee20b4fe9235b7c2ec4187de244acbe0ea329af0a3d` | REVIEW | File |
| `tb_ulx5m_btn2_boot_select.v` | 2110 | `df87d910d7da6b7e3b3289e325d57efc2c4520d6f0274e21cc74cb5060ae59c8` | REVIEW | File |
| `tb_ulx5m_cfg_autoboot_25.v` | 3069 | `e8cff18f9fb80b54aca466337961d90f7aaa364b88809f68eb6a93b07aa83e41` | REVIEW | File |
| `tb_ulx5m_gs_secondary.v` | 791 | `568f4a04808fcdc6a52ac9f53a132dd2810984f7da0e6e952f8f738f54bcdd38` | REVIEW | File |
| `tb_ulx5m_normal_boot_reset.v` | 1779 | `8dfd1c56369638c2ca3d0252460ae1ce9a0dd8335b7f3352e1d0b3d7e3d746e3` | REVIEW | File |
| `test-ulx5m-recover-secondary.py` | 683 | `4879c244f495e87a8bbee1bcc48a3ba70efaab04f59bc6a479d0fa23c5bfbc5f` | REVIEW | File |
| `test-ulx5m-serv-at25ql321-chain.c` | 20317 | `4680001fcd63d7315560a12819e23e5dd78e1b23b89cec463a5666cad64ee2e3` | REVIEW | File |
| `test-ulx5m-serv-at25ql321-protected.c` | 1062 | `929ce293f3db9e0e9a2cf9d68f2d11ef4dea15f955c3745570b5e12f432ba918` | REVIEW | File |
| `test-ulx5m-serv-at25ql321.c` | 3562 | `b4019f4ac6d43b63c19980da2ed15c6259614602f161094b4bfec5627914408b` | REVIEW | File |
| `test-ulx5m-serv-flash-program-protected.c` | 1606 | `69d6dc7de59ab1690798a977aebaea51e1d97237e0015e698301f346bd2d5163` | REVIEW | File |
| `test_ulx5m_bootloader.py` | 29417 | `a67ac3d64c3f1eddeddf8560e19fd3dd6aa4d1dbe2b7cf7ad3bdcd166f1b0e70` | REVIEW | File |
| `ulx5m-at25ql321-mock.c` | 4185 | `30ada14a13d6f1306558a729c14bab54e39f7b7628abf6a118f92925937284ae` | REVIEW | File |
| `ulx5m-at25ql321-mock.h` | 799 | `696efd553b06cd9f6188b7d0d37b86850d788e78657a9ffdde6cfa0205f50aeb` | REVIEW | File |
| `ulx5m_acceptance.py` | 23981 | `adbee81221988cf41c9fba6ecebcee9602d78864a2802718965dd9194125449e` | REVIEW | File |
| `ulx5m_bootloader.py` | 12975 | `40a2ff36a9d47ef185160f7f7957f234e0791b68074bf79cc9755964954d2596` | REVIEW | File |
| `ulx5m_dfu_update.py` | 9552 | `24aa5a467dc0384a748987c8ce0ffd46370364ceafcc47da764132c450f473f8` | REVIEW | File |
| `ulx5m_flash_install.py` | 14846 | `04327b12367a075e547573aa111a501036de05f532acca2e89ff60dae6075ca9` | REVIEW | File |
