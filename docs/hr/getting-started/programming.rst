Programiranje i trajno pokretanje
=================================

Postoje dva različita cilja programiranja:

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
#. ``DOOM.H3D`` i ``DOOM.WAD`` čitaju se sa SD kartice.
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

ULX4M-LD Micro-B DFU bootloader zapisuje trajni korisnički bitstream u SPI flash.
Ta slika ostaje nakon isključivanja napajanja i odvojena je od samog DFU
bootloadera.

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

Ako pločica nakon upisa ostane u DFU načinu rada, zatražite od bootloadera da
pokrene već spremljenu sliku:

.. code-block:: bash

   ./bin/dfu-util.exe -a 0 -e

Naredba ``-e`` ne preuzima niti briše FPGA podatke. Pogledajte
:doc:`../user-guide/bootloader` za bootloader i oporavak te
:doc:`../user-guide/jtag-debugging` za otklanjanje pogrešaka putem Tigarda.

.. warning::

   Provjerite bitstream privremenim učitavanjem prije nego što ga trajno zapišete. Neispravnu trajnu sliku moguće je oporaviti, ali privremeno ispitivanje je brže i sigurnije tijekom razvoja.

Pogledajte :doc:`../user-guide/sd-card` za sadržaj SD kartice i dijagnostiku pokretanja.
