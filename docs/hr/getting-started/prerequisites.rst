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

Pristup serijskom portu na Linuxu
---------------------------------

Na izvornom Linuxu, uključujući Ubuntu VM, USB-UART adapteri obično se pojavljuju
kao ``/dev/ttyUSB0``, ``/dev/ttyUSB1`` i tako dalje. Čvor uređaja normalno je u
vlasništvu ``root:dialout`` s načinom ``0660``. Prije korištenja Web Serial-a ili
Python uploadera provjerite aktivni uređaj i grupe trenutačne prijavne sesije:

.. code-block:: bash

   ls -l /dev/ttyUSB*
   groups

Ako UART uređaj pripada grupi ``dialout``, a vaš korisnik ne, dodajte korisnika
u grupu:

.. code-block:: bash

   sudo usermod -aG dialout "$USER"

Nova dodatna grupa primjenjuje se na **novu prijavnu sesiju**. Odjavite se s
Ubuntu radne površine i ponovno prijavite prije pokretanja preglednika. Naredba
``groups`` u već otvorenom terminalu neposredno nakon ``usermod`` i dalje će
prikazati stare grupe sesije.

Za privremeni test bez ponovnog pokretanja, odjave ili ponovnog spajanja USB-a,
dodijelite trenutačnom korisniku pristup postojećem čvoru uređaja ACL-om:

.. code-block:: bash

   sudo setfacl -m u:"$USER":rw /dev/ttyUSB1

Zamijenite ``ttyUSB1`` stvarnim uređajem. ``setfacl`` dolazi iz Ubuntu paketa
``acl``. Ovaj ACL je dijagnostičko stanje vezano uz taj čvor uređaja i može
nestati pri ponovnoj USB enumeraciji; članstvo u ``dialout`` normalna je trajna
postavka.

Pogledajte :doc:`../troubleshooting` za vlasništvo porta, ModemManager, Web
Serial i dijagnostiku jednosmjernog UART-a.

IWAD
----

Repozitorij ne distribuira komercijalni Doom IWAD. Zakonski pribavljenu datoteku ``DOOM.WAD`` držite izvan Gita ili u zanemarenom direktoriju ``wads/``.

.. warning::

   Nemojte spremati u repozitorij niti redistribuirati komercijalni Doom IWAD kao dio repozitorija projekta ili izgradnje dokumentacije.

Povezane poveznice
------------------

* `RISC-V GCC xPack <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_
