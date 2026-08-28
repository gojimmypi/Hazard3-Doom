Organisation des dépôts et propriété
====================================

Hazard3-Doom sépare volontairement la propriété de l'application du RTL
réutilisable du processeur/débogage Hazard3 et de l'intégration SoC spécifique à
ULX3S construite autour de celui-ci.

Arborescence du dépôt
---------------------

.. code-block:: text

   Hazard3-Doom/
   |-- benchmarks/coremark/
   |-- bin/
   |-- doom/
   |-- examples/esp32-sao-shared/
   |-- openocd/
   |-- scripts/
   |-- src/
   |-- tests/
   |-- third_party/Hazard3/
   |-- third_party/doomgeneric/
   |-- VisualGDB/
   |-- wads/
   `-- build/                  generated, ignored

Trois couches de propriété
--------------------------

Il est utile de répartir la propriété du matériel en trois couches plutôt que
d'appeler simplement tout ce qui se trouve sous le sous-module Hazard3 « matériel
Hazard3 » :

.. list-table::
   :header-rows: 1
   :widths: 32 24 44

   * - Élément
     - Propriétaire/origine principal
     - Emplacement / remarques
   * - Pipeline CPU Hazard3 et RTL de processeur réutilisable
     - Wren6991/Hazard3 amont
     - ``third_party/Hazard3/hdl/`` ; pipeline F/X/M, décodeur, CSR, ALU, fichier de registres, wrappers CPU et fonctions architecturales optionnelles.
   * - Hazard3 Debug Module et DTM
     - Wren6991/Hazard3 amont
     - ``third_party/Hazard3/hdl/debug/`` ; comprend le transport ECP5 JTAGG utilisé sur ULX3S.
   * - Fondation du SoC d'exemple minimal
     - Wren6991/Hazard3 amont
     - Intégration CPU/débogage/RAM/UART/timer que le fork étend.
   * - Extensions SoC et cartes ULX3S/ULX4M
     - Fork ulx3s/Hazard3 / intégration du projet
     - SDRAM, vidéo, SD SPI, SAO/ESP32, préchargement du moniteur résident, synthèse et câblage de carte supplémentaires sous ``third_party/Hazard3/example_soc/``.
   * - Moniteur résident et chargeurs
     - Hazard3-Doom
     - ``src/`` et ``doom/``.
   * - Wrappers complets de build carte/application
     - Hazard3-Doom
     - ``scripts/build-*-doom.sh`` et outils associés.
   * - Source d'application DoomGeneric amont/forkée
     - DoomGeneric
     - ``third_party/doomgeneric/``.

Instantané du code source Hazard3
---------------------------------

La documentation du processeur est rattachée à l'instantané Hazard3 du projet :

``736a74459b3f740c47803f20a62d820fcacbe5c3``

* `Source Hazard3 ULX3S épinglée <https://github.com/ulx3s/Hazard3/tree/736a74459b3f740c47803f20a62d820fcacbe5c3>`_
* `Hazard3 stable amont actuel <https://github.com/Wren6991/Hazard3/tree/stable>`_
* :doc:`hazard3/project-integration` - comparaison détaillée entre amont et projet.

Le commit épinglé est la source de vérité pour le build du projet. L'amont
actuel sert de référence pour ce que Hazard3 maintient aujourd'hui, mais les
nouvelles fonctionnalités amont ne deviennent pas des fonctionnalités du projet
tant que le sous-module n'est pas mis à jour délibérément.

Comment classer une modification
--------------------------------

Une règle pratique est :

Comportement du processeur
   Le décodage ISA, les hazards du pipeline, la sémantique des CSR, le
   comportement des traps, le débogage générique et les corrections de wrappers
   CPU réutilisables doivent normalement être évalués comme travail Hazard3 amont.

Comportement SoC réutilisable mais spécifique à la plateforme
   Les contrôleurs SDRAM, l'horloge de carte, l'intégration ECP5 et les
   périphériques généralisés peuvent appartenir à la couche fork Hazard3/SoC
   d'exemple.

Comportement de l'application
   Les commandes du moniteur résident, le chargement Doom, la politique du
   framebuffer, les outils hôte et les workflows utilisateur appartiennent à
   Hazard3-Doom.

Sous-modules
------------

Le superprojet épingle des commits Hazard3 et DoomGeneric exacts. Inspectez
toujours à la fois la branche du superprojet et le commit du sous-module avant
de diagnostiquer une régression. Le nom d'une branche seul ne suffit pas pour
reproduire le matériel.
