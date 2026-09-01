Referenca skripti
=================

Direktorij ``scripts/`` sadrži pomoćne alate na strani hosta za build,
postavljanje, programiranje, debugiranje, provjeru, benchmarking, pregled
izvornog koda i čišćenje koje koristi Hazard3-Doom. Ova stranica opisuje
skripte uključene u repozitorij prema namjeni i objašnjava koji su alati
autoritativni za uobičajene zadatke održavanja.

Većina Bash skripti određuje korijen repozitorija iz vlastite lokacije. Osim
ako skripta ne kaže drukčije, primjeri u nastavku pretpostavljaju da je
trenutačni direktorij korijen repozitorija Hazard3-Doom.

Za kraći sažetak organiziran prema direktoriju pogledajte ``scripts/README.md``
u repozitoriju.

Potpuni buildovi pločica
------------------------

Potpuni omotači za pločice održavaju monitor, FPGA dizajn, Doom sliku i SDRAM
memorijsku mapu međusobno usklađenima.

``scripts/build-ulx3s-doom.sh``
   Potpuni build za ULX3S 85F. Gradi monitor za 50 MHz/64 MiB, priprema
   rezidentnu FPGA boot sliku, gradi ili ponovno koristi 85F bitstream, gradi
   Doom sliku i priprema datoteke za SD-card tijek rada. 85F omotač zadano
   omogućuje proširene HDMI načine; postavite ``HAZARD3_HDMI_EXTENDED_MODES=0``
   za lakši framebuffer profil samo s 320x200.

``scripts/build-ulx3s-12f-doom.sh``
   Potpuni kompaktni build za ULX3S 12F. Zadano koristi memorijski profil od
   32 MiB pri Hazard3 sistemskom taktu od 40 MHz. Mapa od 64 MiB opcionalna je
   kroz ``HAZARD3_MEMORY_PROFILE=64m``. Kompaktni cilj namjerno prihvaća samo
   ``HAZARD3_DOOM_HDMI_RESOLUTION=320x200`` i koristi monitor smješten u SDRAM-u.

``scripts/build-ulx4m-ld-doom.sh``
   Potpuni build za ULX4M-LD 85F. Koristi softversku mapu od 64 MiB pri 40 MHz i prije
   builda monitora, ugrađene boot slike, FPGA bitstreama i Doom slike provjerava
   potrebne generirane LiteDRAM izvore. Trenutačni routed dizajn ima poznate
   timing promašaje za ``clk_sys`` i LiteDRAM, pa koristite
   ``ALLOW_TIMING_FAILURE=1`` kada namjerno generirate trenutačni razvojni
   bitstream.

Primjeri:

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh
   ./scripts/build-ulx3s-12f-doom.sh
   ALLOW_TIMING_FAILURE=1 ./scripts/build-ulx4m-ld-doom.sh

Za testiranje drugog Hazard3 checkouta bez promjene Hazard3-Doom gitlinka:

.. code-block:: bash

   HAZARD3_ROOT=/mnt/c/workspace/Hazard3 \
       ./scripts/build-ulx3s-doom.sh

Pomoćni alati za build monitora i bitstreama
--------------------------------------------

``scripts/build.sh``
   Gradi firmware rezidentnog monitora. Zadano koristi memorijsku mapu od
   64 MiB pri 50 MHz. Važne zamjene uključuju ``HAZARD3_MEMORY_PROFILE``,
   ``HAZARD3_SYS_CLK_HZ``, ``HAZARD3_BUILD_DIR``, ``TOOLCHAIN_PREFIX`` i
   ``HAZARD3_MONITOR_LINKER_SCRIPT``. Izlazi uključuju
   ``hazard3-boot-monitor.elf``, ``.map`` i ``.bin`` u odabranom build
   direktoriju.

``scripts/build-ulx3s-85f-bitstream.sh``
   Ulazna točka specifična za ULX3S 85F za zajednički ECP5 tijek.

``scripts/build-ulx3s-12f-bitstream.sh``
   Ulazna točka specifična za ULX3S 12F za zajednički ECP5 tijek. Zadano koristi
   ``HAZARD3_MEMORY_PROFILE=32m``.

``scripts/build-ulx4m-ld-bitstream.sh``
   Ulazna točka specifična za ULX4M-LD 85F za zajednički ECP5 tijek.

``scripts/build-ecp5-bitstream-common.sh``
   Interna zajednička implementacija sinteze/place-and-routea koju koriste tri
   omotača za bitstream specifična za pločice. Uobičajeno se ne poziva izravno.
   ``ALLOW_TIMING_FAILURE=1`` dopušta generiranje bitstreama uz zadržavanje
   timing promašaja kao vidljivih upozorenja; koristite ga samo za namjerno
   prihvaćenu razvojnu timing iznimku, poput trenutačnog ULX4M-LD cilja.

``scripts/make-boot-hex.py``
   Pretvara binarnu datoteku monitora u heksadecimalnu inicijalizacijsku
   datoteku koju koristi FPGA boot memorija.

``scripts/build-xpack.cmd``
   Native Windows build monitora koji koristi ``bin/riscv-gcc``. Argumenti su
   ``[build|clean|rebuild] [64m|32m] [50000000|25000000]``. Bez argumenata
   gradi monitor za 64 MiB/50 MHz.

Pomoćni alati za Doom i Supercon build
--------------------------------------

``doom/build-doom-image.sh``
   Gradi i pakira povezanu Doom aplikaciju. Monitor i Doom slika moraju koristiti
   isti memorijski profil.

``scripts/build-doom-noncombat.sh``
   Gradi posebnu Supercon noncombat sliku pod ``build/doom-image-noncombat/``.
   Skripta primjenjuje transformaciju samo na pripremljenu kopiju DoomGenerica i
   provjerava marker simbole u rezultirajućim objektnim datotekama.

``scripts/apply-doom-noncombat.py``
   Interna transformacija izvornog koda koju koristi posebni noncombat build.
   Ne mijenja checkoutani DoomGeneric submodul.

``scripts/build-supercon10-wad.py``
   Provjerava i spaja projektni Supercon PWAD s lokalnim ``DOOM1.WAD``. Zadano
   je rezultirajuća kombinirana slika ``wads/SUPERCON10.WAD``.

``scripts/cleanup-supercon-dev.py.bak``
   Zadržana sigurnosna kopija starijeg pomoćnog alata za čišćenje Supercon
   razvojnog okruženja. Nije dio normalnog podržanog tijeka rada.

Placement i routed sweepovi seedova
-----------------------------------

Sweepovi samo za placement brzo rangiraju kandidate. Oni nisu konačan dokaz
timinga. Prije odabira produkcijskog seeda koristite routed sweep.

Za detaljnu arhitekturu sweepa, GitHub Actions parametre, zamrznuti netlist,
live timing monitor, watchdog limite, artifacts i A/B strategiju pogledajte
:doc:`timing-sweeps`.

``scripts/sweep-peek.sh``
   ULX3S 85F nextpnr sweep samo za placement. Zaustavlja se prije routinga. Bez
   argumenta seeda pretražuje konfigurirani raspon; izričiti seed ograničava
   pokretanje. ``SWEEP_JOBS`` upravlja brojem paralelnih placementa, a
   ``HAZARD3_HDMI_EXTENDED_MODES`` odabire 85F video profil.

``scripts/sweep.sh``
   Potpuni ULX3S 85F place-and-route sweep. Prihvaća izričite seedove, popis
   seedova odvojenih zarezom ili ``--all``. ``SWEEP_JOBS`` upravlja paralelnim
   routing poslovima. Routed logovi i bitstreamovi zadržavaju se pod
   ``build/ulx3s-seed-sweep/``.

``scripts/sweep-peek-ulx3s-12f.sh``
   ULX3S 12F sweep samo za placement. Prihvaća izričite seedove ili ``--all``.
   Zadano koristi četiri paralelna posla i profil od 32 MiB. Rezultati se
   zapisuju pod ``build/ulx3s-12f-placement-sweep/<profile>/``.

``scripts/sweep-ulx3s-12f.sh``
   Potpuni routed sweep za ULX3S 12F. Prihvaća izričite seedove ili ``--all``.
   Zadano koristi četiri paralelna routinga i profil od 32 MiB. Routed logovi,
   konfiguracija, SVF, bitstreamovi, metapodaci i CSV rezultati zadržavaju se
   pod ``build/ulx3s-12f-seed-sweep/<profile>/``.

``scripts/sweep-peek-ulx3s-12f-best-peek.sh``
   Pomoćna skripta za nastavak koja pokreće routed sweep za najbolje 12F
   placement kandidate.

``scripts/sweep-ulx4m-ld.sh``
   ULX4M-LD routed seed sweep. Prihvaća jedan seed ili raspon seedova i zadano
   koristi dva paralelna posla.

``scripts/sweep-ecp5.sh``
   Zajednički razdjelnik ciljeva za lokalne i GitHub Actions runove. Ispisuje
   podržane ciljeve, priprema/rješava putanje i poziva routed sweep cilja.

``scripts/sweep-ecp5-common.sh``
   Zajednička nextpnr implementacija. Provjerava placer/router postavke, gradi
   nextpnr argumente, primjenjuje watchdog limite, parsira maksimalne frekvencije
   i zapisuje CSV/metapodatke po seedu.

``scripts/watch-ecp5-sweep-results.sh``
   GitHub live collector. Prati artifacts završenih grupa, ispisuje metrike novih
   seedova, PASS/FAIL/TIMEOUT/OTHER brojeve, trajanja i najbolje maksimalne
   frekvencije po domeni.

``scripts/summarize-ecp5-sweep.py``
   Završni CI agregator. Spaja sve seed grupe sa zamrznutim metapodacima i
   konfiguracijom, generira CSV/Markdown sažetke i provjerava potpunost sweepa.

Primjeri:

.. code-block:: bash

   SWEEP_JOBS=8 ./scripts/sweep-peek.sh
   SWEEP_JOBS=8 ./scripts/sweep.sh --all
   SWEEP_JOBS=30 ./scripts/sweep-peek-ulx3s-12f.sh --all
   SWEEP_JOBS=30 ./scripts/sweep-ulx3s-12f.sh --all
   ./scripts/sweep-ulx4m-ld.sh 1-32

Seed koji je prije bio dobar nije zajamčeno i dalje dobar nakon značajne
promjene RTL-a, takta, cachea, EBR-a ili framebuffer-a.

Inicijalizacija submodula i provjere lokalnog stanja
----------------------------------------------------

``scripts/setup-submodules.sh``
   Inicijalizira skup submodula potreban za build. Normalni način inicijalizira
   top-level DoomGeneric i Hazard3, zatim ugniježđene Hazard3 submodule
   ``scripts`` i ``example_soc/libfpga``. Postavite
   ``HAZARD3_INIT_ALL_SUBMODULES=1`` za inicijalizaciju svih rekurzivnih
   submodula.

``scripts/doomgeneric-version.sh``
   Definira DoomGeneric repozitorij/commit koji očekuju pomoćne skripte za Doom
   build.

``scripts/setup-doomgeneric.sh``
   Provjerava DoomGeneric checkout i potrebne izvorne datoteke. Namjerno dirty
   razvojni buildovi zahtijevaju ``HAZARD3_DOOM_ALLOW_DIRTY_DOOMGENERIC=1``.

``scripts/hazard3-submodule.sh``
   Pregledava ili vraća Hazard3 submodul. ``status`` prijavljuje Hazard3 i
   DoomGeneric. ``diff`` i ``restore`` rade nad Hazard3; restore ga vraća na
   gitlink zabilježen u Hazard3-Doom HEAD-u i ažurira njegove ugniježđene
   submodule.

``scripts/update-hazard3-submodule.sh``
   Izričito ažurira, prijavljuje ili vraća Hazard3 gitlink. Namjerno ne mijenja
   ``.gitmodules``. Naredbe su ``update``, ``status`` i ``restore``.

``scripts/check_submodules.bat``
   Windows sigurnosna provjera lokalnog stanja. Za svaki provjereni submodul
   uspoređuje checkout, parent index, gitlink u parent HEAD-u, dirty stanje i
   konfiguriranu udaljenu granu. Remote se odabire usporedbom URL-a iz
   odgovarajućeg ``.gitmodules`` umjesto pretpostavke da se ispravni remote zove
   ``origin``. Uz top-level Hazard3-Doom submodule, provjerava i ugniježđeni
   ``third_party/Hazard3/example_soc/libfpga`` gitlink prema Hazard3 indexu i
   HEAD-u.

Lokalni checker submodula namjerno je konzervativan. Staged pokazivač,
nezabilježeno ažuriranje, grana koja zaostaje, divergentna grana ili nepodudaran
checkout problem su koji treba razumjeti prije commita.

Pregled forkova i grana
-----------------------

``scripts/hazard3-doom-source-status.sh``
   Sveobuhvatno izvješće o povijesti izvornog koda kroz mrežu repozitorija.
   Skripta ne ovisi o remoteovima konfiguriranim u radnom stablu. Stvara
   privremene bare Git repozitorije, dohvaća svaku granu iz svakog konfiguriranog
   forka, otkriva stvarnu zadanu granu svakog repozitorija iz remote HEAD-a i
   uspoređuje povijesti.

   Trenutačne porodice izvora su:

   * Hazard3-Doom: fork trenutačnog korisnika i ``ulx3s/Hazard3-Doom``.
   * DoomGeneric: fork trenutačnog korisnika, ``ulx3s/doomgeneric`` i
     ``ozkl/doomgeneric``.
   * Hazard3: fork trenutačnog korisnika, ``ulx3s/Hazard3`` i
     ``Wren6991/Hazard3``.
   * Hazard3-libfpga/libfpga: fork trenutačnog korisnika ``Hazard3-libfpga``,
     ``ulx3s/Hazard3-libfpga`` i kanonski ``Wren6991/libfpga``.

   Za svaku granu izvješće prikazuje broj commitova ahead/behind u odnosu na
   vlastitu zadanu granu repozitorija i kanonski upstream default, zajedno s
   datumom commita, SHA-om i naslovom. Izvodi i usporedbe default-prema-default
   te usporedbe istoimenih grana kroz forkove. ``UNRELATED`` znači da Git nije
   pronašao zajednički merge base.

   Izlaz se prikazuje uživo i istodobno zapisuje u ``build/source_status.log``.
   Opcionalni prvi argument odabire GitHub korisničko ime; zadano je
   ``gojimmypi``.

.. code-block:: bash

   ./scripts/hazard3-doom-source-status.sh
   ./scripts/hazard3-doom-source-status.sh gojimmypi

Razlika je važna: ``check_submodules.bat`` provjerava sigurnost lokalno
zabilježenog stanja submodula, dok ``hazard3-doom-source-status.sh`` uspoređuje
širu porodicu grana i forkova na GitHubu.

Programiranje i OpenOCD
-----------------------

``scripts/start-openocd.sh``
   Pokreće OpenOCD iz Linuxa ili WSL-a koristeći repozitorijsku ULX3S
   konfiguraciju. Ako se native Windows OpenOCD ``.exe`` pozove iz WSL-a,
   skripta pretvara put konfiguracije u Windows sintaksu.

``scripts/start-openocd.bat``
   Native Windows pokretač OpenOCD-a. Izričita OpenOCD izvršna datoteka može se
   zadati kao prvi argument; inače se koristi binarna datoteka iz repozitorija.

``scripts/load-firmware.sh``
   Učitava normalni monitor ELF kroz aktivni OpenOCD GDB server, zaustavlja cilj,
   učitava i uspoređuje sekcije, postavlja ``$pc`` na ``_start``, nastavlja i
   prekida vezu. Time GDB ne ostaje spojen nakon programiranja.

``scripts/load-firmware-12f.sh``
   Učitava ULX3S 12F monitor smješten u SDRAM-u nakon što je kompaktni FPGA
   bitstream programiran i OpenOCD radi.

``scripts/load-firmware.bat``
   Native Windows loader monitora koji koristi GDB i OpenOCD.

``scripts/load-fpga-bitstream.bat``
   Native Windows pomoćni alat za učitavanje generiranog ili unaprijed izgrađenog
   FPGA bitstreama.

``scripts/flash-ulx3s-persistent.sh``
   Programira ``build/fpga_ulx3s.bit`` u ULX3S SPI flash za trajno hladno
   pokretanje. To se razlikuje od volatilnog SRAM programiranja.

UART upravljanje
----------------

``scripts/return-to-monitor.py``
   Šalje Ctrl-X preko UART-a kako bi aktivni Doom izašao u rezidentni monitor,
   zatim oslobađa serijski port. Zadane vrijednosti su ``/dev/ttyS7`` i 115200
   baud.

``scripts/restart-from-monitor.py``
   Šalje naredbu monitora ``j`` za pokretanje već provjerene Doom slike/IWAD-a,
   zatim oslobađa serijski port. Zadane vrijednosti su ``/dev/ttyS7`` i 115200
   baud.

GDB pomoćni alati
-----------------

``scripts/hazard3-debug.gdb``
   Zajedničke definicije Hazard3 GDB naredbi koje koristi projektna debug postava.

``scripts/gdb/load-hazard3-test-elf.gdb``
   Fokusirana GDB datoteka naredbi za učitavanje Hazard3 monitor/test ELF-a.

``scripts/gdb/sao-probe.gdb``
   Ispituje stanje SAO bridgea iz GDB-a.

``scripts/gdb/sao-scan.gdb``
   Provjerava SAO I2C scan put iz GDB-a.

``scripts/gdb/sao-touchwheel-test.gdb``
   SAO touchwheel test/debug slijed.

``scripts/gdb/sao-touchwheel-led-off.gdb``
   Isključuje touchwheel LED kroz GDB debug put.

CoreMark i analiza ELF-a
------------------------

``scripts/build-coremark.sh``
   Gradi Hazard3 CoreMark port. ``COREMARK_BUILD_PROFILE`` odabire ``baseline``
   ili ``tuned``; mogu se zamijeniti i broj iteracija, sistemski takt, build
   direktorij, Hazard3 checkout i prefiks toolchaina.

``scripts/run-coremark.sh``
   Pokreće CoreMark slike ``performance`` ili ``validation`` ili koristi
   ``qualify`` za obje i sažima rezultat. Serijski port može se zadati za
   automatizirani UART capture.

``scripts/peek-elf.sh``
   Pregledava RISC-V mapu/ELF, odabrani GCC multilib, povezane libgcc članove i
   konačne ISA atribute. Bez argumenata pregledava baseline CoreMark build pod
   ``build/coremark/baseline/``.

Higijena repozitorija i generirani inventar
-------------------------------------------

``scripts/check-executable.sh``
   Provjerava imaju li praćene shell skripte promijenjene u nedavnim commitovima
   Git executable bit. Zadani prozor je pet najnovijih commitova.

``scripts/git-exe.sh``
   Označava jednu praćenu datoteku kao izvršnu u Git indexu i ispisuje
   rezultirajući zapis indexa.

``scripts/check-nettype.sh``
   Provjerava rukovanje Verilog ``default_nettype`` postavkom.

``scripts/inventory.sh``
   Inventarizira Git-praćene datoteke za zadani put i zapisuje deterministička
   Markdown, TSV i SHA-256 izvješća. Skripta pita Git za praćene datoteke umjesto
   obilaska ignoriranih/nepraćenih toolchainova.

``scripts/INVENTORY.md``
   Generirani ljudski čitljiv inventar direktorija skripti.

``scripts/INVENTORY.tsv``
   Generirani strojno čitljiv inventar direktorija skripti.

``scripts/INVENTORY.sha256``
   Generirani SHA-256 izlaz inventara.

``scripts/full-clean.sh``
   Čisti podržane FPGA synthesis ciljeve i uklanja Hazard3-Doom ``build/``
   stablo. ``--dry-run`` prikazuje čišćenje bez izvođenja. Submoduli, WAD
   datoteke i uključeni LiteDRAM izvori namjerno se čuvaju.

VisualGDB i provjera Windows toolchaina
---------------------------------------

``scripts/check-windows-visualgdb.ps1``
   Provjerava native-Windows VisualGDB/NMake projektne postavke i očekivane xPack
   naredbe za build/clean monitora.

``scripts/check-wsl-visualgdb.ps1``
   Provjerava WSL VisualGDB bridge, očekivane WSL build/debug putove i završetke
   redaka praćenih shell skripti potrebne Bashu.

``scripts/setup-xpack-riscv-gcc.cmd``
   Instalira/konfigurira xPack GNU RISC-V Embedded GCC pod ``bin/riscv-gcc`` za
   native Windows build tijek.

.. note::

   Ponašanje skripti razvija se brže od arhitekturne dokumentacije. Kada neka
   opcija ovdje nije dokumentirana, kao autoritativni izvor koristite
   usage/help tekst checkoutane skripte i provjeru varijabli okruženja.
