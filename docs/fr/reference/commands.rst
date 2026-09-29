Référence des commandes du moniteur
===================================


Qualification de la mémoire externe
------------------------------------

Le chemin DDR3 de l'ULX4M-LD a été qualifié sur matériel avec les commandes du
moniteur ci-dessous. Attendez que ``s`` indique ``external_memory_ready=YES``
avant d'exécuter des tests mémoire destructifs.

.. list-table::
   :header-rows: 1

   * - Commande
     - Description
   * - ``m``
     - Test destructif séquentiel sur une fenêtre de diagnostic de 1 Mio.
       Vérifie les largeurs d'accès ainsi que les motifs zéro, un, adresse et
       adresse inversée.
   * - ``a``
     - Test clairsemé des alias d'adresse/de banque sur toute la fenêtre de
       mémoire externe de 64 Mio visible par le logiciel.
   * - ``r``
     - Test pseudo-aléatoire de 1 Mio dans chacune de quatre régions mémoire
       distinctes.
   * - ``q``
     - Exécute la suite complète de qualification : séquentielle + clairsemée +
       pseudo-aléatoire.
   * - ``k``
     - Test d'allocation/de charge du tas. Le profil ULX4M-LD 64 Mio exerce la
       fenêtre de tas de 40 Mio.
   * - ``d``
     - Test rapide de la mémoire et du timer de la plate-forme Doom.
   * - ``x``
     - Copie du code RV32 en mémoire externe puis l'exécute, avec des phases GP
       normale et étrangère, des interruptions de timer et des contrôles de
       garde.
   * - ``z``
     - Réinitialise le tas ; tous les pointeurs de tas existants deviennent
       invalides.
   * - ``s``
     - Affiche l'état d'exécution, notamment l'état de préparation de la mémoire
       externe et l'initialisation/PLL/horloge utilisateur LiteDRAM.
   * - ``v``
     - Affiche les identifiants de version du firmware, du FPGA, du cœur mémoire
       et de l'adaptateur.

Un ``TIMEOUT`` au démarrage ne constitue pas, à lui seul, un échec DDR définitif.
Lors de la mise au point actuelle de l'ULX4M-LD, LiteDRAM a terminé après la
fenêtre d'attente initiale de 5 secondes du moniteur ; ``s`` a ensuite indiqué
que la mémoire était prête et la suite complète de qualification a réussi.

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
