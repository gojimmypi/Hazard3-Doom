Video Pipeline
==============

Doom keeps its native indexed renderer. The project does not require the game to render a full RGB framebuffer in software.

Pipeline
--------

#. Doom renders a 320x200 8-bit indexed frame into internal SRAM.
#. Software stages a completed frame in the uncached video region.
#. FPGA logic transfers the frame into the inactive block-RAM video buffer.
#. The frame buffers swap on vertical blank.
#. A hardware palette converts the indexed pixels for HDMI scanout.

Output geometry
---------------

The documented 1024x600 output repeats each Doom pixel and scanline three times, producing a centered 960x600 image with 32-pixel black borders on the left and right.

Why indexed color?
------------------

Keeping the native indexed representation reduces software memory traffic and allows palette conversion to occur in dedicated FPGA logic.

Video registers
---------------

The HDMI/video control register block begins at:

.. code-block:: text

   0x4000C000
