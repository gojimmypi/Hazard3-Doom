Pin ograničenja, sheme i hardverske revizije
=============================================

Naziv signala postaje fizički hardver kroz lanac artefakata:

.. code-block:: text

   signal u shemi -> PCB vod / FPGA kuglica -> LPF ograničenje
      -> top-level Verilog port -> modul/periferija -> softversko ponašanje

Signal nazvan ``sd_clk`` ispravan je SD clock tek kada ga odgovarajući LPF stavi
na FPGA kuglicu koju ciljana PCB revizija doista vodi do SD signala.

Važne datoteke
--------------

.. code-block:: text

   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.lpf
   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld_v002.lpf
   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ls.lpf
   bootloader/data/top-ulx4m-v002.lpf

LPF sadrži lokacije, I/O standarde, termination/differential postavke i podatke
o satu. Treba ga tretirati kao izvršivu hardversku dokumentaciju.

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

Lokalne reference
-----------------

:download:`ULX4M sheme (lokalna kopija) <ULX4M-LS-v0.0.3.pdf>`

:download:`Alliance AS4C256M16D3 datasheet (lokalna kopija) <../../AllianceMemory_4G_DDR3_AS4C256M16D3C_May2020_Rev1.1_Final.pdf>`

Prije promjene pina
-------------------

#. Identificirajte točnu varijantu i reviziju.
#. Pronađite signal u odgovarajućoj shemi.
#. Potvrdite FPGA kuglicu i I/O banku.
#. Provjerite napon i I/O standard.
#. Promijenite pravi LPF.
#. Provjerite smjer i širinu Verilog porta.
#. Izgradite dizajn i pregledajte upozorenja.
#. Testirajte funkciju na fizičkom hardveru.
#. Za dijeljene sabirnice provjerite ownership i idle stanja.
#. Zabilježite reviziju/profil korišten za validaciju.
