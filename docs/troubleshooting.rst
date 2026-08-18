Troubleshooting
===============

Doom upload times out
---------------------

* Exit Doom with ``Ctrl-X`` so the resident monitor is listening.
* Close PuTTY or any other program that owns the UART port.
* Confirm the selected COM/TTY device.
* Confirm that the monitor and uploader use the same memory profile.

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

OpenOCD cannot see a working Hazard3 debug module
-------------------------------------------------

* Reduce the JTAG clock.
* Ensure only one GDB client is attached.
* Verify the FPGA bitstream is the expected Hazard3 build.
* Verify the ELF matches the running hardware/monitor build.
* Distinguish ECP5 TAP connectivity from Hazard3 debug-module connectivity.

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
