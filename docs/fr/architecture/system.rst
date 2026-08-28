Architecture système
====================

Hazard3-Doom est une pile matériel/logiciel plutôt qu'un unique binaire de
firmware. Le processeur en son centre est le RTL Hazard3 paramétrable standard ;
le projet Doom ajoute autour de ce processeur l'intégration mémoire, vidéo,
stockage, SAO et démarrage propre aux cartes.

Pour un parcours détaillé du CPU, comprenant le pipeline F/X/M, les extensions
ISA sélectionnées, les CSR, les interruptions, l'interface de bus et le chemin
de débogage RISC-V, voir :doc:`hazard3/index`.

Composants principaux
---------------------

.. list-table::
   :header-rows: 1
   :widths: 25 75

   * - Composant
     - Rôle
   * - CPU Hazard3
     - Processeur RISC-V RV32 à trois étages. Ce projet sélectionne M, C, Zba, Zbb, Zbs, Zifencei, les compteurs, le support de débogage, les options de multiplication rapide, la comparaison de branche rapide et le petit prédicteur de branche ; A est désactivé.
   * - Hazard3 Debug Module/DTM
     - Infrastructure de débogage RISC-V amont connectée au TAP JTAG de la puce ECP5 et utilisée par OpenOCD/GDB.
   * - Moniteur résident
     - Firmware de démarrage, diagnostics, chargement UART, démarrage SD et récupération dans la SRAM EBR interne.
   * - SDRAM externe
     - Sous-système mémoire du SoC du projet stockant l'image Doom liée, la mémoire heap/zone, l'IWAD et les zones de staging vidéo.
   * - Moteur HDMI
     - Logique d'affichage du projet présentant le framebuffer Doom indexé.
   * - Interface micro-SD
     - Matériel APB/SPI du projet utilisé pour le chargement autonome de l'exécutable/IWAD après mise sous tension.
   * - Pont APB SAO
     - Accès mémoire-mappé du projet au SAO I2C/GPIO et contrôle des ressources partagées.
   * - ESP32
     - Processeur compagnon optionnel partageant certaines ressources de la carte via des règles explicites de propriété.
   * - OpenOCD/GDB
     - Chemin de débogage côté hôte au niveau du code source via l'architecture standard de débogage externe de Hazard3.

Frontière CPU / SoC
-------------------

Une manière utile de raisonner sur le design consiste à séparer les couches
processeur et plateforme :

.. code-block:: text

   +-------------------------------------------+
   | Hazard3 CPU/debug                         |
   | RISC-V ISA, F/X/M pipeline, CSRs, traps   |
   +-------------------------------------------+
                       |
                       | AHB5
                       v
   +-------------------------------------------+
   | Example SoC and project integration       |
   | SRAM, APB, timer, UART, SDRAM, SD, SAO    |
   +-------------------------------------------+
                       |
                       v
   +-------------------------------------------+
   | ULX3S/ULX4M board hardware                |
   | ECP5, SDRAM, HDMI, micro-SD, ESP32, pins  |
   +-------------------------------------------+

Le processeur exécute des loads et stores RISC-V ordinaires. Le décodeur
d'adresses du SoC détermine si ces accès atteignent la SRAM interne, un
périphérique APB, la SDRAM externe ou une autre cible mappée. De même, la vidéo
Doom et le comportement de la carte SD sont des fonctionnalités de plateforme,
pas des instructions CPU spéciales.

Chemins de démarrage
--------------------

Démarrage de développement
~~~~~~~~~~~~~~~~~~~~~~~~~~

Chargement FPGA -> moniteur résident -> téléversement UART ``.h3d`` -> téléversement UART ``DOOM.WAD`` -> lancement.

Démarrage autonome
~~~~~~~~~~~~~~~~~~

Configuration FPGA depuis flash SPI -> moniteur résident EBR préchargé -> initialisation SDRAM -> micro-SD ``DOOM.H3D`` + ``DOOM.WAD`` -> lancement.

Le préchargement SRAM du moniteur résident est une personnalisation du fork
Hazard3 ULX3S. Il permet au système de démarrer immédiatement un firmware utile
après configuration du FPGA, sans exiger d'abord un téléchargement via le
débogueur.

Périphériques APB
-----------------

Les régions APB importantes propres au projet comprennent :

.. list-table::
   :header-rows: 1

   * - Base
     - Fonction
   * - ``0x40009000``
     - Pont SAO.
   * - ``0x4000A000``
     - Interface SD SPI.
   * - ``0x4000C000``
     - Registres de contrôle HDMI/vidéo.

Ces périphériques sont des ajouts autour du processeur Hazard3. Gardez les
définitions de registres logiciel synchronisées avec le commit du sous-module
matériel Hazard3 correspondant.
