H3IMG executable image format
=============================

H3IMG is the packaged executable image format accepted by the Hazard3-Doom
resident monitor. Files use the ``.h3img`` extension. H3IMG contains a loadable
program image; the Doom IWAD (``DOOM.WAD``) is transferred separately.

This page describes the documented H3IMG container and loading interface.
The implementation is authoritative for header field offsets, checksums, and
validation limits. Do not generate files solely from the partial field list
below without checking the implementation in the matching release.

Container layout
----------------

An H3IMG file begins with a **64-byte binary header**, followed immediately by
the executable payload. The header describes where the payload is loaded, the
execution entry point, and the uninitialized memory area (BSS).

.. code-block:: text

   File offset
   0x0000       64-byte H3IMG header
   0x0040       Executable payload (length specified by header)
   ...          End of file

The format identifier is ``H3I1`` (ASCII bytes ``48 33 49 31``). When read as
a little-endian 32-bit integer its value is ``0x31493348``.

Header information
------------------

The following fields are used by the H3IMG packaging and loading workflow:

.. list-table::
   :header-rows: 1
   :widths: 28 72

   * - Field
     - Purpose
   * - Magic
     - Identifies the H3IMG format/version (``H3I1``).
   * - Load address
     - SDRAM address where the executable payload is copied.
   * - Payload size
     - Number of executable payload bytes following the header.
   * - Entry address
     - Execution address used when the loaded application is launched.
   * - BSS address
     - Start of the uninitialized data region.
   * - BSS size
     - Number of bytes of uninitialized data.
   * - Payload CRC32
     - Integrity check for the executable payload.

.. important::

   This field inventory is not yet a byte-offset specification. Exact field
   offsets, integer encoding for all fields, remaining header bytes, CRC32
   parameters, and range/alignment checks must be verified against the
   corresponding monitor and packager source before treating an independently
   generated image as compatible. In particular, do not assume that unused
   header bytes may have arbitrary values.

Memory and compatibility
------------------------

The monitor loads the image into the configured SDRAM address space. The
payload, BSS, and entry point must be valid for that monitor's memory map.
The project's ``32m`` and ``64m`` SDRAM profiles are distinct: build an image
for the target monitor profile. Loading an image does not itself start Doom.
The monitor's ``j`` command launches a successfully loaded application.

H3IMG is not an ELF container. The host build prepares the bytes to load and
packages them with the H3IMG header; ELF program headers, relocations, symbol
tables, and debugging information are not transmitted as H3IMG metadata.

UART upload (H3L)
-----------------

The browser Device Tool uses the resident monitor's H3L transfer sequence.
The monitor must be at its ``>`` command prompt before the transfer begins.

.. code-block:: text

   browser -> l
   monitor -> H3L READY
   browser -> 64-byte H3IMG header
   monitor -> H3L DATA
   browser -> executable payload
   monitor -> H3L OK

The browser validates the H3IMG header, overall package length, and payload
CRC32 before transmission. A successful transfer updates SDRAM, not the SD
card. The SD-card boot path can also load packaged H3IMG images.

For upload and execution instructions, see :doc:`../user-guide/web-tool`,
:doc:`../user-guide/monitor`, and :doc:`../user-guide/sd-card`.

Implementation references
-------------------------

For a specific repository revision, use the H3IMG constants and parsing code
in the resident monitor and the host-side H3IMG packaging and upload code as
the source of truth. The file-format version must be verified against the
selected monitor build; this page does not promise forward compatibility with
future header revisions.

* `Hazard3-Doom repository <https://github.com/ulx3s/Hazard3-Doom>`_
* `Development fork <https://github.com/gojimmypi/Hazard3-Doom/tree/develop>`_

