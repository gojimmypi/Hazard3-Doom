ULX3S hardverski vodič
======================

**Arhitektura, resursi pločice, sučelja i njihova uporaba u Hazard3-Doomu.**

ULX3S je open-hardware FPGA razvojna pločica temeljena na Lattice ECP5-u,
namijenjena obrazovanju, istraživanju i općim FPGA projektima. Uz FPGA sadrži
vanjski SDR SDRAM, SPI konfiguracijsku flash memoriju, micro-SD, GPDI digitalni
video, USB/JTAG/UART, GPIO, tipke, LED-ove, audio, ADC, RTC i opcionalni/ugrađeni
ESP32 put.

Ta kombinacija dobro odgovara Hazard3-Doomu: pločica može sadržavati procesor,
vanjsku radnu memoriju, indeksirani video, izmjenjivu pohranu, rezidentni monitor
i više neovisnih putova za programiranje i otklanjanje pogrešaka.

.. important::

   Gustoća FPGA-a i revizija PCB-a dvije su različite oznake. Pločica može imati
   ECP5 12F, 25F, 45F ili 85F i istodobno zasebnu PCB reviziju, primjerice 3.0.x
   ili 3.1.x. Prije uporabe sheme, LPF-a ili build cilja utvrdite obje.

Hazard3-Doom trenutačno ima potpune build putove za ULX3S 85F i kompaktni
ULX3S 12F. Druge FPGA gustoće postoje u hardverskoj obitelji, ali to ne znači da
je cijeli Doom SoC kvalificiran za svaku populaciju.

.. toctree::
   :maxdepth: 2

   overview-and-variants
   fpga-and-clocking
   memory
   boot-and-flash
   video-and-storage
   interfaces
   pinout-and-revisions
   sources

Koristan mentalni model
-----------------------

.. code-block:: text

   +---------------------------------------------------------------+
   | ULX3S pločica                                                 |
   |                                                               |
   |  +-------------+       +------------------+                   |
   |  | SPI flash   |<----->| Lattice ECP5     |<----> GPDI video  |
   |  +-------------+       | FPGA             |<----> US1/JTAG    |
   |                        |                  |<----> J1/J2 GPIO   |
   |  +-------------+       | Hazard3 SoC      |<----> micro-SD    |
   |  | SDR SDRAM   |<----->| + kontroleri     |<----> ESP32       |
   |  +-------------+       +------------------+                   |
   |                               |                               |
   |                      rezidentni monitor u EBR-u               |
   +---------------------------------------------------------------+

Vodič razdvaja hardver prisutan na ULX3S-u, ono što stvarna PCB revizija i FPGA
gustoća povezuju te ono što Hazard3-Doom trenutačno implementira i kvalificira.
