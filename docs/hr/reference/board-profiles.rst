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
     - Micron ``MT41K512M16HA`` ili Alliance ``AS4C256M16D3`` DDR3/DDR3L profil; ``ahb_litedram`` + generirani LiteDRAM/``ECP5DDRPHY``
     - 40 MHz CPU/AHB; 60 MHz LiteDRAM korisnički port; 25 MHz referenca/init
     - Micron hardverski kvalificiran; generirani profili specifični za komponentu
   * - ULX4M-LS 85F
     - ``32m``
     - 32 MiB 16-bitni SDR SDRAM; izvorni ``ahb_sdram`` put kontrolera
     - 50 MHz
     - Izvorni SDR memorijski put

Monitor, povezana Doom slika i SDRAM memorijska mapa moraju se slagati oko
memorijskog profila. Potpuni omotači za build pločica automatski postavljaju
profil i takt specifičan za cilj.

Zadane nextpnr postavke routanja
--------------------------------

Omotači za pločice uzimaju zadane postavke routanja iz jedne zajedničke
implementacije, ``scripts/build-ecp5-bitstream-common.sh``. Trenutačne se
vrijednosti uključuju izravno iz te datoteke kako dokumentacija ne bi održavala
drugu kopiju:

.. literalinclude:: ../../scripts/build-ecp5-bitstream-common.sh
   :language: bash
   :start-at: ULX3S_85F_DEFAULT_NEXTPNR_SEED=
   :end-at: ULX4M_LD_85F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT=

``NEXTPNR_SEED`` i dalje može nadjačati zadani seed odabrane pločice za izričiti
route. Ove su vrijednosti release baseline, a ne trajni optimum.

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
     - 11
     - ``clk_sys`` 52.24 MHz
     - PASS pri 50 MHz
   * - ULX3S 12F
     - 82
     - ``clk_sys`` 42.70 MHz
     - PASS pri 40 MHz
   * - ULX4M-LD 85F
     - 83
     - ``clk_sys`` 43.63 MHz; LiteDRAM korisnički port 67.51 MHz
     - PASS pri 40 MHz / 60 MHz; odabrani release route

Ovi release-route zapisi namjerno zadržavaju seed jer je on dio podataka o
podrijetlu timing rezultata. Same zadane vrijednosti održava zajednička build
skripta iznad.

Hardverski kvalificirana ULX4M-LD kontrolna točka koristi zamrznuti netlist,
seed 2 i HeAP
``timingweight=30``. Hardverski testirani bitstream ima SHA256
``294602982dfc4a9906961f2e8b6f43de925d8c11a7e5e6bb0f5e392965a868de``.
Pločica s Micron memorijom prošla je potpunu DDR kvalifikaciju, heap stress,
Doom test i RV32 izvođenje iz DDR-a. Novi netlist mora se ponovno routati i
hardverski kvalificirati; sam timing PASS nije dovoljan. Pogledajte
:doc:`timing-sweeps` za provenance sweepa i pravila usporedbe.

Hardverski kvalificirana ULX4M-LD kontrolna točka znatno je jača od starog
razvojnog stanja ``ALLOW_TIMING_FAILURE``. Točna zamrznuta netlista bila je:

.. code-block:: text

   160c536b12e46667990c887571da6f443ccc6c5a2ba644033db43fc783ea9453

Timing-prolazan hardverski kvalificiran routing koristio je nextpnr seed 2 s HeAP
``timingweight=30``. Točno lokalno testirani bitstream imao je SHA256:

.. code-block:: text

   294602982dfc4a9906961f2e8b6f43de925d8c11a7e5e6bb0f5e392965a868de

Ista zamrznuta netlista nije prolazila s ranijom HeAP postavkom
``timingweight=10``, što pokazuje da su place-and-route postavke dio zapisa
kvalifikacije, a ne usputni detalj.

Hardverska provjera na Micron pločici zatim je prošla cijeli ``q`` SDRAM skup,
stres hrpe 40 MiB, Doom brzi test platforme i izvršavanje kopiranog RV32 koda iz
DDR-a. Sam timing PASS nije dovoljan za tvrdnju o DDR kvalifikaciji.

Nova predučitana slika rezidentnog monitora ili bilo koja druga promjena vidljiva
sintezi stvara novu netlistu. Sačuvajte kvalificirani seed-2 artefakt kao
referencu, zatim ponovno provedite routing i kvalifikaciju.

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
