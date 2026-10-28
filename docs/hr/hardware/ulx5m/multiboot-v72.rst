ULX5M-GS v72: Potvrđeno pokretanje sekundarne slike tijekom rada (28. listopada 2026.)
======================================================================================

.. important::

   Ova stranica opisuje uspješan **izolirani** hardverski pokus na pločici
   ULX5M-GS V005. Primarna slika v72 ne podržava USB DFU. Produkcijski
   SERV/BTN2 bootloader **još nije dovršen**. Sačuvajte datoteke za obnovu
   v63c, izvorne potpune sigurnosne kopije flasha i točan kandidat v72.

Dokazi hardverskog ispitivanja
------------------------------

Instalacijski alat v72c potvrdio je da su oba neovisna očitanja početnog
stanja flasha od 4 MiB jednaka, sa SHA-256 vrijednošću
``644c7c1b26e4cc2ba419a59a53ca8ffbbc02e808920d68336e84ac886d81cb02``.
Provjereni su točno jedan GateMate JTAG IDCODE ``0x20000001``, flash JEDEC
``1f 42 16`` i potpuna slika flasha nakon upisa. Zamijenjeno je samo prvih
64 KiB primarne slike; provjerena sekundarna aplikacija v41 ostala je na
adresi ``0x201000``. Sačuvani su sigurnosna kopija prvog bloka v63c i cijeli
izvorni sadržaj čipa.

Nakon isključivanja napajanja, postavljanja SW1 na OFF/OFF (aktivni SPI),
ostavljanja BTN2 otpuštenim i ponovnog uključivanja, opaženo je stalno
svjetlo D6 i treptanje D7, zatim treptanje D0 i pomicanje svjetlosnog uzorka
kroz D1-D7. Taj uzorak potvrđuje izvođenje poznate aplikacije v41, a ne
samo uspješan upis naredbe ili simulirani RECFG. Za taj početak rada iz
aktivnog SPI načina nije korišteno konfiguriranje FPGA-a putem SRAM-a/JTAG-a.

.. list-table:: Hardverske i slikovne kontrolne vrijednosti
   :header-rows: 1
   :widths: 37 63

   * - Stavka
     - Provjerena vrijednost
   * - Veličina primarne slike v72
     - 14 987 bajtova
   * - SHA-256 primarne slike v72
     - ``839696d7c8a4ecdf63dff904c01ce85aea280bd885eda4309c7e5d25800e3aa0``
   * - SHA-256 naredbe izvedene iz slike v72
     - ``8fbec9715a209dac2dc35dc6b517972b9d64dcdc5a7b4437fac7731a0d2849e4``
   * - SHA-256 prvih 64 KiB kandidata v72c
     - ``b31d6b84b9fd849007da4aae23010fd1f98efa000a74aab7336a495eb5699fdc``
   * - SHA-256 cijelog flasha v63c prije instalacije
     - ``644c7c1b26e4cc2ba419a59a53ca8ffbbc02e808920d68336e84ac886d81cb02``
   * - SHA-256 cijelog flasha nakon instalacije v72
     - ``56d10293b68afbf21c353c7733a0a5d39a97c20d3f5a9c87b0335a09c7f36397``
   * - SHA-256 sekundarnog sektora v41
     - ``28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee``
   * - Sesija za oporavak v72c
     - ``build-ulx5m-gs/v72c-registered-ab-20261028T193955726442Z-508``
   * - Alati i usmjeravanje
     - OSS CAD Suite 2026-07-20; ciljana frekvencija 25 MHz, najveća
       frekvencija nakon usmjeravanja 79,26 MHz; seed 302, CCGM1A1

Izvorni ``state.json`` te sesije navodi da preuzimanje izvođenja nije bilo
testirano; to odgovara stanju u trenutku instalacije. Naknadno opažanje
LED-ova nakon uključivanja potvrdilo je hardverski rezultat. Nemojte
naknadno prepravljati povijesnu datoteku stanja radi tvrdnje da je izvršena
automatizirana hardverska provjera.

Što pokazuju uspješni i neuspješni pokusi
-----------------------------------------

.. list-table:: Kontrolirane hardverske usporedbe
   :header-rows: 1
   :widths: 13 53 34

   * - Inačica
     - Razlikovno svojstvo
     - Hardverski rezultat
   * - v65
     - Minimalni RECFG u aktivnom SPI načinu, bez šest ulaznih West-A GPIO-a
     - Sekundarno pokretanje: PASS
   * - v66
     - Šest konfiguracijskih flash pinova dodijeljeno korisničkim GPIO
       ulazima bez izlaznog pogona
     - Sekundarno pokretanje: FAIL
   * - v67
     - Usmjerena izvedba v66 s obrisanim bitom vlasništva statusnih
       konfiguracijskih ulaza/izlaza u pakiranoj slici
     - Sekundarno pokretanje: PASS
   * - v68
     - Ažuriranje statusa memorijske banke prije RECFG-a
     - Sekundarno pokretanje: FAIL
   * - v70
     - Točna naredba od 27 bajtova izvedena iz TinyDFU-a, kraće čekanje
       mirovanja i drukčije registriranje izlaza
     - Sekundarno pokretanje: FAIL
   * - v72
     - Registrirani naredba, podaci i signal valjanosti, uz dokumentirani
       završni slijed i čekanje nakon naredbe prema TinyDFU-u
     - Sekundarno pokretanje: PASS

Usporedba pokazuje da ispravan CRC i sadržaj statusne naredbe sami po sebi
nisu dovoljni. Ona **ne** određuje jedinstven vremenski kvar u inačici v70.
Nemojte skraćivati potvrđeni slijed v72 bez zasebnog ispitivanja.

Potvrđeni slijed naredbe i upravljača
-------------------------------------

Završna naredba korištena u v72 generirana je iz zapisa konfiguracijskog
statusa **vlastite pakirane slike**. Njezinih 27 bajtova glasi:

.. code-block:: text

   DB 0C B8 7E 17 10 00 20 04 01 00 00 00 00 00 00
   5D 31 00 00 00 00 33 00 00 00 00

Ta je naredba referencija za ponovljivost **isključivo za sliku v72**. Ne
smije se nepromijenjena ugraditi u konačni SERV bitstream na 48 MHz.
Transformacija izvedena iz TinyDFU-a briše odgovarajuće bitove upravljanja
konfiguracijom i vlasništva nad korisničkim ulazima/izlazima, uključuje
potrebne zastavice autonomnog takta te ponovno izračunava oba CRC-a.
Konačnu pakiranu sliku treba ponovno usporediti s ugrađenim ROM-om.

Slijednik ``CC_CFG_CTRL`` u v72 koristi registrirane ``EN``, ``VALID`` i
``DATA``. EN se uključuje najmanje tri takta prije podataka, između valjanih
bajtova postoji najmanje jedan neaktivan takt, nakon zadnjeg bajta slijedi
najmanje osam taktova s EN na visokoj razini te zatim 16 odbrojenih taktova
mirovanja s EN na niskoj razini prije aktiviranja ``RECFG``. Odjeljak 7.6
Cologne Chip UG1001 opisuje početni EN, razmak između bajtova i završno
razdoblje s visokim EN. TinyDFU je dodatna referencija za registrirani FSM
i čekanje mirovanja. Uspješan hardverski pokus potvrđuje da taj kombinirani
slijed radi na ovoj pločici, ali ne i da je pojedini interval minimalan.

Granice integracije u produkcijski bootloader
---------------------------------------------

Postojeći SERV firmware već ima provjeru izvornog sektora v41 samo za čitanje
(``fw/ulx5m_spi_active_boot.c``), funkciju za oslobađanje flasha i Wishbone
zahtjeve ARM/BOOT. Wishbone RTL u ``rtl/ulx5m_spi_active_reboot_wb.v``
trenutačno povezuje ``CC_CFG_CTRL`` **samo za RECFG** (CLK/EN/VALID/DATA
spojeni na nisku razinu). To treba zamijeniti potvrđenim registriranim
slijedom naredbe v72, bez promjene javnog ARM/BOOT statusnog sučelja i bez
uklanjanja provjere CRC-a flash sektora u firmwareu. Upis u BOOT označava
*prihvaćen zahtjev*, a ne dokaz preuzimanja izvođenja.

Potreban slijed za integriranu verziju:

#. Zadržati točno postojeće početno zaključavanje BTN2 načina rada:
   držanje BTN2 tijekom uključivanja odabire DFU, a otpuštanje nakon
   enumeracije **ne smije** isključiti DFU. Normalni put nikada ne smije
   poslati naredbu tijekom rada dok je zaključan DFU način.
#. U normalnom načinu zadržati postojeću provjeru izvornog sekundarnog
   sektora v41 na ``0x201000`` isključivo čitanjem. Ne poistovjećivati
   stariji testni omotač U5IM na ``0x200000`` s ulaznom adresom izvorne
   bitstream slike v41.
#. Pričekati mirovanje flash kontrolera i fizički otpustiti svih šest
   flash pinova iz FPGA izlaznih pogona prije slanja konfiguracijske
   naredbe. Zadržati Wishbone protokol ARM/BOOT; novi FSM pokreće se tek
   nakon zahtjeva BOOT.
#. Ugraditi registrirani FSM za slanje bajtova iz v72 u Wishbone periferiju.
   Takt mora biti **stvarni** takt integriranog kontrolera (nazivno 48 MHz),
   a ne takt probne izvedbe v72 na 25 MHz. Modelirati status i sigurno
   resetiranje pri neuspjehu.
#. Izraditi završnu pakiranu primarnu sliku s ``--reconfig`` i
   ``--bootaddr 2101248`` (``0x201000``). Generirati ROM od 27 bajtova
   iz te točne završne pakirane slike. Ponavljati sintezu, postavljanje/
   usmjeravanje, pakiranje i provjeru izvedene naredbe do ograničene,
   točne fiksne točke. Odbaciti zastarjeli ROM, pogrešan CRC, pogrešnu
   adresu pokretanja, regresiju vlasništva pinova, nedostajuće taktne
   bitove ili izostanak konvergencije.
#. Testirati integrirani Wishbone handshake, prijelaz pinova u stanje
   visoke impedancije, valne oblike EN/VALID, završni pakirani ROM,
   potpuno čitanje izvornog sektora, izolaciju DFU načina i ponašanje
   USB-a. Usmjeravanje izvesti lokalno za **48 MHz** uz fiksiranu verziju
   alata; uspjeh minimalne v72 izvedbe na 25 MHz ne potvrđuje taj dizajn.
#. Čuvati potpune sigurnosne kopije flasha v63c i v72, za svakog kandidata
   koristiti postojeći zaštićeni postupak JTAG instalacije/provjere/obnove
   i ne mijenjati zaštićene sekundarne sektore. Hardversko prihvaćanje
   zahtijeva normalan hladni start s pomičnim LED uzorkom i hladni start
   s pritisnutim BTN2 koji dovodi do trajne DFU enumeracije ``1D50:614B``
   **nakon otpuštanja BTN2**, zatim provjere sektora samo čitanjem i
   izričito odobrene DFU testove upisa.

Ovo je tehnički plan integracije, **ne** dopuštenje za programiranje
kombiniranog kandidata. v72 nema DFU, a nijedan kombinirani kandidat na
48 MHz još nije kvalificiran. Ako se v72 proba zadrži za dodatna mjerenja,
ne smije se tvrditi da postoji USB oporavak. Prije povratka u uobičajeni
razvoj DFU-a obnovite točnu primarnu sliku v63c kroz spremljenu JTAG
sesiju oporavka.

Reference
---------

* `Izvorni kod TinyDFU ULX5M <https://github.com/pu-cc/tinydfu-bootloader/tree/master/boards/ulx5m>`_
  (``mkcmd.py`` i registrirani kontroler u ``tinydfu_ulx5m.v``).
* `Cologne Chip UG1001, odjeljak 7.6 <https://www.colognechip.com/docs/ug1001-gatemate1-primitives-library-latest.pdf>`_
  (ograničenja ``CC_CFG_CTRL``).
* Lokalni izvori, testovi i alati v72 u ``bootloader-serv/``; lokalni
  ``manifest.json`` sesije v72c i neovisno opaženi rezultat na LED-ovima.

Nastavak integracije SERV/DFU v73 (28. listopada 2026.)
-------------------------------------------------------

Primarna slika v72 može ostati instalirana dok se kombinirani kandidat v73
gradi izvan mreže; za razvoj nije potrebno obnavljati v63c. v72 nema USB
DFU pa oporavak i dalje ovisi o JTAG-u dok integrirani kandidat ne prođe
oba načina fizičkog prihvaćanja. Izgradnja v73 reproducira poznatu
registriranu statusnu naredbu iz **konačne kombinirane SERV primarne
slike**, a ne iz ROM-a v72, te pakira samo eksperimentalni kandidat.
Nemojte ga programirati dok novi A/B instalacijski alat s fiksiranim
SHA vrijednostima ne bude kvalificiran za trenutačno stanje flasha v72.
Lokalni koraci izgradnje i prihvaćanja navedeni su u
``bootloader-serv/README_ULX5M_GS_V73_INTEGRATION_20261028.md``.
