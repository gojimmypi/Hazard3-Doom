Pin ograničenja, sheme i PCB revizije
=====================================

ULX3S signal prolazi kroz više artefakata:

.. figure:: ../../images/ulx3s-pinout.png
   :alt: ULX3S raspored pinova

   **ULX3S raspored pinova** - dodjela FPGA GPIO signala i pinova konektora.

Ponovno upotrebljivi Tiny Tapeout ULX3S postupak ima vlastiti LPF pod
``tt/fpga/ulx3s/``. Nemojte mijenjati jednu datoteku ograničenja uz pretpostavku
da je koriste sve druge ULX3S izgradnje. Pogledajte
:doc:`../../getting-started/tiny-tapeout-ulx3s` za taj odvojeni postupak.

.. code-block:: text

   signal na shemi -> PCB vod/ECP5 kuglica -> LPF -> Verilog port -> periferija

Zato naziv Verilog signala nije dovoljan; aktivni LPF mora odgovarati stvarnoj
PCB reviziji.

Projektni izvori ograničenja
----------------------------

Glavna ULX3S implementacija nalazi se u Hazard3 submodulu pod
``example_soc/fpga/`` i ``example_soc/synth/``. Tiny Tapeout ULX3S workflow ima
zaseban LPF pod ``tt/fpga/ulx3s/``; ne treba pretpostaviti da svi buildovi koriste
isti constraints file.


.. code-block:: text

   third_party/Hazard3/example_soc/fpga/
   third_party/Hazard3/example_soc/synth/

Upstream sheme po reviziji
--------------------------

ULX3S repozitorij čuva PDF sheme za više revizija:

* `v3.0.8 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v308.pdf>`_
* `v3.1.4 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v314.pdf>`_
* `v3.1.6 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v316.pdf>`_
* `v3.1.7 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v317.pdf>`_

Ako se lokalne kopije dodaju u ovaj direktorij, zadržite PCB reviziju u nazivu,
primjerice ``ULX3S-v3.1.7-schematics.pdf``. Naziv poput ``ULX3S-v3.1.7-schematics.pdf`` mnogo je manje dvosmislen od ``ulx3s-schematics.pdf``.

Oprez s numeriranjem headera
----------------------------

Upstream constraint komentari razlikuju angled-female i vertical-male headere
pri tumačenju ``GP``/``GN`` fizičkih pinova. Za testirani Hazard3-Doom UART:

.. code-block:: text

   J1 pin 6 / GP0 -> Hazard3 TxD
   J1 pin 8 / GP1 -> Hazard3 RxD

Prije promjene pina utvrdite PCB reviziju, FPGA, odgovarajuću shemu, ECP5 pin i
I/O banku, LPF koji build stvarno koristi te svaki sharing s ESP32/ADC/SD, a
zatim provjerite rezultat na hardveru.

Disciplina revizija
-------------------

Prije promjene ULX3S pina ili sučelja specifičnog za pločicu:

#. Odredite reviziju PCB-a.
#. Odredite ugrađenu gustoću/pakiranje ECP5 uređaja.
#. Pronađite signal u odgovarajućoj shemi.
#. Potvrdite kuglicu pakiranja i I/O banku.
#. Provjerite potreban napon i I/O standard.
#. Odredite LPF koji koristi točan omotač izgradnje.
#. Potvrdite smjer i širinu Verilog porta najviše razine.
#. Provjerite dijeli li se signal s ESP32, ADC-om, SD-om ili drugim uređajem.
#. Izgradite projekt i pregledajte upozorenja/timing.
#. Provjerite fizičku funkciju na hardveru.

Tako razlike između sheme i ograničenja ostaju vidljive umjesto da se skrivaju u
lokalno kopiranom broju pina.
