Hazard3-Doom
============

**Doom koji radi na Hazard3 RISC-V CPU-u u ECP5 FPGA-u, s HDMI videom, UART/JTAG otklanjanjem pogrešaka i podrškom za ULX3S/ULX4M pločice.**

Hazard3-Doom objedinjuje rezidentni monitor, učitljivu DoomGeneric aplikaciju,
FPGA konfiguracije za pločice, alate za prijenos s računala te integraciju
hardvera i softvera za porodice ULX3S i ULX4M.

.. note::

   Ove stranice prate aktivnu granu ``develop``. Značajke koje se još razvijaju
   izričito su označene. Detaljne stranice o arhitekturi procesora dodatno su
   vezane uz točan snimak izvornog koda Hazard3 naveden u
   :doc:`architecture/hazard3/index`.

Počnite ovdje
-------------

* :doc:`getting-started/quick-start` - pokrenite pločicu uz najmanji broj koraka.
* :doc:`getting-started/build` - izgradite FPGA, rezidentni monitor i Doom sliku.
* :doc:`user-guide/web-flasher` - programirajte FPGA SRAM na ULX3S izravno iz Chromea/Edgea putem WebUSB-a.
* :doc:`user-guide/sd-card` - podesite samostalno hladno pokretanje s micro-SD kartice.
* :doc:`user-guide/i2cdriver` - skenirajte i pregledajte SAO I2C sabirnicu preko HDMI-ja.
* :doc:`user-guide/jtag-debugging` - otklanjajte pogreške u Hazard3 putem OpenOCD/GDB-a ili VisualGDB-a.
* :doc:`architecture/hazard3/index` - upoznajte Hazard3 RISC-V procesor, cjevovod, konfiguraciju ISA-e, CSR-ove, sabirnice i arhitekturu za otklanjanje pogrešaka.
* :doc:`architecture/system` - razumijte kako su povezani FPGA, monitor, SDRAM, HDMI, SD, SAO i ESP32.

.. toctree::
   :maxdepth: 2
   :caption: Početak rada

   getting-started/index

.. toctree::
   :maxdepth: 2
   :caption: Korisnički vodič

   user-guide/index

.. toctree::
   :maxdepth: 2
   :caption: Arhitektura

   architecture/index

.. toctree::
   :maxdepth: 2
   :caption: Referenca

   reference/index
   faq
   troubleshooting
   contributing

Poveznice projekta
------------------

* `Hazard3-Doom repozitorij <https://github.com/gojimmypi/Hazard3-Doom>`_
* `ULX3S Hazard3 hardverski fork <https://github.com/ulx3s/Hazard3>`_
* `Izvorni Hazard3 projekt <https://github.com/Wren6991/Hazard3>`_
* `Izvorni DoomGeneric projekt <https://github.com/ozkl/doomgeneric>`_
