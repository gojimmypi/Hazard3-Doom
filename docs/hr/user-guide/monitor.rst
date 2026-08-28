Rezidentni monitor
==================

Rezidentni monitor je firmware koji ostaje dostupan čak i kada se učitljiva Doom aplikacija zamijeni ili završi. Pruža UART naredbe, protokole za učitavanje, dijagnostiku i put oporavka koji se koristi tijekom razvoja.

Glavne Doom naredbe
-------------------

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Naredba
     - Funkcija
   * - ``l``
     - Primi zapakiranu izvršnu Doom sliku putem UART-a.
   * - ``w``
     - Primi IWAD u rezervirano područje SDRAM-a.
   * - ``j``
     - Pokreni provjerenu Doom sliku i IWAD.
   * - ``b``
     - Pokušaj pokretanje s micro-SD kartice.
   * - ``c``
     - Ispiši stanje i brojače SD/FAT pokretanja.

Mogućnost Web Serial snimke zaslona
-----------------------------------

Trenutačni rezidentni monitor sudjeluje u Web Serial protokolu za snimku
zaslona. Nakon što uspješno prikaže monitorski RGB332 testni uzorak, čuva
provjerenu predmemoriranu kopiju u rezerviranom SDRAM-u. Upit sposobnosti
``0x1c`` vraća ACK dok je ta predmemorija valjana, a ``0x1d`` serijalizira
predmemorirani okvir.

Učitavanje slike ``.h3d`` naredbom ``l`` samo pohranjuje i provjerava izvršnu
datoteku u SDRAM-u; ono **ne** pokreće tu sliku niti aktivira Doomov vlastiti
rukovatelj snimkom zaslona. Doom postaje aktivni pružatelj zaslona tek nakon što
``j`` pokrene sliku i počne raditi njegova UART/HDMI petlja. HDMI GUI I2CDrivera
na isti način postaje aktivni pružatelj dok ``i2c gui`` / ``sao gui`` upravlja
UART-om. Pogledajte :doc:`web-serial`.

SAO / I2C HDMI dijagnostika
---------------------------

Monitor može pokrenuti interaktivno HDMI I2C dijagnostičko sučelje naredbom:

.. code-block:: text

   i2c gui

ili ``sao gui``. Dok je GUI aktivan, UART tipke upravljaju HDMI sučeljem.
Izađite tipkom ``Q``, ``Ctrl-X`` ili Esc kada nije aktivan upit za operand.
Pogledajte :doc:`i2cdriver` za potpunu referencu kontrola.

Povratak iz Dooma
-----------------

Pritisnite ``Ctrl-X`` dok Doom radi kako biste se vratili u monitor. To je korisno prije prijenosa zamjenske izvršne datoteke ili WAD-a.

Repozitorij također sadrži pomoćne skripte za povratak u monitor ili ponovno pokretanje iz monitora kada terminal nije praktičan.

Izgradnja monitora
------------------

Trenutačna grana još uvijek naziva ELF monitora ``build/hazard3-boot-monitor.elf``. Funkcionalno, taj ELF je firmware rezidentnog monitora koji se koristi za početno pokretanje, otklanjanje pogrešaka, učitavanje i dijagnostiku.
