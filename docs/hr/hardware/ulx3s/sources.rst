Izvorni dizajn i dodatna literatura
===================================

Hazard3-Doom dodaje projektno tumačenje ULX3S-a, ali ne zamjenjuje izvornu
hardversku dokumentaciju pločice.

Glavni ULX3S izvori
-------------------

* `ULX3S hardverski repozitorij <https://github.com/emard/ulx3s>`_ - KiCad
  izvori, sheme, PCB, BOM, constraints i povijest revizija.
* `ULX3S priručnik <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_ -
  konektori, napajanje, programiranje, ESP32 i revizijske razlike.
* `ULX3S na Crowd Supplyju <https://www.crowdsupply.com/radiona/ulx3s>`_ - pregled
  projekta i komercijalni kontekst.
* `ULX3S Quick Start <https://github.com/ulx3s/quick-start>`_.
* `ULX3S Pinout <https://github.com/ulx3s/ulx3s-pinout>`_.

PDF sheme
---------

Upstream repozitorij uključuje, među ostalima, revizije
`3.0.8 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v308.pdf>`_,
`3.1.4 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v314.pdf>`_,
`3.1.5 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v315.pdf>`_,
`3.1.6 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v316.pdf>`_ i
`3.1.7 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v317.pdf>`_.

Ako se kopije spremaju pod ``docs/hardware/ulx3s/``, u nazivu zadržite reviziju
i uz lokalni download ostavite upstream poveznicu.

Hazard3-Doom izvori
-------------------

ULX3S projektni kod nalazi se prvenstveno pod
``third_party/Hazard3/example_soc/fpga/``, ``synth/`` i ``soc/``, te u
``scripts/``, ``bootloader/``, ``openocd/`` i ``web/``.

Ako se izvori ne slažu, prednost dajte fizičkoj pločici, zatim odgovarajućoj
shemi/PCB/BOM reviziji, LPF-u i wrapperu točnog builda, datasheetu ugrađene
komponente i tek zatim općim opisima.

Vidi i :doc:`../../reference/board-profiles`,
:doc:`../../architecture/hazard3/memory-and-bus`, :doc:`../../architecture/video`,
:doc:`../../getting-started/programming`, :doc:`../../user-guide/bootloader`,
:doc:`../../user-guide/sd-card`, :doc:`../../user-guide/web-flasher` i
:doc:`../../user-guide/jtag-debugging`.
