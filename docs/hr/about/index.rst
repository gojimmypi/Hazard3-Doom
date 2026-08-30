O projektu Hazard3-Doom
=======================

Hazard3-Doom je otvoreni FPGA hardversko-softverski projekt izgrađen oko
Hazard3 RISC-V procesora i Lattice ECP5 FPGA sklopova. Objedinjuje softverski
procesor, memorijske kontrolere, rezidentni monitor, aplikacije koje se izvode
iz vanjske memorije, HDMI video, micro-SD pohranu, serijsko i JTAG otklanjanje
pogrešaka te I/O mogućnosti porodica ULX3S i ULX4M.

Doom je najvidljivija aplikacija, ali istodobno je i korisno sistemsko
opterećenje. Za njegovo izvođenje potrebno je mnogo više od same CPU jezgre:
učitavanje izvršne datoteke, ispravna memorijska mapa, kontinuirani pristup
vanjskoj memoriji, vremenski sklopovi, ulazi, pohrana, video i dovoljno
softverske infrastrukture za dugotrajan rad veće C aplikacije. Zbog toga je
projekt koristan za proučavanje cijelog puta od RTL-a do interaktivnog programa.

Što se može naučiti
-------------------

Hazard3-Doom može se proučavati na više razina. Početnik može prvo učitati
poznati bitstream i koristiti monitor, a zatim postupno ponovno izgraditi ili
mijenjati slojeve ispod njega.

.. list-table::
   :header-rows: 1
   :widths: 27 73

   * - Područje
     - Primjeri tema
   * - Dizajn RISC-V procesora
     - Hazard3 cjevovod, konfiguracija ISA-e, CSR-ovi, iznimke, prekidi, ponašanje grananja i podrška za otklanjanje pogrešaka.
   * - Integracija SoC-a
     - AHB5/APB međuspojevi, dekodiranje adresa, memorijske mape, vremenski sklopovi, UART-i i memorijski mapirane periferije.
   * - Memorijski sustavi
     - Interni EBR SRAM, vanjski SDR SDRAM, DDR3, memorijski kontroleri, latencija, propusnost, inicijalizacija i vremenski kompromisi.
   * - FPGA implementacija
     - Yosys sinteza, nextpnr postavljanje/usmjeravanje, ograničenja, pretraživanje seed vrijednosti, zatvaranje timinga i kompromisi resursa na ECP5 sklopovima.
   * - Ugrađeni softver
     - Početni kod, mape linkera, rezidentni firmware, učitavanje izvršnih datoteka, smještaj heap memorije, dijagnostika i oporavak.
   * - Grafika i I/O
     - Indeksirani framebufferi, HDMI prikaz, micro-SD pohrana, serijski protokoli, I2C/SAO uređaji i dijeljeni resursi pločice.
   * - Otklanjanje pogrešaka
     - UART dijagnostika, JTAG, OpenOCD, GDB i povezivanje softverskih kvarova s ponašanjem FPGA-a i memorije.
   * - Otvoreno inženjerstvo
     - Reproducibilne izgradnje, fiksiranje podmodula, razlike između izvornog i projektnog koda, licence, dokumentacija i regresijsko testiranje.

Detaljan pregled procesora počinje u :doc:`../architecture/hazard3/index`.
Razlike između pločica i memorija sažete su u
:doc:`../reference/board-profiles`.

Zašto Doom?
-----------

Trepćuća LED ili mali bare-metal test mogu dokazati da jedan blok radi. Doom
zahtijeva da mnogi blokovi dugo rade zajedno. Opterećuje izvođenje instrukcija,
velike strukture podataka, vanjsku memoriju, učitavanje datoteka, osvježavanje
framebuffera, timing i korisničku interakciju, a istodobno daje rezultat koji je
lako promatrati.

Zbog toga su i kvarovi poučni. Oštećena tekstura, nizak broj sličica u sekundi,
neuspjelo podizanje sustava, memorijska iznimka ili regresija timinga nakon
usmjeravanja mogu izravno dovesti do proučavanja određenog dijela računalnog
sustava.

Izvan učionice
--------------

Projekt je koristan i kao platforma za inženjerski rad i izradu prototipova.
Doom se može promatrati kao zahtjevno referentno opterećenje, dok se iste FPGA i
SoC ideje prilagođavaju drugom softveru ili vlastitom RTL-u. Moguće primjene
uključuju:

* procjenu RISC-V soft procesora uz FPGA logiku specifičnu za aplikaciju;
* prototipiranje vlastitih periferija, mostova protokola ili determinističke upravljačke logike;
* eksperimentiranje s memorijskim arhitekturama i podjelom funkcija između hardvera i softvera;
* izradu demonstratora s videom, pohranom, senzorima, kamerama ili mrežom;
* procjenu otvorenog FPGA alatskog lanca prije izrade vlastite pločice; i
* korištenje modularnog FPGA-a u prototipu ugrađenog proizvoda.

Hazard3-Doom treba smatrati razvojnim i obrazovnim projektom, a ne certificiranim
referentnim dizajnom za proizvodnju. Razvoj proizvoda zahtijeva uobičajene
provjere zatvaranja timinga, električnih zahtjeva, pouzdanosti, sigurnosti,
dostupnosti komponenti, proizvodnog testiranja i licenci svakog hardverskog i
softverskog dijela. Podaci igre Doom također imaju odvojena prava distribucije
od otvorenog izvornog koda enginea i FPGA projekta.

ULX4M i ekosustav Compute Module nosivih pločica
------------------------------------------------

ULX4M je posebno zanimljiv za prototipiranje jer je modularni FPGA
system-on-module, a ne sve-u-jednom razvojna pločica. ULX4M hardverski projekt
opisuje ga kao kompatibilnog s rasporedom pinova nosivih pločica Raspberry Pi
Compute Module 4 (CM4), pa se FPGA modul može koristiti na baznim pločicama tipa
CM4 ili na posebno dizajniranoj nosivoj pločici.

Takva modularna podjela korisna je i u nastavi i pri istraživanju proizvoda:
FPGA i memorija ostaju na ULX4M-u, dok nosiva pločica može osigurati konektore,
napajanje, kamere, zaslone, mrežu, pohranu ili drugi I/O specifičan za
aplikaciju. Tim zato može ispitati nekoliko konfiguracija nosivih pločica prije
projektiranja manje vlastite pločice koja sadrži samo sučelja potrebna konačnom
proizvodu.

ULX4M projekt objavio je testiranja s više proizvoda tipa CM4, uključujući
Raspberry Pi Compute Module I/O pločicu, Waveshare pločice, Piunora i TOFU
nosivu pločicu. Te izvještaje treba smatrati primjerima kompatibilnosti, a ne
jamstvom za svaku reviziju pločice ili svako sučelje. Prije povezivanja hardvera
provjerite shemu nosive pločice, reviziju ULX4M-a, FPGA ograničenja pinova,
naponske zahtjeve i RTL koji stvarno implementira pojedino sučelje.

.. important::

   Kompatibilnost pinova s CM4 **ne** znači da je ULX4M Raspberry Pi niti da se
   na njemu može izvoditi Raspberry Pi softver. Zajednički format nosive pločice
   pruža mogućnost električne i mehaničke integracije; ULX4M sadrži ECP5 FPGA i
   izvodi logiku implementiranu u njegovom bitstreamu.

Za Hazard3-Doom trenutni ULX4M-LS put koristi SDR SDRAM, dok ULX4M-LD koristi
DDR3 preko LiteDRAM-a. Zato su te dvije varijante korisne ne samo za usporedbu
integracije na nosive pločice nego i za usporedbu bitno različitih arhitektura
memorijskih kontrolera. Trenutno stanje izgradnje i timinga pogledajte u
:doc:`../reference/board-profiles`.

Vanjski ULX4M resursi
---------------------

* `ULX4M dokumentacija <https://github.com/intergalaktik/ulx4m-documentation>`_
* `ULX4M hardverski repozitorij <https://github.com/intergalaktik/ulx4m>`_
* `ULX4M projekt i bilješke o kompatibilnosti nosivih pločica <https://www.crowdsupply.com/intergalaktik/ulx4m/updates/pre-launch-progress>`_
* `Raspberry Pi Compute Module dokumentacija <https://www.raspberrypi.com/documentation/computers/compute-module.html>`_
* `ULX4M Open Source Hardware certifikat <https://certification.oshwa.org/hr000013.html>`_
