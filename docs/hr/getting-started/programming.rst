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

.. warning::

   Provjerite bitstream privremenim učitavanjem prije nego što ga trajno zapišete. Neispravnu trajnu sliku moguće je oporaviti, ali privremeno ispitivanje je brže i sigurnije tijekom razvoja.

Pogledajte :doc:`../user-guide/sd-card` za sadržaj SD kartice i dijagnostiku pokretanja.
