Building Hazard3-Doom
=====================

Complete board builds
---------------------

ULX3S 85F:

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh

ULX4M-LD 85F:

.. code-block:: bash

   ./scripts/build-ulx4m-ld-doom.sh

The wrapper builds the FPGA design in the pinned Hazard3 submodule, the resident monitor, and the linked Doom image.

Resident monitor only
---------------------

ULX3S:

.. code-block:: bash

   ./scripts/build.sh

Typical outputs:

.. code-block:: text

   build/hazard3-boot-monitor.elf
   build/hazard3-boot-monitor.map

Linked Doom image only
----------------------

For the 64 MiB profile used by ULX3S 85F and ULX4M-LD 85F:

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=64m ./doom/build-doom-image.sh

Typical outputs:

.. code-block:: text

   build/doom-image/hazard3-doom.elf
   build/doom-image/hazard3-doom.map
   build/doom-image/hazard3-doom.bin
   build/doom-image/hazard3-doom.h3d

Testing another Hazard3 checkout
--------------------------------

You can test a hardware checkout without changing the pinned submodule pointer:

.. code-block:: bash

   HAZARD3_ROOT=/mnt/c/workspace/Hazard3 \
       ./scripts/build-ulx3s-doom.sh

Build ownership
---------------

The project intentionally keeps reusable FPGA/CPU hardware in Hazard3 while keeping Doom-specific monitor/application ownership in Hazard3-Doom. See :doc:`../architecture/repositories`.
