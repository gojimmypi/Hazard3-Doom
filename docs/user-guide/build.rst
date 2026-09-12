Build Guide
===========

The primary step-by-step build instructions are in
:doc:`../getting-started/build`. This page connects that workflow with the
prerequisite, board-profile, script-reference, and timing information that is
useful when rebuilding or changing a target.

Normal board builds
-------------------

For a normal build, prefer the complete board wrapper for the target. These
wrappers keep the FPGA design, resident monitor, Doom image, clock, and memory
profile aligned:

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh
   ./scripts/build-ulx3s-12f-doom.sh
   ./scripts/build-ulx4m-ld-doom.sh

See :doc:`../getting-started/build` for the supported board configurations,
selective monitor and Doom-image rebuilds, submodule preparation, output files,
and build-specific environment variables.

Tool versions and reproducibility
---------------------------------

FPGA timing results depend on more than the source tree. Yosys, nextpnr,
Project Trellis, routing settings, and the selected seed can all affect the
result. Check the host before building with:

.. code-block:: bash

   ./scripts/requirements-check.sh

See :doc:`../getting-started/prerequisites` for the required host tools. The
board-specific nextpnr defaults are owned by
``scripts/build-ecp5-bitstream-common.sh`` and summarized directly from that
file in :doc:`../reference/board-profiles`.

A seed that passed timing with one netlist or tool version is not a timing
guarantee for another. If the synthesis result, CAD-tool version, clocking, or
routing configuration changes, rerun the appropriate timing validation before
using the result as a release build. See :doc:`../reference/timing-sweeps` for
the sweep and qualification workflow.

Build scripts and advanced workflows
------------------------------------

For the complete catalog of build, programming, validation, cleanup, and timing
helpers, see :doc:`../reference/scripts`. That reference documents the complete
board wrappers as well as the lower-level monitor, bitstream, Doom-image, and
seed-sweep tools.

For repository ownership and the boundary between Hazard3 hardware and
Hazard3-Doom-specific software, see :doc:`../architecture/repositories`.
