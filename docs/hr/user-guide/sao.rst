Podrška za SAO / I2C
====================

Hazard3-Doom izlaže Hackaday-style SAO priključak preko I2C/GPIO mosta kojim upravlja APB. Ista fizička SAO sabirnica također se može dijeliti s ugrađenim ESP32 putem pomoćnog protokola vlasništva.

Signali priključka
------------------

Dokumentirani ULX3S SAO signali su:

.. list-table::
   :header-rows: 1

   * - Signal
     - ULX3S pin
   * - SDA
     - A9
   * - SCL
     - B10
   * - GPIO1
     - B9
   * - GPIO2
     - C10

Hazard3 APB baza
----------------

SAO most mapiran je na:

.. code-block:: text

   0x40009000

Naredbe monitora
----------------

Rezidentni monitor pruža naredbe uključujući:

.. code-block:: text

   sao info
   sao gui
   sao recover
   sao scan
   sao probe
   sao read
   sao write
   i2c scan
   i2c gui

HDMI I2CDriver sučelje
----------------------

Rezidentni monitor također pruža interaktivni HDMI alat u stilu I2CDrivera:

.. code-block:: text

   i2c gui

GUI omogućuje skeniranje, ispitivanje, čitanje/pisanje registara, oporavak
sabirnice, odabir 100/400 kHz, toplinsku kartu adresa, povijest transakcija i
logički SDA/SCL trag. Pogledajte :doc:`i2cdriver` za kontrole, sigurnosne napomene
i važnu razliku između iniciranog logičkog traga i pravog pasivnog snimanja
sabirnice.

Dijeljenje s ESP32
------------------

FPGA i ESP32 koriste pomoćnu vezu ULX3S Wi-Fi GPIO16/GPIO17 za koordiniranje logičkog vlasništva nad SAO sabirnicom. Primjer ESP32 firmwarea nalazi se u:

.. code-block:: text

   examples/esp32-sao-shared/

Vlasnik koji nema kontrolu nad sabirnicom mora otpustiti svoje izlaze, a ne samo odlučiti da neće slati podatke.

Električna napomena
-------------------

I2C pull-up otpornici uspostavljaju visoku razinu u mirovanju, ali ne zamjenjuju serijsku zaštitu koju može zahtijevati određeni SAO dizajn. Prije spajanja hardvera koji aktivno pogoni opcionalne GPIO vodove provjerite električne zahtjeve dodatka.
