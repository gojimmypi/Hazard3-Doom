Web Serial konzola i HDMI snimka zaslona
========================================

Hazard3-Doom uključuje pregledničku konzolu bez dodatnih ovisnosti u direktoriju
``web/``. Koristi preglednički Web Serial API za izravnu komunikaciju s UART-om
pločice i može zatražiti i snimku zaslona od podržanih HDMI aplikacija.

Ista web-aplikacija sadrži i zaseban WebUSB FPGA programator za ULX3S ``US1``
FT231X JTAG sučelje. Web Serial i WebUSB neovisni su transporti: UART konzola
ostaje na svojem serijskom adapteru, dok FPGA programator komunicira s JTAG-om.
Pogledajte :doc:`web-flasher`.

Put snimke zaslona ne snima TMDS, ne čita piksele natrag s fizičkog HDMI
priključka i ne zahtijeva poslužitelj. Aktivna firmware aplikacija šalje
indeksirani izvorni okvir i paletu putem UART-a. JavaScript lokalno rekonstruira
cijeli aktivni HDMI raster i preuzima ga kao PNG.

Datoteke web-aplikacije
-----------------------

Preglednička aplikacija implementirana je datotekama:

.. code-block:: text

   web/index.html
   web/app.js
   web/styles.css

``index.html`` sadrži kontrole, ``app.js`` upravlja Web Serial transportom i
protokolom snimke zaslona, a ``styles.css`` definira izgled korisničkog sučelja.

Stranica je statična. U putu snimke zaslona nema JavaScript package managera,
frameworka, backenda ni cloud usluge.

Zahtjevi za preglednik i posluživanje
-------------------------------------

Web Serial zahtijeva preglednik koji izlaže ``navigator.serial`` i siguran
kontekst. ``localhost`` je prihvatljiv za lokalni razvoj, a HTTPS je prikladan
za hostanu upotrebu poput GitHub Pagesa.

Jednostavan lokalni poslužitelj može se pokrenuti iz direktorija ``web/``:

.. code-block:: bash

   python3 -m http.server 8000

Zatim otvorite ``http://localhost:8000/`` u pregledniku koji podržava Web Serial.

Uobičajene Hazard3-Doom UART postavke su:

.. code-block:: text

   115200 baud
   8 data bits
   no parity
   1 stop bit
   no flow control

Web konzola izlaže te serijske postavke u korisničkom sučelju i sprema
korisničke postavke u preglednikov ``localStorage``.

Pregled snimke zaslona
----------------------

Kontrola **Screen snip** preuzima trenutačnu podržanu HDMI aplikaciju kao puni
PNG ``1024x600``. Implementacija je podijeljena u tri sloja:

#. Preglednik ispituje aktivnog korisnika UART-a kako bi utvrdio podržava li
   snimku zaslona.
#. Rezidentni monitor (kada je njegova predmemorirana testna slika valjana),
   Doom ili I2CDriver HDMI GUI serijalizira svoju indeksiranu izvornu sliku i
   RGB332 paletu preko UART-a.
#. Preglednik izdvaja binarni prijenos iz terminalskog toka, proširuje indeksirani
   izvor na oglašenu veličinu zaslona, kodira PNG pomoću Canvas API-ja i pokreće
   lokalno preuzimanje.

Trenutačni rezidentni monitor također može biti pružatelj snimke zaslona. Nakon
uspješnog prikaza monitorskog testnog uzorka sprema provjerenu predmemoriranu
kopiju tog RGB332 okvira u rezervirani SDRAM i na zahtjev može serijalizirati tu
predmemoriju. Doom i I2CDriver HDMI GUI imaju vlastite implementacije aktivnog
zaslona. Učitana, ali nepokrenuta ``.h3d`` slika ne pruža sposobnost samo zato
što je prisutna u SDRAM-u.

Otkrivanje sposobnosti
----------------------

Povezan serijski priključak nije dovoljan za omogućavanje snimke zaslona.
Preglednik koristi mali dogovor o sposobnosti kako bi gumb odražavao firmware
način koji trenutačno prima UART ulaz.

Rezervirani bajtovi su:

.. list-table::
   :header-rows: 1
   :widths: 18 24 58

   * - Bajt
     - Naziv
     - Značenje
   * - ``0x1c``
     - Upit sposobnosti
     - Preglednik ga šalje kako bi pitao podržava li aktivni firmware zaslon protokol snimke zaslona.
   * - ``0x06``
     - ACK sposobnosti
     - Vraća ga trenutačni monitor kada je njegova predmemorirana slika valjana ili podržana Doom/I2CDriver HDMI implementacija. Preglednik troši ovaj bajt i ne prikazuje ga u terminalu.
   * - ``0x1d``
     - Zahtjev za snimanje
     - Šalje se tek nakon potvrde sposobnosti. Aktivni pružatelj zaslona odgovara okvirom ``H3SNIP1``.

Pojedinačni upit sposobnosti čeka ACK najviše 750 ms. Oko prijelaza u radu,
primjerice pri pokretanju Dooma, web-aplikacija zadržava dulji prozor ponovnog
stjecanja i ponavlja upite dok se novi korisnik UART-a inicijalizira. Time se
sprječava da prerani upit tijekom pokretanja Dooma trajno ostavi gumb isključenim.
Zahtjev za snimanje šalje se tek nakon potvrde sposobnosti.

Stanje snimke zaslona prikazuje se i omogućavanjem gumba i tekstom pri prelasku
pokazivača:

.. list-table::
   :header-rows: 1
   :widths: 25 25 50

   * - Stanje
     - Gumb
     - Značenje pri prelasku/status
   * - Nema serijske veze
     - Onemogućen
     - Najprije se povežite s pločicom.
   * - Provjera
     - Onemogućen
     - Upit sposobnosti je u tijeku.
   * - Nepodržano / nema valjane snimke
     - Onemogućen
     - Trenutačni korisnik UART-a nije prijavio valjan izvor snimke.
   * - Podržani monitor/Doom/I2C zaslon
     - Omogućen
     - Prijavljeni HDMI izvor može se preuzeti kao PNG ``1024x600``.
   * - Snimanje u tijeku
     - Onemogućen, označen ``Capturing...``
     - Trenutačno se prima binarni prijenos zaslona.

HTML omata onemogućeni gumb zasebnim elementom koji prima hover. Onemogućeni
HTML gumbi ne primaju pouzdano pointer događaje, pa omot ima tekst ``title`` i
ostaje dostupan pokazivaču čak i kada se gumb ne može kliknuti.

Kada se sposobnost ponovno provjerava
-------------------------------------

Preglednik ispituje sposobnost kada se otvori serijska veza. Također zakazuje
novi upit nakon naredbi koje mogu promijeniti koji firmware zaslon upravlja
UART-om:

.. code-block:: text

   i2c gui
   sao gui
   j
   b

Jednoznakovne naredbe za pokretanje koriste dulju odgodu od GUI naredbi kako bi
nova aplikacija stigla preuzeti kontrolu prije dolaska upita.

Ako snimka trenutačno nije dostupna, pomicanje pokazivača preko kontrole Screen
snip pokreće novi upit. Tako se korisničko sučelje automatski oporavlja ako se
firmware način promijenio putem koji preglednik nije uočio.

Kontrola **Stop Doom** ``Ctrl-X`` i kontrola ``Q`` I2C GUI-ja pokreću ponovno
stjecanje sposobnosti jer te operacije vraćaju vlasništvo nad UART-om
rezidentnom monitoru. Monitor može vratiti ACK ako je njegova predmemorirana
slika i dalje valjana. Klik na **Screen snip** također izvodi završnu provjeru
sposobnosti prije slanja ``0x1d``. To štiti od zastarjelog stanja korisničkog
sučelja ako se aktivni firmware promijenio nakon posljednjeg uspješnog upita.

UART usmjeravanje naredbi i tipka ``H``
---------------------------------------

Rezidentni monitor obrađuje rezervirani upit sposobnosti ``0x1c`` i zahtjev za
snimanje ``0x1d`` prije obične obrade naredbi konzole. Uobičajene ispisive tipke
ostaju nepromijenjene; posebno, monitor zadržava ``H`` kao tipku Help::

   case 'h':
   case 'H':
   case '?':
       console_print_help();
       break;

Kada je ``i2c gui`` aktivan, ``hazard3_sao_console_feed(received)`` prima UART
bajt prije switcha rezidentnog monitora i troši GUI tipke poput ``H``. Privatna
pomoćna funkcija I2C GUI-ja ``toggle_resolution()`` označena je ``static`` u
``src/i2cdriver_hdmi.c`` i ne smije se pozivati iz ``src/main.c``. Takav poziv
stvorio bi nedefiniranu linker referencu; nevaljano je i vraćanje vrijednosti iz
``console_poll()``, koji vraća ``void``.

Doom i I2C GUI također presreću ``0x1c`` i ``0x1d`` unutar svojih aktivnih
ulaznih putova, pa sposobnost prati onaj runtime koji trenutačno posjeduje UART
ulaz. I2C GUI mora vratiti ACK na ``0x1c`` i implementirati ``0x1d``; u suprotnom
preglednik ispravno ostavlja **Screen snip** onemogućenim iako rukovatelj snimke
postoji.

Protokol na vezi
----------------

Nakon primitka ``0x1d`` firmware zapisuje ASCII zaglavlje završeno s ``CR LF`` i
odmah zatim zapisuje binarni payload.

Gramatika zaglavlja je:

.. code-block:: text

   H3SNIP1 <source_width> <source_height> <display_width> <display_height> IDX8 <palette_bytes> <pixel_bytes>\r\n

Trenutačni firmware šalje vodeći ``CR LF`` prije ``H3SNIP1`` kako bi se obični
UART tekst vizualno odvojio od zaglavlja protokola. Preglednik prihvaća i
prosljeđuje prethodne obične tekstualne retke dok ne vidi valjani ``H3SNIP1``
redak.

Za trenutačne Hazard3-Doom ciljeve ``display_width`` i ``display_height`` su
``1024`` i ``600``. ``palette_bytes`` mora biti točno ``256``, a ``pixel_bytes``
mora biti jednak ``source_width * source_height``.

Preglednik odbija nevaljana zaglavlja, izvorne slike veće od 1.000.000 piksela i
slike zaslona veće od 4.000.000 piksela. Samo zaglavlje također je ograničeno na
1024 bajta dok snimanje čeka valjani redak odgovora.

Binarni payload
---------------

Binarni payload neposredno nakon zaglavlja sastoji se od:

#. 256 bajtova podataka RGB332 palete.
#. ``source_width * source_height`` bajtova indeksiranih piksela poredanih po redovima.

Nema binarnog završetka ni terminatora. Veličine u provjerenom zaglavlju govore
pregledniku točno koliko bajtova treba potrošiti. Svi kasniji UART bajtovi vraćaju
se u uobičajenu obradu terminala.

Trenutačni identifikator protokola ``IDX8`` opisuje prikaz na vezi, a ne nužno
pakiranje framebuffer-a pružatelja u memoriji. Svaki preneseni piksel zauzima
jedan bajt i indeks je palete od 0 do 255.

Trenutačni načini izvora
------------------------

.. list-table::
   :header-rows: 1
   :widths: 22 18 18 18 24

   * - Pružatelj/način
     - Geometrija izvora
     - Bajtovi piksela
     - Binarni bajtovi s paletom
     - Napomene
   * - Standardni Doom
     - ``320x200``
     - ``64000``
     - ``64256``
     - Izvorni Doom indeksirani izvor.
   * - Doom prikaz visoke razlučivosti
     - ``400x240``
     - ``96000``
     - ``96256``
     - Doom i dalje iscrtava ``320x200``; firmware prije serijalizacije snimke primjenjuje isto proširenje koje koristi HDMI prikazni put.
   * - I2CDriver kompatibilnost
     - ``320x200``
     - ``64000``
     - ``64256``
     - 8-bitni indeksirani izvor kompatibilan s EBR-om.
   * - I2CDriver 400 testni način
     - ``400x240``
     - ``96000``
     - ``96256``
     - Opcionalni usporedni način visoke razlučivosti.

Primjeri zaglavlja su:

.. code-block:: text

   H3SNIP1 320 200 1024 600 IDX8 256 64000
   H3SNIP1 400 240 1024 600 IDX8 256 96000

Format RGB332 palete
--------------------

Svaki bajt palete je ``RRRGGGBB``:

.. code-block:: text

   bits 7..5   red,   3 bits
   bits 4..2   green, 3 bits
   bits 1..0   blue,  2 bits

Preglednik proširuje komponente na 8-bitni RGB istom semantikom ponavljanja
bitova koju koristi video put:

.. code-block:: text

   R8 = (R3 << 5) | (R3 << 2) | (R3 >> 1)
   G8 = (G3 << 5) | (G3 << 2) | (G3 >> 1)
   B8 = B2 * 0x55

Doom šalje svih 256 trenutačnih stavki palete nakon pretvorbe u RGB332.
I2CDriver UI trenutačno koristi 16 logičkih boja; stavke 0 do 15 sadrže UI paletu,
a stavke 16 do 255 šalju se kao nula, u skladu s ponašanjem njegove video palete.

Vrijeme Doom snimanja
---------------------

Doom ne serijalizira framebuffer odmah iz svojeg UART ulaznog rukovatelja.
Primitak ``0x1d`` postavlja pending zastavicu. Zahtjev se izvršava nakon sljedećeg
dovršenog ``DG_DrawFrame()`` prikaznog puta, pa se snimka zaslona temelji na
dovršenom okviru, a ne na radnom međuspremniku koji Doom još može mijenjati.

U Doom izgradnji ``400x240`` sam Doom ostaje renderer ``320x200``. Kod za
snimanje primjenjuje isto proširenje izvora koje koristi izravni HDMI prikaz:
16 vodoravnih izvornih piksela postaje 20 izlaznih izvornih piksela, a svaka
skupina od pet izvornih redaka postaje šest redaka. Dobiveni izvor protokola je
točno ``400x240``.

Vrijeme i pakiranje I2CDriver snimke
------------------------------------

I2CDriver HDMI GUI obrađuje ``0x1d`` izravno iz svoje UART petlje događaja.
Serijalizira GUI framebuffer koji predstavlja trenutačni aktivni način izvora.
Kontrolni bajt presreće se prije uobičajene interaktivne obrade tipki, pa se
zahtjev ne tumači kao I2C GUI naredba ili znak upita.

Prijamni put u pregledniku
--------------------------

Uobičajene UART bajtove dekodira trajni ``TextDecoder`` i dodaje ih terminalu.
Prijam snimke zaslona privremeno mijenja samo tumačenje dolaznih bajtova:

#. Dok se čeka zaglavlje, prikupljaju se potpuni tekstualni retci.
#. Retci koji nisu ``H3SNIP1`` zaglavlje vraćaju se terminalu.
#. Nakon valjanog zaglavlja preglednik alocira točno
   ``palette_bytes + pixel_bytes`` bajtova.
#. Ti se bajtovi kopiraju doslovno i nikada ne prolaze kroz dekoder teksta.
#. Nakon primitka točne duljine payloada, svi preostali bajtovi u istom serijskom
   bloku vraćaju se u normalnu obradu terminala.

To razdvajanje je potrebno jer proizvoljni bajtovi framebuffer-a i palete nisu
UTF-8 tekst te mogu sadržavati kontrolne znakove, NUL bajtove ili sekvence koje
bi oštetile izlaz terminala kada bi se dekodirale.

Rekonstrukcija HDMI rastera
---------------------------

Preglednik stvara Canvas u memoriji čije su dimenzije veličina zaslona oglašena
u zaglavlju. Trenutačni firmware oglašava ``1024x600``.

Za svaki piksel zaslona ``(x, y)`` JavaScript odabire odgovarajući izvorni piksel
cjelobrojnim nearest-neighbor mapiranjem:

.. code-block:: text

   source_x = floor(x * source_width / display_width)
   source_y = floor(y * source_height / display_height)

Izvorni bajt koristi se kao indeks u primljenoj RGB332 paleti. Proširena RGB
vrijednost i alpha vrijednost 255 zapisuju se u ``ImageData``. Preglednik zatim
poziva ``canvas.toBlob(..., "image/png")`` i preuzima rezultat.

To znači da snimka zaslona predstavlja aktivni raster zaslona rekonstruiran iz
iste indeksirane izvorne slike, a ne snimku električnih HDMI simbola. Također
znači da preglednik ne mora znati je li firmware izvor došao iz EBR-a, SDRAM-a
ili Doom međuspremnika za proširenje.

Naziv i lokalnost preuzimanja
-----------------------------

Generirani naziv datoteke uključuje rekonstruiranu geometriju zaslona i ISO UTC
vremensku oznaku, primjerice:

.. code-block:: text

   hazard3-doom-hdmi-1024x600-2026-08-19T18-00-00Z.png

Paleta, indeksirani okvir, RGB proširenje, Canvas slika i PNG obrađuju se lokalno
u pregledniku. Web-aplikacija ne šalje snimku zaslona na poslužitelj.

Trošak UART prijenosa
---------------------

Trenutačni transport namjerno je nekomprimiran. Pri 115200 baud i 8-N-1
formatiranju može se prenijeti najviše 11.520 UART podatkovnih bajtova u sekundi
prije softverskog overheada. Približna minimalna vremena binarnog payloada zato
su:

.. list-table::
   :header-rows: 1
   :widths: 25 25 25 25

   * - Izvor
     - Binarni bajtovi
     - Približno minimalno vrijeme
     - Praktični učinak
   * - ``320x200``
     - ``64256``
     - 5.6 s
     - Primjetna pauza dok firmware zapisuje UART podatke.
   * - ``400x240``
     - ``96256``
     - 8.4 s
     - Dulja pauza.

ASCII zaglavlje tim vrijednostima dodaje samo malu količinu podataka. Firmware
tijekom payloada izvodi blokirajući UART tok, pa Doom ili I2C GUI mogu izgledati
pauzirano dok prijenos ne završi. Veličina PNG-a ne utječe na UART vrijeme jer se
PNG kompresija događa tek nakon što indeksirani payload stigne u preglednik.

Timeouti i obrada pogrešaka
---------------------------

Preglednik koristi dva neovisna timeouta:

* Upit sposobnosti: 750 ms.
* Aktivno snimanje zaslona: 30 sekundi.

Parser snimke prijavljuje pogrešku ako je zaglavlje neispravno, deklarirane
veličine nisu dosljedne, zaglavlje postane predugo, serijska veza se izgubi,
zahtjev se ne može zapisati, payload ne završi prije timeouta snimke ili
preglednik ne može kodirati Canvas kao PNG.

Odspajanje prekida aktivno snimanje i vraća sposobnost na nedostupno.

Kompatibilnost i verzioniranje
------------------------------

Stariji Doom ili I2CDriver firmware ne razumije rezervirani upit sposobnosti i
zato ne šalje ``0x06`` ACK. Preglednik to tretira kao nepodržano i ostavlja
Screen snip onemogućenim. Time se sprječava slanje binarnog zahtjeva za snimanje
firmwareu koji bi bajt mogao drukčije protumačiti.

Miješana revizija također može sadržavati implementaciju snimanja ``0x1d`` bez
novijeg dogovora ``0x1c``/``0x06``. Preglednik tu kombinaciju namjerno tretira
kao nedostupnu. UART petlja I2CDrivera mora implementirati i ACK sposobnosti i
obradu zahtjeva za snimanje prije nego što se gumb može omogućiti.

``H3SNIP1`` je oznaka verzije protokola. Promjene zbog kojih bi postojeći parseri
pogrešno protumačili payload trebaju koristiti novu oznaku verzije umjesto tihe
promjene značenja polja ``H3SNIP1``.

Rezidentni monitor ne bi trebao potvrditi ``0x1c`` osim ako zaista ima
kompatibilnog pružatelja snimke zaslona. Sposobnost mora opisivati aktivnog
korisnika UART-a, a ne samo činjenicu da bitstream ima HDMI hardver.

Lokacije implementacije
-----------------------

Glavne točke implementacije su:

.. code-block:: text

   web/app.js
       capability state machine
       raw UART request/ACK handling
       H3SNIP1 parser
       binary payload isolation
       RGB332 expansion
       1024x600 reconstruction
       PNG download

   web/index.html
       Screen snip button and hoverable disabled-state wrapper

   web/styles.css
       disabled-button wrapper pointer behavior

   doom/doomgeneric_hazard3.c
       Doom capability ACK
       deferred capture request
       Doom palette serialization
       320x200 and 400x240 source serialization

   src/i2cdriver_hdmi.c
       I2C GUI capability ACK
       active GUI framebuffer serialization
       GUI palette serialization
       320x200 and 400x240 source handling

Nije potrebna promjena FPGA HDL-a samo zbog Web Serial protokola. Transport
snimke zaslona implementiran je u firmwareu i pregledniku.

Sigurnost i privatnost
----------------------

Preglednik traži od korisnika da odabere i odobri serijski priključak. UART
promet odvija se između odabranog serijskog uređaja i JavaScripta u pregledniku.
Put snimke zaslona stvara lokalni Blob URL samo dovoljno dugo da pokrene
preuzimanje PNG-a, a zatim taj URL opoziva.

Upotreba
--------

#. Poslužite ažurirani direktorij ``web/`` iz sigurnog konteksta ili localhosta.
#. Povežite preglednik s Hazard3-Doom serijskim priključkom na 115200 8-N-1.
#. Pokrenite Doom ili ``i2c gui``/``sao gui`` koristeći firmware koji implementira
   ``H3SNIP1`` i ACK sposobnosti.
#. Pričekajte da se **Screen snip** omogući. Prijeđite pokazivačem preko kontrole
   kako biste vidjeli trenutačno stanje dostupnosti.
#. Pritisnite **Screen snip**.
#. Ostavite serijski priključak povezan dok se binarni prijenos ne dovrši i ne
   započne preuzimanje PNG-a.

Pogledajte :doc:`doom` za ponašanje specifično za Doom, :doc:`i2cdriver` za HDMI
I2C GUI, :doc:`../architecture/video` za prikazni put i
:doc:`../troubleshooting` za uobičajene probleme sa snimkom zaslona.
