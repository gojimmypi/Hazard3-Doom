Rad DFU bootloadera i oporavak
==============================

.. important::

   Zamjena DFU bootloadera na pločici **vrlo je neuobičajena** i **nije** dio
   uobičajene instalacije Hazard3-Dooma, učitavanja novog FPGA bitstreama,
   ažuriranja Hazard3 monitora ili ažuriranja Dooma.

   U normalnom radu zadržite postojeći bootloader i mijenjajte samo
   **korisnički bitstream** u predviđenom DFU području. Područje bootloadera u
   flash memoriji izlažite i zapisujte samo pri namjernom razvoju bootloadera
   ili oporavku pločice čiji je trajni bootloader nestao, oštećen ili poznato
   nekompatibilan.

Ova stranica opisuje USB DFU bootloader na razini pločice za ULX3S i ULX4M-LD.
Normalan DFU rad namjerno je odvojen od rijetkog postupka zamjene i oporavka
bootloadera.

Nemojte miješati ove tri komponente
-----------------------------------

``DFU bootloader``
   Trajna FPGA konfiguracija i malo firmware okruženje na početku SPI flasha.
   Omogućuje USB DFU i zatim predaje upravljanje korisničkoj FPGA slici.

``Korisnički FPGA bitstream``
   Uobičajena Hazard3-Doom FPGA slika. Njegovo ažuriranje je rutinsko i ne
   zahtijeva zamjenu DFU bootloadera.

``Hazard3 boot monitor``
   RISC-V firmware koji gradi Hazard3-Doom, primjerice
   ``hazard3-boot-monitor.elf``. Njegova ponovna izgradnja ili učitavanje ne
   znači da treba zamijeniti DFU bootloader pločice.

Za novu Hazard3-Doom FPGA sliku koristite
:doc:`../getting-started/programming`. Za JTAG otklanjanje pogrešaka koristite
:doc:`jtag-debugging`.

Kada je zamjena bootloadera stvarno opravdana
---------------------------------------------

Zamjenu tretirajte kao naprednu operaciju održavanja ili oporavka. Uobičajeni
razlozi ograničeni su na sljedeće slučajeve:

* trajni DFU bootloader više se ne enumerira i dijagnosticiran je kao nestao ili
  oštećen;
* revizija pločice zahtijeva namjernu promjenu mapiranja pinova ili hardverske
  kompatibilnosti bootloadera;
* aktivno razvijate i provjeravate sam bootloader.

Instalacija Hazard3-Dooma, novi FPGA bitstream, promjena Hazard3/LiteDRAM RTL-a,
ažuriranje ``hazard3-boot-monitor.elf`` ili učitavanje Dooma **nisu** razlozi za
zamjenu bootloadera.

Normalan rad
------------

USB DFU uređaj enumerira se kao VID:PID ``1d50:614b``. Normalni korisnički
bitstream koristi alternate setting 0. Uobičajeno ažuriranje zato cilja **alt
0**, a ne područje bootloadera.

ULX3S
~~~~~

ULX3S bootloader pruža DFU na ``US2``. ``US1`` passthrough za programiranje
ESP32-a specifičan je za ULX3S i ne treba ga pretpostaviti na ULX4M-LD.

Za ulazak u DFU na ULX3S-u držite ``BTN1`` ili uključite ``SW1`` te spojite
``US2``.

Ako se pločica ne napaja preko ``US2`` zbog USB/RTC stanja napajanja, upstream README bootloadera opisuje dvije mogućnosti oporavka: spojite i ``US1`` ili držite ``BTN1`` i kratko pritisnite ``BTN0`` kako biste uključili pločicu. Provjerite enumeraciju:

.. code-block:: bash

   dfu-util -l

Normalni korisnički bitstream zapisuje se na alt 0:

.. code-block:: bash

   dfu-util -a 0 -D blink.bit

Za izlazak iz DFU-a i pokretanje spremljene slike:

.. code-block:: bash

   dfu-util -a 0 -e

ULX4M-LD
~~~~~~~~

Provjereno mapiranje za ULX4M-LD v0.0.3 koristi ove fizičke oznake tipki:

.. list-table:: ULX4M-LD ponašanje pri pokretanju
   :header-rows: 1
   :widths: 35 65

   * - Uvjet
     - Rezultat
   * - Bez tipki
     - Pokreće korisnički bitstream od adrese ``0x200000``.
   * - PCB ``BTN3``
     - Normalni DFU; alt 0 do 4 vidljivi, alt 5 skriven.
   * - PCB ``BTN2`` + ``BTN3``
     - DFU za nadogradnju bootloadera; alt 0 do 5 vidljivi.

.. warning::

   ``BTN2`` + ``BTN3`` **nije** normalni način programiranja. On izlaže alt 5,
   gdje se nalazi bootloader. Za uobičajeno Hazard3-Doom ažuriranje koristite
   samo ``BTN3`` i programirajte alt 0.

Provjereni DFU raspored:

.. list-table:: ULX4M-LD alternate settings
   :header-rows: 1
   :widths: 10 35 55

   * - Alt
     - Flash raspon
     - Namjena
   * - 5
     - ``0x000000-0x1FFFFF``
     - Bootloader; skriven u normalnom DFU načinu.
   * - 4
     - ``0x800000-0xFFFFFF``
     - Korisnički podaci.
   * - 3
     - ``0x400000-0xFFFFFF``
     - Korisnički podaci.
   * - 2
     - ``0x360000-0x3FFFFF``
     - SaxonSoc U-Boot područje.
   * - 1
     - ``0x340000-0x35FFFF``
     - SaxonSoc ``fw_jump`` područje.
   * - 0
     - ``0x200000-0xFFFFFF``
     - Normalno područje korisničkog bitstreama.

Za uobičajeno ažuriranje isključite napajanje, držite PCB ``BTN3`` dok spajate
Micro-B kabel, pričekajte enumeraciju ``1d50:614b``, a zatim otpustite ``BTN3``.
Tipku nije potrebno držati tijekom prijenosa. Ako Bash u WSL-u za priložene
Windows alate prijavi ``Permission denied``:

.. code-block:: bash

   chmod +x ./bin/openFPGALoader.exe ./bin/dfu-util.exe

Normalna Hazard3-Doom naredba:

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

Za izlazak iz DFU-a:

.. code-block:: bash

   ./bin/dfu-util.exe -a 0 -e

Opcija ``-e`` ne zamjenjuje bootloader; pokreće već spremljenu korisničku sliku.

Rijetka zamjena i oporavak bootloadera
--------------------------------------

.. danger::

   Nemojte zamijeniti ispravan bootloader samo zato što postoji novija verzija
   Hazard3-Dooma. Ažuriranje bootloadera zapisuje prva 2 MiB flash memorije i
   može ukloniti najjednostavniji DFU put oporavka.

Za ULX4M-LD ključno je pravilo provjeriti novi bootloader u FPGA SRAM-u **prije**
zapisa trajnog alt-5 područja.

0.2.0 CI pin alata
~~~~~~~~~~~~~~~~~~

GitHub Actions workflow ``ULX4M Bootloader`` za izdanje 0.2.0 namjerno fiksira
OSS CAD Suite na ``2026-09-14``. Time se zadržava poznato dobra okolina za
sintezu i place-and-route koja je korištena za provjeru izdanja, umjesto tihog
praćenja novijih nightly verzija alata.

Kasniji OSS CAD Suite nightly otkrio je problem višestrukih drivera u postojećoj
uporabi ECP5 ``TRELLIS_IO`` primitiva samo za ulaz. RTL čišćenje, testiranje s
novijom verzijom suitea i svako namjerno ažuriranje fiksirane CAD verzije posao
su za 0.3.0. Do tada je 0.2.0 pin dio reproducibilnog okruženja za izgradnju
bootloadera.

Konzervativni slijed:

#. Izgradite bootloader za točnu pločicu i FPGA.
#. Napravite i provjerite SRAM sliku bez trajnog ``--bootaddr``.
#. Odvojeno provjerite normalni DFU i način nadogradnje.
#. Spremite postojeća 2 MiB iz alt 5.
#. Pripremite alt-5 sliku veličine točno 2 MiB.
#. Pokrenite poznato dobar bootloader iz SRAM-a u načinu nadogradnje.
#. Zapišite alt 5.
#. Pročitajte alt 5 natrag prije isključivanja napajanja.
#. Provjerite veličinu i SHA256.
#. Tek zatim provedite testove hladnog pokretanja.

Sigurnosna kopija alt 5:

.. code-block:: bash

   ./bin/dfu-util.exe -d 1d50:614b -a 5 \
       -U bootloader-alt5-before-update.bin

Očekivana veličina je točno ``2097152`` bajtova.

Nakon zapisa ponovno pročitajte područje i usporedite hash vrijednosti prije
isključivanja napajanja. Ako trajni DFU nije dostupan, provjereni ULX4M-LD put
oporavka koristi Tigard/JTAG za učitavanje hitnog bootloadera u SRAM s
``EMERGENCY_RESTORE2`` te zatim vraća alt 5.

Za točne naredbe izgradnje, SRAM repacking, oporavak i provjeru pogledajte
``bootloader/README_ULX4M_BOOTLOADER.md``. Ti su koraci namjerno odvojeni od
normalnog programiranja.


Postupak oporavka ULX4M-LD dokumentiran u ``bootloader/README_ULX4M_BOOTLOADER.md`` provjeren je na ULX4M-LD v0.0.3 s LFE5UM-85F FPGA-om i JTAG IDCODE-om ``0x01113043``. Nemojte koristiti sliku izgrađenu za drugu gustoću FPGA-a ili neprovjereno mapiranje pločice.

Siguran slijed zamjene
~~~~~~~~~~~~~~~~~~~~~~

Najvažnije pravilo glasi: **zamjenski bootloader provjerite u FPGA SRAM-u prije
pisanja trajne bootloader regije u flashu**.

Konzervativni slijed zamjene:

#. Izgradite namijenjeni bootloader za točnu pločicu i FPGA.
#. Prepakirajte testnu sliku samo za SRAM bez trajne postavke ``--bootaddr``.
#. Učitajte je preko JTAG-a i provjerite uobičajeni DFU rad.
#. Zasebno provjerite način nadogradnje bootloadera.
#. Prije prepisivanja spremite postojeću alt-5 bootloader regiju.
#. Pripremite sliku veličine točno 2 MiB za alt 5.
#. Pokrenite poznato ispravan bootloader iz FPGA SRAM-a u načinu nadogradnje.
#. Dok ta SRAM kopija radi, zapišite zamjenu u alt 5.
#. Pročitajte alt 5 natrag prije ciklusa napajanja.
#. Provjerite očitano bajt-po-bajt ili usporedbom SHA256 hashova.
#. Tek nakon uspješnog očitanja isključite napajanje i provedite testove hladnog
   pokretanja.

Postupak namjerno izbjegava izvršavanje bootloadera iz flasha dok se ta ista
flash regija zamjenjuje.

Sigurnosna kopija ULX4M-LD alt 5
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Kada je alt 5 namjerno izložen načinom nadogradnje bootloadera, spremite postojeća
prva 2 MiB prije bilo kakvog pisanja:

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -U bootloader-alt5-before-update.bin

Provjerite veličinu kopije i zabilježite hash:

.. code-block:: bash

   stat -c '%n: %s bytes' bootloader-alt5-before-update.bin
   sha256sum bootloader-alt5-before-update.bin

Očekivana veličina je točno ``2097152`` bajtova.

Pisanje i provjera zamjene
~~~~~~~~~~~~~~~~~~~~~~~~~~

Dok poznato ispravan SRAM bootloader i dalje radi u namjernom načinu nadogradnje,
zapišite sliku veličine točno 2 MiB u alt 5:

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -D bootloader-alt5-2m.img

Nemojte odmah napraviti ciklus napajanja. Najprije ponovno pročitajte regiju:

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -U bootloader-alt5-after-update.bin

Zatim provjerite da obje datoteke imaju točno 2 MiB i jednake hashove:

.. code-block:: bash

   stat -c '%n: %s bytes' \
       bootloader-alt5-2m.img \
       bootloader-alt5-after-update.bin

   sha256sum \
       bootloader-alt5-2m.img \
       bootloader-alt5-after-update.bin

Ne pokrećite zamjenski bootloader hladnim pokretanjem ako se veličine ili hashovi
razlikuju.

ULX4M-LD provjera hladnog pokretanja
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Nakon provjerenog očitanja alt 5 potpuno uklonite napajanje kako bi se SRAM testna
slika izgubila. Zatim provjerite sva tri trajna puta pokretanja:

#. Bez tipki: pokreće se normalni korisnički bitstream.
#. PCB ``BTN3``: pokreće se obični DFU, a alt 5 ostaje skriven.
#. PCB ``BTN2`` + ``BTN3``: pokreće se DFU za nadogradnju i alt 5 je vidljiv.

Tek nakon uspjeha sva tri testa zamjena bootloadera može se smatrati dovršenom.

JTAG oporavak kada trajni DFU nije dostupan
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ako se trajni bootloader ne enumerira kao ``1d50:614b``, provjereni ULX4M-LD
oporavak koristi Tigard/JTAG za učitavanje hitnog bootloadera u FPGA SRAM. Izvor
bootloadera pruža ``EMERGENCY_RESTORE2`` koji prisilno uključuje i "ostani u DFU"
i dopuštenje pisanja bootloadera kako bi se alt 5 mogao obnoviti.

Lanac oporavka je:

.. code-block:: text

   Tigard JTAG
       -> emergency bootloader in FPGA SRAM
       -> USB DFU 1d50:614b
       -> alt 5 access
       -> restore exactly first 2 MiB
       -> read back exactly first 2 MiB
       -> SHA256 match
       -> cold boot from SPI flash

Za točne ULX4M-LD naredbe izgradnje, postupak SRAM prepakiranja, remaper tipki,
mapiranje pinova i detalje hitne izgradnje koristite izvorni dokument
``bootloader/README_ULX4M_BOOTLOADER.md``. Ti su koraci namjerno izvan uobičajenog
Hazard3-Doom puta programiranja jer pripadaju oporavku pločice i razvoju
bootloadera, a ne rutinskom programiranju aplikacije.

Napomena o zaštiti bootloadera ULX3S od pisanja
-----------------------------------------------

Izvorni ULX3S bootloader može zaštititi od pisanja prva 2 MiB na podržanim 16 MiB
ISSI IS25LP128 i Winbond W25Q128 flash uređajima. Ponašanje zaštite ovisi o
proizvođaču flasha. Izvorni README također upozorava da neke verzije
``openFPGALoader`` mogu ukloniti zaštitu koja nije OTP tijekom pisanja flasha.

Svako ažuriranje ULX3S bootloader regije tretirajte kao zaseban zahvat održavanja.
Nemojte koristiti naredbe za trajni flash koje prepisuju prva 2 MiB samo da biste
instalirali novu Hazard3-Doom korisničku sliku.

Izvori
------

* ``bootloader/README.md`` - ULX3S DFU rad i zaštita flash memorije.
* ``bootloader/README_ULX4M_BOOTLOADER.md`` - provjereni ULX4M-LD postupak
  izgradnje, SRAM testa, sigurnosne kopije, oporavka, instalacije i readbacka.

Reference implementacije
------------------------

* `openFPGALoader <https://trabucayre.github.io/openFPGALoader/guide/install.html>`_
