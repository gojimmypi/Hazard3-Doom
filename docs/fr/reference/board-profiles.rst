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
     - DDR3L MT41K512M16HA-125 de 1 Gio ; ``ahb_litedram`` + LiteDRAM généré/``ECP5DDRPHY``
     - CPU/AHB 40 MHz par défaut ; port utilisateur LiteDRAM 75 MHz
     - Cible LiteDRAM ; dérogation de timing requise
   * - ULX4M-LS 85F
     - ``32m``
     - SDR SDRAM 16 bits de 32 Mio ; chemin du contrôleur natif ``ahb_sdram``
     - 50 MHz
     - Chemin mémoire SDR natif

Le moniteur, l'image Doom liée et la cartographie mémoire SDRAM doivent utiliser
le même profil mémoire. Les wrappers de build complets pour chaque carte règlent
automatiquement le profil et l'horloge propres à leur cible.

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
     - 55
     - ``clk_sys`` 51.77 MHz
     - PASS à 50 MHz
   * - ULX3S 12F
     - 65
     - ``clk_sys`` 42.11 MHz
     - PASS à 40 MHz
   * - ULX4M-LD 85F
     - 232
     - ``clk_sys`` 38.69 MHz ; LiteDRAM 62.52 MHz
     - FAIL à 40 MHz / 75.01 MHz

Le build ULX4M-LD utilise donc ``ALLOW_TIMING_FAILURE=1`` lorsqu'un bitstream
de développement est nécessaire. Cette dérogation transforme les échecs de
timing en avertissements signalés ; elle ne prétend pas que le timing est fermé.
Relancez le timing routé après toute modification importante du RTL, du netlist,
du seed ou de la chaîne d'outils. Le résultat ULX3S 85F est propre au modèle de
timing sélectionné par le flux actuel du projet et ne doit pas être comparé
directement à des exécutions utilisant un autre modèle de timing ECP5. Voir
:doc:`timing-sweeps` pour la provenance des sweeps et les règles de comparaison.

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
