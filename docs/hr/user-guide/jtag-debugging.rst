JTAG otklanjanje pogrešaka
==========================

Hazard3 uključuje izvorni RISC-V Debug Module i Debug Transport Module.
Na ULX3S-u Hazard3 ECP5 prilagodnik povezuje RISC-V DTM registre s JTAG TAP-om
ECP5 čipa preko primitive ``JTAGG``. To omogućuje otklanjanje pogrešaka na
razini izvornog koda putem uobičajene USB/JTAG veze pločice.

Za objašnjenje hardverskog puta, apstraktnih naredbi, ubrizgavanja instrukcija,
pristupa sistemskoj sabirnici i značajki za otklanjanje pogrešaka odabranih u
ovom bitstreamu pogledajte :doc:`../architecture/hazard3/debug`.

OpenOCD
-------

Projekt čuva svoju OpenOCD konfiguraciju u ``openocd/``, a pomoćne skripte u
``scripts/``. Na Windowsu je trenutačni ULX3S ``ft232r`` OpenOCD put potvrđen s
**WinUSB** i **libusbK** upravljačkim programima na ugrađenom FT231X-u. WinUSB
je preporučeni razvojni binding kada isto računalo koristi i Hazard3-Doom
WebUSB FPGA flasher. Zadani FTDI VCP/D2XX binding namijenjen je izvornim FTDI
alatima kao što je Windows ``fujprog`` i nije OpenOCD libusb put.

GDB se povezuje s OpenOCD-om putem TCP-a, uobičajeno na ``localhost:3333``.
Zato nasljeđuje USB kompatibilnost OpenOCD procesa; GDB sam ne otvara FT231X.
Pogledajte :doc:`web-flasher` za matricu kompatibilnosti upravljačkih programa.

Tipičan tijek rada je:

#. Povežite ULX3S preko njegova uobičajenog USB/JTAG sučelja.
#. Pokrenite OpenOCD s projektnom konfiguracijom.
#. Povežite RISC-V GDB klijent na ``localhost:3333``.
#. Učitajte ili se spojite na ``build/hazard3-boot-monitor.elf``.

Skupno učitavanje monitora
--------------------------

Kada OpenOCD već radi i nijedan drugi GDB klijent nije povezan:

.. code-block:: bash

   ./scripts/load-firmware.sh

Ili navedite određeni ELF:

.. code-block:: bash

   ./scripts/load-firmware.sh /path/to/hazard3-boot-monitor.elf

VisualGDB
---------

Korisnici Windowsa mogu koristiti projektne datoteke u ``VisualGDB/`` s Visual
Studiom. Debugger i dalje komunicira s istim OpenOCD/GDB ciljem, pa tijek rada iz
naredbenog retka ostaje referentni postupak.

GDB pomoćna skripta za pokretanje je:

.. code-block:: text

   scripts/hazard3-debug.gdb

Otklanjanje poteškoća
---------------------

Ako se modul za otklanjanje pogrešaka ne otkriva pouzdano, smanjite JTAG takt
prije promjene HDL-a. Kvaliteta USB/JTAG signala i vremenska svojstva prilagodnika
mogu uzrokovati kvarove koji izgledaju kao pogreške CPU debugiranja.

Pogledajte :doc:`../troubleshooting` za uobičajene probleme s OpenOCD-om i
vlasništvom nad uređajem.
