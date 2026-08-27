# Hazard3-Doom Inventory

This manifest identifies every Git-tracked file under `scripts/`,
except the generated `INVENTORY.*` manifest files themselves.
Ignored and untracked local files are intentionally not inventoried.

It is intended to support integrity verification, reproducibility, release
auditing, and exact identification of tracked artifacts. A hash identifies
the bytes in a file; it does not by itself establish provenance or intent.

Git source: current index (`git ls-files --cached`)

Files inventoried: 52

Total bytes: 253497

## Verification

```bash
(cd scripts && sha256sum -c INVENTORY.sha256)
```

The `component` column is an identification aid. Any entry marked `REVIEW`
should be identified before a public release.

| Path | Bytes | SHA-256 | Component | Kind |
|---|---:|---|---|---|
| `README.md` | 13905 | `a44ce6f3830c2c21ba2281f8baf9031cb63491d1c759edf11dbfc14e693d6f1e` | REVIEW | Markdown documentation |
| `apply-doom-noncombat.py` | 6057 | `93001efa46ed2df74634c6bbb76119a1fcbe1bff93dd48ce611f699e7075b460` | REVIEW | File |
| `build-coremark.sh` | 6171 | `95a454f34d447eb4d9f41ea5e387facbca47414a74ec81a9f2bd5a9fe0d34ccb` | REVIEW | Shell script |
| `build-doom-noncombat.sh` | 2973 | `cd0b6151525408307004004cee09d41097956dcc70b9f80de7aeb70763931dec` | REVIEW | Shell script |
| `build-ecp5-bitstream-common.sh` | 17093 | `35f5f8e9046d74f9a8e6e0ad5eedf90e06f52c37d804a287732fc3411c616856` | REVIEW | Shell script |
| `build-supercon10-wad.py` | 6291 | `a00aa8684ba11c76860d8f236e8edf67c13819196c8c1b1c6a3bd55f262bfb68` | REVIEW | File |
| `build-ulx3s-12f-bitstream.sh` | 707 | `7b81fb614824c09277fa503e4071228701612b93964044e8790213f5bd69bb6c` | REVIEW | Shell script |
| `build-ulx3s-12f-doom.sh` | 3640 | `64336e2cca37ac193e9bd757960f4205f2bb2d2748de773680cd03bbf1690e94` | REVIEW | Shell script |
| `build-ulx3s-85f-bitstream.sh` | 633 | `199c2454083736cbf40fe86ce81a6d12d24b248133dd0628bf2832e7db08aaf5` | REVIEW | Shell script |
| `build-ulx3s-doom.sh` | 4419 | `b962d362f1ac7b142ca73fca3e7cd89787bf6876b2dd5889d44459fc0b7cba81` | REVIEW | Shell script |
| `build-ulx4m-ld-bitstream.sh` | 638 | `5e49066502e2220edb7c027f285118422c1ca5ff2dcd95d3eff51002bd6c5c66` | REVIEW | Shell script |
| `build-ulx4m-ld-doom.sh` | 3723 | `ac1ee46753a17991d300d352c82de446d371b55ae93fd02aefacf13c99c4d87e` | REVIEW | Shell script |
| `build-xpack.cmd` | 7822 | `2647bfa096a2215027ab82a850a027b891a5976b98eb1b4fdffd252812e37e16` | REVIEW | File |
| `build.sh` | 3897 | `7dd3c7fd604b1b90c09981940b3d595354944a7a38b12f3d9c8255b484e1e6df` | REVIEW | Shell script |
| `check-executable.sh` | 1779 | `6d6a9d586c3ec823dc338dfea275578f2d20c51154354460702ae58faf735c47` | REVIEW | Shell script |
| `check-nettype.sh` | 3458 | `acb786bde7432f4e7e5abd7f6f3a310e2285ba102cd8483a808eb50f43306f7d` | REVIEW | Shell script |
| `check-windows-visualgdb.ps1` | 7924 | `8fc10e1c4a57cd1d94994f98e0b614d6f77f5531780ca6e8eee0a969be56fe06` | REVIEW | File |
| `check-wsl-visualgdb.ps1` | 7766 | `150eaf3accccdcc72cdc894a9f300af4b21b0c4a199e8608138375d222ca64e2` | REVIEW | File |
| `check_submodules.bat` | 9863 | `48c1f8086f6c5f52db9c0c59b3d8954aaebbfc669a28df8586292cb3656367bb` | REVIEW | File |
| `doomgeneric-version.sh` | 686 | `daebcc02d2f76f7e7950b759a75972ee9ae0b4a614ced798de8df5d17c220c37` | REVIEW | Shell script |
| `flash-ulx3s-persistent.sh` | 890 | `73583b480788e9ae086596f34c7edf2a3739cf374ca8c3fbf7a0fbd20b27b1ef` | REVIEW | Shell script |
| `full-clean.sh` | 2996 | `577393606b32401e0515e9d4af7e51cae6b10aca81b28940b074ef3f7fa35ccc` | REVIEW | Shell script |
| `gdb/load-hazard3-test-elf.gdb` | 111 | `6427733c16353906f606306f483d3ce9f2f1ad11d29fbb4f3a3fc7de26afbba9` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-probe.gdb` | 1395 | `3b9203f6b8a272b311819998287ed0309bd350b21171370499e649e078bf75fe` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-scan.gdb` | 1592 | `e9f2efd38cb04eb78a0d6876e03a35279b394990619d17539a362db5e4ff8143` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-touchwheel-led-off.gdb` | 791 | `bb2d06662043ab90b6b0ec53f2017e9a98412848fc8a36a88e23329a7787b211` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `gdb/sao-touchwheel-test.gdb` | 3819 | `17356a48e0d17aabc366624d408b81702630497e3d0e434afeab7ee83badd59d` | xPack GNU RISC-V Embedded GCC/GDB runtime | File |
| `git-exe.sh` | 1173 | `e5a4b70411e7799f070ab7ba68d4553cf321925cd537d9e11acaec0765bea670` | REVIEW | Shell script |
| `hazard3-debug.gdb` | 488 | `1870db3adc99a2870c03a1ca7eae33c7bc39e7a5459db94faa55ecbd58138254` | REVIEW | File |
| `hazard3-doom-source-status.sh` | 14317 | `d96e167647c5779e56ace2c81869d651f19419828e1c3c0c819a9fc29b72d49a` | REVIEW | Shell script |
| `hazard3-submodule.sh` | 7821 | `f07792408a7bdcd0f2c558b0966763401b64f399b24adb168c603d537c7c3f5f` | REVIEW | Shell script |
| `inventory.sh` | 11092 | `d84afcf71be6e2361325185c1bad75d869d8c3e6563bcdc6a2d8896a32acf428` | Hazard3-Doom repository | Shell script |
| `load-firmware-12f.sh` | 870 | `47aa0f7ffe0cf6e4cd239b6913d271388369e0109045225a38e2f5bc48fe0e93` | REVIEW | Shell script |
| `load-firmware.bat` | 2010 | `4f0bfef43b8d131b4cc4a3b2330a9be64b05333c258ab9251e2b6b7b8e9c290d` | REVIEW | File |
| `load-firmware.sh` | 2211 | `56fae7b29afe439c3db640ace80ce647708627798ee46625c74c80d257347ebb` | REVIEW | Shell script |
| `load-fpga-bitstream.bat` | 1939 | `777309c817905b33e7ab2874eedbb4648f19d9868aef2075ff58118116d525c6` | REVIEW | File |
| `make-boot-hex.py` | 2082 | `c8c81fc333216b0f7ca70afc72a1012ebb4cce24209d42091150e8ed9b5d21b8` | REVIEW | File |
| `peek-elf.sh` | 23145 | `e598e6b0ae0c350fb15af256acf43b4d5b992e9dbad8aca18bc997888a4bdd52` | REVIEW | Shell script |
| `restart-from-monitor.py` | 1478 | `9290401eeea380203a395ff7edf25db2685e3c44d98a8ec0d830805f4a8d4a88` | REVIEW | File |
| `return-to-monitor.py` | 1445 | `5589c0b21a8f3f707d0654459d5b3b288d69b27d16fb8d2ccae94df587508104` | REVIEW | File |
| `run-coremark.sh` | 4457 | `00a02db7c4dc80c04b864227177343bf7449d44a48e52de9801735f567afd9e7` | REVIEW | Shell script |
| `setup-doomgeneric.sh` | 3052 | `ef786f80920e11516195b2deb5cebb74473c2fc838504d7e7712596141bf0c1b` | REVIEW | Shell script |
| `setup-submodules.sh` | 1790 | `adbd4058fed327e347030a008542af8c96850bc8e68ce61c2b57f7fb8d226c5b` | REVIEW | Shell script |
| `setup-xpack-riscv-gcc.cmd` | 3749 | `76b28eacc02b7606aaa0353644a8c07e4ccaf818a8499a67a1a1d34759bb6001` | REVIEW | File |
| `start-openocd.bat` | 876 | `0505d9121b31a504c7a5ceeedb4773e08efcbc4aca5d14ddc88e82033cf6012a` | REVIEW | File |
| `start-openocd.sh` | 1559 | `48d8dbe26b40045c48e9bd4671f125b4819125546aebd68b67232a239a0d20ed` | REVIEW | Shell script |
| `sweep-peek-ulx3s-12f-best-peek.sh` | 1042 | `71636156f2046208699414bff49bd2b1cad036dc7997cb19cdecb383cbffa82b` | REVIEW | Shell script |
| `sweep-peek-ulx3s-12f.sh` | 10793 | `75618df498e560c0ba303b5236c8675f5e64efb8744b19c7bfc38889103a008c` | REVIEW | Shell script |
| `sweep-peek.sh` | 6878 | `3b17cd3071cf32910998c6e9d0946f4e019e3cd6cc55a775e05866a3ac6b0d19` | REVIEW | Shell script |
| `sweep-ulx3s-12f.sh` | 12784 | `74426487ac9749104ff7d6e4461ea7c4f0d939cf2b5cdef3e653643d172df2ca` | REVIEW | Shell script |
| `sweep-ulx4m-ld.sh` | 8017 | `6a0ee4166a7669008186f91c11af22d04e42aef7507d763da4c152db0218b92a` | REVIEW | Shell script |
| `sweep.sh` | 7390 | `004c8d5db170c336a05ccc8b1c0e04c93314159e034483dc621eb027cacdd6c4` | REVIEW | Shell script |
