Video Pipeline
==============

Doom keeps its native indexed renderer. The project does not require the game to render a full RGB framebuffer in software.

Pipeline
--------

#. Doom renders a 320x200 8-bit indexed frame into the project screen buffer.
#. Software writes the completed indexed frame into the inactive internal EBR
   framebuffer through the direct video register path.
#. The internal frame buffers swap on vertical blank.
#. A hardware palette converts the indexed pixels for HDMI scanout.

Output geometry
---------------

The documented 1024x600 output scales Doom's native 320x200 indexed frame to the full panel. Vertical scaling is exactly 3x (200 to 600 lines), while horizontal scaling is fractional so all 1024 output pixels are used.

Why indexed color?
------------------

Keeping the native indexed representation reduces software memory traffic and allows palette conversion to occur in dedicated FPGA logic.

Video registers
---------------

The HDMI/video control register block begins at:

.. code-block:: text

   0x4000C000


Non-Doom users of the video path
--------------------------------

The resident monitor can also use the direct indexed EBR path for diagnostics.
The :doc:`../user-guide/i2cdriver` interface renders its own 320x200 indexed
screen, writes the inactive internal framebuffer, and requests a vertical-blank
swap without modifying DoomGeneric.
