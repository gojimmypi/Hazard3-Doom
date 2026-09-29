Pin ograničenja, sheme i hardverske revizije
=============================================

Naziv signala postaje fizički hardver kroz lanac artefakata. Razumijevanje tog
lanca jedna je od najprenosivijih lekcija FPGA razvoja.


Od mreže na shemi do Verilog porta
----------------------------------

.. code-block:: text

   mreža na shemi pločice
        |
        v
   PCB vod / kuglica FPGA pakiranja
        |
        v
   LPF LOCATE + IOBUF ograničenje
        |
        v
   Verilog port najviše razine
        |
        v
   projektni modul / periferija
        |
        v
   ponašanje vidljivo softveru

Primjerice, SD takt nije "pin SD takta" samo zato što se Verilog signal zove
``sd_clk``. Ispravan SD takt postaje tek kada odgovarajući LPF mapira taj port na
kuglicu pakiranja koju odabrana revizija PCB-a vodi do signala utora/noseće
pločice.

.. figure:: ../../images/ulx4m_ld-pinout.png
   :alt: ULX4M-LD raspored pinova

   **ULX4M-LD raspored pinova** - FPGA dodjele pinova na
   `Waveshare CM4 nosećoj pločici <https://www.waveshare.com/wiki/CM4-IO-BASE-A#Dimension>`_.

Hazard3-Doom datoteke ograničenja
---------------------------------

Važne projektne datoteke uključuju:

.. code-block:: text

   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.lpf
   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld_v002.lpf
   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ls.lpf
   bootloader/data/top-ulx4m-v002.lpf

Doom SoC i DFU bootloader različiti su FPGA dizajni pa ne moraju izlagati ista
imena signala najviše razine čak ni kada ciljaju istu fizičku pločicu.

LD LPF sadrži mnogo više od lokacija: primjenjuje DDR3 SSTL I/O tipove,
terminaciju/diferencijalne postavke, podatke o frekvenciji oscilatora, uobičajena
LVCMOS ograničenja i mapiranje pinova specifično za pločicu. Tretirajte ga kao
izvršivu hardversku dokumentaciju.
Disciplina revizija
-------------------

Za svaku ULX4M pločicu zabilježite LS/LD varijantu, PCB reviziju, puni FPGA dio
i memorijsku populaciju. Dvije pločice nazvane "ULX4M-LD" mogu zahtijevati
različite DDR3 profile.

Kada se upstream izvori ne slažu, zabilježite neslaganje i potražite razlog:
prototip, starija revizija, alternativni BOM, druga grana ili zastarjela
dokumentacija. Crowd Supply primjerice opisuje Micron
``MT41K512M16HA-125`` 1-GiB LD, upstream priručnik navodi
``MT41K256M16TW-107`` 512 MiB, a Hazard3-Doom dodatno podržava Alliance
``AS4C256M16D3`` profil.


Razlike među izvorima također su podatak
----------------------------------------

Kada se dva izvorna izvora ne slažu, nemojte skrivati razliku. Zabilježite je i
potražite razlog: starija revizija, prototip nasuprot proizvodnji, alternativni
BOM, nepodudaranje grane ili zastarjela dokumentacija.

Projekt trenutačno ima konkretan primjer. Crowd Supply stranica opisuje Micron
``MT41K512M16HA-125`` LD konfiguraciju od 1 GiB, dok jedna stranica izvornog LD
priručnika navodi ``MT41K256M16TW-107`` od 512 MiB, a Hazard3-Doom dodatno
podržava Alliance ``AS4C256M16D3`` profil. Ispravan izbor za izgradnju je dio na
stvarnoj pločici, a ne prva otvorena web-stranica.

Korištenje lokalne kopije sheme
-------------------------------

Repozitorij sadrži lokalnu kopiju ULX4M sheme za razvojnu referencu:

:download:`ULX4M sheme (lokalna kopija) <ULX4M-LS-v0.0.3.pdf>`

Također sadrži Alliance DDR3 podatkovni list korišten pri radu s alternativnom
memorijom:

:download:`Alliance AS4C256M16D3 podatkovni list (lokalna kopija) <../../AllianceMemory_4G_DDR3_AS4C256M16D3C_May2020_Rev1.1_Final.pdf>`

Te su datoteke korisne reference, ali podrijetlo grane/revizije i dalje je
važno. PDF u repozitoriju nije dokaz da svaka fizička pločica odgovara toj
reviziji sheme.

Kontrolni popis prije promjene pina
-----------------------------------

#. Odredite točnu ciljnu pločicu/reviziju.
#. Pronađite signal u odgovarajućoj shemi.
#. Potvrdite FPGA kuglicu pakiranja i I/O banku.
#. Provjerite potreban napon i I/O standard.
#. Ažurirajte ispravan LPF, a ne slično nazvanu prototipnu datoteku.
#. Potvrdite smjer i širinu Verilog porta najviše razine.
#. Izgradite uz ozbiljno razmatranje upozorenja.
#. Testirajte fizičku funkciju na hardveru.
#. Ako promjena utječe na zajedničku sabirnicu, provjerite vlasništvo i stanja
   mirovanja.
#. Zabilježite reviziju/profil korišten za rezultat provjere.

Taj je postupak sporiji od kopiranja broja pina s foruma, ali mnogo brži od
kasnijeg otklanjanja električki nemogućeg dizajna.

Vanjski ULX4M izvori
--------------------

* `ULX4M dokumentacija <https://github.com/intergalaktik/ulx4m-documentation>`_
* `ULX4M hardverski repozitorij <https://github.com/intergalaktik/ulx4m>`_
* `ULX4M projekt i bilješke o kompatibilnosti nosećih pločica <https://www.crowdsupply.com/intergalaktik/ulx4m/updates/pre-launch-progress>`_
* `Dokumentacija Raspberry Pi Compute Module <https://www.raspberrypi.com/documentation/computers/compute-module.html>`_
* `Waveshare CM4-IO-BASE-A shema <https://files.waveshare.com/upload/a/aa/CM4-IO-BASE-A_V4_SchDoc.pdf>`_

* `ULX4M Open Source Hardware certifikat <https://certification.oshwa.org/hr000013.html>`_
