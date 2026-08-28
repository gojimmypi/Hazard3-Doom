ISA i konfiguracija
===================

Hazard3 je snažno parametriziran. Važno je razlikovati tri stvari:

#. što Hazard3 RTL može implementirati;
#. koje su zadane vrijednosti generičke konfiguracije; i
#. što ULX3S Hazard3-Doom wrapper zapravo odabire.

Mjerodavan fiksirani popis parametara je
`hazard3_config.vh <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_config.vh>`_. Odabrane ULX3S vrijednosti
nalaze se u `fpga_ulx3s.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/fpga/fpga_ulx3s.v>`_.

Projektni ISA profil
--------------------

Efektivni projektni profil je RV32I baza s odabranim standardnim ekstenzijama:

.. list-table::
   :header-rows: 1
   :widths: 18 22 16 44

   * - ISA značajka
     - Hazard3 parametar
     - Projekt
     - Namjena
   * - RV32I
     - ``EXTENSION_E=0``
     - Omogućeno
     - Puni 32-registarski 32-bitni cjelobrojni osnovni ISA.
   * - M
     - ``EXTENSION_M``
     - Omogućeno
     - Cjelobrojno množenje/dijeljenje/ostatak.
   * - A
     - ``EXTENSION_A``
     - Onemogućeno
     - Atomske memorijske operacije namjerno nisu prisutne u ovoj izgradnji.
   * - C
     - ``EXTENSION_C``
     - Omogućeno
     - 16-bitna kodiranja komprimiranih instrukcija.
   * - Zba
     - ``EXTENSION_ZBA``
     - Omogućeno
     - Operacije generiranja adresa poput skaliranih add oblika.
   * - Zbb
     - ``EXTENSION_ZBB``
     - Omogućeno
     - Osnovne operacije manipulacije bitovima.
   * - Zbs
     - ``EXTENSION_ZBS``
     - Omogućeno
     - Operacije postavljanja/brisanja/invertiranja/izdvajanja pojedinačnog bita.
   * - Zifencei
     - ``EXTENSION_ZIFENCEI``
     - Omogućeno
     - ``fence.i`` sinkronizacija dohvata instrukcija.
   * - Zbc
     - ``EXTENSION_ZBC``
     - Onemogućeno
     - Carry-less množenje nije sintetizirano.
   * - Zbkb
     - ``EXTENSION_ZBKB``
     - Onemogućeno
     - Osnovne bitovne operacije usmjerene na scalar crypto nisu sintetizirane.
   * - Zbkx
     - ``EXTENSION_ZBKX``
     - Zadano onemogućeno
     - Crossbar permutation podskup nije odabran wrapperom.
   * - Zcb / Zclsd / Zcmp
     - odgovarajući parametri
     - Zadano onemogućeno
     - Dodatni podskupovi komprimiranih instrukcija nisu odabrani.
   * - Zilsd
     - ``EXTENSION_ZILSD``
     - Zadano onemogućeno
     - Load/store pair ekstenzija nije odabrana.

Ponašanje ``Zicsr`` prisutno je jer su omogućeni machine CSR blokovi potrebni
ovom SoC-u. ``CSR_COUNTER=1`` omogućuje brojače performansi i implementaciju
Zicntr CSR-ova u ovom Hazard3 snimku. Sam user mode ostaje onemogućen u projektu.

Kako konfiguracija dolazi do jezgre
-----------------------------------

Hazard3 drži svoje konfiguracijske parametre u jednoj zajedničkoj include
datoteci i prosljeđuje ih niz hijerarhiju pomoću ``hazard3_config_inst.vh``.
To je čist obrazovni obrazac za podesivi RTL: top-level integrator može
promijeniti značajku bez uređivanja pojedinačnih pipeline modula.

Pojednostavljeni prikaz je:

.. code-block:: text

   fpga_ulx3s.v
       sets feature/performance parameters
              |
              v
   example_soc.v
              |
              v
   hazard3_cpu_1port.v
              |
              v
   hazard3_core.v + decoder/CSR/ALU/front end

Dekoder zatim koristi te parametre kako bi nepodržana kodiranja instrukcija
učinio nedopuštenima. Pogledajte
`hazard3_decode.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_decode.v>`_ za decode kontroliran ekstenzijama.
Primjerice, opcodeovi M ekstenzije usmjeravaju se na multiply/divide put samo
kada je ``EXTENSION_M`` omogućen, a atomska kodiranja zahtijevaju ``EXTENSION_A``.

Konfiguracija privilegija i zaštite
-----------------------------------

ULX3S example SoC prisiljava postavke potrebne za koristan machine-mode sustav:

.. list-table::
   :header-rows: 1

   * - Postavka
     - Efektivna vrijednost
     - Značenje
   * - ``CSR_M_MANDATORY``
     - 1
     - Potrebna machine-level podrška za identifikacijske/statusne CSR-ove.
   * - ``CSR_M_TRAP``
     - 1
     - Podrška za machine trap/interrupt CSR-ove.
   * - ``U_MODE``
     - 0 (zadano)
     - Nema user-mode izvršavanja u ovoj projektnoj izgradnji.
   * - ``PMP_REGIONS``
     - 0 (zadano)
     - Nema Physical Memory Protection regija u ovoj projektnoj izgradnji.
   * - ``DEBUG_SUPPORT``
     - 1
     - Omogućen debug mode i integracija vanjskog Debug Modulea.
   * - ``BREAKPOINT_TRIGGERS``
     - 0 (zadano)
     - Nisu odabrani opcionalni slotovi triggera na adresu instrukcije.
   * - ``NUM_IRQS``
     - 1
     - Jedan ulaz vanjskog prekida; example SoC ovdje spaja UART IRQ.

Nemojte miješati tvrdnju "Hazard3 podržava user mode/PMP/triggere" s tvrdnjom
"ovaj bitstream ih sadrži". Prvo je sposobnost upstream CPU-a; drugo ovisi o
parametrima sinteze.

Postavke usmjerene na performanse
---------------------------------

Projekt također mijenja implementacijske izbore koji nisu ISA ekstenzije:

.. list-table::
   :header-rows: 1

   * - Parametar
     - Vrijednost projekta
     - Učinak
   * - ``REDUCED_BYPASS``
     - 0
     - Zadržava uobičajenu, potpuniju forwarding mrežu.
   * - ``MUL_FAST``
     - 1
     - Omogućuje brzu implementaciju množenja.
   * - ``MUL_FASTER``
     - 1
     - Omogućuje dodatni put množenja manje latencije koji ovaj snimak pruža.
   * - ``MULH_FAST``
     - 1
     - Ubrzava operacije množenja gornje polovice.
   * - ``MULDIV_UNROLL``
     - 4
     - Obavlja više iterativnog multiply/divide rada po ciklusu od minimalne konfiguracije.
   * - ``FAST_BRANCHCMP``
     - 1
     - Sintetizira brzi komparator grananja.
   * - ``BRANCH_PREDICTOR``
     - 1
     - Omogućuje malu strukturu predviđanja grananja unatrag.
   * - ``RESET_REGFILE``
     - 0
     - Ne troši reset logiku na brisanje registara opće namjene.

Posljedica za softver
---------------------

Softver treba prevoditi za ISA koji je stvarno prisutan u FPGA-u, a ne za
nadskup koji Hazard3 teoretski može sintetizirati. Reprezentativan odabir
arhitekture za kod namijenjen samo ovoj konfiguraciji konceptualno je:

.. code-block:: text

   rv32imc + zba + zbb + zbs + zicsr + zifencei

Točan GCC/LLVM zapis za ``-march`` treba pratiti sintaksu ekstenzija koju
prihvaća instalirani alatni lanac i projektne build skripte. Posebno, nemojte
omogućiti ``A`` samo zato što upstream Hazard3 podržava atomike.

Upstream u odnosu na fiksirani snimak
-------------------------------------

Trenutačni upstream Hazard3 nastavlja dodavati značajke i implementacijska
poboljšanja. Te su promjene vrijedan referentni materijal, ali fiksirani ULX3S
commit ostaje ispravan izvor za pitanja na razini ciklusa ili konfiguracije ove
konkretne FPGA slike.

Za arhitekturno proučavanje koristite oba:

* `Fiksirana projektna konfiguracija <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_config.vh>`_ - točne opcije i
  zadane vrijednosti dostupne ovom snimku.
* `Trenutačna upstream stable konfiguracija <https://github.com/Wren6991/Hazard3/blob/stable/hdl/hazard3_config.vh>`_
  - trenutačni održavani smjer upstreama.
