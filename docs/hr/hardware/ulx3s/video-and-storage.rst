Video, micro-SD i runtime pohrana
=================================

GPDI video
----------

ULX3S ima GPDI izlaz. Hazard3-Doom ga koristi za indexed-framebuffer video put.
Glavni Doom način je 320x200 indeksirana boja uz hardversku pretvorbu palete.
Kompaktni 12F cilj namjerno ostaje na 320x200 putu.

Vidi :doc:`../../architecture/video` i :doc:`../../user-guide/web-serial`.

HDMI zasloni i primjer kućišta
-------------------------------

GPDI izlaz može se koristiti s HDMI zaslonom uz odgovarajuću GPDI-na-HDMI
vezu. Hazard3-Doom video put nije vezan uz određeni monitor: Elecrow zaslon od
sedam inča praktičan je hardverski primjer, ali mogu se koristiti i drugi HDMI
zasloni.

Dostupno je 3D ispisivo kućište za kompaktni ULX3S demonstracijski sustav
izgrađen oko Elecrow 7-inčnog 1024x600 IPS HDMI zaslona. U isto kućište smješta
ULX3S i zaslon, uz zadržan pristup kontrolama pločice, statusnim LED-ovima,
GPIO/JTAG priključcima, kontrolama zaslona i vođenju kabela. Dostupne su i
opcije za stalak, razvojne nožice, OLED okvir i mali unutarnji ventilator.

Kućište je mehanički projektirano za taj Elecrow panel; nije potrebno za
Hazard3-Doom i ne ograničava FPGA video izlaz na taj zaslon. Za projektne
datoteke, upute za ispis, sastavljanje i napomene o kompatibilnosti vidi:

* `ULX3S Elecrow 7 inch HDMI Display Enclosure
  <https://github.com/gojimmypi/ulx3s-elecrow-7inch-hdmi-enclosure>`_
* `Crowd Supply: New Enclosure & Upcoming Campaign News
  <https://www.crowdsupply.com/radiona/ulx3s/updates/new-enclosure-and-upcoming-campaign-news>`_

.. warning::

   Dokumentacija kućišta sadrži upozorenja specifična za povezivanje. Posebno,
   nemojte istodobno koristiti vanjski HDMI ulaz kućišta i interno spojeni
   ULX3S video put te nemojte istodobno spajati USB priključak za dodir i USB
   priključak za napajanje zaslona. Prije sastavljanja pregledajte repozitorij
   kućišta.

micro-SD pohrana
----------------

micro-SD je izmjenjiva nevolatilna pohrana. Samostalni ULX3S boot može s nje
učitati ``DOOM.IMG`` i ``DOOM.WAD``.

* SPI flash čuva trajnu FPGA konfiguraciju;
* EBR može sadržavati rezidentni monitor;
* SDRAM je volatilna radna memorija;
* micro-SD čuva izmjenjive datoteke.

Dijeljeni SD s ESP32
--------------------

micro-SD signali dijeljeni su između FPGA-a i ESP32. Kada Hazard3 upravlja SD
sabirnicom, ESP32 GPIO14, GPIO15, GPIO2 i GPIO13 moraju ostati u visokoj
impedanciji.

.. important::

   Vlasništvo SD sabirnice električno je pravilo, ne samo softverski mutex. Dva
   aktivna izlaza na istoj liniji mogu uzrokovati pogreške i električni sukob.

Vidi :doc:`../../user-guide/sd-card` i :doc:`../../user-guide/sao`.

Pločica ima i audio te priključak za mali zaslon; korisni su za eksperimente,
ali nisu potrebni za uobičajeni Hazard3-Doom video/storage put.
