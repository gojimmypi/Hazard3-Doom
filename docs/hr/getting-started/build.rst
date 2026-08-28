Izgradnja Hazard3-Dooma
=======================

Potpune izgradnje za pločice
----------------------------

Potpune omotne skripte za pločice najsigurniji su način za izgradnju međusobno
usklađenih FPGA slike, monitora i Doom slike za jedan cilj.

ULX3S 85F, 64 MiB, 50 MHz:

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh

Kompaktni cilj ULX3S 12F, zadano 32 MiB, 40 MHz:

.. code-block:: bash

   ./scripts/build-ulx3s-12f-doom.sh

ULX4M-LD 85F, 64 MiB, 50 MHz:

.. code-block:: bash

   ./scripts/build-ulx4m-ld-doom.sh

Omotna skripta za 12F podržava SDRAM mapu od 32 MiB ili 64 MiB, ali je zadana
vrijednost 32 MiB. Ako odaberete mapu od 64 MiB, monitor i Doom slika moraju biti
međusobno usklađeni:

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=64m ./scripts/build-ulx3s-12f-doom.sh

Kompaktni cilj 12F namjerno podržava samo Doom/video put 320x200.
Nakon programiranja 12F bitstreama i pokretanja OpenOCD-a, učitajte njegov
monitor koji se nalazi u SDRAM-u pomoću:

.. code-block:: bash

   ./scripts/load-firmware-12f.sh

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
   build/doom-image/hazard3-doom.h3d

Ispitivanje druge Hazard3 kopije
--------------------------------

Možete ispitati drugu kopiju hardvera bez promjene pokazivača na podmodul
Hazard3-Dooma:

.. code-block:: bash

   HAZARD3_ROOT=/mnt/c/workspace/Hazard3 \
       ./scripts/build-ulx3s-doom.sh

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

Pogledajte :doc:`../reference/scripts` za pomoćne skripte za sweepove 85F, 12F i
ULX4M-LD te lokacije rezultata.

Vlasništvo nad izgradnjom
-------------------------

Projekt namjerno zadržava višekratno upotrebljiv FPGA/CPU hardver u Hazard3,
a dijelove monitora/aplikacije specifične za Doom u Hazard3-Doomu. Pogledajte
:doc:`../architecture/repositories`.
