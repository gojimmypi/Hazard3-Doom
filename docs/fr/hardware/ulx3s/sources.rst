Sources de conception et lectures complémentaires
=================================================

Hazard3-Doom ajoute une interprétation spécifique au projet sans remplacer la
documentation matérielle ULX3S d'origine.

Sources ULX3S principales
-------------------------

* `Dépôt matériel ULX3S <https://github.com/emard/ulx3s>`_ - sources KiCad,
  schémas, PCB, BOM, contraintes et historique.
* `Manuel ULX3S <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_ -
  connecteurs, alimentation, programmation, ESP32 et différences de révision.
* `ULX3S sur Crowd Supply <https://www.crowdsupply.com/radiona/ulx3s>`_ - vue
  d'ensemble et contexte commercial.
* `ULX3S Quick Start <https://github.com/ulx3s/quick-start>`_.
* `ULX3S Pinout <https://github.com/ulx3s/ulx3s-pinout>`_.

PDF de schémas
--------------

Le dépôt amont conserve notamment les révisions
`3.0.8 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v308.pdf>`_,
`3.1.4 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v314.pdf>`_,
`3.1.5 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v315.pdf>`_,
`3.1.6 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v316.pdf>`_ et
`3.1.7 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v317.pdf>`_.

Si des copies sont conservées sous ``docs/hardware/ulx3s/``, gardez la révision
dans le nom et le lien amont à côté de la copie locale.

Sources Hazard3-Doom
--------------------

Les éléments ULX3S du projet se trouvent principalement sous
``third_party/Hazard3/example_soc/fpga/``, ``synth/``, ``soc/``, ainsi que dans
``scripts/``, ``bootloader/``, ``openocd/`` et ``web/``.

En cas de divergence entre sources, donnez priorité au matériel physique, puis
au schéma/PCB/BOM correspondant, au LPF/wrapper du build exact, à la fiche
technique du composant et enfin aux descriptions générales.

Voir aussi :doc:`../../reference/board-profiles`,
:doc:`../../architecture/hazard3/memory-and-bus`, :doc:`../../architecture/video`,
:doc:`../../getting-started/programming`, :doc:`../../user-guide/bootloader`,
:doc:`../../user-guide/sd-card`, :doc:`../../user-guide/web-flasher` et
:doc:`../../user-guide/jtag-debugging`.
