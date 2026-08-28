Često postavljana pitanja
=========================

ULX3S pločica nije prepoznata
-----------------------------

Provjerite je li USB-A na Micro-USB kabel spojen na `US`, priključak na istom
kraju pločice kao SD kartica.

Koristite kratke i kvalitetne kabele. Kabel ne smije biti samo za punjenje.

Pokušajte izravnu vezu, bez USB hubova.

Prazan HDMI zaslon
------------------

Ako je zaslon neko vrijeme bio uključen bez aktivnog HDMI signala, možda se
neće probuditi na prvi video signal. Pokušajte isključiti napajanje i pričekati
nekoliko sekundi prije ponovnog pokušaja. Takvo je ponašanje zabilježeno na
Elecrow 7" HDMI zaslonu.

Naredba "monitor" nije podržana za ovaj target.
------------------------------------------------

Pogledajte sljedeći odjeljak: to ne možete učiniti kada je target ``exec``.

To ne možete učiniti kada je target ``exec``
--------------------------------------------

Ako pri učitavanju firmwarea Console Monitora pomoću GDB-a vidite sličnu
pogrešku, provjerite radi li OpenOCD i sluša li na očekivanom portu (zadano:
3333).

$ ./scripts/load-firmware-12f.sh
Calling /mnt/c/workspace/Hazard3-Doom/scripts/load-firmware.sh \
-rwxr-xr-x 1 gojimmypi gojimmypi 316036 Aug 25 12:10 hazard3-boot-monitor.elf
localhost:3333: Connection timed out.
"monitor" command not supported by this target.
You can't do that when your target is ``exec``
Section .vectors, range 0x20000040 -- 0x20000076: matched.
Section .text, range 0x20000078 -- 0x2000bacb: matched.
Section .srodata.bar_colors.1, range 0x2000bacc -- 0x2000bad4: matched.
Section .data, range 0x2000bad4 -- 0x2000badc: matched.
No registers.

You can't do that when your target is ``exec``


Web Serial ne prikazuje kompatibilne uređaje, ali Windows vidi COM port. Što prvo pokušati?
--------------------------------------------------------------------------------------------

Ako Chrome prikazuje da čeka ažuriranje preglednika, dovršite ažuriranje i
potpuno ponovno pokrenite Chrome prije promjene USB serijskih drivera ili
izmjene Hazard3-Doom web konzole.

Pogledajte indikator ažuriranja preglednika ispod:

.. image:: images/chrome-pending-update.png
   :alt: Chrome indikator čekajućeg ažuriranja
   :align: center

Tijekom testiranja Hazard3-Dooma na Windowsu, Chromeov interni zapis uređaja i
dalje je prijavljivao CH340 adapter kao ``COM7``, ali je izbornik Web Serial
prikazivao ``No compatible devices found``. Nakon dovršetka čekajućeg Chrome
ažuriranja i ponovnog pokretanja preglednika, izbornik serijskog porta ponovno
je radio.

Hazard3-Doom web konzola namjerno traži nefiltrirani izbornik serijskih portova,
pa nije ograničena na CH340, FTDI, CP210x ili neki drugi određeni USB-serijski
adapter.

Također imajte na umu da ``navigator.serial.getPorts()`` vraća portove za koje
je trenutačni browser origin već dobio dopuštenje. To nije popis svih COM
portova instaliranih u Windowsu.

Ako ponovno pokretanje ažuriranog preglednika ne vrati port, nastavite s
:ref:`web-serial-no-compatible-devices`. Posebno, ako je Chrome zabilježio da je
COM port uklonjen tijekom debug sesije, fizički odspojite i ponovno spojite
vanjski USB-UART adapter. Samo zaustavljanje OpenOCD-a možda neće pokrenuti
ponovnu enumeraciju serijskog uređaja u Windowsu/Chromeu potrebnu da port
ponovno postane dostupan za odabir.

Može li OpenOCD koristiti WinUSB na ULX3S-u?
--------------------------------------------

Da, s trenutačnom Hazard3-Doom ULX3S postavom. Projektni OpenOCD put koristi
adapter ``ft232r`` kroz libusb i provjeren je s ugrađenim FT231X vezanim na
WinUSB. libusbK također radi s OpenOCD-om, ali više nije obvezan odabir drivera.
GDB se povezuje na OpenOCD preko TCP-a i zato radi s bilo kojim FT231X vezanjem
koje OpenOCD uspješno koristi.

WinUSB je posebno praktičan jer zadovoljava i browser WebUSB FPGA/JTAG flasher.
Normalni FTDI VCP/D2XX driver i dalje je potreban FTDI-native aplikacijama poput
Windows ``fujprog``. Pogledajte :doc:`user-guide/web-flasher` za matricu
kompatibilnosti.

Zašto FPGA WebUSB flasher treba WinUSB na Windowsu?
---------------------------------------------------

ULX3S ``US1`` FT231X uobičajeno koristi FTDI Windows driver. Chrome/Edge WebUSB
ne može otvoriti to sučelje kroz normalno FTDI VCP/D2XX vezanje, pa browser
programator za izravni USB pristup zahtijeva WinUSB. To utječe samo na
WebUSB/JTAG put; zaseban USB-UART adapter može i dalje služiti Hazard3-Doom Web
Serial konzoli.

Pogledajte :doc:`user-guide/web-flasher` za upute za postavljanje i vraćanje
drivera ili :ref:`webusb-access-denied` ako preglednik prijavi ``Access denied``.
