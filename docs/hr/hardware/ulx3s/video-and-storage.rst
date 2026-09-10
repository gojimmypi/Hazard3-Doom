Video, micro-SD i runtime pohrana
=================================

GPDI video
----------

ULX3S ima GPDI izlaz. Hazard3-Doom ga koristi za indexed-framebuffer video put.
Glavni Doom način je 320x200 indeksirana boja uz hardversku pretvorbu palete.
Kompaktni 12F cilj namjerno ostaje na 320x200 putu.

Vidi :doc:`../../architecture/video` i :doc:`../../user-guide/web-serial`.

micro-SD pohrana
----------------

micro-SD je izmjenjiva nevolatilna pohrana. Samostalni ULX3S boot može s nje
učitati ``DOOM.H3D`` i ``DOOM.WAD``.

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
