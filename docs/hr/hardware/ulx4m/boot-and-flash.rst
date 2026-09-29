Konfiguracija, SPI flash, USB DFU i JTAG
========================================

ULX4M ima više putova za programiranje i boot. Oni imaju različite uloge.

Tri odvojena sloja
------------------

``DFU bootloader pločice``
   Trajna FPGA konfiguracija/firmware pri početku SPI flasha. Omogućuje USB DFU
   i normalno predaje kontrolu user bitstreamu.

``Hazard3-Doom user bitstream``
   ECP5 konfiguracija s Hazard3 SoC-om, memorijom, videom i resident monitorom.

``Hazard3 resident monitor / Doom slika``
   RISC-V softver koji se izvršava nakon FPGA konfiguracije. Njegov rebuild ne
   znači da DFU bootloader treba zamijeniti.

Pogledajte :doc:`../../user-guide/bootloader` i
:doc:`../../getting-started/programming`.

Organizacija flasha
-------------------

Upstream dokumentacija opisuje prva 2 MiB (``0x000000`` do ``0x1fffff``) kao
bootloader/protected područje, a normalni user bitstream počinje na
``0x200000``. Većina FPGA eksperimenata zato treba koristiti FPGA SRAM ili
normalno user područje, a ne bootloader prostor.

USB DFU
-------

Upstream bootloader enumerira kao VID:PID ``1d50:614b``; projekt koristi DFU
altsetting 0 za user bitstream. Repo također sadrži
``scripts/ulx4m-bootloader.sh`` za rijetke slučajeve izgradnje, provjere i
oporavka samog bootloadera.

.. warning::

   Ne zamjenjujte ispravan DFU bootloader samo zato što se promijenio
   Hazard3-Doom bitstream, memorijski profil ili resident monitor.

JTAG
----

ULX4M nudi vanjski JTAG i JTAG-over-GPIO mogućnosti. Hazard3-Doom koristi JTAG
za pristup ECP5 uređaju i za Hazard3 RISC-V Debug Module preko ECP5 JTAG
infrastrukture. Trenutačna ULX4M-LD 85F meta koristi IDCODE ``0x01113043``.

Za novu rutu ili rizičnu izmjenu poželjno je privremeno učitati bitstream u FPGA
SRAM kada programator to omogućuje; power cycle tada vraća trajni boot put.

Testiranje u SRAM-u ili flashu
------------------------------

Pri provjeri novog routinga, memorijskog profila ili rizične FPGA promjene,
poželjno je učitati bitstream u FPGA SRAM kada to dostupni programator podržava.
Nakon ciklusa napajanja vraća se trajni konfiguracijski put. Korisničku sliku
zapišite u flash tek nakon što bitstream prođe predviđene testove pokretanja.
