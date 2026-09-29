Memorija i sabirničko sučelje
=============================

Hazard3 odvaja procesorski cjevovod od sistemske memorijske mape. To je
odvajanje posebno važno u projektu Hazard3-Doom jer je većina velikog
memorijskog i grafičkog sklopa dodatak SoC-a specifičan za projekt, a ne dio
CPU jezgre.

Transakcijska sučelja na strani jezgre
--------------------------------------

:hazard3-src:`hazard3_core.v <hdl/hazard3_core.v>` ima logički odvojene kanale
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
:hazard3-src:`hazard3_cpu_1port.v <hdl/hazard3_cpu_1port.v>`. Ovo je prvo mjesto
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

* :hazard3-src:`example_soc.v <example_soc/soc/example_soc.v>` - CPU reset vektor i
  integracija memorije/periferije SoC-a.
* :hazard3-src:`fpga_ulx3s.v <example_soc/fpga/fpga_ulx3s.v>` - dubina SRAM-a od 128 KiB,
  naziv datoteke za predpunjenje, opcije pločice i odabrani CPU parametri.
* :hazard3-src:`hazard3_boot.hex <example_soc/soc/hazard3_boot.hex>` - generirana
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
     - LiteDRAM koristi 60 MHz korisnički port sa 128-bitnim Wishbone sučeljem,
       dok Hazard3/AHB radi na 40 MHz. Adapter prelazi između taktnih domena po
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


ULX4M-LD DDR3 konfiguracija i kvalifikacija
-------------------------------------------

Proizvodne ULX4M-LD pločice ne moraju sve sadržavati isti DDR3 uređaj. Projekt je
namijenjen podršci najmanje sljedećih x16 dijelova kroz zasebne generirane
LiteDRAM profile:

.. list-table::
   :header-rows: 1
   :widths: 28 22 20 30

   * - Uređaj
     - Gustoća
     - Približan kapacitet
     - Projektna napomena
   * - Micron ``MT41K512M16HA``
     - 8 Gbit, x16
     - 1 GiB
     - Trenutačno hardverski kvalificirana pločica koristi ovu obitelj. LiteDRAM
       geometrija ima 16 bitova retka, 10 bitova stupca i 3 bita banke.
   * - Alliance ``AS4C256M16D3``
     - 4 Gbit, x16
     - 512 MiB
     - Podržan kao alternativna populacija pločice kroz drugi generirani
       LiteDRAM modul/profil.

Fizički kapacitet čipa veći je od trenutačne Hazard3-Doom softverske mape.
Hazard3-Doom namjerno izlaže profil vanjske memorije od 64 MiB na
``0x20000000-0x23ffffff`` uz dijagnostički alias; neiskorišten fizički kapacitet
nije potreban trenutačnom softveru.

Odabir čipa pripada generiranoj LiteDRAM konfiguraciji, a ne datoteci
``ahb_litedram.v``. Sučelje AHB-LiteDRAM mosta ostaje isto dok se generirana jezgra
mijenja prema memorijskom uređaju, inicijalizacijskom CPU-u, frekvenciji i drugim
postavkama profila izgradnje. Time razlike u populaciji pločice ostaju izvan
Hazard3 sučelja sistemske sabirnice.

Trenutačno hardverski kvalificirane LiteDRAM postavke su:

.. code-block:: text

   memtype: DDR3
   phy: ECP5DDRPHY
   input/reference clock: 25 MHz
   LiteDRAM user clock: 60 MHz
   LiteDRAM init clock: 25 MHz
   Hazard3/AHB system clock: 40 MHz
   user port: 128-bit Wishbone
   cmd_buffer_depth: 2
   cmd_buffer_buffered: true
   with_auto_precharge: true
   initialization CPU: SERV for the qualified checkpoint

``cmd_buffer_depth=0`` odbačen je tijekom timing eksperimenata jer je stvarao
kombinacijske petlje/probleme s timingom. Kvalificirani profil zadržava dubinu 2.
``with_auto_precharge`` ostaje ``true`` u kvalificiranoj konfiguraciji.

Inicijalizacijski CPU (primjerice SERV ili VexRiscv) dio je generirane LiteDRAM
jezgre i ne mijenja sučelje sabirnice ``ahb_litedram.v``. Držite odvojene
generirane profile kako bi se vrsta CPU-a, DDR uređaj i frekvencija korisničkog
takta mogli programski sweepati bez ručnog uređivanja generiranog Veriloga.

Verzionirani YAML profili izvor su koji se uređuje za te generirane jezgre.
Odaberite fizički broj RAM dijela; jedna naredba regenerira obje CPU varijante:

.. code-block:: bash

   cd third_party/Hazard3/example_soc/third_party/LiteDRAM
   ./regenerate-ulx4m.sh MT41K512M16HA
   ./regenerate-ulx4m.sh AS4C256M16D3

Svako pokretanje zamjenjuje ``generated-serv/`` i ``generated-vexrisc/`` odabranim
RAM profilom. Prije izgradnje za pločicu potvrdite ``ram_part`` zapisan u
``LITEDRAM_VERSIONS.txt`` svakog generiranog direktorija.

Hardverska kvalifikacija više je od nextpnr timing PASS-a. Na kvalificiranoj
Micron pločici monitor je uspješno izvršio sve sljedeće testove na LiteDRAM
routingu od 60 MHz:

* destruktivni sekvencijalni test od 1 MiB s pristupima bajt/poluriječ/riječ i
  uzorcima nula, jedinica, adrese i invertirane adrese;
* rijetko testiranje aliasiranja/adresa kroz cijeli softverski vidljiv prozor od
  64 MiB;
* pseudoslučajne testove od 1 MiB u četiri odvojene regije razmaknute 16 MiB;
* cijeli ``q`` kvalifikacijski skup, ponovljeno;
* test alokacije/opterećenja hrpe od 40 MiB;
* brzi test Doom platformske memorije/timera; i
* izvršavanje kopiranog RV32 koda iz DDR-a, uključujući faze s normalnim i stranim
  GP-om, prekide timera i zaštitne provjere.

Naredba stanja mjerodavna je nakon pokretanja. Tijekom jednog pokretanja rezidentni
monitor ispisao je 5-sekundni ``TIMEOUT`` vanjske memorije dok se LiteDRAM još
kalibrirao, ali kasniji ``s`` pokazao je ``external_memory_ready=YES``,
``init_done=YES``, ``init_error=NO``, ``pll_locked=YES``,
``user_clock_ready=YES`` i ``ready=YES``. Svi naknadni kvalifikacijski testovi
prošli su. Zato početnu poruku o isteku vremena ne treba smatrati konačnim DDR
kvarom bez provjere trenutačnog stanja.

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

Povezane poveznice
------------------

* `nextpnr-ecp5 <https://github.com/YosysHQ/nextpnr>`_

* `Yosys <https://github.com/YosysHQ/yosys>`_
