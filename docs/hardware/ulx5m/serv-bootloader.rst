ULX5M-GS SERV Bootloader: Setup, Operation, and Recovery
========================================================

.. important:: Verified configuration and limitations

   The seed-160 ``FWTN`` primary is validated for persistent DFU recovery
   and autonomous secondary boot. The SRAM-only ``FWTF`` v2d profile is
   validated for a same-image, 3,026-byte USB secondary rewrite, including
   firmware verification, independent USB readback and full-flash JTAG
   comparison. Updates are in-place; power-loss recovery and larger images
   are not hardware-qualified.

This guide applies to the Intergalaktik ULX5M-GS **V005** and the
``bootloader-serv/`` directory in Hazard3-Doom. It documents the experimental
SERV RV32I bootloader, **not** the Hazard3 CPU or the Doom application. The
verified secondary in this record is a small walking-LED GateMate image; a
ULX5M Doom application is a separate integration task.

Factory-new board: initial bootloader installation
--------------------------------------------------

.. note::

   This procedure uses previously verified JTAG flash programming
   and readback operations. The complete installation sequence has
   not yet been independently tested on a factory-new board.

.. warning:: Persistent flash programming.

   This writes persistent flash. Use only on a factory-new ULX5M-GS V005
   with explicit authorization to replace its factory configuration. Do not
   use the maintenance installer for this task: it requires an existing
   secondary and a qualified FWTF build. Never install FWTF as the golden primary.

No firmware build is required. Obtain the matching release files
``bin/ulx5m_gs_bootloader.bit`` (FWTN) and ``bin/ulx5m_gs_blinky.bit``
with the matching release manifest ``bin/INVENTORY.sha256``. Use a Tigard,
openFPGALoader v1.2.0 and Python 3. On Windows use the bundled executable;
on native Ubuntu install a compatible v1.2.0 executable on PATH and configure
USB permissions. Under WSL, the installer uses the bundled Windows
executable via Windows interoperability. Keep the repository on a Windows
drive (for example, ``/mnt/c``); no native WSL USB access is required.

With both devices off, set SW1 ON/ON. Connect Tigard at 1.8 V logic with
common ground and VTGT disconnected; verify the board voltage domains (see
:doc:`index`). Power the ULX5M first, then Tigard. Leave BTN2 released.
Expect a single GateMate IDCODE ``0x20000001`` and flash JEDEC ``1F 42 16``.
Stop on unexpected devices or errors.

Before any JTAG access, the installer automatically checks both bitstreams
against their entries in ``bin/INVENTORY.sha256``. No manual hash entry is
required. A missing inventory, missing or duplicate entry, invalid hash or
mismatch stops the installer before JTAG access. Use the inventory from the
same trusted release; do not regenerate it to bypass a mismatch.

Run ``scripts/factory-install-ulx5m-bootloader.py`` from the project root.
It reads two independent 4 MiB backups in 128 KiB chunks before asking for
permission to write. Keep the backups outside any disposable build directory.
The primary occupies 512 KiB at zero; the secondary starts at ``0x201000``.
Only the primary partition and the secondary's occupied erase sectors are
replaced. All other bytes must remain unchanged. Do not run with Python -O.

**Windows PowerShell**

.. code-block:: powershell

   cd C:\workspace\Hazard3-Doom
   py -3 .\scripts\factory-install-ulx5m-bootloader.py

**Ubuntu under WSL (Bash)**

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom
   python3 ./scripts/factory-install-ulx5m-bootloader.py

**Native Ubuntu / Linux (Bash)**

.. code-block:: bash

   cd ~/Hazard3-Doom
   python3 ./scripts/factory-install-ulx5m-bootloader.py

After PASS, power off Tigard and ULX5M, disconnect Tigard, set SW1 OFF/OFF.
Hold BTN2 before powering the ULX5M; release after USB ``1D50:614B`` enumerates.
Use the identity query below to confirm FWTN. Power off again, release BTN2,
and power on: expect the secondary walking LEDs for the demo image.
If anything fails, stop, retain both factory backups and logs, and do not
retry or attempt automatic rollback. This procedure has no automatic recovery.

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
   * - Same-image 3,026-byte USB rewrite and independent 4 MiB verification
     - Hardware PASS (``FWTF`` v2d)
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
running SERV firmware loop. The measured startup interval for the reference
secondary was approximately 2.68 seconds.

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

``FWTN`` and ``FWTF`` are four-byte ASCII **firmware profile identifiers**,
not image filenames, GateMate configuration commands or USB product IDs.
They occupy bytes 0..3 of the 24-byte vendor STATUS response (request
``0x5D``), identifying the firmware currently answering over USB, not the
contents of secondary flash. Both profiles use USB VID:PID ``1D50:614B``.

``FWTN``
   Default restricted profile (build without ``DFU_FULL_IMAGE=1``), installed
   as the golden persistent primary. USB enumeration and read-only secondary
   verification are hardware-proven. Its restricted 4 KiB test writer is
   **not** the full-image updater; the host refuses ``--execute`` on ``FWTN``.

``FWTF``
   Opt-in full-image writer (``DFU_FULL_IMAGE=1``), tested by temporary JTAG
   ``-m`` SRAM loading, **not** installed to primary flash. The v2d candidate
   passed a physical 3,026-byte secondary rewrite, firmware FINISH and
   independent USB host readback. Two independent post-write 4 MiB JTAG
   dumps, golden ``FWTN`` recovery and autonomous secondary boot also passed.
   Interrupted-write recovery and larger images remain unqualified.

After the four ASCII bytes, STATUS returns five little-endian 32-bit values:
phase, expected image length, expected CRC32, received byte count and error
code. Phase ``0`` is disarmed, ``1`` armed, ``4`` verifying, ``2`` verified
and ``3`` failed. An accepted FINISH request is **not** itself proof of
verification: the host must poll through phase ``4`` and require phase ``2``
with no error. The host's SHA-256 readback compares bytes, but is not an
image-authenticity signature.

The full-image protocol uses ordered 64-byte class DNLOAD blocks, stream
CRC32, and vendor ARM (``0x5C``), STATUS (``0x5D``) and FINISH (``0x5E``)
requests. ``--probe`` permits either profile and performs **read-only**
verification; ``--execute`` requires ``FWTF``, an exact confirmation
argument and the expected image SHA-256 (checked before USB access).
Ordinary ``dfu-util -D`` is not a qualified replacement for
this explicitly armed update protocol.

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

Both Tigard-first and ULX5M-first power-up orders have worked; neither
is a required sequence. A completed JTAG SRAM transfer does not establish
that the firmware is running. If the LEDs remain dark or USB does not
enumerate, disconnect power from **both** devices and retry with the
opposite power-up order, holding BTN2 through configuration. Confirm D4
ON, D3 OFF and USB enumeration before accessing flash. The cause of the
power-order sensitivity is not established. Keep Tigard VTGT disconnected,
maintain a common ground, and never interrupt flash erase/program power.

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   ../bin/openFPGALoader.exe -c tigard --freq 1000k --detect
   ../bin/openFPGALoader.exe -c tigard --freq 1000k -m \
     "$(wslpath -w "$PWD/build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit")"

Check JTAG IDCODE ``0x20000001`` and the ``Load SRAM via JTAG: 100%``
result. The ``-m`` operation is volatile; do **not** use ``-f``. Wait for
Windows to enumerate ``1D50:614B``. A loaded image can still choose normal
mode if BTN2 was released too early.

A JTAG SRAM load with SW1 ON/ON is not an SPI-active cold-boot test.
GateMate latches its configuration mode at reset; JTAG mode does not
automatically boot an image from SPI flash. With BTN2 released, D3 ON,
D4 OFF and D7 blinking indicate normal mode in the primary firmware,
not a verified secondary handoff. Absence of walking LEDs in this test
alone is not evidence of an autoboot regression. Check autonomous boot
separately with SW1 OFF/OFF and BTN2 released at cold power-on; that
tests the installed ``FWTN`` primary, not the SRAM-only ``FWTF`` image.
Do not change SW1 while the board is powered to force a mode change.

Save the installed bootloader
-----------------------------

Power off both devices. Set SW1 ON/ON, connect Tigard with common ground,
1.8 V logic and VTGT disconnected. Power the ULX5M first, then Tigard.
From Windows PowerShell, run the following read-only commands. Four 128 KiB
reads avoid relying on a large single flash transfer. Stop if detection
fails or the flash is not the expected AT25QL321 (JEDEC ``1F 42 16``).

.. code-block:: powershell

   cd C:\workspace\Hazard3-Doom
   .\bin\openFPGALoader.exe -c tigard --freq 1000k --detect
   $output = "$HOME\ulx5m-bootloader.bin"
   $data = New-Object 'System.Collections.Generic.List[byte]'
   for ($offset = 0; $offset -lt 524288; $offset += 131072) {
       $chunk = "$output.$offset.chunk"
       if (Test-Path $chunk) { throw "Chunk already exists: $chunk" }
       .\bin\openFPGALoader.exe -c tigard --freq 1000k --dump-flash --file-size 131072 -o $offset $chunk
       if ($LASTEXITCODE -ne 0) { throw "Read failed: $offset" }
       $bytes = [IO.File]::ReadAllBytes($chunk)
       if ($bytes.Length -ne 131072) { throw "Invalid chunk size: $offset" }
       $data.AddRange($bytes)
   }
   if (Test-Path $output) { throw "Backup already exists: $output" }
   [IO.File]::WriteAllBytes($output, $data.ToArray())
   Get-Item $output
   Get-FileHash $output -Algorithm SHA256

**Native Ubuntu / Linux (Bash)**

Use a native Linux build of openFPGALoader with GateMate and Tigard support (the tested Windows version is v1.2.0). Make sure it is on PATH and USB permissions are configured. This is not the WSL workflow: on the tested Windows/WSL setup, use the PowerShell commands above. Stop if detection fails or any flash read reports a JEDEC ID other than ``1F 42 16``. Run this block in Bash; it creates a new backup directory and refuses to reuse an existing one.

.. code-block:: bash

   (
       set -euo pipefail
       openFPGALoader -c tigard --freq 1000k --detect
       backup_dir="$HOME/ulx5m-bootloader-backup"
       mkdir "$backup_dir"
       cd "$backup_dir"
       for offset in 0 131072 262144 393216; do
           chunk="$offset.chunk"
           openFPGALoader -c tigard --freq 1000k --dump-flash --file-size 131072 -o "$offset" "$chunk"
           test "$(wc -c < "$chunk")" -eq 131072
       done
       cat 0.chunk 131072.chunk 262144.chunk 393216.chunk > ulx5m-bootloader.bin
       test "$(wc -c < ulx5m-bootloader.bin)" -eq 524288
       wc -c ulx5m-bootloader.bin
       sha256sum ulx5m-bootloader.bin
   )

The result is a 524,288-byte raw flash backup of ``0x000000..0x07FFFF``,
including any padding, not necessarily identical in length to the original
``.bit`` file. Keep the chunks until verification is complete. For a second
independent read, change the output filename and compare both SHA-256 hashes.
A matching reference dump identifies the installed bytes; a hash alone does
not reveal a version. For full-chip recovery, also retain a 4 MiB backup.
Power off both devices and return SW1 to OFF/OFF when finished.

Query the bootloader identity
-----------------------------

With Tigard disconnected or off, set SW1 OFF/OFF while powered off. Hold
BTN2 during ULX5M power-up and release after DFU enumeration. With Windows
PyUSB and the libusb backend available (see prerequisites), query the
USB vendor STATUS response directly, without a secondary image:

.. code-block:: powershell

   cd C:\workspace\Hazard3-Doom
   $env:PATH = "$PWD\bin;$env:PATH"
   py -3 -c "import usb.core; d=usb.core.find(idVendor=0x1d50,idProduct=0x614b); assert d is not None, 'DFU device not found'; s=bytes(d.ctrl_transfer(0xC0,0x5D,0,0,24)); assert len(s)==24, 'Unexpected STATUS length'; print('Profile:', s[:4].decode('ascii')); print('USB bcdDevice: 0x%04X' % d.bcdDevice)"

**Native Ubuntu / Linux (Bash)**

On native Ubuntu, install PyUSB and libusb, then check DFU enumeration. USB access must be permitted by the host's udev rules. If access fails, correct the permissions before retrying. On the tested WSL setup use Windows PowerShell instead.

.. code-block:: bash

   sudo apt install python3-usb libusb-1.0-0 usbutils
   lsusb -d 1d50:614b
   python3 -c "import usb.core; d=usb.core.find(idVendor=0x1d50,idProduct=0x614b); assert d is not None, 'DFU device not found'; s=bytes(d.ctrl_transfer(0xC0,0x5D,0,0,24)); assert len(s)==24, 'Unexpected STATUS length'; print('Profile:', s[:4].decode('ascii')); print('USB bcdDevice: 0x%04X' % d.bcdDevice)"

The native Linux alternatives have not been tested on the board.

Expect ``FWTN`` or ``FWTF``. The USB ``bcdDevice`` descriptor is also shown
for information; neither field is documented as a unique firmware build
version. This standalone read-only command is derived from the documented
STATUS protocol; it has not been hardware-tested here. The existing
``--probe`` procedure below is the documented alternative. No semantic
version, Git commit or seed query is established by this guide.

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
erase, program, FINISH or RECFG requests**. The separate ``--execute``
command requires explicit authorization.

Guarded secondary update (experimental)
---------------------------------------

The reference procedure rewrites the existing 3,026-byte native secondary
in sector ``0x201000..0x201FFF``. It does **not** install a primary
bootloader. Updates are **in-place and non-atomic**: USB disconnect, power
loss or flash errors can leave the secondary unbootable. Obtain explicit
operator authorization for each destructive update.

The following prerequisites are required before an authorized experiment:

* Verify the primary and secondary image hashes in the qualification table.
* Preserve two **independent**, matching 4 MiB pre-write dumps outside
  generated build directories. For the verified reference flash image,
  SHA-256 is ``3aa6280fd96de3c00ef844a2f0298a919f7cea9311d5a267ee0be85bc4375c78``
  (``../ulx5m-prewrite-readonly-20261030-FN1nVy/``). Future flash contents
  may differ; verify and retain the actual pre-write backups.
* Confirm the ``0x201BD2..0x3FFFFF`` tail is all ``0xFF`` and keep
  ``0x000000..0x200FFF`` protected. v2d does not erase trailing sectors.
* Use SW1 ON/ON and BTN2 held continuously during the **SRAM-only** JTAG
  ``-m`` load of the exact v2d ``FWTF`` primary. Verify D4 ON, D3 OFF, USB
  ``1D50:614B``, and a successful **read-only** ``--probe`` reporting ``FWTF``.
  Never install ``FWTF`` into the golden primary flash partition.

Only after those checks and explicit approval, run the existing canonical
Windows host tool (not WSL PyUSB). The command below is **destructive**:

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   SCRIPT_WIN="$(wslpath -w "$PWD/tests/ulx5m_dfu_update.py")"
   IMAGE_WIN="$(wslpath -w "$PWD/build-ulx5m-gs/native-v41-secondary-3026.bit")"
   BIN_WIN="$(wslpath -w "$PWD/../bin")"
   EXPECTED_SHA256="68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
   powershell.exe -NoProfile -Command \
     "\$env:PATH='$BIN_WIN;' + \$env:PATH; py -3 '$SCRIPT_WIN' --image '$IMAGE_WIN' --execute --confirm REPLACE-SECONDARY-0x201000 --expected-sha256 '$EXPECTED_SHA256'"

After an authorized update, require successful FINISH verification and an
independent USB readback matching the supplied image SHA-256. The reference
secondary SHA-256 is
``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``.
The host does not issue FPGA RECFG.

Use the JTAG ``tests/ulx5m_flash_install.py`` read-only ``detect()`` and
``dump()`` APIs for independent full-chip verification. For the same-image
reference rewrite, the 4 MiB dump must match the pre-write image byte-for-byte
(SHA-256 ``3aa6280fd96de3c00ef844a2f0298a919f7cea9311d5a267ee0be85bc4375c78``).
For a different secondary image, compare the changed region with the new
payload and verify that all other flash bytes remain unchanged. Finally,
verify SW1 OFF/OFF with BTN2 held for ``FWTN`` recovery and BTN2 released
for autonomous secondary boot. Only the same-image reference operation has
completed these physical checks.

If any transfer, verification or comparison fails, stop. Preserve logs and
backups; do not attempt an automatic retry or normal secondary boot. Enter
golden DFU with BTN2 held before the next cold boot, and diagnose recovery
before another authorized write. No automatic rollback exists.

Persistent golden boot and recovery
-----------------------------------

After a volatile test, power off both boards, set SW1 OFF/OFF, leave Tigard
**off**, and hold BTN2 before powering the ULX5M. Release BTN2 after the
primary DFU LED pattern appears. The USB read-only probe should show
``FWTN`` again. Power-cycle a second time with BTN2 **released** to
confirm automatic secondary boot and walking LEDs.

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
FINISH verification now advances incrementally and does not erase trailing
sectors. DNLOAD erase/page operations run in the foreground but still
synchronously poll flash WIP, which may delay USB servicing (4 KiB erase
can take up to 400 ms). Worst-case USB responsiveness, larger-image writes
and interrupted-update recovery remain unqualified. Documentation does not
authorize a destructive operation.

Troubleshooting
---------------

.. list-table:: Common symptoms
   :header-rows: 1
   :widths: 38 62

   * - Symptom
     - Check
   * - JTAG detection fails
     - SW1 ON/ON; cold-power both devices, try either power-up order; ground, 1.8 V I/O; IDCODE ``0x20000001``
   * - JTAG load succeeds but USB is absent
     - Check LEDs and BTN2 latch; if all LEDs are dark, cold-power both devices and reverse the power-up order; D4 ON, D3 OFF indicate DFU
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

USBView messages on Windows
~~~~~~~~~~~~~~~~~~~~~~~~~~~

With the board in DFU mode, open the supplied ``bin/usbview.exe`` on
Windows. When working in WSL, use this Windows utility rather than a
native Linux USB tool on the existing bench setup. A successful
DFU enumeration reports VID:PID ``1D50:614B``, product string
``ULX5M-GS FPGA (DFU Probe)``, Full Speed, configuration ``0x01`` and
interface class/subclass/protocol ``FE/01/02``.

The following USBView messages can be misleading:

* **Old ULX4M name:** Windows may retain the friendly name
  ``ULX4M-LS FPGA (DFU)`` for the shared VID:PID. Check the actual
  product string in the Device Descriptor rather than the tree label.
* **Open Pipes: 0 / No open pipes!:** expected for this DFU interface.
  All DFU requests use the default control endpoint EP0. There are no
  additional endpoints (``bNumEndpoints = 0``).
* **HID Descriptor with many descriptor entries:** USBView can mistake
  the DFU functional descriptor for a HID descriptor because both use
  type ``0x21``. The 64-byte DFU transfer size is then misinterpreted
  as 64 HID descriptor entries, and the tool can display unrelated
  bytes beyond the nine-byte descriptor. This is a USBView decoding
  problem, not evidence of a corrupt FPGA descriptor.

For the observed descriptor bytes ``09 21 09 00 00 40 00 10 01``,
correct DFU decoding gives ``bLength = 9``, ``bDescriptorType = 0x21``,
``bmAttributes = 0x09`` (download capable, device handles detach),
``wDetachTimeOut = 0``, ``wTransferSize = 64`` and
``bcdDFUVersion = 0x0110`` (DFU 1.1).

Do not change the firmware or reinstall the USB driver solely to eliminate
these messages. Enumeration alone does not prove flash update support or
identify the running firmware profile; use the read-only STATUS query above.
On native Ubuntu/Linux, use ``lsusb -v -d 1d50:614b`` in Bash to inspect
the descriptors instead (with appropriate USB permissions).

See Microsoft's `USBView source (DisplayHidDescriptor) <https://github.com/microsoft/Windows-driver-samples/blob/main/usb/usbview/display.c>`_
for the HID decoding implementation.

Qualification reference
-----------------------

.. list-table:: Reference configuration and image checksums
   :header-rows: 1
   :widths: 43 57

   * - Item
     - Value
   * - Golden persistent ``FWTN`` primary
     - 420,175 bytes; SHA-256 ``c41830bd09e0e924facd2425f10a8072878e59505d12b82aff533be7df8cfe27``
   * - Opt-in SRAM-tested ``FWTF`` v2d primary
     - 420,175 bytes; SHA-256 ``c73b8d6fe1ac1150ad3e3bba72c6d64664ee495185fade339f188f628dcfe167``
   * - Known-good native walking-LED secondary
     - 3,026 bytes; SHA-256 ``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``
   * - Two matching current pre-write 4 MiB backups
     - SHA-256 ``3aa6280fd96de3c00ef844a2f0298a919f7cea9311d5a267ee0be85bc4375c78``; ``../ulx5m-prewrite-readonly-20261030-FN1nVy/``
   * - Two matching post-write 4 MiB JTAG dumps
     - Same SHA-256; ``../ulx5m-postwrite-readonly-20261030-fiHyVE/``
   * - Routed full-image candidate
     - Seed 160; 25 MHz domain Fmax 67.96 MHz; 48 MHz domain Fmax 49.06 MHz

These checksums identify the validated seed-160/v2d reference configuration,
not arbitrary future builds. Both primary profiles use the same output
filename but have different contents. Verify SHA-256 before JTAG loading or
flash programming.

Related documentation
---------------------

* :doc:`index` - V005 pin configuration, power and bank-voltage cautions.
* :doc:`bringup` - dated physical testing and evidence.
* :doc:`multiboot-v72` - historical isolated secondary-boot experiment.
* :doc:`../../user-guide/bootloader` - ULX3S/ULX4M DFU documentation and
  older ULX5M development context; do not apply their flash addresses to V005.
