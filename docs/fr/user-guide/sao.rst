Prise en charge SAO / I2C
=========================

Hazard3-Doom expose un connecteur SAO de style Hackaday via un pont I2C/GPIO contrôlé par APB. Le même bus SAO physique peut également être partagé avec l'ESP32 embarqué grâce à un protocole latéral de propriété.

Signaux du connecteur
---------------------

Les signaux SAO ULX3S documentés sont :

.. list-table::
   :header-rows: 1

   * - Signal
     - Broche ULX3S
   * - SDA
     - A9
   * - SCL
     - B10
   * - GPIO1
     - B9
   * - GPIO2
     - C10

Base APB Hazard3
----------------

Le pont SAO est mappé à :

.. code-block:: text

   0x40009000

Commandes du moniteur
---------------------

Le moniteur résident fournit notamment les commandes :

.. code-block:: text

   sao info
   sao gui
   sao recover
   sao scan
   sao probe
   sao read
   sao write
   i2c scan
   i2c gui

Interface HDMI I2CDriver
------------------------

Le moniteur résident fournit également un outil HDMI interactif de type I2CDriver :

.. code-block:: text

   i2c gui

L'interface graphique permet l'analyse, la détection, la lecture/écriture de
registres, la récupération du bus, la sélection 100/400 kHz, une carte thermique
des adresses, l'historique des transactions et une trace logique SDA/SCL. Voir
:doc:`i2cdriver` pour les commandes, les remarques de sécurité et la distinction
importante entre une trace logique initiée et une véritable capture passive du bus.

Partage avec l'ESP32
--------------------

Le FPGA et l'ESP32 utilisent la connexion latérale ULX3S Wi-Fi GPIO16/GPIO17 pour coordonner la propriété logique du bus SAO. L'exemple de firmware ESP32 se trouve sous :

.. code-block:: text

   examples/esp32-sao-shared/

Le propriétaire qui ne détient pas le bus doit relâcher ses sorties, et non simplement décider de ne pas transmettre.

Remarque électrique
-------------------

Les résistances de pull-up I2C établissent le niveau haut au repos mais ne remplacent aucune protection série exigée par un design SAO particulier. Vérifiez les exigences électriques de l'extension avant de connecter du matériel qui pilote activement les lignes GPIO optionnelles.
