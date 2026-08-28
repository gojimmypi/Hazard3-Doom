Hladno pokretanje s micro-SD kartice
====================================

Put pokretanja sa SD kartice omogućuje programiranom ULX3S-u da se oporavi nakon potpunog prekida napajanja i pokrene Doom bez povezanog razvojnog računala.

Sadržaj kartice
---------------

Postavite ove datoteke u korijenski direktorij micro-SD kartice formatirane kao FAT:

.. code-block:: text

   DOOM.H3D
   DOOM.WAD

``DOOM.WAD`` je kanonski naziv IWAD datoteke koji trenutačni postupak hladnog pokretanja koristi.

Podrška datotečnom sustavu
--------------------------

Monitor podržava datoteke u korijenskom direktoriju FAT16/FAT32 s nazivima 8.3. Podržane su i fragmentirane datoteke.

Slijed hladnog pokretanja
-------------------------

#. ECP5 učitava svoju konfiguraciju iz ugrađenog SPI flasha.
#. Donji interni EBR sadrži inicijalizacijsku sliku rezidentnog monitora.
#. Hazard3 počinje na svojoj reset/monitor ulaznoj točki.
#. SDRAM se inicijalizira.
#. Monitor inicijalizira SD karticu i montira FAT.
#. ``DOOM.H3D`` se učitava u SDRAM i provjerava.
#. ``DOOM.WAD`` se pronalazi i učitava u svoje rezervirano područje.
#. Monitor pokreće Doom.

Dijagnostika monitora
---------------------

Upotrijebite ``c`` za ispis trenutačnog stanja i brojača SD/FAT-a. Upotrijebite ``b`` za ručno ponavljanje pokušaja pokretanja sa SD kartice.

Ispravno izvješće stanja sadrži podatke poput:

.. code-block:: text

   sd_initialized=YES
   type=SDHC/SDXC
   fat_type=FAT32
   mounted=YES
   wad=DOOM.WAD

Dijeljeni ESP32/FPGA SD pinovi
------------------------------

Na ULX3S-u je micro-SD utor također spojen na GPIO-ove ESP32. Kada Hazard3
upravlja SD karticom, firmware ESP32 mora ostaviti GPIO 14, 15, 2 i 13 u stanju
visoke impedancije kako se ne bi električki sukobio s FPGA SD sučeljem.

.. important::

   Vlasništvo nad SD sabirnicom električki je problem, a ne samo softverski mutex. Oba uređaja nikada ne smiju istodobno aktivno pogoniti zajedničku sabirnicu.

Pogledajte :doc:`sao` za zaseban mehanizam dijeljenog pristupa FPGA/ESP32 koji se koristi za SAO promet.
