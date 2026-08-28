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

.. warning::

   Validez un bitstream avec un chargement temporaire avant de l'écrire de manière persistante. Une image persistante défectueuse peut être récupérée, mais les tests temporaires sont plus rapides et plus sûrs pendant le développement.

Voir :doc:`../user-guide/sd-card` pour le contenu de la carte SD et les diagnostics de démarrage.
