Web alat za uređaj
==================

Hazard3-Doom u direktoriju ``web/`` sadrži web alat za uređaj koji u jednoj
stranici objedinjuje uobičajene postupke pokretanja i rada s pločicom. Time za
većinu interaktivnog rada nisu potrebni zaseban terminal i više naredbenih
alata za prijenos.

Trenutačna stranica ima četiri glavna područja:

* **Device uploading** - programiranje FPGA SRAM-a, učitavanje firmwarea
  konzole, prijenos Doom H3D slike i prijenos Doom IWAD-a;
* **Serial connection** - odabir Web Serial porta i UART postavke;
* **UART terminal** - izlaz monitora/Dooma, unos naredbi, zapis i HDMI snimka;
* **Hazard3-Doom controls** - brze naredbe za monitor, SAO i I2CDriver.

Paneli **Device uploading** i **Serial connection** mogu se sklopiti. Svaki
pojedini uploader unutar **Device uploading** također je sklopiv kako bi
terminal tijekom normalnog rada zadržao većinu prostora preglednika.

Glavne radnje ostaju u zaglavljima odjeljaka, cijela stranica normalno se
pomiče, a logovi flashera/firmwarea mogu se okomito promijeniti po visini. Kratki
hover opisi pojašnjavaju transport, radnju dostupnog gumba ili razlog zbog kojeg
je gumb onemogućen.

Pregled prijenosnih putova
--------------------------

Web alat koristi tri neovisna puta:

.. code-block:: text

   Stranica preglednika (localhost ili HTTPS/GitHub Pages)
     |
     +-- Web Serial --> USB-UART --> rezidentni monitor / Doom
     |                  |             |
     |                  |             +-- H3L .h3d prijenos
     |                  |             +-- H3W .wad prijenos
     |                  |             +-- terminal / naredbe / screen snip
     |
     +-- WebUSB ------> ULX3S US1 FT231X --> ECP5 JTAG --> FPGA SRAM
     |
     +-- loopback HTTP --> web-server.py --> GDB --> OpenOCD --> Hazard3 debug
                           127.0.0.1:8000             :3333
                           samo firmware konzole

Web Serial i WebUSB izravno komuniciraju s uređajima koje korisnik odabere u
dijalozima dopuštenja. Uploader firmwarea konzole razlikuje se: preglednik ne
može izravno pokrenuti GDB ili OpenOCD, pa preko loopback HTTP-a poziva lokalni
``web-server.py`` helper.

Sama stranica ne mora biti poslužena iz ``web-server.py``. Javna HTTPS stranica
može koristiti helper na istom računalu, dok GDB i OpenOCD ostaju lokalni.

Zahtjevi preglednika
--------------------

Koristite aktualni preglednik temeljen na Chromiumu, primjerice Chrome ili
Edge. Web Serial i WebUSB zahtijevaju siguran kontekst. ``localhost`` je
prihvatljiv lokalno, a HTTPS za hostani alat.

Javna stranica dostupna je na:

.. code-block:: text

   https://ulx3s.github.io/Hazard3-Doom/

UART terminal, H3D/IWAD prijenos, screen snip i WebUSB programiranje FPGA-a ne
zahtijevaju lokalni web server.

Učitavanje firmwarea konzole dodatno zahtijeva lokalni helper. Iz korijena
repozitorija pokrenite:

.. code-block:: bash

   python3 web/web-server.py

Helper sluša samo na loopbacku, zadano ``127.0.0.1:8000``. Nakon pokretanja
možete nastaviti koristiti GitHub Pages ili otvoriti
``http://127.0.0.1:8000/``. Preglednik može zatražiti dopuštenje za lokalnu
mrežu/loopback; dopustite ga ako je potreban console loader.

Helper prihvaća samo izričito dopuštene browser origine. Druga razvojna origina
može se dodati, primjerice:

.. code-block:: bash

   python3 web/web-server.py --allow-origin http://127.0.0.1:9000

Wildcard ``*`` namjerno nije dopušten.

Neobavezni pristupni ključ
~~~~~~~~~~~~~~~~~~~~~~~~~~

Za dodatnu zaštitu:

.. code-block:: bash

   python3 web/web-server.py --access-key

Helper traži ključ bez prikaza. Isti ključ unesite u **Console firmware
uploader**. Preglednik ga drži samo u memoriji stranice, ne u ``localStorage``.
Ključ na naredbenom retku je podržan, ali je manje poželjan jer ga mogu otkriti
shell history ili popis procesa.

Ključ je dodatna zaštita: helper i dalje sluša samo na loopbacku, provjerava
točan ``Origin`` i zahtijeva očekivana zaglavlja lokalnog loadera.

.. warning::

   Za potpuni Device Tool nemojte otvarati ``web/index.html`` preko ``file://``
   URL-a. Koristite HTTPS ili localhost kako bi Web Serial, WebUSB i loopback API
   imali odgovarajući sigurnosni kontekst.

Provjera zdravlja helpera
~~~~~~~~~~~~~~~~~~~~~~~~~

**Console firmware uploader** periodički provjerava helper i nudi **refresh**.
Svaki zahtjev nosi novu ``challenge`` vrijednost koju helper vraća, pa stari
cacheirani odgovor ``Ready`` ne može prikazati zaustavljeni helper kao živ.

Zato su normalne log linije poput:

.. code-block:: text

   GET /api/console-firmware/status?challenge=... HTTP/1.1

Nakon prvog stanja **Ready** stranica ga nastavlja provjeravati. Ako se
``web-server.py`` zaustavi, status se vraća na nedostupno bez reloada.

Serijska veza
-------------

Proširite **Serial connection** i odaberite UART uređaj. Uobičajene postavke su:

.. code-block:: text

   115200 baud
   8 podatkovnih bitova
   bez pariteta
   1 stop bit
   bez kontrole toka

Završetak retka postavlja se zasebno; ``CR + LF`` je uobičajena interaktivna
postavka.

**Connect** otvara browser picker. **Reconnect** otvara već autorizirani port i
onemogućen je dok je UART već spojen; hover tekst objašnjava razlog.

Serijski port može imati samo jednog vlasnika. Device Tool koristi Web Lock i
``BroadcastChannel`` između tabova iste origine, pa drugi tab može prijaviti
**UART already in use** ako prvi već drži port. Druga origina, PuTTY ili druga
aplikacija ne mogu se imenovati, ali se neuspjeli ``open()`` prikazuje kao
vjerojatan konflikt vlasništva porta.

``http://127.0.0.1:8000`` i ``https://ulx3s.github.io`` različite su
origine, pa ne dijele taj lock. Operacijski sustav ipak sprječava da obje
stranice istodobno otvore isti serijski port.

H3D i IWAD odjeljci također jasno prikazuju UART preduvjet i, kada UART nije
spojen, nude vlastiti **Connect UART**.

Učitavanje i programiranje
--------------------------

Proširite **Device uploading** za četiri odvojena postupka. Odvojeni su jer
koriste različite transporte i imaju različita pravila trajnosti.

FPGA web flasher
~~~~~~~~~~~~~~~~

**FPGA web flasher** prihvaća ULX3S ECP5 ``.bit`` ili kompatibilni ``.svf`` te
programira FPGA **SRAM** preko FT231X JTAG sučelja ``US1`` koristeći WebUSB.

Preglednik očitava fizički ECP5 JTAG ID, a za ``.bit`` provjerava odgovara li
cilj bitstreama fizičkom FPGA-u. Slika se pokreće odmah, ali se gubi nakon
isključivanja napajanja. Ova kontrola namjerno ne zapisuje trajni SPI flash.

Na Windowsu ULX3S FT231X koji koristi WebUSB mora imati WinUSB upravljački
program. To je odvojeno od vanjskog USB-UART adaptera za Web Serial.

Pogledajte :doc:`web-flasher` za ciljne ID-ove, kompatibilnost upravljačkih
programa, JTAG postupak i otklanjanje poteškoća.

Uploader firmwarea konzole
~~~~~~~~~~~~~~~~~~~~~~~~~~

**Console firmware uploader** učitava ``hazard3-boot-monitor.elf`` kroz Hazard3
debug modul. Aktivni monitor ne mijenja sam sebe:

#. preglednik provjeri 32-bitni little-endian RISC-V ELF;
#. pošalje ELF loopback helperu ``web-server.py``;
#. helper pozove lokalni firmware loader;
#. GDB se spoji na OpenOCD, zaustavi Hazard3, upiše i provjeri ELF sekcije,
   postavi programsko brojilo, nastavi procesor i prekine vezu.

Najprije pokrenite odgovarajuću OpenOCD konfiguraciju i ostavite GDB server na
portu ``3333``. Odspojite browser FPGA flasher s ``US1`` jer preglednik i
OpenOCD ne mogu istodobno posjedovati isti FT231X JTAG.

Panel odvojeno prikazuje:

* **Local loader** - može li preglednik dohvatiti ``web-server.py``;
* **OpenOCD** - postoji li lokalni listener na ``127.0.0.1:3333``.

OpenOCD provjera je **pasivna**: helper pregledava tablicu lokalnih listenera
umjesto da otvara TCP vezu prema portu ``3333``. Time ne troši GDB connection
slot niti ometa stvarno učitavanje.

Pri pokretanju ``web-server.py`` prikazuje stanje spremnosti ili upozorenje ako
GDB server nije pronađen. Stranica periodički osvježava isto stanje; ako OpenOCD
nije prisutan, gumb za učitavanje ostaje onemogućen uz hover objašnjenje.

Upotrebljiva OpenOCD sesija sadrži, primjerice:

.. code-block:: text

   Examined RISC-V core; found 1 harts
   Listening on port 3333 for gdb connections

Vanjski J1 USB-UART za Web Serial neovisan je o ``US1`` FT231X JTAG putu, pa
UART može ostati spojen.

Console uploader radi i s lokalne stranice i s javne HTTPS stranice. U oba
slučaja GDB i OpenOCD ostaju lokalni.

Doom H3D uploader
~~~~~~~~~~~~~~~~~

**Doom H3D uploader** šalje zapakiranu ``.h3d`` sliku preko iste Web Serial veze
koju koristi terminal. Rezidentni monitor mora biti na svom ``>`` promptu.

Prije prijenosa preglednik provjerava H3D zaglavlje, duljinu paketa i CRC32
payload-a, a zatim koristi H3L protokol monitora:

.. code-block:: text

   preglednik -> l
   monitor    -> H3L READY
   preglednik -> 64-bajtno H3D zaglavlje
   monitor    -> H3L DATA
   preglednik -> H3D payload
   monitor    -> H3L OK

Prijenos mijenja samo SDRAM; ne mijenja SD karticu. Opcija **Launch with ``j``
after upload** može pokrenuti sliku nakon što je monitor prihvati.

Ako Doom već radi, prvo upotrijebite **Stop Doom** i pričekajte da se vrati
monitorov ``>`` prompt.

Ako prijenos istekne čekajući ``H3L READY``, alat sada prikazuje istaknuti
dijagnostički tekst. Najprije provjerite radi li rezidentni monitor na ``>``
promptu. Ako je lokalni helper dostupan, ali OpenOCD nije, alat dodatno sugerira
da monitor možda još treba učitati. OpenOCD ne mora ostati pokrenut nakon što je
monitor učitan.

Doom IWAD uploader
~~~~~~~~~~~~~~~~~~

**Doom IWAD uploader** preko Web Serial veze šalje zakonito pribavljen Doom
IWAD. Hazard3-Doom ne distribuira komercijalni IWAD sadržaj.

Preglednik provjerava oznaku ``IWAD``, granice direktorija i svih lumpova, naziv
vidljiv Doomu, veličinu rezerviranog SDRAM-a i CRC32. Prijenos koristi H3W:

.. code-block:: text

   preglednik -> w
   monitor    -> H3W READY
   preglednik -> 64-bajtno H3W zaglavlje
   monitor    -> H3W DATA
   preglednik -> IWAD bajtovi
   monitor    -> H3W OK

Odaberite memorijski profil koji odgovara buildu rezidentnog monitora:

.. list-table::
   :header-rows: 1
   :widths: 20 30 50

   * - Profil
     - IWAD adresa učitavanja
     - Trenutačna uporaba
   * - ``64m``
     - ``0x22c00000``
     - ULX3S i ULX4M-LD
   * - ``32m``
     - ``0x21000000``
     - ULX4M-LS

Profil je bitan jer H3W zaglavlje sadrži odredišnu SDRAM adresu; pogrešan profil
nije samo UI postavka.

Kao i kod H3D-a, **Launch with ``j`` after upload** šalje ``j`` tek nakon
``H3W OK``.

H3W timeout dijagnostika koristi isti savjet za rezidentni monitor i OpenOCD kao
H3D uploader.

Vlasništvo UART-a tijekom binarnog prijenosa
--------------------------------------------

H3D i IWAD payload-i su binarni UART prijenosi. Tijekom prijenosa web aplikacija
privremeno zaustavlja obične kontrole naredbi i screen-snip capability probeove
kako dodatni bajt ne bi završio u payload-u. Normalan terminal nastavlja rad
nakon završetka ili pogreške.

UART terminal i kontrole
------------------------

UART terminal prikazuje izlaz uživo, povijest naredbi, RX/TX brojače, trajanje
sesije, lokalni echo, automatsko pomicanje, kopiranje/spremanje loga i unos
naredbi monitora.

Panel **Hazard3-Doom controls** daje gumbe za česte naredbe monitora i SAO/I2C
operacije. Sirove jednobajtne kontrole ne dodaju odabrani završetak retka.

Gumb **Help** namjerno šalje jedan sirovi bajt ``h`` bez završetka retka; ne šalje
riječ ``help``. Hover tekst je također ovisan o stanju: onemogućeni gumb
objašnjava koji preduvjet nedostaje, a omogućeni opisuje radnju.

**Screen snip** može preko UART-a dohvatiti podržani HDMI prikaz i u pregledniku
rekonstruirati sliku ``1024x600``. Pogledajte :doc:`web-serial` za capability
pregovaranje, protokol, rekonstrukciju i firmware detalje.

Preporučeni slijed za pokretanje
--------------------------------

Za tipičnu ULX3S razvojnu sesiju:

#. Otvorite ``https://ulx3s.github.io/Hazard3-Doom/`` ili lokalnu stranicu.
#. Po potrebi programirajte odgovarajući ``.bit`` preko **FPGA web flasher**.
#. Nakon programiranja **odspojite flasher s US1**. WebUSB i OpenOCD ne mogu
   istodobno posjedovati FT231X JTAG.
#. Ako bi moglo trebati učitavanje console firmwarea, u jednom terminalu
   pokrenite ``python3 web/web-server.py``. Javna stranica može koristiti taj
   loopback helper bez ponovnog otvaranja s localhosta.
#. U drugom terminalu pokrenite ``./scripts/start-openocd.sh`` i pričekajte
   ``Examined RISC-V core`` te ``Listening on port 3333``. OpenOCD status u
   Device Toolu trebao bi automatski postati **Ready**; **refresh** pokreće
   trenutačnu provjeru.
#. U **Serial connection** odaberite vanjski UART i spojite se s ``115200 8N1``.
   UART može ostati spojen dok OpenOCD radi.
#. Po potrebi učitajte ``hazard3-boot-monitor.elf`` kroz **Console firmware
   uploader**.
#. Provjerite banner monitora i da ``>`` prompt odgovara na jednobajtni gumb
   **Help**.
#. Prenesite Doom ``.h3d`` sliku.
#. Prenesite zakonito pribavljeni IWAD s odgovarajućim memorijskim profilom.
#. Pokrenite s ``j`` iz uploadera ili terminala.

Bez micro-SD kartice monitor može prvo prijaviti ``CMD0 failed
r1=0x000000FF`` prije ``>`` prompta. To je očekivano i nije kvar UART-a, SDRAM-a
ili OpenOCD-a.

Naredbeni upload skripti ostaju korisni za automatizaciju i dijagnostiku; web
uploaderi koriste iste H3L/H3W protokole.

Granice podataka i trajnosti
----------------------------

.. list-table::
   :header-rows: 1
   :widths: 30 35 35

   * - Operacija
     - Transport
     - Trajno nakon gašenja?
   * - FPGA web flasher
     - WebUSB / JTAG
     - Ne; samo FPGA SRAM
   * - Console firmware uploader
     - loopback HTTP + GDB/OpenOCD
     - Ne; učitano u aktivni FPGA sustav
   * - H3D uploader
     - Web Serial / H3L
     - Ne; samo SDRAM
   * - IWAD uploader
     - Web Serial / H3W
     - Ne; samo SDRAM

Za samostalni boot i trajnu FPGA konfiguraciju pogledajte
:doc:`../getting-started/programming` i :doc:`sd-card`.

Povezana dokumentacija
----------------------

* :doc:`web-serial` - detaljna Web Serial konzola i HDMI screen-snip protokol.
* :doc:`web-flasher` - detaljni ULX3S WebUSB/JTAG vodič.
* :doc:`monitor` - naredbe i loaderi rezidentnog monitora.
* :doc:`doom` - Doom slika i rad programa.
* :doc:`sd-card` - samostalno H3D/IWAD učitavanje s micro-SD kartice.
* :doc:`jtag-debugging` - OpenOCD/GDB postavljanje.
