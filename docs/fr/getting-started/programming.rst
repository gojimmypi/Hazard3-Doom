Programmation et démarrage persistant
=====================================

Il existe deux objectifs de programmation différents :

Sous Windows, exécutez les étapes en ligne de commande de cette page depuis
**WSL/Ubuntu Bash**, sauf indication explicite contraire. Le navigateur et la
configuration des pilotes USB Windows restent du côté Windows ; appeler un
``.exe`` Windows fourni depuis WSL ne fait pas de PowerShell ou ``cmd.exe`` le
shell de build du projet.

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
#. ``DOOM.IMG`` et ``DOOM.WAD`` sont lus depuis la carte SD.
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

L'ULX4M-LD utilise son bootloader DFU Micro-B USB pour stocker le bitstream
utilisateur persistant dans la flash SPI. Cette image utilisateur est conservée
après une coupure d'alimentation. Sous Windows, le périphérique DFU apparaît
normalement avec le VID:PID ``1d50:614b`` et WinUSB. Cette connexion USB est
distincte de l'adaptateur externe Tigard JTAG/UART.

.. important::

   La programmation normale de Hazard3-Doom met à jour le **bitstream
   utilisateur**, et non le bootloader DFU lui-même. Le remplacement du
   bootloader est très inhabituel et doit être réservé au développement du
   bootloader ou à la récupération d'un bootloader absent/corrompu. Consultez
   :doc:`../user-guide/bootloader` pour cette opération et sa procédure de
   récupération distinctes.

Pour entrer dans le mode DFU établi de récupération/programmation :

#. Coupez l'alimentation.
#. Maintenez le bouton PCB ``BTN3`` (certaines versions de carte peuvent utiliser d'autres boutons !).
#. Connectez le câble Micro-B USB de l'ULX4M.
#. Attendez l'énumération du VID:PID ``1d50:614b``, puis relâchez ``BTN3``.

``BTN3`` ne sert qu'à sélectionner DFU au démarrage ; il n'est pas nécessaire de
le maintenir pendant le transfert. Lorsque vous invoquez directement depuis WSL
les exécutables Windows fournis, utilisez
``chmod +x ./bin/openFPGALoader.exe ./bin/dfu-util.exe`` si Bash signale
``Permission denied``.

La commande de programmation validée est :

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

Le réglage alternatif DFU 0 correspond à la zone du bitstream utilisateur ; le
bootloader ULX4M conserve sa propre zone protégée sous la région de l'image
utilisateur. Lors de la mise au point, une image correctement écrite n'a commencé
à s'exécuter qu'après avoir explicitement demandé au bootloader de quitter DFU.
Utilisez :

.. code-block:: bash

   ./bin/dfu-util.exe -a 0 -e

Cette commande ``-e`` ne télécharge ni n'efface de données FPGA. Elle demande la
transition du bootloader qui démarre l'image utilisateur déjà stockée. La
séquence validée a produit une sortie UART immédiatement après ``-e``.

Cette distinction est importante pour le diagnostic. Si l'IDCODE ECP5 est
visible via Tigard mais que l'UART reste silencieux et qu'OpenOCD indique
``dtmcontrol is 0``, vérifiez si la carte est encore en DFU avant de modifier le
câblage JTAG ou le RTL Hazard3. Consultez :doc:`../user-guide/jtag-debugging`.

Le démarrage à froid persistant est une étape de qualification distincte de
« écriture DFU + exécution immédiate ». Validez d'abord une image candidate avec
``dfu-util -a 0 -e`` et les tests de qualification DDR, puis vérifiez le
comportement normal au démarrage de la carte. Ne considérez pas qu'un transfert
DFU réussi suffit à qualifier le démarrage à froid.

Point de contrôle d'image qualifiée ULX4M-LD
--------------------------------------------

Le point de contrôle de développement actuellement qualifié sur matériel est le
routage seed 2 avec Hazard3 à 40 MHz et LiteDRAM à 60 MHz, documenté dans
:doc:`../reference/board-profiles`. Le SHA256 du bitstream testé localement était :

.. code-block:: text

   294602982dfc4a9906961f2e8b6f43de925d8c11a7e5e6bb0f5e392965a868de

Après programmation et sortie du mode DFU, utilisez la commande ``s`` du moniteur
pour confirmer que LiteDRAM est prête, puis exécutez ``q`` avant de considérer
une nouvelle image générée comme un remplacement qualifié pour la DDR.

.. warning::

   Validez un bitstream avant d'en faire l'image autonome normale. Pour
   l'ULX4M-LD, cela inclut à la fois le timing statique et de vrais tests DDR ;
   un PASS nextpnr seul ne suffit pas.

Consultez :doc:`../user-guide/sd-card` pour le contenu de la carte SD et les
diagnostics de démarrage.

Références d'implémentation
---------------------------

* :doc:`../user-guide/bootloader`
* :doc:`../reference/board-profiles`

* `openFPGALoader <https://trabucayre.github.io/openFPGALoader/guide/install.html>`_
