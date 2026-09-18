# Hazard3-Doom Inventory

This manifest identifies every Git-tracked file under `scripts/`,
except the generated `INVENTORY.*` manifest files themselves.
Ignored and untracked local files are intentionally not inventoried.

It is intended to support integrity verification, reproducibility, release
auditing, and exact identification of tracked artifacts. A hash identifies
the bytes in a file; it does not by itself establish provenance or intent.

Project version: v0.2.0

Git source: current index (`git ls-files --cached`)

Files inventoried: 77

Total bytes: 592030

## Verification

```bash
(cd scripts && sha256sum -c INVENTORY.sha256)
```

The `component` column is an identification aid. Any entry marked `REVIEW`
should be identified before a public release.

| Path | Bytes | SHA-256 | Component | Kind |
|---|---:|---|---|---|
| `README.md` | 20758 | `eee20c501db0cdf415f555a8bb53a92c9289a06d1123cd4264d0d426a111beea` | REVIEW | Markdown documentation |
| `apply-doom-noncombat.py` | 6775 | `3a8062684727b572d903c3a53ef729d64438b6f3c2bdfdd5c426bfe5bec08658` | REVIEW | File |
| `build-coremark.sh` | 7033 | `0845978f2cf4dc4f497a20930f206b68b2a0d727110843e300ca3e04da85cce4` | REVIEW | Shell script |
| `build-doom-noncombat.sh` | 4654 | `19ba9e651097c9d0b2b947266f58124322fc085b75784cf6c186f130296a53a7` | REVIEW | Shell script |
| `build-ecp5-bitstream-common.sh` | 26997 | `e7c3d914421e84bd59ec455ea212156bc1e3d7ae1bf98a5de91f862840b1ae4f` | REVIEW | Shell script |
| `build-supercon10-wad.py` | 6988 | `9d69e095203df153dad20f839f8ce049ef62b4433521f4c1804938043c751da6` | REVIEW | File |
| `build-ulx3s-12f-bitstream.sh` | 1406 | `973f5543461e945f3b2676727bd7b86a3d2eddc76d959e3b72a66e4ae26425a1` | REVIEW | Shell script |
| `build-ulx3s-12f-doom.sh` | 5417 | `318dc3aa6949dbc8d480a6e0876601ba796cb18899e9efbfee6f3c97df6d545a` | REVIEW | Shell script |
| `build-ulx3s-12f-sweep_summary.md` | 7158 | `40260f011c5421d2e8c2b345416ba16495c193993ee9fdd36323bd029f6b83c6` | REVIEW | Markdown documentation |
| `build-ulx3s-85f-bitstream.sh` | 1333 | `01edce7bd19ecb5bbbe1a620f7f2f1c2900898a6a197720859c1612e7e787c35` | REVIEW | Shell script |
| `build-ulx3s-85f-sweep_summary.md` | 6794 | `2cfdbef52e72ccfc15efffe07105c067fd1ab32a54c3382094c5f9a3d31e4eb2` | REVIEW | Markdown documentation |
| `build-ulx3s-doom.sh` | 5549 | `590758dd9c913838d1e5276646c31f72809c7f6fa5e96623a295521053b18710` | REVIEW | Shell script |
| `build-ulx4m-ld-bitstream.sh` | 1339 | `61e431dee6e42b9d2b53f8dfdc77330d0f8040057625ab6cb89a65f9b3d3ebaf` | REVIEW | Shell script |
| `build-ulx4m-ld-doom.sh` | 5951 | `83a68471c6aa9faf0e05e671678938600bfd10b3041bad4ff572961a25adc957` | REVIEW | Shell script |
| `build-ulx4m-ld-sweep_summary.md` | 8517 | `f92171f9f40d55d815d39a85336320089a93bd6b8f1ef1a4aab620a220d68ac2` | REVIEW | Markdown documentation |
| `build-xpack.cmd` | 9704 | `8672fbf2aab466a9478fdc2cc93f01604659d1ad302243d82307204db43a66b3` | REVIEW | File |
| `build.sh` | 5386 | `460b1c95ff1cccac75a258da2618b91816930487c6fef1bbd7c2b79ecd808cf3` | REVIEW | Shell script |
| `check-executable.sh` | 2649 | `911d291ea02cb0f3b0e1bdd999cfc70b57ef3753448f1fa5a5525d6921a4c5e5` | REVIEW | Shell script |
| `check-nettype.sh` | 4335 | `d03f4bc32c3cce2f421eef456ddd3929ef0f9dc1e959dcbbc39f35c1232332f9` | REVIEW | Shell script |
| `check-system-requirements.sh` | 5897 | `3091a8eea35c51600ba7e7ed8323f0d7d8e8ece9fe582a0ba613dad9cd80c786` | REVIEW | Shell script |
| `check-windows-visualgdb.ps1` | 8640 | `ff4326dbf7d9e4399b46dd8e981476a3ed3e6ce489eadeb239ae77c0f2b93d28` | REVIEW | File |
| `check-wsl-visualgdb.ps1` | 8483 | `45c44a693c87952b3a1cc2859804eb08b74ee6b34ded685c99f0aedaee062a1b` | REVIEW | File |
| `check_submodules.bat` | 10617 | `8f05a6d9f9738ddea8ebc84f4b4cdef7df848824a0b5d971e0a9a5f4675cc98b` | REVIEW | File |
| `dev-prompt.cmd` | 3871 | `45a646a44eb35c235be9d5062ad063542eddf1a5774cd198a5320e038bf4ba21` | REVIEW | File |
| `doomgeneric-version.sh` | 1386 | `5a6cf61c5c1fd11237763279ed0a1d39d2dce37f3720c752e4e0114cae71ef81` | REVIEW | Shell script |
| `flash-ulx3s-persistent.sh` | 1599 | `55dbb3ef4ee9d6315b5f622e4e0141e20bb165a631d0b85badb38e62f2b478fd` | REVIEW | Shell script |
| `full-clean.sh` | 5814 | `1d2732bee827bf875b529ddb05dd1874438c76ec95b90958302fb705b06e49be` | REVIEW | Shell script |
| `full-install.sh` | 7574 | `5fff0ac5a350417be7b1ffdea6c0c70603f4a50df8dd224398ee3722a6246232` | REVIEW | Shell script |
| `gdb/load-ulx3s-12f-monitor.gdb` | 1166 | `3688da0d54a699aada2fd37ace0d6480232d7c1adec7d26e841847c88b9a6d3a` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/load-ulx3s-85f-monitor.gdb` | 1078 | `301b42bf76d2745b87d1516add0b1a411c9e61797694e69e5766ccb025920148` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/load-ulx4m-ld-85f-monitor.gdb` | 1238 | `670bea99fe8f94ec55d669ff1580b3c3d84f3abd607d92aa4fb842d162f27f73` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-probe.gdb` | 2086 | `4133bf62ae717eb5d49c7dccf283a90d0fa5267d9262aefdbcb150aa10be4eac` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-scan.gdb` | 2288 | `fc220edfff82d934267000aa4ead2fb7df72a6b4044c48c5010d8be5826dc6aa` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-touchwheel-led-off.gdb` | 1506 | `cc4b5f9124b2c935f35a1bfc72c393c00fad7110055150e3447bd9404b651a4a` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-touchwheel-test.gdb` | 4547 | `13097de76e5acccbab3439a62ab2cd808d9b6b4b01b7288b2f8eb3db0ac07ff4` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `generate-ecp5-seed-matrix.py` | 2032 | `99bbc34c941180bff96a88a332ab8739a54d3984e424c54b3d29e43febd3a9e3` | REVIEW | File |
| `generate-sbom.py` | 36154 | `1f8e03201d140814e0245ecc9bd12cc3f9f9d5e0e9e696de6720e724c60368db` | REVIEW | File |
| `git-exe.sh` | 1849 | `fd3a9ebccf709c8a45817d9ec67738b765d7074454309db41834af4a13dced66` | REVIEW | Shell script |
| `hazard3-debug.gdb` | 1181 | `38a49cf5e41db070c8c21402e7b797c0d0e56f7d50d15de0dfdfbef39a4ac4a3` | REVIEW | File |
| `hazard3-doom-source-status.sh` | 22103 | `0d9e973fbdf8e911030b72378572ad45506b50b7e5ffc6b6712eb03b90ba5614` | REVIEW | Shell script |
| `hazard3-submodule.sh` | 8529 | `21a5d01d95108a9d304fc9b2bf9606f18c5a76416259fa27525cb32a9ff6e45e` | REVIEW | Shell script |
| `install-cmake.sh` | 1326 | `1150e96c9fc32901301cc70fb2776aa27cc83e687ff640a981a1615221d0ecd6` | REVIEW | Shell script |
| `install-nextpnr-ecp5.sh` | 11194 | `bd2cb80531cb3a0397d8a504eb1d279b4c7ff4c0008d236a9ae34b3041678fdd` | REVIEW | Shell script |
| `install-riscv-toolchain.sh` | 3006 | `662b28c35a491bb15a47e57635f8f2eaa86582683f81f71b4c1bed84e46604bd` | REVIEW | Shell script |
| `install-yosys.sh` | 7447 | `cedafe1a7bd32849088da73fd1814a6a7673da51d054cc561b3ab2ef7cac8f30` | REVIEW | Shell script |
| `inventory.sh` | 12317 | `c70db2bc87c20011a9f7316dad3943e1d22d508ecc287537aec8e374119600cc` | Hazard3-Doom repository | Shell script |
| `load-firmware-12f.sh` | 1570 | `63b70d39f092cdb590da8f8541806f67fe99556ea7f81afd8eb87a940cd1fc82` | REVIEW | Shell script |
| `load-firmware.bat` | 2744 | `b5ef6334aeb4124bd4582d7620d5d399df896ed80b021e1c3d56b5140b8d5a2b` | REVIEW | File |
| `load-firmware.sh` | 3560 | `226c1d11fc468ab2e0bd4743072a8ca75c81ebf098ba874adeba8fe5f1828afa` | REVIEW | Shell script |
| `load-fpga-bitstream.bat` | 2712 | `b7dafb42e129ebb75787c5b4e000c178afc6a32325242791f6990bf25b5e6cf9` | REVIEW | File |
| `make-boot-hex.py` | 2794 | `bd4e1d863e021e5cb7345d5c57e0e37cf1751d3f8c333652eb52fd48d2ab05ac` | REVIEW | File |
| `peek-elf.sh` | 24394 | `9ae200bee9f45c3ceddb53543efe362f5b79997bad4b23d147d06e625be18052` | REVIEW | Shell script |
| `publish-check.sh` | 2864 | `0bbe46ddee13b48a1318fbff8500fc311b61ec964c2974fff3063d4e91229f1e` | REVIEW | Shell script |
| `refresh-version.sh` | 4275 | `b90ebfc5f4954a88109370935c9233e59ef27bcf3bf4c6a239fab30434e109f4` | REVIEW | Shell script |
| `requirements-check.sh` | 34394 | `12ed763e288632212f52c1531759dcea2361c6d7b62ddb31cc9d57c0d525d8d7` | REVIEW | Shell script |
| `restart-from-monitor.py` | 2180 | `62fafcba0da53b21b5704f221c655c63eb5520f2def0fbe7312005a65c59dd2d` | REVIEW | File |
| `return-to-monitor.py` | 2144 | `0214047d05bf37b06453388892bc8c5a13a49af1154f962e1680eaa644316ceb` | REVIEW | File |
| `run-coremark.sh` | 5148 | `ee257f329b138a6bfcc01224c96c8f4459b171f493f437f423190cb1d811a336` | REVIEW | Shell script |
| `setup-doomgeneric.sh` | 3758 | `c5e0db035fd7c7ca27f2a742c61e40cd76b667735d03fb70165d462e9417a53a` | REVIEW | Shell script |
| `setup-submodules.sh` | 2492 | `50acdd84c3befd4ae3820d8f871edd2ba600975d31191cd1460b83e7095919f4` | REVIEW | Shell script |
| `setup-xpack-riscv-gcc.cmd` | 4527 | `4ebeb6512881634e17c5d18e5424112f142bf651d35f07b8ed197c20f43f108e` | REVIEW | File |
| `start-openocd.bat` | 1772 | `fa12c169fcbec5b1c33c98195aa97263ecd35ebf3d382380ef6b66b80cc53895` | REVIEW | File |
| `start-openocd.sh` | 5444 | `a5a9e1e771b7b3d8e5e0a8062d5b09e8a0fe067faa12f72d3ccc1b058bcf3c0f` | REVIEW | Shell script |
| `summarize-ecp5-sweep.py` | 11880 | `1c9764208c376f0795c4ec68d84d19bb16fac4a2296cf5c062d1543d740edf75` | REVIEW | File |
| `sweep-ecp5-common.sh` | 10641 | `8fcb40ac93677d355233982c20f88273b7cda9ff8349a1a5fd866daf6314fdc1` | REVIEW | Shell script |
| `sweep-ecp5.sh` | 3894 | `063ea19a6218833320be8f3f1e6dc0cb2a0c885fc0326f8a54e0d981c0009205` | REVIEW | Shell script |
| `sweep-peek-ulx3s-12f-best-peek.sh` | 1693 | `d64946c8f5aa8f9c4947007c13ba5ff7ed49d3d15db896ede13ea263fbe2c81b` | REVIEW | Shell script |
| `sweep-peek-ulx3s-12f.sh` | 11605 | `88f043454b509fcf100fb917e743d59bac2f0939fb77d1ac418349f1e637770e` | REVIEW | Shell script |
| `sweep-peek.sh` | 7796 | `d1fdff21aa65330d2704b2733b9876a136f32ab33c07953e8d1da59258d0db77` | REVIEW | Shell script |
| `sweep-ulx3s-12f.sh` | 13979 | `27030de91b8dd4ae514c6fc1b784862bf382144e1ab2ab6d4aecd4cd4181e2e3` | REVIEW | Shell script |
| `sweep-ulx3s-85f.sh` | 13111 | `9d37223b804741c6b6e4abc992c26df60c089fb39c07072dbfcc4207e4156e68` | REVIEW | Shell script |
| `sweep-ulx4m-ld.sh` | 16562 | `a1dccb5925b207479f06cc9fa2bd43c29d2a0ca03f4cfe45d758203014b194bf` | REVIEW | Shell script |
| `sweep.sh` | 775 | `73dfc7d13c2d77e1ccc5e6ce72856621c639e27c01d88e13bfc4225dcb1f3895` | REVIEW | Shell script |
| `test-readthedocs.sh` | 10923 | `9438b1c09e34df5130f19e1d9dfd2f589fb47001a3d7126266530f2a86e0f9f7` | REVIEW | Shell script |
| `test-scripts.sh` | 20595 | `9c06b2951f99d4df69d86ca45fd89c6a36732f5150fe7e5a80772146c044b975` | REVIEW | Shell script |
| `ulx4m-bootloader.sh` | 29934 | `414abaebdfe5c9c74756c24f3c6a4a896006092ebc0ce2306ecdb44768e1b889` | REVIEW | Shell script |
| `watch-ecp5-sweep-results.sh` | 18199 | `4d7b1bd134af275ad36d608811c64b9b2bf4ee201ee419d677bdf0b8b886536d` | REVIEW | Shell script |
