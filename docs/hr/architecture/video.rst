Video pipeline
==============

Video pipeline je značajka Hazard3-Doom/ULX3S SoC-a oko procesora; nije dio
upstream Hazard3 CPU jezgre. CPU proizvodi framebuffer podatke običnim memorijskim
operacijama, dok projektni hardver te podatke pretvara u signal zaslona.

Doom zadržava svoj izvorni indeksirani renderer. Projekt ne zahtijeva da igra u
softveru iscrtava puni RGB framebuffer.

Pipeline
--------

#. Doom iscrtava 320x200 8-bitni indeksirani okvir u projektni screen buffer.
#. Softver zapisuje dovršeni indeksirani okvir u neaktivni interni EBR framebuffer
   kroz izravni put video registara.
#. Interni framebufferi zamjenjuju se tijekom vertical blankinga.
#. Hardverska paleta pretvara indeksirane piksele za HDMI scanout.

Geometrija izlaza
-----------------

Dokumentirani izlaz 1024x600 skalira Doomov izvorni indeksirani okvir 320x200 na
cijeli panel. Okomito skaliranje je točno 3x (200 na 600 redaka), dok je vodoravno
skaliranje frakcijsko kako bi se iskoristila sva 1024 izlazna piksela.

Zašto indeksirana boja?
-----------------------

Zadržavanje izvornog indeksiranog prikaza smanjuje softverski memorijski promet
i omogućuje da se pretvorba palete obavi u namjenskoj FPGA logici.

Video registri
--------------

Blok HDMI/video kontrolnih registara počinje na:

.. code-block:: text

   0x4000C000

Web Serial put snimke zaslona
-----------------------------

Značajka Web Serial snimke zaslona namjerno je iznad fizičkog HDMI enkodera.
Ne snima TMDS i ne ovisi o općenitom EBR readback putu. Podržana aktivna
aplikacija serijalizira svoj indeksirani izvorni okvir zajedno s RGB332 paletom
putem UART-a koristeći protokol ``H3SNIP1``. Preglednik zatim rekonstruira
oglašeni raster ``1024x600`` nearest-neighbor mapiranjem izvora i lokalno kodira
PNG.

Tako payload na vezi ostaje kompaktan u odnosu na puni RGB framebuffer i isti
parser u pregledniku može prihvatiti Doom izvore i I2C GUI izvore različitih
geometrija. Pogledajte :doc:`../user-guide/web-serial` za cijeli protokol.

Korisnici video puta koji nisu Doom
-----------------------------------

Rezidentni monitor također može koristiti izravni indeksirani EBR put za
dijagnostiku. Sučelje :doc:`../user-guide/i2cdriver` iscrtava vlastiti 320x200
indeksirani zaslon, zapisuje neaktivni interni framebuffer i traži zamjenu na
vertical blankingu bez promjene DoomGenerica.
