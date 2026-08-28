Referenca naredbi monitora
==========================

Pokretanje i Doom
-----------------

.. list-table::
   :header-rows: 1

   * - Naredba
     - Opis
   * - ``l``
     - Prima zapakiranu Doom sliku preko UART-a.
   * - ``w``
     - Prima IWAD preko UART-a.
   * - ``j``
     - Pokreće provjerenu izvršnu datoteku i WAD.
   * - ``b``
     - Pokreće SD boot loader.
   * - ``c``
     - Ispisuje status SD/FAT pokretanja.

SAO / I2C
---------

.. list-table::
   :header-rows: 1

   * - Naredba
     - Opis
   * - ``sao info``
     - Prikazuje stanje SAO bridgea/vlasništva.
   * - ``sao gui``
     - Pokreće HDMI dijagnostičko sučelje u stilu I2CDrivera.
   * - ``sao recover``
     - Pokušava oporaviti sabirnicu.
   * - ``sao scan``
     - Pretražuje SAO I2C sabirnicu.
   * - ``sao probe``
     - Ispituje uređaj/adresu.
   * - ``sao read``
     - Čita iz SAO I2C cilja.
   * - ``sao write``
     - Piše u SAO I2C cilj.
   * - ``i2c scan``
     - Pretražuje I2C sabirnicu pomoću kompatibilne naredbe.
   * - ``i2c gui``
     - Alias za ``sao gui``.

Interaktivne HDMI I2C kontrole
------------------------------

Nakon pokretanja ``sao gui`` ili ``i2c gui``, UART postaje ulaz tipkovnice za
HDMI sučelje. ``S`` pretražuje, ``P`` ispituje, ``R`` čita jedan registar,
``W`` zapisuje jedan registar, ``X`` pokušava oporavak sabirnice, ``1``/``4``
odabiru 100/400 kHz, ``C`` briše stanje prikaza, a ``Q`` izlazi. Pogledajte
:doc:`../user-guide/i2cdriver` za unos operanada, sigurnosne napomene i
ponašanje logičkog traga.

Rezervirani upravljački bajtovi Web Seriala
-------------------------------------------

Ovi sirovi bajtovi dio su transporta browser screen-snipa, a ne tekstualne
naredbe rezidentnog monitora:

.. list-table::
   :header-rows: 1

   * - Bajt
     - Namjena
   * - ``0x1c``
     - Upit sposobnosti screen-snipa.
   * - ``0x06``
     - ACK sposobnosti iz podržanog cachea monitora ili aktivne aplikacije prikaza.
   * - ``0x1d``
     - Zahtjev za screen-snip snimku.

Pogledajte :doc:`../user-guide/web-serial` za potpuni protokol ``H3SNIP1`` i
automat stanja.
