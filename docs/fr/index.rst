Hazard3-Doom
============

**Doom fonctionnant sur le processeur RISC-V Hazard3 dans un FPGA ECP5, avec sortie vidéo HDMI, débogage UART/JTAG et prise en charge des cartes ULX3S/ULX4M.**

Hazard3-Doom combine un moniteur résident, une application DoomGeneric chargeable,
des builds FPGA pour les cartes, des outils de téléversement côté hôte et
l'intégration matériel/logiciel pour les familles ULX3S et ULX4M.

.. note::

   Ces pages suivent la branche ``develop`` active. Les fonctionnalités encore
   en évolution sont signalées explicitement. Les pages détaillées sur
   l'architecture du processeur sont également rattachées à l'instantané exact
   du code source Hazard3 indiqué dans :doc:`architecture/hazard3/index`.

Commencer ici
-------------

* :doc:`about/index` - comprendre le projet, ses usages pédagogiques et l'intérêt de l'ULX4M pour le prototypage modulaire.
* :doc:`getting-started/quick-start` - mettre une carte en fonctionnement avec un minimum d'étapes.
* :doc:`getting-started/build` - construire le FPGA, le moniteur résident et l'image Doom.
* :doc:`user-guide/web-flasher` - programmer la SRAM du FPGA ULX3S directement depuis Chrome/Edge avec WebUSB.
* :doc:`user-guide/sd-card` - configurer un démarrage autonome à froid depuis une carte micro-SD.
* :doc:`user-guide/i2cdriver` - analyser et inspecter le bus I2C SAO sur HDMI.
* :doc:`user-guide/jtag-debugging` - déboguer Hazard3 avec OpenOCD/GDB ou VisualGDB.
* :doc:`architecture/hazard3/index` - découvrir le processeur RISC-V Hazard3, son pipeline, sa configuration ISA, ses CSR, ses bus et son architecture de débogage.
* :doc:`architecture/system` - comprendre comment le FPGA, le moniteur, la SDRAM, HDMI, la SD, le SAO et l'ESP32 s'assemblent.

.. toctree::
   :maxdepth: 2
   :caption: Vue d'ensemble du projet

   about/index

.. toctree::
   :maxdepth: 2
   :caption: Prise en main

   getting-started/index

.. toctree::
   :maxdepth: 2
   :caption: Guide utilisateur

   user-guide/index

.. toctree::
   :maxdepth: 2
   :caption: Architecture

   architecture/index

.. toctree::
   :maxdepth: 2
   :caption: Référence

   reference/index
   faq
   troubleshooting
   contributing

Liens du projet
---------------

* `Dépôt Hazard3-Doom <https://github.com/gojimmypi/Hazard3-Doom>`_
* `Fork matériel Hazard3 pour ULX3S <https://github.com/ulx3s/Hazard3>`_
* `Projet Hazard3 amont <https://github.com/Wren6991/Hazard3>`_
* `Projet DoomGeneric amont <https://github.com/ozkl/doomgeneric>`_
