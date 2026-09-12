Troubleshooting
===============

Windows ``fujprog`` reports ``Cannot find JTAG cable``
------------------------------------------------------

On Windows, ``fujprog`` expects the ULX3S ``US1`` FT231X interface to use the
normal FTDI VCP/D2XX driver. If that interface was rebound to WinUSB for the
browser WebUSB flasher, or to another libusb driver for JTAG, restore the FTDI
driver in Device Manager before using Windows ``fujprog``.

Close OpenOCD, ``openFPGALoader``, and browser WebUSB sessions first, restore the
FTDI driver, unplug/reconnect ``US1``, and retry. See
:doc:`user-guide/web-flasher` for the driver compatibility table and restore
procedure.

.. _webusb-access-denied:

WebUSB flasher reports ``USBDevice.open(): Access denied``
----------------------------------------------------------

If the FPGA web flasher can see the ULX3S FTDI device but Windows rejects
``USBDevice.open()``, the problem occurs before JTAG begins. Direct WebUSB
access requires the ULX3S FT231X interface to use the WinUSB driver rather than
the normal FTDI VCP/D2XX driver.

#. Close ``fujprog``, OpenOCD, ``openFPGALoader``, and other programs that may own the FT231X.
#. Confirm that the selected device is the ULX3S ``US1`` FT231X.
#. Bind that interface to WinUSB, for example with Zadig.
#. Unplug and reconnect ``US1``.
#. Reload the web application and reconnect the flasher.

.. warning::

   Replacing the FTDI driver changes how Windows exposes that interface.
   Verify the selected device before changing its driver. Software that expects
   the normal FTDI VCP/D2XX driver will not use that interface until the FTDI
   driver is restored.

.. figure:: images/Zadig-FTDI-to-WinUSB.png
   :alt: Zadig replacing the ULX3S FTDI driver with WinUSB.
   :width: 580px

   Example ULX3S FT231X WinUSB selection.

See :doc:`user-guide/web-flasher` for the complete WebUSB programming flow
and driver restore notes.

WebUSB flasher reports an unrecognized JTAG ID
----------------------------------------------

Do not program until the physical ECP5 target is identified. Close other JTAG
software, unplug/reconnect ``US1``, reconnect the browser, and probe again. A
healthy ULX3S probe should identify a supported ECP5 such as ``LFE5U-12F`` or
``LFE5U-85F`` and display its 32-bit IDCODE.

The FT231X USB product string is not authoritative for the FPGA variant. Use
the ECP5 JTAG ID reported by **Probe JTAG** when deciding whether an image
matches the board.

WebUSB flasher reports an FPGA image target mismatch
-----------------------------------------------------

This is a safety check. The ECP5 target embedded in the selected ``.bit`` file
does not match the physical JTAG ID. Select or rebuild the bitstream for the
attached FPGA instead of bypassing the check.

.. _web-serial-no-compatible-devices:

Web Serial picker says no compatible devices found
---------------------------------------------------

If the browser opens the Web Serial chooser but reports ``No compatible
devices found`` even though Windows shows the COM port, check the browser
before changing hardware or USB serial drivers.

#. If Chrome shows ``Finish update``, ``Relaunch``, or another pending-update
   indicator, complete the update and fully restart Chrome. During
   Hazard3-Doom testing, Chrome still enumerated a CH340 adapter as ``COM7``
   in ``chrome://device-log`` while the Web Serial chooser remained empty.
   After the update was completed and Chrome was relaunched, the chooser
   worked again.
#. Retry **Connect**. The Hazard3-Doom web console intentionally requests the
   browser's serial-port picker without a USB VID/PID filter, so it is designed
   to work with any serial port the browser exposes.
#. Close PuTTY, upload scripts, IDE serial monitors, or other programs that may
   already own the port.
#. Open ``chrome://device-log``, enable the Serial and USB categories, and
   inspect whether the expected COM port was removed but never added again.
   During one verified debug session, Chrome logged ``Serial device removed:
   path=COM7`` and did not recover after OpenOCD was merely stopped, even though
   PuTTY could still open the port. Physically unplugging and reconnecting the
   external USB-UART adapter forced Windows/Chrome re-enumeration and restored
   the Web Serial chooser.
#. If debug activity preceded the failure, close PuTTY and other serial owners,
   stop OpenOCD, then physically disconnect/reconnect **the external USB-UART
   adapter**. Stopping OpenOCD alone may release its FT231X/JTAG handle without
   causing Chrome to rediscover the independent COM port.
#. After reconnecting, ``chrome://device-log`` should show both the USB device
   and a fresh ``Serial device added`` event for the expected COM port. Use
   **Connect** in the web UI to invoke the browser chooser.
#. Do not use ``navigator.serial.getPorts()`` as a complete Windows COM-port
   inventory. It returns only ports already authorized for the current browser
   origin. Use **Connect** to grant access to another port.

.. figure:: images/chrome-pending-update.png
   :alt: Chrome showing a Finish update button while the Hazard3-Doom UART Console is disconnected.
   :width: 520px

   If the Web Serial chooser is empty while Chrome shows a pending update,
   complete the update and relaunch before changing serial drivers.

Web Serial selects a Linux TTY but fails to open it
---------------------------------------------------

If Chrome can see and authorize a port such as ``USB2.0-Serial (ttyUSB1)`` but
``SerialPort.open()`` fails, separate browser authorization from Linux device
permissions.

Check the device node, current login groups, and current owner:

.. code-block:: bash

   ls -l /dev/ttyUSB1
   groups
   fuser -v /dev/ttyUSB1

A common Ubuntu result is:

.. code-block:: text

   crw-rw---- 1 root dialout ... /dev/ttyUSB1

If ``dialout`` owns the device but is missing from ``groups``, add the user:

.. code-block:: bash

   sudo usermod -aG dialout "$USER"

The change applies to a **new login session**. ``groups`` in an existing desktop
session will not change just because ``usermod`` succeeded, and an already
running Chrome process keeps the old supplementary groups.

For a temporary diagnostic that does not require a reboot, logout, or USB
reconnect, grant the current user an ACL on the existing device node:

.. code-block:: bash

   sudo setfacl -m u:"$USER":rw /dev/ttyUSB1

Replace ``ttyUSB1`` with the actual port. This ACL may disappear when the device
is re-enumerated; ``dialout`` membership remains the normal persistent fix.
``newgrp dialout`` can create a shell with the new group immediately, but it does
not change an already-running desktop or Chrome process.

If permissions are correct but open still fails, check whether another process
owns the port with ``fuser``. Ubuntu's ModemManager can also probe USB serial
adapters. Temporarily stop it for diagnosis with:

.. code-block:: bash

   sudo systemctl stop ModemManager

Disable ModemManager permanently only on a system where its modem functionality
is intentionally not needed.

UART output is readable but the monitor ignores commands
--------------------------------------------------------

Readable boot text at ``115200 8N1`` proves the FPGA transmit path and baud rate,
but it does **not** prove the opposite UART direction. If the monitor prints a
clean banner and ``>`` prompt but ``h`` or ``?`` receives no response, inspect
the adapter TX-to-FPGA-RX path first. A loose jumper can create exactly this
one-way symptom.

The project-tested ULX3S wiring is:

.. code-block:: text

   adapter TX  -> ULX3S J1 pin 8 / GP1 / Hazard3 RxD
   adapter RX  <- ULX3S J1 pin 6 / GP0 / Hazard3 TxD
   adapter GND -> ULX3S GND

See :doc:`hardware/ulx3s/interfaces` for the board interface description.

To distinguish browser behavior from the physical UART, disconnect Web Serial so
it releases the port, then test directly on Linux:

.. code-block:: bash

   stty -F /dev/ttyUSB1 \
       115200 cs8 -cstopb -parenb \
       -ixon -ixoff -crtscts raw -echo

   # In one terminal:
   cat /dev/ttyUSB1

   # In another terminal, send the monitor's one-byte help command:
   printf 'h' > /dev/ttyUSB1

If boot output is clean but this command still produces no response, focus on the
adapter TX wire, connector seating, ground, and FPGA RX pin rather than changing
OpenOCD or the baud rate.

WebUSB cannot open or claim the ULX3S
------------------------------------

On Linux, the Hazard3-Doom Device Tool may be able to detect the ULX3S but
still fail to open it.

Two common errors are:

``Access denied``
   The browser does not have read/write permission for the raw USB device.

``Unable to claim interface``
   The Linux ``ftdi_sio`` driver already owns the FT231X USB interface.

See :doc:`user-guide/web-flasher` for the Linux udev permission setup and
the procedure for temporarily releasing the ULX3S interface from
``ftdi_sio``.

When using a virtual machine, also verify that the ULX3S USB device is
connected to the guest operating system rather than the host.

Doom upload times out
---------------------

* Exit Doom with ``Ctrl-X`` so the resident monitor is listening.
* Close PuTTY or any other program that owns the UART port.
* Confirm the selected COM/TTY device.
* Confirm that the monitor and uploader use the same memory profile.

No micro-SD card is installed, but cold boot reports CMD0 failure
-----------------------------------------------------------------

This is expected. The resident monitor tries the micro-SD cold-boot path before
returning to the interactive prompt. With no card installed, output may include:

.. code-block:: text

   ULX3S cold boot: trying micro-SD...
   SD boot: initializing micro-SD...
   SD: CMD0 failed r1=0x000000FF
   SD boot: card initialization failed
   Type h or ? for help.
   >

If SDRAM/video diagnostics passed and the ``>`` prompt appears, the missing-card
message is not a system failure.

SD card mounts but files are not found
--------------------------------------

* Use root filenames ``DOOM.H3D`` and ``DOOM.WAD``.
* Confirm FAT16/FAT32 formatting.
* Use the monitor ``c`` command to inspect FAT type, mount state, and discovered file sizes.
* Avoid relying on long filenames; the boot path is designed around root 8.3 names.

SD becomes unreliable when ESP32 firmware runs
----------------------------------------------

Confirm that ESP32 GPIO 14, 15, 2, and 13 are high-impedance while Hazard3 owns the SD bus. A firmware ownership flag is insufficient if the ESP32 pin drivers remain enabled.

SAO scan finds some devices but not others
------------------------------------------

Not every SAO is necessarily an I2C peripheral. Some devices may use the optional GPIO pins or unusual I2C behavior. Use ``sao info``, ``sao scan``, ``sao probe``, and device-specific documentation before assuming the bridge is faulty.

``i2c gui`` is reported as an unknown command
-----------------------------------------------

The board is running an older resident monitor. Building a new ELF does not
replace the firmware already executing in Hazard3. Rebuild and load the monitor
explicitly:

.. code-block:: bash

   ./scripts/build.sh
   ./scripts/load-firmware.sh ./build/hazard3-boot-monitor.elf

After loading, monitor help should list both ``sao gui`` and ``i2c gui``.

I2C GUI scan finds a device but logical trace is blank
------------------------------------------------------

Older revisions of the HDMI GUI cleared the logical trace at the end of
``S`` scan. Current code retains the probe trace for the last ACKing address.
Rebuild/reload the current monitor if the heatmap updates but the scan trace
remains empty. ``P`` on a known address is also a direct check of the logical
trace renderer.

I2C GUI remains on HDMI after exit
----------------------------------

This is expected with the current software. Exiting restores UART monitor
control and the 100-kHz SAO bus rate, but does not reconstruct the frame that
was visible before the GUI started. Launch Doom or present another monitor
video frame to replace the last analyzer image.

``shellcheck`` is not installed
-------------------------------

Project shell scripts are expected to pass ShellCheck. On Ubuntu/WSL, install it with:

.. code-block:: bash

   sudo apt-get install shellcheck

For a broader host check, run ``./scripts/requirements-check.sh``.


Missing required executable: /opt/riscv/bin/riscv32-unknown-elf-gcc
-------------------------------------------------------------------

The monitor build defaults to the ``/opt/riscv/bin/riscv32-unknown-elf-`` prefix.
If your RISC-V toolchain uses another prefix, set ``TOOLCHAIN_PREFIX`` explicitly.
For example, an xPack installation commonly uses:

.. code-block:: bash

   TOOLCHAIN_PREFIX=riscv-none-elf- ./scripts/build.sh

Run ``./scripts/requirements-check.sh`` to detect common RISC-V toolchain prefixes
and verify that the compiler accepts the Hazard3 ISA/ABI options.

c++: fatal error: Killed signal terminated program cc1plus
----------------------------------------------------------

This almost always means the Ubuntu VM ran out of available RAM and the kernel's
OOM killer terminated one of the C++ compiler processes. It is not a C++ compile error.
Increase the VM memory or swap allocation, or reduce build parallelism before retrying.

Workflow reports that CMake is too old
--------------------------------------

The machine requirements checker treats CMake as an optional development tool.
If a particular workflow requires a newer version, install or upgrade CMake to
the version requested by that workflow, then verify with ``cmake --version``.

See the ``install-cmake.sh`` script in the ``scripts/`` directory to
install CMake 3.25 or higher.

ROR: Max frequency for clock '$glbnet$clk_sys': XX.YY MHz (FAIL at 50 MHz)
--------------------------------------------------------------------------

If the routed frequency is below the target when using the default seeds, first
confirm that Yosys and nextpnr match the versions recorded with the authoritative
routing defaults in ``scripts/build-ecp5-bitstream-common.sh``. Routing seeds are
tool-version-specific.

Record the local versions with:

.. code-block:: text

   yosys --version
   nextpnr-ecp5 --version
   ecppack --version



Console firmware uploader remains on ``Loading...``
---------------------------------------------------

The browser console firmware uploader does not start OpenOCD. Three pieces must
be running at the same time:

.. code-block:: text

   browser -> web-server.py -> GDB -> OpenOCD :3333 -> Hazard3

Start OpenOCD in one terminal and leave it running:

.. code-block:: bash

   ./scripts/start-openocd.sh

A usable session reaches both ``Examined RISC-V core`` and ``Listening on port
3333 for gdb connections``. In another terminal start:

.. code-block:: bash

   python3 web/web-server.py

Open ``http://127.0.0.1:8000/``. Do not use a ``file://`` URL for
``web/index.html``. The web page's **Local loader Ready** state means the local
HTTP helper is reachable; OpenOCD must still be running separately. During a
normal batch load, OpenOCD may log an accepted GDB connection followed by a
``dropped 'gdb' connection`` when the loader disconnects after resuming the
core.

Useful checks are:

.. code-block:: bash

   ss -ltnp | grep ':3333'
   curl http://127.0.0.1:8000/api/console-firmware/status

Also disconnect the browser FPGA web flasher from ``US1`` before OpenOCD starts,
because both use the same FT231X JTAG interface. The external J1 USB-UART adapter
is separate and may remain connected.

OpenOCD reports USB timeout or an all-zero JTAG scan in a VM
------------------------------------------------------------

VM USB passthrough can occasionally produce an initial message such as
``LIBUSB_ERROR_TIMEOUT`` followed by ``JTAG scan chain interrogation failed: all
zeroes``. Read the later OpenOCD state before deciding that the session failed.
If it subsequently reports:

.. code-block:: text

   Examined RISC-V core; found 1 harts
   Listening on port 3333 for gdb connections

then GDB can use the server. Stop and immediately restart OpenOCD once to confirm
that the scan is clean. If OpenOCD never finds the ECP5 TAP or Hazard3 core,
verify VMware USB attachment to the guest, close the browser WebUSB FPGA flasher,
and check for another JTAG owner before changing clocks or RTL.

OpenOCD cannot see a working Hazard3 debug module
-------------------------------------------------

* On Windows ULX3S, use a current OpenOCD build with ``ft232r`` support and bind
  the on-board FT231X to **WinUSB** or **libusbK**. The current project setup
  has been verified with WinUSB; libusbK is not mandatory.
* Do not confuse the ULX3S ``US1`` FT231X/JTAG driver with the separate external
  USB-UART COM-port driver used by Web Serial.
* On ULX4M-LD with Tigard, keep Interface 0 on the FTDI VCP driver for UART and
  Interface 1 on libusbK for JTAG. OpenOCD uses ``ftdi channel 1``.
* On ULX4M-LD, the correct LFE5UM-85F IDCODE is ``0x01113043``. If OpenOCD reads
  that IDCODE but reports ``dtmcontrol is 0``, the physical JTAG path is alive;
  verify that the user bitstream has left DFU and is actually running before
  changing DTM RTL or wiring.
* The established Tigard wiring has no target reset wire connected. Do not rely
  on SRST/TRST to start the FPGA design.
* Reduce the JTAG clock only after checking the active bitstream and driver
  binding.
* Ensure only one GDB client is attached.
* Verify the FPGA bitstream is the expected Hazard3 build.
* Verify the ELF matches the running hardware/monitor build.
* Distinguish ECP5 TAP connectivity from Hazard3 debug-module connectivity.

If the same ULX3S FT231X also needs the browser FPGA flasher, prefer WinUSB so
both OpenOCD/GDB and WebUSB work without another driver swap. Restore the FTDI
VCP/D2XX driver only when a tool such as Windows ``fujprog`` requires it.

ULX4M-LD reports external-memory TIMEOUT
----------------------------------------

The current monitor's initial 5-second wait can expire before LiteDRAM finishes
calibration. Do not treat the banner ``TIMEOUT`` as a final failure by itself.
Run ``s`` and check the live state. A usable DDR state includes:

.. code-block:: text

   external_memory_ready=YES
   init_done=YES
   init_error=NO
   pll_locked=YES
   user_clock_ready=YES
   ready=YES

If those fields are ready, run ``q``. The qualified 40/60 MHz ULX4M-LD route
has passed the complete SDRAM suite repeatedly, plus ``k``, ``d``, and ``x``.

Build suddenly changes because of submodules
--------------------------------------------

Check both the superproject and submodule state:

.. code-block:: bash

   git status
   git submodule status --recursive
   git branch --show-current
   git -C third_party/Hazard3 branch --show-current
   git -C third_party/doomgeneric branch --show-current

A clean superproject does not imply that a submodule is on the branch or commit you expected.

Related links
-------------

* `RISC-V GCC XPACK <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_
