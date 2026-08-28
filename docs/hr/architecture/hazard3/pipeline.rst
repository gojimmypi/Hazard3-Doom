Trostupanjski pipeline
======================

Najbolji način za razumijevanje Hazard3-a jest pratiti instrukciju kroz stupnjeve
``F``, ``X`` i ``M`` u
`hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_ i
`hazard3_frontend.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_frontend.v>`_.

Stupanj F: dohvat i priprema
----------------------------

Frontend traži 32-bitno poravnate riječi iz memorije instrukcija. Budući da je
u ovom projektu omogućena ekstenzija ``C``, sam tok instrukcija može sadržavati
16-bitne ili 32-bitne instrukcije. 32-bitna instrukcija također može početi u
gornjoj polovici jedne dohvaćene riječi i završiti u donjoj polovici sljedeće.

Hazard3 tu nepodudarnost rješava međuspremnicima umjesto prisiljavanja sabirnice
na 16-bitna čitanja instrukcija. Fiksirani frontend sadrži:

* prefetch queue s dva 32-bitna zapisa; i
* međuspremnik za sastavljanje instrukcije od poluriječi instrukcija.

Queue odvaja vremenska svojstva odgovora sabirnice od potrošnje pipelinea.
Međuspremnik poluriječi omogućuje jezgri oblikovanje sljedeće arhitekturne
instrukcije na bilo kojem 16-bitnom poravnanju. Komprimirane instrukcije proširuju
se prije nego što ih potroši normalna logika izvršavanja.

Konceptualno:

.. code-block:: text

   32-bit fetch words
        |
        v
   +-------------------+
   | prefetch queue    |  two words
   +-------------------+
        |
        v
   +-------------------+
   | halfword assembly |  handles 16/32-bit boundaries
   +-------------------+
        |
        v
   +-------------------+
   | C decompressor    |  if instruction is compressed
   +-------------------+
        |
        v
        X stage

Preusmjeravanje dohvata uzrokovano grananjem, skokom, trapom, povratkom, debug
događajem ili ``fence.i`` poništava rad iz starog toka instrukcija i pokreće
frontend na novom PC-u.

Stupanj X: dekodiranje i izvršavanje
------------------------------------

Stupanj X objedinjuje rad koji bi udžbenički peterostupanjski procesor mogao
razdvojiti između stupnjeva dekodiranja i izvršavanja. Važni poslovi uključuju:

* dekodiranje instrukcije i provjeru omogućenih ISA ekstenzija;
* odabir vrijednosti ``rs1`` i ``rs2``, uključujući rezultate iz bypassa;
* izvođenje cjelobrojnih ALU operacija;
* usporedbu operanada grananja;
* izračun ciljeva grananja/skoka;
* izračun load/store adresa;
* pokretanje CSR, multiply/divide i memorijskih operacija; i
* odluku smije li instrukcija prijeći u M.

Dekoder uzima parametre u obzir. Primjerice, atomsko kodiranje nije samo
zanemareno kada je ``EXTENSION_A=0``; dekodira se kao nedopuštena instrukcija.
Zato je sintetizirana konfiguracija dio arhitekturnog ugovora koji softver vidi.

Stupanj M: dovršetak i umirovljenje
-----------------------------------

Stupanj M drži najstariju instrukciju u letu. U njemu se odabiru kasni rezultati
i arhitekturni dovršetak postaje konačan. Primjeri uključuju:

* čekanje dovršetka podatkovne faze load ili store operacije;
* odabir učitanih podataka za zapis u registar;
* potvrdu ALU/multiply/CSR rezultata u ``rd``;
* ulazak u trap nakon sinkrone iznimke ili prihvaćenog prekida;
* dovršetak prijelaza debug moda; i
* umirovljenje instrukcije za brojač umirovljenih instrukcija.

Ako memorijski sustav uvede wait-stateove, stupanj M može stati. Backpressure se
zatim širi prema X i F tako da nijedna mlađa instrukcija ne prestigne stariju.

Prosljeđivanje podataka i hazardi
---------------------------------

I kratak pipeline može imati read-after-write hazarde. Hazard3 uključuje bypass
putove tako da rezultat ne mora uvijek prvo biti zapisan u registarsku datoteku
pa ponovno pročitan prije nego što ga sljedeća instrukcija upotrijebi.

Razmotrite dvije ovisne ALU instrukcije:

.. code-block:: asm

   add  x5, x6, x7
   xor  x8, x5, x9

S uobičajenom full-bypass konfiguracijom ``xor`` može primiti rezultat prethodne
instrukcije forwardingom umjesto čekanja punog kruga kroz registarsku datoteku.

Load-use ovisnost je drukčija:

.. code-block:: asm

   lw   x5, 0(x6)
   add  x8, x5, x9

Vrijednost učitavanja ne postoji dok je memorija ne vrati. Logika hazarda u
fiksiranoj jezgri posebno tretira load-use kao RAW slučaj koji može zahtijevati
stall. Stvarno kašnjenje ovisi i o vremenu odgovora memorije/sabirnice.

Projekt ne omogućuje ``REDUCED_BYPASS``, pa koristi potpuniju bypass konfiguraciju.

Grananja i mali prediktor
-------------------------

Hazard3 može sintetizirati mali mehanizam predviđanja grananja. Projekt postavlja
``BRANCH_PREDICTOR=1``.

To je namjerno mnogo jednostavnije od prediktora desktop CPU-a. Fiksirana jezgra
pamti nedavno koristan cilj grananja unatrag i može rano preusmjeriti dohvat za
predviđeno uzeto grananje petlje. Grananja unatrag dobar su cilj za mali prediktor
jer često implementiraju petlje:

.. code-block:: asm

   loop:
       # loop body
       addi x5, x5, -1
       bnez x5, loop

Prediktor smanjuje ponovljene fetch mjehuriće u uskim petljama kada je njegova
jednostavna pretpostavka točna. Pri nepodudaranju jezgra preusmjerava frontend i
nastavlja arhitekturnim putem. Ulazak u trap i sinkronizacija dohvata instrukcija
također po potrebi brišu/poništavaju stanje predviđanja.

Brza usporedba grananja
-----------------------

``FAST_BRANCHCMP=1`` odabran je u ULX3S izgradnji. Time se omogućuje namjenski
brzi put usporedbe grananja umjesto oslanjanja samo na serializiraniji ALU put
usporedbe. To je implementacijska opcija za timing/performanse; ne mijenja
RISC-V vidljivu semantiku grananja.

Ponašanje množenja i dijeljenja
-------------------------------

Projekt omogućuje ekstenziju ``M`` i odabire opcije brzog množenja:

.. code-block:: text

   MUL_FAST       = 1
   MUL_FASTER     = 1
   MULH_FAST      = 1
   MULDIV_UNROLL  = 4

Parametri množenja troše više FPGA logike u zamjenu za manju latenciju množenja
i bolji throughput. Dijeljenje/ostatak i dalje koriste iterativnu aritmetiku;
unroll faktor određuje koliko rada sekvencijalna jedinica obavi po ciklusu. To je
dobar primjer čestog kompromisa u dizajnu procesora: ISA ostaje isti, dok se
površina, timing i CPI mogu znatno promijeniti RTL parametrima.

Vježba proučavanja pipelinea
----------------------------

Korisna vježba čitanja izvora jest pratiti ova četiri slijeda kroz RTL:

#. neovisne ALU operacije;
#. ALU rezultat koji koristi sljedeća instrukcija;
#. load koji odmah koristi sljedeća instrukcija; i
#. uzeto grananje unatrag u petlji.

Počnite u ``hazard3_core.v`` kod komentara stupnjeva, zatim pratite stall,
bypass, branch-redirect i M-stage writeback signale. U ``hazard3_frontend.v``
pogledajte što preusmjeravanje radi podacima instrukcija u queueu.
