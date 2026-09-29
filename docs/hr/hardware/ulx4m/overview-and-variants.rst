Pregled i varijante pločice
===========================

Što je ULX4M?
-------------

ULX4M je obitelj open hardware FPGA system-on-module pločica namijenjenih
carrier pločicama koje koriste mehanički format i konektore Raspberry Pi Compute
Module 4. Obitelj prenosi ideju ULX3S-a u kompaktni modularni format i izlaže
više brzih veza.

``ULX4M-LS``
   Lattice ECP5 s vanjskim SDR SDRAM-om.

``ULX4M-LD``
   Lattice ECP5 s vanjskim DDR3/DDR3L-om. Hazard3-Doom na ovoj meti koristi
   LiteDRAM i ECP5 DDR PHY.

Objavljene specifikacije ovise o reviziji
-----------------------------------------

Ne postoji jedna javna tablica koja sigurno opisuje svaki proizvedeni ULX4M.
Javni izvori opisuju različite revizije i odabire komponenti, pa broj dijela
uvijek treba vezati uz konkretan izvor ili fizičku pločicu.

.. list-table:: Primjeri iz javnih ULX4M izvora
   :header-rows: 1
   :widths: 22 26 26 26

   * - Izvor/varijanta
     - Opisana memorija
     - Opisani Ethernet
     - Tumačenje
   * - Crowd Supply ULX4M-LS
     - 64 MiB ``IS42S16320D-6BLI``
     - ``KSZ9031RNXCA``
     - Promovirana LS konfiguracija.
   * - Upstream ULX4M-LS priručnik
     - 32 MiB ``IS42S16160G-7BL``
     - ``LAN8720A``
     - Starija ili druga LS populacija.
   * - Crowd Supply ULX4M-LD
     - 1 GiB ``MT41K512M16HA-125``
     - ``KSZ9031RNXCA``
     - Odgovara Micron 8-Gbit klasi koju Hazard3-Doom podržava.
   * - Upstream ULX4M-LD priručnik
     - 512 MiB ``MT41K256M16TW-107``
     - ``KSZ9031RNXCA``
     - Druga dokumentirana LD populacija/revizija.
   * - Trenutačni Hazard3-Doom LD profili
     - ``MT41K512M16HA`` ili ``AS4C256M16D3``
     - Trenutačni Doom dizajn ga ne koristi
     - Podržani profili kontrolera, ne tvrdnja o svim pločicama.

Prvo identificirajte stvarni hardver, a zatim odaberite odgovarajući build
profil.

Sažetak Hazard3-Doom meta
-------------------------

Trenutačni profili pločica projekta sažeti su u nastavku. Pogledajte
:doc:`../../reference/board-profiles` za zapis kvalifikacije izdanja.

.. list-table::
   :header-rows: 1
   :widths: 20 20 24 18 18

   * - Meta
     - FPGA klasa
     - Vanjska memorija
     - Hazard3 sat
     - Status projekta
   * - ULX4M-LS 85F
     - ECP5 85K build
     - 16-bitni SDR SDRAM preko nativnog SDR kontrolera
     - 50 MHz
     - Podržan build put; provjeriti reviziju i populaciju.
   * - ULX4M-LD 85F
     - ``LFE5UM-85F-8BG381C``
     - x16 DDR3 preko LiteDRAM/``ECP5DDRPHY``
     - 40 MHz
     - Hardverski kvalificiran s Micron 8-Gbit profilom; generira se i Alliance profil.

Trenutačni LS build zahtijeva 85K-klasu FPGA-a jer kompletna Doom konfiguracija
troši više EBR-a nego što 12K uređaj može pružiti.

Resursi pločice
---------------

Objavljene ULX4M varijante nude ECP5 FPGA, vanjsku memoriju, SPI flash, USB DFU,
JTAG, GPDI video, micro-SD, Ethernet, CSI/DSI konektore, GPIO, tipke, DIP
prekidače, LED-ice te, kada to FPGA i PCB revizija omogućuju, SerDes/PCIe veze.

Popis opisuje hardver pločice, a ne nužno periferije koje Hazard3-Doom danas
koristi.

Praćenje memorijske transakcije
-------------------------------

Na ULX4M-LD čitanje približno prolazi ovim putem:

.. code-block:: text

   Hazard3 -> AHB5 -> ahb_litedram.v -> CDC -> 128-bitni Wishbone
           -> LiteDRAM -> ECP5DDRPHY -> x16 DDR3

Na ULX4M-LS isti softverski pristup dolazi do nativnog SDR kontrolera. To je
koristan primjer kako procesor može ostati gotovo isti dok se memorijski sustav
na razini pločice bitno promijeni.
