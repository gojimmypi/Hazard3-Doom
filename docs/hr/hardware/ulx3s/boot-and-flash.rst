FPGA konfiguracija, flash i boot putovi
=======================================

ULX3S ima više načina programiranja. Važno je razlikovati ECP5 konfiguracijski
SRAM, SPI flash i Hazard3 runtime memoriju.

Volatilna konfiguracija
-----------------------

``US1`` FT231X/JTAG put može učitati ECP5 konfiguracijski SRAM pomoću
``fujprog``, ``openFPGALoader``, OpenOCD/SVF ili Hazard3-Doom WebUSB flashera.
Takvo učitavanje je **volatilno** i nestaje nakon prekida napajanja.

Trajni SPI flash
----------------

Ugrađeni SPI flash čuva FPGA slike koje se mogu učitati pri uključivanju.
Potpuni Hazard3-Doom bitstream može u EBR-u sadržavati i preloaded rezidentni
monitor; on se pojavi nakon FPGA konfiguracije neovisno o tome je li bitstream
učitan privremeno ili iz flasha.

Različite uloge ``US1`` i ``US2``
---------------------------------

``US1`` je glavni priključak za napajanje, FT231X i uobičajeni JTAG put.
``US2`` je spojen na FPGA pinove i koristi se i za opcionalni DFU bootloader
kada je on instaliran.

Uobičajeni Hazard3-Doom WebUSB flasher koristi ``US1``. DFU bootloader je
zaseban mehanizam i ne treba ga zamjenjivati samo radi nove Doom FPGA slike.

Vidi :doc:`../../user-guide/bootloader` i
:doc:`../../getting-started/programming`.

Runtime učitavanje firmwarea
----------------------------

OpenOCD/GDB može učitati softver u već konfigurirani FPGA bez pisanja
konfiguracijskog flasha. I ta promjena je volatilna.

.. code-block:: text

   FPGA SRAM load    -> volatilna hardverska konfiguracija
   SPI flash write   -> trajna FPGA konfiguracija
   OpenOCD ELF load  -> volatilno stanje softvera/monitora
   micro-SD datoteke -> trajni izmjenjivi podaci
