Hazard3-Doom
============

**Doom sur le processeur RISC-V Hazard3 dans un FPGA ECP5 - et un terrain d'expérimentation pratique pour comprendre comment processeur, logique FPGA, mémoire, vidéo, firmware et logiciel s'assemblent.**

Hazard3-Doom est bien plus que Doom porté sur une carte FPGA supplémentaire.
C'est un écosystème matériel et logiciel pédagogique construit autour du
processeur RISC-V open source Hazard3 et des familles FPGA ECP5 ULX3S et ULX4M.

.. important:: État de la traduction

   La documentation anglaise est la référence pour les changements les plus
   récents de cette version. Les pages françaises suivent la même structure
   générale, mais certaines pages techniques - notamment JTAG, bootloader,
   WebUSB, sweeps de timing et ULX4M - peuvent être en retard sur l'anglais.
   Lorsqu'un détail de câblage, de commande ou de qualification matérielle est
   critique, vérifiez aussi la page anglaise correspondante.



.. admonition:: Le même CPU Hazard3 que dans le Raspberry Pi RP2350
   :class: important

   Hazard3 n'est pas un processeur créé uniquement pour ce projet. Le
   microcontrôleur RP2350 de Raspberry Pi contient une paire de cœurs RISC-V
   Hazard3 open hardware, sélectionnables à la place de sa paire de Cortex-M33,
   et le RP2350 équipe la famille Raspberry Pi Pico 2. Hazard3-Doom synthétise
   cette même architecture de processeur Hazard3 open source dans le FPGA ECP5.

   La configuration du processeur n'est pas identique : RP2350 et Hazard3-Doom
   activent des fonctionnalités et extensions ISA Hazard3 optionnelles
   différentes pour leurs SoC respectifs. Cette origine CPU et ce RTL communs
   font de Hazard3-Doom un moyen pratique d'étudier cette architecture dans un
   système que vous pouvez reconstruire et modifier.

   * `Raspberry Pi RP2350 <https://www.raspberrypi.com/products/rp2350/>`_
   * `Datasheet RP2350 - processeur Hazard3 <https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf>`_
   * `Raspberry Pi Pico 2 <https://www.raspberrypi.com/products/raspberry-pi-pico-2/>`_
   * `RTL Hazard3 amont <https://github.com/Wren6991/Hazard3>`_

Le projet réunit des exemples C et Verilog, des conceptions FPGA, la vidéo HDMI
et les framebuffers, des contrôleurs de mémoire externe, l'accès à la carte SD,
le débogage UART et JTAG, un moniteur de démarrage résident, des outils de
téléversement côté hôte et une application DoomGeneric chargeable.

Vous pouvez simplement jouer à Doom sur un CPU RISC-V soft, ou descendre plus
profondément dans le système pour voir comment un ordinateur complet basé sur
FPGA est construit : intégration du processeur, mémoire, horloges et timing,
vidéo, périphériques, démarrage, chargement et outils de débogage.

Que vous expérimentiez avec RISC-V, appreniez le Verilog ou vouliez comprendre
ce qu'il faut pour faire fonctionner Doom sur un matériel que vous pouvez
inspecter et modifier de bout en bout, Hazard3-Doom est conçu pour être exploré.

.. note::

   Ces pages décrivent la version de documentation sélectionnée. Les
   fonctionnalités encore en évolution sont signalées explicitement. Les pages
   détaillées sur l'architecture du processeur sont également rattachées à
   l'instantané exact du code source Hazard3 indiqué dans
   :doc:`architecture/hazard3/index`.

Commencer ici
-------------

* :doc:`about/index` - comprendre le projet et ce que vous pouvez y apprendre.
* :doc:`getting-started/no-install` - exécuter une ULX3S avec des images précompilées et le Device Tool, sans chaîne de build FPGA.
* :doc:`getting-started/quick-start` - installer les outils de développement et construire le FPGA, le moniteur résident et l'image Doom depuis les sources.
* :doc:`user-guide/web-tool` - utiliser l'outil Device Tool du navigateur pour les tâches courantes de mise en route et d'interaction.

Pour aller plus loin
--------------------

* :doc:`hardware/index` - explorer le matériel ULX3S et ULX4M utilisé par Hazard3-Doom.
* :doc:`user-guide/pinouts` - consulter les brochages et le câblage pratique UART/JTAG.
* :doc:`user-guide/jtag-debugging` - déboguer Hazard3 avec OpenOCD/GDB ou VisualGDB.
* :doc:`user-guide/i2cdriver` - scanner et utiliser le bus I2C SAO de manière interactive.
* :doc:`user-guide/web-flasher` - programmer directement le FPGA ULX3S avec WebUSB.
* :doc:`architecture/hazard3/index` - découvrir le processeur RISC-V Hazard3, son pipeline, sa configuration ISA, ses bus et son architecture de débogage.
* :doc:`architecture/system` - comprendre comment s'assemblent le FPGA, le moniteur, la mémoire, HDMI, la SD, le SAO et l'ESP32.
* :doc:`reference/apb-peripherals` - consulter les adresses, registres, bits et exemples C autonomes des peripheriques APB.
* :doc:`reference/timing-sweeps` - exécuter les sweeps ECP5 et interpréter les résultats de timing.
* :doc:`user-guide/sd-card` - configurer un démarrage autonome à froid depuis une carte micro-SD.
* :doc:`getting-started/tiny-tapeout-ulx3s` - construire des projets Tiny Tapeout pour le FPGA ECP5 ULX3S.

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
   :caption: Matériel

   hardware/index

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

* `Dépôt Hazard3-Doom <https://github.com/ulx3s/Hazard3-Doom>`_
* `Fork matériel Hazard3 pour ULX3S <https://github.com/ulx3s/Hazard3>`_
* `Projet Hazard3 amont <https://github.com/Wren6991/Hazard3>`_
* `Guide de conception et manuel de référence Hazard3 <https://wren.wtf/hazard3/doc/>`_
* `Source de la documentation Hazard3 <https://github.com/Wren6991/Hazard3/tree/stable/doc>`_
* `Projet DoomGeneric amont <https://github.com/ozkl/doomgeneric>`_
* `Sources matérielles ULX4M <https://github.com/intergalaktik/ulx4m>`_
* `Documentation matérielle ULX4M <https://github.com/intergalaktik/ulx4m-documentation>`_
* `Page ULX4M Crowd Supply <https://www.crowdsupply.com/intergalaktik/ulx4m>`_
