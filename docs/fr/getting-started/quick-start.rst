Démarrage rapide depuis les sources
====================================

.. note::

   Pour exécuter Hazard3-Doom avant d'installer les chaînes de développement
   FPGA et RISC-V, commencez par :doc:`no-install` et les images précompilées
   publiées.

.. important:: Utilisateurs Windows : ouvrez d'abord WSL/Ubuntu

   Cette page de build depuis les sources suppose un shell Linux/Bash. Sous
   Windows, utilisez **WSL avec Ubuntu** pour cloner le dépôt, installer la
   chaîne de build et exécuter les scripts ``.sh``. Ne remplacez pas ces
   commandes de build par PowerShell ou ``cmd.exe``. Windows natif n'est utilisé
   que pour les étapes explicitement marquées navigateur, pilote USB, port COM
   ou ``.exe`` Windows.


Cible
-----

La cible principale documentée est l'**ULX3S 85F** exécutant Hazard3 à 50 MHz avec sortie HDMI. La cible compacte ULX3S 12F et les profils ULX4M-LD/ULX4M-LS sont également documentés lorsque leur horloge, leur vidéo ou leur organisation mémoire diffère.

Configuration requise
---------------------

Configuration minimale du système de développement :

* RAM : 8 Gio configurés (les machines virtuelles peuvent signaler un peu moins
  de mémoire utilisable)
* Processeurs : 2
* Disque : capacité du système de fichiers de 40 Gio
* Swap : 4 Gio recommandés

Recommandé pour les compilations depuis les sources :

* RAM : 12 à 16 Gio
* Processeurs : 4
* Disque : 60 Gio ou plus
* Swap : 4 à 8 Gio

La compilation des outils FPGA depuis les sources peut utiliser beaucoup de
mémoire, en particulier avec les compilations parallèles. Les paquets OSS CAD
Suite recommandés évitent cette étape de compilation des outils. Sur les
systèmes disposant de moins que la RAM minimale requise, les builds du projet
peuvent néanmoins être interrompus en raison de la pression mémoire.

Le script ``check-system-requirements.sh`` affiche les ressources détectées :

.. code-block:: bash

   ./scripts/check-system-requirements.sh


Installation des logiciels requis
----------------------------------

Pour la chaîne d'outils FPGA, le point de départ multiplate-forme recommandé est
`OSS CAD Suite <https://github.com/YosysHQ/oss-cad-suite-build>`_, fourni sous
forme de binaires précompilés. Installez le paquet adapté à votre plate-forme et
activez son environnement afin que Yosys, nextpnr, Project Trellis/ecppack et
les outils associés soient disponibles dans ``PATH``. Installez séparément une
chaîne GCC RISC-V bare-metal compatible et rendez-la disponible dans ``PATH`` ;
voir :doc:`prerequisites` pour les noms de chaînes pris en charge et les
options de remplacement.

Pour Ubuntu/WSL, le projet fournit également un installateur pratique. Par
défaut, il installe et active automatiquement la version précompilée d'OSS CAD
Suite attendue par le projet, ainsi que les autres logiciels nécessaires à
l'environnement de développement connu. Des options avancées de compilation
depuis les sources sont également disponibles lorsque certains outils FPGA
doivent être construits à partir de commits GitHub amont spécifiques :

.. code-block:: bash

   mkdir -p workspace
   cd workspace

   wget \
       https://raw.githubusercontent.com/ulx3s/Hazard3-Doom/main/scripts/full-install.sh \
       https://raw.githubusercontent.com/ulx3s/Hazard3-Doom/main/scripts/check-system-requirements.sh

   chmod +x ./full-install.sh
   chmod +x ./check-system-requirements.sh

   ./full-install.sh

.. admonition:: Versions reproductibles des outils FPGA

   Par défaut, l'installateur pratique utilise la version précompilée d'OSS CAD
   Suite attendue par le projet. Ses options de compilation depuis les sources
   peuvent à la place construire certains outils FPGA à partir de commits GitHub
   amont spécifiques lorsqu'une révision exacte est requise. Si vous utilisez
   une version OSS CAD Suite installée indépendamment, vérifiez le build obtenu
   et son timing. Voir :doc:`/user-guide/build` et le script
   `build-ecp5-bitstream-common.sh <https://github.com/ulx3s/Hazard3-Doom/blob/main/scripts/build-ecp5-bitstream-common.sh>`_
   pour plus de détails.

1. Cloner le dépôt
------------------

Si vous utilisez ``./full-install.sh`` ci-dessus, cette étape a été effectuée
automatiquement.


Utilisez un clone récursif afin que les sous-modules Hazard3 et DoomGeneric soient présents :

.. code-block:: bash

   git clone --recursive https://github.com/ulx3s/Hazard3-Doom.git
   cd Hazard3-Doom
   git submodule sync --recursive
   git submodule update --init --recursive

Pour un checkout existant :

.. code-block:: bash

   ./scripts/setup-submodules.sh

2. Construire la cible ULX3S complète
-------------------------------------

.. code-block:: bash

   ./scripts/build-ulx3s-85f-doom.sh

Les sorties importantes incluent :

.. code-block:: text

   build/fpga_ulx3s_85f.bit
   build/ulx3s-85f/monitor/hazard3-boot-monitor.elf
   build/ulx3s-85f/doom-image/hazard3-doom.h3img
   build/ulx3s-85f/hazard3-boot-monitor.hex

3. Programmer le FPGA pour un essai
-----------------------------------

Pour ULX3S, l'application web Hazard3-Doom peut charger ``fpga_ulx3s_85f.bit``
directement dans la SRAM du FPGA via l'interface JTAG FT231X ``US1`` de la
carte. Développez **FPGA web flasher**, sélectionnez le fichier ``.bit``,
connectez le périphérique USB ULX3S, sondez le JTAG puis choisissez
**Program FPGA SRAM**.

Sous Windows, ce chemin WebUSB exige que l'interface FT231X de l'ULX3S utilise
le pilote WinUSB. Voir :doc:`../user-guide/web-flasher` pour la procédure
complète de configuration, de pilote, de vérification de cible et de dépannage.

Un chargement FPGA volatile **ne survit pas** à une coupure d'alimentation.
D'autres outils de programmation ULX3S peuvent toujours être utilisés si vous
les préférez. Pour une installation autonome permanente, voir
:doc:`programming` et :doc:`../user-guide/sd-card`.


Depuis WSL/Bash sous Windows, le ``fujprog`` Windows fourni peut être appelé
directement grâce à l'interopérabilité WSL :

.. code-block:: bash

   ./bin/fujprog-v48-win64.exe ./build/fpga_ulx3s_85f.bit

Sous Linux natif avec ``fujprog`` installé :

.. code-block:: bash

   fujprog ./build/fpga_ulx3s_85f.bit

Optionnel : charger l'ELF actuel du moniteur via OpenOCD
--------------------------------------------------------

Une mise à jour logicielle du moniteur peut être chargée sans rerouter ni
reprogrammer le FPGA. Ce chemin utilise le module de débogage Hazard3 et exige
trois éléments coopérants : OpenOCD, le helper loopback ``web-server.py`` et le
navigateur. La page du navigateur peut être la copie publique GitHub Pages ;
seuls le helper, GDB et OpenOCD doivent tourner localement.

Déconnectez d'abord le **FPGA web flasher** du navigateur de ``US1`` afin
qu'OpenOCD puisse posséder l'interface JTAG FT231X. Dans un terminal, depuis la
racine du dépôt, démarrez OpenOCD :

.. code-block:: bash

   ./scripts/start-openocd.sh

Une session ULX3S 85F saine contient des lignes similaires à :

.. code-block:: text

   JTAG tap: lfe5u85.hazard3 tap/device found: 0x41113043
   Examined RISC-V core; found 1 harts
   Listening on port 3333 for gdb connections

Laissez OpenOCD en cours d'exécution. Dans un second terminal, démarrez le
helper loopback :

.. code-block:: bash

   python3 web/web-server.py

Pour une clé d'accès facultative demandée au démarrage, utilisez ``--access-key``. L'assistant n'écoute que sur ``127.0.0.1`` et indique si un service est présent sur le port GDB OpenOCD habituel ``3333``.

Vous pouvez alors continuer avec la page publique
``https://ulx3s.github.io/Hazard3-Doom/`` ou ouvrir la copie locale
``http://127.0.0.1:8000/``. Le panneau **Console firmware uploader** doit
indiquer **Local loader Ready** et **OpenOCD Ready** ; **refresh** force une
vérification immédiate.

Sélectionnez ``build/ulx3s-85f/monitor/hazard3-boot-monitor.elf`` puis chargez-le.
GDB se connecte au serveur OpenOCD déjà actif, vérifie les sections ELF, reprend
Hazard3 puis se déconnecte. La vérification d'état OpenOCD du helper est passive
et ne consomme pas de connexion GDB.

L'adaptateur USB-UART J1 externe utilise un chemin distinct de l'interface JTAG
``US1`` ; Web Serial peut donc rester connecté pendant qu'OpenOCD fonctionne.
Voir :doc:`../user-guide/web-tool` et :doc:`../user-guide/jtag-debugging` pour
le workflow complet et les détails de dépannage.

4. Charger Doom via UART
------------------------

L'outil web peut effectuer les deux transferts Doom sans quitter la console du
navigateur. Développez **Serial connection**, connectez l'UART de la carte et
vérifiez que l'invite ``>`` du moniteur résident est active. Développez ensuite
**Device uploading** :

#. Ouvrez **Doom H3IMG uploader**, sélectionnez
   ``build/ulx3s-85f/doom-image/hazard3-doom.h3img`` puis **Upload H3IMG**.
#. Ouvrez **Doom IWAD uploader**, sélectionnez un fichier ``.wad`` obtenu
   légalement, choisissez le profil mémoire correspondant au moniteur résident
   puis **Upload IWAD**.
#. Activez **Launch with ``j`` after upload** dans le chargeur IWAD si Doom doit
   démarrer immédiatement après l'acceptation de l'IWAD.

Pour le flux complet et la table des profils mémoire, voir
:doc:`../user-guide/web-tool`.

Les chargeurs en ligne de commande restent disponibles. Fermez d'abord tout
terminal ou connexion navigateur qui possède le port UART. Le shell de
développement normal est WSL/Linux Bash. Les exemples PowerShell et ``cmd.exe``
ci-dessous sont uniquement des alternatives natives Windows pour le
téléversement UART ; ils ne remplacent pas WSL pour le build depuis les sources.

**WSL/Linux Bash**

.. code-block:: bash

   python3 doom/upload-doom-image.py \
       build/ulx3s-85f/doom-image/hazard3-doom.h3img \
       --port /dev/ttyS7

   python3 doom/upload-wad.py \
       /path/to/DOOM.WAD \
       --port /dev/ttyS7 \
       --launch

Sous WSL, utilisez le périphérique série exposé pour le port COM Windows
lorsqu'il est disponible (par exemple COM7 peut apparaître comme
``/dev/ttyS7``).

**Optionnel : Windows PowerShell**

.. code-block:: powershell

   python.exe .\doom\upload-doom-image.py `
       .\build\ulx3s-85f\doom-image\hazard3-doom.h3img `
       --port COM7

   python.exe .\doom\upload-wad.py `
       C:\path\to\DOOM.WAD `
       --port COM7 `
       --launch

**Optionnel : invite de commandes Windows (cmd.exe)**

.. code-block:: bat

   python.exe .\doom\upload-doom-image.py ^
       .\build\ulx3s-85f\doom-image\hazard3-doom.h3img ^
       --port COM7

   python.exe .\doom\upload-wad.py ^
       C:\path\to\DOOM.WAD ^
       --port COM7 ^
       --launch

Le chargeur IWAD en ligne de commande utilise désormais ``--memory-profile auto``
par défaut. Il interroge le moniteur en cours d'exécution avec la commande ``v``
et sélectionne la région WAD ``32m`` ou ``64m`` du moniteur avant d'envoyer
l'en-tête. Cela évite qu'un moniteur 12F de 32 Mio reçoive accidentellement
une adresse WAD de 64 Mio. Les options explicites ``--memory-profile 32m`` ou
``--memory-profile 64m`` restent disponibles pour un ancien moniteur qui ne
signale pas ``memory_profile``. L'image H3IMG doit toujours correspondre au
build de la carte.

Les noms de ports UART ne sont que des exemples. Sous WSL/Linux, utilisez le
périphérique visible dans cet environnement, par exemple ``/dev/ttyS7`` sous
WSL ou ``/dev/ttyUSB0``/``/dev/ttyACM0`` sous Linux natif. Les alternatives
Windows natives utilisent le port COM attribué à la carte.

5. Vérifier le démarrage
------------------------

Un lancement UART sain contient des marqueurs similaires à :

.. code-block:: text

   H3L READY
   H3L DATA
   H3L OK
   H3W READY
   H3W DATA
   H3W OK
   Doom SDRAM image startup
   monitor ABI: PASS
   Doom interactive HDMI loop: READY

Chemin rapide ULX4M-LD
------------------------

Pour ULX4M-LD, utilisez un bitstream qualifié avec Hazard3 à 40 MHz et LiteDRAM
à 60 MHz. Pour entrer en DFU normal, coupez l'alimentation, maintenez le bouton
PCB ``BTN3`` pendant la connexion du câble Micro-B ULX4M, attendez l'énumération
du VID:PID ``1d50:614b``, puis relâchez ``BTN3``. Il n'est **pas** nécessaire de
maintenir ``BTN3`` pendant la programmation.

Si Bash sous WSL signale ``Permission denied`` pour les outils Windows fournis,
rendez-les exécutables :

.. code-block:: bash

   chmod +x ./bin/openFPGALoader.exe ./bin/dfu-util.exe

Programmez le bitstream utilisateur persistant puis quittez explicitement DFU :

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

   ./bin/dfu-util.exe -a 0 -e

Utilisez l'interface 0 de Tigard avec le pilote FTDI VCP pour l'UART à 115200
bauds et l'interface 1 avec libusbK pour le JTAG OpenOCD. Le build ULX4M-LD
complet écrit l'image Doom dans
``build/ulx4m-ld/doom-image/hazard3-doom.h3img``. Par exemple, sous WSL/Bash si
le VCP Tigard apparaît comme ``/dev/ttyS8`` :

.. code-block:: bash

   ./doom/upload-doom-image.py \
       ./build/ulx4m-ld/doom-image/hazard3-doom.h3img \
       --port /dev/ttyS8

Le nom du périphérique série n'est qu'un exemple. Une fois le moniteur actif,
vérifiez ``s`` pour ``external_memory_ready=YES`` puis exécutez ``q``. Le chemin
qualifié actuel passe également ``k``, ``d`` et ``x``.

Pour une mise à jour logicielle seule du moniteur correspondant au FPGA à
40 MHz :

.. code-block:: bash

   HAZARD3_BUILD_DIR="$PWD/build/ulx4m-ld-monitor-test/monitor" \
   HAZARD3_MEMORY_PROFILE=64m \
   HAZARD3_SYS_CLK_HZ=40000000 \
       ./scripts/build.sh

Démarrez ensuite la configuration OpenOCD Tigard ULX4M et chargez explicitement
cet ELF de test séparé :

.. code-block:: bash

   ./scripts/load-firmware.sh \
       ./build/ulx4m-ld-monitor-test/monitor/hazard3-boot-monitor.elf

Pour un build complet ULX4M-LD normal, utilisez plutôt l'outil propre à la carte
``scripts/gdb/load-ulx4m-ld-85f-monitor.gdb``. Voir
:doc:`../user-guide/jtag-debugging` pour les détails sur les pilotes, le câblage,
l'IDCODE et le dépannage DTM.

Étapes suivantes
----------------

* Utilisez :doc:`../user-guide/monitor` pour inspecter et contrôler le moniteur résident.
* Utilisez :doc:`../user-guide/sd-card` pour démarrer sans PC.
* Utilisez :doc:`../user-guide/jtag-debugging` pour le débogage au niveau du code source.
* Utilisez :doc:`../user-guide/sao` pour la prise en charge SAO/I2C.
* Utilisez :doc:`../user-guide/i2cdriver` pour l'interface HDMI d'analyse I2C.

Références d'implémentation
---------------------------
* `openFPGALoader <https://trabucayre.github.io/openFPGALoader/guide/install.html>`_
