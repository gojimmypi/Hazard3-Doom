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

Screen snip button remains disabled
-----------------------------------

Hover the disabled control and read its status text. The browser requires a
capability ACK from the firmware mode that currently owns UART input. The
resident monitor intentionally does not acknowledge the query. Launch updated
Doom or ``i2c gui``/``sao gui`` and hover the control again to force a new
probe.

If the screen is visibly Doom or the I2C GUI but the button remains disabled,
make sure the corresponding application was rebuilt with the capability handler
for raw query byte ``0x1c`` and ACK byte ``0x06``. Updating only ``web/app.js``
does not add firmware support.

In particular, an I2C GUI source that already handles ``0x1d`` screen capture
but lacks ``0x1c``/``0x06`` capability handling will remain disabled by design.
Merge the capability handler into that same current I2C GUI source rather than
replacing newer resolution/framebuffer work with an older screen-snip file.

Screen snip starts but times out
--------------------------------

A successful capability preflight is followed by raw request byte ``0x1d``.
The browser then waits up to 30 seconds for a valid ``H3SNIP1`` header and its
complete binary payload. Verify that no other terminal owns the UART and that
the serial connection remains at the expected baud rate.

At 115200 8-N-1, uncompressed captures are intentionally slow: approximately
5.6 seconds for ``320x200`` and 8.4 seconds for ``400x240`` before small protocol/software overhead. A pause in Doom or the GUI
during that transfer is expected.

Binary garbage appears in the terminal during screen snip
---------------------------------------------------------

The Web Serial application must consume exactly 256 palette bytes plus the
``pixel_bytes`` declared by the validated ``H3SNIP1`` header without passing
those bytes through the terminal ``TextDecoder``. Binary output in the terminal
usually indicates a mismatched web/firmware protocol revision or a malformed
header. Use matching ``web/app.js`` and firmware implementations and verify that
``palette_bytes`` is 256 and ``pixel_bytes`` equals
``source_width * source_height``.

See :doc:`user-guide/web-serial` for the full transport specification.
