Processeur RISC-V Hazard3
=========================

Hazard3 est le processeur au centre de Hazard3-Doom. Il s'agit d'un CPU RISC-V
32 bits compact, in-order et à trois étages, conçu pour une utilisation sur
FPGA et ASIC. Le projet Hazard3 fournit également le matériel de débogage
environnant et l'intégration SoC d'exemple qui permettent de transformer le
cœur CPU en système utilisable.

Cette section explique le processeur d'un point de vue pédagogique et, tout
aussi important, sépare le **design Hazard3 standard** de l'**intégration
ULX3S/Hazard3-Doom** construite autour de lui.


Le lien avec le Raspberry Pi RP2350
-----------------------------------

Hazard3 est également l'une des architectures de processeur intégrées au
microcontrôleur RP2350 de Raspberry Pi. Le RP2350 contient deux cœurs RISC-V
Hazard3 open hardware ainsi que deux cœurs Arm Cortex-M33 ; le logiciel ou la
configuration OTP sélectionne la paire de processeurs utilisée. Le RP2350 est
le microcontrôleur utilisé par les Raspberry Pi Pico 2 et Pico 2 W.

Cela rend le processeur de Hazard3-Doom particulièrement intéressant pour
l'apprentissage : le projet FPGA utilise le même design de processeur Hazard3
open source qu'un microcontrôleur Raspberry Pi produit en série. Cela ne
signifie cependant pas que les deux CPU synthétisés ont une configuration
identique. Hazard3 est paramétrable, et le RP2350 active un ensemble différent
d'extensions ISA, d'extensions personnalisées, de fonctions de débogage et
d'intégration SoC par rapport à la configuration FPGA Hazard3-Doom décrite
ci-dessous.

Références primaires utiles :

* `Page produit Raspberry Pi RP2350 <https://www.raspberrypi.com/products/rp2350/>`_
* `Datasheet Raspberry Pi RP2350, section 3.8 processeur Hazard3 <https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf>`_
* `Page produit Raspberry Pi Pico 2 <https://www.raspberrypi.com/products/raspberry-pi-pico-2/>`_
* `Documentation microcontrôleurs Raspberry Pi - changement d'architecture <https://www.raspberrypi.com/documentation/microcontrollers/microcontroller-chips.html#architecture-switching>`_
* `Source Hazard3 amont et notes de configuration RP2350 <https://github.com/Wren6991/Hazard3>`_

Instantané source utilisé par ce projet
---------------------------------------

Les descriptions techniques de ces pages sont rattachées à l'instantané du
code source Hazard3 utilisé pour cette revue de documentation :

* Commit du fork Hazard3 ULX3S : |hazard3_commit|
* :hazard3-tree:`Parcourir la source épinglée </>`
* `Parcourir la branche stable Hazard3 amont actuelle <https://github.com/Wren6991/Hazard3/tree/stable>`_

.. important::

   Le SHA épinglé fait autorité pour le build FPGA décrit ici. Hazard3 amont
   continue d'évoluer. Une fonctionnalité présente dans les branches amont
   ``stable`` ou ``develop`` actuelles n'est pas automatiquement présente dans
   ce projet tant que le sous-module Hazard3 n'a pas été mis à jour
   délibérément.

Qu'est-ce que Hazard3 amont ?
-----------------------------

Le RTL du processeur sous ``hdl/`` correspond à l'architecture Hazard3 amont :
le cœur à trois étages, le front-end d'instructions, le décodeur, les unités
arithmétiques, les CSR, la logique d'interruption, les hooks du mode debug, le
fichier de registres, le support PMP, les triggers et les wrappers CPU à un ou
deux ports. Les mêmes familles de modules architecturaux sont présentes dans
Hazard3 amont actuel.

L'amont fournit également un SoC d'exemple minimal et une implémentation du
débogage RISC-V. L'exemple amont normal est volontairement petit : processeur,
débogage, RAM, UART et timer de plateforme suffisent pour démontrer et déboguer
le CPU.

Qu'est-ce qui est personnalisé pour Hazard3-Doom ?
--------------------------------------------------

Le fork ULX3S étend la couche du SoC d'exemple et d'intégration de carte plutôt
que de transformer Hazard3 en CPU spécifique à Doom. Les ajouts du projet
comprennent la SDRAM externe, l'accès vidéo, le SPI de carte SD, l'intégration
SAO/ESP32, la logique de broches et de propriété de la carte ainsi qu'une image
de moniteur résident préchargée.

Cette frontière est utile pour apprendre le design :

.. code-block:: text

   RISC-V software
         |
         v
   +-------------------------------+
   | Standard Hazard3 CPU          |
   | F -> X -> M pipeline          |
   | ISA, CSR, traps, debug hooks  |
   +-------------------------------+
         |
         | AHB5 master interface
         v
   +-------------------------------+
   | Example SoC / project fabric  |
   | RAM, APB, timer, UART         |  <- upstream foundation
   | SDRAM, video, SD, SAO, ESP32  |  <- ULX3S project additions
   +-------------------------------+
         |
         v
   ECP5 FPGA and board peripherals

Configuration réelle du processeur ULX3S
----------------------------------------

Le wrapper FPGA ULX3S épinglé sélectionne une configuration RV32I orientée
performances. Les principaux réglages effectifs sont :

.. list-table::
   :header-rows: 1
   :widths: 34 18 48

   * - Fonctionnalité
     - Réglage du projet
     - Signification pédagogique
   * - ISA de base
     - RV32I
     - ISA entière 32 bits avec 32 registres entiers.
   * - ``M``
     - Activé
     - Instructions matérielles de multiplication, division et reste.
   * - ``C``
     - Activé
     - Les instructions compressées 16 bits peuvent être mélangées aux instructions 32 bits.
   * - ``Zba`` / ``Zbb`` / ``Zbs``
     - Activé
     - Génération d'adresses, manipulation de bits de base et opérations sur bits individuels.
   * - ``Zifencei``
     - Activé
     - Synchronisation du fetch d'instructions avec ``fence.i``.
   * - ``A``
     - Désactivé
     - Les instructions mémoire atomiques ne font pas partie de ce CPU synthétisé.
   * - Compteurs machine
     - Activés
     - Les CSR de compteurs de cycles/retrait d'instructions sont implémentés.
   * - Support de débogage
     - Activé
     - Le CPU se connecte au RISC-V Debug Module de Hazard3.
   * - Mode utilisateur / PMP
     - Non activés
     - Ce projet est un système embarqué en mode machine, pas une cible d'OS protégé.
   * - Horloge CPU
     - 50 MHz nominal
     - Le wrapper transmet ``CLK_MHZ=50`` au SoC d'exemple.
   * - Prédicteur de branche
     - Activé
     - Le petit prédicteur de branche arrière de Hazard3 est synthétisé.

Le wrapper exact est :hazard3-src:`fpga_ulx3s.v <example_soc/fpga/fpga_ulx3s.v>`.
Les définitions génériques des paramètres se trouvent dans
:hazard3-src:`hazard3_config.vh <hdl/hazard3_config.vh>`.

Parcours d'apprentissage
------------------------

.. toctree::
   :maxdepth: 1

   overview
   pipeline
   isa-and-configuration
   memory-and-bus
   traps-and-interrupts
   debug
   project-integration
   source-tour
