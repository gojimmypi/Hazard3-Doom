RISC-V arhitektura za debugiranje
=================================

Hazard3 uključuje upstream implementaciju vanjskog RISC-V debugiranja. To je
sposobnost procesora/platforme, a ne debugger specifičan za Doom koji je dodao
aplikacijski projekt.

Put korišten na ULX3S-u posebno je poučan jer pokazuje kako se standardni
RISC-V protokol za debugiranje može povezati s JTAG sklopom proizvođača FPGA-a.

Put debugiranja
---------------

Konceptualni lanac je:

.. code-block:: text

   GDB
    |
    v
   OpenOCD
    |
    v
   ECP5 chip JTAG TAP
    |
    v
   ECP5 JTAGG custom data registers
    |
    v
   Hazard3 JTAG Debug Transport Module (DTM)
    |
    v
   Debug Module Interface (DMI)
    |
    v
   Hazard3 Debug Module (DM)
    |
    +--> halt/resume CPU
    +--> inject instructions
    +--> access debug data register
    `--> system-bus access

Transport specifičan za ECP5 implementiran je u
`hazard3_ecp5_jtag_dtm.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/debug/dtm/hazard3_ecp5_jtag_dtm.v>`_. Koristi
ECP5 primitiv ``JTAGG`` kako bi registre DTMCS i DMI podataka priključio na
postojeći TAP čipa FPGA. Dizajn zato može koristiti uobičajenu USB/JTAG vezu
pločice umjesto dodatnog soft JTAG TAP-a u logici FPGA-a.

Debug Module
------------

Standardni Hazard3 Debug Module nalazi se u
`hazard3_dm.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/debug/dm/hazard3_dm.v>`_. Implementira upravljačku
ravninu između debuggera i jednog ili više Hazard3 hartova. Važni mehanizmi
uključuju:

* zahtjeve za zaustavljanje i nastavak;
* apstraktne naredbe za pristup registrima;
* debug registar ``data0`` koji se dijeli sa zaustavljenim hartom;
* mali programski međuspremnik za umetnute debug instrukcije; i
* pristup sistemskoj sabirnici za čitanje/pisanje memorije iz debuggera,
  neovisno o normalnom izvršavanju softvera.

Projekt omogućuje ``DEBUG_SUPPORT=1`` u CPU instanci, čime se uključuju debug
način na strani jezgre, debug CSR registri, ponašanje run/halt i sučelje za
ubrizgavanje instrukcija koje DM zahtijeva.

Ubrizgavanje instrukcija
------------------------

Ubrizgavanje instrukcija elegantan je dio RISC-V debugiranja. Umjesto izgradnje
potpuno odvojenog puta do svakog internog CPU registra, Debug Module može
zaustaviti hart i uzrokovati izvršavanje pažljivo odabranih instrukcija u debug
načinu. Te instrukcije mogu premještati podatke između arhitekturnih registara
i registra debug podataka.

Prednji dio Hazard3 izravno sudjeluje: kada je zaustavljen u debug načinu, može
prihvatiti riječi instrukcija koje daje debugger umjesto uobičajenog prometa
dohvata instrukcija. Time se ponovno koristi stvarni datapath za
dekodiranje/izvršavanje i debug ponašanje ostaje blisko arhitekturnom
izvršavanju.

Pristup sistemskoj sabirnici
----------------------------

Debug Module može također zatražiti memorijske transakcije kroz debug sučelje
sistemske sabirnice CPU omotača. To se razlikuje od ubrizganih instrukcija:
OpenOCD može pregledavati ili mijenjati memoriju bez traženja od zaustavljenog
programa da za svaki pristup izvršava normalan slijed RISC-V load/store
instrukcija.

Jednoportni omotač arbitrira taj debug promet s istim resursima sabirnice prema
SoC-u koje koristi procesor. Pri debugiranju memorijski mapirane periferije
imajte na umu da čitanje iz debuggera može imati iste hardverske nuspojave kao
čitanje iz softvera ako periferija definira nuspojave pri čitanju.

Hardverski okidači prijelomnih točaka
-------------------------------------

Upstream Hazard3 može implementirati okidače adrese instrukcije. Međutim,
prikvačeni ULX3S omotač ne mijenja ``BREAKPOINT_TRIGGERS``, čija je prikvačena
zadana vrijednost nula. Zato studenti ne bi trebali pretpostaviti da ovaj
bitstream sadrži opcionalna mjesta hardverskih execute-okidača samo zato što ih
upstream jezgra može podržati.

Softverske prijelomne točke, debug halt, single-step ponašanje koje podržava
debug stack te pristup memoriji/registrima iz debuggera odvojeni su mehanizmi
od tih opcionalnih komparatora okidača.

Što je standardno, a što specifično za pločicu?
-----------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - Standardni Hazard3/upstream koncept
     - Odabir projekta ULX3S
   * - RISC-V Debug Module
     - Koristi se izravno.
   * - Hazard3 JTAG-DTM logika
     - Koristi se kroz DTM omotač specifičan za ECP5.
   * - ECP5 ``JTAGG`` adapter
     - Upstream Hazard3 već pruža ovu ECP5 integraciju; nije izum projekta Hazard3-Doom.
   * - Konfigurabilnost ``DEBUG_SUPPORT``
     - Omogućena je u CPU instanci projekta.
   * - OpenOCD/GDB protok protokola
     - Projekt pruža konfiguracijske/pomoćne skripte za svoju pločicu i artefakte builda.
   * - Opcionalni okidači adrese izvršavanja
     - Nisu odabrani u ovoj prikvačenoj ULX3S CPU konfiguraciji.

Praktično debugiranje
---------------------

Pogledajte :doc:`../../user-guide/jtag-debugging` za projektni OpenOCD/GDB i
VisualGDB tijek rada. Ova arhitekturna stranica objašnjava s čime ti alati
zapravo komuniciraju unutar FPGA-a.

Korisna laboratorijska vježba je zaustaviti rezidentni monitor u poznatoj
funkciji, pregledati cjelobrojne registre, pročitati riječ RAM-a kroz debugger,
izvesti single-step jedne instrukcije i zatim odrediti koje su od tih operacija
koristile CPU debug stanje, a koje pristup sistemskoj sabirnici.
