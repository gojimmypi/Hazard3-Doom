ISA and Configuration
=====================

Hazard3 is highly parameterized. It is important to distinguish three things:

#. what the Hazard3 RTL is capable of implementing;
#. what the generic configuration defaults are; and
#. what the ULX3S Hazard3-Doom wrapper actually selects.

The authoritative pinned parameter list is
`hazard3_config.vh <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_config.vh>`_. The selected ULX3S values
are in `fpga_ulx3s.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/fpga/fpga_ulx3s.v>`_.

Project ISA profile
-------------------

The effective project profile is an RV32I base with selected standard
extensions:

.. list-table::
   :header-rows: 1
   :widths: 18 22 16 44

   * - ISA feature
     - Hazard3 parameter
     - Project
     - Purpose
   * - RV32I
     - ``EXTENSION_E=0``
     - Enabled
     - Full 32-register 32-bit integer base ISA.
   * - M
     - ``EXTENSION_M``
     - Enabled
     - Integer multiply/divide/remainder.
   * - A
     - ``EXTENSION_A``
     - Disabled
     - Atomic memory operations are deliberately absent from this build.
   * - C
     - ``EXTENSION_C``
     - Enabled
     - 16-bit compressed instruction encodings.
   * - Zba
     - ``EXTENSION_ZBA``
     - Enabled
     - Address-generation operations such as scaled-add forms.
   * - Zbb
     - ``EXTENSION_ZBB``
     - Enabled
     - Basic bit-manipulation operations.
   * - Zbs
     - ``EXTENSION_ZBS``
     - Enabled
     - Single-bit set/clear/invert/extract operations.
   * - Zifencei
     - ``EXTENSION_ZIFENCEI``
     - Enabled
     - ``fence.i`` instruction-fetch synchronization.
   * - Zbc
     - ``EXTENSION_ZBC``
     - Disabled
     - Carry-less multiplication not synthesized.
   * - Zbkb
     - ``EXTENSION_ZBKB``
     - Disabled
     - Scalar-crypto-oriented basic bit operations not synthesized.
   * - Zbkx
     - ``EXTENSION_ZBKX``
     - Disabled by default
     - Crossbar permutation subset not selected by the wrapper.
   * - Zcb / Zclsd / Zcmp
     - matching parameters
     - Disabled by default
     - Additional compressed instruction subsets not selected.
   * - Zilsd
     - ``EXTENSION_ZILSD``
     - Disabled by default
     - Load/store pair extension not selected.

``Zicsr`` behavior is present because the machine CSR blocks needed by this
SoC are enabled. ``CSR_COUNTER=1`` enables performance counters and the Zicntr
CSR implementation in this Hazard3 snapshot. User mode itself remains disabled
in this project.

How configuration reaches the core
----------------------------------

Hazard3 keeps its configuration parameters in one shared include file and
propagates them down the hierarchy using ``hazard3_config_inst.vh``. This is a
clean educational pattern for configurable RTL: the top-level integrator can
change a feature without editing individual pipeline modules.

A simplified view is:

.. code-block:: text

   fpga_ulx3s.v
       sets feature/performance parameters
              |
              v
   example_soc.v
              |
              v
   hazard3_cpu_1port.v
              |
              v
   hazard3_core.v + decoder/CSR/ALU/front end

The decoder then uses these parameters to make unsupported instruction
encodings illegal. See
`hazard3_decode.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_decode.v>`_ for extension-gated decode.
For example, the M-extension opcodes are routed to the multiply/divide path
only when ``EXTENSION_M`` is enabled, and atomic encodings require
``EXTENSION_A``.

Privilege and protection configuration
--------------------------------------

The ULX3S example SoC forces the settings needed for a useful machine-mode
system:

.. list-table::
   :header-rows: 1

   * - Setting
     - Effective value
     - Meaning
   * - ``CSR_M_MANDATORY``
     - 1
     - Required machine-level identification/status CSR support.
   * - ``CSR_M_TRAP``
     - 1
     - Machine trap/interrupt CSR support.
   * - ``U_MODE``
     - 0 (default)
     - No user-mode execution in this project build.
   * - ``PMP_REGIONS``
     - 0 (default)
     - No Physical Memory Protection regions in this project build.
   * - ``DEBUG_SUPPORT``
     - 1
     - Debug mode and external Debug Module integration enabled.
   * - ``BREAKPOINT_TRIGGERS``
     - 0 (default)
     - No optional instruction-address trigger slots are selected.
   * - ``NUM_IRQS``
     - 1
     - One external interrupt input; the example SoC connects UART IRQ here.

Do not confuse "Hazard3 supports user mode/PMP/triggers" with "this bitstream
contains them." The former is an upstream CPU capability; the latter depends
on synthesis parameters.

Performance-oriented settings
-----------------------------

The project also overrides implementation choices that are not ISA extensions:

.. list-table::
   :header-rows: 1

   * - Parameter
     - Project value
     - Effect
   * - ``REDUCED_BYPASS``
     - 0
     - Retain the normal, fuller forwarding network.
   * - ``MUL_FAST``
     - 1
     - Enable the fast multiply implementation.
   * - ``MUL_FASTER``
     - 1
     - Enable the additional lower-latency multiply path provided by this snapshot.
   * - ``MULH_FAST``
     - 1
     - Accelerate high-half multiply operations.
   * - ``MULDIV_UNROLL``
     - 4
     - Perform more iterative multiply/divide work per cycle than the minimum configuration.
   * - ``FAST_BRANCHCMP``
     - 1
     - Synthesize the fast branch comparator path.
   * - ``BRANCH_PREDICTOR``
     - 1
     - Enable the small backward-branch prediction structure.
   * - ``RESET_REGFILE``
     - 0
     - Do not spend reset logic clearing general-purpose registers.

Software consequence
--------------------

Software should be compiled for the ISA actually present in the FPGA, not the
superset Hazard3 can theoretically synthesize. A representative architecture
selection for code intended only for this configuration is conceptually:

.. code-block:: text

   rv32imc + zba + zbb + zbs + zicsr + zifencei

The exact GCC/LLVM ``-march`` spelling should follow the installed toolchain's
accepted extension syntax and the project's build scripts. In particular, do
not enable ``A`` merely because upstream Hazard3 supports atomics.

Upstream versus pinned snapshot
-------------------------------

Current upstream Hazard3 continues to add features and implementation
improvements. Those changes are valuable reference material, but the pinned
ULX3S commit remains the correct source when answering cycle-level or
configuration questions about this particular FPGA image.

For architectural study, use both:

* `Pinned project config <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_config.vh>`_ - exact options and
  defaults available to this snapshot.
* `Current upstream stable config <https://github.com/Wren6991/Hazard3/blob/stable/hdl/hazard3_config.vh>`_
  - current maintained upstream direction.
