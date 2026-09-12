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

Pločica ima 25 MHz oscilator. Hazard3-Doom iz njega generira taktove za procesor,
SDRAM i video. Trenutačni profili koriste 50 MHz za ULX3S 85F i 40 MHz za
ULX3S 12F. Video ima vlastite izvedene taktove pa timing provjera mora obuhvatiti
više od CPU takta.

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

I/O standardi
-------------

LPF opisuje i pinove i električno ponašanje. GPIO, SDRAM i mnogi periferni
signali koriste 3,3 V LVCMOS, dok GPDI video koristi uparene izlaze i routing
koji moraju odgovarati odabranom wrapperu i ograničenjima.
