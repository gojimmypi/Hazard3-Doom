Preduvjeti
==========

Okruženje računala domaćina
---------------------------

Projekt je zamišljen za ponovljivu izgradnju iz Bash okruženja. Na Windowsu je WSL preporučeno okruženje naredbenog retka za izgradnju; PowerShell je i dalje praktičan za skripte za prijenos putem UART-a.

Potrebni alati
--------------

Potrebno je instalirati barem:

* Git s podrškom za rekurzivne podmodule.
* Python 3.
* ``pyserial`` za prijenose putem UART-a.
* RISC-V GCC/GDB alatni lanac za bare-metal sustave.
* Yosys, nextpnr-ecp5, Project Trellis/ecppack i uobičajene ULX3S FPGA alate za izradu bitstreama.
* OpenOCD kada se koristi JTAG otklanjanje pogrešaka.

Poznati radni RISC-V prefiks koji projekt koristi jest:

.. code-block:: text

   /opt/riscv/bin/riscv32-unknown-elf-

Po potrebi ga promijenite:

.. code-block:: bash

   TOOLCHAIN_PREFIX=/path/to/riscv32-unknown-elf- ./scripts/build.sh

Python ovisnost za alat za prijenos
-----------------------------------

.. code-block:: bash

   python3 -m pip install pyserial

IWAD
----

Repozitorij ne distribuira komercijalni Doom IWAD. Zakonski pribavljenu datoteku ``DOOM.WAD`` držite izvan Gita ili u zanemarenom direktoriju ``wads/``.

.. warning::

   Nemojte spremati u repozitorij niti redistribuirati komercijalni Doom IWAD kao dio repozitorija projekta ili izgradnje dokumentacije.
