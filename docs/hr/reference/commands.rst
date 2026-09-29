Referenca naredbi monitora
==========================


Kvalifikacija vanjske memorije
------------------------------

DDR3 put na ULX4M-LD pločici hardverski je kvalificiran sljedećim naredbama
monitora. Pričekajte da ``s`` prijavi ``external_memory_ready=YES`` prije
pokretanja destruktivnih testova memorije.

.. list-table::
   :header-rows: 1

   * - Naredba
     - Opis
   * - ``m``
     - Destruktivni sekvencijalni test dijagnostičkog prozora od 1 MiB.
       Provjerava širine pristupa te uzorke nula, jedinica, adrese i invertirane
       adrese.
   * - ``a``
     - Rijetki test aliasiranja adresa/banki kroz cijeli softverski vidljiv
       prozor vanjske memorije od 64 MiB.
   * - ``r``
     - Pseudoslučajni test od 1 MiB u svakoj od četiri odvojene memorijske regije.
   * - ``q``
     - Pokreće cijeli skup kvalifikacijskih testova: sekvencijalni + rijetki +
       pseudoslučajni.
   * - ``k``
     - Test alokacije i opterećenja hrpe. ULX4M-LD profil od 64 MiB provjerava
       prozor hrpe od 40 MiB.
   * - ``d``
     - Brzi test Doom platformske memorije i timera.
   * - ``x``
     - Kopira RV32 kod u vanjsku memoriju i izvršava ga, uključujući faze s
       normalnim i stranim GP-om, prekide timera i zaštitne provjere.
   * - ``z``
     - Resetira hrpu; svi postojeći pokazivači na hrpu postaju nevažeći.
   * - ``s``
     - Ispisuje stanje izvođenja, uključujući spremnost vanjske memorije i
       stanje LiteDRAM inicijalizacije/PLL-a/korisničkog takta.
   * - ``v``
     - Ispisuje identifikatore verzija firmwarea, FPGA-a, memorijske jezgre i
       adaptera.

Početni ``TIMEOUT`` sam po sebi nije konačan dokaz DDR kvara. Tijekom trenutačnog
ULX4M-LD pokretanja LiteDRAM je završio nakon početnog čekanja monitora od 5
sekundi; ``s`` je zatim prijavio spremno stanje, a cijeli kvalifikacijski skup
prošao je uspješno.

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
