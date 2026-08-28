Raspored repozitorija i vlasništvo
==================================

Hazard3-Doom namjerno odvaja vlasništvo aplikacije od višekratno upotrebljivog
Hazard3 procesorskog/debug RTL-a i od ULX3S-specifične SoC integracije izgrađene
oko njega.

Stablo repozitorija
-------------------

.. code-block:: text

   Hazard3-Doom/
   |-- benchmarks/coremark/
   |-- bin/
   |-- doom/
   |-- examples/esp32-sao-shared/
   |-- openocd/
   |-- scripts/
   |-- src/
   |-- tests/
   |-- third_party/Hazard3/
   |-- third_party/doomgeneric/
   |-- VisualGDB/
   |-- wads/
   `-- build/                  generated, ignored

Tri sloja vlasništva
--------------------

Korisno je hardversko vlasništvo podijeliti u tri sloja umjesto da se sve u
podmodulu Hazard3 jednostavno naziva "Hazard3 hardverom":

.. list-table::
   :header-rows: 1
   :widths: 32 24 44

   * - Stavka
     - Primarni vlasnik/podrijetlo
     - Lokacija / napomene
   * - Hazard3 CPU pipeline i višekratno upotrebljivi procesorski RTL
     - Wren6991/Hazard3 upstream
     - ``third_party/Hazard3/hdl/``; F/X/M pipeline, dekoder, CSR, ALU, registarska datoteka, CPU wrapperi i opcionalne arhitekturne značajke.
   * - Hazard3 Debug Module i DTM
     - Wren6991/Hazard3 upstream
     - ``third_party/Hazard3/hdl/debug/``; uključuje ECP5 JTAGG transport koji se koristi na ULX3S-u.
   * - Temelj minimalnog example-SoC-a
     - Wren6991/Hazard3 upstream
     - Integracija CPU/debug/RAM/UART/timer koju fork proširuje.
   * - ULX3S/ULX4M SoC i proširenja pločice
     - ulx3s/Hazard3 fork / projektna integracija
     - Dodatni SDRAM, video, SD SPI, SAO/ESP32, preload rezidentnog monitora, sinteza i ožičenje pločice u ``third_party/Hazard3/example_soc/``.
   * - Rezidentni monitor i loaderi
     - Hazard3-Doom
     - ``src/`` i ``doom/``.
   * - Potpune wrapper skripte za izgradnju pločice/aplikacije
     - Hazard3-Doom
     - ``scripts/build-*-doom.sh`` i povezane pomoćne skripte.
   * - Izvorni/forkani izvor aplikacije DoomGeneric
     - DoomGeneric
     - ``third_party/doomgeneric/``.

Snimak izvornog koda Hazard3
----------------------------

Dokumentacija procesora vezana je uz projektni Hazard3 snimak:

``736a74459b3f740c47803f20a62d820fcacbe5c3``

* `Fiksirani ULX3S Hazard3 izvor <https://github.com/ulx3s/Hazard3/tree/736a74459b3f740c47803f20a62d820fcacbe5c3>`_
* `Trenutačni upstream Hazard3 stable <https://github.com/Wren6991/Hazard3/tree/stable>`_
* :doc:`hazard3/project-integration` - detaljna usporedba upstreama i projekta.

Fiksirani commit izvor je istine za projektnu izgradnju. Trenutačni upstream je
referenca za ono što Hazard3 danas održava, ali novije upstream značajke ne
postaju projektne značajke dok se podmodul namjerno ne ažurira.

Kako klasificirati promjenu
---------------------------

Praktično pravilo je:

Ponašanje procesora
   ISA dekodiranje, pipeline hazardi, CSR semantika, ponašanje trapova, generički
   debug i popravci višekratno upotrebljivih CPU wrappera u pravilu se trebaju
   razmatrati kao upstream Hazard3 rad.

Višekratno upotrebljivo, ali platformski specifično SoC ponašanje
   SDRAM kontroleri, taktovi pločice, ECP5 integracija i generalizirane periferije
   mogu pripadati sloju Hazard3 forka/example-SoC-a.

Ponašanje aplikacije
   Naredbe rezidentnog monitora, učitavanje Dooma, politika framebuffer-a, host
   alati i tijekovi za krajnjeg korisnika pripadaju Hazard3-Doomu.

Podmoduli
---------

Superprojekt fiksira točne commitove Hazard3 i DoomGeneric. Prije dijagnosticiranja
regresije uvijek provjerite i granu superprojekta i commit podmodula. Sam naziv
grane nije dovoljan za reprodukciju hardvera.
