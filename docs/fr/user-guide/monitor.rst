Moniteur résident
=================

Le moniteur résident est le firmware qui reste disponible même lorsque l'application Doom chargeable est remplacée ou se termine. Il fournit les commandes UART, les protocoles de chargement, les diagnostics et le chemin de récupération utilisé pendant le développement.

Commandes Doom principales
--------------------------

.. list-table::
   :header-rows: 1
   :widths: 15 85

   * - Commande
     - Fonction
   * - ``l``
     - Recevoir une image exécutable Doom empaquetée via UART.
   * - ``w``
     - Recevoir un IWAD dans la région SDRAM réservée.
   * - ``j``
     - Lancer l'image Doom et l'IWAD validés.
   * - ``b``
     - Tenter le flux de démarrage micro-SD.
   * - ``c``
     - Afficher l'état et les compteurs du démarrage SD/FAT.

Capacité de capture d'écran Web Serial
--------------------------------------

Le moniteur résident actuel participe au protocole de capture d'écran Web
Serial. Après avoir présenté avec succès la mire de test RGB332 du moniteur, il
en conserve une copie validée dans la SDRAM réservée. Une requête de capacité
``0x1c`` renvoie un ACK tant que ce cache est valide, et ``0x1d`` sérialise
l'image mise en cache.

Le téléversement d'une image ``.h3d`` avec ``l`` ne fait que stocker et valider
l'exécutable en SDRAM ; il **n'exécute pas** cette image et n'active pas le
gestionnaire de capture d'écran propre à Doom. Doom ne devient le fournisseur
d'écran actif qu'après que ``j`` a lancé l'image et que sa boucle UART/HDMI a
commencé à s'exécuter. De même, l'interface HDMI I2CDriver devient un fournisseur
actif pendant que ``i2c gui`` / ``sao gui`` possède l'UART. Voir
:doc:`web-serial`.

Diagnostics HDMI SAO / I2C
--------------------------

Le moniteur peut lancer l'interface interactive de diagnostic I2C HDMI avec :

.. code-block:: text

   i2c gui

ou ``sao gui``. Pendant que l'interface est active, les frappes UART contrôlent
l'interface HDMI. Quittez avec ``Q``, ``Ctrl-X`` ou Esc lorsqu'aucune invite
d'opérande n'est active. Voir :doc:`i2cdriver` pour la référence complète des
commandes.

Retour depuis Doom
------------------

Appuyez sur ``Ctrl-X`` pendant l'exécution de Doom pour revenir au moniteur. Cela est utile avant de téléverser un exécutable ou un WAD de remplacement.

Le dépôt contient également des scripts d'assistance pour revenir au moniteur ou redémarrer depuis celui-ci lorsqu'un terminal n'est pas pratique.

Build du moniteur
-----------------

La branche actuelle nomme toujours l'ELF du moniteur ``build/hazard3-boot-monitor.elf``. Fonctionnellement, cet ELF est le firmware du moniteur résident utilisé pour la mise au point initiale, le débogage, les chargeurs et les diagnostics.
