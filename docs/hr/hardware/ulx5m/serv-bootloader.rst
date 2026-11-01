ULX5M-GS SERV bootloader: instalacija, rad i oporavak
=====================================================

.. important:: Stanje provjerenih funkcija

   Trajni primarni ``FWTN`` (sjeme 160) potvrđen je za DFU oporavak i
   autonomno pokretanje sekundarne slike. ``FWTF`` v2d, učitan samo u
   SRAM, potvrđen je za USB ponovno pisanje iste sekundarne slike od
   3 026 bajtova, uključujući FINISH, USB povratno čitanje i neovisnu
   JTAG usporedbu cijelog flasha. Ažuriranje nije atomsko; veće slike i
   oporavak nakon prekida nisu kvalificirani.

Ovaj vodič opisuje direktorij ``bootloader-serv/`` projekta Hazard3-Doom
za pločicu Intergalaktik ULX5M-GS **V005**. Mali RV32I procesor SERV
unutar bootloadera nije isto što i procesor Hazard3 koji pokreće Doom.
Provjerena sekundarna aplikacija je primjer s pomičnim LED uzorkom,
a ne Doom.

Dostupne funkcije
-----------------

.. list-table:: Funkcije i razina provjere
   :header-rows: 1
   :widths: 62 38

   * - Funkcija
     - Status
   * - Trajni primarni bitstream, sjeme 160, iz SPI flasha
     - Hardver: PASS
   * - USB DFU s BTN2 pritisnutim i zatim otpuštenim
     - Hardver: PASS (``FWTN``)
   * - Automatsko pokretanje sekundarne slike s ``0x201000``
     - Hardver: PASS (pomični LED uzorak)
   * - USB enumeracija ``1D50:614B``
     - Hardver: PASS (``FWTN`` i SRAM-učitani ``FWTF``)
   * - Čitanje svih 3026 bajtova i provjera SHA-256
     - Hardver: PASS u oba profila
   * - Puni DFU tok i provjera flash memorije
     - Izvanmrežni testovi: PASS
   * - Ponovni upis iste slike od 3 026 bajtova i JTAG provjera 4 MiB
     - Hardver: PASS (``FWTF`` v2d)
   * - Atomsko ažuriranje i automatski povratak
     - Nisu implementirani

Načini pokretanja
-----------------

SW1 bira izvor početne FPGA konfiguracije. BTN2 zatim određuje što radi
primarna konfiguracija. SW1 mijenjajte samo uz isključeno napajanje.

* **SW1 OFF/OFF, BTN2 pritisnut prije uključivanja:** trajna primarna
  konfiguracija učitava se iz SPI flasha i ostaje u USB DFU načinu.
* **SW1 OFF/OFF, BTN2 otpušten:** trajni primarni bitstream pokreće
  izvornu sekundarnu konfiguraciju s adrese ``0x201000``.
* **SW1 ON/ON, BTN2 pritisnut tijekom JTAG učitavanja:** privremeno
  učitavanje ispitnog primarnog bitstreama u SRAM uz izbor DFU načina.

Stanje BTN2 zaključava se pri pokretanju primarne konfiguracije.
Otpuštanje gumba nakon izbora DFU-a ne isključuje USB. Kasniji pritisak
BTN2 ne može prebaciti već zaključani normalni način u DFU.
SW1 OFF/OFF označava aktivni SPI (``0x0``), a ON/ON JTAG (``0xC``).

Pločica koristi referentni takt 25 MHz, nominalnu PLL domenu 48 MHz za
SERV/USB te nezavisni 25 MHz upravljač rekonfiguracije
(``rtl/ulx5m_cfg_autoboot_25.v``). Upravljač oslobađa flash pinove te
šalje GateMate konfiguracijsku naredbu i ``RECFG``. Za autonomno
pokretanje nije potreban aktivni USB ni prijenos aplikacije preko USB-a.
Na ispitanom hardveru sekundarna aplikacija pokrenuta je nakon približno
2,68 sekundi.

.. list-table:: Primarni LED pokazatelji
   :header-rows: 1
   :widths: 18 82

   * - LED
     - Značenje
   * - D7
     - Treperenje kao pokazatelj rada
   * - D6
     - PLL je zaključan
   * - D5
     - Odabir načina pokretanja je zaključan
   * - D4
     - Odabran je DFU
   * - D3
     - Odabran je normalni način
   * - D2
     - Trenutno stanje BTN2
   * - D0, D1
     - Pokazatelji firmvera

U provjerenom trajnom DFU načinu nakon otpuštanja BTN2 svijetle D0/D1,
D2/D3 su ugašene, D4/D5/D6 svijetle, a D7 treperi. Samo treperenje D7
ne dokazuje USB enumeraciju. Sekundarna aplikacija prikazuje zaseban
pomični uzorak LED-ova.

Raspored SPI flash memorije
---------------------------

U9 je AT25QL321 od 4 MiB, JEDEC ``1F 42 16``. Veličina sektora za
brisanje je 4096 bajtova, a stranice za programiranje 256 bajtova.
Pravila adresiranja za sekundarni DFU su:

.. list-table:: Flash regije
   :header-rows: 1
   :widths: 34 27 39

   * - Raspon adresa
     - Veličina
     - Namjena
   * - ``0x000000..0x07FFFF``
     - 512 KiB
     - **Zaštićeni** trajni primarni bitstream
   * - ``0x080000..0x1FFFFF``
     - 1,5 MiB
     - **Rezerviran** postojeći/nepoznati sadržaj
   * - ``0x200000..0x200FFF``
     - 4 KiB
     - **Rezerviran** sektor kandidata/metapodataka
   * - ``0x201000..0x3FFFFF``
     - 2 093 056 bajtova
     - Sekundarni prostor; opcijski pisac ``FWTF``

Ove granice provodi softver; ne radi se o zaštitnim bitovima flash čipa.
Najveća sekundarna slika ima ``0x1FF000`` bajtova. Host ne može odabrati
proizvoljnu ciljnu adresu upisa. Rezervirane regije nisu slobodan prostor.

.. warning:: Primarna i sekundarna .bit datoteka nisu iste

   ``build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit``
   sadrži **primarni bootloader**, ne sekundarnu sliku za DFU.
   Sekundarna slika mora biti zasebno pakirana GateMate konfiguracija
   namijenjena adresi ``0x201000``. Lokalni referentni primjer
   ``build-ulx5m-gs/native-v41-secondary-3026.bit`` izdvojen je iz
   provjerene flash kopije; ne nastaje automatski pri novom build-u.

SERV procesor i njegov firmver smješteni su u unutarnju blokovsku RAM
memoriju FPGA-a. Wishbone sabirnica povezuje status/LED/tipke
(``0x80000000``), UART (``0x81000000``), USB (``0x82000000``),
RAM USB krajnjih točaka (``0x83000000``) i SPI upravljač
(``0x84000000``). Konfiguracijski upravljač ima vlastitu
sinkronizaciju i signal potvrde.

USB i profili firmvera
----------------------

Puni USB brzinski način koristi VID:PID ``1D50:614B`` i razred,
podrazred i protokol ``FE/01/02``. DFU DNLOAD blokovi imaju najviše
64 bajta i prolaze kroz kontrolnu krajnju točku EP0, bez zasebne
bulk krajnje točke. Naziv proizvoda u deskriptoru je
``ULX5M-GS FPGA (DFU Probe)``. Windows može zadržati staro ime ULX4M,
pa uređaj prepoznajte po VID:PID i stvarnom deskriptoru.

``FWTN`` i ``FWTF`` su četveroznakovni ASCII **identifikatori profila
firmvera**, a ne nazivi datoteka, GateMate naredbe ili USB identifikatori.
Nalaze se u bajtovima 0..3 odgovora proizvođačeve naredbe STATUS od
24 bajta (zahtjev ``0x5D``). Označavaju firmver koji odgovara preko USB-a,
a ne sadržaj sekundarne flash slike. Oba profila koriste VID:PID
``1D50:614B``.

``FWTN``
   Zadani ograničeni profil (bez ``DFU_FULL_IMAGE=1``), instaliran kao
   trajni primarni bitstream. USB enumeracija i čitanje sekundarne slike
   provjereni su na hardveru. Testni zapisivač od 4 KiB nije alat za
   ažuriranje cijele slike; host odbija ``--execute`` s tim profilom.

``FWTF``
   Opcijski zapisivač cijele slike (``DFU_FULL_IMAGE=1``), privremeno
   učitan u SRAM putem JTAG ``-m``; nije instaliran u primarni flash.
   Verzija v2d prošla je fizički USB upis 3 026 bajtova, FINISH i
   neovisnu USB provjeru. Dva potpuna JTAG ispisa, povratak na ``FWTN``
   i autonomno pokretanje također su prošli. Oporavak nakon prekida i
   veće slike još nisu provjereni.

Nakon ASCII oznake, STATUS vraća pet 32-bitnih little-endian vrijednosti:
fazu, očekivanu duljinu, očekivani CRC32, broj primljenih bajtova i kod
greške. Faze su ``0`` (nije naoružan), ``1`` (naoružan), ``4`` (provjera
u tijeku), ``2`` (provjereno) i ``3`` (pogreška). Potvrda zahtjeva FINISH
nije potvrda uspjeha; host mora dočekati fazu ``2`` bez pogreške.
SHA-256 uspoređuje bajtove, ali nije provjera autentičnosti potpisa.

Protokol koristi DNLOAD blokove od 64 bajta u zadanom redoslijedu, CRC32
i zahtjeve ARM (``0x5C``), STATUS (``0x5D``) i FINISH (``0x5E``).
``--probe`` prihvaća oba profila i služi samo za **čitanje**;
``--execute`` traži ``FWTF``, izričitu potvrdu i očekivani SHA-256
slike (provjera prije USB pristupa). Sam ``dfu-util -D``
nije zamjena za ovaj zaštićeni postupak ažuriranja.

Preduvjeti
----------

* Preuzmite Hazard3-Doom s pripadajućim fiksiranim podmodulima i koristite
  direktorij ``bootloader-serv/`` (ne stari PicoRV32 ``bootloader/``).
* Za Make, Python, Yosys, nextpnr i Icarus testove koristite WSL/Ubuntu
  ili Linux. Provjerena konfiguracija koristila je OSS CAD Suite
  ``2026-07-20`` i RISC-V bare-metal GCC ``12.2.0``.
* Na provjerenom Windows/WSL računalu WSL **nema** izravan USB pristup.
  Koristite Windows ``py -3`` s PyUSB i ``bin/libusb-1.0.dll``.
  Po potrebi u PowerShellu instalirajte
  ``py -3 -m pip install pyusb``.
* Za JTAG koristite izvorni Windows ``bin/openFPGALoader.exe`` v1.2.0
  i Tigard s 1,8 V logičkim razinama, zajedničkom masom i odspojenim VTGT.
  Nemojte mijenjati upravljačke programe samo radi WSL ``lsusb``.
* Provjerite naponske domene i upozorenja za V005 u :doc:`index`.

Izgradnja i provjera u WSL-u
----------------------------

Naredbe se pokreću iz ``bootloader-serv/``:

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   make -f Makefile.ulx5m-gs show-settings
   make -f Makefile.ulx5m-gs test
   make -f Makefile.ulx5m-gs build SEED=160
   make -f Makefile.ulx5m-gs qualify SEED=160

Zadana izgradnja odabire ograničeni profil ``FWTN``. Za eksperimentalni
``FWTF`` profil treba izričito odabrati:

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   make -f Makefile.ulx5m-gs build SEED=160 DFU_FULL_IMAGE=1
   make -f Makefile.ulx5m-gs qualify SEED=160 DFU_FULL_IMAGE=1

Izlazna datoteka primarne konfiguracije je
``build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit``.
Build izvodi i provjerava GateMate konfiguracijsku naredbu od 27 bajtova
za **točno taj konačni bitstream**. Uspješan P&R ne znači da USB i
pokretanje rade na fizičkom uređaju. Sjeme 160 je povijesna referenca,
ne jamstvo za izmijenjeni firmver.

Privremeno JTAG učitavanje u SRAM
---------------------------------

Isključite napajanje ULX5M-a i Tigarda. Postavite SW1 ON/ON, pritisnite
BTN2, uključite napajanje ULX5M-a te zatim Tigarda. **Držite BTN2
pritisnut tijekom cijelog JTAG učitavanja i dok se ne upali D4.** Nakon
otpuštanja D4 mora ostati upaljena, a D3 ugašena. Naknadni pritisak BTN2
ne mijenja već zaključani način.

Oba redoslijeda uključivanja (Tigard prvi ili ULX5M prvi) bila su uspješna;
nijedan nije utvrđen kao obvezan. Dovršen JTAG prijenos ne dokazuje da
firmver radi. Ako LED-ovi ostanu ugašeni ili USB nije dostupan, isključite
**oba** uređaja, pokušajte obrnuti redoslijed i držite BTN2 tijekom
konfiguracije. Prije pristupa flashu potvrdite D4 upaljenu, D3 ugašenu i
USB vezu. Uzrok osjetljivosti na redoslijed napajanja nije utvrđen.
Tigard VTGT mora ostati nepovezan, uz zajedničku masu. Ne prekidajte
napajanje tijekom brisanja ili pisanja flasha.

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   ../bin/openFPGALoader.exe -c tigard --freq 1000k --detect
   ../bin/openFPGALoader.exe -c tigard --freq 1000k -m \
     "$(wslpath -w "$PWD/build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit")"

Provjerite IDCODE ``0x20000001`` i ``Load SRAM via JTAG: 100%``.
Opcija ``-m`` je privremena; **nemojte koristiti ``-f``**.
Pričekajte Windows USB uređaj ``1D50:614B``.

JTAG učitavanje u SRAM sa SW1 ON/ON nije ispitivanje pokretanja iz
SPI flash memorije nakon hladnog uključenja. GateMate pri resetiranju
pamti konfiguracijski način; JTAG način ne pokreće automatski sliku
iz SPI flash memorije. Kad je BTN2 otpušten, D3 uključen, D4 isključen
i D7 treperi, primarni firmver je odabrao normalni način, ali to ne
potvrđuje predaju sekundarnoj slici. Izostanak hodajućih LED-ova
sam po sebi nije dokaz regresije. Autonomno pokretanje provjerite
odvojenim hladnim uključenjem sa SW1 OFF/OFF i otpuštenim BTN2; time
se provjerava instalirani ``FWTN``, a ne ``FWTF`` učitan u SRAM.
Ne mijenjajte SW1 dok je pločica pod napajanjem.

USB provjera samo čitanjem
--------------------------

Potreban je zasebno spremljeni i provjereni izvorni sekundarni bitstream
koji odgovara stvarnoj flash memoriji. Sljedeći naziv je **lokalan** i
ne postoji automatski nakon čiste izgradnje:

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   sha256sum build-ulx5m-gs/native-v41-secondary-3026.bit
   python3 tests/ulx5m_dfu_update.py \
     --image build-ulx5m-gs/native-v41-secondary-3026.bit

Druga naredba radi samo izvanmrežnu prethodnu provjeru. Poznati SHA-256
sekundarne slike je
``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``.
Za USB pristup koristite **Windows Python** pokrenut iz WSL-a:

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   SCRIPT_WIN="$(wslpath -w "$PWD/tests/ulx5m_dfu_update.py")"
   IMAGE_WIN="$(wslpath -w "$PWD/build-ulx5m-gs/native-v41-secondary-3026.bit")"
   BIN_WIN="$(wslpath -w "$PWD/../bin")"
   powershell.exe -NoProfile -Command \
     "\$env:PATH='$BIN_WIN;' + \$env:PATH; py -3 '$SCRIPT_WIN' --image '$IMAGE_WIN' --probe"

Uspjeh prikazuje ``Device profile FWTN`` ili ``FWTF``, potom
``Verified 3026/3026 bytes`` i odgovarajući SHA-256. Naredba ``--probe``
**ne šalje ARM, erase, program, FINISH ni RECFG**. Ne koristite
``--execute`` u početnom postupku.

Kontrolirano sekundarno ažuriranje (eksperimentalno)
----------------------------------------------------

Referentni postupak ponovno programira poznatu sekundarnu sliku od
3 026 bajtova u sektoru ``0x201000..0x201FFF``, bez instaliranja trajnog
primarnog bootloadera. Ažuriranje je **na istome mjestu**, bez atomskog
dovršetka ili automatskog povratka. Svaki destruktivni zapis zahtijeva
izričito odobrenje korisnika.

Prije upisa sačuvajte dvije neovisne i identične kopije cijelog flasha
od 4 MiB. SHA-256 referentnog stanja je
``3aa6280fd96de3c00ef844a2f0298a919f7cea9311d5a267ee0be85bc4375c78``
(``../ulx5m-prewrite-readonly-20261030-FN1nVy/``); buduće stanje može
biti različito. Provjerite SHA-256 primarnog i sekundarnog bitstreama,
izbrisani raspon ``0x201BD2..0x3FFFFF`` za referentnu sliku i očuvanje
zaštićenih regija.

S uključenim SW1 ON/ON i neprekidno pritisnutim BTN2 učitajte ``FWTF``
v2d u SRAM isključivo JTAG opcijom ``-m``. Provjera samo čitanjem
``--probe`` mora potvrditi ``FWTF``, JEDEC ``1F 42 16`` i svih
3 026 bajtova. ``FWTF`` ne smije se instalirati u primarni flash.

Nakon zasebnog odobrenja, sljedeća je naredba **destruktivna** i koristi
postojeći Windows Python alat:

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   SCRIPT_WIN="$(wslpath -w "$PWD/tests/ulx5m_dfu_update.py")"
   IMAGE_WIN="$(wslpath -w "$PWD/build-ulx5m-gs/native-v41-secondary-3026.bit")"
   BIN_WIN="$(wslpath -w "$PWD/../bin")"
   EXPECTED_SHA256="68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
   powershell.exe -NoProfile -Command \
     "\$env:PATH='$BIN_WIN;' + \$env:PATH; py -3 '$SCRIPT_WIN' --image '$IMAGE_WIN' --execute --confirm REPLACE-SECONDARY-0x201000 --expected-sha256 '$EXPECTED_SHA256'"

Nakon odobrenog zapisa zahtijevajte uspješan FINISH i neovisno USB čitanje
koje odgovara SHA-256 vrijednosti poslane slike. SHA-256 referentne
sekundarne slike je
``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``.
Host ne šalje naredbu FPGA RECFG.

Zatim neovisno pročitajte svih 4 MiB preko JTAG-a čitajućim API-jem
``detect()``/``dump()`` iz ``tests/ulx5m_flash_install.py``. Pri ponovnom
upisu iste referentne slike cijeli flash mora odgovarati početnom stanju
(SHA-256 ``3aa6280fd96de3c00ef844a2f0298a919f7cea9311d5a267ee0be85bc4375c78``).
Za različitu sliku provjerite novi zapis i očuvanje svih ostalih bajtova.
Provjerite DFU ``FWTN`` uz BTN2 pritisnut pri uključivanju, a zatim
sekundarno pokretanje uz BTN2 otpušten, oba sa SW1 OFF/OFF. Samo upis
iste referentne slike prošao je te fizičke provjere.

Ako bilo što ne uspije, sačuvajte zapisnike; nemojte automatski ponoviti
zapis ili pokušati normalno pokretanje. Koristite zlatni DFU uz BTN2.

Trajni povratak i oporavak
--------------------------

Nakon SRAM testa isključite oba uređaja, postavite SW1 OFF/OFF i ostavite
Tigard isključenim. Držite BTN2 prije uključivanja ULX5M-a i otpustite
kad se pojavi DFU LED uzorak. USB provjera mora ponovno prepoznati
``FWTN``. Pri drugom hladnom pokretanju BTN2 ostaje otpušten, a
sekundarna aplikacija treba prikazati pomične LED-ove.

Upis novog trajnog primarnog bitstreama je zaseban **destruktivan servisni
postupak**. JTAG ``-m`` ga ne instalira. Za već pripremljenu flash memoriju
postoje zaštićeni alat ``tests/ulx5m_flash_install.py``, sigurnosne kopije,
provjere primarne regije i kontrolirani povratak. To **nije** postupak
inicijalnog programiranja prazne pločice. Sačuvajte dvije nezavisne kopije
cijele flash memorije od 4 MiB i točne SHA-256 vrijednosti.

Ažuriranje ``FWTF`` prepisuje sekundarnu sliku **na istome mjestu**.
Prekid napajanja može je učiniti neispravnom. Ako primarna konfiguracija
ostane ispravna, BTN2 pri uključivanju omogućuje DFU oporavak; inače je
potreban vanjski JTAG/flash. U verziji v2d DNLOAD obrada odvija se izvan
USB povratnih poziva, a FINISH provjerava sliku postupno bez brisanja
preostalih sektora. Čekanje WIP stanja pri brisanju i programiranju još
je sinkrono te može odgoditi USB obradu. Najdulja trajanja USB usluge,
veće slike i oporavak nakon prekida nisu kvalificirani. Ovaj vodič ne
odobrava destruktivni zapis.

Rješavanje problema
-------------------

* **Nema JTAG detekcije:** SW1 ON/ON, isključiti oba uređaja pa isprobati
  oba redoslijeda napajanja; 1,8 V, zajednička masa, IDCODE ``0x20000001``.
* **JTAG učitavanje uspije, USB nedostaje:** provjeriti BTN2 i LED-ove;
  ako su svi ugašeni, isključiti oba uređaja i promijeniti redoslijed.
  D4 upaljena i D3 ugašena znače DFU.
* **Windows prikazuje stari naziv ULX4M:** provjeriti VID:PID i stvarni
  ``ULX5M-GS FPGA (DFU Probe)`` deskriptor.
* **WSL ne vidi USB:** koristiti Windows Python preko PowerShella.
* **Nedostaje PyUSB/libusb:** provjeriti Windows ``py -3``, ne samo WSL.
* **Prijavljen je ``FWTN`` umjesto ``FWTF``:** provjeriti učitani bitstream
  i njegovu SHA-256 vrijednost.
* **Slika ne prolazi preflight:** koristiti izvorni sekundarni bitstream,
  ne primarni ``PACK-ONLY.bit``.
* **Prekinuto ažuriranje:** bez pretpostavke automatskog povratka;
  koristiti BTN2 DFU ili vanjski oporavak.

Referentne kontrolne vrijednosti
--------------------------------

Sljedeće vrijednosti označavaju testiranu konfiguraciju 30. listopada
2026., a ne sve buduće inačice:

* Trajni primarni ``FWTN``: 420 175 bajtova; SHA-256
  ``c41830bd09e0e924facd2425f10a8072878e59505d12b82aff533be7df8cfe27``.
* SRAM-isprobani primarni ``FWTF`` v2d: 420 175 bajtova; SHA-256
  ``c73b8d6fe1ac1150ad3e3bba72c6d64664ee495185fade339f188f628dcfe167``.
* Poznata sekundarna slika: 3026 bajtova; SHA-256
  ``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``.
* Dvije neovisne kopije prije zapisa (4 MiB): SHA-256
  ``3aa6280fd96de3c00ef844a2f0298a919f7cea9311d5a267ee0be85bc4375c78``;
  ``../ulx5m-prewrite-readonly-20261030-FN1nVy/``.
* Dvije kopije nakon JTAG provjere (4 MiB): isti SHA-256;
  ``../ulx5m-postwrite-readonly-20261030-fiHyVE/``.
* Ruta sjemena 160: Fmax 67,96 MHz (domena 25 MHz) i
  49,06 MHz (domena 48 MHz).

Oba profila koriste isti izlazni naziv datoteke. Prije bilo kakvog
programiranja JTAG-om ili u flash provjerite SHA-256.

Povezana dokumentacija
----------------------

* :doc:`index` - naponska i hardverska upozorenja za V005.
* :doc:`bringup` - zapis fizičkih ispitivanja.
* :doc:`multiboot-v72` - povijesni pokus s rekonfiguracijom.
* :doc:`../../user-guide/bootloader` - raniji postupci ULX3S/ULX4M;
  ne primjenjivati njihove flash adrese na V005.
