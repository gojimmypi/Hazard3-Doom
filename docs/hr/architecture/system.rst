Arhitektura sustava
===================

Hazard3-Doom je hardversko-softverski sklop, a ne jedna firmware binarna
datoteka. Procesor u njegovu središtu je standardni parametrizirani Hazard3 RTL;
Doom projekt oko tog procesora dodaje integraciju memorije na razini pločice,
videa, pohrane, SAO-a i pokretanja.

Za detaljan pregled CPU-a, uključujući F/X/M pipeline, odabrane ISA ekstenzije,
CSR-ove, prekide, sučelje sabirnice i RISC-V debug put, pogledajte
:doc:`hazard3/index`.

Glavne komponente
-----------------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Komponenta
     - Uloga
   * - Hazard3 CPU
     - Trostupanjski RV32 RISC-V procesor. Ovaj projekt odabire M, C, Zba, Zbb, Zbs, Zifencei, brojače, debug podršku, opcije brzog množenja, brzu usporedbu grananja i mali prediktor grananja; A je isključen.
   * - Hazard3 Debug Module/DTM
     - Izvorna RISC-V debug infrastruktura spojena na JTAG TAP ECP5 čipa koju koriste OpenOCD/GDB.
   * - Rezidentni monitor
     - Firmware za pokretanje, dijagnostiku, UART učitavanje, SD boot i oporavak u internom EBR SRAM-u.
   * - Vanjski SDRAM
     - Memorijski podsustav projektnog SoC-a koji pohranjuje povezanu Doom sliku, heap/zone memoriju, IWAD i video staging područja.
   * - HDMI engine
     - Projektna logika zaslona koja prikazuje indeksirani Doom framebuffer.
   * - micro-SD sučelje
     - Projektni APB/SPI hardver koji se koristi za samostalno učitavanje izvršne datoteke/IWAD-a nakon uključivanja.
   * - SAO APB most
     - Projektni memorijski mapirani pristup SAO I2C/GPIO-u i upravljanju dijeljenim resursima.
   * - ESP32
     - Opcionalni prateći procesor koji dijeli odabrane resurse pločice prema izričitim pravilima vlasništva.
   * - OpenOCD/GDB
     - Host debug put na razini izvornog koda kroz standardnu vanjsku debug arhitekturu Hazard3-a.

Granica CPU-a i SoC-a
---------------------

Koristan način razmišljanja o dizajnu jest odvojiti slojeve procesora i platforme:

.. code-block:: text

   +-------------------------------------------+
   | Hazard3 CPU/debug                         |
   | RISC-V ISA, F/X/M pipeline, CSRs, traps   |
   +-------------------------------------------+
                       |
                       | AHB5
                       v
   +-------------------------------------------+
   | Example SoC and project integration       |
   | SRAM, APB, timer, UART, SDRAM, SD, SAO    |
   +-------------------------------------------+
                       |
                       v
   +-------------------------------------------+
   | ULX3S/ULX4M board hardware                |
   | ECP5, SDRAM, HDMI, micro-SD, ESP32, pins  |
   +-------------------------------------------+

Procesor izvršava obična RISC-V učitavanja i spremanja. Dekoder adresa SoC-a
određuje dosežu li ti pristupi interni SRAM, APB periferiju, vanjski SDRAM ili
drugi mapirani cilj. Isto tako, Doom video i ponašanje SD kartice značajke su
platforme, a ne posebne CPU instrukcije.

Putovi pokretanja
-----------------

Razvojno pokretanje
~~~~~~~~~~~~~~~~~~~

FPGA učitavanje -> rezidentni monitor -> UART prijenos ``.h3d`` -> UART prijenos ``DOOM.WAD`` -> pokretanje.

Samostalno pokretanje
~~~~~~~~~~~~~~~~~~~~~

FPGA konfiguracija iz SPI flasha -> unaprijed učitan rezidentni monitor u EBR-u -> inicijalizacija SDRAM-a -> micro-SD ``DOOM.H3D`` + ``DOOM.WAD`` -> pokretanje.

SRAM preload rezidentnog monitora prilagodba je u ULX3S Hazard3 forku. Omogućuje
sustavu da pokrene koristan firmware odmah nakon konfiguracije FPGA-a bez
prethodnog preuzimanja putem debuggera.

APB periferije
--------------

Važna projektno lokalna APB područja uključuju:

.. list-table::
   :header-rows: 1

   * - Baza
     - Funkcija
   * - ``0x40009000``
     - SAO most.
   * - ``0x4000A000``
     - SD SPI sučelje.
   * - ``0x4000C000``
     - HDMI/video kontrolni registri.

Te periferije dodane su oko procesora Hazard3. Definicije registara u softveru
držite usklađene s odgovarajućim commitom hardverskog podmodula Hazard3.
