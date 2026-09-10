Preduvjeti
==========

Okruženje računala domaćina
---------------------------

Projekt je zamišljen za ponovljivu izgradnju iz Bash okruženja. Na Windowsu je WSL preporučeno okruženje naredbenog retka za izgradnju; PowerShell je i dalje praktičan za skripte za prijenos putem UART-a.

Provjera preduvjeta računala
----------------------------

Nakon kloniranja repozitorija pokrenite nedestruktivnu provjeru računala prije
prvog builda:

.. code-block:: bash

   ./scripts/requirements-check.sh

Provjera ne instalira pakete i ne mijenja konfiguraciju. Nedostajući obavezni
alati daju neuspješan izlazni status, dok se opcionalni alati za razvoj,
simulaciju, otklanjanje pogrešaka i dokumentaciju prijavljuju zasebno. Provjera
također potvrđuje da pronađeni RISC-V kompajler prihvaća Hazard3 RV32 ISA/ABI
opcije.

Potrebni alati
--------------

Potrebno je instalirati barem:

* Git s podrškom za rekurzivne podmodule.
* Python 3.
* ``pyserial`` za prijenose putem UART-a.
* RISC-V GCC/GDB alatni lanac za bare-metal sustave.
* Yosys, nextpnr-ecp5, Project Trellis/ecppack i uobičajene ULX3S FPGA alate za izradu bitstreama.
* OpenOCD kada se koristi JTAG otklanjanje pogrešaka.
* ``shellcheck`` za provjeru shell skripti.

Build monitora trenutačno zadano koristi ovaj RISC-V prefiks:

.. code-block:: text

   /opt/riscv/bin/riscv32-unknown-elf-

Provjera računala prepoznaje i uobičajene alternative poput
``riscv-none-elf-`` te xPack instalacije. Ako je kompajler instaliran drugdje,
izričito postavite prefiks builda. Na primjer:

.. code-block:: bash

   TOOLCHAIN_PREFIX=riscv-none-elf- ./scripts/build.sh

Python ovisnost za alat za prijenos
-----------------------------------

.. code-block:: bash

   python3 -m pip install pyserial

IWAD
----

Repozitorij ne distribuira komercijalni Doom IWAD. Zakonski pribavljenu datoteku ``DOOM.WAD`` držite izvan Gita ili u zanemarenom direktoriju ``wads/``.

.. warning::

   Nemojte spremati u repozitorij niti redistribuirati komercijalni Doom IWAD kao dio repozitorija projekta ili izgradnje dokumentacije.

Povezane poveznice
------------------

* `RISC-V GCC xPack <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_
