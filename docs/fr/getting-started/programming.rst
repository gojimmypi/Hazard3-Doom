Programmation et démarrage persistant
=====================================

Il existe deux objectifs de programmation différents :

Chargement FPGA temporaire
--------------------------

Une commande normale de programmation FPGA volatile est idéale pour tester un nouveau bitstream. Elle configure immédiatement l'ECP5 mais la configuration est perdue lorsque l'alimentation est coupée.

Pour ULX3S, le :doc:`../user-guide/web-flasher` dans le navigateur peut effectuer
ce chargement temporaire directement depuis un fichier ``.bit`` ou ``.svf``
compatible via ``US1``. Le navigateur sonde l'identifiant JTAG physique de
l'ECP5, vérifie qu'un fichier ``.bit`` cible la même variante de FPGA, exécute
la séquence de programmation SRAM Project Trellis et démarre immédiatement la
nouvelle image.

Le flasher WebUSB ne modifie pas la flash SPI persistante. Sous Windows, son
accès direct au FT231X nécessite le pilote WinUSB. Cette même association
WinUSB a également été validée avec le chemin OpenOCD/GDB ULX3S du projet ; un
workflow de débogage n'impose donc pas intrinsèquement un passage à libusbK.
Consultez la matrice de compatibilité des pilotes dans le guide du flasher avant
de modifier l'association USB.

Configuration FPGA persistante
------------------------------

Pour une installation autonome, écrivez le bitstream FPGA validé dans la flash SPI de configuration de l'ULX3S. À la prochaine mise sous tension, l'ECP5 se configurera depuis la flash.

La séquence autonome prévue est :

#. L'ECP5 se configure depuis la flash SPI.
#. La Block RAM est initialisée avec l'image du moniteur résident Hazard3.
#. Hazard3 démarre sans PC hôte.
#. Le moniteur initialise la SDRAM et l'interface micro-SD.
#. ``DOOM.H3D`` et ``DOOM.WAD`` sont lus depuis la carte SD.
#. Doom est lancé sur HDMI.

ULX4M-LD : chargement FPGA temporaire
-------------------------------------

Avec Tigard connecté au JTAG de l'ULX4M-LD, ``openFPGALoader`` peut charger une
nouvelle configuration ECP5 directement en SRAM sans remplacer l'image
utilisateur persistante :

.. code-block:: bash

   ./bin/openFPGALoader.exe \
       -c tigard \
       ./build/fpga_ulx4m_ld.bit

Ce chargement est volatile. Une coupure d'alimentation ou une reconfiguration du
FPGA le supprime ; il convient donc aux essais d'un bitstream avant son écriture
persistante.

ULX4M-LD : programmation DFU persistante
----------------------------------------

Le bootloader DFU Micro-B de l'ULX4M-LD écrit le bitstream utilisateur persistant
dans la flash SPI. Cette image est conservée après une coupure d'alimentation et
est distincte du bootloader DFU lui-même.

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

Après l'écriture, si la carte reste en mode DFU, demandez au bootloader de lancer
l'image déjà stockée :

.. code-block:: bash

   ./bin/dfu-util.exe -a 0 -e

Cette commande ``-e`` ne télécharge ni n'efface les données FPGA. Voir
:doc:`../user-guide/bootloader` pour le bootloader et la récupération, et
:doc:`../user-guide/jtag-debugging` pour le débogage via Tigard.

.. warning::

   Validez un bitstream avec un chargement temporaire avant de l'écrire de manière persistante. Une image persistante défectueuse peut être récupérée, mais les tests temporaires sont plus rapides et plus sûrs pendant le développement.

Voir :doc:`../user-guide/sd-card` pour le contenu de la carte SD et les diagnostics de démarrage.
