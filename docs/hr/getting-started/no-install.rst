Pokretanje bez instalacije - ULX3S
==================================

Najbrži način za isprobati Hazard3-Doom na ULX3S pločici jest koristiti
unaprijed izgrađene datoteke projekta i Device Tool u pregledniku. Za ovaj put
nije potrebno klonirati repozitorij niti instalirati Yosys, nextpnr, RISC-V
prevoditelj, Python skripte za prijenos, OpenOCD ili GDB.

Ova stranica privremeno programira FPGA, prenosi Doom u SDRAM i pokreće ga.
Postupak ne mijenja ULX3S SPI flash, pa se FPGA slika gubi nakon isključivanja
napajanja.

.. note::

   Potreban je noviji preglednik temeljen na Chromiumu, primjerice Chrome ili
   Edge. Na Windowsu ULX3S ``US1`` FT231X možda treba koristiti WinUSB upravljački
   program kako bi mu WebUSB mogao pristupiti. To je podešavanje USB upravljačkog
   programa, a ne instalacija FPGA ili RISC-V razvojnog alata. Pogledajte
   :doc:`../user-guide/web-flasher`.

Što je potrebno
---------------

* ULX3S 85F ili ULX3S 12F pločica;
* HDMI zaslon;
* ULX3S ``US1`` USB veza za WebUSB programiranje FPGA-a;
* vanjski USB-UART adapter spojen na Hazard3-Doom UART;
* odgovarajuće unaprijed izgrađene ``.bit`` i ``.h3img`` datoteke;
* legalno nabavljen Doom IWAD, primjerice ``DOOM.WAD`` ili ``DOOM1.WAD``.

Za UART veze pogledajte :doc:`../user-guide/pinouts`, a za potpuni opis alata
:doc:`../user-guide/web-tool`.

1. Preuzmite unaprijed izgrađene datoteke
-----------------------------------------

Direktorij ``bin/`` u repozitoriju preporučeni je izvor objavljenih unaprijed
izgrađenih slika:

`Pregledajte Hazard3-Doom bin direktorij <https://github.com/ulx3s/Hazard3-Doom/tree/main/bin>`_

Koristite ``bin/INVENTORY.md`` i pripadajući popis kontrolnih suma kako biste
provjerili namjenu objavljenih datoteka:

`Prikaži bin/INVENTORY.md <https://github.com/ulx3s/Hazard3-Doom/blob/main/bin/INVENTORY.md>`_

Odaberite par koji odgovara FPGA-u na pločici:

.. list-table::
   :header-rows: 1
   :widths: 18 39 43

   * - Pločica
     - FPGA slika
     - Doom H3IMG slika
   * - ULX3S 85F
     - ``fpga_ulx3s_85f_hdmi_doom.bit``
     - ``hazard3-doom-ulx3s-85F.h3img``
   * - ULX3S 12F
     - ``fpga_ulx3s_12f_hdmi_doom.bit``
     - ``hazard3-doom-ulx3s-12F.h3img``

Nemojte miješati datoteke različitih profila pločica. Programator u pregledniku
provjerava fizički ECP5 JTAG ID i odbija ``.bit`` datoteku čiji ugrađeni cilj ne
odgovara otkrivenom FPGA-u.

.. _fig-no-install-bin-prebuilt-files:

.. figure:: ../images/no-install-bin-prebuilt-files.png
   :alt: GitHub bin direktorij projekta Hazard3-Doom s unaprijed izgrađenim ULX3S datotekama.
   :width: 85%
   :class: screenshot

   Objavljene unaprijed izgrađene ULX3S datoteke u direktoriju ``bin/``
   repozitorija, zajedno s ``INVENTORY.md`` za identifikaciju i provjeru.

Nedavni GitHub Actions buildovi
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

GitHub Actions tijek **Board integration builds** drugi je izvor izlaza nedavnih
uspješnih buildova:

`Otvori Board integration builds <https://github.com/ulx3s/Hazard3-Doom/actions/workflows/fpga-builds.yml>`_

Otvorite uspješno izvođenje i preuzmite artifact za točan profil pločice koji
želite ispitati. Workflow artifacti korisni su za testiranje nedavnog CI builda,
ali nisu trajno mjesto za preuzimanje: imaju razdoblje zadržavanja i nestaju kada
artifact ili pripadajuće izvođenje istekne ili bude obrisano. Objavljene datoteke
u ``bin/`` zato su jednostavniji izbor za prvo pokretanje.

.. _fig-no-install-actions-artifacts:

.. figure:: ../images/no-install-actions-artifacts.png
   :alt: GitHub Actions stranica Board integration builds s dostupnim ULX3S artifactima za preuzimanje.
   :width: 85%
   :class: screenshot

   Workflow Board integration builds može također pružiti nedavne ULX3S build
   artifacte za testiranje.

2. Otvorite Device Tool
-----------------------

Otvorite hostanu aplikaciju:

`Hazard3-Doom Device Tool <https://ulx3s.github.io/Hazard3-Doom/>`_

Za ovaj put bez instalacije sve potrebne radnje izvode se izravno u pregledniku.
``web-server.py``, OpenOCD i GDB nisu potrebni. Oni su potrebni samo za dodatni
workflow učitavanja i otklanjanja pogrešaka ELF firmwarea konzole.

3. Programirajte FPGA SRAM
--------------------------

Spojite ULX3S ``US1`` USB priključak, zatim u Device Toolu:

#. Otvorite **Device uploading**.
#. Otvorite **FPGA web flasher**.
#. Odaberite odgovarajuću ``.bit`` datoteku.
#. Odaberite **Connect ULX3S USB** i ULX3S FTDI uređaj.
#. Odaberite **Probe JTAG** i potvrdite da je otkriven očekivani FPGA.
#. Odaberite **Program FPGA SRAM**.
#. Pričekajte poruku o uspješnom završetku u zapisniku programatora.

FPGA konfiguracija je privremena. Isključivanje i ponovno uključivanje pločice
vraća uobičajenu trajnu konfiguraciju.

.. _fig-no-install-web-flasher:

.. figure:: ../images/no-install-web-flasher.png
   :alt: Hazard3-Doom FPGA WebUSB programator s odabranom ULX3S bitstream datotekom i otkrivenim FPGA-om.
   :width: 85%
   :class: screenshot

   Programator FPGA-a u pregledniku nakon JTAG provjere i odabira odgovarajuće
   ULX3S ``.bit`` datoteke.

4. Spojite UART
---------------

Hazard3-Doom koristi ULX3S ``J1`` GPIO konektor za vanjski UART. Koristite 3,3 V
USB-UART adapter i ukrstite TX/RX signale:

.. code-block:: text

   USB-UART TXD  ->  J1 pin 6  / GP0 / B11 -> Hazard3 uart_rx
   USB-UART RXD  <-  J1 pin 8  / GP1 / A10 <- Hazard3 uart_tx
   USB-UART GND  ->  ULX3S GND
   USB-UART VCC  ->  nije spojeno

.. _fig-ulx3s-uart-pinout:

.. figure:: ../images/ulx3s-uart-pinout.png
   :alt: ULX3S pinout s istaknutim Hazard3-Doom UART-om na GP0 i GP1 konektora J1.
   :width: 85%

   **ULX3S Hazard3-Doom UART** -- GP0 je FPGA ulaz za prijam, a GP1 FPGA izlaz
   za slanje.

Otvorite **Serial connection** i spojite se sa standardnim Hazard3-Doom
postavkama:

.. code-block:: text

   115200 baud
   8 data bits
   no parity
   1 stop bit
   no flow control

Rezidentni monitor već je ugrađen u uobičajenu Hazard3-Doom FPGA sliku.
Uspješno pokretanje prikazuje banner monitora i odzivnik ``>``. Za ovaj postupak
nije potrebno učitati ``hazard3-boot-monitor.elf``.

Ako se odzivnik ne pojavi, prije nastavka pogledajte :doc:`../troubleshooting` i
:doc:`../user-guide/web-serial`.

5. Prenesite Doom H3IMG sliku
-----------------------------

U **Device uploading** otvorite **Doom H3IMG uploader**:

#. Odaberite odgovarajuću ``hazard3-doom-*.h3img`` datoteku.
#. Odaberite **Upload H3IMG**.
#. Pričekajte da monitor prihvati sliku.

H3IMG slika mora odgovarati istom profilu pločice kao i ``.bit`` datoteka.

.. _fig-no-install-h3img-upload:

.. figure:: ../images/no-install-h3img-upload.png
   :alt: Hazard3-Doom H3IMG alat za prijenos s odabranom slikom Doom specifičnom za pločicu.
   :width: 85%
   :class: screenshot

   Prijenos slike ``hazard3-doom-*.h3img`` koja odgovara profilu pločice putem
   Device Toola.

6. Prenesite svoj Doom IWAD
---------------------------

Otvorite **Doom IWAD uploader** i odaberite legalno nabavljenu ``.wad`` datoteku.
Odaberite memorijski profil koji odgovara rezidentnom monitoru:

.. list-table::
   :header-rows: 1
   :widths: 45 25

   * - Pločica
     - Memorijski profil
   * - ULX3S 85F
     - ``64m``
   * - ULX3S 12F
     - ``32m``

Odaberite **Upload IWAD**. Za automatsko pokretanje Dooma nakon prijenosa prije
uploada uključite **Launch with ``j`` after upload**.

Projekt ne distribuira komercijalni Doom IWAD. Morate sami osigurati legalno
nabavljeni IWAD.

.. _fig-no-install-iwad-upload:

.. figure:: ../images/no-install-iwad-upload.png
   :alt: Hazard3-Doom IWAD alat za prijenos s odabranom WAD datotekom i uključenim automatskim pokretanjem.
   :width: 85%
   :class: screenshot

   Prijenos Doom IWAD-a s ispravnim memorijskim profilom monitora i opcionalnim
   automatskim pokretanjem.

7. Provjerite pokretanje Dooma
------------------------------

Uspješan prijenos i pokretanje uključuju poruke slične ovima:

.. code-block:: text

   H3L READY
   H3L DATA
   H3L OK
   H3W READY
   H3W DATA
   H3W OK
   Doom SDRAM image startup
   monitor ABI: PASS
   Doom interactive HDMI loop: READY

Doom bi sada trebao biti vidljiv preko HDMI-a, a terminal preglednika može
ostati spojen za naredbe monitora i dijagnostiku.

.. _fig-no-install-doom-running:

.. figure:: ../images/no-install-doom-running.png
   :alt: Doom pokrenut na ULX3S HDMI zaslonu dok je Hazard3-Doom alat u pregledniku i dalje povezan.
   :width: 85%
   :class: screenshot

   Doom u radu nakon uspješnog FPGA programiranja te prijenosa H3IMG i IWAD
   datoteka.

Što ovaj put ne instalira
-------------------------

Ovaj brzi postupak namjerno izbjegava razvojno okruženje. Ne instalira niti
zahtijeva Yosys, nextpnr, Project Trellis, RISC-V GCC alatni lanac, Hazard3-Doom
checkout i podmodule, naredbene skripte za prijenos ili OpenOCD/GDB za uobičajeni
put monitor/H3IMG/IWAD.

Kada želite ponovno izgraditi ili mijenjati FPGA, firmware monitora ili Doom
sliku, nastavite s :doc:`quick-start` i :doc:`build`.

ULX4M-LD
--------

Unaprijed izgrađene ULX4M-LD slike također uklanjaju potrebu za lokalnim FPGA
buildom, ali trenutačni put programiranja još koristi DFU alate na računalu. Zato
nije jednak ULX3S postupku samo u pregledniku opisanom na ovoj stranici.
Pogledajte :doc:`programming`.

Povezana dokumentacija
----------------------

* :doc:`../user-guide/web-tool` - potpuna referenca Device Toola.
* :doc:`../user-guide/web-flasher` - ULX3S WebUSB, WinUSB, provjera cilja i otklanjanje pogrešaka.
* :doc:`../user-guide/web-serial` - UART/Web Serial rad i otklanjanje pogrešaka.
* :doc:`../user-guide/pinouts` - ULX3S UART i JTAG veze.
* :doc:`quick-start` - instalacija razvojnih alata i build iz izvornog koda.
* :doc:`programming` - privremene i trajne metode programiranja pločice.
