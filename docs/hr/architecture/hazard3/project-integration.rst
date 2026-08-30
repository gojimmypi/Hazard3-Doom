Upstream Hazard3 i prilagodbe projekta
======================================

Najvažnije pravilo održavanja projekta Hazard3-Doom jest držati granicu
upstream procesora vidljivom. Dodana je velika količina hardvera kako bi Doom
bio praktičan na ULX3S/ULX4M, ali te dodatke ne treba zamijeniti za promjene
RISC-V ISA-e ili temeljnog Hazard3 cjevovoda.

Osnova usporedbe
----------------

Ova je stranica pregledana **2026-08-19** u odnosu na:

* snimku projekta: `ulx3s/Hazard3 na 736a74459b3f740c47803f20a62d820fcacbe5c3 <https://github.com/ulx3s/Hazard3/tree/736a74459b3f740c47803f20a62d820fcacbe5c3>`_;
* trenutačno održavanu upstream granu: `Wren6991/Hazard3 stable <https://github.com/Wren6991/Hazard3/tree/stable>`_.

Trenutačni upstream može se promijeniti nakon tog datuma. Prikvačeni SHA ostaje
izvor istine za ovdje dokumentirani build.

Standardni upstream procesorski materijal
-----------------------------------------

Sljedeće su komponente Hazard3 arhitekture ili ponovno upotrebljive upstream
infrastrukture, a ne izmjene specifične za Doom:

.. list-table::
   :header-rows: 1
   :widths: 34 66

   * - Područje
     - Standardna upstream uloga
   * - ``hdl/hazard3_core.v``
     - Trostupanjski in-order CPU cjevovod i arhitekturno upravljanje izvršavanjem.
   * - Front end / decoder / decompressor
     - RISC-V dohvat, dekodiranje, obrada komprimiranih instrukcija i uvjetovanje proširenja.
   * - ALU / multiply-divide blokovi
     - Cjelobrojno izvršavanje i konfigurabilni M/bit-manipulation datapathovi.
   * - CSR, PMP, power, IRQ, trigger moduli
     - Konfigurabilne arhitekturne/upravljačke značajke koje isporučuje Hazard3.
   * - ``hazard3_cpu_1port.v`` i ``hazard3_cpu_2port.v``
     - Ponovno upotrebljivi omotači koji transakcije jezgre prevode na sistemske AHB5 sabirnice.
   * - Hazard3 Debug Module i DTM
     - Standardna vanjska RISC-V podrška za debugiranje.
   * - ECP5 JTAGG DTM adapter
     - Upstream Hazard3 podrška za korištenje TAP-a ECP5 čipa s OpenOCD-om.
   * - Koncept minimalnog primjer-SoC-a
     - Referentna integracija CPU + debug + RAM + UART + timer.

U trenutačnom upstream stablu ``stable``, ``example_soc/soc`` ostaje kompaktan
oko osnovnih datoteka primjer-SoC-a i direktorija periferije. Nasuprot tome,
``example_soc/soc`` u prikvačenom ULX3S forku sadrži dodatne module za SDRAM,
SAO, SD i boot sliku. Ta razlika na razini direktorija snažno pokazuje gdje je
koncentrirana hardverska prilagodba ovog projekta.

Integracija specifična za projekt ili fork
------------------------------------------

Prikvačeni ULX3S fork dodaje sistemske značajke potrebne Doom platformi:

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Područje projekta
     - Namjena
   * - ``ahb_sdram.v`` / ``ulx3s_sdram_controller.v``
     - Povezuje vanjski SDR SDRAM na ULX3S i ULX4M-LS pločicama s procesorskim/sistemskim memorijskim sklopom.
   * - ``ahb_litedram.v`` / generirani LiteDRAM
     - Povezuje ULX4M-LD DDR3 kroz adapter taktnih domena između 50 MHz AHB-a i 75 MHz LiteDRAM/Wishbone sučelja.
   * - Video/izvorni SDRAM pristup
     - Omogućuje display cjevovodu korištenje framebuffer podataka bez predstavljanja videa kao CPU značajke.
   * - ``apb_sao_bridge.v``
     - Memorijski mapirano SAO upravljanje za firmware projekta.
   * - ``sao_i2c_engine.v`` / logika zajedničkog kontrolera
     - Implementira projektne I2C/SAO funkcije i izričito vlasništvo/arbitražu.
   * - ``sao_esp32_uart_bridge.v`` / ``sao_uart_phy.v``
     - Sporedna komunikacija i dijeljenje resursa s ESP32 suputnikom.
   * - ``apb_sd_spi.v``
     - APB-upravljani SD-card SPI mehanizam za samostalno učitavanje.
   * - Predpunjenje ``hazard3_boot.hex``
     - Smješta rezidentni monitor u interni EBR pri konfiguriranju FPGA-a.
   * - ULX3S omotač pločice/ograničenja
     - Povezuje SDRAM, HDMI/video, SD, SAO/ESP32, taktove i pinove pločice s proširenim SoC-om.

Što je točno dodao commit ``736a744``
-------------------------------------

Prikvačeni commit nosi naslov ``Add SD apb, improve SAO, introduce
hazard3_boot.hex``. Promjene su koncentrirane u primjer-SoC i ULX3S integraciju
pločice. Konkretno, dodaje SD APB blok, omogućuje SD SPI u ULX3S omotaču, dodaje
podršku za predpunjenje SRAM-a rezidentnim monitorom, ažurira SAO integraciju i
ulaze za sintezu/ograničenja potrebne tim značajkama.

To je upravo obrazac koji želimo očuvati: značajke pločice/aplikacije
implementiraju se oko procesora umjesto ugrađivanja ponašanja projekta u
generičku jezgru.

Odabrani CPU parametri su integracija, a ne CPU fork
----------------------------------------------------

Odabir Hazard3 parametara također je dio integracije projekta, ali nije isto
što i mijenjanje implementacije procesora. Na primjer:

.. code-block:: text

   EXTENSION_A       = 0
   EXTENSION_C       = 1
   EXTENSION_M       = 1
   EXTENSION_ZBA     = 1
   EXTENSION_ZBB     = 1
   EXTENSION_ZBS     = 1
   BRANCH_PREDICTOR  = 1

Te vrijednosti govore standardnom parametriziranom Hazard3 RTL-u koji hardver
treba sintetizirati. Projekt je vlasnik odabira; upstream je vlasnik generičkih
mehanizama.

Isto vrijedi za ``RESET_VECTOR=0x40`` i ``DEBUG_SUPPORT=1`` u CPU instanci
primjer-SoC-a. To su konfiguracijske odluke ovog sistema.

Zašto je ova granica važna
--------------------------

Za obrazovanje
   Studenti mogu proučavati stvarnu RISC-V jezgru bez prethodnog razdvajanja
   Doom grafike ili SD-card logike od CPU cjevovoda.

Za upstreaming
   Ponovno upotrebljivi popravci procesora pripadaju upstream Hazard3 projektu;
   značajke pločice/aplikacije trebaju ostati u forku ili se generalizirati
   prije predlaganja upstreamu.

Za debugiranje
   Ilegalna instrukcija najprije upućuje na ISA konfiguraciju/compile zastavice;
   kvar SDRAM/video/SD dijela najprije upućuje na integraciju SoC-a. Odvajanje
   tih domena smanjuje prostor pretraživanja.

Za nadogradnje
   Buduće ažuriranje Hazard3 submodula može se pregledati kroz dva pitanja:
   "što se promijenilo u upstream ponašanju procesora/debuga?" i "zadovoljava li
   naša okolna integracija i dalje ista sučelja?"

Vlasništvo repozitorija u Hazard3-Doomu
---------------------------------------

Superprojekt zato treba čitati kao tri sloja:

.. code-block:: text

   Hazard3-Doom application/monitor/scripts
                 |
                 v
   pinned ulx3s/Hazard3 integration fork
       |                    |
       |                    +-- project SoC/board additions
       v
   upstream Hazard3 CPU/debug architecture

Pogledajte :doc:`../repositories` za odgovarajući raspored
repozitorija/submodula.
