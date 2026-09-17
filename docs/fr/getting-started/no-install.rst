Démarrage sans installation - ULX3S
====================================

Le moyen le plus rapide d'essayer Hazard3-Doom sur une ULX3S consiste à utiliser
les fichiers précompilés du projet et le Device Tool dans le navigateur. Cette
méthode ne nécessite ni clonage du dépôt, ni Yosys, ni nextpnr, ni compilateur
RISC-V, ni scripts Python d'upload, ni OpenOCD, ni GDB.

Cette page programme temporairement le FPGA, charge Doom en SDRAM et le démarre.
La procédure ne modifie pas la flash SPI de l'ULX3S : l'image FPGA est donc
perdue à la mise hors tension.

.. note::

   Un navigateur récent basé sur Chromium, comme Chrome ou Edge, est requis.
   Sous Windows, le FT231X du port ``US1`` de l'ULX3S peut devoir utiliser le
   pilote WinUSB avant que WebUSB puisse y accéder. Il s'agit d'une configuration
   de pilote USB, et non de l'installation d'une chaîne de développement FPGA ou
   RISC-V. Voir :doc:`../user-guide/web-flasher`.

Matériel et fichiers nécessaires
--------------------------------

* une carte ULX3S 85F ou ULX3S 12F ;
* un écran HDMI ;
* la connexion USB ``US1`` de l'ULX3S pour la programmation WebUSB du FPGA ;
* un adaptateur USB-vers-UART externe connecté à l'UART Hazard3-Doom ;
* les fichiers précompilés ``.bit`` et ``.h3d`` correspondant à la carte ;
* un IWAD Doom obtenu légalement, par exemple ``DOOM.WAD`` ou ``DOOM1.WAD``.

Voir :doc:`../user-guide/pinouts` pour les connexions UART et
:doc:`../user-guide/web-tool` pour la référence complète du Device Tool.

1. Télécharger les fichiers précompilés
----------------------------------------

Le répertoire ``bin/`` du dépôt est la source recommandée pour les images
précompilées publiées par le projet :

`Parcourir le répertoire bin de Hazard3-Doom <https://github.com/ulx3s/Hazard3-Doom/tree/main/bin>`_

Utilisez ``bin/INVENTORY.md`` et l'inventaire des sommes de contrôle associé pour
identifier les fichiers publiés et leur rôle :

`Voir bin/INVENTORY.md <https://github.com/ulx3s/Hazard3-Doom/blob/main/bin/INVENTORY.md>`_

Sélectionnez la paire correspondant au FPGA de la carte :

.. list-table::
   :header-rows: 1
   :widths: 18 39 43

   * - Carte
     - Image FPGA
     - Image Doom H3D
   * - ULX3S 85F
     - ``fpga_ulx3s_hdmi_doom.bit``
     - ``hazard3-doom-ulx3s-85F.h3d``
   * - ULX3S 12F
     - ``fpga_ulx3s_12f_hdmi_doom.bit``
     - ``hazard3-doom-ulx3s-12F.h3d``

Ne mélangez pas des fichiers provenant de profils de carte différents. Le
flasher du navigateur sonde l'identifiant JTAG ECP5 physique et refuse un
fichier ``.bit`` dont la cible intégrée ne correspond pas au FPGA détecté.

.. _fig-no-install-bin-prebuilt-files:

.. figure:: ../images/no-install-bin-prebuilt-files.png
   :alt: Répertoire bin de Hazard3-Doom sur GitHub montrant les fichiers précompilés ULX3S.
   :width: 85%
   :class: screenshot

   Fichiers précompilés ULX3S publiés dans le répertoire ``bin/`` du dépôt,
   avec ``INVENTORY.md`` pour l'identification et la vérification.

Builds récents de GitHub Actions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le workflow GitHub Actions **Board integration builds** fournit également les
sorties des builds récents réussis :

`Ouvrir Board integration builds <https://github.com/ulx3s/Hazard3-Doom/actions/workflows/fpga-builds.yml>`_

Ouvrez une exécution réussie et téléchargez l'artifact correspondant exactement
au profil de carte voulu. Ces artifacts conviennent aux tests d'un build CI
récent, mais ne constituent pas un emplacement de téléchargement permanent :
ils ont une durée de rétention et disparaissent lorsque l'exécution ou l'artifact
expire ou est supprimé. Les fichiers publiés dans ``bin/`` sont donc le choix le
plus simple pour un premier essai.

.. _fig-no-install-actions-artifacts:

.. figure:: ../images/no-install-actions-artifacts.png
   :alt: Page GitHub Actions Board integration builds affichant les artefacts téléchargeables ULX3S.
   :width: 85%
   :class: screenshot

   Le workflow Board integration builds peut aussi fournir des artefacts ULX3S
   récents pour les essais.

2. Ouvrir le Device Tool
------------------------

Ouvrez l'application hébergée :

`Hazard3-Doom Device Tool <https://ulx3s.github.io/Hazard3-Doom/>`_

Pour cette méthode sans installation, toutes les opérations nécessaires sont
réalisées directement dans le navigateur. ``web-server.py``, OpenOCD et GDB ne
sont pas requis ; ils servent uniquement au workflow facultatif de chargement
et de débogage du firmware console ELF.

3. Programmer la SRAM du FPGA
-----------------------------

Connectez le port USB ``US1`` de l'ULX3S, puis dans le Device Tool :

#. Développez **Device uploading**.
#. Développez **FPGA web flasher**.
#. Sélectionnez le fichier ``.bit`` correspondant.
#. Choisissez **Connect ULX3S USB** et sélectionnez le périphérique FTDI ULX3S.
#. Choisissez **Probe JTAG** et vérifiez le FPGA détecté.
#. Choisissez **Program FPGA SRAM**.
#. Attendez que le journal indique la réussite de la programmation.

La configuration FPGA est volatile. Un cycle d'alimentation restaure la
configuration persistante normale de la carte.

.. _fig-no-install-web-flasher:

.. figure:: ../images/no-install-web-flasher.png
   :alt: Programmateur FPGA WebUSB de Hazard3-Doom avec un bitstream ULX3S sélectionné et le FPGA détecté.
   :width: 85%
   :class: screenshot

   Le programmateur FPGA du navigateur après la sonde JTAG et la sélection du
   fichier ``.bit`` ULX3S approprié.

4. Connecter l'UART
--------------------

Hazard3-Doom utilise le connecteur GPIO ``J1`` de l ULX3S pour son UART
externe. Utilisez un adaptateur USB-vers-UART 3,3 V et croisez TX/RX :

.. code-block:: text

   USB-UART TXD  ->  J1 pin 6  / GP0 / B11 -> Hazard3 uart_rx
   USB-UART RXD  <-  J1 pin 8  / GP1 / A10 <- Hazard3 uart_tx
   USB-UART GND  ->  ULX3S GND
   USB-UART VCC  ->  non connecté

.. _fig-ulx3s-uart-pinout:

.. figure:: ../images/ulx3s-uart-pinout.png
   :alt: Brochage ULX3S mettant en évidence l UART Hazard3-Doom sur GP0 et GP1 de J1.
   :width: 85%

   **UART Hazard3-Doom sur ULX3S** -- GP0 est l entrée de réception du FPGA et
   GP1 est la sortie de transmission du FPGA.

Développez **Serial connection** et connectez-vous avec les paramètres
Hazard3-Doom habituels :

.. code-block:: text

   115200 baud
   8 data bits
   no parity
   1 stop bit
   no flow control

Le moniteur résident est déjà intégré à l image FPGA Hazard3-Doom normale. Un
démarrage réussi affiche la bannière du moniteur puis l invite ``>``. Il n est
pas nécessaire de charger ``hazard3-boot-monitor.elf`` pour cette procédure.

Si aucune invite n apparaît, voir :doc:`../troubleshooting` et
:doc:`../user-guide/web-serial` avant de continuer.

5. Charger l'image Doom H3D
---------------------------

Sous **Device uploading**, développez **Doom H3D uploader** :

#. Sélectionnez le fichier ``hazard3-doom-*.h3d`` correspondant.
#. Choisissez **Upload H3D**.
#. Attendez que le moniteur accepte l'image.

Conservez toujours l'image H3D du même profil de carte que le fichier ``.bit``.

.. _fig-no-install-h3d-upload:

.. figure:: ../images/no-install-h3d-upload.png
   :alt: Outil d'upload H3D de Hazard3-Doom avec une image Doom spécifique à la carte sélectionnée.
   :width: 85%
   :class: screenshot

   Envoi de l'image ``hazard3-doom-*.h3d`` correspondant à la carte via le
   Device Tool.

6. Charger votre IWAD Doom
--------------------------

Développez **Doom IWAD uploader** et sélectionnez votre fichier ``.wad`` obtenu
légalement. Choisissez le profil mémoire correspondant au moniteur résident :

.. list-table::
   :header-rows: 1
   :widths: 45 25

   * - Carte
     - Profil mémoire
   * - ULX3S 85F
     - ``64m``
   * - ULX3S 12F
     - ``32m``

Choisissez **Upload IWAD**. Pour lancer Doom automatiquement après le transfert,
activez **Launch with ``j`` after upload** avant de démarrer l'upload.

Le projet ne distribue pas l'IWAD commercial de Doom. Vous devez fournir votre
propre IWAD obtenu légalement.

.. _fig-no-install-iwad-upload:

.. figure:: ../images/no-install-iwad-upload.png
   :alt: Outil d'upload IWAD de Hazard3-Doom avec un fichier WAD sélectionné et le lancement automatique activé.
   :width: 85%
   :class: screenshot

   Envoi d'un IWAD Doom avec le profil mémoire du moniteur approprié et le
   lancement automatique optionnel activé.

7. Vérifier le démarrage de Doom
--------------------------------

Un upload et un lancement corrects produisent des messages similaires à :

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

Doom doit maintenant être visible en HDMI et le terminal du navigateur peut
rester connecté pour les commandes du moniteur et les diagnostics.

.. _fig-no-install-doom-running:

.. figure:: ../images/no-install-doom-running.png
   :alt: Doom en cours d'exécution sur un écran HDMI ULX3S alors que l'outil navigateur reste connecté.
   :width: 85%
   :class: screenshot

   Doom en cours d'exécution après une programmation FPGA réussie et les uploads
   H3D et IWAD.

Ce que cette méthode n'installe pas
-----------------------------------

Cette procédure évite volontairement l'environnement de développement. Elle
n'installe et ne nécessite pas Yosys, nextpnr, Project Trellis, une chaîne GCC
RISC-V, le checkout Hazard3-Doom et ses submodules, les scripts d'upload en ligne
de commande, ni OpenOCD/GDB pour le chemin normal moniteur/H3D/IWAD.

Pour reconstruire ou modifier le FPGA, le firmware du moniteur ou l'image Doom,
continuez avec :doc:`quick-start` et :doc:`build`.

ULX4M-LD
--------

Les images précompilées ULX4M-LD évitent également un build FPGA local, mais la
méthode de programmation actuelle utilise encore des outils DFU sur l'hôte. Elle
n'est donc pas équivalente à la méthode ULX3S entièrement basée sur le navigateur
décrite ici. Voir :doc:`programming`.

Documentation associée
----------------------

* :doc:`../user-guide/web-tool` - référence complète du Device Tool.
* :doc:`../user-guide/web-flasher` - WebUSB ULX3S, WinUSB, contrôles de cible et dépannage.
* :doc:`../user-guide/web-serial` - fonctionnement et dépannage UART/Web Serial.
* :doc:`../user-guide/pinouts` - connexions UART et JTAG de l'ULX3S.
* :doc:`quick-start` - installer les outils de développement et tout construire depuis les sources.
* :doc:`programming` - méthodes de programmation temporaire et persistante.
