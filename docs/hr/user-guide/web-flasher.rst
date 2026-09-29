FPGA WebUSB flasher
===================

Hazard3-Doom uključuje preglednički programator ULX3S FPGA-a u aplikaciji
``web/``. Programira ECP5 FPGA izravno preko ULX3S ``US1`` FT231X JTAG sučelja
koristeći WebUSB.

Za pregled cijelog web alata i ostalih putova prijenosa pogledajte
:doc:`web-tool`.

Flasher je odvojen od UART konzole:

.. code-block:: text

   Browser
     |
     +-- Web Serial --> UART adapter --> Hazard3 monitor / Doom console
     |
     +-- WebUSB -----> ULX3S US1 FT231X --> ECP5 JTAG --> FPGA SRAM

Trenutačna implementacija programira **samo FPGA SRAM**. Odabrana slika pokreće
se odmah nakon programiranja, ali je nestabilna i gubi se kada pločica ostane
bez napajanja. Preglednički flasher ne briše niti ponovno zapisuje ULX3S SPI
konfiguracijski flash.

Zbog toga je web flasher prikladan za ispitivanje novog Hazard3-Doom bitstreama
prije razmatranja trajnog ažuriranja flasha.

.. _fig-webusb-flasher:

.. figure:: ../images/Flash-from-WebUSB.png
   :alt: Hazard3-Doom FPGA web flasher programira ULX3S ECP5 sliku putem WebUSB-a.
   :class: screenshot

   FPGA web flasher koristi WebUSB za ULX3S JTAG, dok ostatak stranice zadržava
   postojeću Web Serial konzolu.

Zahtjevi
--------

Koristite aktualan preglednik temeljen na Chromiumu, poput Chromea ili Edgea.
WebUSB zahtijeva siguran kontekst, pa koristite hostanu HTTPS stranicu ili
stranicu posluženu s ``localhost`` adrese.

Javna stranica može izravno programirati FPGA:

.. code-block:: text

   https://ulx3s.github.io/Hazard3-Doom/

Odabrani ``.bit``/``.svf`` podaci ostaju u pregledniku i preko WebUSB-a se
izravno šalju lokalnom FT231X-u. Za programiranje FPGA SRAM-a nije potreban
lokalni web server.

Za lokalni razvoj pokrenite jednostavan poslužitelj iz direktorija ``web/`` u
repozitoriju:

.. code-block:: bash

   cd web
   python3 -m http.server 8000

Zatim otvorite:

.. code-block:: text

   http://localhost:8000/

Preglednik komunicira izravno s odabranim USB uređajem. FPGA slika i JTAG
podaci ne prenose se na web-poslužitelj.


USB postavljanje ovisno o hostu
-------------------------------

WebUSB postupak programiranja isti je nakon što preglednik može otvoriti i
preuzeti ULX3S FT231X sučelje, ali postavljanje operacijskog sustava razlikuje se:

.. list-table::
   :header-rows: 1
   :widths: 20 80

   * - Host
     - WebUSB postavljanje
   * - Windows
     - Povežite ULX3S FT231X koji koristi ``US1`` s WinUSB upravljačkim programom.
       Zadig je jedan praktičan način. Uobičajeni FTDI VCP/D2XX upravljački
       program nije kompatibilan s ovim WebUSB putem preglednika.
   * - Linux
     - Osigurajte da korisnik može otvoriti sirovi USB uređaj, uobičajeno udev
       pravilom. Ako ``ftdi_sio`` posjeduje ULX3S FT231X sučelje, oslobodite samo
       to sučelje dok ga WebUSB koristi.
   * - macOS
     - Nemojte instalirati Windows WinUSB/Zadig postavke ni Linux udev pravila.
       Koristite aktualan preglednik temeljen na Chromiumu, zatvorite aplikacije
       koje možda već posjeduju FT231X i ponovno spojite ``US1`` ako je sučelje
       zauzeto.

Vlasništvo WebUSB-a i OpenOCD-a
-------------------------------

Browser FPGA flasher i OpenOCD koriste isti ULX3S ``US1`` FT231X JTAG put. Mogu
koristiti isti WinUSB binding, ali ne mogu istodobno posjedovati FT231X.

Nakon uspješnog SRAM programiranja pritisnite **Disconnect** u flasheru prije
pokretanja OpenOCD-a. Ako OpenOCD već radi, zaustavite ga prije spajanja
browser flashera. Vanjski USB-UART koji koristi Web Serial neovisan je i može
ostati spojen tijekom primopredaje.

Onemogućene JTAG kontrole imaju hover tekst koji objašnjava nedostajući
preduvjet, primjerice potrebu za ULX3S USB vezom prije **Probe JTAG**.

Kompatibilnost Windows USB upravljačkih programa
------------------------------------------------

ULX3S priključak ``US1`` izlaže ugrađeni FT231X koji se koristi za JTAG. Na
Windowsu upravljački program povezan s tim FT231X-om određuje koji ga USB alati
na računalu mogu otvoriti. To je odvojeno od vanjskog USB-na-UART adaptera koji
koristi Hazard3-Doom Web Serial konzola.

Tablica u nastavku bilježi kombinacije koje koristi trenutačni Hazard3-Doom
ULX3S tijek rada. ``OpenOCD`` se odnosi na izgradnju s ``ft232r`` adapter
driverom i libusb Windows backendom, poput xPack izgradnje koju ovaj projekt
koristi.

.. raw:: html

    <table class="compat-table">
        <thead>
            <tr>       <th>Alat / put</th>                                                               <th>WinUSB</th>                                  <th>FTDI VCP/D2XX</th>                                                             <th>libusbK</th></tr>
        </thead>
        <tbody>
            <tr><td>OpenOCD (ULX3S FT231X JTAG)</td>           <td><span class="compat-dot compat-yes"> </span>Radi</td> <td><span class="compat-dot compat-no">  </span>Ne</td>                   <td><span class="compat-dot compat-yes"> </span>Radi</td></tr>
            <tr><td>GDB preko OpenOCD-a</td>                   <td><span class="compat-dot compat-yes"> </span>Radi</td> <td><span class="compat-dot compat-no">  </span>Nema OpenOCD transporta</td> <td><span class="compat-dot compat-yes"> </span>Radi</td></tr>
            <tr><td>Hazard3-Doom WebUSB FPGA/JTAG flasher</td> <td><span class="compat-dot compat-yes"> </span>Radi</td> <td><span class="compat-dot compat-no">  </span>Ne</td>                   <td><span class="compat-dot compat-no">  </span>Ne</td></tr>
            <tr><td>Windows fujprog / FTDI D2XX alati</td>     <td><span class="compat-dot compat-no">  </span>Ne</td>    <td><span class="compat-dot compat-yes"> </span>Radi</td>                <td><span class="compat-dot compat-no">  </span>Ne</td></tr>
            <tr><td>Hazard3-Doom Web Serial UART (vanjski
                    CH340/CH341, CP210x, FTDI UART itd.)</td> <td><span class="compat-dot compat-na">  </span>N/P</td>   <td><span class="compat-dot compat-na">  </span>N/P</td>                  <td><span class="compat-dot compat-na">  </span>N/P</td></tr>
            <tr><td>PuTTY / uobičajeni COM-port UART
                    na vanjskom adapteru</td>               <td><span class="compat-dot compat-na">  </span>N/P</td>   <td><span class="compat-dot compat-na">  </span>N/P</td>                  <td><span class="compat-dot compat-na">  </span>N/P</td></tr>
        </tbody>
    </table>

Za razvoj Hazard3-Dooma **WinUSB je najpraktičniji binding ULX3S FT231X-a kada
su potrebni i pregledničko WebUSB programiranje i OpenOCD/GDB**. Trenutačni
OpenOCD ``ft232r`` put potvrđeno radi s WinUSB-om; libusbK ostaje valjana opcija
za OpenOCD, ali nije prikladan za preglednički WebUSB flasher.

Uobičajeni FTDI VCP/D2XX driver i dalje je potreban za Windows ``fujprog`` i
druge aplikacije koje izravno koriste vlasnički FTDI driver/API. Promjena
bindinga FT231X-a ne resetira već konfigurirani FPGA.

Tipična pogreška WebUSB upravljačkog programa je:

.. code-block:: text

   ERROR: Failed to execute 'open' on 'USBDevice': Access denied.

Flasher prepoznaje slučaj odbijenog pristupa na Windowsu i bilježi savjet za
WinUSB driver umjesto da ga tretira kao JTAG pogrešku.

.. _fig-webusb-access-denied:

.. figure:: ../images/WebUSB-USBDevice-Access-Denied.png
   :alt: Hazard3-Doom WebUSB flasher prikazuje USBDevice Access denied prije instalacije WinUSB-a.
   :class: screenshot

   ``USBDevice.open()`` access denied nastaje prije početka JTAG-a. Na Windowsu
   provjerite binding FT231X upravljačkog programa prije istraživanja FPGA-a ili
   JTAG ožičenja.

Jedan način odabira WinUSB-a jest Zadig:

#. Povežite ULX3S USB priključak ``US1``.
#. Zatvorite ``fujprog``, OpenOCD, ``openFPGALoader`` i druge programe koji možda
   već koriste FT231X.
#. Pokrenite Zadig i po potrebi uključite **Options -> List All Devices**.
#. Odaberite ULX3S FTDI uređaj. Prije zamjene bilo kojeg drivera potvrdite da je
   odabrani uređaj namijenjeno ULX3S sučelje.
#. Odaberite **WinUSB** kao zamjenski driver i instalirajte ga.
#. Odspojite i ponovno spojite ``US1`` prije povratka u preglednik.

.. _fig-zadig-ftdi-winusb:

.. figure:: ../images/Zadig-FTDI-to-WinUSB.png
   :alt: Zadig podešen za zamjenu ULX3S FTDI upravljačkog programa WinUSB-om.
   :class: screenshot

   Primjer Zadig odabira za ULX3S FT231X. Provjerite odabrani uređaj prije
   zamjene njegova upravljačkog programa.

.. warning::

   Promjena bindinga FT231X-a mijenja koji Windows USB API može preuzeti sučelje.
   Softver koji izričito očekuje FTDI VCP/D2XX prestat će raditi na tom sučelju
   dok se FTDI driver ne vrati. To **ne** sprječava zaseban vanjski USB-na-UART
   adapter da nastavi pružati Hazard3-Doom Web Serial konzolu.

Da biste ``US1`` vratili na uobičajeni FTDI driver, u Windows Device Manageru
vratite upravljački program ULX3S USB uređaja na instalirani FTDI driver ili
ponovno instalirajte odgovarajući FTDI VCP/D2XX paket.

.. _fig-windows-restore-ftdi-driver:

.. figure:: ../images/Windows-set-default-USB-from-WinUSB.png
   :alt: Naredba Update driver u Windows Device Manageru za ULX3S uređaj koji koristi WinUSB.
   :class: screenshot

   Device Manager može vratiti uobičajeni FTDI driver kada je potrebna FTDI
   VCP/D2XX aplikacija poput Windows ``fujprog``.


Linux i Ubuntu USB pristup
--------------------------

Na Linuxu preglednik mora imati izravan pristup ULX3S USB uređaju kako bi mogao
koristiti WebUSB sučelje za programiranje FPGA-a.

To je osobito važno kada Ubuntu radi u virtualnom stroju. Primjerice, u VMware
Workstationu najprije provjerite da je ULX3S USB uređaj spojen na gostujući
sustav, a ne na Windows host.

ULX3S FTDI uređaj uobičajeno izgleda ovako::

   0403:6015 Future Technology Devices International, Ltd Bridge(I2C/SPI/UART/FIFO)

Potvrdite da ga Ubuntu vidi:

.. code-block:: console

   $ lsusb -d 0403:6015
   Bus 001 Device 004: ID 0403:6015 Future Technology Devices International, Ltd Bridge(I2C/SPI/UART/FIFO)

Brojevi sabirnice i uređaja razlikovat će se.

WebUSB ``Access denied``
~~~~~~~~~~~~~~~~~~~~~~~~

Ako alat prijavi pogrešku sličnu ovoj::

   Failed to execute 'open' on 'USBDevice': Access denied.

preglednik vidi ULX3S, ali prijavljeni korisnik nema dovoljna dopuštenja za
otvaranje sirovog USB uređaja.

U gornjem primjeru ``Bus 001 Device 004`` odgovara putu:

.. code-block:: text

   /dev/bus/usb/001/004

Provjerite dopuštenja:

.. code-block:: console

   $ ls -l /dev/bus/usb/001/004
   $ getfacl /dev/bus/usb/001/004

Tipična neispravna konfiguracija izgleda ovako::

   crw-rw-r-- 1 root root ... /dev/bus/usb/001/004

U tom slučaju običan korisnik ima samo pravo čitanja.

Za privremeni dijagnostički test dopustite čitanje/pisanje:

.. code-block:: console

   $ sudo chmod 0666 /dev/bus/usb/001/004

Zatim ponovno pokušajte ``Connect ULX3S USB``.

.. warning::

   Gornja ``chmod`` naredba služi samo kao dijagnostički test. Promjena
   dopuštenja gubi se kada se USB uređaj odspoji ili ponovno enumerira.

Za trajni pristup izradite udev pravilo:

.. code-block:: console

   $ sudo tee /etc/udev/rules.d/70-ulx3s-webusb.rules >/dev/null <<'EOF'
   SUBSYSTEM=="usb", ATTR{idVendor}=="0403", ATTR{idProduct}=="6015", TAG+="uaccess"
   EOF

Ponovno učitajte udev pravila:

.. code-block:: console

   $ sudo udevadm control --reload-rules

Zatim odspojite i ponovno spojite ULX3S USB uređaj. Nakon ponovnog spajanja
ponovno pokrenite ``lsusb`` jer se broj uređaja mogao promijeniti.

WebUSB ``Unable to claim interface``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Drugi problem specifičan za Linux može se pojaviti nakon što su USB dopuštenja
ispravljena. Alat može prijaviti::

   Could not claim the ULX3S FT231X interface:
   Failed to execute 'claimInterface' on 'USBDevice':
   Unable to claim interface.

To obično znači da je Linux kernel upravljački program ``ftdi_sio`` već preuzeo
FTDI sučelje.

Provjerite dodjele USB upravljačkih programa:

.. code-block:: console

   $ lsusb -t

Sukobljeno ULX3S sučelje izgleda slično ovome::

   Dev 004, If 0, Class=Vendor Specific Class, Driver=ftdi_sio, 12M

Preglednik ne može preuzeti sučelje dok ga posjeduje ``ftdi_sio``. Odredite naziv
FTDI sučelja:

.. code-block:: console

   $ ls -l /sys/bus/usb/drivers/ftdi_sio/

Primjerice, ULX3S sučelje može izgledati kao::

   1-2.1:1.0

Točan naziv ovisi o USB topologiji računala ili virtualnog stroja.

Privremeno oslobodite samo to sučelje od ``ftdi_sio``:

.. code-block:: console

   $ echo '1-2.1:1.0' | sudo tee /sys/bus/usb/drivers/ftdi_sio/unbind

Zamijenite ``1-2.1:1.0`` nazivom s vašeg sustava. Provjerite rezultat:

.. code-block:: console

   $ lsusb -t

ULX3S sučelje više ne bi trebalo prikazivati ``Driver=ftdi_sio``. Bez odspajanja
ULX3S-a vratite se u alat i ponovno odaberite ``Connect ULX3S USB``.

Nakon korištenja WebUSB-a
~~~~~~~~~~~~~~~~~~~~~~~~~

FTDI sučelje možete vratiti uobičajenom Linux serijskom upravljačkom programu:

.. code-block:: console

   $ echo '1-2.1:1.0' | sudo tee /sys/bus/usb/drivers/ftdi_sio/bind

Ponovno zamijenite ``1-2.1:1.0`` nazivom sa svog sustava.

.. note::

   Uobičajeno nemojte uklanjati cijeli kernel modul ``ftdi_sio``. Oslobađanje
   samo ULX3S sučelja izbjegava ometanje drugih FTDI USB uređaja.

   Također izbjegavajte automatsko oslobađanje svakog ``0403:6015`` uređaja udev
   pravilom osim ako je računalo namijenjeno isključivo WebUSB programiranju.
   Inače Linux ne može koristiti normalno FTDI serijsko sučelje dok je upravljački
   program odspojen.

Ubuntu virtualni strojevi
~~~~~~~~~~~~~~~~~~~~~~~~~

U VMware Workstationu oba sloja moraju biti ispravna:

#. ULX3S USB uređaj mora biti spojen na Ubuntu gosta, a ne na host.
#. Ubuntu mora dopustiti pregledniku otvaranje sirovog USB uređaja.
#. ``ftdi_sio`` ne smije posjedovati FTDI sučelje dok ga koristi WebUSB.

Ako ``lsusb`` ne prikazuje ``0403:6015``, prvo riješite USB vezu virtualnog
stroja. Promjene preglednika ili udeva neće pomoći dok uređaj nije vidljiv u
gostujućem sustavu.

.. _web-flasher-macos-usb:

macOS USB pristup
-----------------

macOS ne koristi Windows Zadig/WinUSB postupak niti Linux udev pravila. Počnite s
uobičajenim WebUSB zahtjevima: aktualnim preglednikom temeljenim na Chromiumu i
hostanim HTTPS alatom ili ``localhost``.

Prije odabira **Connect ULX3S USB** zatvorite ``fujprog``, OpenOCD,
``openFPGALoader``, serijske terminale i drugi softver koji možda već posjeduje
ULX3S FT231X sučelje. Ako preglednik prijavi pogrešku pristupa ili preuzimanja
sučelja, odspojite i ponovno spojite ``US1`` te pokušajte ponovno prije promjene
sistemskog softvera.

Vanjski USB-UART adapter koji koristi Hazard3-Doom Web Serial konzola odvojen je
od ULX3S ``US1`` JTAG sučelja i može ostati spojen.

.. note::

   Indikator hosta u alatu temelji se na informacijama o platformi koje prijavi
   preglednik. Ako prikazuje **Unknown**, koristite odjeljak za operacijski sustav
   koji odgovara stvarnom hostu.

Programiranje ``.bit`` datoteke
-------------------------------

Uobičajeni Hazard3-Doom tijek prihvaća ECP5 ``.bit`` datoteku koju FPGA
izgradnja izravno proizvede. Nije potreban ručni korak pretvorbe.

Za standardnu ULX3S izgradnju slika je obično:

.. code-block:: text

   build/fpga_ulx3s_85f.bit

Za programiranje:

#. Izgradite ili nabavite bitstream za namijenjenu ULX3S FPGA inačicu.
#. Otvorite Hazard3-Doom web-aplikaciju i proširite **FPGA web flasher**.
#. Odaberite ``.bit`` datoteku.
#. Kliknite **Connect ULX3S USB** i odaberite ULX3S FTDI uređaj spojen na
   ``US1``.
#. Kliknite **Probe JTAG**.
#. Potvrdite da je otkriveni ECP5 očekivani FPGA.
#. Kliknite **Program FPGA SRAM**.
#. Pričekajte da pokazivač napretka i zapis flashera prijave uspješan završetak.

Uspješna sesija na 85F sadrži poruke slične ovima:

.. code-block:: text

   INFO: Converted fpga_ulx3s_85f.bit to the Project Trellis ECP5 SRAM SVF sequence for LFE5U-85F.
   INFO: Loaded fpga_ulx3s_85f.bit: 1,018 programming commands.
   INFO: Connected to ULX3S FPGA ...
   OK: JTAG probe found LFE5U-85F (0x41113043).
   INFO: Programming fpga_ulx3s_85f.bit into LFE5U-85F FPGA SRAM...
   OK: Programming stream completed successfully in ... s (1,018 commands).

Nakon uspješne konfiguracije SRAM-a, novo programirana FPGA slika pokreće se
odmah. Ako slika sadrži uobičajeni Hazard3-Doom sustav, rezidentni monitor i
Doom tijek mogu se zatim normalno nastaviti.

Identifikacija cilja i sigurnosne provjere
------------------------------------------

Preglednik prije programiranja ispituje fizički ECP5 JTAG ID. Trenutačni flasher
prepoznaje:

.. list-table::
   :header-rows: 1
   :widths: 35 35

   * - FPGA
     - JTAG IDCODE
   * - LFE5U-12F
     - ``0x21111043``
   * - LFE5U-25F
     - ``0x41111043``
   * - LFE5U-45F
     - ``0x41112043``
   * - LFE5U-85F
     - ``0x41113043``

Za ``.bit`` datoteku preglednik također izvlači ECP5 ciljni ID ugrađen u
bitstream. Neposredno prije programiranja ponovno ispituje pločicu i odbija
nastaviti ako se cilj bitstreama i fizički FPGA ne podudaraju.

Ova se provjera namjerno temelji na ECP5 JTAG ID-u, a ne na FT231X USB product
stringu. Opis u EEPROM-u FT231X-a može identificirati pločicu, primjerice kao
``ULX3S FPGA 12K``, čak i kada fizički ECP5 JTAG ID prijavi 85F. Za odluke o
programiranju mjerodavan je JTAG ID.

Kako radi programiranje ``.bit`` datoteke
-----------------------------------------

Project Trellis uobičajeno pruža ``tools/bit_to_svf.py`` za pretvorbu ECP5
bitstreama u JTAG Serial Vector Format (SVF) slijed potreban za konfiguraciju
SRAM-a. Hazard3-Doom tu pretvorbu izvodi u pregledniku kako bi korisnici mogli
izravno odabrati izlaz iz izgradnje.

Pretvorba u pregledniku uključuje:

* izvlačenje ECP5 IDCODE-a iz bitstreama;
* Project Trellis ECP5 početni slijed konfiguracije;
* obrtanje bitova koje zahtijeva SVF/JTAG prikaz;
* programske ``SDR`` blokove od najviše 8000 bitova;
* ECP5 operacije stanja i provjere; i
* završni slijed koji pokreće konfiguriranu FPGA sliku.

Generirani tok zatim izvršava JTAG stroj stanja u pregledniku preko sinkronog
bit-bang sučelja FT231X-a.

Unaprijed generirane SVF datoteke
---------------------------------

Flasher također prihvaća ``.svf`` datoteku. To je korisno za ispitivanje,
interoperabilnost ili usporedbu ponašanja preglednika s drugim JTAG alatima.

Project Trellis može generirati ekvivalentan ECP5 SRAM programski tok pomoću:

.. code-block:: bash

   python3 /path/to/prjtrellis/tools/bit_to_svf.py \
       build/fpga_ulx3s_85f.bit \
       build/fpga_ulx3s_85f.svf

Preglednik implementira SVF operacije potrebne za uobičajeni Project Trellis
slijed programiranja ECP5 SRAM-a. Nepodržane naredbe zaustavljaju programiranje
uz izričitu pogrešku umjesto da budu tiho zanemarene.

JTAG transport
--------------

WebUSB programator prati ULX3S FT231X sinkrono bit-bang mapiranje koje koristi
``fujprog``:

.. code-block:: text

   TCK  0x20
   TMS  0x40
   TDI  0x80
   TDO  0x08

Transport koristi sinkroni bit-bang način FT231X-a. Implementacija uzima u obzir
FTDI prijamni pipeline pri uzorkovanju TDO-a; to je važno jer pogreška uzorkovanja
od jednog ciklusa pomiče vraćeni ECP5 IDCODE.

Preglednik također provodi SVF ``TDO``/``MASK`` usporedbe tijekom programiranja.
Neuspjela usporedba zaustavlja tok i prijavljuje se u zapisu flashera.

Kontrole zapisa flashera
------------------------

FPGA flasher ima vlastiti zapis, neovisan o UART terminalu.

* **Auto-scroll** zadano prati nove programske poruke. Isključite opciju kako
  biste pregledali raniji izlaz dok programiranje traje.
* **Copy log** kopira cijeli trenutačni zapis flashera u međuspremnik.
* **Clear log** uklanja prikazanu povijest flashera bez odspajanja USB-a,
  resetiranja napretka ili prekidanja aktivne JTAG operacije programiranja.
* Područje zapisa ima okomitu kliznu traku i može se mijenjati po visini.

Otklanjanje poteškoća
---------------------

``USBDevice.open(): Access denied``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Na Windowsu to obično znači da FT231X još koristi FTDI VCP/D2XX driver umjesto
WinUSB-a ili da drugi proces već posjeduje USB sučelje. Instalirajte/odaberite
WinUSB za namijenjeni ULX3S FT231X, odspojite/ponovno spojite ``US1`` i pokušajte
ponovno. Ako je WinUSB već instaliran, najprije zatvorite druge USB/JTAG programe.

Pogledajte :ref:`webusb-access-denied` za sažeti postupak otklanjanja poteškoća.

Neprepoznat ili pomaknut JTAG ID
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ispravno ispitivanje treba vratiti jedan od poznatih ECP5 IDCODE-ova iz gornje
tablice. Ako vraćena vrijednost nije prepoznata:

* odspojite drugi JTAG softver;
* odspojite/ponovno spojite ``US1``;
* ponovno povežite preglednik i ponovite ispitivanje; i
* potvrdite da se poslužuje trenutačni ``web/flasher.js``, a ne zastarjela kopija
  iz predmemorije preglednika.

Nemojte programirati sliku kada se fizički JTAG cilj ne može identificirati.

Nepodudaranje cilja bitstreama
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ako preglednik prijavi da pločica i slika ciljaju različite ECP5 uređaje, nemojte
zaobilaziti provjeru. Ponovno izgradite ili odaberite bitstream namijenjen
fizičkoj pločici.

Programiranje završava i nova slika se pokreće
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

To je očekivani rezultat. Programiranje FPGA SRAM-a je nestabilno, pa ciklus
napajanja vraća FPGA na konfiguraciju pohranjenu u trajnom SPI flashu.

Trajna konfiguracija
--------------------

WebUSB flasher namjerno **ne** zapisuje trajni SPI flash. Trajno ažuriranje ima
veći trošak oporavka od privremenog SRAM učitavanja i treba ostati zaseban,
izričito potvrđen tijek rada.

Pogledajte :doc:`../getting-started/programming` za razliku između privremenog
učitavanja FPGA-a i trajne konfiguracije pokretanja.
Vanjske reference
-----------------

* `ULX3S priručnik <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_
* `fujprog <https://github.com/kost/fujprog>`_
* `Project Trellis <https://github.com/YosysHQ/prjtrellis>`_
* `WebUSB API <https://developer.mozilla.org/en-US/docs/Web/API/WebUSB_API>`_

* `openFPGALoader <https://trabucayre.github.io/openFPGALoader/guide/install.html>`_
