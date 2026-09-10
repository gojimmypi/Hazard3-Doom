Guides matériels
================

Hazard3-Doom est conçu pour être exploré depuis le logiciel jusqu'à la carte.
Ces pages décrivent les plates-formes FPGA physiques, les composants autour du
FPGA et la manière dont ils deviennent des ressources utilisables par
Hazard3-Doom.

Ces guides complètent la documentation d'origine des cartes. Ils ne remplacent
ni les schémas, ni les nomenclatures, ni les fiches techniques, ni les notes de
révision. Leur objectif est de relier le matériel physique au Verilog, aux
contraintes, aux contrôleurs mémoire, au firmware et aux outils de débogage du
projet.

.. toctree::
   :maxdepth: 2

   ulx3s/index
   ulx4m/index

Pourquoi un guide matériel ?
----------------------------

Le seul nom d'une carte masque plusieurs couches importantes. Une conception
FPGA doit connaître le boîtier exact du FPGA, la mémoire montée, la broche de
chaque signal, la norme d'E/S requise, la provenance des horloges et les
interfaces réellement routées vers les connecteurs. Le logiciel ajoute ensuite
d'autres questions : quel contrôleur possède le matériel, où il apparaît dans
la carte mémoire et ce qui a réellement été validé sur une carte physique.

Lorsqu'une page publique, un schéma amont et une carte assemblée ne concordent
pas, le guide conserve cette différence au lieu de choisir silencieusement une
source.
