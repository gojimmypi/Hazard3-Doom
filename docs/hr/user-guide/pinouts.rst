Pinovi pločica i ožičenje
===========================

Ova stranica okuplja dijagrame pinova i veze koje su najkorisnije za UART
adaptere, SAO dodatke, debug hardver i druge vanjske uređaje. Hardverski vodič
i dalje je mjerodavan za PCB revizije, sheme, LPF ograničenja i FPGA package
pinove.

ULX3S
-----

.. _fig-ulx3s-pinout:

.. figure:: ../images/ulx3s-pinout.png
   :alt: ULX3S pinout

   **ULX3S pinout** - FPGA GPIO i raspored konektora.

Hazard3-Doom monitor UART koristi ove J1 veze:

.. code-block:: text

   adapter TX  -> J1 pin 6 / GP0 -> Hazard3 RxD
   adapter RX  <- J1 pin 8 / GP1 <- Hazard3 TxD
   adapter GND -> susjedni J1 GND

TX i RX su nazvani iz perspektive pojedinog uređaja pa ih treba križati kao što
je prikazano. Za shemu, LPF, orijentaciju konektora i revizije pločice pogledajte
:doc:`../hardware/ulx3s/pinout-and-revisions`.

Tigard JTAG prema Hazard3 na ULX3S
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ULX3S J4 je izravna vanjska JTAG veza prema ECP5. Hazard3 koristi ECP5 hardverski
JTAG TAP i primitiv ``JTAGG`` za RISC-V debug modul. S Tigardom u ``SPI/JTAG``
načinu koristite:

.. list-table:: Tigard prema ULX3S J4
   :header-rows: 1
   :widths: 20 20 20 40

   * - Tigard pin
     - Signal
     - Boja
     - ULX3S J4
   * - 2
     - GND
     - Crna
     - GND
   * - 3
     - TCK
     - Bijela
     - TCK
   * - 4
     - TDI
     - Siva
     - TDI
   * - 5
     - TDO
     - Ljubičasta
     - TDO
   * - 6
     - TMS
     - Plava
     - TMS

ULX3S napajajte normalno preko US1 i postavite Tigard na 3,3 V logiku. Nemojte
spajati ``VTGT`` kako Tigard ne bi napajao pločicu. ``TRST`` i ``SRST`` nisu
potrebni za Hazard3. Za OpenOCD i GDB single-step primjere pogledajte
:doc:`jtag-debugging`.

Tigard JTAG prema ugrađenom ESP32
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ovo je zasebna debug meta. Klasični ESP32 na ULX3S je Xtensa procesor, a njegovi
JTAG GPIO pinovi 12 do 15 dijele se s micro-SD priključkom. Sljedeće ožičenje je
izvedeno iz ULX3S sheme/LPF-a i Espressif ESP32 JTAG rasporeda; još nije
projektno kvalificirano na ULX3S pločici.

.. list-table:: Tigard prema ULX3S ESP32
   :header-rows: 1
   :widths: 18 18 18 20 26

   * - Tigard
     - JTAG signal
     - ESP32 pin
     - ULX3S SD signal
     - micro-SD kontakt
   * - Pin 4 / siva
     - TDI
     - GPIO12 / MTDI
     - DAT2
     - Pin 1
   * - Pin 3 / bijela
     - TCK
     - GPIO13 / MTCK
     - DAT3
     - Pin 2
   * - Pin 6 / plava
     - TMS
     - GPIO14 / MTMS
     - CLK
     - Pin 5
   * - Pin 5 / ljubičasta
     - TDO
     - GPIO15 / MTDO
     - CMD
     - Pin 3
   * - Pin 2 / crna
     - GND
     - GND
     - VSS
     - Pin 6 ili drugi GND

.. warning::

   Isti SD signali spojeni su i na ECP5. Nemojte koristiti Tigard za ESP32 dok
   FPGA slika može aktivno upravljati SD sabirnicom. Izvadite SD karticu i
   koristite provjerenu FPGA sliku koja ostavlja ``SD_D2``, ``SD_D3``,
   ``SD_CLK`` i ``SD_CMD`` u high-impedance stanju.

ULX4M-LD na Waveshare CM4 carrieru
----------------------------------

.. _fig-ulx4m-ld-pinout:

.. figure:: ../images/ulx4m_ld-pinout.png
   :alt: ULX4M-LD pinout

   **ULX4M-LD pinout** - FPGA pinovi na
   `Waveshare CM4 carrieru <https://www.waveshare.com/wiki/CM4-IO-BASE-A#Dimension>`_.

Za projektno provjerenu Tigard UART vezu:

.. code-block:: text

   Tigard UART TX  -> fizički pin 16 -> GPIO23 -> FPGA N4 -> uart_rx
   Tigard UART RX  <- fizički pin 18 -> GPIO24 <- FPGA N3 <- uart_tx
   Tigard GND      -> fizički pin 20
   Tigard VCC      -> nije spojeno

Nemojte napajati ULX4M preko Tigarda. Pogledajte
:doc:`../hardware/ulx4m/pinout-and-revisions` i :doc:`jtag-debugging`.

Generiranje prilagođenih pinout dijagrama
-----------------------------------------

Pinout dijagrami mogu se ponovno generirati ili prilagoditi samostalnim
`ULX Pinout Generatorom <https://github.com/ulx3s/ulx3s-pinout>`_. Alat gradi
annotirane dijagrame iz datoteka ograničenja specifičnih za pločicu, mapiranja
konektora, slika pločice i podataka o rasporedu, umjesto održavanja jednog ručno
uređivanog pinouta. Trenutačno podržava ULX3S i ULX4M-LD.

Generator je koristan kada želite:

* ponovno generirati objavljeni dijagram iz njegovih izvornih podataka;
* odabrati LPF za drugu reviziju ULX3S pločice;
* pregledati aliase ili električne metapodatke zapisane u LPF-u;
* vidjeti koje FPGA lokacije povezane s ULX4M-LD headerom koristi određeni LPF
  dizajna;
* izraditi SVG, PNG, PDF ili PostScript izlaz; ili
* prilagoditi položaj, širinu i boju oznaka ili drugu geometriju dijagrama.

.. warning::

   Generirani dijagrami služe kao pomoćna dokumentacija, a ne kao zamjena za
   shemu pločice ili stvarnu datoteku ograničenja korištenu za izgradnju FPGA
   slike. Prije spajanja hardvera provjerite napajanje konektora, FPGA lokacije,
   reviziju PCB-a, orijentaciju konektora, dijeljene resurse i odabrani LPF.

Kako generator radi
~~~~~~~~~~~~~~~~~~~

Generiranje mapiranja i iscrtavanje dijagrama namjerno su odvojeni koraci.
Uobičajeni tijek je:

.. code-block:: text

   board constraint file
           |
           v
   boards/<board>/generator.py
           |
           v
   boards/<board>/data.py
           |
           +---------------- board image
           +---------------- styles.css
           |
           v
   boards/<board>/layout.py
           |
           v
   output/<board>/pinout_*.{svg,png,pdf,ps}

``generate-data-from-lpf.py`` odabire LPF parser specifičan za pločicu i zapisuje
generirane podatke mapiranja. ``generate-pinout.py`` učitava ``layout.py``
odabrane pločice i iscrtava postojeći ``data.py``. Iscrtavanje **ne** odabire
niti tiho ponovno generira LPF konfiguraciju, pa prvo ponovno generirajte
mapiranje kad god promijenite LPF ili opcije mapiranja.

Sve naredbe pokrećite iz korijena repozitorija ``ulx3s-pinout``. Konfiguracija
pločica koristi putanje relativne na repozitorij.

Instalacija na Ubuntu ili WSL
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Uobičajeni workflow temelji se na Pythonu. Na Ubuntu ili WSL sustavu:

.. code-block:: bash

   sudo apt update
   sudo apt install python3-pip

   cd /mnt/c/workspace
   git clone https://github.com/ulx3s/ulx3s-pinout.git
   cd ulx3s-pinout

   python3 -m pip install --user --upgrade pinout cairosvg pillow

Ovisnosti imaju različite uloge:

* ``pinout`` gradi objektni model dijagrama i izvozi SVG;
* ``cairosvg`` omogućuje pretvorbu u PNG, PDF i PostScript; i
* ``Pillow`` provjerava slike i normalizira fotografiju ULX4M-LD carriera prije
  primjene kalibriranih koordinata konektora.

Podržane pločice možete u svakom trenutku ispisati s:

.. code-block:: bash

   ./generate-data-from-lpf.py --list-boards
   ./generate-pinout.py --list-boards

ULX3S brzi početak
~~~~~~~~~~~~~~~~~~

Zadani ULX3S podaci generiraju se iz v3.1.6/v3.1.7 LPF konfiguracije i uključuju
prepoznate aliase koje koristi commitani pinout:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       --include aliases \
       --markdown output/ulx3s/PIN-MAPPING.md

Generirajte zadani SVG:

.. code-block:: bash

   ./generate-pinout.py ulx3s

Ili PNG:

.. code-block:: bash

   ./generate-pinout.py ulx3s --format png

Uobičajeni izlazi su:

.. code-block:: text

   output/ulx3s/pinout_ulx3s.svg
   output/ulx3s/pinout_ulx3s.png
   output/ulx3s/PIN-MAPPING.md

Generirani SVG ugrađuje sliku pločice pa se može pregledavati bez mrežne veze.

Uporaba drugog ULX3S LPF-a
~~~~~~~~~~~~~~~~~~~~~~~~~~

Repozitorij sadrži više ULX3S datoteka ograničenja u
``boards/ulx3s/constraints/``, uključujući v1.7-patch, v2.0, v3.1.4 i v3.1.6
varijante. Za generiranje iz određene LPF datoteke u repozitoriju navedite je
izričito:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v20.lpf \
       --include aliases \
       --markdown output/ulx3s/PIN-MAPPING-v20.md

   ./generate-pinout.py ulx3s --format png

Za eksperimentiranje bez zamjene commitane ULX3S ``data.py`` datoteke zapišite
mapiranje u privremenu datoteku:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v20.lpf \
       -o build/ulx3s-v20-data.py

Ta je privremena datoteka korisna za pregled i usporedbu. Renderer koristi
uobičajeni ``boards/ulx3s/data.py`` pločice osim ako implementacija pločice nije
promijenjena da koristi nešto drugo.

Neobavezne ULX3S LPF oznake
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Osnovni dijagram ne mora prikazivati svaki LPF metapodatak. Koristite
``--include`` za odabir dodatnih polja. Za autoritativni trenutačni popis pitajte
instalirani generator:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s --list-fields

Trenutačna polja uključuju:

.. code-block:: text

   aliases
   connector
   flags
   iobuf
   pullmode
   io_type
   drive
   frequency
   comment
   all

Korisni primjeri slijede.

Uključite samo aliase:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v316.lpf \
       --include aliases

Uključite aliase i često korisne električne metapodatke:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v316.lpf \
       --include aliases,connector,flags,pullmode,io_type,drive,frequency

Uključite svaki parsirani ``IOBUF`` ključ/vrijednost par:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v316.lpf \
       --include iobuf

Zatražite proizvoljan određeni ``IOBUF`` ključ:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v316.lpf \
       --iobuf-key SLEWRATE

Polja znače:

* ``aliases`` spaja prepoznate aliase u GP/GN komentarima s drugim aktivnim
  ``LOCATE COMP`` imenima koja koriste istu FPGA lokaciju. Dupli aliasi emitiraju
  se samo jednom.
* ``connector`` emitira oznake konektora poput ``J1_5+``, ``J1_5-``, ``J2_35+``
  i ``J2_35-``. Kada LPF komentar sadrži izričiti connector token, generator ga
  provjerava prema fizičkom predlošku.
* ``flags`` izdvaja korisne zastavice iz komentara poput ``DIFF``, ``PCLK`` i
  ``GR_PCLK``.
* ``iobuf`` emitira sve parsirane ``IOBUF`` ključ/vrijednost parove. ``pullmode``,
  ``io_type`` i ``drive`` odabiru uža podskupove.
* ``frequency`` emitira ``FREQUENCY PORT`` metapodatke kada postoje.
* ``comment`` emitira potpuni GP/GN inline komentar. Može znatno proširiti oznake
  i uglavnom služi za audit.
* ``all`` uključuje svako podržano neobavezno polje, uključujući sirovi komentar.

ULX3S vektorski i skalarni GPIO oblici
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Neke ULX3S LPF datoteke sadrže i vektorska i skalarna imena za iste GPIO-e:

.. code-block:: text

   gp[0]..gp[27] / gn[0]..gn[27]
   gp0..gp27     / gn0..gn27

Generator provjerava da se oba oblika razrješavaju na isti FPGA ``SITE``. Za
aliase i električne metapodatke oblici se ipak ne spajaju naslijepo.
``--gpio-form auto`` je zadano i preferira potpuni vektorski oblik.

Po potrebi izričito odaberite oblik:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s --gpio-form vector
   ./generate-data-from-lpf.py ulx3s --gpio-form scalar

v3.1.6/v3.1.7 LPF trenutačno sadrži poznatu GN12 razliku metapodataka. Vektorski
oblik navodi ``PULLMODE=UP``, ``IO_TYPE=LVCMOS33`` i ``DRIVE=4`` bez
``FREQUENCY`` unosa, dok skalarni oblik navodi ``PULLMODE=NONE``,
``IO_TYPE=LVCMOS33`` i ``FREQUENCY=50 MHZ``. Uobičajeni generator to prijavljuje
kao upozorenje, a test suite repozitorija očekuje to upozorenje.

Da bi bilo koje neslaganje vektorskih/skalarnih metapodataka bilo fatalno,
dodajte:

.. code-block:: bash

   --strict-form-metadata

ULX3S fizičko numeriranje i provjera
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Generirano ULX3S mapiranje slijedi konvenciju datoteke ograničenja za ženske
J1/J2 konektore savijene 90 stupnjeva i montirane na vrhu pločice. Ako koristite
muške okomite headere s donje strane PCB-a ili ravni kabel, provjerite
orijentaciju prije spajanja. Pogled s druge strane konektora može prividno
zamijeniti lijevu i desnu stranu.

Generator provjerava ove važne invarijante:

.. code-block:: text

   J1 contains physical pins 1..40 exactly once
   J2 contains physical pins 1..40 exactly once
   GP0..GP27 appear exactly once
   GN0..GN27 appear exactly once

GPIO rasponi su:

.. code-block:: text

   J1: GP0..GP13 and GN0..GN13
   J2: GP14..GP27 and GN14..GN27

Uvijek provjerite FPGA package lokacije prema odabranom LPF-u umjesto
zaključivanja lokacije iz susjednih pinova.

ULX3S projektne/korisničke oznake
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Projektne oznake odvojene su od metapodataka izvedenih iz LPF-a. Tako generator
može prikazati semantičke oznake poput UART oznaka za GP0 i GP1 bez pretvaranja
da su ta projektna značenja dio datoteke ograničenja pločice.

Isključite projektne/korisničke oznake s:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s --no-user-labels

Koristite ``--include`` za informacije izvedene iz LPF-a, a mehanizam korisničkih
oznaka za projektna značenja.

ULX4M-LD brzi početak
~~~~~~~~~~~~~~~~~~~~~

Generirajte zadano ULX4M-LD mapiranje i Markdown tablicu:

.. code-block:: bash

   ./generate-data-from-lpf.py ulx4m-ld \
       --markdown output/ulx4m-ld/PIN-MAPPING.md

Generirajte SVG ili PNG:

.. code-block:: bash

   ./generate-pinout.py ulx4m-ld
   ./generate-pinout.py ulx4m-ld --format png

Uobičajeni izlazi su:

.. code-block:: text

   output/ulx4m-ld/pinout_ulx4m_ld.svg
   output/ulx4m-ld/pinout_ulx4m_ld.png
   output/ulx4m-ld/PIN-MAPPING.md

ULX4M-LD generator namjerno drži dva sloja odvojena:

* fiksno ožičenje Raspberry Pi header -> CM4 -> ULX4M-LD FPGA lokacija; i
* trenutačnu uporabu tih FPGA lokacija u LPF-u.

To je važno jer lokaciju fizički povezanu s 40-pinskim headerom može koristiti i
drugi resurs dizajna. Odabrani LPF određuje aktivna imena resursa prikazana u
tom sloju dijagrama; nisu hardkodirana u crtež.

Generiranje svih podržanih pločica
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Kada ``data.py`` svake pločice sadrži željeno mapiranje, generirajte sve pločice
s:

.. code-block:: bash

   ./generate-pinout.py all

Ponovno, to iscrtava postojeće podatke pločica. Ne regenerira svaku pločicu iz
LPF-a.

Formati izlaza i nazivi datoteka
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Renderer podržava:

.. code-block:: text

   svg
   png
   pdf
   ps

Primjeri:

.. code-block:: bash

   ./generate-pinout.py ulx3s --format svg
   ./generate-pinout.py ulx3s --format png
   ./generate-pinout.py ulx4m-ld --format pdf
   ./generate-pinout.py ulx4m-ld --format ps

Za prilagođeni naziv datoteke pri generiranju jedne pločice:

.. code-block:: bash

   ./generate-pinout.py ulx4m-ld \
       --format svg \
       --output output/ulx4m-ld/custom.svg

Generiranje uobičajeno prepisuje odabranu izlaznu datoteku. Koristite
``--no-overwrite`` kako biste zadržali postojeću datoteku i dopustili
``pinout.manager`` da odabere jedinstven naziv izlaza.

Napredna izravna uporaba pinout.managera
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``generate-pinout.py`` je preporučeni front-end za pločice, ali svaki
``layout.py`` pločice izlaže i modulni objekt ``diagram`` koji očekuje izvorni
``pinout.manager`` workflow.

ULX3S:

.. code-block:: bash

   python3 -m pinout.manager \
       --export boards/ulx3s/layout.py output/ulx3s/pinout_ulx3s.svg \
       --overwrite

ULX4M-LD:

.. code-block:: bash

   python3 -m pinout.manager \
       --export boards/ulx4m-ld/layout.py output/ulx4m-ld/pinout_ulx4m_ld.svg \
       --overwrite

Prilagodba dijagrama
~~~~~~~~~~~~~~~~~~~~

LPF datoteke, generatorski kod specifičan za pločicu, slike pločice, layout kod
i ``styles.css`` tretirajte kao izvor. Ponovno generirajte ``data.py`` i izlazne
slike umjesto trajnog uređivanja generiranih SVG ili PNG datoteka.

Za promjene mapiranja ili oznaka izvedenih iz LPF-a radite u:

.. code-block:: text

   boards/ulx3s/generator.py
   boards/ulx3s/constraints/*.lpf

   boards/ulx4m-ld/generator.py
   boards/ulx4m-ld/constraints/*.lpf

Za položaj i geometriju uredite layout pločice:

.. code-block:: text

   boards/ulx3s/layout.py
   boards/ulx4m-ld/layout.py

Layout upravlja dimenzijama dijagrama, položajem slike pločice, pozicijama grupa
oznaka, geometrijom leader linija, semantičkim širinama oznaka, visinom i
razmakom oznaka, centriranjem pločice, položajem legende i kalibracijskim
koordinatama specifičnim za pločicu.

Širine ULX3S oznaka odabiru se prema semantičkom tipu. Layout sadrži kontrole
poput:

.. code-block:: text

   PIN_NUMBER_LABEL_WIDTH
   GPIO_SIGNAL_LABEL_WIDTH
   FPGA_SITE_LABEL_WIDTH
   POWER_LABEL_WIDTH
   GROUND_LABEL_WIDTH
   USER_LABEL_WIDTH
   ALIAS_LABEL_WIDTH
   CONNECTOR_LABEL_WIDTH
   METADATA_LABEL_WIDTH
   ANALOG_LABEL_WIDTH
   PWM_LABEL_WIDTH
   TOUCH_LABEL_WIDTH
   DEFAULT_LABEL_WIDTH

Geometrija ULX3S pill oznaka također je parametrizirana u
``boards/ulx3s/layout.py``, uključujući radius kuta, boju obruba i širinu
obruba. Zajednički vizualni stil, uključujući GP/GN boje, boje diferencijalnih
parova, FPGA lokacije, napajanje i masu, aliase, metapodatke konektora, leader
linije, fontove i legendu, nalazi se u ``styles.css``.

Pri promjeni ULX4M-LD položaja zadržite izmjerenu kalibraciju krajnjih točaka
Raspberry Pi headera odvojenu od položaja oznaka. Koordinate konektora drže
leader linije spojene na ispravne pinove na fotografiji carriera.

Provjera promjena
~~~~~~~~~~~~~~~~~

Pokrenite iste parser i rendering provjere koje koristi GitHub Actions workflow
repozitorija:

.. code-block:: bash

   ./scripts/test-pinout.sh

Privremeni izlaz provjere zapisuje se u:

.. code-block:: text

   build/pinout-tests/

Test suite provjerava Python sintaksu, otkrivanje pločica, pomoć naredbenog
retka, SVG i PNG rendering obje pločice, čitljivost PNG-a, reproducibilnost
commitanih zadanih ``data.py`` datoteka, generiranje Markdown mapiranja, svaku
commitanu ULX3S i ULX4M-LD datoteku ograničenja, ULX3S alias put, ShellCheck kada
je dostupan te da testovi ne mijenjaju praćene datoteke.

Uspješno pokretanje proizvodi barem ove renderirane datoteke:

.. code-block:: text

   build/pinout-tests/rendered/pinout_ulx3s.svg
   build/pinout-tests/rendered/pinout_ulx3s.png
   build/pinout-tests/rendered/pinout_ulx4m_ld.svg
   build/pinout-tests/rendered/pinout_ulx4m_ld.png

Prije commita promjene pinouta dijagrame pregledajte i vizualno. Potvrdite da je
slika pločice prisutna, da oznake konektora pokazuju na odgovarajuće rupe, da su
J1/J2 i GP/GN brojevi potpuni, da FPGA package lokacije odgovaraju datoteci
ograničenja te da napajanje/masa odgovaraju shemi ciljane revizije pločice.
Automatske provjere nadopunjuju, a ne zamjenjuju, vizualnu provjeru i provjeru
sheme.

Rješavanje problema
~~~~~~~~~~~~~~~~~~~

``module '<name>' has no attribute 'diagram'``
   ``pinout.manager`` zahtijeva modulni objekt nazvan ``diagram``. Svaki
   ``layout.py`` pločice mora ga izložiti.

PNG, PDF ili PS export ne uspijeva, a SVG radi
   CairoSVG put pretvorbe stroži je prema nekim CSS sintaksama od modernih
   preglednika. Koristite klasične RGB vrijednosti odvojene zarezima poput
   ``rgb(34, 173, 0)`` umjesto CSS Color 4 vrijednosti odvojenih razmacima poput
   ``rgb(34 173 0)``.

ULX3S prijavljuje GN12 upozorenje metapodataka
   To je poznata v3.1.6/v3.1.7 razlika vektorskih/skalarnih metapodataka opisana
   iznad. Uobičajeni test suite je dopušta. Koristite
   ``--strict-form-metadata`` kada namjerno želite da ta razlika prekine
   generiranje.

``data.py`` reproducibility test ne uspijeva
   Commitani podaci pločice moraju se moći reproducirati zadanim opcijama
   generiranja repozitorija. Za ULX3S commitani default uključuje
   ``--include aliases``. Test ispisuje diff kada generirani podaci ne odgovaraju
   commitanoj datoteci.

Oznake se renderiraju, ali slika pločice nedostaje
   Provjerite postoji li slika specifična za pločicu:

   .. code-block:: bash

      ls -lh boards/ulx3s/ulx3s.png
      ls -lh boards/ulx4m-ld/cm4-io-base-b-3_3.jpg

   Oba layouta ugrađuju sliku pločice u generirani SVG.

Preglednik i dalje prikazuje stariji SVG
   Lokalne SVG datoteke mogu biti cacheirane. Ponovno učitajte datoteku ili
   zatvorite i ponovno otvorite karticu preglednika nakon regeneriranja.

Repozitorij sadrži starije pomoćne direktorije poput ``fpga2pinout/``,
``svg2png/`` i ``png2base64/``. To su legacy alati i nisu potrebni trenutačnom
Python workflowu za generiranje ULX3S ili ULX4M-LD dijagrama.

Prije spajanja vanjskog hardvera
--------------------------------

* Potvrdite točnu pločicu i PCB reviziju.
* Potvrdite aktivni FPGA bitstream i LPF ograničenja.
* Provjerite I/O napon i smjer signala prije spajanja.
* Spojite mase prije oslanjanja na UART ili druge single-ended signale.
* Nemojte pretpostaviti da položaj konektora ima istu funkciju kroz različite
  revizije pločice ili carriera.

Dijagrami su praktične vizualne reference, ali stvarnu električnu vezu određuju
aktivna ograničenja i shema hardvera koji je pred vama.

Vanjske reference
-----------------

* `ULX3S hardverski priručnik <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_
* `ULX3S hardverski izvori <https://github.com/emard/ulx3s>`_
* `ULX Pinout Generator <https://github.com/ulx3s/ulx3s-pinout>`_
* `Tigard hardver/debug adapter <https://github.com/tigard-tools/tigard>`_
* `ESP32 JTAG mapiranje pinova <https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/jtag-debugging/configure-other-jtag.html>`_
* `ULX4M hardverski izvori <https://github.com/intergalaktik/ulx4m>`_
* `Waveshare CM4-IO-BASE-A shema <https://files.waveshare.com/upload/a/aa/CM4-IO-BASE-A_V4_SchDoc.pdf>`_
* `Waveshare CM4-IO-BASE-A carrier <https://www.waveshare.com/wiki/CM4-IO-BASE-A>`_
