ECP5 timing i seed sweepovi
===========================

Hazard3-Doom pokreće više nextpnr-ecp5 place-and-route prolaza radi
karakterizacije ECP5 timinga, odabira korisnih seedova, usporedbe placement i
routing postavki te otkrivanja timing regresija nakon promjena RTL-a ili
generiranog jezgrenog modula. Iste sweep skripte koriste se lokalno i u GitHub
Actions workflowu ``ECP5 seed sweep``.

Sweep nije samo traženje sretnog seeda. To je i reproducibilan eksperiment:
sintetizirati jedan netlist, routati upravo taj netlist mnogo puta, zabilježiti
alatni lanac i konfiguraciju te usporediti sve obavezne domene takta.

Zašto su seedovi važni
----------------------

nextpnr koristi seed za dio nasumičnih odluka pri placementu i routingu. Različiti
seedovi zato istražuju različite fizičke implementacije istog sintetiziranog
dizajna. Jedan seed može poboljšati jednu domenu takta, a pogoršati drugu.

Broj seeda ne određuje njegovu kvalitetu. Seed koji je prolazio na starijem
netlistu treba nakon značajne promjene RTL-a, generiranog LiteDRAM jezgrenog
modula, taktova, geometrije memorije, framebuffera, ograničenja, sinteze ili CAD
alata smatrati samo povijesnom referencom.

Za korisne A/B usporedbe koristite **isti skup seedova** za svaku konfiguraciju.

Što znači timing PASS
---------------------

Routani seed prolazi samo ako sve obavezne domene takta za cilj zadovolje
ograničenja u istom routeu.

.. list-table:: Obavezni routani taktovi
   :header-rows: 1
   :widths: 22 18 18 18 18 18

   * - Cilj
     - ``clk_sys``
     - LiteDRAM user
     - Video pixel
     - TMDS x5
     - LiteDRAM init
   * - ULX3S 85F
     - 50 MHz
     - n/a
     - 50 MHz
     - 250 MHz
     - n/a
   * - ULX3S 12F
     - 40 MHz
     - n/a
     - 50 MHz
     - 250 MHz
     - n/a
   * - ULX4M-LD 85F
     - Odabire workflow; zadano 40 MHz
     - 60 MHz
     - 50 MHz
     - 250 MHz
     - 25 MHz

Route proces može završiti uspješno, a timing status ipak biti ``FAIL``. Sweep
namjerno koristi nextpnr način ``timing-allow-fail`` kako bi sačuvao mjerenja i
za routove koji ne zatvaraju timing.


Kvalificirana ULX4M-LD kontrolna točka 40/60 MHz
------------------------------------------------

Trenutačna hardverski kvalificirana ULX4M-LD kontrolna točka koristi:

.. code-block:: text

   Hazard3/AHB:          40 MHz
   LiteDRAM user:        60 MHz
   LiteDRAM reference:   25 MHz
   LiteDRAM init:        25 MHz
   LiteDRAM init CPU:    SERV
   nextpnr placer:       heap
   timingweight:         30
   critexp:              3
   timing-driven rip-up: enabled
   seed:                 2

SHA256 zamrznute sintetizirane netliste je:

.. code-block:: text

   160c536b12e46667990c887571da6f443ccc6c5a2ba644033db43fc783ea9453

Za tu točnu netlistu seed 2 dosegnuo je 43,94 MHz za ``clk_sys`` i 67,81 MHz za
LiteDRAM korisnički takt, čime je zadovoljio zahtjeve 40/60 MHz. Točan SHA256
lokalno hardverski testiranog bitstreama je:

.. code-block:: text

   294602982dfc4a9906961f2e8b6f43de925d8c11a7e5e6bb0f5e392965a868de

Ista netlista i seedovi **nisu** pouzdano zatvarali timing s ranijim HeAP
postavkama ``timingweight=10``, ``critexp=2`` bez rip-upa. Zato metapodaci sweepa
moraju bilježiti podešavanje place/route alata uz seed i hash netliste.

Nakon statičkog timinga provedena je stvarna DDR kvalifikacija na pločici s
Micron memorijom. Routing je prošao sekvencijalni test 1 MiB, puni rijetki test
aliasiranja 64 MiB, pseudoslučajni test u četiri regije, ponovljeni ``q``, stres
hrpe 40 MiB, Doom test memorije/timera i izvršavanje kopiranog RV32 koda iz DDR-a.
Nemojte novi routing označiti hardverski kvalificiranim samo na temelju nextpnr
timinga.

Za ponavljanje poznatog dobrog eksperimenta routinga nad već zamrznutom
odgovarajućom netlistom:

.. code-block:: bash

   SWEEP_SKIP_SYNTH=1 \
   SWEEP_JOBS=1 \
   SWEEP_ROUTE_TIMEOUT_SECONDS=1200 \
   SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT=30 \
   SWEEP_NEXTPNR_HEAP_CRITEXP=3 \
   SWEEP_NEXTPNR_TMG_RIPUP=1 \
       ./scripts/sweep-ecp5.sh ulx4m-ld-85f 2

``SWEEP_SKIP_SYNTH=1`` koristite tek nakon provjere hasha zamrznute netliste i
svih metapodataka profila. Ponovna izgradnja preload monitora, profil DDR uređaja,
generirana LiteDRAM jezgra, takt, RTL promjena ili promjena alata za sintezu
poništava usporedbu sa zamrznutom netlistom i zahtijeva novu sintezu pa novi sweep.

Čuvanje ULX4M-LD bitstreama za hardverski test
----------------------------------------------

ULX4M-LD sweep uobičajeno sprema timing dnevnike/rezultate i ne mora pakirati
svaki istraživački routing. Kada seed vrijedi odnijeti na hardver, izričito
sačuvajte nextpnr tekstualnu konfiguraciju. Za kvalificirani seed-2 eksperiment:

.. code-block:: bash

   SWEEP_SKIP_SYNTH=1 \
   SWEEP_JOBS=1 \
   SWEEP_ROUTE_TIMEOUT_SECONDS=1200 \
   SWEEP_NEXTPNR_HEAP_TIMINGWEIGHT=30 \
   SWEEP_NEXTPNR_HEAP_CRITEXP=3 \
   SWEEP_NEXTPNR_TMG_RIPUP=1 \
   SWEEP_NEXTPNR_EXTRA_ARGS="--textcfg build/ulx4m-ld-test/fpga_ulx4m_ld-seed2.config" \
       ./scripts/sweep-ecp5.sh ulx4m-ld-85f 2

Zatim zapakirajte tu **već routanu** konfiguraciju bez ponovnog pokretanja
nextpnr-a:

.. code-block:: bash

   ecppack \
       --compress \
       --svf build/ulx4m-ld-test/fpga_ulx4m_ld-seed2.svf \
       --idcode 0x01113043 \
       build/ulx4m-ld-test/fpga_ulx4m_ld-seed2.config \
       build/ulx4m-ld-test/fpga_ulx4m_ld-seed2.bit

Nemojte koristiti praktičnu skriptu za bitstream koja potajno ponovno pokreće
nextpnr s drugačijim/zadanim postavkama place alata; time bi nastao drugačiji
routing od timing rezultata koji se kvalificira. Prije hardverskog testa
provjerite hash netliste, routing postavke, seed i završni SHA256 bitstreama.

Lokalni sweep
-------------

Razdjelnik ciljeva je ``scripts/sweep-ecp5.sh``. Skripte za pojedine pločice
nude izravne ulazne točke:

.. code-block:: bash

   ./scripts/sweep-ecp5.sh --list-targets
   ./scripts/sweep-ulx3s-85f.sh 1-32
   ./scripts/sweep-ulx3s-12f.sh 1-32
   ./scripts/sweep-ulx4m-ld.sh 1-32

``SWEEP_JOBS`` određuje lokalni paralelizam:

.. code-block:: bash

   SWEEP_JOBS=8 ./scripts/sweep-ulx4m-ld.sh 1-32

Jedan nextpnr proces može trošiti nekoliko stotina MiB memorije. Veći
``SWEEP_JOBS`` skraćuje vrijeme samo dok CPU, RAM, disk i host sustav mogu
podnijeti dodatno opterećenje.

.. _fig-concurrent-nextpnr-ecp5:

.. figure:: ../images/concurrent-nextpnr-ecp5.png
   :alt: Više paralelnih nextpnr-ecp5 procesa tijekom lokalnog sweepa
   :class: screenshot

   Lokalno je moguće paralelno routati više seedova. ``SWEEP_JOBS`` prilagodite
   stvarnim resursima računala.

Tijek normalno sintetizira jednom i isti netlist koristi za sve seedove.
``SWEEP_SKIP_SYNTH=1`` koristite samo ako postojeći netlist sigurno odgovara
trenutačnim izvorima, taktovima i opcijama.

GitHub Actions sweep
--------------------

Trenutačni workflow je
``.github/workflows/ulx4m-ld-seed-sweep.yml``. U sučelju se prikazuje kao
``ECP5 seed sweep``, a birač cilja podržava ULX3S 85F, ULX3S 12F i ULX4M-LD 85F.

Workflow se ručno pokreće preko ``workflow_dispatch`` i namjerno odvaja sintezu
od routinga kako bi svi route jobovi koristili isti zamrznuti netlist.

Concurrency je grupiran po cilju i Git refu uz ``cancel-in-progress: false`` pa
novi run za isti cilj/ref ne služi za prekid već pokrenutog sweepa.

Parametri workflowa
~~~~~~~~~~~~~~~~~~~

.. list-table:: GitHub sweep parametri
   :header-rows: 1
   :widths: 22 18 60

   * - Parametar
     - Zadano
     - Namjena
   * - ``target``
     - ``ulx3s-85f``
     - ``ulx3s-85f``, ``ulx3s-12f`` ili ``ulx4m-ld-85f``.
   * - ``seed_first`` / ``seed_last``
     - 1 / 260
     - Uključivi raspon seedova. Trenutačni GitHub workflow dopušta 1-260.
       Za eksperimente prvo koristite manji raspon.
   * - ``max_parallel``
     - 20
     - Najveći broj istodobnih GitHub route jobova: 4, 8, 12 ili 20.
   * - ``seeds_per_job``
     - 2
     - Seedovi koji se serijski routaju unutar jednog joba: 1-5. Dva smanjuje
       posljedice iznimno sporog seeda.
   * - ``retain_bitstreams``
     - false
     - Čuvanje ``.bit`` datoteke za svaki seed. Za velike istraživačke sweepove
       ostavite isključeno ako bitstreamovi neće biti testirani na pločici.
   * - ``ulx3s_85f_extended_modes``
     - 1
     - Uključuje prošireni HDMI profil za ULX3S 85F.
   * - ``ulx3s_12f_memory_profile``
     - ``32m``
     - SDRAM profil 12F: ``32m`` ili ``64m``.
   * - ``ulx4m_sys_clk_mhz``
     - 40
     - Hazard3 CPU/AHB takt za ULX4M-LD: 25, 40 ili 50 MHz. LiteDRAM user domena
       ostaje zasebna na 60 MHz.
   * - ``ulx4m_litedram_cpu``
     - ``serv``
     - CPU unutar generiranog LiteDRAM init jezgrenog modula: ``serv`` ili
       ``vexrisc``.
   * - ``placer``
     - ``heap``
     - HeAP ili simulated annealing ``sa``. SA može biti znatno sporiji i treba
       ga prvo testirati na malom skupu seedova.
   * - ``router``
     - ``router1``
     - ``router1`` ili ``router2``; uspoređujte ih na istom netlistu i istim
       seedovima.
   * - ``heap_timingweight``
     - 10
     - HeAP timing težina: 10, 20, 30 ili 40.
   * - ``heap_critexp``
     - 2
     - HeAP eksponent kritičnosti: 2, 3 ili 4.
   * - ``tmg_ripup``
     - false
     - Uključuje eksperimentalni timing-driven rip-up.
   * - ``router2_alt_weights``
     - false
     - Uključuje alternativne težine za Router2.
   * - ``nextpnr_extra_args``
     - prazno
     - Dodatni napredni nextpnr argumenti. Njihova uporaba mora biti dio
       zabilježene eksperimentalne konfiguracije.
   * - ``synth_oss_cad_suite_version``
     - ``2026-07-20``
     - OSS CAD Suite verzija za sintezu.
   * - ``route_oss_cad_suite_version``
     - ``2026-07-20``
     - OSS CAD Suite verzija za route jobove; može se namjerno razlikovati radi
       kontrolirane usporedbe nextpnr verzija.

``max_parallel`` i ``seeds_per_job`` imaju različite uloge. Za ``N`` seedova
workflow stvara približno ``ceil(N / seeds_per_job)`` route jobova. Najviše
``max_parallel`` jobova radi istodobno, a seedovi unutar svakog joba obrađuju se
serijski. Raspon 1-260 s dva seeda po jobu daje 130 route jobova.


Zašto dva seeda po GitHub jobu
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Pojedini seed ponekad traje dramatično dulje od susjednih. Velike grupe seedova
omogućuju takvom sporom seedu da zadrži runner i odgodi više seedova iza sebe.
Vrlo male grupe povećavaju trošak checkouta, artefakata i pokretanja runnera.
Zadana vrijednost od dva seeda po jobu praktičan je kompromis koji ograničava
posljedice kvara.

Matrica koristi ``fail-fast: false`` pa jedna routing grupa ne otkazuje sve
ostale. To je važno za karakterizaciju: loš seed ne smije sakriti korisne
rezultate nepovezanih seedova.

Arhitektura jobova
------------------

Workflow ima četiri logičke cjeline: ``prepare``, ``watch``, ``route`` i
``summarize``.

.. list-table:: Timeouti GitHub jobova
   :header-rows: 1
   :widths: 24 20 56

   * - Job
     - Timeout
     - Napomena
   * - ``prepare``
     - 90 min
     - Sinteza, provenance, matrica i objava zamrznutih ulaza.
   * - ``watch``
     - 360 min
     - Live collector artifacts rezultata.
   * - ``route``
     - 350 min
     - Obuhvaća cijelu matrix grupu i sve serijske seedove u njoj.
   * - ``summarize``
     - 60 min
     - Preuzimanje, agregacija, provjera potpunosti i završni artifact.

Budući da timeout ``route`` joba pokriva cijelu grupu, velika vrijednost
``seeds_per_job`` postaje rizična ako više seedova dođe blizu svog watchdog
limita.

``prepare``: zamrzavanje eksperimenta
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``prepare`` provjerava parametre, postavlja alatni lanac, inicijalizira potrebne
podmodule, sintetizira cilj samo jednom, bilježi SHA256 netlista, Git revizije i
gitlinkove, verzije alata i parametre workflowa, generira matricu seed grupa te
objavljuje zamrznutu arhivu ulaza za routing.

Svaki route job ponovno provjerava SHA256 prije pokretanja nextpnr-a. Time se
sprječava usporedba različitih netlista unutar istog sweepa.

Zamrznuti ulazni artifact i artifacts pojedinih grupa trenutačno se čuvaju jedan
dan. Završni sažeti sweep artifact čuva se 14 dana; spremite ga drugdje kada
postane dugoročna projektna kontrolna točka.

``route``: neovisni runneri
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Svaki matrix job dobiva vlastiti Ubuntu runner; runneri ne dijele datotečni
sustav. Job preuzima zamrznutu arhivu, provjerava hash, vraća traženu verziju
nextpnr-a i serijski routa dodijeljene seedove uz ``SWEEP_JOBS=1`` i
``SWEEP_SKIP_SYNTH=1``.

Za svaki seed čuvaju se konzolni izlaz, route logovi, CSV rezultat, trajanje,
izlazni status, SHA256 netlista i po želji bitstream.

``watch``: live timing monitor
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Live monitor ne može izravno čitati druge GitHub runnere. Završene grupe zato
objavljuju male artifacts datoteke, a ``watch`` job prati nove artifacts i
ispisuje rezultate dok routing još traje.

.. code-block:: bash

   ./scripts/watch-ecp5-sweep-results.sh \
       "${SWEEP_TARGET}" \
       "${SWEEP_SEED_FIRST}" \
       "${SWEEP_SEED_LAST}" \
       "${SWEEP_SEEDS_PER_JOB}"

Primjer:

.. code-block:: text

   ------------------------------------------------------------
   LIVE TIMING RESULTS
   Timing-passing seeds: 16 19 49
   Progress: 22/260 seeds | 11/130 groups | 11/130 jobs
   Status: PASS=3 FAIL=19 TIMEOUT=0 OTHER=0
   PASS route duration: avg=388s | fastest=254s (seed 19) | slowest=582s (seed 49)
   Best PASS max MHz: sys=51.27 (seed 19) | video=81.07 (seed 19) | tmds=370.78 (seed 19)
   Timeout seeds: none
   Other/problem seeds: none
   ------------------------------------------------------------

Grupe mogu stići izvan numeričkog redoslijeda jer se brži jobovi završe prvi.
Istaknute metrike namjerno koriste samo ``PASS`` seedove. ``PASS route duration``
isključuje FAIL, TIMEOUT i OTHER rezultate, pa seed koji završi na watchdog
limitu ne može postati najsporiji uspješni route. ``Best PASS max MHz`` računa
maksimum svake domene samo među seedovima koji već prolaze sve obavezne timing
ciljeve. Pojedinačni retci grupa i dalje prikazuju FAIL i timeout rezultate kao
korisne dijagnostičke reference.

``summarize``: konačni rezultat
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Završni job preuzima sve grupe i zamrznute reference.
``scripts/summarize-ecp5-sweep.py`` generira Markdown/CSV sažetke, inventar i
SHA256 kontrolne sume te provjerava da svaki traženi seed ima rezultat ili
izričitu klasifikaciju timeouta/pogreške.

Timeouti i dugi seedovi
-----------------------

.. list-table:: Trenutačni watchdog limiti
   :header-rows: 1
   :widths: 32 22 46

   * - Limit
     - Vrijednost
     - Namjena
   * - Route timeout
     - 7200 s
     - Ograničava interni nextpnr route.
   * - Route kill-after
     - 30 s
     - Eskalira prekid ako se proces ne zaustavi.
   * - Whole-seed timeout
     - 7600 s
     - Ograničava cijelu sweep obradu jednog seeda.
   * - Whole-seed kill-after
     - 30 s
     - Eskalira prekid zaglavljenog seeda.
   * - GitHub route-job timeout
     - 350 min
     - Ograničava cijeli matrix job.

Watchdog statusi 124 i 137 bilježe se kao timeout i obrada se nastavlja sa
sljedećim seedom. Ostali neočekivani nenulti statusi ostaju stvarne pogreške
alata ili integracije.

Strategija odabira parametara
-----------------------------

Za novi netlist preporučeni redoslijed je:

#. Uspostaviti baseline seedovima 1-32 uz HeAP/Router1.
#. Iste seedove ponoviti za svaku kontroliranu usporedbu.
#. Najbolju jednu ili dvije konfiguracije proširiti na 1-128.
#. Puni 1-260 sweep pokrenuti tek kada konfiguracija opravdava trošak ili je
   potrebna šira statistika.

HeAP težine/eksponente, ``tmg_ripup`` i Router2 tretirajte kao eksperimente, a
ne zajamčena poboljšanja. SA prvo testirajte na malom skupu uz uključene
timeoute.

Ako uspoređujete nextpnr verzije, zadržite isti sintetizirani netlist i mijenjajte
samo ``route_oss_cad_suite_version``. Ako se mijenja sinteza, mijenja se i
SHA256 netlista pa stari seed rang više nije izravno usporediv.

Tumačenje i reproducibilnost
----------------------------

``PASS`` znači da prolaze sve obavezne domene. ``FAIL`` znači da je routing
završen, ali najmanje jedna domena promašuje cilj. Timeout nije timing mjerenje.
``NO_RESULT`` i ``ERROR`` zahtijevaju pregled logova.

Prije usporedbe sweepova provjerite SHA256 netlista, cilj, taktove, profil
značajki, LiteDRAM jezgru, LPF ograničenja, nextpnr verziju, placer/router
postavke i isti skup seedova.

Nakon promjene generirane jezgre, primjerice promjene LiteDRAM geometrije
memorije, ponovno sintetizirajte i uspostavite novi seed baseline.


Kontrolni popis reproducibilnosti
---------------------------------

Prije usporedbe dva sweepa provjerite sve sljedeće:

* isti SHA256 sintetizirane netliste, osim ako je sinteza varijabla koja se ispituje;
* isti cilj i profil značajki specifičan za cilj;
* iste zahtjeve za taktovima;
* isti LiteDRAM CPU/generiranu jezgru kada se koristi ULX4M-LD;
* isti LPF/ograničenja;
* istu nextpnr verziju za routing;
* iste postavke place/route alata i dodatne argumente; i
* isti podskup seedova za kontrolirane A/B usporedbe.

Nakon promjene generirane jezgre, primjerice promjene LiteDRAM memorijskog
uređaja/geometrije, ponovno sintetizirajte i uspostavite novu referentnu liniju
seedova. Stari poredak seedova nije prenosiv na novu netlistu.

Savjeti za razvoj i česte zamke
-------------------------------

* Nemojte tumačiti ``--timing-allow-fail`` kao dopuštenje ili PASS timinga. Ono
  samo dopušta da routing završi kako bi sweep mogao prikupiti neuspjele timing
  vrijednosti.
* Nemojte birati seed prema maksimumu jedne taktne domene osim ako isti seed
  zadovoljava sve potrebne domene.
* Nemojte koristiti ``SWEEP_SKIP_SYNTH=1`` nakon promjene RTL-a, generirane
  jezgre, takta ili ograničenja osim ako je odgovarajuća netlista namjerno
  regenerirana.
* Držite ``seeds_per_job`` malim kada seedovi pokazuju dugačke repove trajanja.
  Velika serijska grupa može jedan patološki seed pretvoriti u višesatno
  kašnjenje.
* ``max_parallel`` je GitHub ograničenje konkurentnosti runnera, a ne broj
  nextpnr procesa unutar routing joba. Svaki routing job namjerno obrađuje jedan
  seed odjednom.
* Visoke lokalne vrijednosti ``SWEEP_JOBS`` mogu iscrpiti memoriju prije nego što
  iskorištenost CPU-a izgleda zasićeno.
* Bitstreamove čuvajte samo kada su potrebni. Timing dnevnici i CSV datoteke puno
  su manji i dovoljni za većinu istraživanja.
* Odabrani proizvodni kandidat testirajte na hardveru. Statičko zatvaranje
  timinga nužan je dokaz, ali kvalifikacija na razini pločice i dalje je važna.
* Sačuvajte završne artefakte sweepa kada rezultat postane projektna kontrolna
  točka; sadrže hashove, konfiguraciju, verzije alata i dokaze po seedu potrebne
  za kasniju reprodukciju ili reviziju rezultata.

Povezane datoteke
-----------------

.. code-block:: text

   .github/workflows/ulx4m-ld-seed-sweep.yml
   scripts/sweep-ecp5.sh
   scripts/sweep-ecp5-common.sh
   scripts/sweep-ulx3s-85f.sh
   scripts/sweep-ulx3s-12f.sh
   scripts/sweep-ulx4m-ld.sh
   scripts/watch-ecp5-sweep-results.sh
   scripts/summarize-ecp5-sweep.py

Vidi i :doc:`scripts` te :doc:`board-profiles`.

``WHOLE_SEED_TIMEOUT`` ili drugi timeout status
   Watchdog je zaustavio routing koji je prekoračio dopušteno vrijeme. To nije timing mjerenje i ne treba ga rangirati zajedno s dovršenim routinzima.

Vanjske reference
-----------------

* `RISC-V GCC XPACK <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_

* `nextpnr-ecp5 <https://github.com/YosysHQ/nextpnr>`_
