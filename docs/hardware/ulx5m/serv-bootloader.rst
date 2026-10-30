ULX5M-GS SERV Bootloader: Setup, Operation, and Recovery
========================================================

.. important:: Verified configuration and limitations

   The persistent GateMate seed-160 primary is **hardware verified** for
   BTN2-held USB DFU and BTN2-released automatic secondary boot. The optional
   full-image ``FWTF`` firmware is **hardware verified for USB enumeration
   and flash readback only**. Its full-image USB erase/program/FINISH path is
   not yet qualified on physical hardware. Do not treat it as a production
   updater or assume power-loss-safe rollback.

This guide applies to the Intergalaktik ULX5M-GS **V005** and the
``bootloader-serv/`` directory in Hazard3-Doom. It documents the experimental
SERV RV32I bootloader, **not** the Hazard3 CPU or the Doom application. The
verified secondary in this record is a small walking-LED GateMate image; a
ULX5M Doom application is a separate integration task.

Verified capabilities
---------------------

.. list-table:: Verified and experimental capabilities
   :header-rows: 1
   :widths: 57 43

   * - Capability
     - Verification status
   * - Persistent seed-160 primary from SPI flash
     - Hardware PASS
   * - BTN2-held USB DFU after BTN2 release
     - Hardware PASS (``FWTN``)
   * - Automatic boot at secondary address ``0x201000``
     - Hardware PASS (walking LEDs)
   * - Windows USB ``1D50:614B`` enumeration
     - Hardware PASS (``FWTN`` and SRAM-loaded ``FWTF``)
   * - Full 3,026-byte secondary readback and SHA-256 comparison
     - Hardware PASS (both profiles)
   * - Full-image stream and flash protection/verification
     - Offline emulator tests PASS
   * - Full-image USB erase/program/FINISH on physical flash
     - **Not yet qualified**
   * - Power-loss-safe update and automatic rollback
     - Not implemented

Startup modes
-------------

The hardware SW1 straps choose how GateMate obtains its **primary FPGA
configuration** at reset. BTN2 separately chooses what that primary does.
Change SW1 only while the FPGA is powered off.

.. list-table:: Tested switch/button combinations
   :header-rows: 1
   :widths: 18 32 50

   * - SW1
     - BTN2 at primary startup
     - Result
   * - OFF/OFF
     - Held before power-up
     - Load persistent primary from SPI flash and enter USB DFU
   * - OFF/OFF
     - Released
     - Load persistent primary, then start secondary at ``0x201000``
   * - ON/ON
     - Held throughout JTAG SRAM load and startup
     - Run an experimental primary temporarily; DFU when D4 is on

``OFF/OFF`` is SPI-active mode (configuration mode ``0x0``). ``ON/ON`` is
JTAG mode (``0xC``). Mixed settings are not used for this workflow. The
BTN2 latch is sampled during startup: releasing the button after entering
DFU does not switch modes. Conversely, pressing BTN2 **after** normal mode
has latched cannot enable USB.

The board has a 25 MHz reference clock. The independent
``rtl/ulx5m_cfg_autoboot_25.v`` controller issues the GateMate configuration
command and ``RECFG`` from its own 25 MHz domain. The SERV/USB SoC uses a
nominal 48 MHz PLL domain. The normal-mode controller releases the flash
pins for reconfiguration; the secondary boot does not depend on USB or a
running SERV firmware loop. On the tested board, walking LEDs appeared after
approximately 2.68 seconds.

.. list-table:: Primary LED diagnostics
   :header-rows: 1
   :widths: 15 85

   * - LED
     - Meaning while primary is running
   * - D7
     - Blinking heartbeat
   * - D6
     - PLL locked
   * - D5
     - Startup mode latched
   * - D4
     - DFU selected (ON)
   * - D3
     - Normal boot selected (ON)
   * - D2
     - Live BTN2 indication; ON while button is held
   * - D0, D1
     - Firmware status/witness LEDs

The observed persistent DFU indication **after releasing BTN2** is D0/D1
ON, D2/D3 OFF, D4/D5/D6 ON and D7 blinking. D7 blinking alone does not
prove the USB interface is active. The secondary uses a different walking
LED pattern.

Memory map and image roles
--------------------------

The U9 SPI flash is AT25QL321, JEDEC ``1F 42 16`` (4 MiB). Erase sectors
are 4,096 bytes and program pages are 256 bytes. The known flash layout is:

.. list-table:: Flash regions and secondary DFU policy
   :header-rows: 1
   :widths: 31 25 44

   * - Address range
     - Size
     - Use
   * - ``0x000000..0x07FFFF``
     - 512 KiB
     - **Protected** persistent primary bootloader
   * - ``0x080000..0x1FFFFF``
     - 1.5 MiB
     - **Reserved** existing/unknown flash contents
   * - ``0x200000..0x200FFF``
     - 4 KiB
     - **Reserved** candidate/metadata sector
   * - ``0x201000..0x3FFFFF``
     - 2,093,056 bytes
     - Native secondary window (``FWTF`` opt-in writer only)

These are software range guards, not hardware flash write-protection bits.
The secondary upper bound is ``0x1FF000`` bytes. Do not assume the reserved
ranges are empty just because a previously used staging test was erased.
The updater accepts no arbitrary host-selected flash address.

.. warning:: Primary and secondary .bit files are different

   ``build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit`` is
   the **primary bootloader**. It is not a native secondary and must not be
   passed as the DFU update payload.

   A native secondary is a separately packed GateMate image that belongs at
   ``0x201000``. The physical test used a recovered 3,026-byte image named
   ``build-ulx5m-gs/native-v41-secondary-3026.bit``. That filename is a
   local recovered artifact, **not** an output of a clean source checkout.

The SERV CPU is a compact RV32I soft core with firmware initialized into
FPGA block RAM. A Wishbone peripheral map provides status/LED/button
(``0x80000000``), UART logic (``0x81000000``), USB controller
(``0x82000000``), USB endpoint RAM (``0x83000000``) and SPI controller
(``0x84000000``). Configuration control has a separate synchronization/ACK
interface. This board's SERV bootloader is independent of the Hazard3/Doom
monitor firmware used by the eventual user image.

USB interface and firmware profiles
-----------------------------------

The DFU primary identifies as USB full-speed ``1D50:614B`` and uses interface
class/subclass/protocol ``FE/01/02``. USB control transfers carry up to
64-byte DFU blocks; the implementation has no separate bulk data endpoint.
The device-reported product is ``ULX5M-GS FPGA (DFU Probe)``. Windows can
show a cached ULX4M-friendly name; identify the device by VID:PID and its
actual descriptors rather than the tree label.

``FWTN``
   Default/restricted profile. Physical USB boot and readback are proven;
   this is the installed golden primary. Its native test writer is only a
   restricted 4 KiB experiment, **not** a full-image updater.

``FWTF``
   Opt-in ``DFU_FULL_IMAGE=1`` firmware profile. The full-image stream,
   bounds, erase/page/readback handling and vendor ARM/STATUS/FINISH protocol
   passed offline emulator tests. The candidate enumerated on physical USB
   after a **JTAG SRAM-only** load and read back the complete secondary.
   No full-image physical USB write has been qualified.

The full-image update protocol uses ordered 64-byte class DNLOAD blocks,
stream CRC32, explicit vendor ARM/STATUS/FINISH and a final independent
flash readback. The host's SHA-256 comparison is a stronger end-to-end
byte-for-byte check, but is not a signature/authenticity mechanism. A
normal ``dfu-util -D`` transfer is **not** a qualified replacement for
this project's explicitly armed update procedure. The host tool refuses
destructive update against ``FWTN``.

Newcomer prerequisites
----------------------

* Obtain the Hazard3-Doom source, including required pinned submodules, and
  find the ``bootloader-serv/`` directory. Do not interchange this target
  with ``bootloader/`` (PicoRV32) or the ECP5 ULX3S/ULX4M build outputs.
* Use a Linux shell or Windows 11 **WSL with Ubuntu** for Make, Python,
  synthesis, timing and Icarus tests. The tested baseline used OSS CAD Suite
  ``2026-07-20`` with Yosys ``0.67+47`` and nextpnr-himbaechel
  ``0.10-95-gddc6c8c8`` plus RISC-V bare-metal GCC **12.2.0**.
* The tested Windows/WSL installation has **no native USB devices in WSL**.
  Use Windows ``py -3`` and the Windows libusb backend to access the device.
  The repository's ``bin/libusb-1.0.dll`` is added to Windows PATH by the
  command below. PyUSB must be installed for the **Windows** Python used.
  If needed, install it from Windows PowerShell with
  ``py -3 -m pip install pyusb`` and verify with
  ``py -3 -c "import usb.core"``. Do not install it only in WSL.
* For temporary FPGA configuration, use the original Windows
  ``bin/openFPGALoader.exe`` (v1.2.0) and Tigard at 1.8 V logic. Share ground;
  keep Tigard VTGT disconnected. Do not change Windows USB drivers merely to
  make WSL ``lsusb`` work.
* Verify the specific V005 board's voltage domains and power wiring first;
  see :doc:`index`. Reported VDD_EA overvoltage is a known hardware concern.

Build and qualify in WSL
------------------------

All commands below are run from ``bootloader-serv/``:

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   make -f Makefile.ulx5m-gs show-settings
   make -f Makefile.ulx5m-gs test
   make -f Makefile.ulx5m-gs build SEED=160
   make -f Makefile.ulx5m-gs qualify SEED=160

The default build selects the restricted ``FWTN`` profile. To build the
experimental ``FWTF`` firmware explicitly, use:

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   make -f Makefile.ulx5m-gs build SEED=160 DFU_FULL_IMAGE=1
   make -f Makefile.ulx5m-gs qualify SEED=160 DFU_FULL_IMAGE=1

The final primary is
``build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit``.
The build derives and verifies a 27-byte GateMate configuration command
from the **exact packed image**. Do not reuse a command ROM derived from
another version or seed. A successful route is offline evidence, not a
physical USB, flash-write or autonomous-boot test. Seed 160 is a dated
hardware checkpoint, not a guarantee for future firmware changes.

Temporary SRAM test without altering flash
------------------------------------------

Power off the FPGA and Tigard. Set SW1 ON/ON. Hold BTN2 while powering the
ULX5M, then power Tigard. **Keep BTN2 held through the entire JTAG SRAM
load and until D4 is ON**. Then release it; D4 should stay ON and D3 stay
OFF. If D3 is ON, reset/reload with BTN2 held; pressing BTN2 late cannot
change the latched boot mode.

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   ../bin/openFPGALoader.exe -c tigard --freq 1000k --detect
   ../bin/openFPGALoader.exe -c tigard --freq 1000k -m \
     "$(wslpath -w "$PWD/build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit")"

Check JTAG IDCODE ``0x20000001`` and the ``Load SRAM via JTAG: 100%``
result. The ``-m`` operation is volatile; do **not** use ``-f``. Wait for
Windows to enumerate ``1D50:614B``. A loaded image can still choose normal
mode if BTN2 was released too early.

Read-only physical USB verification
-----------------------------------

The USB ``--probe`` command requires a known native secondary image that
matches the board's installed flash. The following path exists only if the
3,026-byte known-good image was already recovered from verified flash
backups. Verify the image hash before using it:

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   sha256sum build-ulx5m-gs/native-v41-secondary-3026.bit
   python3 tests/ulx5m_dfu_update.py \
     --image build-ulx5m-gs/native-v41-secondary-3026.bit

The second command above performs **offline preflight only**. Its known-good
image SHA-256 is
``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``.
With the ULX5M in DFU mode, use native **Windows Python** for USB:

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   SCRIPT_WIN="$(wslpath -w "$PWD/tests/ulx5m_dfu_update.py")"
   IMAGE_WIN="$(wslpath -w "$PWD/build-ulx5m-gs/native-v41-secondary-3026.bit")"
   BIN_WIN="$(wslpath -w "$PWD/../bin")"
   powershell.exe -NoProfile -Command \
     "\$env:PATH='$BIN_WIN;' + \$env:PATH; py -3 '$SCRIPT_WIN' --image '$IMAGE_WIN' --probe"

An expected successful result identifies ``Device profile FWTN`` or
``Device profile FWTF``, verifies ``3026/3026`` bytes and reports the
matching SHA-256. ``--probe`` uses vendor IN reads only: it sends **no ARM,
erase, program, FINISH or RECFG requests**. Do not use the destructive
``--execute`` option during newcomer setup.

Persistent golden boot and recovery
-----------------------------------

After a volatile test, power off both boards, set SW1 OFF/OFF, leave Tigard
**off**, and hold BTN2 before powering the ULX5M. Release BTN2 after the
primary DFU LED pattern appears. The USB read-only probe should show
``FWTN`` again. Power-cycle a second time with BTN2 **released** to
confirm automatic secondary boot and walking LEDs. The October 30 bench
confirmed both modes, including the final walking LEDs, without Tigard.

Installing a new primary in persistent flash is a **separate, advanced and
destructive** maintenance operation. Building the bitstream or using ``-m``
does not install it. The guarded ``tests/ulx5m_flash_install.py`` utility
is designed for a previously provisioned chip with a verified secondary;
it performs full-flash backup and primary-only verification/rollback checks.
It is not a blank-board provisioning recipe. Review its help and preflight,
retain independent original 4 MiB flash backups, and verify exact image
hashes before authorizing any primary write. Do not overwrite the proven
seed-160 primary solely to test the experimental full-image DFU path.

The full-image ``FWTF`` update is **in-place**, not an A/B atomic update.
An interrupted erase/program sequence can leave the secondary unbootable.
If the persistent primary is healthy, hold BTN2 before power-on to regain
DFU; otherwise, external JTAG/flash recovery is required. The lengthy
synchronous FINISH readback/tail scan also requires physical timing/USB
qualification before a first destructive update. The present documentation
provides **no** authorization to perform that write.

Troubleshooting
---------------

.. list-table:: Common symptoms
   :header-rows: 1
   :widths: 38 62

   * - Symptom
     - Check
   * - JTAG detection fails
     - SW1 ON/ON; power ULX5M before Tigard; ground, 1.8 V I/O; IDCODE ``0x20000001``
   * - JTAG load succeeds but USB is absent
     - BTN2 must remain held through load/startup; D4 ON and D3 OFF identify DFU
   * - USB device has an old ULX4M Windows name
     - Use VID:PID and actual ``ULX5M-GS FPGA (DFU Probe)`` descriptor
   * - WSL ``lsusb`` does not see board
     - Expected on this bench; invoke Windows Python through PowerShell
   * - Python reports no PyUSB/libusb backend
     - Install/check dependencies for Windows ``py -3``, not just WSL Python
   * - Host reports ``FWTN`` instead of ``FWTF``
     - Persistent golden boot or wrong candidate; check the bitfile hash
   * - Preflight rejects the image
     - Supply a native *secondary*, not the primary PACK-ONLY bitstream
   * - Power loss during a future secondary update
     - Do not rely on automatic rollback; use BTN2-held DFU or external recovery

Reproducibility reference
-------------------------

.. list-table:: Hardware-proven image fingerprints
   :header-rows: 1
   :widths: 43 57

   * - Item
     - Value
   * - Golden persistent ``FWTN`` primary
     - 420,175 bytes; SHA-256 ``c41830bd09e0e924facd2425f10a8072878e59505d12b82aff533be7df8cfe27``
   * - Opt-in SRAM-tested ``FWTF`` primary
     - SHA-256 ``6c1bb2b8219f9b0c69c56725467b9a6c40f80a3a5caf6262dfe5769842528c97``
   * - Known-good native walking-LED secondary
     - 3,026 bytes; SHA-256 ``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``
   * - Matching original full-flash backups
     - SHA-256 ``09542df4b40bb6bcce00a327bb890f6a2d46099eae2e41f7a89e8e602614007d``
   * - Golden primary recovery session
     - ``build-ulx5m-gs/flash-install-20261030T155241133153Z``
   * - Routed full-image candidate
     - Seed 160; 25 MHz domain Fmax 67.96 MHz; 48 MHz domain Fmax 49.06 MHz

These values identify the hardware tested on October 30, 2026 and must
not be assumed for future revisions. The two primary images have the same output filename but
different contents. Check the file SHA-256 before a JTAG or flash operation.

Related documentation
---------------------

* :doc:`index` - V005 pin configuration, power and bank-voltage cautions.
* :doc:`bringup` - dated physical testing and evidence.
* :doc:`multiboot-v72` - historical isolated secondary-boot experiment.
* :doc:`../../user-guide/bootloader` - ULX3S/ULX4M DFU documentation and
  older ULX5M development context; do not apply their flash addresses to V005.
