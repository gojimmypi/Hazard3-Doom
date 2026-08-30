Memorija i sabirničko sučelje
=============================

Hazard3 odvaja procesorski cjevovod od sistemske memorijske mape. To je
odvajanje posebno važno u projektu Hazard3-Doom jer je većina velikog
memorijskog i grafičkog sklopa dodatak SoC-a specifičan za projekt, a ne dio
CPU jezgre.

Transakcijska sučelja na strani jezgre
--------------------------------------

`hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_ ima logički odvojene kanale
za:

* dohvat instrukcija; i
* pristupe podacima za učitavanje/spremanje.

To omogućuje da se ista jezgra ugradi u različite sistemske arhitekture.
Standardni Hazard3 omotači prikazuju dva uobičajena izbora:

``hazard3_cpu_2port``
   Zadržava AHB5 promet instrukcija i podataka na odvojenim glavnim portovima.

``hazard3_cpu_1port``
   Arbitrira zahtjeve instrukcija i podataka na jedan AHB5 glavni port.

Hazard3-Doom instancira
`hazard3_cpu_1port.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_cpu_1port.v>`_. Ovo je prvo mjesto
na kojem student treba razlikovati **paralelizam cjevovoda** od **paralelizma
memorijske sabirnice**: i F i M mogu istodobno imati razlog za pristup
memoriji, ali jednoulazni omotač mora serijalizirati pristup zajedničkom
vanjskom glavnom sučelju.

AHB5 pojmovi vidljivi u omotaču
-------------------------------

Omotač izlaže poznate AHB signale adresne/upravljačke i podatkovne faze,
uključujući adresu, vrstu prijenosa, veličinu, smjer pisanja, odgovor, ready te
podatke za čitanje/pisanje. Sadrži i signale za ekskluzivni pristup koji se
koriste kada se sintetizira opcionalno Hazard3 proširenje ``A``.

Projekt onemogućuje ``EXTENSION_A``, pa softver u ovom bitstreamu ne može
izvršavati RISC-V atomske memorijske instrukcije, iako standardni omotač ima
potrebnu sabirničku infrastrukturu za konfiguracije koje ih omogućuju.

Hijerarhija sabirnice SoC-a
---------------------------

Na visokoj razini, memorijski put projekta izgleda ovako:

.. code-block:: text

                     +-------------------+
   instruction ----->|                   |
                     | hazard3_cpu_1port |---- AHB5 ----+
   load/store ------>|                   |              |
                     +-------------------+              v
                                                +---------------+
                                                | example SoC   |
                                                | decode/fabric |
                                                +---------------+
                                                  |     |     |
                                                SRAM  APB   SDRAM

CPU ne mora znati završava li neka adresa u ECP5 blokovskom RAM-u, APB UART-u,
vanjskom SDRAM-u ili projektnom video prozoru. Izdaje uobičajeno arhitekturno
učitavanje/spremanje, a dekodiranje adrese u SoC-u određuje odredište.

Reset vektor i rezidentni SRAM
------------------------------

Prikvačeni primjer SoC-a instancira procesor s:

.. code-block:: text

   RESET_VECTOR = 0x00000040

ULX3S omotač konfigurira 128 KiB interne SRAM memorije i koristi
``hazard3_boot.hex`` kao sliku za predpunjenje. To je prilagodba ovog projekta:
omogućuje da rezidentni monitor bude prisutan odmah nakon konfiguriranja FPGA-a,
tako da hladno pokretanje ne ovisi o prethodnom preuzimanju koda kroz debugger.

Relevantne lokacije izvornog koda su:

* `example_soc.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/example_soc.v>`_ - CPU reset vektor i
  integracija memorije/periferije SoC-a.
* `fpga_ulx3s.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/fpga/fpga_ulx3s.v>`_ - dubina SRAM-a od 128 KiB,
  naziv datoteke za predpunjenje, opcije pločice i odabrani CPU parametri.
* `hazard3_boot.hex <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/hazard3_boot.hex>`_ - generirana
  inicijalizacijska slika rezidentnog monitora u ovoj snimci forka.

Pogledajte :doc:`../memory-map` za memorijsku mapu projekta Hazard3-Doom
vidljivu softveru.

Vanjski DRAM nije značajka Hazard3 CPU-a
----------------------------------------

Velika Doom slika, heap, IWAD podaci i video međuspremnici u projektu nalaze se
u vanjskoj memoriji. Podrška za tu memoriju nalazi se u integraciji primjer-SoC-a
u forku. ULX3S i ULX4M-LS koriste izvorni SDR SDRAM put, dok ULX4M-LD koristi
LiteDRAM DDR3 put.

Ovo je ključna arhitekturna granica:

* **Odgovornost upstream CPU-a:** izvršavati učitavanja/spremanja i poštovati
  ready/error odgovore sabirnice.
* **Odgovornost projektnog SoC-a:** dekodirati adresne prozore vanjske memorije,
  implementirati predmemoriranje/aliase gdje je konfigurirano, arbitrirati
  korisnike memorije i upravljati memorijskim sučeljem pločice.

CPU učitavanje s adrese ``0x20xxxxxx`` nije posebna "SDRAM instrukcija". To je
uobičajeno RISC-V učitavanje čija se fizička adresa usmjerava prema podsustavu
vanjske memorije.

Implementacije memorijskih kontrolera
-------------------------------------

Hazard3-Doom koristi tri različita memorijska mehanizma. Interni ECP5 EBR je
sinkroni blokovski SRAM unutar FPGA-a i ne treba DRAM kontroler. SDR SDRAM i
DDR3 komponente na pločicama zasebne su vanjske memorije i zahtijevaju
kontrolere koji upravljaju refreshom i DRAM timingom.

.. list-table::
   :header-rows: 1
   :widths: 19 20 27 34

   * - Cilj/memorija
     - Fizičko sučelje
     - Put kontrolera
     - Važno ponašanje
   * - Interni ECP5 EBR
     - Ugrađeni sinkroni SRAM
     - ``ahb_sync_sram`` / inferirani EBR
     - Nema activate/precharge operacija, refresha ni DRAM treninga. To je
       memorija s najmanjom i najpredvidljivijom latencijom, ali EBR kapacitet
       je ograničen.
   * - ULX3S 12F/85F
     - Vanjski 16-bitni SDR SDRAM
     - ``ahb_sdram.v`` -> ``ulx3s_sdram_controller.v``
     - Izvorni projektni SDR kontroler. Prihvaća jedan zahtjev kontrolera
       odjednom, drži retke otvorenima kada je moguće, koristi CAS latenciju 2 i
       periodično radi precharge radi refresha. CPU i video zahtjevi arbitriraju
       se u AHB/SDRAM adapteru.
   * - ULX4M-LS 85F
     - Vanjski 16-bitni SDR SDRAM, komponenta od 32 MiB na pločici
     - ``ahb_sdram.v`` -> ``ulx3s_sdram_controller.v``
     - Koristi isti izvorni SDR memorijski podsustav kao ULX3S put pri sistemskom
       taktu od 50 MHz. Omotač pločice prosljeđuje SDRAM takt pomaknut za pola
       ciklusa i drži video na zasebnom PLL-u.
   * - ULX4M-LD 85F
     - Vanjski DDR3
     - ``ahb_litedram.v`` -> generirani LiteDRAM -> ``ECP5DDRPHY``
     - LiteDRAM koristi 75 MHz korisnički port sa 128-bitnim Wishbone sučeljem,
       dok Hazard3/AHB radi na 50 MHz. Adapter prelazi između taktnih domena po
       jedan zahtjev odjednom. Firmware za pokretanje izvodi DDR3 inicijalizaciju,
       read leveling i memorijski test prije omogućavanja normalnih pristupa.

Ta dva puta vanjske memorije zato imaju različite performansne kompromise.
Izvorni SDR kontroler jednostavniji je i ima manje sučeljske logike, ali vanjski
SDR SDRAM i dalje ima activate/CAS/refresh latenciju. DDR3 nudi znatno veću burst
propusnost, dok trenutačni ULX4M-LD adapter dodaje prijelaz između taktnih domena
i pretvorbu zahtjeva. Konkretno, trenutačni adapter mapira svaki DDR3 BL8 prijenos
na jednu 128-bitnu Wishbone riječ; zapisi koriste atomski 128-bitni
read/modify/write prije zapisivanja cijelog bursta. Za in-order Hazard3 jezgru
latencija prvog pristupa i ponašanje predmemorije mogu biti važniji od vršne DDR
propusnosti.

Nemojte brkati vanjski SDRAM na ULX3S-u s ECP5 EBR-om. EBR je SRAM fizički unutar
FPGA-a; SDR SDRAM čip zasebna je komponenta na pločici. LiteDRAM se ne koristi u
izvornom SDR putu ULX3S-a.

Redoslijed memorijskih operacija i ``fence.i``
----------------------------------------------

Projekt omogućuje ``Zifencei``. ``fence.i`` služi za sinkronizaciju dohvata
instrukcija s prethodnim zapisima koji su možda promijenili memoriju instrukcija.
Hazard3 izlaže namjeru memorijskog redoslijeda/ispiranja dohvata kako bi okolni
sistem mogao sudjelovati kada je potrebno. To postaje važnije kako SoC dobiva
predmemorije ili drugo stanje između jezgre i memorije.

Za samomodificirajući kod ili loader koji zapisuje izvršnu memoriju i zatim
skače u nju, korisno je razumjeti ovaj slijed:

.. code-block:: text

   write new instruction bytes
          |
          v
   complete required data ordering
          |
          v
       fence.i
          |
          v
   fetch newly written instructions

Točan put učitavanja softvera u Hazard3-Doomu obrađuju rezidentni monitor i
projektni memorijski sistem, ali mehanizam sinkronizacije dohvata instrukcija
standardno je RISC-V/Hazard3 ponašanje.

Nema MMU-a u ovom projektu
--------------------------

Ova konfiguracija je bare-metal ugrađeni sistem. Ne omogućuje MMU za virtualnu
memoriju niti izolaciju korisničkog načina/PMP-a. Adrese u
:doc:`../memory-map` zato je najbolje razumjeti kao fizičke adresne prozore
SoC-a koje izravno koriste firmware u strojnom načinu i Doom aplikacija.
