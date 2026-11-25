# ULX5M-GS SERV Bootloader vs. tinyDFU

**Comparison date:** 2026-10-30  
**In-house project:** Hazard3-Doom `bootloader-serv`, ULX5M-GS target  
**Reference:** [`pu-cc/tinydfu-bootloader`, ULX5M implementation](https://github.com/pu-cc/tinydfu-bootloader/tree/master/boards/ulx5m)

## Executive summary

Both designs provide an FPGA-resident USB Device Firmware Upgrade (DFU) interface for programming external SPI flash and starting a secondary GateMate FPGA image. Their primary difference is architectural:

- **Hazard3-Doom:** software-controlled bootloader running on a **SERV RV32I RISC-V softcore**, with USB, SPI-flash and reconfiguration peripherals. It prioritizes explicit flash-region protection, validation, and integration with the existing ULX3S/ULX4M bootloader workflow.
- **tinyDFU:** **CPU-free Verilog design** whose USB DFU control logic directly drives an SPI-flash state machine and GateMate reconfiguration logic. Its ULX5M board target is a useful reference for USB and `CC_CFG_CTRL` operation, with a simpler control path.

**Current result:** the Hazard3-Doom experimental `FWTF` image passed **one authorized, same-image, 3,026-byte USB DFU rewrite** of the secondary at `0x201000`, including device-side verification and a matching USB readback SHA-256. The persistent `FWTN` image has previously demonstrated autonomous secondary boot. **Independent full-chip comparison, persistent recovery and autonomous boot *after* that rewrite remain to be verified.** This is not yet proof of general-purpose, interruption-safe field updating.

`FWTN` and `FWTF` are **project-specific diagnostic signatures**, not standard industry terminology: `FWTN` identifies the persistent restricted/golden DFU profile; `FWTF` identifies the experimental full-image DFU profile loaded into volatile FPGA configuration memory for testing.

## Feature comparison

**Status key:** **HW** = demonstrated on the ULX5M-GS hardware in our tests; **SRC** = present in reviewed source or documented implementation, but not necessarily independently tested; **PENDING** = not yet qualified for our bootloader. tinyDFU capabilities marked SRC were checked against the referenced upstream ULX5M source; we have not independently reproduced all upstream hardware results.

| Feature | Hazard3-Doom ULX5M-GS SERV bootloader | pu-cc tinyDFU ULX5M |
|---|---|---|
| **Architecture** | SERV RV32I CPU with firmware-driven USB/flash control (**HW/SRC**) | Direct Verilog USB/DFU and flash state machines; no CPU (**SRC**) |
| **FPGA family** | Cologne Chip GateMate, ULX5M-GS (**HW**) | Cologne Chip GateMate, ULX5M (**SRC**) |
| **System clocks** | 25 MHz SERV/control, 48 MHz USB (**HW/SRC**) | 25 MHz reference; 48 MHz USB PLL; divided 12 MHz control clock (**SRC**) |
| **USB interface** | Full-speed USB DFU, class/subclass/protocol `FE/01/02` (**HW**) | Full-speed USB DFU, `FE/01/02` (**SRC**) |
| **USB VID:PID** | `1D50:614B` (**HW**) | `0959:116D` defined in ULX5M `boardinfo.vh` (**SRC**) |
| **DFU transfer unit** | 64-byte ordered DNLOAD blocks in the full-image update protocol (**SRC/HW for 3,026 bytes**) | `wTransferSize = 256` bytes, matching its flash page size (**SRC**) |
| **DFU alternate settings** | Application/update path at alt 0; restricted vendor control for protected update operations (**HW/SRC**) | Six settings: user image, user data, bootloader, three security registers (**SRC**) |
| **Standard host interoperability** | USB DFU enumeration and standard control requests; full-image writing additionally requires project-specific ARM/STATUS/FINISH control (**HW/SRC**) | Conventional `dfu-util` DFU download/upload by alternate setting (**SRC**) |
| **Startup behavior** | BTN2 held selects DFU; BTN2 released boots the stored secondary without a five-second DFU idle wait (**HW, before the latest rewrite**) | Enters bootloader first; auto-boots user image after approximately five seconds unless DFU activity cancels it (**SRC**) |
| **Explicit start/exit** | GateMate `CC_CFG_CTRL` reconfiguration path; automatic handoff verified before latest write (**HW**) | `DFU_DETACH` or idle timeout initiates `CC_CFG_CTRL` command/reconfiguration (**SRC**) |
| **Secondary image address** | `0x201000` (**HW**) | `0x100000` (**SRC**) |
| **Total SPI flash** | 4 MiB AT25QL321; JEDEC `0x1F4216` (**HW**) | ULX5M target defines 4 MiB flash (**SRC**) |
| **Flash page/erase geometry** | 256-byte pages; 4 KiB erase sectors (**HW/SRC**) | 256-byte pages; 4 KiB erase sectors (**SRC**) |
| **USB flash readback** | Physical flash readback with matching 3,026-byte SHA-256 (**HW**) | DFU_UPLOAD through direct flash bridge (**SRC**) |
| **USB flash writing** | One guarded erase/program/finish cycle rewriting the *same* 3,026-byte image at `0x201000` (**HW**); larger/new image **PENDING** | Erase-on-sector-boundary and page programming through DFU_DNLOAD (**SRC**) |
| **Write validation** | Ordered blocks, expected-length/CRC handling, device-side verification and host SHA-256 readback (**HW/SRC**) | DFU status and flash-busy handling; host may verify with DFU_UPLOAD. No equivalent in-core full-image CRC/readback verification found in reviewed RTL (**SRC**) |
| **Flash-region protection** | Deny-by-default write window; flash below `0x201000` protected in full-image DFU, with no arbitrary address or chip erase (**SRC**) | Alt settings expose a writable **bootloader partition** and security registers; not the same deny-by-default golden-primary policy (**SRC**) |
| **Update authorization** | Explicit host-side opt-in/arming and guarded firmware update state (**SRC**) | DFU alt selection and ordinary DFU requests; no analogous ARM requirement found in reviewed RTL (**SRC**) |
| **Atomic A/B firmware update** | **Not implemented/qualified** | No atomic A/B image rollback found in the reviewed ULX5M design (**SRC**) |
| **Power-interruption recovery** | Persistent golden loader and JTAG recovery path exist; interruption during an actual secondary update **PENDING** | SPI-flash/JTAG recovery remains relevant after an interrupted/incorrect write; no automatic rollback established by reviewed source (**SRC**) |
| **LED status** | Eight-board-LED startup/DFU witnesses; distinctive secondary walking-LED application (**HW**) | Four-LED idle blink and activity/walking pattern (**SRC**) |
| **Testing evidence** | Host simulations, unit tests, local timing-closed builds, USB read/first guarded write and earlier autonomous boots (**HW/SRC**) | ULX5M source, board build and testbench tree; external reported working example, but not the same in-house test record (**SRC**) |
| **Implementation complexity** | More flexible firmware architecture, but more components, state handling, USB responsiveness and timing dependencies | Smaller conceptual control path, with functionality concentrated in RTL; less firmware extensibility |

## Flash layouts are not interchangeable

The two bootloaders deliberately use **different partition maps**. A tinyDFU image or DFU transfer must not be applied to our flash layout without a separately reviewed migration plan.

| Flash range (inclusive) | Hazard3-Doom policy | tinyDFU ULX5M policy |
|---|---|---|
| `0x000000`–`0x07FFFF` | Persistent 512 KiB primary/golden bootloader; protected from secondary DFU writes | First half of its 1 MiB bootloader partition; exposed through bootloader alt 2 |
| `0x080000`–`0x0FFFFF` | Occupied/unknown data: preserve, do not erase | Remainder of its 1 MiB bootloader partition (alt 2) |
| `0x100000`–`0x1FFFFF` | Occupied/unknown data: preserve, do not erase | 1 MiB user-image partition (alt 0); native secondary begins at `0x100000` |
| `0x200000`–`0x200FFF` | Reserved metadata/legacy sector; protected | Start of user-data partition (alt 1) |
| `0x201000`–`0x3FFFFF` | Authorized secondary-update *address window*; preserve unknown/trailing contents unless explicitly inventoried/authorized | Remaining user-data partition (alt 1) |

Hazard3-Doom's maximum **address window** from `0x201000` through `0x3FFFFF` is **2,093,056 bytes** (`0x1FF000`). That is a boundary, **not** a declaration that all occupied sectors inside it may be discarded. The previously proven secondary has only **3,026 bytes**.

tinyDFU also exposes three separate SPI security-register alternatives, numbered **3–5**; they are not part of the ordinary 4 MiB address map.

## Current Hazard3-Doom hardware evidence

| Test | Result as of 2026-10-30 |
|---|---|
| Flash-installed seed-160 golden primary (`FWTN`) | **PASS**: cold boot, DFU entry and USB enumeration |
| USB identity | **PASS**: `1D50:614B`, DFU `FE/01/02` |
| Existing secondary at `0x201000` | **PASS**: automatic reconfiguration and walking-LED execution in previous cold boots |
| Volatile JTAG-loaded full-image candidate (`FWTF`) | **PASS**: USB enumeration, flash identification and 3,026-byte USB readback |
| First explicitly authorized USB secondary rewrite | **PASS**: 3,026 of 3,026 bytes, device verification, USB readback; known identical-image SHA-256 `68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd` |
| Reconfiguration immediately following this write | **Not attempted**: no RECFG command was issued during the guarded writer test |
| Independent post-write full 4 MiB comparison | **PENDING** |
| Reboot into persistent `FWTN` and autonomous secondary after this write | **PENDING** |
| New/different and large full-image USB DFU writes | **PENDING** on hardware; host/mock tests are not a substitute |
| USB disconnect, reset or power loss during update | **PENDING**; automatic transactional rollback not established |

The experiment proved one physical USB flash update path without overwriting the golden primary by design. It **does not yet prove** preservation of every untouched flash byte, long-operation USB responsiveness, post-update bootability or safe failure in all conditions.

## Specific upstream tinyDFU observations

1. **Useful GateMate reference:** its top-level `tinydfu_ulx5m.v` contains a 27-byte `CC_CFG_CTRL` command ROM, a finite-state-machine sequencer, and `RECFG`, followed by a `--reconfig --bootaddr 1048576` pack. This is useful reference material, but our verified secondary starts at a different address and the command bytes are image/layout-specific.
2. **Simpler update path:** `usb_dfu_ctrl_ep.v` dispatches `DFU_DNLOAD`, `DFU_UPLOAD`, `DFU_GETSTATUS`, `DFU_DETACH`, and alt selections directly to `usb_spiflash_bridge.v`, which performs sector erase and page programming. It does not require a running RISC-V core.
3. **Different risk model:** tinyDFU's source explicitly exposes alt 2 for its bootloader partition and alt 3–5 for security registers. This is convenient for recovery and maintenance, but exposes operations that our restricted update path intentionally excludes. Do not treat either design as authenticated or tamper-resistant merely because it implements USB DFU.
4. **Upstream command mismatch:** tinyDFU ULX5M `boardinfo.vh` declares VID:PID **`0959:116D`**, but its `Makefile` `dfu` target uses **`16d0:116d`**. The board definition, not that convenience command, determines the compiled USB identity. Verify against actual enumeration before using upstream examples.
5. **USB transfer size is not a throughput benchmark:** 64-byte versus 256-byte DFU transfers alone do not establish which implementation is faster. Flash erase/program time, SPI clock, USB service latency and whole-image measurement matter.

## Engineering assessment

**tinyDFU is the more direct reference design** for a minimal GateMate USB-to-SPI-flash bootloader. Its RTL provides a useful benchmark for USB enumeration, straightforward flash operations and reconfiguration. Its different partition map and exposed bootloader/security-register access make it **unsuitable as a drop-in replacement** for our installed flash image.

**Our SERV bootloader provides a more controlled foundation** for the planned common ULX3S/ULX4M/ULX5M experience, especially protected regions, explicit update arming and post-write checks. It has also crossed an important hardware milestone with the first guarded secondary rewrite. However, **functional richness is not equivalent to operational maturity**: to finish it, the next evidence should establish full-chip preservation after that write, persistent-bootloader recovery, successful autonomous boot of the rewritten image, and then a separately authorized different-image/larger-image and interruption test sequence.

**Safety constraint:** any further erase/program/reflash, destructive recovery or interruption experiment requires a *new, explicit authorization*. The first 3,026-byte write approval does not extend to other writes. This report provides no flash-changing commands.

## Primary sources

**tinyDFU ULX5M source** (reviewed 2026-10-30):

- [ULX5M top-level, clocks, LEDs, auto-boot, `CC_CFG_CTRL`](https://github.com/pu-cc/tinydfu-bootloader/blob/master/boards/ulx5m/tinydfu_ulx5m.v)
- [ULX5M flash layout and USB ID](https://github.com/pu-cc/tinydfu-bootloader/blob/master/boards/ulx5m/boardinfo.vh)
- [ULX5M Makefile, `BOOTADDR`, programming targets](https://github.com/pu-cc/tinydfu-bootloader/blob/master/boards/ulx5m/Makefile)
- [DFU alt settings and request handling](https://github.com/pu-cc/tinydfu-bootloader/blob/master/usb/usb_dfu_ctrl_ep.v)
- [SPI flash read, erase, and page-program logic](https://github.com/pu-cc/tinydfu-bootloader/blob/master/usb/usb_spiflash_bridge.v)
- [USB DFU core](https://github.com/pu-cc/tinydfu-bootloader/blob/master/usb/usb_dfu_core.v)

**Hazard3-Doom:** hardware and test evidence from the October 30, 2026 seed-160 installation, `FWTN`/`FWTF` USB tests, and the first explicitly authorized same-image 3,026-byte rewrite, as reported in the project's hardware sessions; see the local `bootloader-serv` build and diagnostic records for exact reproducibility. This comparison is a status report, not a replacement for those logs or a source revision audit.
