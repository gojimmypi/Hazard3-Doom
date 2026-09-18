Débogage JTAG
=============

Hazard3 comprend un RISC-V Debug Module et un Debug Transport Module. Sur les
cartes ECP5, Hazard3 expose le DTM RISC-V via le TAP JTAG de la puce ECP5 et la
primitive ``JTAGG``. OpenOCD voit donc d'abord le TAP ECP5 physique, puis utilise
les instructions privées ER1/ER2 de l'ECP5 pour atteindre DTMCS et DMI de
Hazard3.

Pour une explication du chemin matériel, des commandes abstraites, de
l'injection d'instructions, de l'accès au bus système et des fonctions de
débogage sélectionnées dans ce bitstream, voir
:doc:`../architecture/hazard3/debug`.

OpenOCD et GDB
--------------

GDB se connecte à OpenOCD par TCP, normalement sur ``localhost:3333``. GDB
n'ouvre pas directement l'adaptateur USB JTAG. Le pilote USB et la configuration
de l'adaptateur relèvent donc d'OpenOCD, tandis que
``scripts/load-firmware.sh`` n'utilise GDB qu'après qu'OpenOCD a correctement
examiné la cible.

Pour ULX3S, le lanceur recommandé est :

.. code-block:: bash

   ./scripts/start-openocd.sh

Le lanceur est volontairement utilisable depuis WSL comme depuis Linux natif.
Sous Linux natif, il résout ``openocd`` depuis ``PATH``. Sous WSL, il peut
utiliser le ``openocd.exe`` Windows fourni pour un checkout monté depuis
Windows lorsque l'interopérabilité WSL est disponible ; sinon, il utilise
OpenOCD Linux natif. Cela maintient les chemins du dépôt et le format de
l'exécutable cohérents avec l'environnement hôte.

Les configurations ULX3S du projet sont prévues pour fonctionner avec OpenOCD
Ubuntu ``0.12.0`` ainsi qu'avec les builds OpenOCD plus récents actuellement
utilisés par le projet. En particulier, l'orthographe de compatibilité
``gdb_report_data_abort`` est acceptée par 0.12.0 ; les builds plus récents
peuvent afficher un avertissement de dépréciation tout en continuant de
l'accepter. Ne remplacez pas une installation OpenOCD de la distribution
uniquement pour supprimer cet avertissement.

Avec OpenOCD déjà lancé et aucun autre client GDB connecté :

.. code-block:: bash

   ./scripts/load-firmware.sh

Ou fournissez explicitement un ELF :

.. code-block:: bash

   ./scripts/load-firmware.sh /path/to/hazard3-boot-monitor.elf

La forme sans argument désigne la sortie du build autonome
``scripts/build.sh``. Pour un build complet de carte, préférez le fichier de
commandes GDB propre à la cible afin de ne pas confondre le moniteur avec un ELF
construit pour une autre horloge ou un autre profil mémoire :

.. code-block:: bash

   # ULX3S 85F
   riscv-none-elf-gdb -batch -x scripts/gdb/load-ulx3s-85f-monitor.gdb

   # ULX3S 12F
   riscv-none-elf-gdb -batch -x scripts/gdb/load-ulx3s-12f-monitor.gdb

   # ULX4M-LD 85F
   riscv-none-elf-gdb -batch -x scripts/gdb/load-ulx4m-ld-85f-monitor.gdb

Chaque fichier sélectionne le moniteur sous le répertoire
``build/<board>/monitor/`` correspondant, arrête la cible, charge et vérifie
l'ELF avec ``compare-sections``, règle ``$pc`` sur ``_start``, relance le
processeur puis se déconnecte. N'utilisez pas un ELF générique ou ancien provenant
d'un autre build de carte : il peut s'exécuter tout en utilisant un diviseur UART,
une carte mémoire ou un protocole de chargement incorrect.

Lorsqu'un exécutable Windows ``.exe`` fourni est lancé depuis WSL, le shell reste
Bash. Utilisez des chemins comme ``./bin/gdb/riscv-none-elf-gdb.exe`` et une
barre oblique inverse finale (``\``) pour continuer une commande Bash. La
syntaxe ``cmd.exe`` comme ``.\bin\...`` et la continuation ``^`` n'est valide
qu'après être entré explicitement dans ``cmd.exe`` ; collée directement dans WSL,
elle est interprétée comme des commandes Bash séparées ou altérées.

FT231X intégré à l'ULX3S
------------------------

Sur ULX3S, le projet utilise la connexion USB/JTAG FT231X normale de la carte.
Le chemin OpenOCD ``ft232r`` actuel a été vérifié sous Windows avec **WinUSB**
et **libusbK**. WinUSB est pratique lorsque le même FT231X sert aussi au flasher
FPGA WebUSB de Hazard3-Doom. L'association FTDI VCP/D2XX par défaut est destinée
aux outils FTDI natifs tels que ``fujprog`` sous Windows et n'est pas le chemin
libusb d'OpenOCD.

Voir :doc:`web-flasher` pour la matrice de compatibilité des pilotes ULX3S.

Un démarrage OpenOCD sain sur ULX3S 85F contient une sortie similaire à :

.. code-block:: text

   JTAG tap: lfe5u85.hazard3 tap/device found: 0x41113043
   Examined RISC-V core; found 1 harts
   hart 0: XLEN=32
   Listening on port 3333 for gdb connections

Dans une VM, une transaction USB initiale peut parfois signaler
``LIBUSB_ERROR_TIMEOUT`` ou une interrogation JTAG entièrement nulle. Jugez
l'état final et pas seulement le premier avertissement : si OpenOCD examine
ensuite le cœur RISC-V et ouvre le port 3333, le serveur de débogage est
utilisable. Un redémarrage immédiat et propre est une bonne confirmation. Si le
TAP/cœur n'est jamais trouvé, vérifiez que le FT231X est attaché à l'invité, que
le flasher FPGA du navigateur est déconnecté et qu'aucun autre processus ne
possède l'interface JTAG.

ULX3S avec Tigard externe
-------------------------

Tigard peut être utilisé à la place du FT231X intégré. C'est particulièrement
utile pour comparer des adaptateurs de débogage, éviter de modifier le pilote du
FT231X ou utiliser le chemin JTAG MPSSE plus rapide du FT2232H. Le câblage suit
les brochages JTAG Tigard et ULX3S publiés ; qualifiez ce chemin d'adaptateur
externe sur la carte cible avant de le considérer comme une configuration
validée par le projet.

J4 est le connecteur JTAG externe physique, pas un contrôleur JTAG distinct. Ses
signaux ``TCK``, ``TMS``, ``TDI`` et ``TDO`` sont reliés au TAP JTAG matériel de
la puce ECP5. Ce sont des broches JTAG dédiées, et non des GPIO utilisateur
ordinaires ; le chemin de débogage Hazard3 ECP5 ne les route donc pas via des
contraintes LPF ``LOCATE`` normales. Le LPF de référence ULX3S laisse également
ces sites dédiés commentés comme GPIO utilisateur.

Lorsque Hazard3 est configuré pour le transport de débogage ECP5, le chemin est
le suivant :

.. code-block:: text

   Tigard / FT2232H
          |
          v
      ULX3S J4
          |
          v
   ECP5 hard JTAG TAP
          |
          v
       JTAGG
          |
          v
   Hazard3 ECP5 JTAG DTM
          |
          v
   RISC-V Debug Module
          |
          v
      Hazard3 CPU

``JTAGG`` est la connexion du fabric FPGA au TAP ECP5 existant ; Hazard3 ne crée
pas un second TAP externe. Hazard3 mappe les registres de données RISC-V
``DTMCS`` et ``DMI`` sur les hooks de registres utilisateur ``ER1`` et ``ER2`` de
l'ECP5, sélectionnés par les instructions ``0x32`` et ``0x38``. Les fonctions TAP
standard telles que IDCODE et BYPASS restent fournies par le TAP ECP5. C'est
également pourquoi OpenOCD identifie d'abord l'ECP5, puis utilise les
instructions privées pour atteindre le débogueur RISC-V.

Cela diffère du mode générique ``DTM_TYPE="JTAG"`` de Hazard3, dans lequel un
DTM JTAG RISC-V normal est connecté à quatre ports d'E/S utilisateur. Pour
ULX3S, le mode ECP5 instancie ``hazard3_ecp5_jtag_dtm`` et ``JTAGG`` en interne ;
J4 se connecte donc au TAP ECP5 et non directement à des broches JTAG RISC-V.

Reliez directement le connecteur JTAG de Tigard au J4 de l'ULX3S :

.. code-block:: text

   Tigard GND (pin 2, black)    -> ULX3S J4 GND
   Tigard TCK (pin 3, white)    -> ULX3S J4 TCK
   Tigard TDI (pin 4, grey)     -> ULX3S J4 TDI
   Tigard TDO (pin 5, purple)   <- ULX3S J4 TDO
   Tigard TMS (pin 6, blue)     -> ULX3S J4 TMS
   Tigard VTGT                  -> not connected
   Tigard TRST / SRST           -> not connected

.. _fig-ulx3s-jtag-pinout:

.. figure:: ../images/ulx3s-jtag-pinout.png
   :alt: Brochage ULX3S mettant en évidence les broches JTAG dédiées TCK, TDI, TDO et TMS de J4.
   :width: 85%

   **JTAG externe ULX3S** -- ``J4`` est le connecteur physique du TAP JTAG
   matériel ECP5. Utilisez ses broches dédiées TCK, TDI, TDO et TMS pour la
   connexion Tigard ; ce ne sont pas des GPIO FPGA ordinaires.

Réglez Tigard en mode ``SPI/JTAG`` et logique 3,3 V. Alimentez normalement
l'ULX3S par US1. Voir :doc:`pinouts` pour la disposition physique de J4 et les
précautions de câblage.

La partie adaptateur Tigard d'une configuration OpenOCD est :

.. code-block:: text

   adapter driver ftdi
   transport select jtag
   ftdi vid_pid 0x0403 0x6010
   ftdi channel 1
   ftdi layout_init 0x0038 0x003b
   ftdi layout_signal nTRST -data 0x0010
   ftdi layout_signal nSRST -data 0x0020
   adapter speed 1000

La partie cible Hazard3 est la même que dans
``openocd/ulx3s-openocd.cfg`` : le TAP ECP5 possède un registre d'instruction de
8 bits, et DTMCS/DMI de Hazard3 sont atteints par les instructions privées ECP5
``0x32`` et ``0x38``. Pour une ULX3S 85F, l'IDCODE ECP5 est ``0x41113043``. Une
carte 12F utilise ``0x21111043`` à la place.

Une fois qu'OpenOCD a signalé le TAP ECP5, examiné un hart RISC-V 32 bits et
ouvert le port 3333, connectez le GDB RISC-V du projet à l'ELF. Avec
l'exécutable GDB exact fourni par la toolchain RISC-V installée, le flux
interactif est, conceptuellement :

.. code-block:: text

   $ riscv-none-elf-gdb path/to/hazard3-boot-monitor.elf
   (gdb) target extended-remote localhost:3333
   (gdb) monitor halt
   (gdb) break main
   (gdb) continue
   (gdb) next
   (gdb) stepi
   (gdb) info registers
   (gdb) continue

``next`` et ``step`` opèrent au niveau source lorsque les informations de
débogage sont disponibles ; ``nexti`` et ``stepi`` opèrent instruction machine
par instruction machine. Il s'agit d'un véritable débogage pas à pas du cœur
RISC-V Hazard3 exécuté dans le FPGA. Tigard externe entre toujours par le TAP
JTAG ECP5 ; il ne se connecte pas directement à des broches RISC-V.

Débogage de l'ESP32 ULX3S intégré avec Tigard
---------------------------------------------

L'ESP32 intégré est une cible JTAG totalement distincte de Hazard3. C'est un
ESP32 Xtensa double cœur classique ; utilisez donc la prise en charge OpenOCD
ESP32 d'Espressif et un GDB Xtensa, et non le GDB RISC-V utilisé pour Hazard3.
Cette connexion est déduite du schéma/LPF ULX3S et des broches JTAG documentées
par Espressif ; elle n'a pas encore été qualifiée par le projet sur ULX3S.

Le JTAG natif de l'ESP32 utilise :

.. code-block:: text

   TDI -> GPIO12 / MTDI
   TCK -> GPIO13 / MTCK
   TMS -> GPIO14 / MTMS
   TDO <- GPIO15 / MTDO

Sur ULX3S, ces quatre signaux ESP32 sont partagés avec l'interface microSD. La
connexion Tigard pratique les atteint donc via les signaux SD :

.. code-block:: text

   Tigard TDI (pin 4, grey)    -> SD DAT2 -> ESP32 GPIO12
   Tigard TCK (pin 3, white)   -> SD DAT3 -> ESP32 GPIO13
   Tigard TMS (pin 6, blue)    -> SD CLK  -> ESP32 GPIO14
   Tigard TDO (pin 5, purple)  <- SD CMD  <- ESP32 GPIO15
   Tigard GND (pin 2, black)   -> board GND

Les contacts microSD correspondants sont DAT2 broche 1, DAT3 broche 2, CMD
broche 3, CLK broche 5 et VSS/GND broche 6. Un breakout ou une rallonge est bien
plus simple et plus sûr que de sonder directement les contacts du connecteur.
Retirez la carte SD.

.. warning::

   L'ECP5 est connecté aux mêmes signaux SD. Ne déboguez pas l'ESP32 sur ces
   fils tant que le FPGA peut piloter le bus SD. Utilisez ou vérifiez une image
   FPGA qui laisse ``SD_D2``, ``SD_D3``, ``SD_CLK`` et ``SD_CMD`` en haute
   impédance. Le design Hazard3-Doom normal utilise la SD ; cette isolation doit
   donc être réalisée délibérément avant de connecter Tigard.

Maintenir l'ESP32 en reset avec J3
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Si des problèmes de carte SD sont rencontrés côté FPGA, le cavalier ``J3`` de
l'ULX3S peut maintenir l'ESP32 en reset. ``J3`` est un connecteur à 2 broches
qui met le signal ``EN`` de l'ESP32 à la masse lorsqu'il est court-circuité.
Cela désactive l'ESP32 et peut aider à l'isoler du bus SD partagé pendant le
diagnostic ou lorsque le FPGA doit avoir la propriété exclusive de la carte SD.

.. _fig-ulx3s-j3-wifi-off:

.. figure:: ../images/ulx3s-j3-schematic-zoom.png
   :alt: Détail du schéma du cavalier J3 ULX3S montrant EN de l'ESP32 tiré à l'état bas
   :align: center

   **Cavalier ULX3S J3 (WIFI_OFF)** -- court-circuiter ``J3`` tire le signal
   ``EN`` de l'ESP32 à l'état bas et maintient l'ESP32 en reset/désactivé.

Le ``SRST`` de Tigard peut, en option, être connecté au côté ``WIFI_OFF``/EN du
cavalier J3 de l'ULX3S pour un reset matériel. ``EN`` de l'ESP32 est un signal
d'activation actif à l'état haut ; le tirer à l'état bas réinitialise/désactive
la puce. Ne connectez pas le fil de reset au côté masse de J3, et ne connectez
pas ``VTGT`` de Tigard lorsque l'ULX3S est auto-alimentée.

Avec OpenOCD Espressif installé, la configuration est équivalente à :

.. code-block:: bash

   openocd \
       -f interface/ftdi/tigard.cfg \
       -c "set ESP32_FLASH_VOLTAGE 3.3" \
       -f target/esp32.cfg

Utilisez ensuite l'ELF produit par le build ESP32 :

.. code-block:: text

   $ xtensa-esp32-elf-gdb path/to/esp32-app.elf
   (gdb) target remote localhost:3333
   (gdb) monitor halt
   (gdb) break app_main
   (gdb) continue
   (gdb) next
   (gdb) stepi

Le réglage ``ESP32_FLASH_VOLTAGE`` est important car GPIO12/TDI est également
une entrée de strap de démarrage de l'ESP32. La configuration OpenOCD
d'Espressif utilise ce réglage de tension flash pour maintenir l'état inactif
de JTAG TDI adapté à une mémoire flash 3,3 V.

ULX4M-LD avec Tigard
--------------------

La connexion DFU Micro-B de l'ULX4M est le chemin de configuration/bootloader
du FPGA. Ce n'est **pas** l'adaptateur de débogage JTAG de Hazard3. Pour le
débogage ULX4M-LD, utilisez un Tigard FT2232H externe.

Configuration Tigard connue comme fonctionnelle
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Utilisez ces réglages :

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Élément
     - Réglage
   * - Sélecteur de mode Tigard
     - ``JTAG``
   * - Alimentation cible Tigard
     - ``OFF`` ; ne pas alimenter l'ULX4M depuis Tigard
   * - Tension de référence cible
     - 3,3 V
   * - USB VID:PID
     - ``0403:6010``
   * - Canal FTDI OpenOCD
     - ``1`` (canal B FT2232H / USB Interface 1)
   * - Horloge JTAG
     - 1000 kHz
   * - Composant ECP5
     - LFE5UM-85F
   * - IDCODE ECP5
     - ``0x01113043``
   * - Instructions Hazard3 DTMCS/DMI
     - ``0x32`` / ``0x38``

L'IDCODE correct du LFE5UM-85F est ``0x01113043``. N'utilisez pas la valeur
``0x41113043`` associée à une autre variante de composant ECP5.

Séparation des pilotes Windows
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Tigard expose deux interfaces USB FT2232H indépendantes. Configurez-les une
fois et laissez-les ainsi :

.. list-table::
   :header-rows: 1
   :widths: 25 25 25 25

   * - Interface USB
     - Canal FT2232H
     - Pilote Windows
     - Utilisation dans le projet
   * - Interface 0
     - A
     - FTDI VCP
     - Port COM UART
   * - Interface 1
     - B
     - libusbK
     - JTAG OpenOCD

Cela permet d'utiliser PuTTY/Web Serial sur l'UART et OpenOCD JTAG en même
temps ; il n'y a aucune raison de continuer à changer de pilote entre les deux.
Si libusbK est installé par erreur sur Interface 0, le port COM UART disparaît.
Restaurez Interface 0 sur le pilote FTDI USB Serial/VCP et laissez Interface 1
sur libusbK.

.. _fig-zadig-tigard-libusbk:

.. figure:: ../images/Zadig-Tigard-set-interface-1-libusbk.png
   :alt: Zadig sélectionnant libusbK pour Tigard Interface 1
   :class: screenshot

   Appliquez libusbK à Tigard Interface 1 pour JTAG. Gardez Interface 0 sur le
   pilote FTDI VCP pour le port COM UART.

UART ULX4M-LD via Tigard
~~~~~~~~~~~~~~~~~~~~~~~~

L'interface UART de Tigard est indépendante de son canal JTAG. Utilisez
115200 8N1, sans contrôle de flux. Sur le connecteur 40 broches de style
Raspberry Pi du carrier Waveshare, le câblage confirmé est :

.. code-block:: text

   Tigard UART TX (yellow)  -> physical pin 16 -> GPIO23 -> FPGA N4 -> uart_rx
   Tigard UART RX (orange)  <- physical pin 18 -> GPIO24 <- FPGA N3 <- uart_tx
   Tigard GND               -> physical pin 20
   Tigard VCC               -> not connected

TX et RX doivent être croisés exactement comme indiqué. Voir :doc:`pinouts`
pour le brochage annoté du carrier ULX4M-LD.

Configuration OpenOCD ULX4M-LD
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

La configuration du projet est :

.. code-block:: bash

   ./bin/openocd.exe -d2 \
       -f ./third_party/Hazard3/example_soc/ulx4m-openocd-tigard.cfg

Les valeurs importantes de la configuration sont équivalentes à :

.. code-block:: text

   adapter driver ftdi
   ftdi vid_pid 0x0403 0x6010
   ftdi channel 1
   ftdi layout_init 0x0038 0x003b
   ftdi layout_signal nTRST -data 0x0010
   ftdi layout_signal nSRST -data 0x0020

   transport select jtag
   adapter speed 1000

   set _CHIPNAME lfe5um85
   jtag newtap $_CHIPNAME hazard3 \
       -expected-id 0x01113043 \
       -irlen 8 \
       -irmask 0xFF \
       -ircapture 0x5

   set _TARGETNAME $_CHIPNAME.hazard3
   target create $_TARGETNAME riscv -chain-position $_TARGETNAME
   riscv set_ir dtmcs 0x32
   riscv set_ir dmi 0x38

   gdb_report_data_abort enable
   init
   halt

Le câblage Tigard établi ne connecte **pas** de fil de reset cible. Ne comptez
pas sur SRST/TRST pour réinitialiser ou démarrer le design ULX4M ; les entrées
de layout FTDI restent dans la configuration de l'adaptateur, mais le reset
n'est pas physiquement câblé à la cible dans cette configuration.

Une session saine atteint une sortie similaire à :

.. code-block:: text

   JTAG tap: lfe5um85.hazard3 tap/device found: 0x01113043
   Examined RISC-V core; found 1 hart
   XLEN=32
   Listening on port 3333 for gdb connections

La valeur Hazard3 DTMCS connue comme correcte est ``0x00004071``.

Interpréter ``dtmcontrol is 0``
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le TAP JTAG matériel de l'ECP5 peut renvoyer l'IDCODE de la puce même lorsque le
bitstream utilisateur Hazard3 ne s'exécute pas. Cette combinaison est donc
utile pour le diagnostic :

.. code-block:: text

   JTAG IDCODE = 0x01113043
   dtmcontrol = 0

Elle prouve que le chemin JTAG physique Tigard-vers-ECP5 fonctionne, mais ne
prouve **pas** que la logique utilisateur Hazard3 ``JTAGG``/DTM est active.
Avant de modifier le RTL DTM ou le câblage JTAG, confirmez que le bitstream
utilisateur ULX4M a réellement démarré. Si la carte est encore dans son
bootloader DFU, exécutez :

.. code-block:: bash

   ./bin/dfu-util.exe -a 0 -e

Puis réessayez OpenOCD. Dans la séquence de mise en route validée, quitter DFU
de cette façon a démarré le design utilisateur, restauré l'UART Hazard3 et rendu
la logique FPGA utilisateur disponible pour les tests suivants.

Si le design utilisateur s'exécute visiblement sur l'UART mais que DTMCS reste
nul, utilisez le scan brut ECP5 ER1/DTMCS ou comparez avec un build OpenOCD connu
comme fonctionnel avant de modifier le RTL Hazard3.

Construire et charger un moniteur adapté à l'horloge
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le profil FPGA ULX4M-LD actuellement qualifié exécute Hazard3/AHB à 40 MHz.
Construisez un moniteur logiciel correspondant sans relancer le routage FPGA :

.. code-block:: bash

   HAZARD3_BUILD_DIR="$PWD/build/ulx4m-ld-monitor-test/monitor" \
   HAZARD3_MEMORY_PROFILE=64m \
   HAZARD3_SYS_CLK_HZ=40000000 \
       ./scripts/build.sh

Puis, avec OpenOCD ayant déjà examiné la cible :

.. code-block:: bash

   ./scripts/load-firmware.sh \
       ./build/ulx4m-ld-monitor-test/monitor/hazard3-boot-monitor.elf

Un chargement réussi signale des sections ``.vectors``, ``.text``, données en
lecture seule et ``.data`` correspondantes avant de reprendre à l'adresse
``0x00000040``.

VisualGDB
---------

Les utilisateurs Windows peuvent utiliser les fichiers du projet sous
``VisualGDB/`` avec Visual Studio. Le débogueur communique toujours avec la même
cible OpenOCD/GDB ; le chemin en ligne de commande reste donc le workflow de
référence. Déconnectez VisualGDB avant d'exécuter le chargeur batch de firmware,
car un seul client GDB doit posséder la cible OpenOCD à la fois.

Le script d'assistance au démarrage GDB est :

.. code-block:: text

   scripts/hazard3-debug.gdb

Dépannage
---------

Si le module de débogage n'est pas détecté de manière fiable, distinguez
d'abord l'accès au TAP physique de l'accès au DTM Hazard3. Un IDCODE ECP5
correct avec DTMCS nul est une panne différente d'un adaptateur incapable de
lire l'IDCODE ECP5. Ne réduisez l'horloge JTAG qu'après avoir vérifié l'image
FPGA active, la séparation des pilotes Tigard et les réglages
d'alimentation/référence de la cible.

Voir :doc:`../troubleshooting` pour les problèmes courants liés à OpenOCD et à
la propriété des interfaces.

Références externes
-------------------

* `Manuel ULX3S <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_
* `Contraintes ULX3S v2.x/v3.0 <https://github.com/emard/ulx3s/blob/master/doc/constraints/ulx3s_v20.lpf>`_
* `DTM JTAG ECP5 de Hazard3 <https://github.com/Wren6991/Hazard3/blob/stable/hdl/debug/dtm/hazard3_ecp5_jtag_dtm.v>`_
* `Sélection DTM de l'exemple SoC Hazard3 <https://github.com/Wren6991/Hazard3/blob/stable/example_soc/soc/example_soc.v>`_
* `Brochage et utilisation de Tigard <https://github.com/tigard-tools/tigard>`_
* `Brochage JTAG ESP32 Espressif <https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/jtag-debugging/configure-other-jtag.html>`_
* `Primitives prises en charge par yosys/nextpnr <https://github.com/YosysHQ/nextpnr/blob/main/ecp5/docs/primitives.md>`_
