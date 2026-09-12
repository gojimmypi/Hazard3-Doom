Démarrage rapide
================

Cible
-----

La cible principale documentée est l'**ULX3S 85F** exécutant Hazard3 à 50 MHz avec sortie HDMI. La cible compacte ULX3S 12F et les profils ULX4M-LD/ULX4M-LS sont également documentés lorsque leur horloge, leur vidéo ou leur organisation mémoire diffère.

1. Cloner le dépôt
------------------

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

   ./scripts/build-ulx3s-doom.sh

Les sorties importantes incluent :

.. code-block:: text

   build/fpga_ulx3s.bit
   build/ulx3s/monitor/hazard3-boot-monitor.elf
   build/ulx3s/doom-image/hazard3-doom.h3d
   build/ulx3s/hazard3-boot-monitor.hex

3. Programmer le FPGA pour un essai
-----------------------------------

Pour ULX3S, l'application web Hazard3-Doom peut charger ``fpga_ulx3s.bit``
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

Optionnel : charger l'ELF actuel du moniteur via OpenOCD
--------------------------------------------------------

Une mise à jour logicielle du moniteur peut être chargée sans rerouter ni
reprogrammer le FPGA. Ce chemin utilise le module de débogage Hazard3 et exige
trois processus coopérants : OpenOCD, le serveur web local et le navigateur.

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
serveur web du projet :

.. code-block:: bash

   python3 web/web-server.py

Ouvrez ``http://127.0.0.1:8000/`` dans Chrome ou Edge. N'ouvrez **pas**
``web/index.html`` avec une URL ``file://`` ; la page statique ne peut pas
appeler l'API locale de chargement du firmware. Développez **Console firmware
uploader**, sélectionnez ``build/ulx3s/monitor/hazard3-boot-monitor.elf`` puis
chargez-le. GDB se connecte au serveur OpenOCD déjà actif, vérifie les sections
ELF, reprend Hazard3 puis se déconnecte.

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

#. Ouvrez **Doom H3D uploader**, sélectionnez
   ``build/ulx3s/doom-image/hazard3-doom.h3d`` puis **Upload H3D**.
#. Ouvrez **Doom IWAD uploader**, sélectionnez un fichier ``.wad`` obtenu
   légalement, choisissez le profil mémoire correspondant au moniteur résident
   puis **Upload IWAD**.
#. Activez **Launch with ``j`` after upload** dans le chargeur IWAD si Doom doit
   démarrer immédiatement après l'acceptation de l'IWAD.

Pour le flux complet et la table des profils mémoire, voir
:doc:`../user-guide/web-tool`.

Les chargeurs en ligne de commande restent disponibles. Fermez d'abord tout
terminal ou connexion navigateur qui possède le port UART, puis exécutez :

.. code-block:: powershell

   py .\doom\upload-doom-image.py `
       .\build\doom-image\hazard3-doom.h3d `
       --port COM7

   py .\doom\upload-wad.py `
       C:\path\to\DOOM.WAD `
       --port COM7 `
       --launch

Le nom du port UART n'est qu'un exemple ; utilisez le port attribué à votre
carte.

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

Étapes suivantes
----------------

* Utilisez :doc:`../user-guide/monitor` pour inspecter et contrôler le moniteur résident.
* Utilisez :doc:`../user-guide/sd-card` pour démarrer sans PC.
* Utilisez :doc:`../user-guide/jtag-debugging` pour le débogage au niveau du code source.
* Utilisez :doc:`../user-guide/sao` pour la prise en charge SAO/I2C.
* Utilisez :doc:`../user-guide/i2cdriver` pour l'interface HDMI d'analyse I2C.
