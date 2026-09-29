Profils de cartes
=================

.. list-table::
   :header-rows: 1
   :widths: 18 16 28 14 24

   * - Carte
     - Profil mémoire
     - Mémoire externe/contrôleur
     - Horloge système
     - Note vidéo/build
   * - ULX3S 85F
     - ``64m``
     - SDR SDRAM 16 bits ; chemin du contrôleur natif ``ahb_sdram``
     - 50 MHz
     - 320x200 par défaut ; modes étendus disponibles
   * - ULX3S 12F
     - ``32m`` par défaut ; ``64m`` en option
     - SDR SDRAM 16 bits ; chemin du contrôleur natif ``ahb_sdram``
     - 40 MHz
     - Scanout SDRAM compact 320x200
   * - ULX4M-LD 85F
     - ``64m``
     - Profil DDR3/DDR3L Micron ``MT41K512M16HA`` ou Alliance ``AS4C256M16D3`` ; ``ahb_litedram`` + LiteDRAM généré/``ECP5DDRPHY``
     - CPU/AHB 40 MHz ; port utilisateur LiteDRAM 60 MHz ; référence/init 25 MHz
     - Micron qualifié sur le matériel ; profils générés propres au composant
   * - ULX4M-LS 85F
     - ``32m``
     - SDR SDRAM 16 bits de 32 Mio ; chemin du contrôleur natif ``ahb_sdram``
     - 50 MHz
     - Chemin mémoire SDR natif

Le moniteur, l'image Doom liée et la cartographie mémoire SDRAM doivent utiliser
le même profil mémoire. Les wrappers de build complets pour chaque carte règlent
automatiquement le profil et l'horloge propres à leur cible.

Paramètres de routage nextpnr par défaut
----------------------------------------

Les wrappers des cartes prennent leurs paramètres de routage par défaut dans
une seule implémentation commune, ``scripts/build-ecp5-bitstream-common.sh``.
Les affectations actuelles sont incluses directement depuis ce fichier afin que
la documentation n'en conserve pas une seconde copie :

.. literalinclude:: ../../scripts/build-ecp5-bitstream-common.sh
   :language: bash
   :start-at: ULX3S_85F_DEFAULT_NEXTPNR_SEED=
   :end-at: ULX4M_LD_85F_DEFAULT_NEXTPNR_HEAP_TIMINGWEIGHT=

``NEXTPNR_SEED`` peut toujours remplacer la valeur par défaut de la carte pour
un routage explicite. Ces valeurs sont des références de release, pas des
optima permanents.

Validation FPGA actuelle
------------------------

Les valeurs routées ci-dessous sont des points de contrôle de régression issus
des builds du projet. Les révisions exactes, le SHA256 du netlist, les versions
des outils CAD et les paramètres du sweep doivent être lus dans l'artifact
correspondant ; ces valeurs ne sont pas des garanties de timing portables :

.. list-table::
   :header-rows: 1
   :widths: 24 12 40 24

   * - Carte
     - Seed
     - Résultat routé
     - État
   * - ULX3S 85F
     - 11
     - ``clk_sys`` 52.24 MHz
     - PASS à 50 MHz
   * - ULX3S 12F
     - 82
     - ``clk_sys`` 42.70 MHz
     - PASS à 40 MHz
   * - ULX4M-LD 85F
     - 83
     - ``clk_sys`` 43.63 MHz ; port utilisateur LiteDRAM 67.51 MHz
     - PASS à 40 MHz / 60 MHz ; route sélectionnée pour la release

Ces lignes de validation de release conservent volontairement le seed car il
fait partie de la provenance du résultat de timing. Les valeurs par défaut
elles-mêmes sont gérées par le script de build commun ci-dessus.

Le point de contrôle ULX4M-LD qualifié sur le matériel utilise un netlist
figé, le seed 2 et
HeAP ``timingweight=30``. Le bitstream testé sur le matériel a pour SHA256
``294602982dfc4a9906961f2e8b6f43de925d8c11a7e5e6bb0f5e392965a868de``.
La carte équipée de mémoire Micron a réussi la suite complète de qualification
DDR, le stress du heap, le test Doom et l'exécution RV32 depuis la DDR. Un
nouveau netlist doit être routé puis qualifié à nouveau ; un PASS de timing seul
ne suffit pas. Voir :doc:`timing-sweeps` pour la provenance et les règles de
comparaison.

Le point de contrôle ULX4M-LD qualifié sur matériel est nettement plus robuste
que l'ancien état de développement ``ALLOW_TIMING_FAILURE``. La netlist figée
exacte était :

.. code-block:: text

   160c536b12e46667990c887571da6f443ccc6c5a2ba644033db43fc783ea9453

Le routage qualifié sur matériel et conforme au timing utilisait le seed 2 de
nextpnr avec HeAP ``timingweight=30``. Le bitstream exact testé localement avait
pour SHA256 :

.. code-block:: text

   294602982dfc4a9906961f2e8b6f43de925d8c11a7e5e6bb0f5e392965a868de

La même netlist figée échouait avec l'ancien réglage HeAP ``timingweight=10``, ce
qui montre que les paramètres de placement/routage font partie du dossier de
qualification et ne sont pas un détail accessoire.

La validation matérielle sur la carte Micron a ensuite réussi la suite complète
``q`` de qualification SDRAM, le stress du tas de 40 Mio, le test rapide de la
plate-forme Doom et l'exécution RV32 copiée depuis la DDR. Un PASS de timing seul
ne suffit pas pour revendiquer une qualification DDR.

Une nouvelle précharge du moniteur résident ou toute autre modification visible
par la synthèse crée une nouvelle netlist. Conservez l'artefact seed 2 qualifié
comme référence, puis relancez le routage et la qualification.

Bases principales des périphériques ULX3S
-----------------------------------------

.. list-table::
   :header-rows: 1

   * - Périphérique
     - Base
   * - Pont SAO
     - ``0x40009000``
   * - SD SPI
     - ``0x4000A000``
   * - HDMI/vidéo
     - ``0x4000C000``
