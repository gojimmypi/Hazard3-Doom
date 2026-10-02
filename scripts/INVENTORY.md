# Hazard3-Doom Inventory

This manifest identifies every Git-tracked file under `scripts/`,
except the generated `INVENTORY.*` manifest files themselves.
Ignored and untracked local files are intentionally not inventoried.

It is intended to support integrity verification, reproducibility, release
auditing, and exact identification of tracked artifacts. A hash identifies
the bytes in a file; it does not by itself establish provenance or intent.

Project version: v0.2.0

Git source: current index (`git ls-files --cached`)

Files inventoried: 80

Total bytes: 692145

## Verification

```bash
(cd scripts && sha256sum -c INVENTORY.sha256)
```

The `component` column is an identification aid. Any entry marked `REVIEW`
should be identified before a public release.

| Path | Bytes | SHA-256 | Component | Kind |
|---|---:|---|---|---|
| `README.md` | 23336 | `141a5bf9189bedec3cc044004a96f5ead0514bf006471d32478e82732aca9a4c` | REVIEW | Markdown documentation |
| `apply-doom-noncombat.py` | 6775 | `3a8062684727b572d903c3a53ef729d64438b6f3c2bdfdd5c426bfe5bec08658` | REVIEW | File |
| `build-coremark.sh` | 7696 | `bf3456ab3951439cde96e6301f961526893f80e51e02ca5d19f0de933008e2f6` | REVIEW | Shell script |
| `build-doom-noncombat.sh` | 5708 | `1a904b485825762b1502ede99245f64db1121e3d8a3d2fee944fad9a08218b23` | REVIEW | Shell script |
| `build-ecp5-bitstream-common.sh` | 27214 | `6f59d138fd59ac1fe6cb21267847d5eb0bce98b79a10f6c892f23059aa467d10` | REVIEW | Shell script |
| `build-supercon10-wad.py` | 6988 | `9d69e095203df153dad20f839f8ce049ef62b4433521f4c1804938043c751da6` | REVIEW | File |
| `build-ulx3s-12f-bitstream.sh` | 1611 | `c3ca7d2f9538a5f3daf10f7e8ad67a3d5c3032e5922ad95876b9522edf2d5bdd` | REVIEW | Shell script |
| `build-ulx3s-12f-doom.sh` | 10967 | `4d571997082c8d249c1861db46b547aa3352f0129a9a0a5fd8de979d84f48ddd` | REVIEW | Shell script |
| `build-ulx3s-12f-sweep_summary.md` | 7158 | `40260f011c5421d2e8c2b345416ba16495c193993ee9fdd36323bd029f6b83c6` | REVIEW | Markdown documentation |
| `build-ulx3s-85f-bitstream.sh` | 1538 | `9b5586386fa461ed236a18e6ebee549d91b70bc44fdcdac8176eec655cc21a5c` | REVIEW | Shell script |
| `build-ulx3s-85f-doom.sh` | 8948 | `8b118d0dde9bdc5eb91e1b9199a47fd40df89211e61805e39b3ba8940a51c01f` | REVIEW | Shell script |
| `build-ulx3s-85f-sweep_summary.md` | 6794 | `2cfdbef52e72ccfc15efffe07105c067fd1ab32a54c3382094c5f9a3d31e4eb2` | REVIEW | Markdown documentation |
| `build-ulx4m-ld-bitstream.sh` | 1544 | `79f607d5031939d1bc08374ce26b7cc5d14aba6eac19459e76bbd622a5a03305` | REVIEW | Shell script |
| `build-ulx4m-ld-doom.sh` | 9172 | `7b0e548a1e337b0c3b58422df593d246a17d5321dcf7c5a355f2cb8886ae1001` | REVIEW | Shell script |
| `build-ulx4m-ld-sweep_summary.md` | 8517 | `f92171f9f40d55d815d39a85336320089a93bd6b8f1ef1a4aab620a220d68ac2` | REVIEW | Markdown documentation |
| `build-xpack.cmd` | 9704 | `8672fbf2aab466a9478fdc2cc93f01604659d1ad302243d82307204db43a66b3` | REVIEW | File |
| `build.sh` | 6049 | `6bbc54624d33449aa073227dcf7599f544b8ee307b7ef9d8961f1fcea6dbcff1` | REVIEW | Shell script |
| `check-executable.sh` | 3297 | `1317c862f081f22633d205ba10f3249e15810e3489c6948a8bb8761ca9ffae8b` | REVIEW | Shell script |
| `check-nettype.sh` | 4540 | `f20f1011753d02d0c618baab5998c4ae6c4403cc7b2df46177ff6c5584468ef2` | REVIEW | Shell script |
| `check-system-requirements.sh` | 6780 | `5152c41106826bff882b4e1d34e3787499eb507531cfda602559004ff0016705` | REVIEW | Shell script |
| `check-windows-visualgdb.ps1` | 8640 | `ff4326dbf7d9e4399b46dd8e981476a3ed3e6ce489eadeb239ae77c0f2b93d28` | REVIEW | File |
| `check-wsl-visualgdb.ps1` | 8483 | `45c44a693c87952b3a1cc2859804eb08b74ee6b34ded685c99f0aedaee062a1b` | REVIEW | File |
| `check_submodules.bat` | 10617 | `8f05a6d9f9738ddea8ebc84f4b4cdef7df848824a0b5d971e0a9a5f4675cc98b` | REVIEW | File |
| `dev-prompt.cmd` | 3879 | `7ada5dc43ae6d7dac5b06878867d09c60e08d0406bdef9c45b938c97333220e7` | REVIEW | File |
| `doomgeneric-version.sh` | 1591 | `e461166288862ba39a5d5bbd4237b696ccb11153038ba3011665ad636c917971` | REVIEW | Shell script |
| `flash-ulx3s-persistent.sh` | 1812 | `ca065c362fb91afc4c981810c3d06d83c90cc8b899216d2988560961e824bf20` | REVIEW | Shell script |
| `full-clean.sh` | 6201 | `2e167df0d07e94a30dbb12b489ed27154f17f6117e67352ff62b18559c9fef8e` | REVIEW | Shell script |
| `full-install.sh` | 16370 | `4068d6544094439e6e5724768dedbc5addaeaf355ba1071887bc3cf78662622f` | REVIEW | Shell script |
| `gdb/load-ulx3s-12f-monitor.gdb` | 1166 | `3688da0d54a699aada2fd37ace0d6480232d7c1adec7d26e841847c88b9a6d3a` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/load-ulx3s-85f-monitor.gdb` | 1086 | `dc1647c8a34c072b6d0367ae13ae7ca3acdf9d4e14bfaffa2326f42a697bd249` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/load-ulx4m-ld-85f-monitor.gdb` | 1238 | `670bea99fe8f94ec55d669ff1580b3c3d84f3abd607d92aa4fb842d162f27f73` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-probe.gdb` | 2086 | `4133bf62ae717eb5d49c7dccf283a90d0fa5267d9262aefdbcb150aa10be4eac` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-scan.gdb` | 2288 | `fc220edfff82d934267000aa4ead2fb7df72a6b4044c48c5010d8be5826dc6aa` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-touchwheel-led-off.gdb` | 1506 | `cc4b5f9124b2c935f35a1bfc72c393c00fad7110055150e3447bd9404b651a4a` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-touchwheel-test.gdb` | 4547 | `13097de76e5acccbab3439a62ab2cd808d9b6b4b01b7288b2f8eb3db0ac07ff4` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `generate-ecp5-seed-matrix.py` | 2032 | `99bbc34c941180bff96a88a332ab8739a54d3984e424c54b3d29e43febd3a9e3` | REVIEW | File |
| `generate-sbom.py` | 36154 | `1f8e03201d140814e0245ecc9bd12cc3f9f9d5e0e9e696de6720e724c60368db` | REVIEW | File |
| `git-exe.sh` | 2054 | `5b8657761147e4bc8ba3b0d736f642576fb9dc1e0e8b6bac82089ebac7ce8611` | REVIEW | Shell script |
| `hazard3-debug.gdb` | 1181 | `38a49cf5e41db070c8c21402e7b797c0d0e56f7d50d15de0dfdfbef39a4ac4a3` | REVIEW | File |
| `hazard3-doom-source-status.sh` | 22308 | `c6703e4db0945c13f3d9aa8846ec710c25787608cd6f5610e617a070404daef7` | REVIEW | Shell script |
| `hazard3-submodule.sh` | 8734 | `c090ec89d12d69360dd26592c6baf913279a15718c852747254f3dae0eb0d3bd` | REVIEW | Shell script |
| `install-cmake.sh` | 1607 | `7105517e156b7338d3e6a7a930866794084e18e67d706ab11c2731da63ba34f0` | REVIEW | Shell script |
| `install-nextpnr-ecp5.sh` | 12534 | `d81421e2da0b082e277bc1bb5241dacf13fb6148e9511810681c412f803d8d32` | REVIEW | Shell script |
| `install-oss-cad-suite.sh` | 8211 | `4d19a2992c4a23eee95f9c0dfa920de28770804497226b035b8db741d0b98698` | REVIEW | Shell script |
| `install-riscv-toolchain.sh` | 7289 | `23aa7c22b9298fd52ad9db6c7697bf73adfb56aa1a7cefc71c7c3b4f36ea90ec` | REVIEW | Shell script |
| `install-yosys.sh` | 8816 | `f7fd39609e7f597f7a2e13cd36b440719fb9204994b4798a4d84a8def6799aa5` | REVIEW | Shell script |
| `inventory.sh` | 18753 | `e9aebd39fbce7b9072abd6d6c7bb3f41f0e24e5b5b0585709e2bf5077536e66b` | Hazard3-Doom repository | Shell script |
| `load-firmware-12f.sh` | 5005 | `cb8b0ec2524e760b63656af0cd894459ec5015b37f14d88f4eba4283da87cc66` | REVIEW | Shell script |
| `load-firmware-direct-verify.py` | 6691 | `3092a9b9a8447ba83ea325863e1d6b8ac4583b7580aef24465de1934d0af48f5` | REVIEW | File |
| `load-firmware.bat` | 3233 | `3a8f6a2cb06ae93ae85db245320b9834547d96dc33c3967fe4106e0d524e5de5` | REVIEW | File |
| `load-firmware.sh` | 6463 | `ca9f902c8dce1e20d089a66b4328e0c10d0446d0c9d137a12310fcc701cbfefb` | REVIEW | Shell script |
| `load-fpga-bitstream.bat` | 2682 | `b353e67ed74dcaf90b2edb349ab58dfcb5e9ee484b28f3ca031c8cf5599ed957` | REVIEW | File |
| `make-boot-hex.py` | 2775 | `1f0eb80ad684ed1303fca182eec9b0160c8e20cd165dc8cf710a5c38ec2696f2` | REVIEW | File |
| `peek-elf.sh` | 25041 | `d6893ccbb714025037dd4f416f455e9d49cd94d8732b6fec6eb82736b6223113` | REVIEW | Shell script |
| `publish-check.sh` | 3069 | `917f7ad508e708a54a886b7599f26d54436d20501194de122f4e235090876178` | REVIEW | Shell script |
| `refresh-version.sh` | 4480 | `18418ed6f45af6bef901313e6a2dfbc51c8b6ff59a1038d4a9a793ece455e875` | REVIEW | Shell script |
| `requirements-check.sh` | 37947 | `2668d0746edabf7a3c0f22d6f27b150554cd43f62aa2b33e9d98d489e37dae03` | REVIEW | Shell script |
| `restart-from-monitor.py` | 2180 | `62fafcba0da53b21b5704f221c655c63eb5520f2def0fbe7312005a65c59dd2d` | REVIEW | File |
| `return-to-monitor.py` | 2144 | `0214047d05bf37b06453388892bc8c5a13a49af1154f962e1680eaa644316ceb` | REVIEW | File |
| `riscv-doom-runtime.sh` | 9656 | `d4cd4f8b28e07bc93e6225772831906e2745e7017361cffd942a8a6382cdd961` | REVIEW | Shell script |
| `run-coremark.sh` | 5353 | `beeafffbc6ae911170dfcf44a5bc12796da180780ae1cb9b37e283017ac3d366` | REVIEW | Shell script |
| `setup-doomgeneric.sh` | 3963 | `1006e21f497f6553eb8bf30009cf0c75b57dd54f4720c7b6d172a874b6236560` | REVIEW | Shell script |
| `setup-submodules.sh` | 2697 | `50ab220e349763a8af70edc8228832d2f49ce39645e61a1ac4eb69142f3b8023` | REVIEW | Shell script |
| `setup-xpack-riscv-gcc.cmd` | 4527 | `4ebeb6512881634e17c5d18e5424112f142bf651d35f07b8ed197c20f43f108e` | REVIEW | File |
| `start-openocd.bat` | 8333 | `da858356e9981d5b44447ea17b0f276bc0823848acdf20440c4a19f577b95e21` | REVIEW | File |
| `start-openocd.sh` | 10021 | `2d08c7ec39d6724f1e28976a09d9d119ad97797a426ba6cc1d85c697f2f3125a` | REVIEW | Shell script |
| `summarize-ecp5-sweep.py` | 11880 | `1c9764208c376f0795c4ec68d84d19bb16fac4a2296cf5c062d1543d740edf75` | REVIEW | File |
| `sweep-ecp5-common.sh` | 10846 | `04ff401514b143a8f8b20b07d4bef94800186dcba2c8e0fafe60e48f581163ba` | REVIEW | Shell script |
| `sweep-ecp5.sh` | 4103 | `87375460306eafc9326d71405b3fe524ccd0d34b7fcec05d934930b3339ccb53` | REVIEW | Shell script |
| `sweep-peek-ulx3s-12f-best-peek.sh` | 1898 | `fc15e3672a893cc2abe7e292956a4d84437521b286d83224a764cdabf1e6d73e` | REVIEW | Shell script |
| `sweep-peek-ulx3s-12f.sh` | 11810 | `e58458c8205feaab3f51668207797217980ad014d77837bd78b89a15352bbc21` | REVIEW | Shell script |
| `sweep-peek.sh` | 8033 | `d892fafd87572d9c2510d62cd1f9e00fe5a9a21674c0f6cdd9f167554af87025` | REVIEW | Shell script |
| `sweep-ulx3s-12f.sh` | 14184 | `f97ae35c84dcc150f652ce9036689508ee6c1de2f8d9d82b0b2b8a8059a9c5d2` | REVIEW | Shell script |
| `sweep-ulx3s-85f.sh` | 13147 | `3d2244d6ccfaf13b2901330cd6ef5cc3b8bb842143e2541c16eb31a8f9c7e5aa` | REVIEW | Shell script |
| `sweep-ulx4m-ld.sh` | 16767 | `b6cee368fee2ba1a8f1bd4905bea0ad2c667c00f60366d5692e0ea0330ed20d6` | REVIEW | Shell script |
| `sweep.sh` | 980 | `0ea3290a5ef9f6fe7a386d46add42cf7bb0e217023beb2b79713a463aa92f9d6` | REVIEW | Shell script |
| `test-readthedocs.sh` | 11128 | `cb4c49cf3e3065fdc851d66c193b23966d615c10721cdb889e7ae4cdd0d70f4b` | REVIEW | Shell script |
| `test-scripts.sh` | 27047 | `af41d69e75ac45ff332f8171f44f5f315b86f5fcb009542803a984751081892c` | REVIEW | Shell script |
| `ulx4m-bootloader.sh` | 30139 | `70842c33881cf42c62d4a290084effed82128d686c71ae957f56347a5e92a8f1` | REVIEW | Shell script |
| `watch-ecp5-sweep-results.sh` | 18404 | `112a79ced79b6f66daf1673274482298a2b283f5eb77dd0dd6309eec93b89754` | REVIEW | Shell script |
