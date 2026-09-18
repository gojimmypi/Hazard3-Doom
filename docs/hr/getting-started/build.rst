Izgradnja Hazard3-Dooma
=======================

Potpune izgradnje za pločice
----------------------------

Potpune omotne skripte za pločice najsigurniji su način za izgradnju međusobno
usklađenih FPGA slike, monitora i Doom slike za jedan cilj.

ULX3S 85F, 64 MiB, 50 MHz:

.. code-block:: bash

   ./scripts/build-ulx3s-85f-doom.sh

Kompaktni cilj ULX3S 12F, zadano 32 MiB, 40 MHz:

.. code-block:: bash

   ./scripts/build-ulx3s-12f-doom.sh

ULX4M-LD 85F, softverska mapa 64 MiB, Hazard3 na 40 MHz i LiteDRAM na 60 MHz.
Uobičajeni build mora zadovoljiti sva ograničenja takta:

.. code-block:: bash

   ./scripts/build-ulx4m-ld-doom.sh

Potpune omotne skripte spremaju artifacts specifične za cilj u direktorije
vezane uz pločicu. Konkretno, Doom slike za prijenos nalaze se ovdje:

.. code-block:: text

   build/ulx3s-85f/doom-image/hazard3-doom.h3img
   build/ulx3s-12f/doom-image/hazard3-doom.h3img
   build/ulx4m-ld/doom-image/hazard3-doom.h3img

Samostalna naredba ``doom/build-doom-image.sh`` dokumentirana niže na ovoj
stranici i dalje koristi generički direktorij ``build/doom-image/`` osim ako je
postavljen ``HAZARD3_DOOM_BUILD_DIR``.

Build koristi zajedničke ULX4M-LD postavke definirane u
``scripts/build-ecp5-bitstream-common.sh`` i sažete u
:doc:`../reference/board-profiles`. Povijesna, verzijski spremljena zamrznuta
kontrolna točka seed 2 također je prošla potpunu DDR kvalifikaciju na
ULX4M-LD pločici s Micron memorijom. Novi potpuni build ipak stvara novi
netlist, pa za release artifact ponovno pokrenite timing sweep i hardverske
testove. ``ALLOW_TIMING_FAILURE=1`` rezerviran je za izričite ULX4M-LD sweep
eksperimente, a ne za release buildove. Pogledajte
:doc:`../reference/board-profiles` i :doc:`../reference/timing-sweeps`.

Omotna skripta za 12F podržava SDRAM mapu od 32 MiB ili 64 MiB, ali je zadana
vrijednost 32 MiB. Ako odaberete mapu od 64 MiB, monitor i Doom slika moraju biti
međusobno usklađeni:

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=64m ./scripts/build-ulx3s-12f-doom.sh

Kompaktni cilj 12F namjerno podržava samo Doom/video put 320x200. Njegov EBR
od 1 KiB ne može sadržavati puni monitor, pa potpuni build stvara mali rezidentni
UART bootstrap i ugrađuje ga u ``fpga_ulx3s_12f.bit``. Pri hladnom pokretanju
bootstrap inicijalizira konzolu na 115200 baud i objašnjava da se puni monitor
nalazi u SDRAM-u. Nakon programiranja 12F bitstreama pokrenite:

.. code-block:: bash

   ./scripts/load-firmware-12f.sh

Pomoćna skripta ponovno koristi OpenOCD server koji već sluša na
``localhost:3333`` ili automatski pokreće ``scripts/start-openocd.sh``, čeka GDB
server, učitava i provjerava
``build/ulx3s-12f/monitor/hazard3-boot-monitor.elf`` te zaustavlja samo OpenOCD
proces koji je sama pokrenula.

Samo rezidentni monitor
-----------------------

Generički alat za izgradnju monitora zadano koristi mapu od 64 MiB na 50 MHz:

.. code-block:: bash

   ./scripts/build.sh

Tipični izlazi:

.. code-block:: text

   build/hazard3-boot-monitor.elf
   build/hazard3-boot-monitor.map
   build/hazard3-boot-monitor.bin

Potpune omotne skripte za pločice umjesto vas postavljaju profil memorije,
sistemski takt i linker skriptu za ciljni uređaj. Za ručne izgradnje glavne su
kontrole ``HAZARD3_MEMORY_PROFILE``, ``HAZARD3_SYS_CLK_HZ`` i
``HAZARD3_MONITOR_LINKER_SCRIPT``.

Za softversko ažuriranje samo ULX4M-LD monitora na već konfiguriranom FPGA-u na
40 MHz, spremite izlaz odvojeno od rezidentnog preloada:

.. code-block:: bash

   HAZARD3_BUILD_DIR="$PWD/build/ulx4m-ld-monitor-test/monitor" \
   HAZARD3_MEMORY_PROFILE=64m \
   HAZARD3_SYS_CLK_HZ=40000000 \
       ./scripts/build.sh

Učitajte ga kroz već pokrenutu OpenOCD sesiju pomoću:

.. code-block:: bash

   ./scripts/load-firmware.sh \
       ./build/ulx4m-ld-monitor-test/monitor/hazard3-boot-monitor.elf

Time se ažurira samo procesorski softver u aktivnom FPGA-u i ne rerouta se
poznato dobar bitstream.

Samo povezana Doom slika
------------------------

Za profil od 64 MiB koji koriste ULX3S 85F i ULX4M-LD 85F:

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=64m ./doom/build-doom-image.sh

Za 12F sliku od 32 MiB:

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=32m \
   HAZARD3_DOOM_HDMI_RESOLUTION=320x200 \
       ./doom/build-doom-image.sh

Tipični izlazi:

.. code-block:: text

   build/doom-image/hazard3-doom.elf
   build/doom-image/hazard3-doom.map
   build/doom-image/hazard3-doom.bin
   build/doom-image/hazard3-doom.h3img

Ispitivanje druge Hazard3 kopije
--------------------------------

Možete ispitati drugu kopiju hardvera bez promjene pokazivača na podmodul
Hazard3-Dooma:

.. code-block:: bash

   HAZARD3_ROOT=/mnt/c/workspace/Hazard3 \
       ./scripts/build-ulx3s-85f-doom.sh

Priprema i provjera podmodula
-----------------------------

Inicijalizirajte podmodule potrebne za izgradnju:

.. code-block:: bash

   ./scripts/setup-submodules.sh

Time se inicijaliziraju DoomGeneric i Hazard3 te ugniježđeni Hazard3 podmoduli
``scripts`` i ``example_soc/libfpga``. Za inicijalizaciju cijelog rekurzivnog stabla:

.. code-block:: bash

   HAZARD3_INIT_ALL_SUBMODULES=1 ./scripts/setup-submodules.sh

Za dijagnostiku povijesti izvora i podmodula pogledajte :doc:`../reference/scripts`.
Posebno, Windows naredba ``check_submodules.bat`` provjerava lokalno zabilježene
gitlinkove, dok ``hazard3-doom-source-status.sh`` uspoređuje grane između
povezanih GitHub forkova.

Odabir seeda
------------

Nemojte naslijepo ponovno koristiti prethodno dobar nextpnr seed nakon značajne
promjene netliste. Upotrijebite skripte samo za placement za brzo rangiranje
kandidata, a potpune routed sweepove za mjerodavno mjerenje vremena i generiranje
bitstreama.

Na primjer, tok za 12F može koristiti:

.. code-block:: bash

   SWEEP_JOBS=30 ./scripts/sweep-peek-ulx3s-12f.sh --all
   SWEEP_JOBS=30 ./scripts/sweep-ulx3s-12f.sh --all

Pogledajte :doc:`../reference/scripts` za katalog sweep pomoćnika i
:doc:`../reference/timing-sweeps` za GitHub Actions matricu, odabir parametara,
live timing monitor, timeoute, artifacts i pravila reproducibilnosti.

Vlasništvo nad izgradnjom
-------------------------

Projekt namjerno zadržava višekratno upotrebljiv FPGA/CPU hardver u Hazard3,
a dijelove monitora/aplikacije specifične za Doom u Hazard3-Doomu. Pogledajte
:doc:`../architecture/repositories`.
