Vidéo, micro-SD et stockage d'exécution
=======================================

Vidéo GPDI
----------

ULX3S fournit une sortie GPDI. Hazard3-Doom l'utilise pour le pipeline vidéo à
framebuffer indexé. Le mode Doom principal est 320x200 en couleurs indexées,
avec conversion de palette par le matériel. La cible compacte 12F reste
intentionnellement sur ce chemin 320x200.

Voir :doc:`../../architecture/video` et :doc:`../../user-guide/web-serial`.

Stockage micro-SD
-----------------

La micro-SD est un stockage amovible non volatil. Le démarrage autonome ULX3S
peut y lire ``DOOM.H3D`` et ``DOOM.WAD``.

* la flash SPI stocke la configuration FPGA persistante ;
* l'EBR peut contenir le moniteur résident ;
* la SDRAM est la mémoire de travail volatile ;
* la micro-SD stocke les fichiers amovibles.

Partage SD avec l'ESP32
-----------------------

Les signaux micro-SD sont partagés entre FPGA et ESP32. Lorsque Hazard3 possède
le bus SD, les GPIO14, GPIO15, GPIO2 et GPIO13 de l'ESP32 doivent rester en
haute impédance.

.. important::

   La propriété du bus SD est une règle électrique, pas seulement un verrou
   logiciel. Deux pilotes actifs sur une même ligne peuvent provoquer des
   erreurs et une contention électrique.

Voir :doc:`../../user-guide/sd-card` et :doc:`../../user-guide/sao`.

La carte propose aussi audio et connecteur d'affichage ; ces ressources restent
utiles pour l'expérimentation mais ne sont pas requises par le chemin
vidéo/stockage Doom normal.
