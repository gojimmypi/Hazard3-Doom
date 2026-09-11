Vodič za izgradnju
==================

Glavne detaljne upute za izgradnju nalaze se u
:doc:`../getting-started/build`. Ova stranica povezuje taj postupak sa
zahtjevima, profilima pločica, referencom skripti i informacijama o vremenskom
zatvaranju koje su korisne pri ponovnoj izgradnji ili promjeni ciljne pločice.

Uobičajene izgradnje za pločice
-------------------------------

Za uobičajenu izgradnju koristite potpuni wrapper za ciljnu pločicu. Ti wrapperi
održavaju FPGA dizajn, rezidentni monitor, Doom sliku, takt i memorijski profil
međusobno usklađenima:

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh
   ./scripts/build-ulx3s-12f-doom.sh
   ./scripts/build-ulx4m-ld-doom.sh

Pogledajte :doc:`../getting-started/build` za podržane konfiguracije pločica,
selektivnu ponovnu izgradnju monitora i Doom slike, pripremu podmodula, izlazne
datoteke i varijable okruženja specifične za izgradnju.

Verzije alata i reproducibilnost
--------------------------------

Rezultati FPGA vremenskog zatvaranja ovise o više čimbenika od samog izvornog
stabla. Yosys, nextpnr, Project Trellis, postavke usmjeravanja i odabrani seed
mogu utjecati na rezultat. Prije izgradnje provjerite razvojno okruženje:

.. code-block:: bash

   ./scripts/requirements-check.sh

Pogledajte :doc:`../getting-started/prerequisites` za potrebne alate na razvojnom
računalu. Zadane nextpnr postavke specifične za pločicu definirane su u
``scripts/build-ecp5-bitstream-common.sh`` i sažete izravno iz te datoteke u
:doc:`../reference/board-profiles`.

Seed koji je prošao vremensko zatvaranje s jednom netlistom ili verzijom alata
nije jamstvo vremena za drugu. Ako se promijene rezultat sinteze, verzija CAD
alata, taktovi ili konfiguracija usmjeravanja, ponovno provedite odgovarajuću
provjeru vremena prije nego što rezultat upotrijebite kao izdanje. Pogledajte
:doc:`../reference/timing-sweeps` za postupak sweepa i kvalifikacije.

Skripte za izgradnju i napredni postupci
----------------------------------------

Za potpuni katalog pomoćnih alata za izgradnju, programiranje, provjeru,
čišćenje i mjerenje vremena pogledajte :doc:`../reference/scripts`. Ta referenca
dokumentira potpune wrappere za pločice kao i niže razine alata za monitor,
bitstream, Doom sliku i sweep seedova.

Za vlasništvo nad dijelovima repozitorija i granicu između Hazard3 hardvera i
softvera specifičnog za Hazard3-Doom pogledajte
:doc:`../architecture/repositories`.
