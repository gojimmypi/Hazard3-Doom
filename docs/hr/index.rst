Hazard3-Doom
============

**Doom na Hazard3 RISC-V CPU-u u ECP5 FPGA-u - i praktično igralište za učenje kako procesor, FPGA logika, memorija, video, firmware i softver rade zajedno.**

Hazard3-Doom je mnogo više od Dooma pokrenutog na još jednoj FPGA pločici. To
je obrazovni hardversko-softverski ekosustav izgrađen oko open-source Hazard3
RISC-V procesora te ULX3S i ULX4M ECP5 FPGA obitelji.

.. admonition:: Isti Hazard3 CPU koji se koristi u Raspberry Pi RP2350
   :class: important

   Hazard3 nije jednokratni procesor napravljen samo za ovaj projekt. Raspberry
   Pi RP2350 mikrokontroler sadrži par open-hardware Hazard3 RISC-V jezgri koje
   se mogu odabrati umjesto para Arm Cortex-M33 jezgri, a RP2350 pokreće
   Raspberry Pi Pico 2 obitelj. Hazard3-Doom sintetizira istu open-source
   Hazard3 procesorsku arhitekturu u ECP5 FPGA-u.

   Konfiguracija procesora nije identična: RP2350 i Hazard3-Doom uključuju
   različite opcionalne Hazard3 značajke i ISA ekstenzije za svoje SoC-ove.
   Zajedničko podrijetlo CPU-a i RTL čine Hazard3-Doom praktičnim načinom za
   proučavanje te arhitekture u sustavu koji možete ponovno izgraditi i mijenjati.

   * `Raspberry Pi RP2350 <https://www.raspberrypi.com/products/rp2350/>`_
   * `RP2350 datasheet - Hazard3 procesor <https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf>`_
   * `Raspberry Pi Pico 2 <https://www.raspberrypi.com/products/raspberry-pi-pico-2/>`_
   * `Upstream Hazard3 RTL <https://github.com/Wren6991/Hazard3>`_

Projekt spaja C i Verilog primjere, FPGA dizajne, HDMI video i framebuffer
podršku, kontrolere vanjske memorije, pristup SD kartici, UART i JTAG debug,
resident boot monitor, host-side alate za prijenos i učitljivu DoomGeneric
aplikaciju.

Uključen je i I2C dijagnostički alat temeljen na `I2CDriveru <https://i2cdriver.com/>`_
tvrtke Excamera Labs. Isti kod pruža i dodatnu
:doc:`Hackaday Supercon SAO značajku <user-guide/sao>`.

Hazard3-Doom možete koristiti jednostavno za igranje Dooma na RISC-V soft CPU-u
ili dublje istražiti kako se gradi kompletno FPGA računalo: integraciju CPU-a,
memorijska sučelja, satove i timing, video, periferije, boot i upload mehanizme
te alate za otklanjanje pogrešaka.

Bilo da eksperimentirate s RISC-V-om, učite Verilog ili želite razumjeti što je
potrebno da Doom radi na hardveru koji možete pregledati i mijenjati od vrha do
dna, Hazard3-Doom je napravljen za istraživanje.

.. note::

   Ove stranice opisuju odabranu verziju dokumentacije. Značajke koje se još
   razvijaju izričito su označene. Detaljne stranice o arhitekturi procesora
   vezane uz točan snimak izvornog koda Hazard3 naveden u
   :doc:`architecture/hazard3/index`.

.. important:: Windows buildovi iz izvornog koda koriste WSL

   Na Windowsu upute za build i razvoj iz izvornog koda zahtijevaju **WSL s
   Ubuntuom i Bashom**. PowerShell i ``cmd.exe`` nisu podržane build ljuske za
   skripte repozitorija. Izvorni Windows koristi se samo kada stranica izričito
   traži Device Tool u pregledniku, upravljanje USB upravljačkim programima,
   prijenos preko COM porta ili priloženi Windows ``.exe``. Put
   :doc:`getting-started/no-install` u pregledniku ne zahtijeva WSL.

Počnite ovdje
-------------

* :doc:`about/index` - saznajte što je projekt i što iz njega možete naučiti.
* :doc:`getting-started/no-install` - pokrenite ULX3S iz unaprijed izgrađenih slika u Device Toolu bez FPGA build alata.
* :doc:`getting-started/quick-start` - instalirajte razvojne alate i iz izvornog koda izgradite FPGA, rezidentni monitor i Doom sliku.
* :doc:`user-guide/web-tool` - koristite Device Tool u pregledniku za uobičajeno pokretanje pločice i interaktivne zadatke.

Istražite dalje
---------------

* :doc:`hardware/index` - istražite ULX3S i ULX4M hardver koji koristi Hazard3-Doom.
* :doc:`user-guide/pinouts` - pronađite pinout dijagrame i praktično UART/JTAG ožičenje.
* :doc:`user-guide/jtag-debugging` - otklanjajte pogreške u Hazard3 putem OpenOCD/GDB-a ili VisualGDB-a.
* :doc:`user-guide/i2cdriver` - skenirajte i interaktivno koristite SAO I2C sabirnicu.
* :doc:`user-guide/web-flasher` - programirajte ULX3S FPGA izravno putem WebUSB-a.
* :doc:`architecture/hazard3/index` - upoznajte Hazard3 RISC-V procesor, cjevovod, ISA konfiguraciju, sabirnice i arhitekturu za otklanjanje pogrešaka.
* :doc:`architecture/system` - razumijte kako su povezani FPGA, monitor, memorija, HDMI, SD, SAO i ESP32.
* :doc:`reference/apb-peripherals` - pregledajte APB adrese, registre, bitove i samostalne C primjere.
* :doc:`reference/timing-sweeps` - pokrenite ECP5 sweepove i protumačite timing rezultate.
* :doc:`user-guide/sd-card` - podesite samostalno hladno pokretanje s micro-SD kartice.
* :doc:`getting-started/tiny-tapeout-ulx3s` - gradite Tiny Tapeout projekte za ULX3S ECP5.

.. toctree::
   :maxdepth: 2
   :caption: Pregled projekta

   about/index

.. toctree::
   :maxdepth: 2
   :caption: Početak rada

   getting-started/index

.. toctree::
   :maxdepth: 2
   :caption: Hardver

   hardware/index

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

* `Hazard3-Doom repozitorij <https://github.com/ulx3s/Hazard3-Doom>`_
* `Izvorni Hazard3 projekt <https://github.com/Wren6991/Hazard3>`_
* `Hazard3 vodič za dizajn i referentni priručnik <https://wren.wtf/hazard3/doc/>`_
* `Izvor Hazard3 dokumentacije <https://github.com/Wren6991/Hazard3/tree/stable/doc>`_
* `Izvorni DoomGeneric projekt <https://github.com/ozkl/doomgeneric>`_
* `ULX4M hardverski izvori <https://github.com/intergalaktik/ulx4m>`_
* `ULX4M hardverska dokumentacija <https://github.com/intergalaktik/ulx4m-documentation>`_
* `ULX4M Crowd Supply stranica <https://www.crowdsupply.com/intergalaktik/ulx4m>`_

* `ULX3S Hazard3 hardverski fork, grana ulx-doom <https://github.com/ulx3s/Hazard3/tree/ulx-doom>`_
* `Hazard3-libfpga fork, grana ulx-doom <https://github.com/ulx3s/Hazard3-libfpga/tree/ulx-doom>`_
* `Izvorni Hazard3-libfpga <https://github.com/Wren6991/libfpga>`_
* `ULX3S alat za raspored pinova <https://github.com/ulx3s/ulx3s-pinout>`_
* `ULX3S ulx3s.github.io <https://github.com/ulx3s/ulx3s.github.io>`_
* `ULX3S Tiny Tapeout predložak <https://github.com/ulx3s/ttsky-verilog-template/tree/ulx3s>`_
* `ULX3S Tiny Tapeout GitHub akcija <https://github.com/ulx3s/tt-gds-action/tree/experimental>`_
* `ULX3S Tiny Tapeout pomoćni alati <https://github.com/ulx3s/tt-support-tools/tree/experimental>`_
* `Verilog Language Extension za Visual Studio <https://github.com/gojimmypi/VerilogLanguageExtension>`_
* `I2CDriver <https://i2cdriver.com/>`_
