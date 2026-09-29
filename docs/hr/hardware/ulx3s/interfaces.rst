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

UART je najjednostavniji softverski put prema monitoru. Provjereno vanjsko
Hazard3-Doom UART ožičenje koristi ULX3S J1 zaglavlje ovako:

.. list-table::
   :header-rows: 1
   :widths: 24 30 46

   * - Funkcija na FPGA-u
     - Položaj na ULX3S zaglavlju
     - Veza vanjskog adaptera
   * - ``RxD``
     - J1 pin 8 / ``GP1``
     - Na TX adaptera
   * - ``TxD``
     - J1 pin 6 / ``GP0``
     - Na RX adaptera
   * - ``GND``
     - Susjedna masa
     - Na masu adaptera

Ovo je projektno provjereno laboratorijsko ožičenje, a ne zamjena za provjeru
aktivnog LPF-a i top-level dizajna. Uvijek provjerite izgradnju ako se UART pinovi
promijene. Pogledajte :doc:`pinout-and-revisions` za potpuni ULX3S raspored
pinova i napomene o revizijama.

J1/J2 GPIO
----------

Dva 40-pinska zaglavlja izlažu 56 FPGA GPIO signala označenih kao ``GP``/``GN``
parovi u izvornoj dokumentaciji. Neki su obični jednostrani signali, neki su
pravi FPGA parovi sposobni za diferencijalni rad, a neki se dijele s ESP32 ili
ADC funkcijama ovisno o reviziji PCB-a.

Izvorni priručnik navodi i važan mehanički detalj: tumačenje neparnih/parnih
fizičkih pinova razlikuje se između kutnih ženskih i okomitih muških zaglavlja.
Koristite shemu i komentare u ograničenjima umjesto zaključivanja brojeva pinova
iz fotografije.

Dijeljenje s ESP32
------------------

ULX3S može uključivati ESP32 koji pruža Wi-Fi/Bluetooth i može sudjelovati u
programiranju FPGA-a ili servisima na pločici. Više resursa povezanih s FPGA-om
dijeli se, uključujući micro-SD i odabrane GPIO/JTAG signale na dokumentiranim
revizijama PCB-a.

Hazard3-Doom zato zajednička sučelja tretira kao pitanje vlasništva. Strana koja
ne posjeduje sabirnicu mora je električki otpustiti. To je osobito važno za SD i
za eksperimente koji istodobno koriste ESP32 i FPGA JTAG putove.

Ostala sučelja pločice
----------------------

Tipke, LED-ice, ADC, RTC, audio, OLED/LCD i GPIO s mogućnošću takta dostupni su
za eksperimente. Vrijedni su obrazovni resursi čak i kada ih trenutačni
Hazard3-Doom SoC ne koristi sve.
