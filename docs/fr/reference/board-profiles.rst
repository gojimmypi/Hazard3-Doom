Profils de cartes
=================

.. list-table::
   :header-rows: 1
   :widths: 30 25 20 25

   * - Carte
     - Profil mémoire
     - Horloge système
     - Note vidéo/build
   * - ULX3S 85F
     - ``64m``
     - 50 MHz
     - 320x200 par défaut ; modes étendus disponibles
   * - ULX3S 12F
     - ``32m`` par défaut ; ``64m`` en option
     - 40 MHz
     - Scanout SDRAM compact 320x200
   * - ULX4M-LD 85F
     - ``64m``
     - 50 MHz
     - Cible LiteDRAM
   * - ULX4M-LS 85F
     - ``32m``
     - Profil 50 MHz documenté
     - Référence du profil mémoire

Le moniteur, l'image Doom liée et la cartographie mémoire SDRAM doivent utiliser
le même profil mémoire. Les wrappers de build complets pour chaque carte règlent
automatiquement le profil et l'horloge propres à leur cible.

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
