Cartographie mémoire
====================

Les adresses de cette page appartiennent à l'**intégration SoC** de Hazard3-Doom,
et non à l'ISA RISC-V ni à une cartographie mémoire fixe du processeur Hazard3.
Hazard3 émet des transactions normales d'instructions et de données ; le SoC
environnant décode ces fenêtres d'adresses physiques. Voir
:doc:`hazard3/memory-and-bus` pour la frontière CPU/bus.

SRAM interne
------------

Les 128 Kio de SRAM EBR de l'ECP5 sont répartis ainsi :

.. list-table::
   :header-rows: 1

   * - Plage
     - Utilisation
   * - ``0x00000000-0x0000FFFF``
     - Moniteur résident, traps et pile moniteur/Doom.
   * - ``0x00010000-0x0001F9FF``
     - Écran de travail indexé Doom 320x200.
   * - ``0x0001FA00-0x0001FFFF``
     - SRAM interne inutilisée.

Profil SDRAM 64 Mio
-------------------

Utilisé par ULX3S 85F et ULX4M-LD 85F :

.. list-table::
   :header-rows: 1

   * - Plage
     - Utilisation
   * - ``0x20000000-0x23FFFFFF``
     - 64 Mio de mémoire externe physique.
   * - ``0x24000000-0x27FFFFFF``
     - Alias de diagnostic non mis en cache.
   * - ``0x20100000-0x203FFFFF``
     - Image Doom liée et mise en cache.
   * - ``0x20400000-0x22BFFFFF``
     - Tas et mémoire de zone Doom mis en cache.
   * - ``0x22C00000-0x23BFFFFF``
     - Réservation IWAD mise en cache, 16 Mio.
   * - ``0x23C00000-0x23FFFFFF``
     - Réservation vidéo non mise en cache.

Profil SDRAM 32 Mio
-------------------

Utilisé par ULX4M-LS 85F :

.. list-table::
   :header-rows: 1

   * - Plage
     - Utilisation
   * - ``0x20000000-0x21FFFFFF``
     - 32 Mio de SDRAM physique.
   * - ``0x24000000-0x25FFFFFF``
     - Alias de diagnostic non mis en cache.
   * - ``0x20100000-0x203FFFFF``
     - Image Doom liée et mise en cache.
   * - ``0x20400000-0x20FFFFFF``
     - Tas Doom mis en cache, 12 Mio.
   * - ``0x21000000-0x21BFFFFF``
     - Réservation IWAD mise en cache, 12 Mio.
   * - ``0x21C00000-0x21FFFFFF``
     - Réservation vidéo non mise en cache.
