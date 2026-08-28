Profili pločica
===============

.. list-table::
   :header-rows: 1
   :widths: 30 25 20 25

   * - Pločica
     - Memorijski profil
     - Sistemski takt
     - Napomena o videu/buildu
   * - ULX3S 85F
     - ``64m``
     - 50 MHz
     - 320x200 zadano; dostupni su prošireni načini
   * - ULX3S 12F
     - ``32m`` zadano; ``64m`` opcionalno
     - 40 MHz
     - Kompaktni 320x200 SDRAM scanout
   * - ULX4M-LD 85F
     - ``64m``
     - 50 MHz
     - LiteDRAM cilj
   * - ULX4M-LS 85F
     - ``32m``
     - Dokumentirani profil od 50 MHz
     - Referenca memorijskog profila

Monitor, povezana Doom slika i SDRAM memorijska mapa moraju se slagati oko
memorijskog profila. Potpuni omotači za build pločica automatski postavljaju
profil i takt specifičan za cilj.

Glavne baze ULX3S periferije
----------------------------

.. list-table::
   :header-rows: 1

   * - Periferija
     - Baza
   * - SAO bridge
     - ``0x40009000``
   * - SD SPI
     - ``0x4000A000``
   * - HDMI/video
     - ``0x4000C000``
