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
     - LiteDRAM cilj; potrebna timing iznimka
   * - ULX4M-LS 85F
     - ``32m``
     - Dokumentirani profil od 50 MHz
     - Referenca memorijskog profila

Monitor, povezana Doom slika i SDRAM memorijska mapa moraju se slagati oko
memorijskog profila. Potpuni omotači za build pločica automatski postavljaju
profil i takt specifičan za cilj.

Trenutačna FPGA provjera
------------------------

Trenutačno izdanje lokalno je ponovno izgrađeno iz prikvačenog Hazard3 stabla
uz Yosys 0.60+70 i zadane seedove pločica. Ovi routed rezultati služe kao
regresijske kontrolne točke, a ne kao prijenosna jamstva timinga:

.. list-table::
   :header-rows: 1
   :widths: 24 12 40 24

   * - Pločica
     - Seed
     - Routed rezultat
     - Stanje
   * - ULX3S 85F
     - 55
     - ``clk_sys`` 51.77 MHz
     - PASS pri 50 MHz
   * - ULX3S 12F
     - 65
     - ``clk_sys`` 42.11 MHz
     - PASS pri 40 MHz
   * - ULX4M-LD 85F
     - 232
     - ``clk_sys`` 43.78 MHz; LiteDRAM 64.65 MHz
     - FAIL pri 50 MHz / 75.01 MHz

ULX4M-LD build zato koristi ``ALLOW_TIMING_FAILURE=1`` kada je potreban razvojni
bitstream. Ta iznimka pretvara timing greške u prijavljena upozorenja; ne tvrdi
da je timing zatvoren. Ponovno pokrenite routed timing nakon značajnih promjena
RTL-a, netlista, seeda ili toolchaina. Rezultat ULX3S 85F specifičan je za timing
model koji odabire trenutačni projektni tijek i ne treba ga izravno uspoređivati
s pokretanjima koja odabiru drugi ECP5 timing model.

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
