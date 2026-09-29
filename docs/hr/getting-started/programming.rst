Programiranje i trajno pokretanje
=================================

Postoje dva različita cilja programiranja:

Na Windowsu pokrenite korake naredbenog retka na ovoj stranici iz
**WSL/Ubuntu Basha**, osim ako je izričito navedeno drukčije. Preglednik i
postavljanje Windows USB upravljačkih programa i dalje se odvijaju na Windows
strani; pokretanje priloženog Windows ``.exe`` iz WSL-a ne čini PowerShell ili
``cmd.exe`` projektnom build ljuskom.

Privremeno učitavanje FPGA-a
----------------------------

Uobičajena naredba za nestabilno programiranje FPGA-a idealna je pri ispitivanju novog bitstreama. Odmah konfigurira ECP5, ali se konfiguracija gubi kada se ukloni napajanje.

Za ULX3S, preglednički :doc:`../user-guide/web-flasher` može izvršiti ovo
privremeno učitavanje izravno iz datoteke ``.bit`` ili kompatibilne ``.svf``
datoteke putem ``US1``. Preglednik ispituje fizički ECP5 JTAG ID, provjerava da
``.bit`` datoteka cilja istu FPGA inačicu, izvršava Project Trellis slijed za
programiranje SRAM-a i odmah pokreće novu sliku.

WebUSB flasher ne mijenja trajni SPI flash. Na Windowsu izravan pristup FT231X-u
zahtijeva upravljački program WinUSB. Isti WinUSB binding potvrđeno radi i s
projektnim ULX3S OpenOCD/GDB putem, pa tijek rada za otklanjanje pogrešaka sam po
sebi ne zahtijeva prebacivanje na libusbK. Prije promjene USB bindinga pogledajte
matricu kompatibilnosti upravljačkih programa u vodiču za flasher.

Trajna FPGA konfiguracija
-------------------------

Za samostalnu instalaciju upišite provjereni FPGA bitstream u konfiguracijski SPI flash na ULX3S-u. Pri sljedećem uključivanju ECP5 se sam konfigurira iz flash memorije.

Predviđeni samostalni slijed jest:

#. ECP5 se konfigurira iz SPI flasha.
#. Block RAM se inicijalizira slikom rezidentnog Hazard3 monitora.
#. Hazard3 se pokreće bez računala domaćina.
#. Monitor inicijalizira SDRAM i micro-SD sučelje.
#. ``DOOM.IMG`` i ``DOOM.WAD`` čitaju se sa SD kartice.
#. Doom se pokreće na HDMI-ju.

ULX4M-LD: privremeno učitavanje FPGA-a
--------------------------------------

Kada je Tigard spojen na ULX4M-LD JTAG, ``openFPGALoader`` može novu ECP5
konfiguraciju učitati izravno u SRAM bez zamjene trajne korisničke slike:

.. code-block:: bash

   ./bin/openFPGALoader.exe \
       -c tigard \
       ./build/fpga_ulx4m_ld.bit

Ovo je privremeno učitavanje. Isključivanje napajanja ili ponovna konfiguracija
FPGA-a uklanja ga, pa je prikladno za provjeru kandidata prije trajnog upisa.

ULX4M-LD: trajno DFU programiranje
----------------------------------

ULX4M-LD koristi svoj Micro-B USB DFU bootloader za pohranu trajnog korisničkog
bitstreama u SPI flash. Ta korisnička slika ostaje sačuvana nakon isključivanja
napajanja. Windows DFU uređaj obično vidi kao VID:PID ``1d50:614b`` uz WinUSB.
Ta USB veza odvojena je od vanjskog Tigard JTAG/UART adaptera.

.. important::

   Uobičajeno Hazard3-Doom programiranje ažurira **korisnički bitstream**, a ne
   sam DFU bootloader. Zamjena bootloadera vrlo je neuobičajena i treba biti
   rezervirana za razvoj bootloadera ili oporavak nedostajućeg/oštećenog
   bootloadera. Za taj odvojeni postupak i oporavak pogledajte
   :doc:`../user-guide/bootloader`.

Za ulazak u provjereni DFU način oporavka/programiranja:

#. Isključite napajanje.
#. Držite PCB ``BTN3`` (neke verzije pločice mogu koristiti druge tipke!).
#. Spojite ULX4M Micro-B USB kabel.
#. Pričekajte da se enumerira VID:PID ``1d50:614b``, zatim otpustite ``BTN3``.

``BTN3`` je potreban samo za odabir DFU-a pri pokretanju; ne treba ga držati
tijekom prijenosa. Kada priložene Windows izvršne datoteke pokrećete izravno iz
WSL-a, upotrijebite ``chmod +x ./bin/openFPGALoader.exe ./bin/dfu-util.exe`` ako
Bash prijavi ``Permission denied``.

Provjerena naredba za programiranje je:

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

DFU alternativna postavka 0 područje je korisničkog bitstreama; ULX4M bootloader
čuva vlastito zaštićeno područje ispod regije korisničke slike. Tijekom početnog
puštanja u rad ispravno zapisana slika nije se počela izvršavati dok bootloaderu
nije izričito naređeno da napusti DFU. Upotrijebite:

.. code-block:: bash

   ./bin/dfu-util.exe -a 0 -e

Ova naredba ``-e`` ne preuzima niti briše FPGA podatke. Ona traži prijelaz
bootloadera koji pokreće već pohranjenu korisničku sliku. Provjerena sekvenca dala
je UART izlaz odmah nakon ``-e``.

Ta je razlika važna pri dijagnostici. Ako je ECP5 IDCODE vidljiv preko Tigarda,
ali UART šuti i OpenOCD prijavljuje ``dtmcontrol is 0``, provjerite je li pločica
još u DFU-u prije mijenjanja JTAG ožičenja ili Hazard3 RTL-a. Pogledajte
:doc:`../user-guide/jtag-debugging`.

Trajno hladno pokretanje zaseban je korak kvalifikacije od „DFU zapis + odmah
izvrši”. Najprije provjerite kandidata pomoću ``dfu-util -a 0 -e`` i DDR testova
kvalifikacije, a zatim normalno ponašanje pločice nakon uključivanja napajanja.
Sam uspješan DFU prijenos nije dokaz da je hladno pokretanje kvalificirano.

ULX4M-LD kvalificirana kontrolna slika
--------------------------------------

Trenutačno hardverski kvalificirana razvojna kontrolna točka je seed-2 routing s
Hazard3 na 40 MHz i LiteDRAM na 60 MHz, dokumentiran u
:doc:`../reference/board-profiles`. SHA256 lokalno testiranog bitstreama bio je:

.. code-block:: text

   294602982dfc4a9906961f2e8b6f43de925d8c11a7e5e6bb0f5e392965a868de

Nakon programiranja i izlaska iz DFU-a upotrijebite ``s`` u monitoru kako biste
potvrdili da je LiteDRAM spreman, zatim pokrenite ``q`` prije nego novu generiranu
sliku smatrate DDR-kvalificiranom zamjenom.

.. warning::

   Provjerite bitstream prije nego ga postavite kao uobičajenu samostalnu sliku.
   Za ULX4M-LD to uključuje i statički timing i stvarne DDR testove; sam nextpnr
   PASS nije dovoljan.

Za sadržaj SD kartice i dijagnostiku pokretanja pogledajte
:doc:`../user-guide/sd-card`.

Reference implementacije
------------------------

* :doc:`../user-guide/bootloader`
* :doc:`../reference/board-profiles`

* `openFPGALoader <https://trabucayre.github.io/openFPGALoader/guide/install.html>`_
