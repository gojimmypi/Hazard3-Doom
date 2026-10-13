Benchmarking Hazard3 with CoreMark
==================================

CoreMark runs as a standalone bare-metal program. It replaces the monitor in
internal SRAM and prints results over UART. It does not use the Doom H3IMG
loader or measure Doom's SDRAM, cache, or framebuffer performance.

Requirements
------------

* Program a matching Hazard3 bitstream before loading the ELF.
* Use the ULX3S-85F design with 128 KiB of internal SRAM. The linker script
  ``benchmarks/coremark/link.ld`` places code, data, and stack in
  ``0x00000000-0x0001FFFF``, with vectors at ``0x00000040``.
* The compiled ISA is ``rv32imc_zicsr_zifencei_zba_zbb_zbs``, ABI ``ilp32``.
  The running CPU must implement the instructions used by the ELF.
* Match ``HAZARD3_SYS_CLK_HZ`` to the running FPGA clock. The build script
  accepts ``25000000`` or ``50000000``; the default is ``50000000``.
* Initialize the Hazard3 submodule and install a compatible RISC-V GCC/GDB
  toolchain, Python 3, and OpenOCD. See :doc:`../getting-started/prerequisites`.
* Connect the external UART at 115200 baud, 8 data bits, no parity, 1 stop bit,
  and no flow control. See :doc:`pinouts` for wiring.

The compact ULX3S-12F design has only 1 KiB of bootstrap SRAM. The stock
CoreMark ELF does not fit that memory layout. Other boards require verification
of SRAM capacity, ISA, clock, and peripheral addresses before using this port.
A 40 MHz target also requires changes to the build script's accepted clock
values; setting an environment variable alone is insufficient.

Build
-----

Run commands from the repository root in Bash (WSL on Windows):

.. code-block:: bash

   ./scripts/build-coremark.sh

The default build uses 3000 iterations and creates both run images:

.. code-block:: text

   build/coremark/baseline/coremark-performance.elf
   build/coremark/baseline/coremark-validation.elf

``baseline`` and ``tuned`` are compiler optimization profiles. ``performance``
and ``validation`` are benchmark seed configurations; both must pass validation.
To build the tuned profile:

.. code-block:: bash

   COREMARK_BUILD_PROFILE=tuned ./scripts/build-coremark.sh

The output directory becomes ``build/coremark/tuned/``. The build checks the
CoreMark workload sources against the checked-out Hazard3 commit and compares
ELF ISA attributes with a reference object compiled using the requested ISA.
It writes ``build-info.txt``, ``source-integrity.json``, and per-image
``.map``, ``.isa.txt``, and ``.isa.json`` files beside the ELFs. An ISA-attribute
PASS checks the build; it does not prove that the active bitstream is compatible.

Load and run
------------

Start OpenOCD in a separate terminal and leave it running:

.. code-block:: bash

   ./scripts/start-openocd.sh ulx3s-85f

Wait for OpenOCD to examine the RISC-V hart and listen on port 3333. Disconnect
other GDB clients, including VisualGDB. See :doc:`jtag-debugging` for USB drivers
and adapter setup.

For manual UART capture, open the serial terminal before loading, then run:

.. code-block:: bash

   ./scripts/load-firmware.sh ./build/coremark/baseline/coremark-performance.elf

The loader halts, loads and compares sections, sets ``$pc`` to ``_start``,
resumes, and disconnects. CoreMark starts immediately; no monitor command is
required. For the validation image:

.. code-block:: bash

   ./scripts/load-firmware.sh ./build/coremark/baseline/coremark-validation.elf

For other standalone applications, see :ref:`load-custom-elf`.

Automated capture and qualification
-----------------------------------

Install ``pyserial`` in the Python environment used by the runner. Close other
applications using the UART, then run:

.. code-block:: bash

   ./scripts/run-coremark.sh performance /dev/ttyS7
   ./scripts/run-coremark.sh validation /dev/ttyS7
   ./scripts/run-coremark.sh qualify /dev/ttyS7

Replace ``/dev/ttyS7`` with the UART device accessible to that Python environment.
``qualify`` loads the performance image followed by the validation image and
reports ``RESULT : VALID`` only when both runs pass. OpenOCD must already be
running. Without a serial-port argument, ``performance`` and ``validation``
only load the ELF for manual capture; ``qualify`` requires a serial port.

The runner creates missing build outputs but does not rebuild existing ELFs
just because clock, iteration, or compiler settings changed. Rebuild explicitly
when changing those settings. Use the same clock and build profile for build
and capture, for example on a 25 MHz bitstream:

.. code-block:: bash

   HAZARD3_SYS_CLK_HZ=25000000 COREMARK_BUILD_PROFILE=tuned ./scripts/build-coremark.sh
   HAZARD3_SYS_CLK_HZ=25000000 COREMARK_BUILD_PROFILE=tuned ./scripts/run-coremark.sh qualify /dev/ttyS7

Results
-------

Successful UART output includes:

.. code-block:: text

   Correct operation validated. See README.md for run and reporting rules.
   Hazard3 counters:
      cycles       = ...
      instructions = ...
   COREMARK_DONE

The host summary calculates elapsed seconds, CoreMark/s, CoreMark/MHz, and
cycles per retired instruction from the full 64-bit counters. Use these values
for comparisons. With ``HAS_FLOAT=0``, the standard target-side time and rate
fields use integer seconds and lose precision.

Each run must last at least 10 seconds. If either run is shorter, increase the
iteration count, rebuild, and repeat qualification:

.. code-block:: bash

   COREMARK_ITERATIONS=4000 ./scripts/build-coremark.sh
   ./scripts/run-coremark.sh qualify /dev/ttyS7

The runner saves ``coremark-<run>.run.log`` and
``coremark-<run>.result.json`` beside the ELF. Retain these files, build metadata,
ELF hash, memory report, FPGA configuration, and actual CPU clock with results.
See ``benchmarks/coremark/README.md`` for counter and qualification details.

Troubleshooting and monitor recovery
------------------------------------

* No UART output: check wiring, serial-port ownership, 115200 8N1, CPU clock,
  and whether GDB resumed the CPU.
* Illegal instruction or ISA failure: check the active bitstream against the
  ELF ISA. Rebuild for supported instructions or program a matching bitstream.
* Load or comparison failure: check the ELF memory layout, OpenOCD board
  configuration, and available RAM. Do not load this 128 KiB SRAM image into
  the compact 12F design.
* Incorrect elapsed time or rate: use the actual FPGA CPU clock for both build
  and runner. Software settings do not change the FPGA clock.
* Timeout: check UART output and loader completion. The Python runner defaults
  to a 120-second timeout, including the load operation.

To restore the ULX3S-85F monitor after the benchmark, use its board-specific
ELF while OpenOCD remains running:

.. code-block:: bash

   ./scripts/load-firmware.sh ./build/ulx3s-85f/monitor/hazard3-boot-monitor.elf

This reloads the monitor into RAM. It does not program the FPGA or SPI flash.
