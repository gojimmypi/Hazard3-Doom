Vanjska memorija: SDRAM i DDR3
==============================

Vanjska memorija najveća je arhitekturna razlika između ULX4M-LS i ULX4M-LD.
Hazard3 i dalje izvršava obične RISC-V load/store operacije, ali se logika između
AHB sabirnice i fizičkog memorijskog čipa znatno razlikuje.

Vidi i :doc:`../../architecture/hazard3/memory-and-bus`.

ULX4M-LS: nativni SDR SDRAM
---------------------------

Trenutačni LS wrapper opisuje 32 MiB, 16-bitni SDR SDRAM i koristi istu obitelj
nativnih kontrolera kao ULX3S:

.. code-block:: text

   Hazard3/AHB -> ahb_sdram.v -> ulx3s_sdram_controller.v -> 16-bitni SDR SDRAM

Profil radi na 50 MHz i koristi 9-bitnu SDRAM column geometriju. Kontroler vodi
activate/precharge, CAS, refresh, byte maskiranje i arbitražu s videom.

ULX4M-LD: LiteDRAM DDR3
-----------------------

.. code-block:: text

   Hazard3 40 MHz -> AHB5 -> ahb_litedram.v -> CDC
       -> 128-bitni Wishbone 60 MHz -> LiteDRAM -> ECP5DDRPHY -> x16 DDR3

Generirani LiteDRAM core upravlja geometrijom, inicijalizacijom, rasporedom
naredbi, refreshem i DDR PHY-em. ``ahb_litedram.v`` namjerno zadržava isto
procesorsko sučelje kada se promijeni fizički DDR3 dio.

Podržane DDR3 obitelji profila
------------------------------

.. list-table::
   :header-rows: 1
   :widths: 29 20 20 31

   * - Projektni odabir
     - Gustoća
     - Kapacitet
     - LiteDRAM klasa
   * - ``MT41K512M16HA``
     - 8 Gbit x16
     - 1 GiB
     - ``MT41K512M16``
   * - ``AS4C256M16D3``
     - 4 Gbit x16
     - 512 MiB
     - ``AS4C256M16D3A``

Doom softverski profil trenutačno namjerno izlaže samo 64 MiB vanjske memorije;
preostali fizički kapacitet ne mora biti mapiran.

Trenutačno generirani profil
----------------------------

SERV i VexRisc generirani metapodaci uključeni u ovo izdanje odnose se na Micron
``MT41K512M16HA`` obitelj. Obje varijante bilježe:

.. code-block:: text

   FPGA: LFE5UM-85F-8BG381C
   LiteDRAM: 2024.12
   LiteX: 2024.12
   input/init clock: 25 MHz
   Hazard3 system clock: 40 MHz
   LiteDRAM user clock: 60 MHz
   DDR clock: 120 MHz
   user port: 128-bit Wishbone
   command buffer depth: 2
   command buffer buffered: true
   auto precharge: true

Generirana jezgra može koristiti SERV ili minimalni VexRiscv kao LiteX
inicijalizacijski CPU. Taj CPU dio je DDR inicijalizacijskog okruženja; nije
Hazard3 procesor koji kasnije pokreće Doom.

.. _fig-alliance-ddr3-variants:

.. figure:: ../../images/as4c256m16d3-flavors.png
   :alt: Varijante narudžbenih oznaka Alliance Memory AS4C256M16D3

   **Varijante obitelji Alliance AS4C256M16D3** - detalji narudžbene oznake važni
   su pri identifikaciji ugrađenog DDR3 uređaja; zabilježite punu oznaku kućišta,
   a ne samo osnovni naziv obitelji.

Regeneriranje za ugrađeni RAM
-----------------------------

Ne mijenjajte ručno generirani LiteDRAM Verilog. Koristite YAML profile:

.. code-block:: bash

   cd third_party/Hazard3/example_soc/third_party/LiteDRAM
   ./regenerate-ulx4m.sh MT41K512M16HA

ili:

.. code-block:: bash

   ./regenerate-ulx4m.sh AS4C256M16D3

Generator stvara ``generated-serv/`` i ``generated-vexrisc/`` i bilježi
provenance.

.. important::

   Generirani core mora odgovarati DDR3 dijelu na stvarnoj pločici. Campaign
   stranica, stara shema ili tuđa pločica nisu dovoljne za identifikaciju.

Geometrija i identifikacija
---------------------------

Kod x16 DDR3 geometrija adresiranja daje koristan trag vidljiv softveru. Dvije
trenutačno podržane obitelji razlikuju se po broju redaka i klasi kapaciteta.
Hazard3-Doom tijekom dijagnostike može koristiti destruktivno ispitivanje memorije
kako bi razlikovao uzorak aliasiranja klase 512 MiB od klase 1 GiB, ali to treba
shvatiti kao provjeru geometrije/vjerojatnosti, a ne kao elektroničko očitanje
JEDEC broja dijela.

Pri dokumentiranju pločice, kada je moguće zabilježite:

* oznaku na kućištu ugrađene memorije;
* puni broj dijela proizvođača ako je poznat;
* reviziju PCB-a;
* izvor sheme/sklopa korišten za usporedbu;
* naziv generiranog LiteDRAM profila; i
* rezultat hardverske kvalifikacije.

DDR3 kvalifikacija
------------------

Samo zatvaranje timinga nije dovoljno. Micron put kvalificiran za izdanje
provjeren je destruktivnim sekvencijalnim uzorcima, rijetkim provjerama
aliasiranja/adresa, pseudoslučajnim testovima u odvojenim memorijskim regijama,
punim kvalifikacijskim skupom monitora, opterećenjem hrpe, brzim testom Doom
platforme i izvršavanjem kopiranog RV32 koda iz DDR-a.

Ta je sekvenca namjerno stroža od tvrdnje "LiteDRAM se kalibrirao". Kalibracija
dokazuje da je PHY završio inicijalizaciju; ne dokazuje ispravnost svake adresne
linije, podatkovnog voda, interakcije predmemorije ili dugotrajnog softverskog
pristupa.

Električko sučelje
------------------

LD najviša razina izlaže uobičajeno x16 DDR3 sučelje: adresu, tri bita banke,
RAS/CAS/WE, CKE, CS, ODT, reset, dvije trake maske podataka, šesnaest dvosmjernih
DQ bitova, dvije DQS bajtne trake i diferencijalni takt. LPF dodjeljuje te signale
ECP5 pinovima i primjenjuje SSTL/diferencijalna I/O ograničenja prikladna za DDR3.

Ta su ograničenja dio memorijskog kontrolera. Ispravan LiteDRAM YAML s pogrešnim
LPF-om nije valjan DDR3 dizajn.

Vanjske reference
-----------------

* `LiteDRAM <https://github.com/enjoy-digital/litedram>`_ - konfigurabilni
  generator DRAM kontrolera/PHY-a koji koristi ULX4M-LD put.
* `Alliance Memory AS4C256M16D3 stranica proizvoda <https://www.alliancememory.com/as4c256m16d3/>`_ -
  aktualna obitelj dijela i poveznice na podatkovne listove.
* `Lattice ECP5 / ECP5-5G resursi <https://www.latticesemi.com/ecp5>`_ - podatkovni
  listovi FPGA obitelji i dokumentacija vezana uz DDR.
* :doc:`sources` - ULX4M sheme, repozitoriji pločica i hijerarhija izvornog koda projekta.
