APB Peripheral Address Map
==========================

Hazard3-Doom exposes its low-speed SoC peripherals through a 32-bit APB bus
behind the Hazard3 AHB-L system bus. CPU loads and stores in the
``0x40000000`` region pass through the AHB-to-APB bridge and are then decoded by
the APB splitter in ``third_party/Hazard3/example_soc/soc/example_soc.v``.

The addresses on this page are part of the Hazard3-Doom SoC integration. They
are not architectural RISC-V addresses and are not fixed by the Hazard3 CPU.

APB decoder windows
-------------------

The APB splitter currently exposes six slaves:

.. list-table::
   :header-rows: 1
   :widths: 20 20 20 40

   * - Peripheral
     - CPU base
     - Decoder window
     - RTL / software interface
   * - RISC-V timer
     - ``0x40000000``
     - ``0x40000000-0x40003FFF``
     - ``hazard3_riscv_timer.v``
   * - UART
     - ``0x40004000``
     - ``0x40004000-0x40007FFF``
     - ``uart_mini`` / ``uart_regs.v``
   * - GPIO
     - ``0x40008000``
     - ``0x40008000-0x40008FFF``
     - ``apb_gpio.v``
   * - SAO I2C/GPIO
     - ``0x40009000``
     - ``0x40009000-0x40009FFF``
     - ``apb_sao_bridge.v``
   * - micro-SD SPI
     - ``0x4000A000``
     - ``0x4000A000-0x4000AFFF``
     - ``apb_sd_spi.v``
   * - HDMI/video
     - ``0x4000C000``
     - ``0x4000C000-0x4000FFFF``
     - ``doom/hazard3_video.h`` and the HDMI APB block

The decoder windows are larger than the implemented register sets. Accessing a
word inside a decoded window does not imply that a register exists at that
address. Software should use only the documented offsets below.

The ``0x4000B000-0x4000BFFF`` range is not assigned to a peripheral by the
current APB splitter.

Common MMIO access
------------------

The standalone examples use a simple volatile 32-bit accessor:

.. code-block:: c

   #include <stdint.h>

   #define MMIO32(address) \
       (*(volatile uint32_t *)(uintptr_t)(address))

The shared example definitions are in
``examples/common/hazard3_apb.h``. Keeping the register addresses in one header
reduces the chance that individual examples drift away from the RTL map.

RISC-V timer - 0x40000000
-------------------------

The timer implements a 64-bit ``mtime`` counter and 64-bit ``mtimecmp`` compare
register over the 32-bit APB bus. Hazard3-Doom drives the timer with a one
microsecond tick, so ``mtime`` counts microseconds while the hart is running.
The timer stops advancing while the hart is debug-halted.

.. list-table::
   :header-rows: 1
   :widths: 18 20 22 40

   * - Offset
     - Address
     - Register
     - Description
   * - ``0x00``
     - ``0x40000000``
     - ``CTRL``
     - Bit 0 enables the timer. It resets enabled.
   * - ``0x08``
     - ``0x40000008``
     - ``MTIME``
     - ``mtime[31:0]``.
   * - ``0x0C``
     - ``0x4000000C``
     - ``MTIMEH``
     - ``mtime[63:32]``.
   * - ``0x10``
     - ``0x40000010``
     - ``MTIMECMP``
     - ``mtimecmp[31:0]``.
   * - ``0x14``
     - ``0x40000014``
     - ``MTIMECMPH``
     - ``mtimecmp[63:32]``.

Read a coherent 64-bit time value by checking that the high word did not change
around the low-word read:

.. code-block:: c

   static uint64_t timer_read_us(void)
   {
       uint32_t hi1;
       uint32_t lo;
       uint32_t hi2;

       do {
           hi1 = MMIO32(0x4000000cu);
           lo  = MMIO32(0x40000008u);
           hi2 = MMIO32(0x4000000cu);
       } while (hi1 != hi2);

       return ((uint64_t)hi1 << 32) | lo;
   }

When updating ``mtimecmp``, write the high word to ``0xFFFFFFFF`` first if a
spurious intermediate compare match would be harmful, then write the low word
and final high word.

UART - 0x40004000
-----------------

The UART is the Hazard3-libfpga ``uart_mini`` peripheral. It provides small TX
and RX FIFOs, a fractional divider, optional interrupts, CTS support, and
loopback.

.. list-table::
   :header-rows: 1
   :widths: 18 20 20 42

   * - Offset
     - Address
     - Register
     - Important fields
   * - ``0x00``
     - ``0x40004000``
     - ``CSR``
     - bit 0 EN, bit 1 BUSY, bit 2 TXIE, bit 3 RXIE, bit 4 CTSEN, bit 8 LOOPBACK.
   * - ``0x04``
     - ``0x40004004``
     - ``DIV``
     - bits 13:4 integer divider, bits 3:0 fractional divider.
   * - ``0x08``
     - ``0x40004008``
     - ``FSTAT``
     - TX level/full/empty/error and RX level/full/empty/error status.
   * - ``0x0C``
     - ``0x4000400C``
     - ``TX``
     - Writing bits 7:0 pushes one byte into the TX FIFO.
   * - ``0x10``
     - ``0x40004010``
     - ``RX``
     - Reading bits 7:0 returns and pops one RX byte.

``FSTAT`` uses these fields:

.. code-block:: text

    7:0   TXLEVEL
    8     TXFULL
    9     TXEMPTY
   10     TXOVER       sticky, write 1 to clear
   11     TXUNDER      sticky, write 1 to clear
   23:16  RXLEVEL
   24     RXFULL
   25     RXEMPTY
   26     RXOVER       sticky, write 1 to clear
   27     RXUNDER      sticky, write 1 to clear

With the normal 8x oversampling, the divider register is a fixed-point value
with four fractional bits:

.. code-block:: text

   baud ~= sys_clk / (8 * DIV)
   DIV_register = round((sys_clk * 16) / (baud * 8))

The currently generated ``uart_regs.v`` read path reports the reset divider
value rather than the programmed divider. Software should not use ``DIV``
readback to verify a baud-rate write in the current integration.

A minimal blocking transmit is:

.. code-block:: c

   #define UART_FSTAT   MMIO32(0x40004008u)
   #define UART_TX      MMIO32(0x4000400cu)
   #define UART_TXFULL  (1u << 8)

   static void uart_putc(char c)
   {
       while ((UART_FSTAT & UART_TXFULL) != 0u) {
       }
       UART_TX = (uint8_t)c;
   }

GPIO - 0x40008000
-----------------

The GPIO block currently contains one 8-bit output register.

.. list-table::
   :header-rows: 1
   :widths: 18 20 20 42

   * - Offset
     - Address
     - Register
     - Description
   * - ``0x00``
     - ``0x40008000``
     - ``GPIO_OUT``
     - Bits 7:0 drive ``gpio_out[7:0]``. Reads return the stored output value.

Only the low byte of a write is retained:

.. code-block:: c

   MMIO32(0x40008000u) = 0x55u;

The board wrapper determines what, if anything, each ``gpio_out`` bit drives on
a particular FPGA target.

SAO I2C/GPIO - 0x40009000
-------------------------

The SAO peripheral combines a software-driven I2C engine, two SAO GPIOs, raw
line status, identification registers, and ESP32/Hazard3 ownership status.

.. list-table::
   :header-rows: 1
   :widths: 18 20 22 40

   * - Offset
     - Address
     - Register
     - Description
   * - ``0x00``
     - ``0x40009000``
     - ``COMMAND``
     - Write a low-level I2C command.
   * - ``0x04``
     - ``0x40009004``
     - ``STATUS``
     - I2C result, line, GPIO, and ownership state.
   * - ``0x08``
     - ``0x40009008``
     - ``TXDATA``
     - Byte used by a WRITE command.
   * - ``0x0C``
     - ``0x4000900C``
     - ``RXDATA``
     - Last received byte.
   * - ``0x10``
     - ``0x40009010``
     - ``CLKDIV``
     - 16-bit I2C timing divider.
   * - ``0x14``
     - ``0x40009014``
     - ``TIMEOUT``
     - Clock-stretch timeout in system-clock cycles.
   * - ``0x18``
     - ``0x40009018``
     - ``GPIO``
     - SAO GPIO output/OE control plus synchronized input state.
   * - ``0x1C``
     - ``0x4000901C``
     - ``LINES``
     - Raw synchronized SDA, SCL, GPIO1, and GPIO2 input state.
   * - ``0x20``
     - ``0x40009020``
     - ``ID``
     - ``0x53414F31`` (ASCII ``SAO1``).
   * - ``0x24``
     - ``0x40009024``
     - ``VERSION``
     - Current bridge version, ``0x00020100`` for 2.1.0.
   * - ``0x28``
     - ``0x40009028``
     - ``OWNER``
     - bit 0 ESP owner, bit 1 ESP request.

``COMMAND`` values are:

.. code-block:: text

   1 START
   2 STOP
   3 WRITE
   4 READ_ACK
   5 READ_NACK
   6 RECOVER
   7 ABORT

``STATUS`` bits are:

.. code-block:: text

    0 BUSY
    1 DONE
    2 ACK
    3 NACK
    4 TIMEOUT
    5 REJECTED
    6 BUS_ACTIVE
    7 SDA
    8 SCL
    9 GPIO1
   10 GPIO2
   11 RECOVERED
   12 ESP_OWNER
   13 ESP_REQUEST

``DONE``, ``TIMEOUT``, ``REJECTED``, and ``RECOVERED`` are sticky. Writing a
one to the corresponding status bit clears that sticky flag.

The reset I2C divider is selected from the system clock so the normal target is
approximately 100 kHz. The reset clock-stretch timeout is 10 ms.

micro-SD SPI - 0x4000A000
-------------------------

The micro-SD peripheral is a small software-driven SPI mode-0 master. It is MSB
first and intentionally has no FIFO or DMA.

.. list-table::
   :header-rows: 1
   :widths: 18 20 22 40

   * - Offset
     - Address
     - Register
     - Description
   * - ``0x00``
     - ``0x4000A000``
     - ``CTRL``
     - bit 0 is ``CS_n``; 1 deselects the card.
   * - ``0x04``
     - ``0x4000A004``
     - ``CLKDIV``
     - 16-bit SPI half-period divider.
   * - ``0x08``
     - ``0x4000A008``
     - ``DATA``
     - Write low byte to start a transfer; read low byte for received data.
   * - ``0x0C``
     - ``0x4000A00C``
     - ``STATUS``
     - bit 0 BUSY.

The SPI clock is:

.. code-block:: text

   SCLK = sys_clk / (2 * (CLKDIV + 1))

At 50 MHz the reset divider of 124 produces a 200 kHz initialization clock.
The APB decoder slot exists even when ``SD_SPI_ENABLE`` is false; in that case
the disabled integration returns zero data and leaves the SD outputs inactive.

A byte transfer is:

.. code-block:: c

   static uint8_t sd_spi_xfer(uint8_t tx)
   {
       while ((MMIO32(0x4000a00cu) & 1u) != 0u) {
       }

       MMIO32(0x4000a008u) = tx;

       while ((MMIO32(0x4000a00cu) & 1u) != 0u) {
       }

       return (uint8_t)MMIO32(0x4000a008u);
   }

Do not start arbitrary transfers while another software component is using the
card or while validating shared ULX3S ESP32/FPGA SD ownership behavior.

HDMI/video - 0x4000C000
-----------------------

The video APB block controls and reports the HDMI/video path. Framebuffer pixel
memory is not stored in this APB window; framebuffers live in the external
memory video reservation documented in :doc:`../architecture/memory-map`.

.. list-table::
   :header-rows: 1
   :widths: 18 20 24 38

   * - Offset
     - Address
     - Register
     - Description
   * - ``0x00``
     - ``0x4000C000``
     - ``STATUS``
     - Video mode, framebuffer, DMA, and capability state.
   * - ``0x04``
     - ``0x4000C004``
     - ``CONTROL``
     - Indexed/buffer/present/direct/resolution controls.
   * - ``0x08``
     - ``0x4000C008``
     - ``PALETTE_INDEX``
     - Palette entry selector.
   * - ``0x0C``
     - ``0x4000C00C``
     - ``PALETTE_DATA``
     - Palette data.
   * - ``0x10``
     - ``0x4000C010``
     - ``FRAME_COUNT``
     - Frame counter.
   * - ``0x14``
     - ``0x4000C014``
     - ``DMA_CYCLES``
     - DMA-cycle diagnostic counter.
   * - ``0x18``
     - ``0x4000C018``
     - ``PRESENT_COUNT``
     - Completed present count.
   * - ``0x1C``
     - ``0x4000C01C``
     - ``FPGA_BUILD_ID``
     - Board/FPGA build identifier.
   * - ``0x20``
     - ``0x4000C020``
     - ``DDR_STATUS``
     - External-memory controller/adapter status.
   * - ``0x24``
     - ``0x4000C024``
     - ``DDR_CORE_BUILD_ID``
     - External-memory core build identifier.
   * - ``0x28``
     - ``0x4000C028``
     - ``DDR_ADAPTER_BUILD_ID``
     - Hazard3 memory adapter build identifier.
   * - ``0x2C``
     - ``0x4000C02C``
     - ``DIRECT_ADDRESS``
     - Direct video-write address/control.
   * - ``0x30``
     - ``0x4000C030``
     - ``DIRECT_DATA``
     - Direct video-write data.

Important ``STATUS`` bits are:

.. code-block:: text

    0 FRONT_BUFFER
    1 PRESENT_PENDING
    2 INDEXED
    3 VBLANK
    4 SDRAM_READY
    5 FRAME_VALID
    6 INTERNAL_BUFFER
    7 DMA_BUSY
    8 SWAP_PENDING
    9 DIRECT_SUPPORTED
   10 DIRECT_WRITE_BUSY
   11 HIGH_RES_SUPPORTED
   12 HIGH_RES_ACTIVE
   13 GUI_RES_SUPPORTED
   14 GUI_RES_ACTIVE

``CONTROL`` currently uses:

.. code-block:: text

   0 INDEXED
   1 BUFFER1
   2 PRESENT
   3 DIRECT
   4 HIGH_RES
   5 GUI_RES

Use ``doom/hazard3_video.h`` as the source of truth for the software-visible
video bits and the associated framebuffer layout.

Standalone APB examples
-----------------------

Two bare-metal examples are provided under ``examples/``. They do not link
against the resident monitor or Doom.

``examples/apb-register-dump``
   Initializes the UART and prints a non-destructive snapshot of all six APB
   peripherals. It does not start SAO or SD transactions, change GPIO outputs,
   or modify video state.

``examples/apb-uart-timer``
   Actively demonstrates the timer and UART. It enables the timer, reads
   ``mtime``, waits for one million microsecond ticks, reports the elapsed time,
   then enters a UART echo
   loop until ``q`` or ``Q`` is received.

Both examples share the register definitions and minimal startup code in
``examples/common/``. Each example can still be built independently.

Build the examples
^^^^^^^^^^^^^^^^^^

From Bash or WSL at the repository root:

.. code-block:: bash

   make -C examples

Or build one example:

.. code-block:: bash

   make -C examples/apb-register-dump
   make -C examples/apb-uart-timer

The default build assumes a 50 MHz Hazard3 system clock and 115200 baud. Override
the clock for a 40 MHz target such as the normal ULX4M-LD or ULX3S 12F
profile:

.. code-block:: bash

   make -C examples SYS_CLK_HZ=40000000

The makefiles follow the same toolchain conventions as the main project. They
honor ``TOOLCHAIN_PREFIX`` first, also accept ``CROSS_COMPILE``, recognize the
legacy ``/opt/riscv/bin/riscv32-unknown-elf-`` location, and otherwise use
``riscv-none-elf-*`` from ``PATH``. The normal full installer places the xPack
compiler on ``PATH``. A repo-local ``bin/riscv-gcc`` installation is retained
as a compatibility fallback. Windows ``.exe`` tools are detected automatically
when their path is visible from Bash/WSL; ``EXEEXT=.exe`` can also be set
explicitly.

Each example produces ``.elf``, ``.bin``, ``.map``, and disassembly ``.lst``
files in its local ``build/`` directory. Generated output is not intended to be
committed.

Run through OpenOCD/GDB
^^^^^^^^^^^^^^^^^^^^^^^

The standalone examples are linked at ``0x20100000``, the normal beginning of
the Doom executable window. This keeps them out of the resident monitor and
works with both the 32 MiB and 64 MiB software memory profiles.

The external memory controller must already be initialized. The simplest flow
is to boot the normal resident monitor, confirm external memory is ready, start
the normal Hazard3 OpenOCD session, and then connect GDB without resetting the
FPGA or hart.

For ``apb-register-dump``:

.. code-block:: text

   riscv-none-elf-gdb examples/apb-register-dump/build/apb-register-dump.elf
   (gdb) target extended-remote :3333
   (gdb) monitor halt
   (gdb) load
   (gdb) set $pc = _start
   (gdb) continue

Use the same sequence with the other example ELF. Because the examples replace
the normal executable at ``0x20100000``, upload or reload Doom again before
launching Doom afterward.

.. important::

   Do not issue a target reset immediately before loading one of these examples.
   A reset can return the system to a point before external SDRAM/DDR has been
   initialized, while these example ELFs execute from external memory.

Source-of-truth files
---------------------

When changing the SoC, verify this page and ``examples/common/hazard3_apb.h``
against the implementation files:

* ``third_party/Hazard3/example_soc/soc/example_soc.v`` - APB decoder.
* ``third_party/Hazard3/example_soc/soc/peri/hazard3_riscv_timer.v`` - timer.
* ``third_party/Hazard3/example_soc/libfpga/peris/uart/uart_regs.v`` - UART registers.
* ``third_party/Hazard3/example_soc/soc/apb_gpio.v`` - GPIO.
* ``third_party/Hazard3/example_soc/soc/apb_sao_bridge.v`` - SAO.
* ``third_party/Hazard3/example_soc/soc/apb_sd_spi.v`` - SD SPI.
* ``doom/hazard3_video.h`` - software-visible video register definitions.
