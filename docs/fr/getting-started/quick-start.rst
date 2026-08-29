Démarrage rapide
================

Cible
-----

La cible principale documentée est l'**ULX3S 85F** exécutant Hazard3 à 50 MHz avec sortie HDMI. La cible compacte ULX3S 12F et les profils ULX4M-LD/ULX4M-LS sont également documentés lorsque leur horloge, leur vidéo ou leur organisation mémoire diffère.

1. Cloner le dépôt
------------------

Utilisez un clone récursif afin que les sous-modules Hazard3 et DoomGeneric soient présents :

.. code-block:: bash

   git clone --recursive https://github.com/gojimmypi/Hazard3-Doom.git
   cd Hazard3-Doom
   git switch develop
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
   build/hazard3-boot-monitor.elf
   build/doom-image/hazard3-doom.h3d

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

4. Charger Doom via UART
------------------------

Fermez tout programme de terminal qui possède déjà le port UART, puis téléversez l'image Doom :

.. code-block:: powershell

   py .\doom\upload-doom-image.py `
       .\build\doom-image\hazard3-doom.h3d `
       --port COM7

Téléversez ensuite un IWAD obtenu légalement :

.. code-block:: powershell

   py .\doom\upload-wad.py `
       C:\path\to\DOOM.WAD `
       --port COM7 `
       --launch

Le nom du port UART n'est qu'un exemple ; utilisez le port attribué à votre carte.

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
