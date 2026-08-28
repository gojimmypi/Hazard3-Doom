Hazard3 RISC-V procesor
=======================

Hazard3 je procesor u središtu Hazard3-Dooma. To je kompaktan, in-order,
trostupanjski 32-bitni RISC-V CPU namijenjen FPGA i ASIC primjenama. Projekt
Hazard3 također pruža okolni debug hardver i primjer SoC integracije koji se
koriste za pretvaranje CPU jezgre u upotrebljiv sustav.

Ovaj odjeljak objašnjava procesor iz obrazovne perspektive i, jednako važno,
odvaja **standardni Hazard3 dizajn** od **ULX3S/Hazard3-Doom integracije**
izgrađene oko njega.

Snimak izvornog koda koji ovaj projekt koristi
----------------------------------------------

Tehnički opisi na ovim stranicama vezani su uz Hazard3 snimak izvornog koda
korišten za ovaj pregled dokumentacije:

* commit ULX3S Hazard3 forka: ``736a74459b3f740c47803f20a62d820fcacbe5c3``
* `Pregled fiksiranog izvora <https://github.com/ulx3s/Hazard3/tree/736a74459b3f740c47803f20a62d820fcacbe5c3>`_
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

Točan wrapper je `fpga_ulx3s.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/fpga/fpga_ulx3s.v>`_.
Definicije generičkih parametara nalaze se u
`hazard3_config.vh <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_config.vh>`_.

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
