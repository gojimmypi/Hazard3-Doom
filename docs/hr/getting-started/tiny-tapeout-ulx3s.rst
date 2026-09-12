Tiny Tapeout FPGA buildovi na ULX3S-u
=====================================

Hazard3-Doom također sadrži mali projekt kompatibilan s Tiny Tapeoutom koji se
koristi kao smoke test za ULX3S Tiny Tapeout FPGA tok. Taj je tok odvojen od
uobičajenog Hazard3-Doom FPGA builda: Tiny Tapeout tok omata korisnički
``tt_um_*`` modul ULX3S-specifičnim top-levelom i gradi taj modul za ECP5 FPGA.
On **ne** sintetizira kompletan Hazard3 CPU, SDRAM kontroler, HDMI framebuffer,
rezidentni monitor i Doom aplikaciju.

ULX3S Tiny Tapeout podrška trenutačno se razvija u granama ``experimental``
ovih forkova koje održava ULX3S projekt:

* `ulx3s/tt-gds-action <https://github.com/ulx3s/tt-gds-action/tree/experimental>`_
  pruža višekratno upotrebljivu GitHub Action akciju za workflow Tiny Tapeout
  projekta.
* `ulx3s/tt-support-tools <https://github.com/ulx3s/tt-support-tools/tree/experimental>`_
  sadrži Python alat za FPGA build, ULX3S wrapper i ULX3S LPF ograničenja.

* `tt-fpga-ulx.yaml <https://github.com/ulx3s/Hazard3-Doom/blob/main/.github/workflows/tt-fpga-ulx.yaml>`_

.. admonition:: Status eksperimentalne grane
   :class: important

   Primjeri na ovoj stranici namjerno koriste ``@experimental``. Nemojte ih
   mijenjati u ``@main`` samo zato da workflow izgleda uobičajenije. ULX3S
   podrška još se integrira. Kada ULX3S repozitoriji objave podršku na stabilnoj
   grani ili tagu, ažurirajte reference actiona i support-tools repozitorija
   zajedno kako bi wrapper, sučelje naredbenog retka i workflow ostali usklađeni.

Što rade dva repozitorija
-------------------------

Ta dva repozitorija imaju različite uloge.

``ulx3s/tt-gds-action``
   Ovo je ulazna točka za GitHub Actions. ULX3S composite action nalazi se u
   ``fpga/ulx3s/action.yml``. Ona checkouta alate za podršku, instalira njihove
   Python ovisnosti, stvara Tiny Tapeout korisničku konfiguraciju, instalira
   fiksiranu verziju OSS CAD Suitea, pokreće ECP5 FPGA hardening i prenosi
   dobivene build datoteke kao workflow artifact.

``ulx3s/tt-support-tools``
   Ovdje se nalazi implementacija FPGA builda. ``tt_fpga.py`` čita metapodatke
   Tiny Tapeout projekta, generira wrapper specifičan za pločicu, pokreće Yosys,
   nextpnr-ecp5 i ecppack te zapisuje dobiveni ECP5 bitstream i logove pod
   ``build/``.

Ovo razdvajanje korisno je pri otklanjanju pogrešaka. Problem s workflowom/YAML-om
obično pripada sloju actiona; problemi sa sintezom, wrapperom, mapiranjem pinova,
ECP5 uređajem ili place-and-route ponašanjem obično pripadaju support-tools
sloju.

Potrebna struktura Tiny Tapeout projekta
----------------------------------------

Tok očekuje uobičajene Tiny Tapeout metapodatke i raspored izvornog koda. U
Hazard3-Doomu relevantne su datoteke:

.. code-block:: text

   info.yaml
   src/
       config.json
       project.v

``info.yaml`` je posebno važan. On daje naziv ``top_module`` i popis Verilog
izvornih datoteka. Top-level modul mora koristiti Tiny Tapeout ``tt_um_*``
sučelje. Hazard3-Doom trenutačno koristi mali smoke-test modul
``tt_um_ulx3s_example`` u ``src/project.v``.

FPGA builder može se pokrenuti i bez ``info.yaml`` tako da se ručno navedu
opcije izvora i top-level modula, ali workflow repozitorija namjerno koristi
standardne Tiny Tapeout metapodatke kako bi isti opis projekta ostao upotrebljiv
i za ASIC i za FPGA tokove.

GitHub Actions workflow
-----------------------

ULX3S job koji koristi Hazard3-Doom izgleda ovako:

.. code-block:: yaml

   fpga-ulx3s:
     runs-on: ubuntu-24.04
     steps:
       - name: checkout repo
         uses: actions/checkout@v7
         with:
           submodules: recursive

       - name: FPGA bitstream for TT ASIC Sim (ULX3S ECP5)
         uses: ulx3s/tt-gds-action/fpga/ulx3s@experimental
         with:
           ecp5-device: 85k
           lpf: tt/fpga/ulx3s/ulx3s_v20.lpf
           artifact-name: fpga_ulx3s_ecp5
           uart-enabled: true

Taj job može stajati uz uobičajeni Tiny Tapeout FPGA job. Trenutačni
Hazard3-Doom workflow također gradi iCE40 UP5K cilj odgovarajućom
``fpga/ice40up5k`` akcijom, tako da se isti TT projekt provjerava kroz dvije FPGA
implementacije.

Zašto se koristi recursive checkout
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``submodules: recursive`` checkouta projekt točno kako ga repozitorij
predstavlja, uključujući izvorne ovisnosti predstavljene Git podmodulima. ULX3S
action zatim radi vlastiti checkout ``tt-support-tools`` repozitorija u radni
direktorij nazvan ``tt``. To su dva odvojena checkouta:

#. prvi checkout je Tiny Tapeout projekt koji se gradi;
#. drugi checkout daje Tiny Tapeout build alate.

Ulazi actiona
-------------

``ecp5-device``
   Odabire gustoću ECP5 uređaja koja se prosljeđuje u ``tt_fpga.py``, a zatim u
   nextpnr-ecp5. Hazard3-Doom koristi ``85k`` za ULX3S 85F pločicu. Trenutačni
   support alat prihvaća ``12k``, ``25k``, ``45k`` i ``85k`` za ECP5 ciljeve.

``lpf``
   Putanja do Lattice Preference File datoteke koja sadrži fizička ograničenja
   pinova i takta za ULX3S. Hazard3-Doom za ovaj workflow izričito odabire
   ``tt/fpga/ulx3s/ulx3s_v20.lpf``. Višekratno upotrebljiva ULX3S action
   trenutačno zadano koristi ``ulx3s_v316.lpf``, pa eksplicitni LPF sprječava
   tihu promjenu ograničenja pločice ako se zadana vrijednost actiona promijeni.
   Odabrana v20 datoteka mapira ``clk_25mhz`` na oscilator pločice, ograničava
   taj port na 25 MHz te mapira LED-ove, tipke, GPIO i druge signale wrappera.

``artifact-name``
   Osnovni naziv GitHub Actions artifacta. Action dodaje odabrani ECP5 uređaj,
   pa primjer proizvodi artifact nazvan ``fpga_ulx3s_ecp5_85k``.

``uart-enabled``
   Kada je vrijednost ``true``, action prosljeđuje Verilog definiciju
   ``UART_ENABLED`` FPGA buildu. Time se uključuje opcionalno UART mapiranje u
   ULX3S wrapperu. Koristite ``false`` za projekt koji ne želi to mapiranje.

Composite action također ima ulaze ``tools-repo`` i ``tools-ref``. Njihove su
trenutačne zadane vrijednosti ``ulx3s/tt-support-tools`` i ``experimental``.
Obično ih treba ostaviti nepromijenjene kako bi action koristio odgovarajuću
ULX3S support-tools granu, ali korisne su pri testiranju razvojnog forka ili
određenog commita.

Što action pokreće
------------------

Trenutačni ULX3S composite action izvodi ove operacije:

#. Checkouta ``ulx3s/tt-support-tools`` na traženom ``tools-ref`` u ``tt/``.
#. Postavlja Python 3.11 i instalira ``tt/requirements.txt``.
#. Ako projekt ima ``test/requirements.txt``, instalira i te ovisnosti.
#. Pokreće ``tt/tt_tool.py --create-user-config`` kako bi support alati imali
   top-level modul projekta i konfiguraciju izvora.
#. Instalira OSS CAD Suite koristeći ``YosysHQ/setup-oss-cad-suite@v4``.
   Trenutačni experimental action fiksira verziju suitea na ``2026-04-26``.
#. Pokreće ekvivalent sljedeće ULX3S build naredbe:

   .. code-block:: bash

      python tt/tt_fpga.py harden \
          --name tt_um_fpga_ecp5_85k \
          --fpga-target ulx3s-ecp5 \
          --ecp5-device 85k \
          --lpf tt/fpga/ulx3s/ulx3s_v20.lpf \
          --define UART_ENABLED

#. Prenosi build proizvode i prateće projektne datoteke kao GitHub Actions
   artifact, čak i kada neka kasnija faza prijavi neuspjeh.

Argument ``--define UART_ENABLED`` uključen je samo kada je
``uart-enabled: true``.

Unutar ``tt_fpga.py``
---------------------

Za cilj ``ulx3s-ecp5``, ``tt_fpga.py`` generira ``src/_tt_fpga_top.v`` iz
support-tools predloška ``fpga/ulx3s/tt_fpga_top_ulx3s.v``. Placeholder
korisnički modul u tom predlošku zamjenjuje se vrijednošću ``top_module`` iz
``info.yaml``.

Generirani wrapper zatim se sintetizira zajedno s projektnim izvorima. ECP5 tok
konceptualno izgleda ovako:

.. code-block:: text

   info.yaml + src/project.v
              |
              v
   generate src/_tt_fpga_top.v
              |
              v
       Yosys synth_ecp5
              |
              v
       build/<name>.json
              |
              v
         nextpnr-ecp5
              |
              v
      build/<name>.config
              |
              v
            ecppack
              |
              v
        build/<name>.bit

Za primjer workflowa važne su obično ove datoteke:

.. code-block:: text

   build/01-synth.log
   build/02-nextpnr.log
   build/tt_um_fpga_ecp5_85k.json
   build/tt_um_fpga_ecp5_85k.config
   build/tt_um_fpga_ecp5_85k.bit

``01-synth.log`` prvo je mjesto za provjeru HDL, modularnih ili sintetskih
problema. ``02-nextpnr.log`` sadrži iskorištenost uređaja, placement/routing i
timing informacije. Datoteka ``.bit`` je ULX3S ECP5 bitstream.

Ponašanje ULX3S wrappera
------------------------

Trenutačni wrapper namjerno pruža jednostavno i vidljivo Tiny Tapeout testno
okruženje:

* ULX3S oscilator ``clk_25mhz`` pokreće Tiny Tapeout ulaz ``clk``;
* ULX3S tipka 0 pokreće aktivno-niski Tiny Tapeout ulaz ``rst_n``;
* Tiny Tapeout ``ena`` drži se u visokom stanju;
* ``uo_out[7:0]`` spojen je na osam ULX3S LED-ova;
* kada je ``UART_ENABLED`` definiran, ULX3S ``gp0`` se sinkronizira i mapira na
  Tiny Tapeout ``ui_in[3]``;
* kada je ``UART_ENABLED`` definiran, Tiny Tapeout ``uo_out[4]`` pokreće ULX3S
  ``gp1`` kao UART transmit put;
* wrapper drži ``uio_in`` na nuli, iako projekt i dalje izlaže uobičajeno Tiny
  Tapeout sučelje ``uio_out`` i ``uio_oe``.

Zbog ovog mapiranja jednostavan TT projekt može se izravno testirati LED-ovima,
tipkama i UART-om prije prelaska na ASIC hardening ili fizički shuttle.

Pokretanje istog ULX3S toka lokalno
-----------------------------------

GitHub Action je najjednostavniji reproducibilni put, ali isti support alati
mogu se pokrenuti lokalno. Iz korijena Tiny Tapeout projekta:

.. code-block:: bash

   git clone --branch experimental \
       https://github.com/ulx3s/tt-support-tools.git tt
   python3 -m pip install -r tt/requirements.txt
   python3 tt/tt_tool.py --create-user-config

Yosys, ``nextpnr-ecp5``, Project Trellis/``ecppack`` i njihovi podaci za ECP5
uređaje također moraju biti dostupni u ``PATH``. GitHub Action ih pruža kroz
svoju fiksiranu OSS CAD Suite konfiguraciju; lokalni build može koristiti
ekvivalentno instaliran OSS CAD Suite.

Zatim eksplicitno pokrenite isti FPGA build:

.. code-block:: bash

   python3 tt/tt_fpga.py harden \
       --name tt_um_fpga_ecp5_85k \
       --fpga-target ulx3s-ecp5 \
       --ecp5-device 85k \
       --lpf tt/fpga/ulx3s/ulx3s_v20.lpf \
       --define UART_ENABLED

Izostavite ``--define UART_ENABLED`` kako biste gradili bez opcionalnog UART
mapiranja.

Support alat prihvaća i varijable okruženja ``TT_FPGA_SEED`` i
``TT_FPGA_FREQ``, koje se prosljeđuju u place-and-route tok. Za normalnu
validaciju projekta najprije koristite zadane vrijednosti podržanog workflowa
umjesto proizvoljnog mijenjanja routing parametara; ako projekt treba drugi
seed ili timing cilj, zabilježite te postavke uz rezultate testa.

Programiranje generiranog bitstreama
------------------------------------

Lokalna ili preuzeta ``.bit`` datoteka običan je ULX3S ECP5 bitstream. S
kompatibilnom instalacijom ``fujprog`` moguće je volatilno učitati FPGA ovako:

.. code-block:: bash

   fujprog build/tt_um_fpga_ecp5_85k.bit

Konfiguracija FPGA SRAM-a gubi se kada se pločici isključi napajanje. To je
obično upravo ono što želite za Tiny Tapeout smoke test jer se ne zamjenjuje
trajna flash slika. Pogledajte :doc:`programming` i
:doc:`../user-guide/web-flasher` za Hazard3-Doom načine programiranja i
razmatranja vezana uz USB drivere.

Nemojte miješati ``tt_fpga.py harden`` s
``tt_fpga.py configure --upload``. Trenutačna podnaredba ``configure`` dio je
Tiny Tapeout database/breakout konfiguracijskog puta i traži ``.bin`` sliku.
ULX3S ECP5 build opisan ovdje proizvodi ``.bit`` datoteku; taj ECP5 bitstream
programirajte ULX3S FPGA programskim alatom.

Preuzimanje i provjera GitHub artifacta
---------------------------------------

Nakon završetka joba ``fpga-ulx3s``, otvorite workflow run i preuzmite artifact
``fpga_ulx3s_ecp5_85k``. Action je konfiguriran tako da uključi direktorij
``build/`` zajedno s projektnim ``docs/``, ``src/``, ``info.yaml``, ``LICENSE``
i odabranom LPF datotekom. Tako je artifact koristan i za programiranje i za
dijagnosticiranje točno onoga što je izgrađeno.

Za uspješan build provjerite najmanje sljedeće:

#. ``build/tt_um_fpga_ecp5_85k.bit`` postoji i nije prazna datoteka;
#. ``build/01-synth.log`` prikazuje očekivani Tiny Tapeout top-level modul;
#. ``build/02-nextpnr.log`` identificira namjeravani ECP5 uređaj i nema routing
   neuspjeha;
#. LPF u artifactu je ULX3S constraint datoteka koju workflow očekuje;
#. GitHub Actions log prikazuje očekivane reference za ``ulx3s/tt-gds-action`` i
   ``ulx3s/tt-support-tools``.

Otklanjanje pogrešaka
---------------------

``No project yaml, must specify ...``
   Builder nije pronašao očekivani ``info.yaml`` u korijenu projekta ili je
   naredba pokrenuta iz pogrešnog direktorija. Koristite uobičajeni korijen TT
   projekta ili eksplicitno navedite opcije izvora/top-level modula.

``ulx3s-ecp5 requires --lpf ...``
   ECP5 cilj zahtijeva datoteku fizičkih ograničenja. Koristite odgovarajući
   ULX3S LPF iz checkoutanog support-tools stabla, osim ako namjerno testirate
   drugu reviziju pločice ili drugo mapiranje pinova.

Yosys ne može pronaći korisnički modul
   Provjerite ``top_module`` u ``info.yaml``, popis ``source_files`` i
   ``build/01-synth.log``. Također pregledajte generirani
   ``src/_tt_fpga_top.v`` kako biste potvrdili da je placeholder zamijenjen
   očekivanim ``tt_um_*`` modulom.

nextpnr prijavljuje greške pinova ili packagea
   Potvrdite da ``ecp5-device`` i LPF odgovaraju stvarnoj ULX3S pločici. Nemojte
   rješavati neslaganje pločice brisanjem ograničenja.

UART ne odgovara
   Potvrdite da je korišten ``uart-enabled: true`` i zapamtite da wrapper mapira
   ``gp0`` u ``ui_in[3]`` te ``uo_out[4]`` kroz ``gp1``. Sam Tiny Tapeout modul
   mora implementirati odgovarajuće receive/transmit ponašanje; uključivanje
   wrappera ne dodaje UART jezgru korisničkom dizajnu.

Workflow radi, ali ručni build ne radi
   Najprije usporedite verzije alata. GitHub Action namjerno fiksira OSS CAD
   Suite i ``experimental`` support-tools granu. Lokalna verzija Yosysa,
   nextpnr-ecp5 ili Project Trellisa može dati drugačije rezultate.

Povezane poveznice
------------------

* `ULX3S tt-gds-action experimental grana <https://github.com/ulx3s/tt-gds-action/tree/experimental>`_
* `ULX3S tt-support-tools experimental grana <https://github.com/ulx3s/tt-support-tools/tree/experimental>`_
* `Hazard3-Doom ULX3S TT workflow <https://github.com/ulx3s/Hazard3-Doom/blob/main/.github/workflows/tt-fpga-ulx.yaml>`_
* `ULX3S Tiny Tapeout predložak <https://github.com/ulx3s/ttsky-verilog-template/tree/ulx3s>`_
