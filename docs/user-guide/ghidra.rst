Ghidra static analysis
======================

The project includes a Ghidra extension for inspecting Hazard3-Doom H3IMG
executables. It provides an H3IMG loader and an analyzer for project-specific
memory-mapped I/O (MMIO) registers. Ghidra performs static analysis; it does
not run the FPGA, monitor, or Doom application.

Source and requirements
-----------------------

The extension source and build instructions are in
`ghidra/Hazard3H3IMG <https://github.com/ulx3s/Hazard3-Doom/tree/main/ghidra/Hazard3H3IMG>`_.
See its ``README.md`` for the supported Ghidra and Java versions, Gradle build
commands, installation procedure, and extension-specific options. Use an
extension built for the installed Ghidra version.

Input files
-----------

Use the packaged ``.h3img`` application image produced by the matching project
build. An H3IMG file has a 64-byte header followed by the loadable payload.
The header supplies the load address, entry address, payload length, and BSS
range. See :doc:`../reference/h3img-format` for the format description.

An H3IMG file is not an ELF file and does not contain ELF symbols or DWARF
debug information. For source-level symbol analysis, retain the corresponding
ELF from the same build. Do not assume addresses or binaries from different
build profiles are interchangeable.

Import an H3IMG image
---------------------

1. Install the Hazard3H3IMG extension according to its ``README.md`` and
   restart Ghidra if required.
2. Create or open a Ghidra project.
3. Select **File > Import File** and choose the ``.h3img`` file.
4. Select the H3IMG loader if it is not selected automatically. Verify the
   detected RISC-V language and memory layout before completing the import.
5. Open the imported program in CodeBrowser and run analysis.
6. Check the entry address, loaded image region, and BSS memory block against
   the H3IMG header.

The loader uses the header to place the payload at its runtime address. It
represents BSS as uninitialized memory for analysis; it does not execute the
monitor or clear BSS at runtime.

MMIO register analysis
----------------------

The MMIO analyzer adds address ranges and register names for the project's
peripherals. Verify that the analyzer is enabled in the analysis options for
the imported program. Its symbols can help identify UART, video, and other
peripheral accesses.

A register label is not proof that Ghidra resolved every access to that
address. RISC-V code may construct addresses using multiple instructions
(for example, ``lui`` followed by an addition or store). Computed and
indirect accesses may require manual inspection and references.

For the register addresses and bit definitions, see
:doc:`../reference/apb-peripherals` and :doc:`../architecture/memory-map`.

Limitations
-----------

* Static analysis does not display runtime register contents or framebuffer
  updates. Use :doc:`jtag-debugging` for live target debugging.
* The extension does not convert the H3IMG payload into an ELF file or recover
  symbols that are absent from the package.
* MMIO names and addresses must match the FPGA design being analyzed. Check
  the selected board and firmware revision if they differ.
* An H3IMG payload contains the executable image, not the separate Doom IWAD.
