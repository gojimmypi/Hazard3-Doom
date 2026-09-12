USB, JTAG, UART, GPIO i ESP32 sučelja
=====================================

``US1`` FT231X put
------------------

Glavni ``US1`` priključak vodi do FT231X-a koji se koristi za komunikaciju i
JTAG programiranje. Hazard3-Doom ga koristi s ``fujprog`` alatom, WebUSB
flasherom, OpenOCD-om s FT231X/``ft232r`` podrškom i board/ESP32 serijskim
workflowom kada je aktivan uobičajeni FTDI driver.

Projektno testirani Hazard3 monitor UART koristi zasebno J1 ``GP0``/``GP1``
ožičenje opisano niže; otvaranje ``US1`` FT231X serijskog porta ne treba
smatrati istim signalnim putem.

Na Windowsu je izbor drivera važan; prije promjene vidi
:doc:`../../troubleshooting` i :doc:`../../user-guide/web-flasher`.

Vanjski JTAG
------------

ULX3S ima i šest-pinski JTAG header s TCK, TDI, TDO, TMS, 3,3 V i GND. Prije
spajanja vanjskog adaptera provjerite redoslijed signala i naponske razine.

Hazard3-Doom UART
-----------------

Testirano vanjsko UART ožičenje je:

.. code-block:: text

   RxD -> J1 pin 8 / GP1  (na TX adaptera)
   TxD -> J1 pin 6 / GP0  (na RX adaptera)
   GND -> susjedni ground

To je projektna laboratorijska referenca; ako se UART pinovi mijenjaju,
provjerite stvarni LPF.

GPIO i ESP32
------------

J1/J2 izlažu 56 FPGA signala kao ``GP``/``GN`` parove. Neki su single-ended,
neki differential-capable, a neki se dijele s ESP32 ili ADC-om ovisno o PCB
reviziji. Upstream dokumentacija upozorava i da se fizičko tumačenje pinova
razlikuje za angled-female i vertical-male headere.

ESP32 može sudjelovati u programiranju i board-side servisima. Dijeljeni SD,
GPIO i JTAG-related signali moraju se tretirati kao električno vlasništvo nad
sabirnicom.
