Démarrage rapide depuis les sources
====================================

.. note::

   Pour exécuter Hazard3-Doom avant d'installer les chaînes de développement
   FPGA et RISC-V, commencez par :doc:`no-install` et les images précompilées
   publiées.


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

La compilation de Yosys et de nextpnr depuis les sources peut utiliser beaucoup
de mémoire, en particulier avec les compilations parallèles. Sur les systèmes
disposant de moins que la RAM minimale requise, des processus de compilation
peuvent être interrompus en raison de la pression mémoire.

Le script ``check-system-requirements.sh`` affiche les ressources détectées :

.. code-block:: bash

   ./scripts/check-system-requirements.sh


Installation des logiciels requis
----------------------------------

Sur un système neuf, tout peut être installé avec un seul script. Ce script est
également utile pour les mises à jour :

.. code-block:: bash

   mkdir -p workspace
   cd workspace

   wget \
       https://raw.githubusercontent.com/ulx3s/Hazard3-Doom/main/scripts/full-install.sh \
       https://raw.githubusercontent.com/ulx3s/Hazard3-Doom/main/scripts/check-system-requirements.sh

   chmod +x ./full-install.sh
   chmod +x ./check-system-requirements.sh

   ./full-install.sh

.. admonition:: Versions de Yosys et nextpnr

   Les scripts installent des versions précises de Yosys et nextpnr connues pour
   respecter les contraintes de timing avec les seeds par défaut. Les versions
   déjà installées sont remplacées silencieusement. Si vous utilisez une autre
   version de Yosys ou de nextpnr, vous devrez peut-être adapter les scripts de
   compilation. Voir :doc:`/user-guide/build` pour plus de détails, ainsi que le
   script
   `build-ecp5-bitstream-common.sh <https://github.com/ulx3s/Hazard3-Doom/blob/main/scripts/build-ecp5-bitstream-common.sh>`_.

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

Vous pouvez alors continuer avec la page publique
``https://ulx3s.github.io/Hazard3-Doom/`` ou ouvrir la copie locale
``http://127.0.0.1:8000/``. Le panneau **Console firmware uploader** doit
indiquer **Local loader Ready** et **OpenOCD Ready** ; **refresh** force une
vérification immédiate.

Sélectionnez ``build/ulx3s/monitor/hazard3-boot-monitor.elf`` puis chargez-le.
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
