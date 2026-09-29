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
   :class: screenshot

   Primjer odabira WinUSB-a za ULX3S FT231X.

Pogledajte :doc:`user-guide/web-flasher` za potpuni tijek WebUSB programiranja
i napomene o vraćanju drivera.


Zadig prijavljuje ``Driver Installation: FAILED (Could not allocate resource)``
-------------------------------------------------------------------------------

Ako Zadig ne uspije zamijeniti ULX3S FTDI upravljački program i prikaže poruku
poput ``Driver Installation: FAILED (Could not allocate resource)``, prije
uklanjanja upravljačkih programa ili promjene konfiguracije uređaja provjerite
je li ostao zaglavljen libwdi/Zadig pomoćni proces.

Zatvaranje Zadiga ne mora nužno ugasiti pomoćni proces. U jednom potvrđenom
slučaju ``zadig.exe`` više nije radio, ali je ``installer_x64.exe`` ostao
zaglavljen u pozadini i sprječavao sljedeću instalaciju upravljačkog programa.

U PowerShellu provjerite relevantne instalacijske/pomoćne procese:

.. code-block:: powershell

   Get-Process installer_x64*, wdi*, dpinst*, pnputil* -ErrorAction SilentlyContinue |
       Select-Object Id, ProcessName, Path

Ako je prisutan zaostali ``installer_x64.exe``, a instalacija upravljačkog
programa nije namjerno u tijeku, zaustavite ga:

.. code-block:: powershell

   Stop-Process -Name installer_x64 -Force

Zatim potvrdite da ga više nema:

.. code-block:: powershell

   Get-Process installer_x64* -ErrorAction SilentlyContinue

Ako je od napuštene instalacije/uklanjanja uređaja ostao aktivan i stari
``pnputil.exe``, zaustavite i njega prije ponovnog pokušaja.

Nakon uklanjanja zaostalog pomoćnog procesa:

#. Zatvorite Zadig.
#. Odspojite ULX3S USB vezu.
#. Pričekajte nekoliko sekundi i ponovno je spojite.
#. Pokrenite Zadig kao administrator.
#. Omogućite **Options -> List All Devices**.
#. Odaberite željeno ULX3S FTDI sučelje i provjerite USB ID ``0403:6015``.
#. Ponovno pokušajte instalirati WinUSB/libusb upravljački program.

Nemojte kao prvi korak deinstalirati nepovezane FTDI uređaje. Zaostali
``installer_x64.exe`` može izazvati ovu pogrešku čak i kada Zadig, OpenOCD,
``fujprog`` i drugi vidljivi USB alati više ne rade.

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

.. _fig-chrome-pending-update:

.. figure:: images/chrome-pending-update.png
   :alt: Chrome prikazuje gumb Finish update dok je Hazard3-Doom UART Console odspojen.
   :class: screenshot

   Ako je Web Serial izbornik prazan dok Chrome prikazuje čekajuće ažuriranje,
   dovršite ažuriranje i ponovno pokrenite preglednik prije promjene serijskih
   drivera.


Web Serial izbornik se zatvori, ali se UART ipak ne poveže
----------------------------------------------------------

Ako odaberete serijski uređaj i izbornik preglednika se zatvori, ali alat ostane
nepovezan, najprije provjerite posjeduje li port već neka druga aplikacija.

Trenutačni alat koordinira kartice istog izvora pomoću Web Locka preglednika i
``BroadcastChannel``. Ako druga kopija iste stranice već posjeduje UART, druga
stranica prijavljuje **UART already in use**. Stranica s drugog izvora, PuTTY,
terminal IDE-a ili druga aplikacija ne mogu se identificirati po imenu, pa se
neuspjeli ``SerialPort.open()`` prijavljuje kao vjerojatan sukob vlasništva.

Uobičajeni oporavak:

#. Zatvorite ili odspojite drugu karticu alata ili serijsku aplikaciju.
#. Vratite se u odjeljak za H3IMG/IWAD ili Serial povezivanje.
#. Odaberite **Retry UART** ili **Connect UART** i ponovno odaberite port.

Imajte na umu da su ``http://127.0.0.1:8000`` i javna stranica
``https://ulx3s.github.io`` različiti izvori preglednika. Njihovi Web Lockovi se
ne koordiniraju, iako operacijski sustav i dalje sprječava da obje stranice
istodobno posjeduju isti serijski port.

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


WebUSB ne može otvoriti ili preuzeti ULX3S
------------------------------------------

Na Linuxu Hazard3-Doom alat može otkriti ULX3S, ali ga ipak ne uspjeti otvoriti.

Dvije su uobičajene pogreške:

``Access denied``
   Preglednik nema dopuštenje čitanja/pisanja za sirovi USB uređaj.

``Unable to claim interface``
   Linux upravljački program ``ftdi_sio`` već posjeduje FT231X USB sučelje.

Pogledajte :doc:`user-guide/web-flasher` za Linux udev postavke dopuštenja i
postupak privremenog oslobađanja ULX3S sučelja od ``ftdi_sio``.

Ako koristite virtualni stroj, provjerite i da je ULX3S USB uređaj spojen na
gostujući operacijski sustav, a ne na host.

Doom upload istječe
-------------------

* Izađite iz Dooma pomoću ``Ctrl-X`` kako bi rezidentni monitor slušao.
* Zatvorite PuTTY ili drugi program koji koristi UART port.
* Potvrdite odabrani COM/TTY uređaj.
* Potvrdite da monitor i uploader koriste isti memorijski profil.
* Na zadanom kvalificiranom ULX4M-LD profilu Hazard3 sistemski takt je 40 MHz,
  a UART se i dalje
  očekuje na 115200 bauda. Ako programirana slika istječe na 115200, ali odgovara
  oko 92160 bauda, to je snažan dijagnostički znak da je UART djelitelj monitora
  izračunat uz pretpostavku takta od 50 MHz dok FPGA zapravo radi na 40 MHz
  (``115200 * 40 / 50 = 92160``). Ponovno izgradite cijeli cilj s
  ``./scripts/build-ulx4m-ld-doom.sh``, ponovno programirajte bitstream i testirajte
  na 115200; 92160 koristite samo kao dijagnostički baud.
* Neki WSL ``/dev/ttyS*`` serijski mostovi odbijaju nestandardni dijagnostički
  baud 92160 uz ``termios.error: (5, 'Input/output error')``. Ako je taj test
  potreban, pokrenite uploader s Windows Pythonom preko odgovarajućeg COM porta,
  primjerice iz WSL-a:

  .. code-block:: bash

     cmd.exe /c "py doom/upload-doom-image.py build/ulx4m-ld/doom-image/hazard3-doom.h3img --port COM8 --baud 92160"
* Ako cilj dosegne ``H3L READY`` pa prijavi ``H3L ERROR invalid header``, UART
  handshake radi. Provjerite jesu li rezidentni monitor i ``.h3img`` nastali iz
  međusobno kompatibilnog builda/profila prije promjene serijskih drivera ili
  ožičenja.

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

* Koristite nazive u korijenu ``DOOM.IMG`` i ``DOOM.WAD``.
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


``shellcheck`` nije instaliran
------------------------------

ShellCheck je neobavezan razvojni alat za provjeru shell skripti u repozitoriju.
Nije potreban za uobičajene Hazard3-Doom izgradnje. Na Ubuntu/WSL sustavima
razvojni korisnici koji žele pokretati provjeru shell skripti mogu ga instalirati
ovako:

.. code-block:: bash

   sudo apt-get install shellcheck

Za širu provjeru hosta pokrenite ``./scripts/requirements-check.sh``.

RISC-V GCC lanac alata nije pronađen
------------------------------------

Izgradnja uobičajeno koristi kompatibilni RISC-V bare-metal prevoditelj dostupan
u ``PATH``. Alati ``riscv-none-elf-*`` izravno su podržani, dok
``TOOLCHAIN_PREFIX`` može odabrati drugu instalaciju ili prefiks prevoditelja.
Povijesna lokacija ``/opt/riscv/bin/riscv32-unknown-elf-*`` ostaje podržana samo
kao kompatibilna rezervna mogućnost. Primjerice, xPack instalacija često koristi:

.. code-block:: bash

   TOOLCHAIN_PREFIX=riscv-none-elf- ./scripts/build.sh

Pokrenite ``./scripts/requirements-check.sh`` kako biste otkrili uobičajene
prefikse RISC-V lanca alata i provjerili prihvaća li prevoditelj Hazard3 ISA/ABI
opcije.

``c++: fatal error: Killed signal terminated program cc1plus``
--------------------------------------------------------------

To gotovo uvijek znači da je Ubuntu VM ostao bez dostupnog RAM-a pa je kernelov
OOM killer prekinuo jedan od procesa C++ prevoditelja. To nije C++ pogreška
prevođenja. Povećajte memoriju ili swap VM-a ili smanjite paralelizam izgradnje
prije ponovnog pokušaja.

Workflow prijavljuje da je CMake prestar
----------------------------------------

Provjera zahtjeva računala tretira CMake kao neobavezan razvojni alat. Ako
određeni workflow zahtijeva noviju verziju, instalirajte ili nadogradite CMake na
verziju koju taj workflow traži, zatim provjerite s ``cmake --version``.

Za instalaciju CMakea 3.25 ili novijeg pogledajte skriptu ``install-cmake.sh`` u
direktoriju ``scripts/``.

``ROR: Max frequency for clock '$glbnet$clk_sys': XX.YY MHz (FAIL at 50 MHz)``
------------------------------------------------------------------------------

Ako je routana frekvencija ispod cilja pri korištenju zadanih seedova, najprije
potvrdite da Yosys i nextpnr odgovaraju verzijama zabilježenima uz mjerodavne
zadane postavke routinga u ``scripts/build-ecp5-bitstream-common.sh``. Routing
seedovi ovise o verziji alata.

Zabilježite lokalne verzije ovako:

.. code-block:: text

   yosys --version
   nextpnr-ecp5 --version
   ecppack --version

Uploader firmwarea konzole ostaje na ``Loading...``
----------------------------------------------------

Browser console uploader ne pokreće OpenOCD. Tri dijela surađuju:

.. code-block:: text

   browser stranica -> loopback web-server.py -> GDB -> OpenOCD :3333 -> Hazard3

Stranica može biti javni GitHub Pages Device Tool ili lokalna stranica koju
poslužuje ``web-server.py``. GDB i OpenOCD uvijek ostaju lokalni.

Pokrenite OpenOCD u jednom terminalu:

.. code-block:: bash

   ./scripts/start-openocd.sh

Upotrebljiva sesija dosegne ``Examined RISC-V core`` i ``Listening on port
3333 for gdb connections``. U drugom terminalu pokrenite:

.. code-block:: bash

   python3 web/web-server.py

Helper pri pokretanju upozorava ako listener nije pronađen na
``127.0.0.1:3333``. To je samo upozorenje jer se OpenOCD može pokrenuti kasnije.

Nastavite s ``https://ulx3s.github.io/Hazard3-Doom/`` ili otvorite
``http://127.0.0.1:8000/``. Nemojte koristiti ``file://`` za potpuni Device
Tool. Panel odvojeno prikazuje **Local loader** i **OpenOCD**; **refresh** odmah
ponavlja provjeru.

Status zahtjev nosi promjenjivu ``challenge`` vrijednost kako cacheirani
``Ready`` odgovor ne bi preživio zaustavljanje helpera. OpenOCD provjera je
pasivna: pregledava lokalne listenere umjesto otvaranja TCP veze na ``3333``.

Ako OpenOCD svakih nekoliko sekundi prikazuje prihvaćene ili odbijene GDB veze
dok se ELF ne učitava, vjerojatno još radi stari ``web-server.py`` s aktivnim
TCP probeom. Zaustavite ga i pokrenite trenutačni helper.

Tijekom stvarnog učitavanja jedna prihvaćena GDB veza koja se na kraju zatvori
je očekivana.

Korisne provjere:

.. code-block:: bash

   ss -ltnp | grep ':3333'
   curl http://127.0.0.1:8000/api/console-firmware/status

Prije OpenOCD-a odspojite i browser FPGA WebUSB flasher s ``US1`` jer oba
koriste isti FT231X JTAG. Vanjski J1 USB-UART neovisan je i može ostati spojen.

Ako H3IMG/H3W kasnije istekne čekajući ``READY``, prvo provjerite radi li
rezidentni monitor na ``>`` promptu. Ako helper odgovara, ali OpenOCD nije
prisutan, Device Tool dodatno podsjeća da monitor možda još treba učitati.


Zatim možete nastaviti s:

.. code-block:: text

   https://ulx3s.github.io/Hazard3-Doom/

ili otvoriti lokalnu kopiju na ``http://127.0.0.1:8000/``. Za cijeli alat nemojte
koristiti ``file://`` URL.

Ispravna provjera zdravlja pasivna je i zato **ne** smije stalno stvarati OpenOCD
poruke poput:

.. code-block:: text

   accepting 'gdb' connection on tcp/3333
   attempted 'gdb' connection rejected

Korisne JTAG provjere:

* Na ULX4M-LD s Tigardom držite Interface 0 na FTDI VCP driveru za UART, a Interface 1 na libusbK za JTAG. OpenOCD koristi ``ftdi channel 1``.
* Na ULX4M-LD ispravan LFE5UM-85F IDCODE je ``0x01113043``. Ako OpenOCD očita taj IDCODE, ali prijavi ``dtmcontrol is 0``, fizički JTAG put radi; provjerite je li korisnički bitstream izašao iz DFU-a i stvarno se izvršava prije promjene DTM RTL-a ili ožičenja.

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


ULX4M-LD prijavljuje ``TIMEOUT`` vanjske memorije
-------------------------------------------------

Početno čekanje trenutačnog monitora od 5 sekundi može isteći prije nego LiteDRAM
završi kalibraciju. Sama poruka ``TIMEOUT`` nije konačan dokaz kvara. Pokrenite
``s`` i provjerite trenutačno stanje. Upotrebljivo DDR stanje uključuje:

.. code-block:: text

   external_memory_ready=YES
   init_done=YES
   init_error=NO
   pll_locked=YES
   user_clock_ready=YES
   ready=YES

Ako su ta polja spremna, pokrenite ``q``. Kvalificirani ULX4M-LD routing 40/60
MHz više je puta prošao cijeli SDRAM skup testova, kao i ``k``, ``d`` i ``x``.

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

Povezane poveznice
------------------

* `RISC-V GCC XPACK <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_
