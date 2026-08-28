Débogage JTAG
=============

Hazard3 comprend en amont un RISC-V Debug Module et un Debug Transport Module.
Sur ULX3S, l'adaptateur ECP5 de Hazard3 relie les registres DTM RISC-V au TAP
JTAG de la puce ECP5 via la primitive ``JTAGG``. Cela permet un débogage au
niveau du code source par la connexion USB/JTAG normale de la carte.

Pour une explication du chemin matériel, des commandes abstraites, de
l'injection d'instructions, de l'accès au bus système et des fonctions de
débogage sélectionnées dans ce bitstream, voir
:doc:`../architecture/hazard3/debug`.

OpenOCD
-------

Le projet conserve sa configuration OpenOCD sous ``openocd/`` et ses scripts
d'assistance sous ``scripts/``. Sous Windows, le chemin OpenOCD ULX3S ``ft232r``
actuel a été validé avec **WinUSB** et **libusbK** sur le FT231X embarqué.
WinUSB est l'association de pilote préférée pour le développement lorsque la
même machine utilise aussi le flasher FPGA WebUSB de Hazard3-Doom. L'association
FTDI VCP/D2XX par défaut est destinée aux outils natifs FTDI comme ``fujprog``
sous Windows et n'est pas le chemin libusb d'OpenOCD.

GDB se connecte à OpenOCD par TCP, normalement sur ``localhost:3333``. Il hérite
donc de la compatibilité USB du processus OpenOCD ; GDB lui-même n'ouvre pas le
FT231X. Voir :doc:`web-flasher` pour la matrice de compatibilité des pilotes.

Un workflow typique est :

#. Connecter l'ULX3S via son interface USB/JTAG normale.
#. Démarrer OpenOCD avec la configuration du projet.
#. Connecter un client GDB RISC-V à ``localhost:3333``.
#. Charger ``build/hazard3-boot-monitor.elf`` ou s'y attacher.

Chargement du moniteur en mode batch
------------------------------------

Avec OpenOCD déjà démarré et aucun autre client GDB connecté :

.. code-block:: bash

   ./scripts/load-firmware.sh

Ou fournissez explicitement un ELF :

.. code-block:: bash

   ./scripts/load-firmware.sh /path/to/hazard3-boot-monitor.elf

VisualGDB
---------

Les utilisateurs Windows peuvent utiliser les fichiers du projet sous
``VisualGDB/`` avec Visual Studio. Le débogueur communique toujours avec la même
cible OpenOCD/GDB ; le chemin en ligne de commande reste donc le workflow de
référence.

Le script d'assistance au démarrage GDB est :

.. code-block:: text

   scripts/hazard3-debug.gdb

Dépannage
---------

Si le module de débogage n'est pas détecté de manière fiable, réduisez la
fréquence JTAG avant de modifier le HDL. La qualité du signal USB/JTAG et le
timing de l'adaptateur peuvent provoquer des pannes qui ressemblent à des
problèmes de débogage du CPU.

Voir :doc:`../troubleshooting` pour les problèmes courants liés à OpenOCD et à la propriété des interfaces.
