Guide de compilation
====================

Les instructions détaillées de compilation se trouvent dans
:doc:`../getting-started/build`. Cette page relie ce processus aux prérequis,
aux profils de cartes, à la référence des scripts et aux informations de timing
utiles lors d'une recompilation ou d'un changement de cible.

Compilations normales des cartes
---------------------------------

Pour une compilation normale, utilisez de préférence le wrapper complet de la
carte cible. Ces wrappers maintiennent ensemble la conception FPGA, le moniteur
résident, l'image Doom, l'horloge et le profil mémoire :

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh
   ./scripts/build-ulx3s-12f-doom.sh
   ./scripts/build-ulx4m-ld-doom.sh

Consultez :doc:`../getting-started/build` pour les configurations de cartes
prises en charge, les reconstructions sélectives du moniteur et de l'image Doom,
la préparation des sous-modules, les fichiers de sortie et les variables
d'environnement propres à la compilation.

Versions des outils et reproductibilité
----------------------------------------

Les résultats de timing FPGA dépendent de plus que de l'arborescence source.
Yosys, nextpnr, Project Trellis, les paramètres de routage et la seed choisie
peuvent tous modifier le résultat. Vérifiez l'environnement avant de compiler :

.. code-block:: bash

   ./scripts/requirements-check.sh

Consultez :doc:`../getting-started/prerequisites` pour les outils requis sur la
machine hôte. Les valeurs nextpnr propres à chaque carte sont définies dans
``scripts/build-ecp5-bitstream-common.sh`` et résumées directement à partir de ce
fichier dans :doc:`../reference/board-profiles`.

Une seed qui a satisfait le timing avec une netlist ou une version d'outil ne
garantit pas le timing avec une autre. Si le résultat de synthèse, la version des
outils CAO, l'horloge ou la configuration de routage change, relancez la
validation de timing appropriée avant d'utiliser le résultat pour une version
publiée. Consultez :doc:`../reference/timing-sweeps` pour le processus de sweep
et de qualification.

Scripts de compilation et procédures avancées
----------------------------------------------

Pour le catalogue complet des outils d'aide à la compilation, à la
programmation, à la validation, au nettoyage et au timing, consultez
:doc:`../reference/scripts`. Cette référence documente les wrappers complets des
cartes ainsi que les outils de plus bas niveau pour le moniteur, le bitstream,
l'image Doom et les sweeps de seeds.

Pour l'organisation du dépôt et la séparation entre le matériel Hazard3 et le
logiciel propre à Hazard3-Doom, consultez :doc:`../architecture/repositories`.
