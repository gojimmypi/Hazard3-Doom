Brzi početak iz izvornog koda
=============================

.. note::

   Ako želite pokrenuti Hazard3-Doom prije instalacije FPGA i RISC-V razvojnih
   alata, počnite s :doc:`no-install` i objavljenim unaprijed izgrađenim slikama.


Cilj
----

Primarni dokumentirani cilj je **ULX3S 85F** na kojem Hazard3 radi na 50 MHz uz HDMI izlaz. Kompaktni cilj ULX3S 12F i profili ULX4M-LD/ULX4M-LS također su dokumentirani tamo gdje se razlikuju njihov takt, video ili raspored memorije.

Zahtjevi sustava
----------------

Minimalni razvojni sustav:

* RAM: 8 GiB konfigurirano (virtualni strojevi mogu prijaviti nešto manje
  iskoristive memorije)
* Procesori: 2
* Disk: 40 GiB kapaciteta datotečnog sustava
* Swap: preporučeno 4 GiB

Preporučeno za izgradnju iz izvornog koda:

* RAM: 12-16 GiB
* Procesori: 4
* Disk: 60 GiB ili više
* Swap: 4-8 GiB

Izgradnja Yosysa i nextpnr-a iz izvornog koda može koristiti znatnu količinu
memorije, osobito pri paralelnim izgradnjama. Sustavi s manje od minimalno
potrebne količine RAM-a mogu prekinuti procese izgradnje zbog nedostatka
memorije.

Skripta ``check-system-requirements.sh`` prikazuje otkrivene resurse:

.. code-block:: bash

   ./scripts/check-system-requirements.sh


Instalacija potrebnog softvera
------------------------------

Na svježem sustavu sve se može instalirati jednom skriptom. Skripta je korisna
i za ažuriranja:

.. code-block:: bash

   mkdir -p workspace
   cd workspace

   wget \
       https://raw.githubusercontent.com/ulx3s/Hazard3-Doom/main/scripts/full-install.sh \
       https://raw.githubusercontent.com/ulx3s/Hazard3-Doom/main/scripts/check-system-requirements.sh

   chmod +x ./full-install.sh
   chmod +x ./check-system-requirements.sh

   ./full-install.sh

.. admonition:: Verzije Yosysa i nextpnr-a

   Skripte instaliraju određene verzije Yosysa i nextpnr-a za koje je poznato
   da prolaze vremenska ograničenja sa zadanim seedovima. Već instalirane
   verzije tiho se prepisuju. Ako imate instaliranu drugu verziju Yosysa ili
   nextpnr-a, možda ćete morati prilagoditi skripte za izgradnju. Za detalje
   pogledajte :doc:`/user-guide/build` i skriptu
   `build-ecp5-bitstream-common.sh <https://github.com/ulx3s/Hazard3-Doom/blob/main/scripts/build-ecp5-bitstream-common.sh>`_.

1. Klonirajte repozitorij
-------------------------

Ako koristite gornji ``./full-install.sh``, ovaj je korak izvršen automatski.


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
   build/ulx3s/doom-image/hazard3-doom.h3img
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
tri dijela koji surađuju: OpenOCD, loopback helper ``web-server.py`` i preglednik.
Stranica preglednika može biti javni GitHub Pages; samo helper, GDB i OpenOCD
moraju raditi lokalno.

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

Ostavite OpenOCD pokrenut. U drugom terminalu pokrenite loopback helper:

.. code-block:: bash

   python3 web/web-server.py

Zatim možete nastaviti s javnom stranicom
``https://ulx3s.github.io/Hazard3-Doom/`` ili otvoriti lokalnu kopiju
``http://127.0.0.1:8000/``. **Console firmware uploader** treba prikazati
**Local loader Ready** i **OpenOCD Ready**; **refresh** pokreće trenutačnu
provjeru.

Odaberite ``build/ulx3s/monitor/hazard3-boot-monitor.elf`` i učitajte ga. GDB se
spaja na već pokrenuti OpenOCD server, provjerava ELF sekcije, nastavlja Hazard3
i prekida vezu. OpenOCD status provjera u helperu pasivna je i ne troši GDB
connection slot.

Vanjski J1 USB-UART adapter odvojen je put od ``US1`` JTAG sučelja, pa Web Serial
može ostati spojen dok OpenOCD radi. Pogledajte :doc:`../user-guide/web-tool` i
:doc:`../user-guide/jtag-debugging` za cijeli postupak i detalje otklanjanja
poteškoća.

4. Učitajte Doom putem UART-a
-----------------------------

Web alat može obaviti oba Doom prijenosa bez napuštanja pregledničke konzole.
Proširite **Serial connection**, spojite UART pločice i provjerite da je aktivan
``>`` prompt rezidentnog monitora. Zatim proširite **Device uploading**:

#. Otvorite **Doom H3IMG uploader**, odaberite
   ``build/ulx3s/doom-image/hazard3-doom.h3img`` i kliknite **Upload H3IMG**.
#. Otvorite **Doom IWAD uploader**, odaberite zakonito pribavljenu ``.wad``
   datoteku, odaberite memorijski profil koji odgovara rezidentnom monitoru i
   kliknite **Upload IWAD**.
#. Uključite **Launch with ``j`` after upload** u IWAD uploaderu ako se Doom treba
   pokrenuti odmah nakon što monitor prihvati IWAD.

Za cijeli web postupak i tablicu memorijskih profila pogledajte
:doc:`../user-guide/web-tool`.

Naredbeni uploaderi i dalje su dostupni. Najprije zatvorite terminal ili
pregledničku vezu koja koristi UART port. U sustavu Windows upotrijebite sintaksu
ljuske koja je stvarno otvorena: PowerShell koristi obrnuti apostrof (`````)
za nastavak naredbe u sljedećem retku, dok Windows Command Prompt (``cmd.exe``,
često nazivan DOS prompt) koristi znak ``^``. Nemojte lijepiti PowerShellove
obrnute apostrofe u ``cmd.exe``.

**Windows PowerShell**

.. code-block:: powershell

   py .\doom\upload-doom-image.py `
       .\build\ulx3s\doom-image\hazard3-doom.h3img `
       --port COM7

   py .\doom\upload-wad.py `
       C:\path\to\DOOM.WAD `
       --port COM7 `
       --memory-profile 64m `
       --launch

**Windows Command Prompt (cmd.exe / DOS prompt)**

.. code-block:: bat

   py .\doom\upload-doom-image.py ^
       .\build\ulx3s\doom-image\hazard3-doom.h3img ^
       --port COM7

   py .\doom\upload-wad.py ^
       C:\path\to\DOOM.WAD ^
       --port COM7 ^
       --memory-profile 64m ^
       --launch

**Linux (Bash)**

.. code-block:: bash

   python3 doom/upload-doom-image.py \
       build/ulx3s/doom-image/hazard3-doom.h3img \
       --port /dev/ttyUSB0

   python3 doom/upload-wad.py \
       /path/to/DOOM.WAD \
       --port /dev/ttyUSB0 \
       --memory-profile 64m \
       --launch

Ovi primjeri odnose se na primarnu ULX3S 85F ciljnu pločicu. Za zadanu ULX3S
12F izgradnju upotrijebite ``--memory-profile 32m`` i odgovarajuću 12F H3IMG
sliku. Monitor, H3IMG slika i IWAD uploader moraju koristiti isti memorijski
profil.

Nazivi UART portova samo su primjeri. U sustavu Windows upotrijebite COM port
dodijeljen pločici. U Linuxu upotrijebite odgovarajući uređaj, najčešće
``/dev/ttyUSB0`` ili ``/dev/ttyACM0``.

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

Brzi postupak za ULX4M-LD
---------------------------

Za ULX4M-LD koristite timing-kvalificirani bitstream s Hazard3 na 40 MHz i
LiteDRAM na 60 MHz. Za ulazak u normalni DFU isključite napajanje, držite PCB
``BTN3`` dok spajate ULX4M Micro-B USB kabel, pričekajte da se enumerira VID:PID
``1d50:614b``, a zatim otpustite ``BTN3``. ``BTN3`` **ne** treba ostati pritisnut
tijekom programiranja.

Ako Bash u WSL-u za priložene Windows alate prijavi ``Permission denied``,
postavite izvršne dozvole:

.. code-block:: bash

   chmod +x ./bin/openFPGALoader.exe ./bin/dfu-util.exe

Programirajte trajni korisnički bitstream, a zatim izričito izađite iz DFU-a:

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

   ./bin/dfu-util.exe -a 0 -e

Za UART na 115200 koristite Tigard Interface 0 s FTDI VCP driverom, a za OpenOCD
JTAG Interface 1 s libusbK driverom. Potpuni ULX4M-LD build sprema Doom sliku u
``build/ulx4m-ld/doom-image/hazard3-doom.h3img``. Na primjer, iz WSL/Basha kada
je Tigard VCP dostupan kao ``/dev/ttyS8``:

.. code-block:: bash

   ./doom/upload-doom-image.py \
       ./build/ulx4m-ld/doom-image/hazard3-doom.h3img \
       --port /dev/ttyS8

Naziv serijskog uređaja samo je primjer. Nakon pokretanja monitora provjerite
``s`` za ``external_memory_ready=YES`` i pokrenite ``q``. Trenutačno kvalificirani
put prolazi i ``k``, ``d`` i ``x``.

Za softversko ažuriranje samo monitora koje odgovara FPGA-u na 40 MHz:

.. code-block:: bash

   HAZARD3_BUILD_DIR="$PWD/build/ulx4m-ld-monitor-test/monitor" \
   HAZARD3_MEMORY_PROFILE=64m \
   HAZARD3_SYS_CLK_HZ=40000000 \
       ./scripts/build.sh

Zatim pokrenite ULX4M Tigard OpenOCD konfiguraciju i izričito učitajte taj
odvojeni testni ELF:

.. code-block:: bash

   ./scripts/load-firmware.sh \
       ./build/ulx4m-ld-monitor-test/monitor/hazard3-boot-monitor.elf

Za normalan potpuni ULX4M-LD build radije koristite board-specific helper
``scripts/gdb/load-ulx4m-ld-85f-monitor.gdb``. Za potpune detalje o driverima,
ožičenju, IDCODE-u i DTM dijagnostici pogledajte
:doc:`../user-guide/jtag-debugging`.

Sljedeći koraci
---------------

* Upotrijebite :doc:`../user-guide/monitor` za pregled i upravljanje rezidentnim monitorom.
* Upotrijebite :doc:`../user-guide/sd-card` za pokretanje bez računala.
* Upotrijebite :doc:`../user-guide/jtag-debugging` za otklanjanje pogrešaka na razini izvornog koda.
* Upotrijebite :doc:`../user-guide/sao` za podršku SAO/I2C-a.
* Upotrijebite :doc:`../user-guide/i2cdriver` za HDMI sučelje skenera/analizatora I2C-a.

Implementacijske reference
---------------------------
* `openFPGALoader <https://trabucayre.github.io/openFPGALoader/guide/install.html>`_
