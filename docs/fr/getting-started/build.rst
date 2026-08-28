Construire Hazard3-Doom
=======================

Builds complets des cartes
--------------------------

Les wrappers de build complets des cartes sont la manière la plus sûre de
construire un ensemble cohérent FPGA, moniteur et image Doom pour une cible.

ULX3S 85F, 64 Mio, 50 MHz :

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh

Cible compacte ULX3S 12F, 32 Mio par défaut, 40 MHz :

.. code-block:: bash

   ./scripts/build-ulx3s-12f-doom.sh

ULX4M-LD 85F, 64 Mio, 50 MHz :

.. code-block:: bash

   ./scripts/build-ulx4m-ld-doom.sh

Le wrapper 12F prend en charge une cartographie SDRAM 32 Mio ou 64 Mio, mais
utilise 32 Mio par défaut. Si la cartographie 64 Mio est sélectionnée, gardez le
moniteur et l'image Doom cohérents :

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=64m ./scripts/build-ulx3s-12f-doom.sh

La cible compacte 12F prend volontairement en charge uniquement le chemin
Doom/vidéo 320x200. Après programmation du bitstream 12F et démarrage d'OpenOCD,
chargez son moniteur résident en SDRAM avec :

.. code-block:: bash

   ./scripts/load-firmware-12f.sh

Moniteur résident uniquement
----------------------------

Le constructeur générique du moniteur utilise par défaut la cartographie 64 Mio à 50 MHz :

.. code-block:: bash

   ./scripts/build.sh

Sorties typiques :

.. code-block:: text

   build/hazard3-boot-monitor.elf
   build/hazard3-boot-monitor.map
   build/hazard3-boot-monitor.bin

Les wrappers complets des cartes règlent pour vous le profil mémoire, l'horloge
système et le script de linker propres à la cible. Pour les builds manuels, les
principaux contrôles sont ``HAZARD3_MEMORY_PROFILE``, ``HAZARD3_SYS_CLK_HZ`` et
``HAZARD3_MONITOR_LINKER_SCRIPT``.

Image Doom liée uniquement
--------------------------

Pour le profil 64 Mio utilisé par ULX3S 85F et ULX4M-LD 85F :

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=64m ./doom/build-doom-image.sh

Pour une image 12F 32 Mio :

.. code-block:: bash

   HAZARD3_MEMORY_PROFILE=32m \
   HAZARD3_DOOM_HDMI_RESOLUTION=320x200 \
       ./doom/build-doom-image.sh

Sorties typiques :

.. code-block:: text

   build/doom-image/hazard3-doom.elf
   build/doom-image/hazard3-doom.map
   build/doom-image/hazard3-doom.bin
   build/doom-image/hazard3-doom.h3d

Tester un autre checkout Hazard3
--------------------------------

Vous pouvez tester un checkout matériel sans modifier le pointeur du sous-module
Hazard3-Doom épinglé :

.. code-block:: bash

   HAZARD3_ROOT=/mnt/c/workspace/Hazard3 \
       ./scripts/build-ulx3s-doom.sh

Préparation et vérification des sous-modules
--------------------------------------------

Initialisez les sous-modules nécessaires au build :

.. code-block:: bash

   ./scripts/setup-submodules.sh

Cela initialise DoomGeneric et Hazard3 ainsi que les sous-modules Hazard3
imbriqués ``scripts`` et ``example_soc/libfpga``. Pour initialiser l'arbre
récursif complet :

.. code-block:: bash

   HAZARD3_INIT_ALL_SUBMODULES=1 ./scripts/setup-submodules.sh

Pour les diagnostics d'historique de source et de sous-modules, voir
:doc:`../reference/scripts`. En particulier, la commande Windows
``check_submodules.bat`` valide les gitlinks enregistrés localement, tandis que
``hazard3-doom-source-status.sh`` compare les branches entre les forks GitHub
associés.

Sélection des seeds
-------------------

Ne réutilisez pas aveuglément un seed nextpnr précédemment bon après une
modification importante de la netlist. Utilisez les scripts de placement seul
pour classer rapidement les candidats, puis les sweeps routés pour le timing
autoritatif et la génération du bitstream.

Par exemple, le flux 12F peut utiliser :

.. code-block:: bash

   SWEEP_JOBS=30 ./scripts/sweep-peek-ulx3s-12f.sh --all
   SWEEP_JOBS=30 ./scripts/sweep-ulx3s-12f.sh --all

Voir :doc:`../reference/scripts` pour les outils de sweep 85F, 12F et ULX4M-LD
ainsi que les emplacements des résultats.

Propriété du build
------------------

Le projet conserve volontairement le matériel FPGA/CPU réutilisable dans
Hazard3, tandis que le moniteur et l'application spécifiques à Doom restent dans
Hazard3-Doom. Voir :doc:`../architecture/repositories`.
