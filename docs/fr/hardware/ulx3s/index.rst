Guide matériel ULX3S
====================

**Architecture, ressources de la carte, interfaces et utilisation par Hazard3-Doom.**

ULX3S est une carte FPGA open hardware basée sur un Lattice ECP5, conçue pour
l'enseignement, la recherche et les projets FPGA généraux. Elle associe le FPGA
à de la SDR SDRAM externe, une flash SPI de configuration, un emplacement
micro-SD, une sortie vidéo GPDI, USB/JTAG/UART, GPIO, boutons, LED, audio, ADC,
RTC et un chemin ESP32 optionnel/intégré.

Cette combinaison convient particulièrement bien à Hazard3-Doom : la carte peut
héberger le processeur, la mémoire de travail externe, la vidéo indexée, le
stockage amovible, un moniteur résident et plusieurs chemins indépendants de
programmation et de débogage.

.. important::

   La densité du FPGA et la révision du PCB sont deux identités différentes.
   Une carte peut utiliser un ECP5 12F, 25F, 45F ou 85F tout en appartenant à
   une révision PCB distincte, par exemple 3.0.x ou 3.1.x. Identifiez toujours
   les deux avant de vous fier à un schéma, un fichier de contraintes ou une
   cible de compilation.

Hazard3-Doom fournit actuellement des chemins de compilation complets pour
ULX3S 85F et pour la cible compacte ULX3S 12F. D'autres densités existent dans
la famille matérielle, sans que cela signifie que le SoC Doom complet soit
qualifié pour chacune d'elles.

.. toctree::
   :maxdepth: 2

   overview-and-variants
   fpga-and-clocking
   memory
   boot-and-flash
   video-and-storage
   interfaces
   pinout-and-revisions
   sources

Modèle mental utile
-------------------

.. code-block:: text

   +---------------------------------------------------------------+
   | Carte ULX3S                                                   |
   |                                                               |
   |  +-------------+       +------------------+                   |
   |  | Flash SPI   |<----->| Lattice ECP5     |<----> vidéo GPDI  |
   |  +-------------+       | FPGA             |<----> US1/JTAG    |
   |                        |                  |<----> GPIO J1/J2   |
   |  +-------------+       | SoC Hazard3      |<----> micro-SD    |
   |  | SDR SDRAM   |<----->| + contrôleurs    |<----> ESP32       |
   |  +-------------+       +------------------+                   |
   |                               |                               |
   |                      moniteur résident en EBR                 |
   +---------------------------------------------------------------+

Le guide sépare trois questions souvent confondues : le matériel réellement
présent sur ULX3S, ce que la révision PCB et la densité FPGA sélectionnées
routent effectivement, et ce que Hazard3-Doom implémente et a qualifié.
