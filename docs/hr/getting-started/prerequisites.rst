Preduvjeti
==========

Okruženje računala domaćina
---------------------------

Skripte za build i razvoj projekta zahtijevaju Linux/Bash okruženje. Na
izvornom Linuxu koristite uobičajeni Bash. Na Windowsu koristite **WSL s
Ubuntuom**: WSL je obavezan za build iz izvornog koda i za shell skripte
repozitorija. Nemojte pokretati build skripte iz PowerShella ili ``cmd.exe``.

Izvorni Windows i dalje je prikladan kada dokumentacija izričito traži Device
Tool u pregledniku, upravljanje USB upravljačkim programima, UART prijenos preko
COM porta ili priloženi Windows ``.exe``. Ako blok nije izričito označen kao
PowerShell ili ``cmd.exe``, pokrenite ga iz WSL/Basha.

Provjera preduvjeta računala
----------------------------

Nakon kloniranja repozitorija pokrenite nedestruktivnu provjeru računala prije
prvog builda:

.. code-block:: bash

   ./scripts/requirements-check.sh

Provjera ne instalira pakete i ne mijenja konfiguraciju. Nedostajući obavezni
alati daju neuspješan izlazni status, dok se opcionalni alati za razvoj,
simulaciju, otklanjanje pogrešaka i dokumentaciju prijavljuju zasebno. Provjera
također potvrđuje da pronađeni RISC-V prevoditelj prihvaća Hazard3 RV32 ISA/ABI
opcije.

Potrebni alati
--------------

Potrebno je instalirati barem:

* Git s podrškom za rekurzivne podmodule.
* Python 3.
* ``pyserial`` za prijenose putem UART-a.
* RISC-V GCC/GDB alatni lanac za bare-metal sustave dostupan u ``PATH``.
* Yosys, nextpnr-ecp5, Project Trellis/ecppack i uobičajene ULX3S FPGA alate za izradu bitstreama.
* OpenOCD kada se koristi JTAG otklanjanje pogrešaka.
* ``shellcheck`` za provjeru shell skripti (opcionalno, ali preporučeno).

FPGA alatni lanac
-----------------

Preporučeni FPGA alatni lanac je unaprijed izgrađeni `OSS CAD Suite
<https://github.com/YosysHQ/oss-cad-suite-build>`_. Sadrži Yosys, nextpnr,
Project Trellis/ecppack i povezane alate za Linux, macOS i Windows. Na
Ubuntu/WSL-u ``full-install.sh`` automatski instalira i aktivira OSS CAD Suite
verziju koju projekt očekuje. Umjesto toga možete sami instalirati izdanje OSS
CAD Suitea i aktivirati njegovo okruženje kako bi alati bili dostupni u
``PATH``.

Za napredni razvoj ili rad na reproducibilnosti instalacijske skripte također
nude opcije izgradnje iz izvornog koda koje odabrane FPGA alate grade iz
određenih revizija (commitova) u izvornim GitHub repozitorijima. Izgradnja FPGA alata iz izvornog koda nije
potrebna za uobičajeni postupak instalacije.

Na Windowsu OSS CAD Suite preporučuje WSL s Linux-x64 paketom za najbolje
iskustvo, što odgovara Bash/WSL okruženju koje koristi Hazard3-Doom.

RISC-V GCC alatni lanac
-----------------------

Build koristi kompatibilan RISC-V GCC alatni lanac za bare-metal sustave koji
se nalazi u ``PATH``. ``riscv-none-elf-*`` izravno je podržan, a prepoznaju se i
xPack RISC-V GCC instalacije. Na Ubuntu/WSL-u, macOS-u ili drugoj Linux
distribuciji upotrijebite prikladan paket RISC-V GCC alata za bare-metal sustave
ili instalirajte xPack, zatim osigurajte da je prevoditelj dostupan u ``PATH``.
Nazivi paketa razlikuju se među distribucijama.

Koristite ``TOOLCHAIN_PREFIX`` kada trebate odabrati određenu instalaciju. Na
primjer:

.. code-block:: bash

   TOOLCHAIN_PREFIX=riscv-none-elf- ./scripts/build.sh

Povijesni prefiks ``/opt/riscv/bin/riscv32-unknown-elf-`` i dalje je podržan
radi kompatibilnosti, ali instalacija u ``/opt`` nije obavezna.

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

* `OSS CAD Suite <https://github.com/YosysHQ/oss-cad-suite-build>`_
* `RISC-V GCC xPack <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_

* `Yosys <https://github.com/YosysHQ/yosys>`_
* `nextpnr <https://github.com/YosysHQ/nextpnr>`_
