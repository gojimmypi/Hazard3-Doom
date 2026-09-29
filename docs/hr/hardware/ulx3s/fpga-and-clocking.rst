FPGA, taktovi i I/O domene
==========================

ECP5 obitelj
------------

ULX3S koristi Lattice ECP5 FPGA-e u 381-ball kućištu. Upstream hardver podržava
12F, 25F, 45F i 85F populacije, a Hazard3-Doom trenutačno ima potpune wrappere
za 85F i 12F.

Gustoća mijenja dostupne LUT, EBR i routing resurse, ali sama ne određuje PCB
reviziju.

25 MHz oscilator
----------------

Izvorni ULX3S dizajn ima ugrađeni oscilator od 25 MHz. Hazard3-Doom koristi tu
referencu za generiranje taktova potrebnih procesoru, SDRAM-u i video logici.

Trenutačne osnovne postavke profila pločica su:

.. list-table::
   :header-rows: 1
   :widths: 24 20 56

   * - Cilj
     - Hazard3 takt
     - Namjena
   * - ULX3S 85F
     - 50 MHz
     - CPU, AHB/SoC logika, strana SDRAM kontrolera, monitor i platformska logika.
   * - ULX3S 12F
     - 40 MHz
     - CPU/SoC i SDRAM cilj sa smanjenim resursima.

Video koristi vlastite izvedene taktove, pa zatvaranje timinga mora obuhvatiti
više od samog CPU takta. Točne vrijednosti routanih taktova rezultat su izgradnje,
a ne trajne specifikacije pločice.

SDRAM i timing
--------------

Vanjska memorija je sinkroni SDR SDRAM. Wrapper i kontroler održavaju potreban
fazni odnos sustava i fizičkog SDRAM takta. Promjena ``HAZARD3_SYS_CLK_HZ`` zato
utječe i na memorijski podsustav i timing ograničenja.

Zadane nextpnr postavke centralizirane su u
``scripts/build-ecp5-bitstream-common.sh`` i sažete u
:doc:`../../reference/board-profiles`. Seed koji prolazi na 85F nije dokaz za
12F i mora se ponovno kvalificirati nakon synthesis-visible promjene. Vidi
:doc:`../../reference/timing-sweeps`.


Zatvaranje timinga ovisi o cilju
--------------------------------

Hazard3-Doom centralizira zadane nextpnr postavke routinga u
``scripts/build-ecp5-bitstream-common.sh``. Trenutačne referentne postavke
izdanja također su sažete u :doc:`../../reference/board-profiles`.

Seed koji prolazi na ULX3S 85F nije dokaz da će proći na 12F, a ranije dobar seed
ne treba smatrati valjanim nakon promjene RTL-a vidljive sintezi, predučitavanja
monitora, lanca alata ili ograničenja. Projektni postupak sweepa opisan je u
:doc:`../../reference/timing-sweeps`.

I/O standardi
-------------

LPF opisuje i pinove i električno ponašanje. GPIO, SDRAM i mnogi periferni
signali koriste 3,3 V LVCMOS, dok GPDI video koristi uparene izlaze i routing
koji moraju odgovarati odabranom wrapperu i ograničenjima.
