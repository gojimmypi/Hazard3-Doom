Pokretanje Dooma
================

Učitavanje putem UART-a
-----------------------

Uobičajeni razvojni postupak šalje zapakiranu izvršnu datoteku ``.h3d`` rezidentnom monitoru, zatim šalje ``DOOM.WAD`` i pokreće aplikaciju.

Memorijski profil od 64 MiB zadan je za ULX3S 85F i ULX4M-LD 85F.

Kontrole
--------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Tipka
     - Radnja
   * - ``Esc``
     - Izbornik / natrag.
   * - ``W`` / ``S``
     - Naprijed/natrag ili gore/dolje u izborniku.
   * - ``A`` / ``D``
     - Okretanje ili promjena vrijednosti u izborniku.
   * - ``Z`` / ``C``
     - Bočno kretanje lijevo/desno.
   * - ``F`` ili ``Space``
     - Pucanje.
   * - ``E``
     - Upotrijebi/otvori.
   * - ``M`` ili ``Tab``
     - Automapa.
   * - ``P``
     - Pauza.
   * - ``1`` do ``7``
     - Odabir oružja.
   * - ``Enter``
     - Odabir.
   * - ``Ctrl-X``
     - Izlaz iz Dooma i povratak u rezidentni monitor.

Video put
---------

Doom iscrtava radni zaslon 320x200 s 8-bitnim indeksiranim bojama. HDMI put na FPGA strani prikazuje indeksirani okvir kroz hardversku paletu i logiku za ispis slike. Pogledajte :doc:`../architecture/video` za put podataka.

Web Serial snimka zaslona
-------------------------

Kada konzola u pregledniku potvrdi mogućnost snimke zaslona, Doom prihvaća
rezervirani zahtjev za neobrađenim snimanjem i odgađa serijalizaciju do sljedećeg
dovršenog ``DG_DrawFrame()``. Time se izbjegava kopiranje framebuffer-a koji Doom
još mijenja. Standardne izgradnje šalju indeksirani izvor ``320x200``. Opcionalna
izgradnja prikaza ``400x240`` prije slanja snimke primjenjuje isto proširenje
Doom izvora koje koristi HDMI put.

Preglednik prima paletu i indeksirane piksele, rekonstruira oglašeni HDMI raster
``1024x600`` i lokalno preuzima PNG. Pogledajte :doc:`web-serial` za dogovor o
sposobnosti, format ``H3SNIP1`` na vezi, RGB332 kodiranje palete, vrijeme prijenosa
i stroj stanja za prijam u pregledniku.

Zvuk
----

Zvuk je trenutačno stubiran u dokumentiranoj razvojnoj prekretnici.
