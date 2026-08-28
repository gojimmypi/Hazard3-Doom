Pregled procesora
=================

Hazard3 je mala 32-bitna RISC-V implementacija s namjerno kompaktnim
pipelineom. Nije mikrokodirani nastavni CPU, ali njegova je struktura dovoljno
jednostavna da se u RTL-u može pratiti od dohvata instrukcije do umirovljenja.

Arhitekturno središte je
`hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_. Jezgra izlaže odvojena
sučelja transakcija za dohvat instrukcija i load/store. Wrapper moduli zatim
prilagođavaju ta interna sučelja AHB5 sabirnicama:

* `hazard3_cpu_1port.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_cpu_1port.v>`_ arbitriranjem spaja instrukcijski
  i podatkovni promet na jedan AHB5 master port.
* `hazard3_cpu_2port.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_cpu_2port.v>`_ izlaže neovisne
  instrukcijske i podatkovne AHB5 master portove.

Hazard3-Doom koristi **jednoportni** wrapper, pa dohvat instrukcija i podatkovni
pristupi na kraju dijele AHB put na strani SoC-a.

Tri stupnja, ne pet
-------------------

Uvodni RISC materijali često prikazuju peterostupanjski pipeline nazvan IF, ID,
EX, MEM, WB. Hazard3 umjesto toga organizira procesor u tri široka stupnja:

``F`` - dohvat i priprema instrukcije
   Dohvaća poravnate memorijske riječi, sprema poluriječi instrukcija, obrađuje
   poravnanje i proširenje komprimiranih instrukcija te priprema informacije o
   izvornim registrima za sljedeći stupanj.

``X`` - dekodiranje i izvršavanje
   Dekodira instrukciju, čita/prosljeđuje operande, izvodi ALU i branch rad,
   izračunava adrese, pokreće višecikličke operacije i određuje smije li
   instrukcija napredovati.

``M`` - dovršetak memorije i umirovljenje
   Dovršava load/store i druge kasne operacije, odabire podatke za writeback,
   ažurira arhitekturno stanje i izvodi trap/debug radnje pri umirovljenju.

To ne znači da memorija postoji samo u stupnju M. Dohvat instrukcija ima vlastiti
memorijski promet, a load/store adresa pokreće se iz izvršnog puta. Nazivi
stupnjeva opisuju gdje se instrukcija nalazi u pipelineu, a ne svaku fizičku
aktivnost koja se događa u tom ciklusu.

Karta modula jezgre
-------------------

.. list-table::
   :header-rows: 1
   :widths: 32 68

   * - Izvorni modul
     - Odgovornost
   * - ``hazard3_frontend.v``
     - Fetch queue, sastavljanje/poravnanje instrukcija, obrada komprimiranih instrukcija, preusmjeravanja dohvata i ubrizgavanje debug instrukcija.
   * - ``hazard3_decode.v``
     - Preslikava RISC-V kodiranja instrukcija u interne ALU, load/store, CSR, branch i extension kontrole.
   * - ``hazard3_core.v``
     - Pipeline registri, forwarding, hazardi, tok izvršavanja, trapovi i vršna kontrola jezgre.
   * - ``hazard3_alu.v``
     - Podrška datapatha za cjelobrojnu aritmetiku, logičke operacije, pomake, usporedbe i manipulaciju bitovima.
   * - ``hazard3_mul_fast.v`` / ``hazard3_muldiv_seq.v``
     - Brzi putovi množenja i iterativni mehanizmi množenja/dijeljenja/ostatka odabrani konfiguracijom.
   * - ``hazard3_csr.v``
     - Machine/debug CSR-ovi, stanje trapova, brojači, privilegirano stanje, stanje prekida i opcionalna kontrola prema PMP-u/triggerima.
   * - ``hazard3_regfile_1w2r.v``
     - Cjelobrojna registarska datoteka s dva porta za čitanje i jednim za pisanje.
   * - ``hazard3_irq_ctrl.v``
     - Opcionalno Hazard3 proširenje vanjskog kontrolera prekida.
   * - ``hazard3_pmp.v``
     - Opcionalno Physical Memory Protection uparivanje adresa i prava.
   * - ``hazard3_triggers.v``
     - Opcionalni debug triggeri na adresu instrukcije.

Cjelobrojna registarska datoteka
--------------------------------

Uobičajena RV32I konfiguracija ima registre ``x0`` do ``x31``. ``x0`` je
arhitekturno fiksiran na nulu. Hazard3 registarska datoteka organizirana je za
dva izvorna operanda i jedan zapis odredišta po ciklusu, što odgovara uobičajenom
obliku RISC-V instrukcije:

.. code-block:: text

   add x5, x6, x7
       ^   ^   ^
       |   |   +-- rs2
       |   +------ rs1
       +---------- rd

Projekt ostavlja ``EXTENSION_E`` isključenim, pa koristi puni skup registara
RV32I umjesto smanjenog skupa registara RV32E.

Ugrađeni dizajn u machine modu
------------------------------

Hazard3 je dovoljno podesiv za podršku dodatnim privilegijama i zaštitnim
značajkama, ali Hazard3-Doom instanca namjerno je jednostavna:

* Omogućeni su machine-mode CSR-ovi i trap podrška.
* User mode nije omogućen.
* PMP regije nisu omogućene.
* Omogućen je standardni vanjski debug put.
* Konfiguriran je jedan vanjski ulaz prekida; example SoC ga spaja na UART
  prekid. Platformski timer pokreće machine timer prekid.
* Ulaz softverskog prekida vezan je na nulu u example SoC-u.

Zbog toga je izgradnja vrlo prikladna za bare-metal obrazovanje: kod može
proučavati prekide, CSR-ove, transakcije sabirnice i debug ponašanje bez MMU-a
ili privilegijskog sloja operacijskog sustava koji bi zaklanjao put.

Stanje upstreama
----------------

Prema pregledu od 2026-08-19, trenutačni upstream Hazard3 i dalje se opisuje kao
trostupanjski RV32I/RV32E procesor s podesivim standardnim ekstenzijama,
machine/user izvršavanjem, PMP-om, vanjskim debugom i triggerima na adresu
instrukcije. To su upstream sposobnosti, a ne izumi Hazard3-Dooma.

Stoga projektno pitanje nije "što je promijenjeno unutar RISC-V CPU-a za Doom?",
nego "koje su Hazard3 opcije odabrane i koji je SoC hardver postavljen oko
CPU-a?" Sljedeće stranice detaljno odgovaraju na ta dva pitanja.
