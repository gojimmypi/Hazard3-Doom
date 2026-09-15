Pinovi pločica i ožičenje
===========================

Ova stranica okuplja dijagrame pinova i veze koje su najkorisnije za UART
adaptere, SAO dodatke, debug hardver i druge vanjske uređaje. Hardverski vodič
i dalje je mjerodavan za PCB revizije, sheme, LPF ograničenja i FPGA package
pinove.

ULX3S
-----

.. figure:: ../images/ulx3s-pinout.png
   :alt: ULX3S pinout

   **ULX3S pinout** - FPGA GPIO i raspored konektora.

Hazard3-Doom monitor UART koristi ove J1 veze:

.. code-block:: text

   adapter TX  -> J1 pin 8 / GP1 -> Hazard3 RxD
   adapter RX  <- J1 pin 6 / GP0 <- Hazard3 TxD
   adapter GND -> susjedni J1 GND

TX i RX su nazvani iz perspektive pojedinog uređaja pa ih treba križati kao što
je prikazano. Za shemu, LPF, orijentaciju konektora i revizije pločice pogledajte
:doc:`../hardware/ulx3s/pinout-and-revisions`.

Tigard JTAG prema Hazard3 na ULX3S
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

ULX3S J4 je izravna vanjska JTAG veza prema ECP5. Hazard3 koristi ECP5 hardverski
JTAG TAP i primitiv ``JTAGG`` za RISC-V debug modul. S Tigardom u ``SPI/JTAG``
načinu koristite:

.. list-table:: Tigard prema ULX3S J4
   :header-rows: 1
   :widths: 20 20 20 40

   * - Tigard pin
     - Signal
     - Boja
     - ULX3S J4
   * - 2
     - GND
     - Crna
     - GND
   * - 3
     - TCK
     - Bijela
     - TCK
   * - 4
     - TDI
     - Siva
     - TDI
   * - 5
     - TDO
     - Ljubičasta
     - TDO
   * - 6
     - TMS
     - Plava
     - TMS

ULX3S napajajte normalno preko US1 i postavite Tigard na 3,3 V logiku. Nemojte
spajati ``VTGT`` kako Tigard ne bi napajao pločicu. ``TRST`` i ``SRST`` nisu
potrebni za Hazard3. Za OpenOCD i GDB single-step primjere pogledajte
:doc:`jtag-debugging`.

Tigard JTAG prema ugrađenom ESP32
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ovo je zasebna debug meta. Klasični ESP32 na ULX3S je Xtensa procesor, a njegovi
JTAG GPIO pinovi 12 do 15 dijele se s micro-SD priključkom. Sljedeće ožičenje je
izvedeno iz ULX3S sheme/LPF-a i Espressif ESP32 JTAG rasporeda; još nije
projektno kvalificirano na ULX3S pločici.

.. list-table:: Tigard prema ULX3S ESP32
   :header-rows: 1
   :widths: 18 18 18 20 26

   * - Tigard
     - JTAG signal
     - ESP32 pin
     - ULX3S SD signal
     - micro-SD kontakt
   * - Pin 4 / siva
     - TDI
     - GPIO12 / MTDI
     - DAT2
     - Pin 1
   * - Pin 3 / bijela
     - TCK
     - GPIO13 / MTCK
     - DAT3
     - Pin 2
   * - Pin 6 / plava
     - TMS
     - GPIO14 / MTMS
     - CLK
     - Pin 5
   * - Pin 5 / ljubičasta
     - TDO
     - GPIO15 / MTDO
     - CMD
     - Pin 3
   * - Pin 2 / crna
     - GND
     - GND
     - VSS
     - Pin 6 ili drugi GND

.. warning::

   Isti SD signali spojeni su i na ECP5. Nemojte koristiti Tigard za ESP32 dok
   FPGA slika može aktivno upravljati SD sabirnicom. Izvadite SD karticu i
   koristite provjerenu FPGA sliku koja ostavlja ``SD_D2``, ``SD_D3``,
   ``SD_CLK`` i ``SD_CMD`` u high-impedance stanju.

ULX4M-LD na Waveshare CM4 carrieru
----------------------------------

.. figure:: ../images/ulx4m_ld-pinout.png
   :alt: ULX4M-LD pinout

   **ULX4M-LD pinout** - FPGA pinovi na
   `Waveshare CM4 carrieru <https://www.waveshare.com/wiki/CM4-IO-BASE-A#Dimension>`_.

Za projektno provjerenu Tigard UART vezu:

.. code-block:: text

   Tigard UART TX  -> fizički pin 16 -> GPIO23 -> FPGA N4 -> uart_rx
   Tigard UART RX  <- fizički pin 18 -> GPIO24 <- FPGA N3 <- uart_tx
   Tigard GND      -> fizički pin 20
   Tigard VCC      -> nije spojeno

Nemojte napajati ULX4M preko Tigarda. Pogledajte
:doc:`../hardware/ulx4m/pinout-and-revisions` i :doc:`jtag-debugging`.

Generiranje prilagođenih pinout dijagrama
-----------------------------------------

Dijagrami se mogu ponovno generirati pomoću
`ULX Pinout Generatora <https://github.com/ulx3s/ulx3s-pinout>`_. Alat izvodi
mapiranje iz LPF ograničenja te prikazuje ULX3S ili ULX4M-LD dijagrame kao SVG,
PNG, PDF ili PS. Koristan je za drugu reviziju pločice, izmijenjeni LPF ili
prilagođeni projektni prikaz.

Primjer za Ubuntu ili WSL:

.. code-block:: bash

   git clone https://github.com/ulx3s/ulx3s-pinout.git
   cd ulx3s-pinout
   python3 -m pip install --user --upgrade pinout cairosvg pillow
   ./generate-data-from-lpf.py ulx3s --include aliases \
       --markdown output/ulx3s/PIN-MAPPING.md
   ./generate-pinout.py ulx3s --format png

Prije spajanja vanjskog hardvera
--------------------------------

* Potvrdite točnu pločicu i PCB reviziju.
* Potvrdite aktivni FPGA bitstream i LPF ograničenja.
* Provjerite I/O napon i smjer signala.
* Spojite mase prije oslanjanja na UART ili druge single-ended signale.
* Nemojte pretpostaviti da ista pozicija konektora ima istu funkciju na svim
  revizijama pločice ili carriera.

Vanjske reference
-----------------

* `ULX3S hardverski priručnik <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_
* `ULX Pinout Generator <https://github.com/ulx3s/ulx3s-pinout>`_
* `Tigard <https://github.com/tigard-tools/tigard>`_
* `ESP32 JTAG pinovi <https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/jtag-debugging/configure-other-jtag.html>`_
* `ULX4M hardverski izvori <https://github.com/intergalaktik/ulx4m>`_
