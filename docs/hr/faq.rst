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

OpenOCD ne sluša na ``localhost:3333``
-----------------------------------------

Trenutačni ``scripts/load-firmware.sh`` provjerava port 3333 prije pokretanja
GDB-a. Ako OpenOCD ne radi, skripta se zaustavlja s izravnom pogreškom umjesto
da dopusti GDB-u prelazak na lokalni ``exec`` target. Starije verzije loadera
mogle su ispisati ``monitor command not supported`` ili ``target is exec`` i
zatim prikazati lokalne ELF sekcije kao ``matched``; te usporedbe **nisu**
provjeravale FPGA memoriju.

Za ULX3S 12F nakon programiranja bitstreama koristite praktični loader:

.. code-block:: bash

   ./scripts/load-firmware-12f.sh

Ponovno koristi OpenOCD na portu 3333 ili automatski pokreće projektni OpenOCD
launcher, čeka GDB server i zatim učitava board-specific SDRAM monitor.

Na Windowsu/WSL-u, ako OpenOCD prijavi ``LIBUSB_ERROR_NOT_SUPPORTED`` i ne može
pronaći ``0403:6015``, ULX3S FT231X je obično još vezan na izvorni FTDI
FTDIBUS/D2XX driver. Pomoću Zadiga vežite WinUSB ili libusbK za OpenOCD. Windows
``fujprog`` koristi izvorni FTDI driver, pa prelazak između ``fujprog`` i
OpenOCD-a može zahtijevati promjenu tog vezanja.

Web Serial ne prikazuje kompatibilne uređaje, ali Windows vidi COM port. Što prvo pokušati?
--------------------------------------------------------------------------------------------

Ako Chrome prikazuje da čeka ažuriranje preglednika, dovršite ažuriranje i
potpuno ponovno pokrenite Chrome prije promjene USB serijskih drivera ili
izmjene Hazard3-Doom web konzole.

Pogledajte indikator ažuriranja preglednika ispod:

.. image:: images/chrome-pending-update.png
   :alt: Chrome indikator čekajućeg ažuriranja
   :align: center
   :class: screenshot

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

Chrome vidi ``ttyUSB`` na Ubuntuu, ali Web Serial ga ne može otvoriti. Zašto?
-------------------------------------------------------------------------------

Chromeovo odobrenje uređaja i Linux TTY dozvole odvojene su stvari. Ako je
``/dev/ttyUSB1`` u vlasništvu ``root:dialout``, a trenutačni izlaz naredbe
``groups`` ne sadrži ``dialout``, Chrome može prikazati uređaj u izborniku, ali
``SerialPort.open()`` i dalje može ne uspjeti.

Dodajte korisnika naredbom ``sudo usermod -aG dialout "$USER"`` i otvorite
novu prijavnu sesiju. Za privremenu dijagnostiku bez ponovnog pokretanja ACL
poput ``sudo setfacl -m u:"$USER":rw /dev/ttyUSB1`` može trenutačnom
korisniku dati pristup postojećem čvoru uređaja. Pogledajte
:doc:`troubleshooting` za provjeru vlasništva porta, ModemManagera i UART
ožičenja.

Može li javna GitHub Pages stranica učitati console ELF?
--------------------------------------------------------

Da, ako lokalni loopback helper radi. Stranica može ostati na
``https://ulx3s.github.io/Hazard3-Doom/`` dok ``web-server.py``, GDB i
OpenOCD rade na lokalnom računalu. Preglednik poziva helper na
``127.0.0.1:8000``, a helper zatim koristi lokalni GDB/OpenOCD put.

Console firmware panel odvojeno prikazuje stanje helpera i OpenOCD-a. Neobavezni
``web-server.py --access-key`` dodaje zajednički ključ koji se unosi u stranicu,
ali se ne sprema u ``localStorage``. Pogledajte :doc:`user-guide/web-tool`.

Zašto se drugi Device Tool tab ne može spojiti na UART?
-------------------------------------------------------

Serijski port može imati samo jednog vlasnika. Tabovi iste origine koordiniraju
se preko Web Locka i ``BroadcastChannel`` kako bi drugi tab mogao prijaviti da
je UART već zauzet. Različite origine, primjerice ``http://127.0.0.1:8000`` i
``https://ulx3s.github.io``, ne dijele taj lock, ali preglednik/operacijski
sustav ipak odbija drugo otvaranje. Odspojite prvi tab i upotrijebite **Retry
UART**.

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
