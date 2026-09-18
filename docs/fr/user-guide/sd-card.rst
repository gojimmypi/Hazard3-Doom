Démarrage à froid depuis micro-SD
=================================

Le démarrage depuis SD permet à une ULX3S programmée de repartir après une coupure complète d'alimentation et de lancer Doom sans PC de développement connecté.

.. important::

   Le démarrage micro-SD n'est actuellement pris en charge que sur les cibles
   ULX3S. Sur ULX4M-LD, l'initialisation échoue à CMD0 et la commande de
   démarrage SD du moniteur est désactivée ; l'ULX4M ne dispose pas non plus de
   l'ESP32 présent sur l'ULX3S.

Contenu de la carte
-------------------

Placez ces fichiers dans le répertoire racine d'une carte micro-SD formatée en FAT :

.. code-block:: text

   DOOM.IMG
   DOOM.WAD

``DOOM.WAD`` est le nom de fichier IWAD canonique utilisé par le flux de démarrage à froid actuel.

Prise en charge du système de fichiers
--------------------------------------

Le moniteur prend en charge les fichiers du répertoire racine FAT16/FAT32 avec des noms 8.3. Les fichiers fragmentés sont pris en charge.

Séquence de démarrage à froid
-----------------------------

#. L'ECP5 charge sa configuration depuis la flash SPI embarquée.
#. La partie basse de l'EBR interne contient l'image d'initialisation du moniteur résident.
#. Hazard3 démarre à son point d'entrée reset/moniteur.
#. La SDRAM est initialisée.
#. Le moniteur initialise la carte SD et monte le système FAT.
#. ``DOOM.IMG`` est chargé en SDRAM et validé.
#. ``DOOM.WAD`` est localisé et chargé dans sa région réservée.
#. Le moniteur lance Doom.

Diagnostics du moniteur
-----------------------

Utilisez ``c`` pour afficher l'état SD/FAT et les compteurs actuels. Utilisez ``b`` pour relancer manuellement le chemin de démarrage SD.

Un rapport d'état sain contient notamment des informations comme :

.. code-block:: text

   sd_initialized=YES
   type=SDHC/SDXC
   fat_type=FAT32
   mounted=YES
   wad=DOOM.WAD

Broches SD partagées ESP32/FPGA
-------------------------------

Sur ULX3S, le connecteur micro-SD est également relié à des GPIO de l'ESP32. Lorsque Hazard3 possède la carte SD, le firmware ESP32 doit laisser les GPIO 14, 15, 2 et 13 en haute impédance afin de ne pas entrer en conflit avec l'interface SD du FPGA.

.. important::

   La propriété du bus SD est une question électrique, pas seulement un mutex logiciel. Les deux dispositifs ne doivent jamais piloter activement le bus partagé en même temps.

Voir :doc:`sao` pour le mécanisme distinct d'accès partagé FPGA/ESP32 utilisé pour le trafic SAO.
