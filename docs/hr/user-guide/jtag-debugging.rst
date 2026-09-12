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

Za ULX3S preporučeni pokretač je:

.. code-block:: bash

   ./scripts/start-openocd.sh

Pokretač je namjerno upotrebljiv i iz WSL-a i iz izvornog Linuxa. Na izvornom
Linuxu pronalazi ``openocd`` kroz ``PATH``. Pod WSL-om može koristiti priloženi
Windows ``openocd.exe`` za checkout na Windows datotečnom sustavu kada je WSL
interop dostupan; inače koristi izvorni Linux OpenOCD. Time se putanje
repozitorija i format izvršnog programa usklađuju s okruženjem domaćina.

Projektne ULX3S konfiguracije napisane su za Ubuntu OpenOCD ``0.12.0`` i novije
OpenOCD buildove koje projekt trenutačno koristi. Konkretno, kompatibilni oblik
``gdb_report_data_abort`` prihvaća 0.12.0; noviji buildovi mogu ispisati
upozorenje o zastarjelosti, ali ga i dalje prihvaćaju. Nemojte zamijeniti
OpenOCD paket distribucije samo radi uklanjanja tog upozorenja.

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

Ispravan ULX3S 85F OpenOCD start sadrži izlaz sličan ovome:

.. code-block:: text

   JTAG tap: lfe5u85.hazard3 tap/device found: 0x41113043
   Examined RISC-V core; found 1 harts
   hart 0: XLEN=32
   Listening on port 3333 for gdb connections

U VM-u početna USB transakcija ponekad može prijaviti
``LIBUSB_ERROR_TIMEOUT`` ili neuspjelo potpuno nulto JTAG ispitivanje. Procijenite
završno stanje, a ne samo prvo upozorenje: ako OpenOCD zatim prepozna RISC-V
jezgru i otvori port 3333, debug server je upotrebljiv. Čisto, neposredno
ponovno pokretanje korisna je potvrda. Ako TAP/jezgra nikada nije pronađena,
provjerite je li FT231X priključen gostu, je li preglednikov FPGA flasher
odspojen i koristi li neki drugi proces JTAG sučelje.

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
