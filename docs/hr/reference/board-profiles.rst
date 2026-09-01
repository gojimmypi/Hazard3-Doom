Profili pločica
===============

.. list-table::
   :header-rows: 1
   :widths: 18 16 28 14 24

   * - Pločica
     - Memorijski profil
     - Vanjska memorija/kontroler
     - Sistemski takt
     - Napomena o videu/buildu
   * - ULX3S 85F
     - ``64m``
     - 16-bitni SDR SDRAM; izvorni ``ahb_sdram`` put kontrolera
     - 50 MHz
     - 320x200 zadano; dostupni su prošireni načini
   * - ULX3S 12F
     - ``32m`` zadano; ``64m`` opcionalno
     - 16-bitni SDR SDRAM; izvorni ``ahb_sdram`` put kontrolera
     - 40 MHz
     - Kompaktni 320x200 SDRAM scanout
   * - ULX4M-LD 85F
     - ``64m``
     - 1 GiB MT41K512M16HA-125 DDR3L; ``ahb_litedram`` + generirani LiteDRAM/``ECP5DDRPHY``
     - 40 MHz CPU/AHB zadano; 75 MHz LiteDRAM korisnički port
     - LiteDRAM cilj; potrebna timing iznimka
   * - ULX4M-LS 85F
     - ``32m``
     - 32 MiB 16-bitni SDR SDRAM; izvorni ``ahb_sdram`` put kontrolera
     - 50 MHz
     - Izvorni SDR memorijski put

Monitor, povezana Doom slika i SDRAM memorijska mapa moraju se slagati oko
memorijskog profila. Potpuni omotači za build pločica automatski postavljaju
profil i takt specifičan za cilj.

Trenutačna FPGA provjera
------------------------

Routed vrijednosti ispod regresijske su kontrolne točke iz projektnih buildova.
Točne revizije izvora, SHA256 netlista, verzije CAD alata i sweep parametre treba
uzeti iz odgovarajućeg build/sweep artifacta; ove vrijednosti nisu prijenosna
jamstva timinga:

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
     - ``clk_sys`` 38.69 MHz; LiteDRAM 62.52 MHz
     - FAIL pri 40 MHz / 75.01 MHz

ULX4M-LD build zato koristi ``ALLOW_TIMING_FAILURE=1`` kada je potreban razvojni
bitstream. Ta iznimka pretvara timing greške u prijavljena upozorenja; ne tvrdi
da je timing zatvoren. Ponovno pokrenite routed timing nakon značajnih promjena
RTL-a, netlista, seeda ili toolchaina. Rezultat ULX3S 85F specifičan je za timing
model koji odabire trenutačni projektni tijek i ne treba ga izravno uspoređivati
s pokretanjima koja odabiru drugi ECP5 timing model. Pogledajte
:doc:`timing-sweeps` za provenance sweepa i pravila usporedbe.

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
