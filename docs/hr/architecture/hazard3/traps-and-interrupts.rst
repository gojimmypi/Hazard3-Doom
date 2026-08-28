Trapovi, prekidi i CSR registri
===============================

RISC-V koristi izraz **trap** za prijenos upravljanja uzrokovan sinkronom
iznimkom ili asinkronim prekidom. Hazard3 implementira stanje trapa strojnog
načina koje ovaj projekt koristi u
`hazard3_csr.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_csr.v>`_.

Model privilegija projekta
--------------------------

Hazard3-Doom CPU konfiguriran je kao ugrađeni sistem u strojnom načinu:

* podrška za strojne CSR registre je omogućena;
* podrška za strojne trapove je omogućena;
* korisnički način nije omogućen;
* ulaz softverskog prekida vezan je na nulu;
* jedan ulaz vanjskog prekida koristi se za UART; i
* platformski timer upravlja ulazom strojnog timerskog prekida.

Reset vektor procesora je ``0x00000040``. Početna vrijednost ``mtvec`` je
``0x00000000`` u instanci primjer-SoC-a; početni firmware odgovoran je za
postavljanje željenog rasporeda ulaza u trap tijekom rada.

Važni strojni CSR registri
--------------------------

Sljedeći standardni CSR registri najkorisnija su početna točka za studente:

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - CSR
     - Uloga
   * - ``mstatus``
     - Globalno omogućavanje strojnih prekida i spremljeno stanje prekida/privilegije koje se koristi pri ulazu u trap i povratku.
   * - ``mtvec``
     - Baza strojnog vektora trapova i odabir izravnog/vektorskog načina.
   * - ``mepc``
     - Programsko brojilo povezano s instrukcijom koja je izazvala trap ili s prekinutom točkom izvršavanja.
   * - ``mcause``
     - Određuje je li trap bio prekid ili iznimka i bilježi kod uzroka.
   * - ``mie``
     - Omogućavanje pojedinih izvora strojnog prekida.
   * - ``mip``
     - Stanje čekajućih prekida vidljivo softveru.
   * - ``mtval``
     - CSR vrijednosti trapa. U ovoj prikvačenoj Hazard3 implementaciji čvrsto je postavljen na nulu.
   * - ``mcycle`` / ``minstret``
     - Brojači ciklusa i umirovljenih instrukcija kada je podrška za brojače omogućena.

Prikvačeni CSR RTL maskira ``mepc`` prema poravnanju instrukcija. Budući da je
``C`` omogućen, valjani PC instrukcije može biti poravnat na 16-bitnu granicu;
ne mora uvijek biti poravnat na 32 bita.

Iznimka nasuprot prekidu
------------------------

Koristan mentalni model je:

.. code-block:: text

   synchronous problem in current instruction
       -> exception
       -> examples: illegal instruction, access fault, ecall, ebreak

   asynchronous event from outside instruction stream
       -> interrupt
       -> examples: UART or timer event

Oboje ulaze u strojni put trapa, ali ih ``mcause`` razlikuje. Najviši bit
označava prekid nasuprot iznimci, a polje uzroka identificira konkretan izvor
koji jezgra implementira.

Ulaz u trap
-----------

Na visokoj razini, ulaz u strojni trap izvodi ove arhitekturne radnje:

#. zaustavlja normalno umirovljenje na preciznoj granici instrukcije;
#. sprema odgovarajući PC u ``mepc``;
#. zapisuje razlog trapa u ``mcause``;
#. ažurira stanje stoga za omogućavanje strojnih prekida u ``mstatus``; i
#. preusmjerava dohvat instrukcija na adresu odabranu iz ``mtvec``.

Točan PC spremljen za iznimku konceptualno nije uvijek ista točka kao za
prekid. Upravljanje M-stupnjem u Hazard3 izričito razlikuje uvjete trapa kako
bi ``mret`` mogao nastaviti na arhitekturno ispravnom PC-u.

Povratak iz trapa
-----------------

``mret`` obnavlja strojno stanje trapa i preusmjerava dohvat na ``mepc``. To je
jedan od razloga zbog kojih obrada trapa mora biti usklađena s prednjim dijelom
cjevovoda: sve instrukcije dohvaćene sa starog puta moraju se odbaciti kada se
izvršavanje vrati na spremljeni PC.

Ožičenje vanjskih prekida u ovom projektu
-----------------------------------------

Prikvačeni
`example_soc.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/example_soc.v>`_ povezuje portove
prekida procesora ovako:

.. code-block:: text

   hazard3_cpu_1port
       irq[0]    <- UART IRQ
       soft_irq  <- 0
       timer_irq <- platform timer IRQ

``NUM_IRQS=1`` ovdje je uobičajena Hazard3 postavka. Opcionalno prilagođeno
Hazard3 proširenje kontrolera prekida nije odabrano ULX3S omotačem, pa je ovo
namjerno blisko standardnom RISC-V modelu strojnih prekida.

Slojevi omogućavanja prekida
----------------------------

Primanje električnog/perifernog signala prekida samo je jedan dio obrade
prekida. Softver obično mora postaviti i:

#. stanje omogućavanja prekida specifično za periferiju;
#. odgovarajući bit u ``mie``; i
#. globalno omogućavanje strojnog prekida u ``mstatus``.

Rukovatelj zatim mora obraditi/potvrditi periferni izvor prije povratka; u
suprotnom prekid osjetljiv na razinu može odmah ponovno postati čekajući.

Edukacijski primjer
-------------------

Minimalnoj vježbi s timerskim/UART prekidom može se pristupiti ovim redom:

#. instalirati rukovatelj trapom i postaviti ``mtvec``;
#. u rukovatelju pregledati ``mcause``;
#. omogućavati jedan po jedan izvor prekida;
#. preko UART-a bilježiti ``mepc`` i odabrane CSR registre;
#. potvrditi periferni izvor; i
#. vratiti se instrukcijom ``mret``.

Time odnos između **periferije**, **CSR stanja prekida**, **preusmjeravanja
cjevovoda** i **softvera rukovatelja** postaje izravno vidljiv.

Proučavanje izvornog koda
-------------------------

Ove prikvačene datoteke koristite zajedno:

* `hazard3_csr.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_csr.v>`_ - CSR dekodiranje, ``mstatus``,
  ``mepc``, ``mcause``, stanje prekida i ažuriranja stanja trapa.
* `hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_ - detekcija iznimki, slijed
  trapa, preusmjeravanja dohvata i dovršavanje M-stupnja.
* `example_soc.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/example_soc.v>`_ - stvarno ožičenje UART/timer
  prekida u projektu.
