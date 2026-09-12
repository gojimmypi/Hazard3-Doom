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

Pour ULX3S, le lanceur recommandé est :

.. code-block:: bash

   ./scripts/start-openocd.sh

Le lanceur est volontairement utilisable depuis WSL comme depuis Linux natif.
Sous Linux natif, il résout ``openocd`` depuis ``PATH``. Sous WSL, il peut
utiliser le ``openocd.exe`` Windows fourni pour un checkout situé sur un disque
Windows lorsque l'interopérabilité WSL est disponible ; sinon il utilise
OpenOCD Linux natif. Cela maintient les chemins du dépôt et le format de
l'exécutable cohérents avec l'environnement hôte.

Les configurations ULX3S du projet sont écrites pour fonctionner avec la
version Ubuntu OpenOCD ``0.12.0`` ainsi qu'avec les builds OpenOCD plus récents
actuellement utilisés par le projet. En particulier, l'orthographe de
compatibilité ``gdb_report_data_abort`` est acceptée par 0.12.0 ; les builds
plus récents peuvent afficher un avertissement de dépréciation tout en
continuant de l'accepter. Ne remplacez pas l'installation OpenOCD de la
distribution uniquement pour supprimer cet avertissement.

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

Un démarrage OpenOCD sain sur ULX3S 85F contient une sortie similaire à :

.. code-block:: text

   JTAG tap: lfe5u85.hazard3 tap/device found: 0x41113043
   Examined RISC-V core; found 1 harts
   hart 0: XLEN=32
   Listening on port 3333 for gdb connections

Dans une VM, une transaction USB initiale peut parfois signaler
``LIBUSB_ERROR_TIMEOUT`` ou une interrogation JTAG entièrement nulle. Jugez
l'état final, pas seulement le premier avertissement : si OpenOCD examine ensuite
le cœur RISC-V et ouvre le port 3333, le serveur de débogage est utilisable. Un
redémarrage immédiat et propre est une confirmation utile. Si le TAP/cœur n'est
jamais trouvé, vérifiez que le FT231X est attaché à l'invité, que le flasher FPGA
du navigateur est déconnecté et qu'aucun autre processus ne possède l'interface
JTAG.

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
