Sources de conception et lectures complémentaires
=================================================

Ce guide conserve volontairement la visibilité des sources amont. Hazard3-Doom
ajoute une interprétation et des notes d'intégration, mais ne remplace pas la
documentation de la conception ULX4M.

Sources ULX4M principales
-------------------------

* `ULX4M sur Crowd Supply <https://www.crowdsupply.com/intergalaktik/ulx4m>`_
* `Dépôt matériel Intergalaktik ULX4M <https://github.com/intergalaktik/ulx4m>`_
* `Documentation Intergalaktik ULX4M <https://github.com/intergalaktik/ulx4m-documentation>`_
* `Exemples ULX4M <https://github.com/lawrie/ulx4m_examples>`_


Schémas ULX4M
-------------

Des copies locales des schémas des deux variantes ULX4M sont incluses dans
cette documentation :

:download:`Schéma ULX4M-LD v003 <ULX4M-LD-v003.pdf>`

:download:`Schéma ULX4M-LS v0.0.3 <ULX4M-LS-v0.0.3.pdf>`

ULX4M-LD et ULX4M-LS sont deux variantes de carte distinctes, et non deux
révisions d'une même carte. Utilisez le schéma correspondant à la carte utilisée.

Les schémas sont utiles pour suivre le FPGA, la DDR3, l'alimentation, JTAG, USB,
la carte SD, la vidéo et les autres connexions de niveau carte décrites dans ce
guide.

Les fichiers de conception originaux sont maintenus par le projet ULX4M.
Consultez le dépôt amont pour les fichiers sources et les révisions de schéma
plus récentes.

Sources Hazard3-Doom
--------------------

.. code-block:: text

   third_party/Hazard3/example_soc/fpga/
   third_party/Hazard3/example_soc/synth/
   third_party/Hazard3/example_soc/soc/
   third_party/Hazard3/example_soc/third_party/LiteDRAM/
   bootloader/
   openocd/

Pour résoudre une divergence, utilisez l'ordre de confiance suivant : la carte
physique, le schéma/PCB/BOM correspondant, le LPF et le wrapper du build, la
fiche technique du composant monté, puis les pages de campagne/README/exemples.
Documentez toute divergence qui influence un build.


Les fichiers ULX4M les plus importants comprennent les wrappers Verilog de niveau supérieur LS/LD, les LPF correspondants, ``ahb_litedram.v``, les cœurs LiteDRAM générés et leurs profils YAML modifiables, les makefiles ULX4M ainsi que les fichiers de configuration du bootloader et d'OpenOCD.

Comment traiter des sources contradictoires
-------------------------------------------

Utilisez une hiérarchie de sources au lieu de supposer que la page qui paraît la
plus récente est toujours correcte :

#. **La carte physique devant vous** - les marquages et le comportement mesuré
   priment.
#. **La révision correspondante du schéma/PCB/BOM** - meilleure indication de
   l'intention de conception.
#. **Le LPF et le wrapper du projet correspondants** - source de vérité sur ce
   qu'un bitstream Hazard3-Doom particulier commande réellement.
#. **La fiche technique du composant monté** - limites électriques/de timing et
   géométrie.
#. **Pages de campagne, README, exemples et messages de forum** - contexte utile,
   mais souvent dépendant de la révision.

Lorsqu'une divergence affecte un build, documentez-la dans le projet plutôt que
de la résoudre silencieusement en local. Le prochain utilisateur de la carte
n'aura ainsi pas à refaire la même enquête.

Documentation liée
------------------

* :doc:`../../reference/board-profiles`
* :doc:`../../architecture/hazard3/memory-and-bus`
* :doc:`../../architecture/video`
* :doc:`../../user-guide/bootloader`
* :doc:`../../user-guide/sd-card`
* :doc:`../../user-guide/jtag-debugging`
* :doc:`../../reference/timing-sweeps`
