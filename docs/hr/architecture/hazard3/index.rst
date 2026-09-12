Hazard3 RISC-V procesor
=======================

Hazard3 je procesor u središtu Hazard3-Dooma. To je kompaktan, in-order,
trostupanjski 32-bitni RISC-V CPU namijenjen FPGA i ASIC primjenama. Projekt
Hazard3 također pruža okolni debug hardver i primjer SoC integracije koji se
koriste za pretvaranje CPU jezgre u upotrebljiv sustav.

Ovaj odjeljak objašnjava procesor iz obrazovne perspektive i, jednako važno,
odvaja **standardni Hazard3 dizajn** od **ULX3S/Hazard3-Doom integracije**
izgrađene oko njega.


Veza s Raspberry Pi RP2350
--------------------------

Hazard3 je također jedna od procesorskih arhitektura ugrađenih u Raspberry Pi
RP2350 mikrokontroler. RP2350 sadrži dvije open-hardware Hazard3 RISC-V jezgre
uz dvije Arm Cortex-M33 jezgre; softver ili OTP konfiguracija odabire koji se
par procesora koristi. RP2350 je mikrokontroler koji se koristi na Raspberry Pi
Pico 2 i Pico 2 W pločicama.

Zbog toga je procesor u Hazard3-Doomu posebno zanimljiv za učenje: FPGA projekt
koristi isti open-source Hazard3 procesorski dizajn koji se koristi i u serijski
proizvedenom Raspberry Pi mikrokontroleru. To ipak ne znači da su dva
sintetizirana CPU-a konfigurirana identično. Hazard3 je parametriziran, a RP2350
uključuje drukčiji skup ISA ekstenzija, prilagođenih ekstenzija, debug značajki
i SoC integracije od Hazard3-Doom FPGA konfiguracije opisane u nastavku.

Korisne primarne reference:

* `Raspberry Pi RP2350 stranica proizvoda <https://www.raspberrypi.com/products/rp2350/>`_
* `Raspberry Pi RP2350 datasheet, odjeljak 3.8 Hazard3 processor <https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf>`_
* `Raspberry Pi Pico 2 stranica proizvoda <https://www.raspberrypi.com/products/raspberry-pi-pico-2/>`_
* `Raspberry Pi dokumentacija mikrokontrolera - promjena arhitekture <https://www.raspberrypi.com/documentation/microcontrollers/microcontroller-chips.html#architecture-switching>`_
* `Upstream Hazard3 izvor i bilješke o RP2350 konfiguraciji <https://github.com/Wren6991/Hazard3>`_

Snimak izvornog koda koji ovaj projekt koristi
----------------------------------------------

Tehnički opisi na ovim stranicama vezani su uz Hazard3 snimak izvornog koda
korišten za ovaj pregled dokumentacije:

* commit ULX3S Hazard3 forka: |hazard3_commit|
* :hazard3-tree:`Pregled fiksiranog izvora </>`
* `Pregled trenutačnog upstream Hazard3 stable <https://github.com/Wren6991/Hazard3/tree/stable>`_

.. important::

   Fiksirani SHA mjerodavan je za ovdje opisanu FPGA izgradnju. Upstream Hazard3
   nastavlja se razvijati. Značajka prisutna u trenutačnom upstreamu ``stable``
   ili ``develop`` nije automatski prisutna u ovom projektu dok se podmodul
   Hazard3 namjerno ne ažurira.

Što je upstream Hazard3?
------------------------

Procesorski RTL u ``hdl/`` dio je upstream Hazard3 arhitekture: trostupanjska
jezgra, instruction frontend, dekoder, aritmetičke jedinice, CSR-ovi, logika
prekida, debug-mode hookovi, registarska datoteka, PMP podrška, triggeri te
jednoportni/dvoportni CPU wrapperi. Iste obitelji arhitekturnih modula prisutne
su i u trenutačnom upstream Hazard3 projektu.

Upstream također pruža minimalni primjer SoC-a i RISC-V debug implementaciju.
Uobičajeni upstream primjer namjerno je malen: procesor, debug, RAM, UART i
platformski timer dovoljni su za demonstraciju i debugiranje CPU-a.

Što je prilagođeno za Hazard3-Doom?
-----------------------------------

ULX3S fork proširuje example-SoC i sloj integracije pločice umjesto da Hazard3
pretvara u CPU specifičan za Doom. Projektne dopune uključuju podršku za vanjski
SDRAM, video pristup, SD-card SPI, SAO/ESP32 integraciju, logiku pinova i
vlasništva pločice te unaprijed učitanu sliku rezidentnog monitora.

Ta granica korisna je pri učenju dizajna:

.. code-block:: text

   RISC-V software
         |
         v
   +-------------------------------+
   | Standard Hazard3 CPU          |
   | F -> X -> M pipeline          |
   | ISA, CSR, traps, debug hooks  |
   +-------------------------------+
         |
         | AHB5 master interface
         v
   +-------------------------------+
   | Example SoC / project fabric  |
   | RAM, APB, timer, UART         |  <- upstream foundation
   | SDRAM, video, SD, SAO, ESP32  |  <- ULX3S project additions
   +-------------------------------+
         |
         v
   ECP5 FPGA and board peripherals

Stvarna ULX3S konfiguracija procesora
-------------------------------------

Fiksirani ULX3S FPGA wrapper odabire konfiguraciju RV32I usmjerenu na
performanse. Važne efektivne postavke su:

.. list-table::
   :header-rows: 1
   :widths: 34 18 48

   * - Značajka
     - Postavka projekta
     - Obrazovno značenje
   * - Osnovni ISA
     - RV32I
     - 32-bitni cjelobrojni ISA s 32 cjelobrojna registra.
   * - ``M``
     - Omogućeno
     - Hardverske instrukcije množenja, dijeljenja i ostatka.
   * - ``C``
     - Omogućeno
     - 16-bitne komprimirane instrukcije mogu se miješati s 32-bitnim instrukcijama.
   * - ``Zba`` / ``Zbb`` / ``Zbs``
     - Omogućeno
     - Generiranje adresa, osnovna manipulacija bitovima i operacije nad pojedinačnim bitovima.
   * - ``Zifencei``
     - Omogućeno
     - Sinkronizacija dohvata instrukcija pomoću ``fence.i``.
   * - ``A``
     - Onemogućeno
     - Atomske memorijske instrukcije nisu dio ovog sintetiziranog CPU-a.
   * - Machine brojači
     - Omogućeno
     - Implementirani su CSR-ovi brojača ciklusa/umirovljenih instrukcija.
   * - Debug podrška
     - Omogućeno
     - CPU se povezuje s Hazard3 RISC-V Debug Moduleom.
   * - User mode / PMP
     - Nije omogućeno
     - Ovaj projekt je ugrađeni machine-mode sustav, a ne cilj za zaštićeni OS.
   * - CPU takt
     - Nominalno 50 MHz
     - Wrapper prosljeđuje ``CLK_MHZ=50`` example SoC-u.
   * - Prediktor grananja
     - Omogućeno
     - Sintetizira se Hazard3 mali prediktor grananja unatrag.

Točan wrapper je :hazard3-src:`fpga_ulx3s.v <example_soc/fpga/fpga_ulx3s.v>`.
Definicije generičkih parametara nalaze se u
:hazard3-src:`hazard3_config.vh <hdl/hazard3_config.vh>`.

Put učenja
----------

.. toctree::
   :maxdepth: 1

   overview
   pipeline
   isa-and-configuration
   memory-and-bus
   traps-and-interrupts
   debug
   project-integration
   source-tour
