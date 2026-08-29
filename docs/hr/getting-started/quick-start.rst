Brzi početak
============

Cilj
----

Primarni dokumentirani cilj je **ULX3S 85F** na kojem Hazard3 radi na 50 MHz uz HDMI izlaz. Kompaktni cilj ULX3S 12F i profili ULX4M-LD/ULX4M-LS također su dokumentirani tamo gdje se razlikuju njihov takt, video ili raspored memorije.

1. Klonirajte repozitorij
-------------------------

Upotrijebite rekurzivno kloniranje kako bi podmoduli Hazard3 i DoomGeneric bili dostupni:

.. code-block:: bash

   git clone --recursive https://github.com/gojimmypi/Hazard3-Doom.git
   cd Hazard3-Doom
   git switch develop
   git submodule sync --recursive
   git submodule update --init --recursive

Za postojeću kopiju repozitorija:

.. code-block:: bash

   ./scripts/setup-submodules.sh

2. Izgradite potpuni ULX3S cilj
-------------------------------

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh

Važni izlazni artefakti uključuju:

.. code-block:: text

   build/fpga_ulx3s.bit
   build/hazard3-boot-monitor.elf
   build/doom-image/hazard3-doom.h3d

3. Programirajte FPGA za probno pokretanje
------------------------------------------

Za ULX3S web-aplikacija Hazard3-Doom može učitati ``fpga_ulx3s.bit``
izravno u FPGA SRAM preko JTAG sučelja FT231X na priključku ``US1``.
Proširite **FPGA web flasher**, odaberite datoteku ``.bit``, povežite ULX3S USB
uređaj, ispitajte JTAG i odaberite **Program FPGA SRAM**.

Na Windowsu ovaj WebUSB put zahtijeva da ULX3S FT231X sučelje koristi upravljački
program WinUSB. Pogledajte :doc:`../user-guide/web-flasher` za potpuni postupak
postavljanja, upravljačkog programa, provjere cilja i otklanjanja poteškoća.

Nestabilno učitavanje FPGA-a **ne** preživljava prekid napajanja. Po želji se i
dalje mogu koristiti drugi ULX3S alati za programiranje. Za trajnu samostalnu
instalaciju pogledajte :doc:`programming` i :doc:`../user-guide/sd-card`.

4. Učitajte Doom putem UART-a
-----------------------------

Zatvorite svaki terminalski program koji već koristi UART priključak, zatim prenesite Doom sliku:

.. code-block:: powershell

   py .\doom\upload-doom-image.py `
       .\build\doom-image\hazard3-doom.h3d `
       --port COM7

Zatim prenesite zakonski pribavljen IWAD:

.. code-block:: powershell

   py .\doom\upload-wad.py `
       C:\path\to\DOOM.WAD `
       --port COM7 `
       --launch

Naziv UART priključka samo je primjer; upotrijebite priključak dodijeljen vašoj pločici.

5. Provjerite pokretanje
------------------------

Ispravno pokretanje putem UART-a sadrži oznake slične ovima:

.. code-block:: text

   H3L READY
   H3L DATA
   H3L OK
   H3W READY
   H3W DATA
   H3W OK
   Doom SDRAM image startup
   monitor ABI: PASS
   Doom interactive HDMI loop: READY

Sljedeći koraci
---------------

* Upotrijebite :doc:`../user-guide/monitor` za pregled i upravljanje rezidentnim monitorom.
* Upotrijebite :doc:`../user-guide/sd-card` za pokretanje bez računala.
* Upotrijebite :doc:`../user-guide/jtag-debugging` za otklanjanje pogrešaka na razini izvornog koda.
* Upotrijebite :doc:`../user-guide/sao` za podršku SAO/I2C-a.
* Upotrijebite :doc:`../user-guide/i2cdriver` za HDMI sučelje skenera/analizatora I2C-a.
