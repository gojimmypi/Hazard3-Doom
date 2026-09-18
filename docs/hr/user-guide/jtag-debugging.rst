JTAG debugiranje
================

Hazard3 sadrži RISC-V Debug Module i Debug Transport Module. Na ECP5 pločicama
Hazard3 izlaže RISC-V DTM kroz JTAG TAP ECP5 čipa i primitiv ``JTAGG``. OpenOCD
stoga najprije vidi fizički ECP5 TAP, a zatim koristi privatne ECP5 ER1/ER2
instrukcije kako bi pristupio Hazard3 DTMCS i DMI registrima.

Za objašnjenje hardverskog puta, apstraktnih naredbi, ubrizgavanja instrukcija,
pristupa sistemskoj sabirnici i debug mogućnosti odabranih u ovom bitstreamu
pogledajte :doc:`../architecture/hazard3/debug`.

OpenOCD i GDB
-------------

GDB se s OpenOCD-om povezuje preko TCP-a, uobičajeno na ``localhost:3333``. GDB
ne otvara izravno USB JTAG adapter. USB driver i konfiguracija adaptera stoga
pripadaju OpenOCD-u, dok ``scripts/load-firmware.sh`` koristi GDB tek nakon što
OpenOCD uspješno ispita metu.

Za ULX3S preporučeni launcher je:

.. code-block:: bash

   ./scripts/start-openocd.sh

Launcher je namjerno upotrebljiv i iz WSL-a i iz izvornog Linuxa. Na izvornom
Linuxu pronalazi ``openocd`` preko ``PATH``. Pod WSL-om može koristiti priloženi
Windows ``openocd.exe`` za checkout na Windows mountu ako je WSL interop
dostupan; inače koristi izvorni Linux OpenOCD. Time putanje repozitorija i
format izvršne datoteke ostaju usklađeni s host okruženjem.

Projektne ULX3S konfiguracije napisane su za Ubuntu OpenOCD ``0.12.0`` i novije
OpenOCD buildove koje projekt trenutačno koristi. Konkretno, kompatibilni zapis
``gdb_report_data_abort`` prihvaća 0.12.0; noviji buildovi mogu ispisati
upozorenje o zastarjelosti, ali ga i dalje prihvaćaju. Nemojte mijenjati OpenOCD
iz distribucije samo radi uklanjanja tog upozorenja.

Ako OpenOCD već radi i nijedan drugi GDB klijent nije spojen:

.. code-block:: bash

   ./scripts/load-firmware.sh

Ili navedite ELF izričito:

.. code-block:: bash

   ./scripts/load-firmware.sh /path/to/hazard3-boot-monitor.elf

Oblik bez argumenta odnosi se na izlaz samostalnog ``scripts/build.sh`` builda.
Za potpuni board build radije koristite GDB datoteku naredbi za točno određenu
metu kako se monitor ne bi zamijenio s ELF-om izgrađenim za drugi takt ili
memorijski profil:

.. code-block:: bash

   # ULX3S 85F
   riscv-none-elf-gdb -batch -x scripts/gdb/load-ulx3s-85f-monitor.gdb

   # ULX3S 12F
   riscv-none-elf-gdb -batch -x scripts/gdb/load-ulx3s-12f-monitor.gdb

   # ULX4M-LD 85F
   riscv-none-elf-gdb -batch -x scripts/gdb/load-ulx4m-ld-85f-monitor.gdb

Svaka datoteka odabire monitor iz odgovarajućeg ``build/<board>/monitor/``
direktorija, zaustavlja metu, učitava i provjerava ELF s ``compare-sections``,
postavlja ``$pc`` na ``_start``, nastavlja procesor i odspaja se. Nemojte koristiti
generički ili zastarjeli monitor ELF iz drugog board builda; može se izvršavati,
a ipak koristiti pogrešan UART djelitelj, memorijsku mapu ili protokol loadera.

Kada iz WSL-a pokrećete priloženu Windows ``.exe`` datoteku, okolna ljuska i
dalje je Bash. Koristite put poput ``./bin/gdb/riscv-none-elf-gdb.exe`` i završnu
obrnutu kosu crtu (``\``) za nastavak Bash naredbe. ``cmd.exe`` sintaksa poput
``.\bin\...`` i nastavak retka znakom ``^`` vrijede samo nakon izričitog ulaska
u ``cmd.exe``; zalijepljeni izravno u WSL tumače se kao odvojene ili izmijenjene
Bash naredbe.

Ugrađeni ULX3S FT231X
---------------------

Na ULX3S-u projekt koristi uobičajenu FT231X USB/JTAG vezu pločice. Trenutačni
OpenOCD ``ft232r`` put provjeren je na Windowsu s driverima **WinUSB** i
**libusbK**. WinUSB je praktičan kada isti FT231X koristi i Hazard3-Doom WebUSB
FPGA flasher. Zadani FTDI VCP/D2XX binding namijenjen je FTDI-native alatima
poput Windows ``fujprog`` i nije libusb OpenOCD put.

Za matricu kompatibilnosti ULX3S drivera pogledajte :doc:`web-flasher`.

Zdravo pokretanje OpenOCD-a na ULX3S 85F uključuje izlaz sličan ovome:

.. code-block:: text

   JTAG tap: lfe5u85.hazard3 tap/device found: 0x41113043
   Examined RISC-V core; found 1 harts
   hart 0: XLEN=32
   Listening on port 3333 for gdb connections

U VM-u početna USB transakcija ponekad može prijaviti
``LIBUSB_ERROR_TIMEOUT`` ili neuspjelo JTAG ispitivanje koje vraća same nule.
Procijenite konačno stanje, ne samo prvo upozorenje: ako OpenOCD nakon toga
ispita RISC-V jezgru i otvori port 3333, debug server je upotrebljiv. Čisto
trenutačno ponovno pokretanje dobra je potvrda. Ako TAP/jezgra nikada nisu
pronađeni, provjerite je li FT231X dodijeljen guestu, je li browser FPGA flasher
odspojen i posjeduje li neki drugi proces JTAG sučelje.

ULX3S s vanjskim Tigardom
-------------------------

Tigard se može koristiti umjesto ugrađenog FT231X-a. To je osobito korisno za
usporedbu debug adaptera, izbjegavanje promjene FT231X drivera ili uporabu bržeg
FT2232H MPSSE JTAG puta. Ožičenje slijedi objavljene Tigard i ULX3S JTAG
pinoute; kvalificirajte ovaj put vanjskog adaptera na ciljnoj pločici prije nego
što ga smatrate projektno provjerenom konfiguracijom.

J4 je fizički vanjski JTAG priključak, a ne zaseban JTAG kontroler. Njegovi
signali ``TCK``, ``TMS``, ``TDI`` i ``TDO`` spojeni su na hardverski JTAG TAP
ECP5 čipa. To su namjenski JTAG pinovi, a ne obični korisnički GPIO, pa Hazard3
ECP5 debug put ne vodi kroz uobičajena LPF ``LOCATE`` ograničenja. ULX3S
referentni LPF također ostavlja ta namjenska mjesta komentirana kao korisnički
GPIO.

Kada je Hazard3 konfiguriran za ECP5 debug transport, put izgleda ovako:

.. code-block:: text

   Tigard / FT2232H
          |
          v
      ULX3S J4
          |
          v
   ECP5 hard JTAG TAP
          |
          v
       JTAGG
          |
          v
   Hazard3 ECP5 JTAG DTM
          |
          v
   RISC-V Debug Module
          |
          v
      Hazard3 CPU

``JTAGG`` je veza FPGA logike prema postojećem ECP5 TAP-u; Hazard3 ne stvara
drugi vanjski TAP. Hazard3 mapira RISC-V ``DTMCS`` i ``DMI`` registre podataka na
ECP5 ``ER1`` i ``ER2`` korisničke registre, koje biraju instrukcije ``0x32`` i
``0x38``. Standardne TAP funkcije poput IDCODE i BYPASS i dalje pruža ECP5 TAP.
Zato OpenOCD najprije identificira ECP5, a zatim privatnim instrukcijama dolazi
do RISC-V debuggera.

To se razlikuje od generičkog Hazard3 načina ``DTM_TYPE="JTAG"``, u kojem je
uobičajeni RISC-V JTAG DTM spojen na četiri korisnička I/O porta. Za ULX3S ECP5
način interno instancira ``hazard3_ecp5_jtag_dtm`` i ``JTAGG``, pa se J4 spaja
na ECP5 TAP, a ne izravno na RISC-V JTAG pinove.

Spojite Tigard JTAG zaglavlje izravno na ULX3S J4:

.. code-block:: text

   Tigard GND (pin 2, black)    -> ULX3S J4 GND
   Tigard TCK (pin 3, white)    -> ULX3S J4 TCK
   Tigard TDI (pin 4, grey)     -> ULX3S J4 TDI
   Tigard TDO (pin 5, purple)   <- ULX3S J4 TDO
   Tigard TMS (pin 6, blue)     -> ULX3S J4 TMS
   Tigard VTGT                  -> not connected
   Tigard TRST / SRST           -> not connected

.. _fig-ulx3s-jtag-pinout:

.. figure:: ../images/ulx3s-jtag-pinout.png
   :alt: ULX3S pinout koji ističe namjenske J4 JTAG pinove TCK, TDI, TDO i TMS.
   :width: 85%

   **ULX3S vanjski JTAG** -- ``J4`` je fizički priključak za hardverski ECP5
   JTAG TAP. Za Tigard koristite njegove namjenske TCK, TDI, TDO i TMS pinove;
   oni nisu obični FPGA GPIO.

Postavite Tigard u ``SPI/JTAG`` način i na 3,3 V logiku. ULX3S napajajte
normalno preko US1. Za fizički raspored J4 i upozorenja o ožičenju pogledajte
:doc:`pinouts`.

Dio OpenOCD konfiguracije za Tigard adapter je:

.. code-block:: text

   adapter driver ftdi
   transport select jtag
   ftdi vid_pid 0x0403 0x6010
   ftdi channel 1
   ftdi layout_init 0x0038 0x003b
   ftdi layout_signal nTRST -data 0x0010
   ftdi layout_signal nSRST -data 0x0020
   adapter speed 1000

Hazard3 dio mete jednak je ``openocd/ulx3s-openocd.cfg``: ECP5 TAP ima 8-bitni
instrukcijski registar, a Hazard3 DTMCS/DMI dohvaćaju se ECP5 privatnim
instrukcijama ``0x32`` i ``0x38``. Za ULX3S 85F ECP5 IDCODE je ``0x41113043``.
Pločica 12F umjesto toga koristi ``0x21111043``.

Nakon što OpenOCD prijavi ECP5 TAP, ispita jedan 32-bitni RISC-V hart i otvori
port 3333, spojite projektni RISC-V GDB na ELF. S točnim GDB izvršnim programom
iz instalirane RISC-V toolchain, interaktivni tijek konceptualno izgleda ovako:

.. code-block:: text

   $ riscv-none-elf-gdb path/to/hazard3-boot-monitor.elf
   (gdb) target extended-remote localhost:3333
   (gdb) monitor halt
   (gdb) break main
   (gdb) continue
   (gdb) next
   (gdb) stepi
   (gdb) info registers
   (gdb) continue

``next`` i ``step`` rade na razini izvornog koda kada su debug informacije
dostupne; ``nexti`` i ``stepi`` rade jednu strojnu instrukciju odjednom. To je
pravo single-step debugiranje Hazard3 RISC-V jezgre koja radi unutar FPGA-a.
Vanjski Tigard i dalje ulazi kroz ECP5 JTAG TAP; ne spaja se izravno na RISC-V
pinove.

Debugiranje ugrađenog ULX3S ESP32 s Tigardom
--------------------------------------------

Ugrađeni ESP32 potpuno je odvojena JTAG meta od Hazard3. To je klasični
dvojezgreni Xtensa ESP32, pa koristite Espressif ESP32 OpenOCD podršku i Xtensa
GDB, a ne RISC-V GDB koji se koristi za Hazard3. Ova je veza izvedena iz ULX3S
sheme/LPF-a i Espressifovih dokumentiranih JTAG pinova; još nije projektno
kvalificirana na ULX3S-u.

Izvorni ESP32 JTAG koristi:

.. code-block:: text

   TDI -> GPIO12 / MTDI
   TCK -> GPIO13 / MTCK
   TMS -> GPIO14 / MTMS
   TDO <- GPIO15 / MTDO

Na ULX3S-u ta četiri ESP32 signala dijele se s microSD sučeljem. Praktična
Tigard veza stoga do njih dolazi preko SD signala:

.. code-block:: text

   Tigard TDI (pin 4, grey)    -> SD DAT2 -> ESP32 GPIO12
   Tigard TCK (pin 3, white)   -> SD DAT3 -> ESP32 GPIO13
   Tigard TMS (pin 6, blue)    -> SD CLK  -> ESP32 GPIO14
   Tigard TDO (pin 5, purple)  <- SD CMD  <- ESP32 GPIO15
   Tigard GND (pin 2, black)   -> board GND

Odgovarajući microSD kontakti su DAT2 pin 1, DAT3 pin 2, CMD pin 3, CLK pin 5 i
VSS/GND pin 6. Breakout ili produžetak mnogo je jednostavniji i sigurniji od
izravnog sondiranja kontakata utora. Izvadite SD karticu.

.. warning::

   ECP5 je spojen na iste SD signale. Nemojte debugirati ESP32 preko tih žica
   dok FPGA može upravljati SD sabirnicom. Koristite ili provjerite FPGA sliku
   koja ostavlja ``SD_D2``, ``SD_D3``, ``SD_CLK`` i ``SD_CMD`` u high-impedance
   stanju. Normalni Hazard3-Doom dizajn koristi SD, pa ovu izolaciju treba
   namjerno osigurati prije spajanja Tigarda.

Držanje ESP32 u resetu pomoću J3
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ako se na FPGA strani pojave problemi sa SD karticom, ULX3S ``J3`` jumper može
se koristiti za držanje ESP32 u resetu. ``J3`` je 2-pinski priključak koji pri
kratkom spoju uzemljuje ESP32 ``EN`` signal. Time se ESP32 onemogućuje i može ga
se izolirati od dijeljene SD sabirnice tijekom dijagnostike ili kada FPGA treba
isključivo vlasništvo nad SD karticom.

.. _fig-ulx3s-j3-wifi-off:

.. figure:: ../images/ulx3s-j3-schematic-zoom.png
   :alt: Detalj ULX3S J3 sheme koji prikazuje ESP32 EN povučen na nisku razinu
   :align: center

   **ULX3S J3 (WIFI_OFF) jumper** -- kratki spoj ``J3`` povlači ESP32 ``EN``
   signal na nisku razinu i drži ESP32 u resetiranom/onemogućenom stanju.

Tigard ``SRST`` po želji se može spojiti na ``WIFI_OFF``/EN stranu ULX3S J3
jumpera za hardverski reset. ESP32 ``EN`` je enable signal aktivan na visokoj
razini; povlačenje na nisku razinu resetira/onemogućuje čip. Nemojte spojiti
reset žicu na GND stranu J3 i nemojte spojiti Tigard ``VTGT`` kada se ULX3S
napaja samostalno.

Ako je instaliran Espressif OpenOCD, konfiguracija je ekvivalentna ovoj:

.. code-block:: bash

   openocd \
       -f interface/ftdi/tigard.cfg \
       -c "set ESP32_FLASH_VOLTAGE 3.3" \
       -f target/esp32.cfg

Zatim koristite ELF koji proizvodi ESP32 build:

.. code-block:: text

   $ xtensa-esp32-elf-gdb path/to/esp32-app.elf
   (gdb) target remote localhost:3333
   (gdb) monitor halt
   (gdb) break app_main
   (gdb) continue
   (gdb) next
   (gdb) stepi

Postavka ``ESP32_FLASH_VOLTAGE`` važna je jer je GPIO12/TDI također ESP32
boot-strapping ulaz. Espressif OpenOCD konfiguracija koristi postavku napona
flasha kako bi JTAG TDI idle stanje odgovaralo 3,3 V flash uređaju.

ULX4M-LD s Tigardom
-------------------

ULX4M Micro-B DFU veza jest put konfiguracije/bootloadera FPGA-a. Ona **nije**
Hazard3 JTAG debug adapter. Za ULX4M-LD debugiranje koristite vanjski Tigard
FT2232H.

Provjerena Tigard konfiguracija
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Koristite ove postavke:

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Stavka
     - Postavka
   * - Tigard odabir načina
     - ``JTAG``
   * - Tigard napajanje mete
     - ``OFF``; nemojte napajati ULX4M iz Tigarda
   * - Referentni napon mete
     - 3,3 V
   * - USB VID:PID
     - ``0403:6010``
   * - OpenOCD FTDI kanal
     - ``1`` (FT2232H kanal B / USB Interface 1)
   * - JTAG sat
     - 1000 kHz
   * - ECP5 uređaj
     - LFE5UM-85F
   * - ECP5 IDCODE
     - ``0x01113043``
   * - Hazard3 DTMCS/DMI instrukcije
     - ``0x32`` / ``0x38``

Ispravan LFE5UM-85F IDCODE je ``0x01113043``. Nemojte koristiti
``0x41113043`` vrijednost povezanu s drugom ECP5 varijantom.

Razdvajanje Windows drivera
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Tigard izlaže dva neovisna FT2232H USB sučelja. Konfigurirajte ih jednom i
ostavite tako:

.. list-table::
   :header-rows: 1
   :widths: 25 25 25 25

   * - USB sučelje
     - FT2232H kanal
     - Windows driver
     - Uporaba u projektu
   * - Interface 0
     - A
     - FTDI VCP
     - UART COM port
   * - Interface 1
     - B
     - libusbK
     - OpenOCD JTAG

To omogućuje istodobnu uporabu PuTTY/Web Serial na UART-u i OpenOCD JTAG-a;
nema razloga stalno mijenjati drivere. Ako se libusbK slučajno instalira na
Interface 0, UART COM port nestaje. Vratite Interface 0 na FTDI USB Serial/VCP
driver i ostavite Interface 1 na libusbK.

.. _fig-zadig-tigard-libusbk:

.. figure:: ../images/Zadig-Tigard-set-interface-1-libusbk.png
   :alt: Zadig odabire libusbK za Tigard Interface 1
   :class: screenshot

   Primijenite libusbK na Tigard Interface 1 za JTAG. Interface 0 zadržite na
   FTDI VCP driveru za UART COM port.

ULX4M-LD UART preko Tigarda
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Tigard UART sučelje neovisno je o JTAG kanalu. Koristite 115200 8N1, bez
kontrole toka. Na Waveshare Raspberry Pi-style 40-pinskom headeru potvrđeno je
ožičenje:

.. code-block:: text

   Tigard UART TX (yellow)  -> physical pin 16 -> GPIO23 -> FPGA N4 -> uart_rx
   Tigard UART RX (orange)  <- physical pin 18 -> GPIO24 <- FPGA N3 <- uart_tx
   Tigard GND               -> physical pin 20
   Tigard VCC               -> not connected

TX i RX moraju biti križani točno kako je prikazano. Za označeni ULX4M-LD
carrier pinout pogledajte :doc:`pinouts`.

ULX4M-LD OpenOCD konfiguracija
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Projektna konfiguracija je:

.. code-block:: bash

   ./bin/openocd.exe -d2 \
       -f ./third_party/Hazard3/example_soc/ulx4m-openocd-tigard.cfg

Važne vrijednosti konfiguracije ekvivalentne su ovima:

.. code-block:: text

   adapter driver ftdi
   ftdi vid_pid 0x0403 0x6010
   ftdi channel 1
   ftdi layout_init 0x0038 0x003b
   ftdi layout_signal nTRST -data 0x0010
   ftdi layout_signal nSRST -data 0x0020

   transport select jtag
   adapter speed 1000

   set _CHIPNAME lfe5um85
   jtag newtap $_CHIPNAME hazard3 \
       -expected-id 0x01113043 \
       -irlen 8 \
       -irmask 0xFF \
       -ircapture 0x5

   set _TARGETNAME $_CHIPNAME.hazard3
   target create $_TARGETNAME riscv -chain-position $_TARGETNAME
   riscv set_ir dtmcs 0x32
   riscv set_ir dmi 0x38

   gdb_report_data_abort enable
   init
   halt

Provjereno Tigard ožičenje **ne** spaja žicu za reset mete. Nemojte se
oslanjati na SRST/TRST za resetiranje ili pokretanje ULX4M dizajna; FTDI layout
unosi ostaju dio konfiguracije adaptera, ali reset u ovoj postavi nije fizički
spojen na metu.

Zdrava sesija dolazi do izlaza sličnog ovome:

.. code-block:: text

   JTAG tap: lfe5um85.hazard3 tap/device found: 0x01113043
   Examined RISC-V core; found 1 hart
   XLEN=32
   Listening on port 3333 for gdb connections

Poznata ispravna Hazard3 DTMCS vrijednost je ``0x00004071``.

Tumačenje ``dtmcontrol is 0``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Hardverski ECP5 JTAG TAP može vratiti IDCODE čipa čak i kada Hazard3 korisnički
bitstream ne radi. Zato je ova kombinacija dijagnostički korisna:

.. code-block:: text

   JTAG IDCODE = 0x01113043
   dtmcontrol = 0

Ona dokazuje da fizički Tigard-prema-ECP5 JTAG put radi, ali **ne** dokazuje da
je Hazard3 ``JTAGG``/DTM korisnička logika aktivna. Prije promjene DTM RTL-a ili
JTAG ožičenja potvrdite da je ULX4M korisnički bitstream stvarno pokrenut. Ako
je pločica još u DFU bootloaderu, pokrenite:

.. code-block:: bash

   ./bin/dfu-util.exe -a 0 -e

Zatim ponovno pokušajte OpenOCD. U provjerenom bring-up slijedu izlazak iz DFU-a
na ovaj način pokrenuo je korisnički dizajn, vratio Hazard3 UART i učinio
korisničku FPGA logiku dostupnom za daljnje testiranje.

Ako korisnički dizajn vidljivo radi preko UART-a, ali DTMCS je i dalje nula,
upotrijebite sirovi ECP5 ER1/DTMCS scan ili usporedite s ranije poznatim dobrim
OpenOCD buildom prije mijenjanja Hazard3 RTL-a.

Izgradnja i učitavanje monitora usklađenog sa satom
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Trenutačni kvalificirani ULX4M-LD FPGA profil pokreće Hazard3/AHB na 40 MHz.
Izgradite odgovarajući software-only monitor bez ponovnog routanja FPGA-a:

.. code-block:: bash

   HAZARD3_BUILD_DIR="$PWD/build/ulx4m-ld-monitor-test/monitor" \
   HAZARD3_MEMORY_PROFILE=64m \
   HAZARD3_SYS_CLK_HZ=40000000 \
       ./scripts/build.sh

Zatim, dok OpenOCD već ispituje metu:

.. code-block:: bash

   ./scripts/load-firmware.sh \
       ./build/ulx4m-ld-monitor-test/monitor/hazard3-boot-monitor.elf

Uspješno učitavanje prijavljuje podudarne ``.vectors``, ``.text``, read-only
podatke i ``.data`` sekcije prije nastavka s adrese ``0x00000040``.

VisualGDB
---------

Windows korisnici mogu koristiti projektne datoteke u ``VisualGDB/`` s Visual
Studiom. Debugger i dalje komunicira s istom OpenOCD/GDB metom, pa naredbeni
put ostaje referentni workflow. Odspojite VisualGDB prije pokretanja batch
firmware loadera jer samo jedan GDB klijent smije istodobno posjedovati OpenOCD
metu.

GDB startup helper je:

.. code-block:: text

   scripts/hazard3-debug.gdb

Rješavanje problema
-------------------

Ako debug modul nije pouzdano otkriven, najprije razlikujte fizički TAP pristup
od Hazard3 DTM pristupa. Ispravan ECP5 IDCODE uz DTMCS nula drugačiji je kvar od
adaptera koji uopće ne može pročitati ECP5 IDCODE. Smanjite JTAG sat tek nakon
provjere aktivne FPGA slike, Tigard raspodjele drivera i postavki
napajanja/referentnog napona mete.

Za uobičajene OpenOCD probleme i vlasništvo nad sučeljima pogledajte
:doc:`../troubleshooting`.

Vanjske reference
-----------------

* `ULX3S priručnik <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_
* `ULX3S v2.x/v3.0 ograničenja <https://github.com/emard/ulx3s/blob/master/doc/constraints/ulx3s_v20.lpf>`_
* `Hazard3 ECP5 JTAG DTM <https://github.com/Wren6991/Hazard3/blob/stable/hdl/debug/dtm/hazard3_ecp5_jtag_dtm.v>`_
* `Hazard3 example SoC odabir DTM-a <https://github.com/Wren6991/Hazard3/blob/stable/example_soc/soc/example_soc.v>`_
* `Tigard pinout i uporaba <https://github.com/tigard-tools/tigard>`_
* `Espressif ESP32 JTAG mapiranje pinova <https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/jtag-debugging/configure-other-jtag.html>`_
* `yosys/nextpnr podržani primitivi <https://github.com/YosysHQ/nextpnr/blob/main/ecp5/docs/primitives.md>`_
