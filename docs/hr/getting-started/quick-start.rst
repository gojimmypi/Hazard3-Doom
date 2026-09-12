Brzi početak
============

Cilj
----

Primarni dokumentirani cilj je **ULX3S 85F** na kojem Hazard3 radi na 50 MHz uz HDMI izlaz. Kompaktni cilj ULX3S 12F i profili ULX4M-LD/ULX4M-LS također su dokumentirani tamo gdje se razlikuju njihov takt, video ili raspored memorije.

1. Klonirajte repozitorij
-------------------------

Upotrijebite rekurzivno kloniranje kako bi podmoduli Hazard3 i DoomGeneric bili dostupni:

.. code-block:: bash

   git clone --recursive https://github.com/ulx3s/Hazard3-Doom.git
   cd Hazard3-Doom
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
   build/ulx3s/monitor/hazard3-boot-monitor.elf
   build/ulx3s/doom-image/hazard3-doom.h3d
   build/ulx3s/hazard3-boot-monitor.hex

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

Neobavezno: učitajte trenutačni monitor ELF kroz OpenOCD
--------------------------------------------------------

Softversko ažuriranje monitora može se učitati bez ponovnog place-and-routea ili
ponovnog programiranja FPGA-a. Ovaj put koristi Hazard3 debug modul i zahtijeva
tri procesa koji surađuju: OpenOCD, lokalni web server i preglednik.

Najprije odspojite preglednikov **FPGA web flasher** s ``US1`` kako bi OpenOCD
mogao preuzeti FT231X JTAG sučelje. U jednom terminalu, iz korijena
repozitorija, pokrenite OpenOCD:

.. code-block:: bash

   ./scripts/start-openocd.sh

Ispravna ULX3S 85F sesija sadrži retke slične ovima:

.. code-block:: text

   JTAG tap: lfe5u85.hazard3 tap/device found: 0x41113043
   Examined RISC-V core; found 1 harts
   Listening on port 3333 for gdb connections

Ostavite OpenOCD pokrenut. U drugom terminalu pokrenite projektni web server:

.. code-block:: bash

   python3 web/web-server.py

Otvorite ``http://127.0.0.1:8000/`` u Chromeu ili Edgeu. **Nemojte** otvarati
``web/index.html`` s ``file://`` URL-om; statična stranica ne može pozvati
lokalni API loadera firmwarea. Proširite **Console firmware uploader**, odaberite
``build/ulx3s/monitor/hazard3-boot-monitor.elf`` i učitajte ga. GDB se spaja na
već pokrenuti OpenOCD server, provjerava ELF sekcije, nastavlja Hazard3 i
prekida vezu.

Vanjski J1 USB-UART adapter odvojen je put od ``US1`` JTAG sučelja, pa Web Serial
može ostati spojen dok OpenOCD radi. Pogledajte :doc:`../user-guide/web-tool` i
:doc:`../user-guide/jtag-debugging` za cijeli postupak i detalje otklanjanja
poteškoća.

4. Učitajte Doom putem UART-a
-----------------------------

Web alat može obaviti oba Doom prijenosa bez napuštanja pregledničke konzole.
Proširite **Serial connection**, spojite UART pločice i provjerite da je aktivan
``>`` prompt rezidentnog monitora. Zatim proširite **Device uploading**:

#. Otvorite **Doom H3D uploader**, odaberite
   ``build/ulx3s/doom-image/hazard3-doom.h3d`` i kliknite **Upload H3D**.
#. Otvorite **Doom IWAD uploader**, odaberite zakonito pribavljenu ``.wad``
   datoteku, odaberite memorijski profil koji odgovara rezidentnom monitoru i
   kliknite **Upload IWAD**.
#. Uključite **Launch with ``j`` after upload** u IWAD uploaderu ako se Doom treba
   pokrenuti odmah nakon što monitor prihvati IWAD.

Za cijeli web postupak i tablicu memorijskih profila pogledajte
:doc:`../user-guide/web-tool`.

Naredbeni uploaderi i dalje su dostupni. Najprije zatvorite terminal ili
pregledničku vezu koja koristi UART port, a zatim pokrenite:

.. code-block:: powershell

   py .\doom\upload-doom-image.py `
       .\build\doom-image\hazard3-doom.h3d `
       --port COM7

   py .\doom\upload-wad.py `
       C:\path\to\DOOM.WAD `
       --port COM7 `
       --launch

Naziv UART porta samo je primjer; upotrijebite port dodijeljen pločici.

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
