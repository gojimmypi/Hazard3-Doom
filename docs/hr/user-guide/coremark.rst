Mjerenje Hazard3 procesora s CoreMarkom
=======================================

CoreMark je samostalan bare-metal program. Zamjenjuje monitor u internoj SRAM
memoriji i ispisuje rezultate preko UART-a. Ne koristi H3IMG protokol niti mjeri
Doomov SDRAM, predmemoriju ili framebuffer.

Zahtjevi
--------

Prije učitavanja ELF-a programirajte odgovarajući Hazard3 bitstream. Port koristi
128 KiB interne SRAM memorije, ``0x00000000-0x0001FFFF``, s vektorima na
``0x00000040``. Raspored definira ``benchmarks/coremark/link.ld``. Koristite
odgovarajući ULX3S-85F dizajn. Kompaktni ULX3S-12F ima samo 1 KiB početne SRAM
memorije i ne može pokrenuti ovaj ELF bez prilagodbe. Za druge ploče prvo
provjerite memoriju, ISA, takt i adrese perifernih uređaja.

Prevedeni ISA je ``rv32imc_zicsr_zifencei_zba_zbb_zbs``, ABI ``ilp32``.
``HAZARD3_SYS_CLK_HZ`` mora odgovarati stvarnom FPGA taktu. Skripta prihvaća samo
``25000000`` ili ``50000000`` (zadano). Za cilj na 40 MHz potrebna je i izmjena
skripte; sama varijabla okruženja nije dovoljna.

Inicijalizirajte Hazard3 podmodul i instalirajte RISC-V GCC/GDB, Python 3 i
OpenOCD. Pogledajte :doc:`../getting-started/prerequisites`. Spojite vanjski UART:
115200 baud, 8N1, bez kontrole protoka; ožičenje je na :doc:`pinouts`.

Izgradnja
---------

Iz korijena repozitorija, u Bashu (WSL na Windowsu):

.. code-block:: bash

   ./scripts/build-coremark.sh

Zadanih 3000 iteracija stvara:

.. code-block:: text

   build/coremark/baseline/coremark-performance.elf
   build/coremark/baseline/coremark-validation.elf

``baseline`` i ``tuned`` su profili optimizacije prevoditelja. ``performance`` i
``validation`` su konfiguracije početnih vrijednosti benchmarka; obje moraju
proći validaciju. Za profil ``tuned``:

.. code-block:: bash

   COREMARK_BUILD_PROFILE=tuned ./scripts/build-coremark.sh

Izlazi su u ``build/coremark/tuned/``. Izgradnja provjerava izvore CoreMarka prema
Hazard3 commitu i ISA atribute ELF-a prema referentnom objektu. Sprema
``build-info.txt``, ``source-integrity.json`` te ``.map``, ``.isa.txt`` i
``.isa.json`` datoteke. ISA PASS izgradnje ne potvrđuje kompatibilnost bitstreama.

Učitavanje i snimanje
---------------------

U zasebnom terminalu pokrenite OpenOCD i ostavite ga aktivnim:

.. code-block:: bash

   ./scripts/start-openocd.sh ulx3s-85f

Pričekajte otkrivanje harta i slušanje na portu 3333. Odspojite druge GDB klijente,
uključujući VisualGDB. Pogledajte :doc:`jtag-debugging`. Za ručno snimanje otvorite
UART terminal prije učitavanja:

.. code-block:: bash

   ./scripts/load-firmware.sh ./build/coremark/baseline/coremark-performance.elf
   ./scripts/load-firmware.sh ./build/coremark/baseline/coremark-validation.elf

Pokrenite naredbe zasebno; pričekajte završetak prvog benchmarka prije drugog.
Skripta zaustavlja CPU, učitava i uspoređuje sekcije, postavlja ``$pc`` na
``_start``, nastavlja izvršavanje i odspaja GDB. Nije potrebna naredba monitora.
Za druge programe pogledajte :ref:`load-custom-elf`.

Za automatsko snimanje instalirajte ``pyserial`` u korišteno Python okruženje i
zatvorite ostale aplikacije koje koriste UART:

.. code-block:: bash

   ./scripts/run-coremark.sh performance /dev/ttyS7
   ./scripts/run-coremark.sh validation /dev/ttyS7
   ./scripts/run-coremark.sh qualify /dev/ttyS7

Zamijenite port uređajem dostupnim Pythonu. ``qualify`` pokreće obje slike i
zahtijeva serijski port. Bez porta, ``performance`` i ``validation`` samo učitavaju
ELF za ručno snimanje. OpenOCD mora već raditi. Skripta stvara nedostajuće izlaze,
ali ne obnavlja postojeći ELF kada se parametri promijene. Ponovno ga izgradite;
za izgradnju i snimanje koristite isti profil i takt:

.. code-block:: bash

   HAZARD3_SYS_CLK_HZ=25000000 COREMARK_BUILD_PROFILE=tuned ./scripts/build-coremark.sh
   HAZARD3_SYS_CLK_HZ=25000000 COREMARK_BUILD_PROFILE=tuned ./scripts/run-coremark.sh qualify /dev/ttyS7

Rezultati i otklanjanje poteškoća
---------------------------------

Uspješan ispis sadrži ``Correct operation validated.``, 64-bitne brojače
``cycles`` i ``instructions`` te ``COREMARK_DONE``. Koristite sažetak računala za
trajanje, CoreMark/s, CoreMark/MHz i cikluse po instrukciji. Standardni ispis cilja
s ``HAS_FLOAT=0`` koristi cijele sekunde i gubi preciznost.

Svako izvršavanje mora trajati najmanje 10 sekundi. Ako je kraće, povećajte broj
iteracija, ponovno izgradite i ponovite provjeru:

.. code-block:: bash

   COREMARK_ITERATIONS=4000 ./scripts/build-coremark.sh
   ./scripts/run-coremark.sh qualify /dev/ttyS7

``qualify`` ispisuje ``RESULT : VALID`` samo ako obje izvedbe prođu provjere.
Sačuvajte ``coremark-<run>.run.log``, ``coremark-<run>.result.json``, metapodatke,
ELF hash, izvještaj memorije, FPGA konfiguraciju i stvarni takt. Pojedinosti su u
``benchmarks/coremark/README.md``.

Ako nema UART ispisa, provjerite ožičenje, port, 115200 8N1, takt i nastavak CPU-a.
Za nedopuštenu instrukciju provjerite ISA bitstreama. Za neuspjelo učitavanje ili
usporedbu provjerite RAM i OpenOCD konfiguraciju. Za netočno trajanje provjerite
takt izgradnje i snimanja; softverska postavka ne mijenja FPGA takt. Python runner
zadano čeka 120 sekundi, uključujući učitavanje.

Za povratak na ULX3S-85F monitor, uz aktivan OpenOCD:

.. code-block:: bash

   ./scripts/load-firmware.sh ./build/ulx3s-85f/monitor/hazard3-boot-monitor.elf

Naredba učitava RAM; ne programira FPGA ni SPI flash.
