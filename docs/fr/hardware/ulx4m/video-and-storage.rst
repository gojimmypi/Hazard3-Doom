Vidéo et stockage amovible
============================

ULX4M expose des connexions d'affichage et de stockage, mais le connecteur
physique n'est que la première couche. Hazard3-Doom doit encore fournir la
logique FPGA, les contraintes, les horloges et le logiciel.

Vidéo GPDI / style HDMI
-----------------------

Hazard3-Doom conserve le framebuffer indexé natif de Doom. Le chemin standard
rend 320x200 pixels indexés et les met à l'échelle vers 1024x600. La conversion
de palette et le scanout sont réalisés dans le FPGA.

Les wrappers ULX4M utilisent une PLL vidéo dédiée avec 50 MHz pour les pixels et
250 MHz pour la sérialisation. Voir :doc:`../../architecture/video`.

Les sources publiques décrivent différentes variantes GPDI vraies/fausses
différentielles. Le wrapper et le LPF correspondant au build sont la source de
vérité pour la carte ciblée.

micro-SD
--------

La documentation ULX4M route la SD via l'environnement de broches compatible
CM4/HAT. Certaines configurations de carte porteuse peuvent partager ces
signaux avec un ESP32 externe; le module ULX4M lui-même ne doit pas être décrit
comme contenant un ESP32 embarqué.

Le top-level ULX4M-LD Hazard3-Doom expose actuellement :

.. code-block:: text

   sd_clk
   sd_mosi
   sd_miso
   sd_csn
   sd_pwr_on

``sd_pwr_on`` est activé pendant le fonctionnement du bitstream et le SoC active
son bloc SD SPI sur LD. L'état de validation matérielle reste documenté
séparément de la simple présence du câblage. Voir :doc:`../../user-guide/sd-card`.

Rôles de stockage
-----------------

* la flash SPI configure le FPGA;
* le moniteur résident vit dans l'EBR après configuration;
* SDRAM/DDR3 fournit la mémoire de travail volatile;
* micro-SD fournit les fichiers non volatils amovibles.

Un démarrage autonome traverse donc :

.. code-block:: text

   flash SPI -> configuration FPGA -> moniteur EBR -> init DRAM
             -> lecture micro-SD/FAT -> DOOM.IMG + DOOM.WAD -> Hazard3
