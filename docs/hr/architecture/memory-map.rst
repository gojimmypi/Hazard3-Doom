Memorijska mapa
===============

Adrese na ovoj stranici pripadaju **SoC integraciji** Hazard3-Dooma, a ne
RISC-V ISA-i ili fiksnoj memorijskoj mapi procesora Hazard3. Hazard3 izdaje
obične instrukcijske/podatkovne transakcije; okolni SoC dekodira ove fizičke
adresne prozore. Pogledajte :doc:`hazard3/memory-and-bus` za granicu CPU/sabirnica.

Interni SRAM
------------

ECP5 EBR SRAM od 128 KiB podijeljen je ovako:

.. list-table::
   :header-rows: 1

   * - Raspon
     - Namjena
   * - ``0x00000000-0x0000FFFF``
     - Rezidentni monitor, trapovi i monitor/Doom stog.
   * - ``0x00010000-0x0001F9FF``
     - Doom indeksirani radni zaslon 320x200.
   * - ``0x0001FA00-0x0001FFFF``
     - Neiskorišteni interni SRAM.

SDRAM profil od 64 MiB
----------------------

Koriste ga ULX3S 85F i ULX4M-LD 85F:

.. list-table::
   :header-rows: 1

   * - Raspon
     - Namjena
   * - ``0x20000000-0x23FFFFFF``
     - Fizička vanjska memorija od 64 MiB.
   * - ``0x24000000-0x27FFFFFF``
     - Nekeshirani dijagnostički alias.
   * - ``0x20100000-0x203FFFFF``
     - Keshirana povezana Doom slika.
   * - ``0x20400000-0x22BFFFFF``
     - Keshirani Doom heap i zone memorija.
   * - ``0x22C00000-0x23BFFFFF``
     - Keshirana IWAD rezervacija, 16 MiB.
   * - ``0x23C00000-0x23FFFFFF``
     - Nekeshirana video rezervacija.

SDRAM profil od 32 MiB
----------------------

Koristi ga ULX4M-LS 85F:

.. list-table::
   :header-rows: 1

   * - Raspon
     - Namjena
   * - ``0x20000000-0x21FFFFFF``
     - Fizički SDRAM od 32 MiB.
   * - ``0x24000000-0x25FFFFFF``
     - Nekeshirani dijagnostički alias.
   * - ``0x20100000-0x203FFFFF``
     - Keshirana povezana Doom slika.
   * - ``0x20400000-0x20FFFFFF``
     - Keshirani Doom heap, 12 MiB.
   * - ``0x21000000-0x21BFFFFF``
     - Keshirana IWAD rezervacija, 12 MiB.
   * - ``0x21C00000-0x21FFFFFF``
     - Nekeshirana video rezervacija.
