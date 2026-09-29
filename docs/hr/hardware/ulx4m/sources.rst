Izvorni dizajn i dodatna literatura
===================================

Ovaj vodič namjerno zadržava vidljivost upstream izvora. Hazard3-Doom dodaje
tumačenje i projektne integracijske bilješke, ali ne zamjenjuje izvornu ULX4M
hardversku dokumentaciju.

Glavni ULX4M izvori
-------------------

* `ULX4M na Crowd Supplyu <https://www.crowdsupply.com/intergalaktik/ulx4m>`_
* `Intergalaktik ULX4M hardverski repo <https://github.com/intergalaktik/ulx4m>`_
* `Intergalaktik ULX4M dokumentacija <https://github.com/intergalaktik/ulx4m-documentation>`_
* `ULX4M primjeri <https://github.com/lawrie/ulx4m_examples>`_


ULX4M sheme
-----------

Lokalne kopije shema za obje ULX4M varijante uključene su u ovu dokumentaciju:

:download:`ULX4M-LD v003 shema <ULX4M-LD-v003.pdf>`

:download:`ULX4M-LS v0.0.3 shema <ULX4M-LS-v0.0.3.pdf>`

ULX4M-LD i ULX4M-LS različite su varijante pločice, a ne revizije iste pločice.
Koristite shemu koja odgovara pločici na kojoj radite.

Sheme su korisne za praćenje FPGA-a, DDR3 memorije, napajanja, JTAG-a, USB-a,
SD kartice, videa i drugih veza na razini pločice opisanih u ovom vodiču.

Izvorne projektne datoteke održava ULX4M projekt. Za izvorne datoteke i novije
revizije shema pogledajte izvorni repozitorij.

Hazard3-Doom izvori
-------------------

.. code-block:: text

   third_party/Hazard3/example_soc/fpga/
   third_party/Hazard3/example_soc/synth/
   third_party/Hazard3/example_soc/soc/
   third_party/Hazard3/example_soc/third_party/LiteDRAM/
   bootloader/
   openocd/

Kod neslaganja izvora koristite ovaj prioritet: fizička pločica, odgovarajuća
shema/PCB/BOM revizija, LPF i wrapper za konkretni build, datasheet ugrađene
komponente, a zatim campaign/README/example materijal. Neslaganje koje utječe na
build treba dokumentirati u projektu.


Najvažnije ULX4M datoteke uključuju LS/LD top-level Verilog wrappere, odgovarajuće LPF datoteke, ``ahb_litedram.v``, generirane LiteDRAM jezgre i uređive YAML profile, ULX4M makefileove te konfiguracijske datoteke bootloadera i OpenOCD-a.

Kako postupati s proturječnim izvorima
--------------------------------------

Koristite hijerarhiju izvora umjesto pretpostavke da je stranica koja izgleda
najnovije uvijek točna:

#. **Fizička pločica pred vama** - oznake i izmjereno ponašanje imaju prednost.
#. **Odgovarajuća revizija sheme/PCB-a/BOM-a** - najbolji dokaz projektne namjere.
#. **Odgovarajući LPF i projektni omotač** - izvor istine za ono što određeni
   Hazard3-Doom bitstream stvarno upravlja.
#. **Podatkovni list ugrađene komponente** - električna/vremenska ograničenja i
   geometrija.
#. **Stranice kampanje, README datoteke, primjeri i forumske objave** - koristan
   kontekst, ali često ovisan o reviziji.

Ako je razlika važna za izgradnju, dokumentirajte je u projektu umjesto da je
prešutno riješite samo lokalno. Tako sljedeći korisnik pločice ne mora ponavljati
istu istragu.

Povezana Hazard3-Doom dokumentacija
-----------------------------------

* :doc:`../../reference/board-profiles`
* :doc:`../../architecture/hazard3/memory-and-bus`
* :doc:`../../architecture/video`
* :doc:`../../user-guide/bootloader`
* :doc:`../../user-guide/sd-card`
* :doc:`../../user-guide/jtag-debugging`
* :doc:`../../reference/timing-sweeps`
