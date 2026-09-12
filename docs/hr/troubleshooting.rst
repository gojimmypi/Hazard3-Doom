Otklanjanje poteškoća
=====================

Windows ``fujprog`` prijavljuje ``Cannot find JTAG cable``
----------------------------------------------------------

Na Windowsu ``fujprog`` očekuje da ULX3S ``US1`` FT231X sučelje koristi normalni
FTDI VCP/D2XX driver. Ako je to sučelje prebačeno na WinUSB za WebUSB flasher ili
na drugi libusb driver za JTAG, prije korištenja Windows ``fujprog`` alata vratite
FTDI driver u Device Manageru.

Najprije zatvorite OpenOCD, ``openFPGALoader`` i WebUSB sesije preglednika,
vratite FTDI driver, odspojite/ponovno spojite ``US1`` i pokušajte ponovno.
Pogledajte :doc:`user-guide/web-flasher` za tablicu kompatibilnosti drivera i
postupak vraćanja.

.. _webusb-access-denied:

WebUSB flasher prijavljuje ``USBDevice.open(): Access denied``
--------------------------------------------------------------

Ako FPGA web flasher vidi ULX3S FTDI uređaj, ali Windows odbije
``USBDevice.open()``, problem nastaje prije početka JTAG-a. Izravni WebUSB
pristup zahtijeva da ULX3S FT231X sučelje koristi WinUSB driver umjesto
normalnog FTDI VCP/D2XX drivera.

#. Zatvorite ``fujprog``, OpenOCD, ``openFPGALoader`` i druge programe koji možda koriste FT231X.
#. Potvrdite da je odabrani uređaj ULX3S ``US1`` FT231X.
#. Vežite to sučelje na WinUSB, primjerice pomoću Zadiga.
#. Odspojite i ponovno spojite ``US1``.
#. Ponovno učitajte web aplikaciju i povežite flasher.

.. warning::

   Zamjena FTDI drivera mijenja način na koji Windows izlaže to sučelje.
   Provjerite odabrani uređaj prije promjene drivera. Softver koji očekuje
   normalni FTDI VCP/D2XX driver neće koristiti to sučelje dok se FTDI driver
   ne vrati.

.. figure:: images/Zadig-FTDI-to-WinUSB.png
   :alt: Zadig zamjenjuje ULX3S FTDI driver WinUSB driverom.
   :width: 580px

   Primjer odabira WinUSB-a za ULX3S FT231X.

Pogledajte :doc:`user-guide/web-flasher` za potpuni tijek WebUSB programiranja
i napomene o vraćanju drivera.

WebUSB flasher prijavljuje neprepoznat JTAG ID
----------------------------------------------

Nemojte programirati dok fizički ECP5 cilj nije identificiran. Zatvorite drugi
JTAG softver, odspojite/ponovno spojite ``US1``, ponovno povežite preglednik i
ponovite probe. Ispravan ULX3S probe trebao bi identificirati podržani ECP5
poput ``LFE5U-12F`` ili ``LFE5U-85F`` i prikazati njegov 32-bitni IDCODE.

FT231X USB product string nije autoritativan za varijantu FPGA-a. Pri odluci
odgovara li slika pločici koristite ECP5 JTAG ID koji prijavi **Probe JTAG**.

WebUSB flasher prijavljuje nepodudaranje cilja FPGA slike
---------------------------------------------------------

To je sigurnosna provjera. ECP5 cilj ugrađen u odabranu ``.bit`` datoteku ne
odgovara fizičkom JTAG ID-u. Odaberite ili ponovno izgradite bitstream za
priključeni FPGA umjesto zaobilaženja provjere.

.. _web-serial-no-compatible-devices:

Web Serial izbornik kaže da nema kompatibilnih uređaja
------------------------------------------------------

Ako preglednik otvori Web Serial izbornik, ali prijavi ``No compatible devices
found`` iako Windows prikazuje COM port, prije promjene hardvera ili USB
serijskih drivera provjerite preglednik.

#. Ako Chrome prikazuje ``Finish update``, ``Relaunch`` ili drugi indikator
   čekajućeg ažuriranja, dovršite ažuriranje i potpuno ponovno pokrenite Chrome.
   Tijekom Hazard3-Doom testiranja Chrome je i dalje enumerirao CH340 adapter
   kao ``COM7`` u ``chrome://device-log``, dok je Web Serial izbornik ostao
   prazan. Nakon dovršetka ažuriranja i ponovnog pokretanja Chromea izbornik je
   ponovno radio.
#. Ponovno pokušajte **Connect**. Hazard3-Doom web konzola namjerno traži
   browserov izbornik serijskih portova bez USB VID/PID filtra, pa je
   projektirana za rad sa svakim serijskim portom koji preglednik izloži.
#. Zatvorite PuTTY, upload skripte, IDE serijske monitore ili druge programe
   koji možda već koriste port.
#. Otvorite ``chrome://device-log``, omogućite kategorije Serial i USB te
   provjerite je li očekivani COM port uklonjen, ali nikad ponovno dodan. U
   jednoj provjerenoj debug sesiji Chrome je zabilježio ``Serial device removed:
   path=COM7`` i nije se oporavio nakon samog zaustavljanja OpenOCD-a, iako je
   PuTTY i dalje mogao otvoriti port. Fizičko odspajanje i ponovno spajanje
   vanjskog USB-UART adaptera prisililo je ponovnu enumeraciju u
   Windowsu/Chromeu i vratilo Web Serial izbornik.
#. Ako je debug aktivnost prethodila kvaru, zatvorite PuTTY i druge vlasnike
   serijskog porta, zaustavite OpenOCD, zatim fizički odspojite/ponovno spojite
   **vanjski USB-UART adapter**. Samo zaustavljanje OpenOCD-a može osloboditi
   njegov FT231X/JTAG handle bez toga da Chrome ponovno otkrije neovisni COM
   port.
#. Nakon ponovnog spajanja, ``chrome://device-log`` trebao bi prikazati USB
   uređaj i novi događaj ``Serial device added`` za očekivani COM port.
   Koristite **Connect** u web UI-u kako biste pozvali browser izbornik.
#. Nemojte koristiti ``navigator.serial.getPorts()`` kao potpuni inventar
   Windows COM portova. Vraća samo portove koji su već autorizirani za
   trenutačni browser origin. Za dodjelu pristupa drugom portu koristite
   **Connect**.

.. figure:: images/chrome-pending-update.png
   :alt: Chrome prikazuje gumb Finish update dok je Hazard3-Doom UART Console odspojen.
   :width: 520px

   Ako je Web Serial izbornik prazan dok Chrome prikazuje čekajuće ažuriranje,
   dovršite ažuriranje i ponovno pokrenite preglednik prije promjene serijskih
   drivera.

Web Serial odabere Linux TTY, ali ga ne može otvoriti
-----------------------------------------------------

Ako Chrome može vidjeti i odobriti port poput ``USB2.0-Serial (ttyUSB1)``, ali
``SerialPort.open()`` ne uspije, odvojeno provjerite preglednikovo odobrenje i
Linux dozvole uređaja.

Provjerite čvor uređaja, grupe trenutačne prijavne sesije i trenutačnog vlasnika:

.. code-block:: bash

   ls -l /dev/ttyUSB1
   groups
   fuser -v /dev/ttyUSB1

Uobičajen rezultat na Ubuntuu je:

.. code-block:: text

   crw-rw---- 1 root dialout ... /dev/ttyUSB1

Ako ``dialout`` posjeduje uređaj, ali ga nema u izlazu ``groups``, dodajte
korisnika:

.. code-block:: bash

   sudo usermod -aG dialout "$USER"

Promjena vrijedi za **novu prijavnu sesiju**. Izlaz ``groups`` u postojećoj
sesiji radne površine neće se promijeniti samo zato što je ``usermod`` uspio, a
već pokrenuti Chrome zadržava stare dodatne grupe.

Za privremenu dijagnostiku bez ponovnog pokretanja, odjave ili ponovnog spajanja
USB-a dodijelite trenutačnom korisniku ACL na postojećem čvoru uređaja:

.. code-block:: bash

   sudo setfacl -m u:"$USER":rw /dev/ttyUSB1

Zamijenite ``ttyUSB1`` stvarnim portom. Ovaj ACL može nestati kada se uređaj
ponovno enumerira; članstvo u ``dialout`` ostaje uobičajeno trajno rješenje.
``newgrp dialout`` može odmah stvoriti shell s novom grupom, ali ne mijenja već
pokrenutu radnu površinu ili Chrome proces.

Ako su dozvole ispravne, ali otvaranje i dalje ne uspijeva, naredbom ``fuser``
provjerite koristi li drugi proces port. Ubuntuov ModemManager također može
ispitivati USB serijske adaptere. Za dijagnostiku ga privremeno zaustavite:

.. code-block:: bash

   sudo systemctl stop ModemManager

Trajno onemogućite ModemManager samo na sustavu na kojem njegove modemske
funkcije namjerno nisu potrebne.

UART izlaz je čitljiv, ali monitor ignorira naredbe
---------------------------------------------------

Čitljiv tekst pri pokretanju na ``115200 8N1`` potvrđuje FPGA TX put i baud
rate, ali **ne** potvrđuje suprotni UART smjer. Ako monitor ispiše čistu poruku
pri pokretanju i prompt ``>``, ali ``h`` ili ``?`` ne daje odgovor, najprije
provjerite put od TX izlaza adaptera do RX ulaza FPGA-a. Labava spojna žica može
uzrokovati upravo ovakav jednosmjerni simptom.

Projektom provjereno ULX3S ožičenje je:

.. code-block:: text

   adapter TX  -> ULX3S J1 pin 8 / GP1 / Hazard3 RxD
   adapter RX  <- ULX3S J1 pin 6 / GP0 / Hazard3 TxD
   adapter GND -> ULX3S GND

Pogledajte :doc:`hardware/ulx3s/interfaces` za opis sučelja pločice.

Da biste razlikovali ponašanje preglednika od fizičkog UART-a, odspojite Web
Serial kako bi oslobodio port, a zatim izravno testirajte na Linuxu:

.. code-block:: bash

   stty -F /dev/ttyUSB1 \
       115200 cs8 -cstopb -parenb \
       -ixon -ixoff -crtscts raw -echo

   # U jednom terminalu:
   cat /dev/ttyUSB1

   # U drugom terminalu pošaljite monitorovu jednobajtnu naredbu za pomoć:
   printf 'h' > /dev/ttyUSB1

Ako je izlaz pri pokretanju čist, ali ova naredba i dalje ne daje odgovor,
usredotočite se na TX žicu adaptera, sjedanje konektora, masu i FPGA RX pin
umjesto mijenjanja OpenOCD-a ili baud ratea.

Doom upload istječe
-------------------

* Izađite iz Dooma pomoću ``Ctrl-X`` kako bi rezidentni monitor slušao.
* Zatvorite PuTTY ili drugi program koji koristi UART port.
* Potvrdite odabrani COM/TTY uređaj.
* Potvrdite da monitor i uploader koriste isti memorijski profil.

Nema micro-SD kartice, ali hladno pokretanje prijavljuje CMD0 pogrešku
-----------------------------------------------------------------------

To je očekivano. Rezidentni monitor pokušava put hladnog pokretanja s micro-SD
kartice prije povratka na interaktivni prompt. Bez umetnute kartice izlaz može
sadržavati:

.. code-block:: text

   ULX3S cold boot: trying micro-SD...
   SD boot: initializing micro-SD...
   SD: CMD0 failed r1=0x000000FF
   SD boot: card initialization failed
   Type h or ? for help.
   >

Ako su SDRAM/video dijagnostike prošle i pojavi se prompt ``>``, poruka o
nedostajućoj kartici nije kvar sustava.

SD kartica se montira, ali datoteke nisu pronađene
--------------------------------------------------

* Koristite nazive u korijenu ``DOOM.H3D`` i ``DOOM.WAD``.
* Potvrdite FAT16/FAT32 formatiranje.
* Koristite naredbu monitora ``c`` za pregled FAT tipa, stanja mounta i pronađenih veličina datoteka.
* Nemojte se oslanjati na duge nazive datoteka; boot put projektiran je oko korijenskih 8.3 naziva.

SD postaje nepouzdan kada radi ESP32 firmware
---------------------------------------------

Potvrdite da su ESP32 GPIO 14, 15, 2 i 13 u stanju visoke impedancije dok
Hazard3 posjeduje SD sabirnicu. Zastavica vlasništva u firmwareu nije dovoljna
ako su izlazni driveri ESP32 pinova i dalje omogućeni.

SAO scan pronalazi neke uređaje, ali ne i druge
-----------------------------------------------

Nije svaki SAO nužno I2C periferija. Neki uređaji mogu koristiti opcionalne
GPIO pinove ili neuobičajeno I2C ponašanje. Koristite ``sao info``, ``sao
scan``, ``sao probe`` i dokumentaciju uređaja prije zaključka da je bridge
neispravan.

``i2c gui`` je prijavljen kao nepoznata naredba
-----------------------------------------------

Na pločici radi stariji rezidentni monitor. Izgradnja novog ELF-a ne zamjenjuje
firmware koji se već izvršava u Hazard3. Ponovno izgradite i izričito učitajte
monitor:

.. code-block:: bash

   ./scripts/build.sh
   ./scripts/load-firmware.sh ./build/hazard3-boot-monitor.elf

Nakon učitavanja pomoć monitora trebala bi navesti i ``sao gui`` i ``i2c gui``.

I2C GUI scan pronalazi uređaj, ali je logički trag prazan
---------------------------------------------------------

Starije revizije HDMI GUI-a brisale su logički trag na kraju ``S`` skeniranja.
Trenutačni kod zadržava probe trag za posljednju adresu koja je odgovorila ACK-om.
Ponovno izgradite/učitajte trenutačni monitor ako se heatmap ažurira, ali trag
skeniranja ostaje prazan. ``P`` na poznatoj adresi također je izravna provjera
renderera logičkog traga.

I2C GUI ostaje na HDMI-u nakon izlaska
--------------------------------------

To je očekivano s trenutačnim softverom. Izlazak vraća UART upravljanje
monitorom i SAO brzinu sabirnice od 100 kHz, ali ne rekonstruira frame koji je
bio vidljiv prije pokretanja GUI-a. Pokrenite Doom ili prikažite drugi video
frame monitora kako biste zamijenili zadnju sliku analizatora.

Uploader firmwarea konzole ostaje na ``Loading...``
---------------------------------------------------

Preglednikov uploader firmwarea konzole ne pokreće OpenOCD. Tri dijela moraju
raditi istodobno:

.. code-block:: text

   preglednik -> web-server.py -> GDB -> OpenOCD :3333 -> Hazard3

Pokrenite OpenOCD u jednom terminalu i ostavite ga pokrenutog:

.. code-block:: bash

   ./scripts/start-openocd.sh

Upotrebljiva sesija mora doći do poruka ``Examined RISC-V core`` i ``Listening
on port 3333 for gdb connections``. U drugom terminalu pokrenite:

.. code-block:: bash

   python3 web/web-server.py

Otvorite ``http://127.0.0.1:8000/``. Nemojte koristiti ``file://`` URL za
``web/index.html``. Stanje **Local loader Ready** na web-stranici znači da je
lokalni HTTP pomoćni proces dostupan; OpenOCD i dalje mora zasebno raditi.
Tijekom normalnog batch učitavanja OpenOCD može zabilježiti prihvaćenu GDB vezu,
a zatim ``dropped 'gdb' connection`` kada se loader odspoji nakon nastavka rada
jezgre.

Korisne provjere su:

.. code-block:: bash

   ss -ltnp | grep ':3333'
   curl http://127.0.0.1:8000/api/console-firmware/status

Također odspojite preglednikov FPGA web flasher s ``US1`` prije pokretanja
OpenOCD-a jer oba koriste isto FT231X JTAG sučelje. Vanjski J1 USB-UART adapter
je odvojen i može ostati spojen.

OpenOCD prijavljuje USB timeout ili potpuno nulti JTAG scan u VM-u
------------------------------------------------------------------

USB passthrough virtualnog stroja ponekad može pri početku proizvesti poruku
poput ``LIBUSB_ERROR_TIMEOUT`` nakon koje slijedi ``JTAG scan chain interrogation
failed: all zeroes``. Prije zaključka da sesija nije uspjela provjerite kasnije
OpenOCD stanje. Ako zatim prijavi:

.. code-block:: text

   Examined RISC-V core; found 1 harts
   Listening on port 3333 for gdb connections

GDB može koristiti server. Za potvrdu jednom zaustavite i odmah ponovno
pokrenite OpenOCD kako biste provjerili da je scan čist. Ako OpenOCD nikada ne
pronađe ECP5 TAP ili Hazard3 jezgru, provjerite VMware USB vezu prema gostu,
zatvorite preglednikov WebUSB FPGA flasher i provjerite koristi li netko drugi
JTAG prije promjene taktova ili RTL-a.

OpenOCD ne vidi ispravan Hazard3 debug modul
--------------------------------------------

* Na Windows ULX3S-u koristite aktualni OpenOCD build s podrškom za ``ft232r``
  i vežite ugrađeni FT231X na **WinUSB** ili **libusbK**. Trenutačna postava
  projekta provjerena je s WinUSB-om; libusbK nije obvezan.
* Nemojte zamijeniti ULX3S ``US1`` FT231X/JTAG driver sa zasebnim driverom
  vanjskog USB-UART COM porta koji koristi Web Serial.
* Smanjite JTAG takt.
* Osigurajte da je spojen samo jedan GDB klijent.
* Provjerite da je FPGA bitstream očekivani Hazard3 build.
* Provjerite da ELF odgovara aktivnom hardveru/buildu monitora.
* Razlikujte povezivost ECP5 TAP-a od povezivosti Hazard3 debug modula.

Ako isti FT231X treba i browser FPGA flasheru, preferirajte WinUSB kako bi i
OpenOCD/GDB i WebUSB radili bez nove zamjene drivera. Vratite FTDI VCP/D2XX
driver samo kada ga zahtijeva alat poput Windows ``fujprog``.

Build se iznenada mijenja zbog submodula
----------------------------------------

Provjerite stanje superprojekta i submodula:

.. code-block:: bash

   git status
   git submodule status --recursive
   git branch --show-current
   git -C third_party/Hazard3 branch --show-current
   git -C third_party/doomgeneric branch --show-current

Čist superprojekt ne znači da je submodul na grani ili commitu koji ste
očekivali.
