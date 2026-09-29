Vue d'ensemble et variantes
===========================

Qu'est-ce que l'ULX4M ?
-----------------------

ULX4M est une famille de modules FPGA open hardware conçus pour des cartes
porteuses utilisant le format mécanique et les connecteurs du Raspberry Pi
Compute Module 4. La famille reprend l'idée de l'ULX3S dans un format de module
compact et expose davantage de connexions haut débit.

``ULX4M-LS``
   Lattice ECP5 avec SDR SDRAM externe.

``ULX4M-LD``
   Lattice ECP5 avec DDR3/DDR3L externe. Hazard3-Doom utilise LiteDRAM et le PHY
   DDR ECP5 sur cette cible.

Les spécifications publiques dépendent de la révision
------------------------------------------------------

Les sources publiques décrivent plusieurs révisions et choix de composants. Il
faut donc rattacher chaque référence à une source ou à une carte physique.

.. list-table:: Exemples de descriptions publiques
   :header-rows: 1
   :widths: 22 26 26 26

   * - Source/variante
     - Mémoire décrite
     - Ethernet décrit
     - Interprétation
   * - Crowd Supply ULX4M-LS
     - 64 MiB ``IS42S16320D-6BLI``
     - ``KSZ9031RNXCA``
     - Configuration LS promue par la page du projet.
   * - Manuel amont ULX4M-LS
     - 32 MiB ``IS42S16160G-7BL``
     - ``LAN8720A``
     - Population LS antérieure ou différente.
   * - Crowd Supply ULX4M-LD
     - 1 GiB ``MT41K512M16HA-125``
     - ``KSZ9031RNXCA``
     - Correspond à la classe Micron 8 Gbit prise en charge par Hazard3-Doom.
   * - Manuel amont ULX4M-LD
     - 512 MiB ``MT41K256M16TW-107``
     - ``KSZ9031RNXCA``
     - Autre population/révision LD documentée.
   * - Profils LD Hazard3-Doom
     - ``MT41K512M16HA`` ou ``AS4C256M16D3``
     - Non utilisé par la conception Doom actuelle
     - Profils de contrôleur pris en charge, pas une affirmation sur toutes les cartes.

Il faut identifier le matériel réel avant de sélectionner le profil de build.

Résumé des cibles Hazard3-Doom
------------------------------

Les profils de carte actuels du projet sont résumés ci-dessous. Consultez
:doc:`../../reference/board-profiles` pour l'enregistrement de qualification de la version.

.. list-table::
   :header-rows: 1
   :widths: 20 20 24 18 18

   * - Cible
     - Classe FPGA
     - Mémoire externe
     - Horloge Hazard3
     - État du projet
   * - ULX4M-LS 85F
     - Build ECP5 85K
     - SDR SDRAM 16 bits via le contrôleur SDR natif
     - 50 MHz
     - Chemin de build pris en charge; vérifier la révision et la population.
   * - ULX4M-LD 85F
     - ``LFE5UM-85F-8BG381C``
     - DDR3 x16 via LiteDRAM/``ECP5DDRPHY``
     - 40 MHz
     - Qualifié matériellement avec le profil Micron 8 Gbit; profil Alliance également généré.

Le build LS actuel exige un FPGA de classe 85K car la configuration complète de
Doom consomme plus de blocs EBR que le composant 12K n'en offre.

Ressources de la carte
----------------------

Les variantes ULX4M publiées proposent notamment FPGA ECP5, mémoire externe,
flash SPI, USB DFU, JTAG, vidéo GPDI, micro-SD, Ethernet, connecteurs CSI/DSI,
GPIO, boutons, interrupteurs, LED et, lorsque le FPGA et le routage le
permettent, des voies SerDes/PCIe.

Cette liste décrit le matériel disponible, pas nécessairement les périphériques
que le SoC Hazard3-Doom utilise aujourd'hui.

Suivre une transaction mémoire
------------------------------

Sur ULX4M-LD, une lecture de Doom suit approximativement :

.. code-block:: text

   Hazard3 -> AHB5 -> ahb_litedram.v -> CDC -> Wishbone 128 bits
           -> LiteDRAM -> ECP5DDRPHY -> DDR3 x16

Sur ULX4M-LS, le même accès logiciel aboutit au contrôleur SDR natif. Cette
différence permet d'étudier deux sous-systèmes mémoire très différents sans
changer fondamentalement le processeur.
