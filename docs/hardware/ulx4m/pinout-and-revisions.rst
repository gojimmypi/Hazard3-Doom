Pin Constraints, Schematics, and Hardware Revisions
===================================================

A signal name becomes real hardware through a chain of artifacts. Understanding
that chain is one of the most transferable lessons in FPGA development.

From schematic net to Verilog port
----------------------------------

.. code-block:: text

   board schematic net
        |
        v
   PCB trace / FPGA package ball
        |
        v
   LPF LOCATE + IOBUF constraint
        |
        v
   top-level Verilog port
        |
        v
   project module / peripheral
        |
        v
   software-visible behavior

For example, an SD clock is not "the SD clock pin" because the Verilog signal is
named ``sd_clk``. It becomes the correct SD clock only when the matching LPF
maps that port to the package ball that the selected PCB revision routes to the
socket/carrier signal.

Hazard3-Doom constraint files
-----------------------------

Important project files include:

.. code-block:: text

   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.lpf
   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld_v002.lpf
   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ls.lpf
   bootloader/data/top-ulx4m-v002.lpf

The Doom SoC and the DFU bootloader are different FPGA designs, so they do not
necessarily expose the same top-level signal names even when they target the
same physical board.

The LD LPF contains much more than locations: it applies DDR3 SSTL I/O types,
termination/differential settings, oscillator frequency information, ordinary
LVCMOS constraints, and board-specific pin mappings. Treat it as executable
hardware documentation.

Revision discipline
-------------------

For ULX4M work, record at least four independent identities:

``Module variant``
   LS or LD.

``PCB revision``
   The revision printed on the board or established from manufacturing data.

``FPGA device``
   Full device/package/speed marking where possible.

``Memory population``
   Full SDR/DDR part marking where possible.

Two boards can both be called "ULX4M-LD" and still require different DDR3
profiles. Similarly, a pinout copied from an LS prototype file should not be
assumed correct for an LD revision.

Source conflicts are data
-------------------------

When two upstream sources disagree, do not hide the disagreement. Record it and
look for the reason: older revision, prototype versus production, alternate
BOM, branch mismatch, or documentation lag.

This project currently has a concrete example. The Crowd Supply page describes
a Micron ``MT41K512M16HA-125`` 1-GiB LD configuration, while an upstream LD
manual page lists ``MT41K256M16TW-107`` 512 MiB, and Hazard3-Doom additionally
supports an Alliance ``AS4C256M16D3`` profile. The correct build choice is the
part on the actual board, not whichever web page was opened first.

Using the local schematic copy
------------------------------

The repository includes a local ULX4M schematic PDF for development reference:

:download:`ULX4M schematics (local copy) <ULX4M-LS-v0.0.3.pdf>`

It also includes the Alliance DDR3 datasheet used during the alternate-memory
work:

:download:`Alliance AS4C256M16D3 datasheet (local copy) <../../AllianceMemory_4G_DDR3_AS4C256M16D3C_May2020_Rev1.1_Final.pdf>`

These files are useful references, but the branch/revision provenance still
matters. A PDF in the repository is not proof that every physical board matches
that schematic revision.

Checklist before changing a pin
-------------------------------

#. Identify the exact target board/revision.
#. Find the signal in the matching schematic.
#. Confirm the FPGA package ball and I/O bank.
#. Check the required voltage and I/O standard.
#. Update the correct LPF, not a similarly named prototype file.
#. Confirm the top-level Verilog port direction and width.
#. Build with warnings treated seriously.
#. Test the physical function on hardware.
#. If the change affects a shared bus, verify ownership and idle states.
#. Record the revision/profile used for the validation result.

That process is slower than copying a pin number from a forum post and much
faster than debugging an electrically impossible design later.
