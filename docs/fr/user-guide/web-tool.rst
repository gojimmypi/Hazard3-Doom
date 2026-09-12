Outil Web pour les périphériques
================================

Hazard3-Doom inclut dans le répertoire ``web/`` un outil de périphérique basé
sur le navigateur. Il regroupe dans une seule page les opérations courantes de
mise en route et d'interaction avec la carte, au lieu d'exiger un terminal et
plusieurs outils de téléversement en ligne de commande.

La page actuelle comporte quatre zones principales :

* **Device uploading** - programmation de la SRAM FPGA, chargement du firmware
  console, téléversement Doom H3D et téléversement Doom IWAD ;
* **Serial connection** - sélection du port Web Serial et paramètres UART ;
* **UART terminal** - sortie du moniteur/Doom, saisie de commandes, journaux et
  capture HDMI ;
* **Hazard3-Doom controls** - commandes rapides pour le moniteur, SAO et
  I2CDriver.

Les panneaux **Device uploading** et **Serial connection** sont repliables. Les
chargeurs individuels de **Device uploading** le sont également, afin de laisser
la plus grande partie de la fenêtre au terminal pendant l'utilisation normale.

Vue d'ensemble des transports
-----------------------------

L'outil web utilise trois chemins indépendants :

.. code-block:: text

   Navigateur
     |
     +-- Web Serial --> USB-UART --> moniteur résident / Doom
     |                  |             |
     |                  |             +-- téléversement H3L .h3d
     |                  |             +-- téléversement H3W .wad
     |                  |             +-- terminal / commandes / capture écran
     |
     +-- WebUSB ------> ULX3S US1 FT231X --> ECP5 JTAG --> SRAM FPGA
     |
     +-- localhost ---> web-server.py --> GDB --> OpenOCD --> debug Hazard3
                         firmware console uniquement

Web Serial et WebUSB communiquent directement entre le navigateur et les
périphériques choisis dans les boîtes de dialogue d'autorisation. Le chargeur
de firmware console est différent : il nécessite le serveur local
``web-server.py``, car une page web statique ne peut pas lancer les outils GDB
et OpenOCD de la machine de l'utilisateur.

Prérequis du navigateur
-----------------------

Utilisez un navigateur récent basé sur Chromium, comme Chrome ou Edge. Web
Serial et WebUSB exigent un contexte sécurisé. ``localhost`` est accepté en
local et HTTPS convient à un hébergement tel que GitHub Pages.

Pour disposer de toutes les fonctions, y compris le chargeur du firmware
console, lancez le serveur du projet depuis la racine du dépôt :

.. code-block:: bash

   python3 web/web-server.py

Puis ouvrez :

.. code-block:: text

   http://127.0.0.1:8000/

``http://localhost:8000/`` est équivalent lorsque le serveur local utilise son
binding loopback par défaut.

.. warning::

   Ne double-cliquez pas sur ``web/index.html`` et ne l'ouvrez pas avec une URL
   ``file://`` lorsque le chargeur du firmware console est nécessaire. La page
   peut s'afficher comme fichier local, mais aucune API HTTP ne se trouve
   derrière elle ; le chargeur GDB/OpenOCD local sera donc signalé comme
   indisponible. La barre d'adresse doit afficher ``http://127.0.0.1:8000/``
   (ou ``localhost:8000``).

Un serveur statique générique suffit si le chargeur de firmware console n'est
pas nécessaire :

.. code-block:: bash

   cd web
   python3 -m http.server 8000

Avec un serveur statique ou GitHub Pages, le terminal UART, les chargeurs H3D
et IWAD, la capture d'écran et le flasher FPGA WebUSB restent disponibles. Le
panneau **Console firmware uploader** indique alors que le chargeur local est
indisponible.

Connexion série
---------------

Développez **Serial connection** et choisissez le périphérique UART. Les
paramètres Hazard3-Doom normaux sont :

.. code-block:: text

   115200 bauds
   8 bits de données
   aucune parité
   1 bit d'arrêt
   aucun contrôle de flux

La terminaison de ligne est réglable séparément. ``CR + LF`` est le réglage
interactif habituel.

**Connect** ouvre le sélecteur de périphérique série du navigateur.
**Reconnect** ouvre le port choisi parmi ceux déjà autorisés pour le site. Un
seul programme peut posséder un port série à la fois ; fermez PuTTY, un autre
onglet du navigateur ou un chargeur en ligne de commande avant de vous
connecter.

Téléversement des périphériques
-------------------------------

Développez **Device uploading** pour accéder aux quatre flux. Ils sont séparés
car ils utilisent des transports et des règles de persistance différents.

Flasher FPGA web
~~~~~~~~~~~~~~~~

**FPGA web flasher** accepte un fichier ECP5 ULX3S ``.bit`` ou un fichier
``.svf`` compatible et programme la **SRAM** du FPGA via l'interface JTAG FT231X
``US1`` avec WebUSB.

Le navigateur sonde l'identifiant JTAG ECP5 physique et, pour un fichier
``.bit``, vérifie que la cible du bitstream correspond au FPGA. L'image démarre
immédiatement mais disparaît à la mise hors tension. Cette commande n'écrit pas
la flash SPI persistante.

Sous Windows, le FT231X ULX3S utilisé par WebUSB doit être associé à WinUSB. Ce
pilote est indépendant de l'adaptateur USB-UART externe utilisé par Web Serial.

Voir :doc:`web-flasher` pour les identifiants de cible, les pilotes Windows, la
séquence JTAG et le dépannage.

Chargeur du firmware console
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Console firmware uploader** charge ``hazard3-boot-monitor.elf`` par le module
de débogage Hazard3. Le moniteur en cours d'exécution ne se remplace pas
lui-même. Le flux est le suivant :

#. le navigateur valide l'ELF RISC-V 32 bits little-endian ;
#. ``web-server.py`` le transmet au chargeur local du projet ;
#. GDB se connecte à OpenOCD, arrête Hazard3, écrit et vérifie les sections ELF,
   positionne le compteur ordinal, reprend le processeur puis se déconnecte.

Démarrez d'abord la configuration OpenOCD correspondante et laissez son serveur
GDB écouter sur le port ``3333``. Ne laissez pas le flasher FPGA du navigateur
connecté à ``US1`` pendant qu'OpenOCD utilise la même interface JTAG FT231X.

L'état **Local loader Ready** confirme que le navigateur peut joindre
``web-server.py`` ; il ne remplace ni ne démarre OpenOCD. OpenOCD est un
processus distinct et de longue durée qui doit déjà avoir examiné le cœur
Hazard3. Vérifiez une sortie similaire à :

.. code-block:: text

   Examined RISC-V core; found 1 harts
   Listening on port 3333 for gdb connections

L'adaptateur USB-UART J1 externe utilisé par Web Serial est indépendant de
l'interface JTAG FT231X ``US1`` ; la console UART peut donc rester connectée
pendant qu'OpenOCD fonctionne.

Ce chargeur n'est disponible qu'avec ``web/web-server.py`` sur la machine
locale. Il est désactivé lorsque la page est hébergée comme contenu statique.

Chargeur Doom H3D
~~~~~~~~~~~~~~~~~

**Doom H3D uploader** envoie une image ``.h3d`` empaquetée par la même connexion
Web Serial que le terminal. Le moniteur résident doit afficher son invite
``>``.

Avant l'envoi, le navigateur valide l'en-tête H3D, la longueur du paquet et le
CRC32 de la charge utile. Il suit ensuite le protocole H3L du moniteur :

.. code-block:: text

   navigateur -> l
   moniteur   -> H3L READY
   navigateur -> en-tête H3D de 64 octets
   moniteur   -> H3L DATA
   navigateur -> charge utile H3D
   moniteur   -> H3L OK

Le téléversement modifie uniquement la SDRAM ; il ne modifie pas la carte SD.
L'option **Launch with ``j`` after upload** peut lancer l'image immédiatement
après son acceptation par le moniteur.

Si Doom fonctionne déjà, utilisez d'abord **Stop Doom** et attendez le retour à
l'invite ``>`` du moniteur.

Chargeur Doom IWAD
~~~~~~~~~~~~~~~~~~

**Doom IWAD uploader** envoie par Web Serial un IWAD Doom obtenu légalement.
Hazard3-Doom ne distribue aucun contenu IWAD commercial.

Le navigateur valide l'identification ``IWAD``, les limites du répertoire et
des lumps, le nom visible par Doom, l'espace SDRAM réservé et le CRC32. Le
transfert utilise le protocole H3W :

.. code-block:: text

   navigateur -> w
   moniteur   -> H3W READY
   navigateur -> en-tête H3W de 64 octets
   moniteur   -> H3W DATA
   navigateur -> octets IWAD
   moniteur   -> H3W OK

Sélectionnez le profil mémoire correspondant au moniteur résident :

.. list-table::
   :header-rows: 1
   :widths: 20 30 50

   * - Profil
     - Adresse de chargement IWAD
     - Utilisation actuelle
   * - ``64m``
     - ``0x22c00000``
     - ULX3S et ULX4M-LD
   * - ``32m``
     - ``0x21000000``
     - ULX4M-LS

Le profil est important car l'en-tête H3W contient l'adresse de destination en
SDRAM. Un mauvais profil n'est donc pas un simple choix d'affichage.

Comme pour H3D, l'option **Launch with ``j`` after upload** n'envoie ``j``
qu'après réception de ``H3W OK``.

Propriété du transport pendant un transfert binaire
---------------------------------------------------

Les charges utiles H3D et IWAD sont des transferts UART binaires. Pendant l'un
de ces téléversements, l'application suspend temporairement les commandes
ordinaires et les sondes de capacité de capture d'écran afin qu'aucun octet
étranger ne soit inséré dans la charge utile. Le fonctionnement normal du
terminal reprend à la fin ou en cas d'échec du transfert.

Terminal UART et commandes
--------------------------

Le terminal UART fournit la sortie en direct, l'historique des commandes, les
compteurs RX/TX, la durée de session, l'écho local, le défilement automatique,
la copie/sauvegarde du journal et la saisie de commandes du moniteur.

Le panneau **Hazard3-Doom controls** fournit des boutons pour les opérations
courantes du moniteur et de SAO/I2C. Les commandes brutes d'un octet n'ajoutent
pas la terminaison de ligne choisie.

**Screen snip** peut capturer via UART un affichage HDMI pris en charge et
reconstruire l'image ``1024x600`` dans le navigateur. Voir :doc:`web-serial`
pour la négociation de capacité, le protocole, la reconstruction et les détails
d'implémentation firmware.

Flux de mise en route conseillé
-------------------------------

Pour une session de développement ULX3S typique :

#. Lancez ``python3 web/web-server.py`` et ouvrez
   ``http://127.0.0.1:8000/`` si le chargement du firmware console peut être
   nécessaire.
#. Si nécessaire, développez **Device uploading -> FPGA web flasher** et
   programmez le ``.bit`` correspondant dans la SRAM FPGA.
#. **Déconnectez le FPGA web flasher de US1** après la programmation. OpenOCD et
   WebUSB dans le navigateur ne peuvent pas posséder simultanément l'interface
   JTAG FT231X.
#. Dans un terminal distinct, exécutez ``./scripts/start-openocd.sh`` et attendez
   ``Examined RISC-V core`` ainsi que ``Listening on port 3333``.
#. Développez **Serial connection**, choisissez l'UART externe de la carte et
   connectez-vous en ``115200 8N1``. L'UART peut rester connecté pendant
   qu'OpenOCD fonctionne.
#. Si nécessaire, utilisez **Console firmware uploader** pour charger
   ``hazard3-boot-monitor.elf`` correspondant via le serveur OpenOCD déjà actif.
#. Vérifiez que la nouvelle bannière du moniteur est lisible et que l'invite
   ``>`` répond à ``h`` ou ``?``.
#. Téléversez l'image Doom ``.h3d`` empaquetée.
#. Téléversez un IWAD obtenu légalement avec le profil mémoire du moniteur.
#. Lancez avec ``j`` depuis l'option du chargeur ou depuis le terminal.

Sur une carte sans micro-SD installée, le moniteur peut d'abord signaler un échec
d'initialisation SD tel que ``CMD0 failed r1=0x000000FF`` avant d'afficher
l'invite ``>``. C'est normal lorsqu'aucune carte n'est présente ; il ne s'agit
pas d'une panne UART, SDRAM ou OpenOCD.

Les scripts en ligne de commande restent utiles pour l'automatisation et le
dépannage ; les chargeurs web utilisent les mêmes protocoles H3L/H3W du
moniteur.

Limites des données et de la persistance
----------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 30 35 35

   * - Opération
     - Transport
     - Persistant après coupure ?
   * - FPGA web flasher
     - WebUSB / JTAG
     - Non ; SRAM FPGA uniquement
   * - Console firmware uploader
     - localhost + GDB/OpenOCD
     - Non ; chargé dans le système FPGA en cours
   * - H3D uploader
     - Web Serial / H3L
     - Non ; SDRAM uniquement
   * - IWAD uploader
     - Web Serial / H3W
     - Non ; SDRAM uniquement

Pour le démarrage autonome et la configuration FPGA persistante, voir
:doc:`../getting-started/programming` et :doc:`sd-card`.

Documentation associée
----------------------

* :doc:`web-serial` - console Web Serial et protocole détaillé de capture HDMI.
* :doc:`web-flasher` - guide détaillé WebUSB/JTAG pour ULX3S.
* :doc:`monitor` - commandes et chargeurs du moniteur résident.
* :doc:`doom` - image Doom et fonctionnement à l'exécution.
* :doc:`sd-card` - chargement autonome H3D/IWAD depuis micro-SD.
* :doc:`jtag-debugging` - configuration OpenOCD/GDB.
