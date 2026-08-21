Running Doom
============

UART loading
------------

The normal development flow sends a packaged ``.h3d`` executable to the resident monitor, then sends ``DOOM.WAD`` and launches the application.

The 64 MiB memory profile is the default for ULX3S 85F and ULX4M-LD 85F.

Controls
--------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Key
     - Action
   * - ``Esc``
     - Menu / back.
   * - ``W`` / ``S``
     - Forward/back or menu up/down.
   * - ``A`` / ``D``
     - Turn or adjust a menu value.
   * - ``Z`` / ``C``
     - Strafe left/right.
   * - ``F`` or ``Space``
     - Fire.
   * - ``E``
     - Use/open.
   * - ``M`` or ``Tab``
     - Automap.
   * - ``P``
     - Pause.
   * - ``1`` through ``7``
     - Select weapon.
   * - ``Enter``
     - Select.
   * - ``Ctrl-X``
     - Exit Doom and return to the resident monitor.

Video path
----------

Doom renders a 320x200 8-bit indexed working screen. The FPGA-side HDMI path presents the indexed frame through the hardware palette and scanout logic. See :doc:`../architecture/video` for the data path.

Web Serial screen snip
----------------------

When the browser console confirms screen-snip capability, Doom accepts the
reserved raw capture request and defers serialization until the next completed
``DG_DrawFrame()``. This avoids copying a framebuffer that Doom is still
modifying. Standard builds send a ``320x200`` indexed source. The optional
``400x240`` presentation build applies the same Doom source expansion used by
the HDMI path before transmitting the capture.

The browser receives the palette and indexed pixels, reconstructs the advertised
``1024x600`` HDMI raster, and downloads a PNG locally. See
:doc:`web-serial` for the capability handshake, ``H3SNIP1`` wire format, RGB332
palette encoding, transfer timing, and browser receive state machine.

Sound
-----

Sound is currently stubbed in the documented milestone.
