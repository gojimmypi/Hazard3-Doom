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

Pregled prijenosnih putova
--------------------------

Web alat koristi tri neovisna puta:

.. code-block:: text

   Preglednik
     |
     +-- Web Serial --> USB-UART --> rezidentni monitor / Doom
     |                  |             |
     |                  |             +-- H3L .h3d prijenos
     |                  |             +-- H3W .wad prijenos
     |                  |             +-- terminal / naredbe / screen snip
     |
     +-- WebUSB ------> ULX3S US1 FT231X --> ECP5 JTAG --> FPGA SRAM
     |
     +-- localhost ---> web-server.py --> GDB --> OpenOCD --> Hazard3 debug
                         samo firmware konzole

Web Serial i WebUSB komuniciraju izravno između preglednika i uređaja koje
korisnik odabere u dijalozima dopuštenja. Učitavanje firmwarea konzole je
iznimka: ono zahtijeva lokalni ``web-server.py`` jer statična web-stranica ne
može pokretati lokalne GDB/OpenOCD alate.

Zahtjevi preglednika
--------------------

Koristite aktualni preglednik temeljen na Chromiumu, primjerice Chrome ili
Edge. Web Serial i WebUSB zahtijevaju siguran kontekst. ``localhost`` je
prihvatljiv za lokalni rad, a HTTPS za hostanu kopiju poput GitHub Pagesa.

Za puni alat, uključujući uploader firmwarea konzole, pokrenite projektni
server iz korijena repozitorija:

.. code-block:: bash

   python3 web/web-server.py

Zatim otvorite:

.. code-block:: text

   http://127.0.0.1:8000/

``http://localhost:8000/`` je ekvivalent kada lokalni server koristi zadani
loopback binding.

.. warning::

   Nemojte dvokliknuti ``web/index.html`` niti ga otvarati s ``file://`` URL-om
   kada je potreban uploader firmwarea konzole. Stranica se može prikazati kao
   lokalna datoteka, ali iza nje nema HTTP API-ja, pa će lokalni GDB/OpenOCD
   loader biti prijavljen kao nedostupan. Adresna traka preglednika treba
   prikazivati ``http://127.0.0.1:8000/`` (ili ``localhost:8000``).

Ako uploader firmwarea konzole nije potreban, dovoljan je običan statični
server:

.. code-block:: bash

   cd web
   python3 -m http.server 8000

Sa statičnim serverom ili GitHub Pagesom i dalje rade UART terminal, H3D i IWAD
uploaderi, screen snip i FPGA WebUSB flasher. **Console firmware uploader** tada
prikazuje da lokalni loader nije dostupan.

Serijska veza
-------------

Proširite **Serial connection** i odaberite UART uređaj. Uobičajene
Hazard3-Doom postavke su:

.. code-block:: text

   115200 baud
   8 podatkovnih bitova
   bez pariteta
   1 stop bit
   bez kontrole toka

Završetak retka postavlja se zasebno. ``CR + LF`` je uobičajena interaktivna
postavka.

**Connect** otvara preglednikov izbornik serijskih uređaja. **Reconnect** otvara
odabrani port među portovima za koje je stranica već dobila dopuštenje. Serijski
port može istodobno koristiti samo jedna aplikacija, pa prije povezivanja
zatvorite PuTTY, drugi tab preglednika ili naredbeni uploader.

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
debug modul. Ne traži od aktivnog monitora da zamijeni sam sebe. Postupak je:

#. preglednik provjeri 32-bitni little-endian RISC-V ELF;
#. ``web-server.py`` preda ga lokalnom loaderu projekta;
#. GDB se spoji na OpenOCD, zaustavi Hazard3, upiše i provjeri ELF sekcije,
   postavi programsko brojilo, nastavi procesor i prekine vezu.

Najprije pokrenite odgovarajuću OpenOCD konfiguraciju i ostavite GDB server na
portu ``3333``. Nemojte ostaviti browser FPGA flasher spojen na ``US1`` dok
OpenOCD koristi isto FT231X JTAG sučelje.

Stanje **Local loader Ready** potvrđuje da preglednik može pristupiti
``web-server.py``; ono ne zamjenjuje niti pokreće OpenOCD. OpenOCD je zaseban,
dugotrajan proces koji je već morao prepoznati Hazard3 jezgru. Provjerite izlaz
sličan ovome:

.. code-block:: text

   Examined RISC-V core; found 1 harts
   Listening on port 3333 for gdb connections

Vanjski J1 USB-UART adapter koji koristi Web Serial neovisan je o ``US1`` FT231X
JTAG sučelju, pa UART konzola može ostati spojena dok OpenOCD radi.

Ovaj uploader radi samo preko lokalnog ``web/web-server.py``. Onemogućen je kada
se stranica poslužuje kao statični sadržaj.

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

**Screen snip** može preko UART-a dohvatiti podržani HDMI prikaz i u pregledniku
rekonstruirati sliku ``1024x600``. Pogledajte :doc:`web-serial` za capability
pregovaranje, protokol, rekonstrukciju i firmware detalje.

Preporučeni slijed za pokretanje
--------------------------------

Za tipičnu ULX3S razvojnu sesiju:

#. Pokrenite ``python3 web/web-server.py`` i otvorite
   ``http://127.0.0.1:8000/`` ako bi moglo trebati učitavanje firmwarea konzole.
#. Po potrebi otvorite **Device uploading -> FPGA web flasher** i programirajte
   odgovarajući ``.bit`` u FPGA SRAM.
#. Nakon programiranja **odspojite FPGA web flasher s US1**. OpenOCD i
   preglednikov WebUSB ne mogu istodobno koristiti FT231X JTAG sučelje.
#. U zasebnom terminalu pokrenite ``./scripts/start-openocd.sh`` i pričekajte
   poruke ``Examined RISC-V core`` i ``Listening on port 3333``.
#. Otvorite **Serial connection**, odaberite vanjski UART pločice i spojite se s
   ``115200 8N1``. UART može ostati spojen dok OpenOCD radi.
#. Po potrebi upotrijebite **Console firmware uploader** za učitavanje
   odgovarajućeg ``hazard3-boot-monitor.elf`` kroz već pokrenuti OpenOCD server.
#. Provjerite da je nova poruka monitora čitljiva i da prompt ``>`` odgovara na
   ``h`` ili ``?``.
#. Prenesite zapakiranu Doom ``.h3d`` sliku.
#. Prenesite zakonito pribavljen IWAD s memorijskim profilom monitora.
#. Pokrenite s ``j`` iz opcije u uploaderu ili terminala.

Na pločici bez umetnute micro-SD kartice monitor najprije može prijaviti pogrešku
inicijalizacije poput ``CMD0 failed r1=0x000000FF`` prije prikaza prompta ``>``.
To je očekivano kada kartica nije prisutna; nije kvar UART-a, SDRAM-a ili
OpenOCD-a.

Naredbeni upload skripti i dalje su korisni za automatizaciju i dijagnostiku;
web uploaderi koriste iste H3L/H3W protokole monitora.

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
     - localhost + GDB/OpenOCD
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
