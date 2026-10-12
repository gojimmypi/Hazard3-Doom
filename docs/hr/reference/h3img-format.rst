H3IMG format izvršne slike
==========================

H3IMG je format pakirane izvršne slike koji prihvaća rezidentni monitor
Hazard3-Doom. Datoteke imaju nastavak ``.h3img``. Doom IWAD (``DOOM.WAD``)
prenosi se zasebno.

Struktura datoteke
------------------

H3IMG počinje **64-bajtnim binarnim zaglavljem** iza kojeg slijede izvršni
podaci. Zaglavlje određuje adresu učitavanja, ulaznu adresu i BSS područje.

.. code-block:: text

   Pomak
   0x0000       H3IMG zaglavlje (64 bajta)
   0x0040       Izvršni podaci (duljina iz zaglavlja)
   ...          Kraj datoteke

Oznaka formata je ``H3I1`` (ASCII bajtovi ``48 33 49 31``), odnosno
``0x31493348`` kao 32-bitni little-endian broj.

Polja zaglavlja
---------------

.. list-table::
   :header-rows: 1
   :widths: 28 72

   * - Polje
     - Svrha
   * - Magic
     - Identificira format i verziju (``H3I1``).
   * - Adresa učitavanja
     - SDRAM adresa na koju se kopiraju izvršni podaci.
   * - Veličina podataka
     - Broj izvršnih bajtova iza zaglavlja.
   * - Ulazna adresa
     - Adresa na kojoj započinje izvođenje aplikacije.
   * - BSS adresa
     - Početak neinicijaliziranog podatkovnog područja.
   * - BSS veličina
     - Broj bajtova tog područja.
   * - CRC32 podataka
     - Provjera integriteta izvršnih podataka.

.. important::

   Ovaj popis ne navodi pomake svih polja. Za izradu kompatibilne datoteke
   provjerite puni raspored, zapis brojeva, CRC32 parametre i ograničenja
   adresa u odgovarajućem kodu monitora i alata za pakiranje.

Memorija i kompatibilnost
-------------------------

Monitor učitava sliku u konfigurirani SDRAM. Adrese izvršnih podataka, BSS-a i
ulazne točke moraju odgovarati memorijskoj mapi monitora. Profili ``32m`` i
``64m`` nisu zamjenjivi. Učitavanje ne pokreće program; naredba ``j`` pokreće
uspješno učitanu aplikaciju.

H3IMG nije ELF datoteka. Ne prenosi ELF tablice simbola, relokacije ni podatke
za otklanjanje pogrešaka.

UART prijenos (H3L)
-------------------

Web Device Tool koristi H3L protokol. Monitor mora prikazivati odzivnik ``>``.

.. code-block:: text

   preglednik -> l
   monitor    -> H3L READY
   preglednik -> H3IMG zaglavlje (64 bajta)
   monitor    -> H3L DATA
   preglednik -> izvršni podaci
   monitor    -> H3L OK

Preglednik prije prijenosa provjerava zaglavlje, duljinu datoteke i CRC32.
Prijenos zapisuje SDRAM, ne SD karticu. Moguće je i učitavanje H3IMG datoteke
sa SD kartice.

Upute: :doc:`../user-guide/web-tool`, :doc:`../user-guide/monitor` i
:doc:`../user-guide/sd-card`.

Implementacija
--------------

Mjerodavni su kod monitora te alati za pakiranje i prijenos iz iste revizije
repozitorija. Nije zajamčena kompatibilnost s budućim verzijama.

* `Hazard3-Doom repozitorij <https://github.com/ulx3s/Hazard3-Doom>`_
* `Razvojna grana <https://github.com/gojimmypi/Hazard3-Doom/tree/develop>`_
