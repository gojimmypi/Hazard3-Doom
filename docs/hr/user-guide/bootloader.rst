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
``US2``. Provjerite enumeraciju:

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

Izvori
------

* ``bootloader/README.md`` - ULX3S DFU rad i zaštita flash memorije.
* ``bootloader/README_ULX4M_BOOTLOADER.md`` - provjereni ULX4M-LD postupak
  izgradnje, SRAM testa, sigurnosne kopije, oporavka, instalacije i readbacka.
