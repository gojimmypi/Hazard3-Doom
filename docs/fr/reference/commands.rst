Référence des commandes du moniteur
===================================

Démarrage et Doom
-----------------

.. list-table::
   :header-rows: 1

   * - Commande
     - Description
   * - ``l``
     - Recevoir une image Doom empaquetée via UART.
   * - ``w``
     - Recevoir l'IWAD via UART.
   * - ``j``
     - Lancer l'exécutable et le WAD validés.
   * - ``b``
     - Exécuter le chargeur de démarrage SD.
   * - ``c``
     - Afficher l'état du démarrage SD/FAT.

SAO / I2C
---------

.. list-table::
   :header-rows: 1

   * - Commande
     - Description
   * - ``sao info``
     - Afficher l'état du pont SAO/de la propriété du bus.
   * - ``sao gui``
     - Lancer l'interface de diagnostic HDMI de type I2CDriver.
   * - ``sao recover``
     - Tenter une récupération du bus.
   * - ``sao scan``
     - Analyser le bus I2C SAO.
   * - ``sao probe``
     - Sonder un périphérique/une adresse.
   * - ``sao read``
     - Lire depuis une cible I2C SAO.
   * - ``sao write``
     - Écrire vers une cible I2C SAO.
   * - ``i2c scan``
     - Analyser le bus I2C avec la commande de compatibilité.
   * - ``i2c gui``
     - Alias de ``sao gui``.

Commandes I2C HDMI interactives
-------------------------------

Après le démarrage de ``sao gui`` ou ``i2c gui``, l'UART devient l'entrée
clavier de l'interface HDMI. ``S`` analyse le bus, ``P`` sonde une adresse,
``R`` lit un registre, ``W`` écrit un registre, ``X`` tente une récupération
du bus, ``1``/``4`` sélectionnent 100/400 kHz, ``C`` efface l'état de
affichage et ``Q`` quitte. Voir :doc:`../user-guide/i2cdriver` pour la saisie
des opérandes, les remarques de sécurité et le comportement de la trace logique.

Octets de contrôle réservés Web Serial
--------------------------------------

Ces octets bruts appartiennent au transport de capture d'écran du navigateur et
ne sont pas des commandes texte du moniteur résident :

.. list-table::
   :header-rows: 1

   * - Octet
     - Rôle
   * - ``0x1c``
     - Requête de capacité de capture d'écran.
   * - ``0x06``
     - ACK de capacité provenant d'un cache de moniteur pris en charge ou d'une application d'affichage active.
   * - ``0x1d``
     - Requête de capture d'écran.

Voir :doc:`../user-guide/web-serial` pour le protocole ``H3SNIP1`` complet et
sa machine d'états.
