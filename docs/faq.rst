Frequently Asked Questions
==========================

Web Serial reports no compatible devices, but Windows sees my COM port. What should I try first?
--------------------------------------------------------------------------------------------------

If Chrome shows a pending browser update, complete the update and fully relaunch
Chrome before changing USB serial drivers or modifying the Hazard3-Doom web
console.

See the browser update indicator below:

.. image:: images/chrome-pending-update.png
   :alt: Chrome pending update indicator
   :align: center

During Hazard3-Doom testing on Windows, Chrome's internal device log still
reported the CH340 adapter as ``COM7``, but the Web Serial chooser displayed
``No compatible devices found``. After the pending Chrome update was completed and Chrome was relaunched,
the serial-port chooser worked again.

The Hazard3-Doom web console intentionally requests an unfiltered serial-port
picker, so it is not limited to CH340, FTDI, CP210x, or another specific USB
serial adapter.

Also remember that ``navigator.serial.getPorts()`` returns ports that the
current browser origin has already been authorized to use. It is not a list of
every COM port installed in Windows.

If relaunching the updated browser does not restore the port, continue with
:ref:`web-serial-no-compatible-devices`. In particular, if Chrome logged that
the COM port was removed during a debug session, physically unplug/reconnect the
external USB-UART adapter. Stopping OpenOCD alone may not trigger the Windows /
Chrome serial-device re-enumeration needed to make the port selectable again.

Can OpenOCD use WinUSB on the ULX3S?
------------------------------------

Yes, with the current Hazard3-Doom ULX3S setup. The project's OpenOCD path uses
the ``ft232r`` adapter through libusb and has been verified with the on-board
FT231X bound to WinUSB. libusbK also works for OpenOCD, but is no longer a
mandatory driver choice. GDB connects to OpenOCD over TCP and therefore works
through whichever FT231X binding OpenOCD successfully uses.

WinUSB is especially convenient because it also satisfies the browser WebUSB
FPGA/JTAG flasher. The normal FTDI VCP/D2XX driver is still needed by FTDI-native
applications such as Windows ``fujprog``. See :doc:`user-guide/web-flasher` for
the compatibility matrix.

Why does the FPGA WebUSB flasher need WinUSB on Windows?
--------------------------------------------------------

The ULX3S ``US1`` FT231X normally uses an FTDI Windows driver. Chrome/Edge
WebUSB cannot open that interface through the normal FTDI VCP/D2XX binding, so
the browser programmer requires WinUSB for direct USB access. This affects only
the WebUSB/JTAG path; a separate USB-to-UART adapter can continue to serve the
Hazard3-Doom Web Serial console.

See :doc:`user-guide/web-flasher` for setup and driver restore instructions, or
:ref:`webusb-access-denied` if the browser reports ``Access denied``.

