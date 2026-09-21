Video i izmjenjiva pohrana
==========================

ULX4M izlaže priključke za video i pohranu, ali fizički konektor samo je prvi
sloj. Hazard3-Doom još mora pružiti FPGA logiku, ograničenja, satove i softver.

GPDI / HDMI-stil video
----------------------

Hazard3-Doom zadržava Doomov nativni indeksirani framebuffer. Standardni put
renderira 320x200 indeksiranih piksela i skalira ih na 1024x600. Pretvorba palete
i scanout izvode se u FPGA logici.

ULX4M wrapperi koriste poseban video PLL s 50 MHz pixel satom i 250 MHz
serializer satom. Pogledajte :doc:`../../architecture/video`.

Javni izvori opisuju različite true/fake differential GPDI izvedbe. Wrapper i
LPF koji pripadaju konkretnom buildu izvor su istine za ciljanu pločicu.

micro-SD
--------

ULX4M dokumentacija vodi SD signale kroz CM4/HAT okruženje. Neke carrier/HAT
konfiguracije mogu te signale dijeliti s vanjskim ESP32; sam ULX4M modul ne
sadrži onboard ESP32 i tako ga ne treba opisivati.

Trenutačni ULX4M-LD top-level izlaže:

.. code-block:: text

   sd_clk
   sd_mosi
   sd_miso
   sd_csn
   sd_pwr_on

``sd_pwr_on`` je aktivan dok bitstream radi, a SoC na LD-u uključuje SD SPI
blok. Status stvarne hardverske validacije vodi se odvojeno od same činjenice da
su signali rutirani. Vidi :doc:`../../user-guide/sd-card`.

Uloge pohrane
-------------

* SPI flash konfigurira FPGA;
* resident monitor nakon konfiguracije živi u EBR-u;
* SDRAM/DDR3 je volatilna radna memorija;
* micro-SD je izmjenjiva nevolatilna pohrana datoteka.

Standalone boot zato prelazi više granica:

.. code-block:: text

   SPI flash -> FPGA konfiguracija -> EBR monitor -> DRAM init
             -> micro-SD/FAT -> DOOM.IMG + DOOM.WAD -> Hazard3
