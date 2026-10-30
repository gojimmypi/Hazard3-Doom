ULX5M-GS SERV bootloader: instalacija, rad i oporavak
=====================================================

.. important:: Stanje provjerenih funkcija

   Trajni primarni bitstream sa sjemenom 160 provjeren je na pločici
   ULX5M-GS V005 za USB DFU (BTN2 pritisnut pri pokretanju) i autonomno
   pokretanje sekundarne slike (BTN2 otpušten). Opcijski firmver ``FWTF``
   provjeren je na stvarnom hardveru samo za USB enumeraciju i **čitanje**
   flash memorije nakon privremenog učitavanja putem JTAG-a. Programiranje,
   brisanje i završna provjera cijele slike putem USB-a **nisu** još
   potvrđeni na hardveru. Nema atomskog povratka na prethodnu sliku.

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
   * - USB upis cijele sekundarne slike
     - Nije provjeren na hardveru
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

``FWTN``
   Zadani ograničeni profil, instaliran kao trajni primarni bitstream.
   USB pokretanje i čitanje flasha provjereni su na hardveru.
   Ispitni zapisivač ograničen je na 4 KiB.

``FWTF``
   Opcijski profil uz ``DFU_FULL_IMAGE=1``. DFU prijemnik, granice upisa,
   brisanje, programiranje i povratno čitanje prošli su emulacijske testove.
   Nakon privremenog JTAG učitavanja na hardveru se enumerirao kao USB
   i pročitao sekundarnu sliku. **Nije potvrđen stvarni USB upis cijele
   slike.**

Eksperimentalni protokol zahtijeva pravilnim redom poslane DNLOAD
blokove od 64 bajta, CRC32 toka, izričite ARM/STATUS/FINISH kontrole i
nezavisno povratno čitanje. SHA-256 usporedba na hostu provjerava
jednakost bajtova, ali nije mehanizam autentičnosti ni potpisa.
Samo ``dfu-util -D`` nije kvalificirana procedura ažuriranja.
Host alat odbija destruktivni zapis s profilom ``FWTN``.

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

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   ../bin/openFPGALoader.exe -c tigard --freq 1000k --detect
   ../bin/openFPGALoader.exe -c tigard --freq 1000k -m \
     "$(wslpath -w "$PWD/build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit")"

Provjerite IDCODE ``0x20000001`` i ``Load SRAM via JTAG: 100%``.
Opcija ``-m`` je privremena; **nemojte koristiti ``-f``**.
Pričekajte Windows USB uređaj ``1D50:614B``.

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
potreban vanjski JTAG/flash. Dugotrajna sinkrona FINISH provjera (čitanje
slike i pretraga preostalih sektora) mora proći stvarne vremenske USB
testove prije prvog zapisa. Ovaj vodič ne odobrava destruktivne naredbe.

Rješavanje problema
-------------------

* **Nema JTAG detekcije:** SW1 ON/ON, uključiti ULX5M prije Tigarda,
  1,8 V logika, zajednička masa, IDCODE ``0x20000001``.
* **JTAG učitavanje uspije, USB nedostaje:** držati BTN2 tijekom cijelog
  učitavanja; D4 upaljena i D3 ugašena znače DFU.
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
* SRAM-isprobani primarni ``FWTF``: SHA-256
  ``6c1bb2b8219f9b0c69c56725467b9a6c40f80a3a5caf6262dfe5769842528c97``.
* Poznata sekundarna slika: 3026 bajtova; SHA-256
  ``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``.
* Dvije identične početne kopije flasha (4 MiB): SHA-256
  ``09542df4b40bb6bcce00a327bb890f6a2d46099eae2e41f7a89e8e602614007d``.
* Oporavak trajnog primarnog bitstreama:
  ``build-ulx5m-gs/flash-install-20261030T155241133153Z``.
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
