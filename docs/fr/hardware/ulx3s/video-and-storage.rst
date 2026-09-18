Vidéo, micro-SD et stockage d'exécution
=======================================

Vidéo GPDI
----------

ULX3S fournit une sortie GPDI. Hazard3-Doom l'utilise pour le pipeline vidéo à
framebuffer indexé. Le mode Doom principal est 320x200 en couleurs indexées,
avec conversion de palette par le matériel. La cible compacte 12F reste
intentionnellement sur ce chemin 320x200.

Voir :doc:`../../architecture/video` et :doc:`../../user-guide/web-serial`.

Écrans HDMI et exemple de boîtier
----------------------------------

La sortie GPDI peut piloter un écran HDMI avec la connexion GPDI-vers-HDMI
appropriée. Le chemin vidéo Hazard3-Doom n'est pas lié à un moniteur précis :
l'écran Elecrow de sept pouces est un exemple matériel pratique, mais d'autres
écrans HDMI peuvent également être utilisés.

Un boîtier imprimable en 3D est disponible pour construire un système de
démonstration ULX3S compact autour de l'écran HDMI IPS Elecrow 7 pouces
1024x600. Il regroupe l'ULX3S et l'écran tout en conservant l'accès aux
commandes de la carte, aux LED d'état, aux connecteurs GPIO/JTAG, aux commandes
de l'écran et au routage des câbles. Des options sont prévues pour un support,
des pieds de développement, un cadre OLED et un petit ventilateur interne.

Le boîtier est mécaniquement conçu pour ce panneau Elecrow ; il n'est pas requis
par Hazard3-Doom et ne limite pas la sortie vidéo FPGA à cet écran. Pour les
fichiers de conception, les notes d'impression, l'assemblage et les remarques
de compatibilité, voir :

* `ULX3S Elecrow 7 inch HDMI Display Enclosure
  <https://github.com/gojimmypi/ulx3s-elecrow-7inch-hdmi-enclosure>`_
* `Crowd Supply: New Enclosure & Upcoming Campaign News
  <https://www.crowdsupply.com/radiona/ulx3s/updates/new-enclosure-and-upcoming-campaign-news>`_

.. warning::

   La documentation du boîtier contient des précautions propres au câblage.
   N'utilisez notamment pas l'entrée HDMI externe du boîtier en même temps que
   le chemin vidéo ULX3S connecté en interne, et ne branchez pas simultanément
   les entrées USB tactile et USB d'alimentation de l'écran. Consultez le dépôt
   du boîtier avant l'assemblage.

Stockage micro-SD
-----------------

La micro-SD est un stockage amovible non volatil. Le démarrage autonome ULX3S
peut y lire ``DOOM.IMG`` et ``DOOM.WAD``.

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
