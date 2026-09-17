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

Les actions principales restent dans les en-têtes de section, la page entière
se déroule normalement et les journaux du flasher/firmware peuvent être
redimensionnés verticalement. Des infobulles courtes décrivent les transports,
les actions disponibles et la raison pour laquelle un bouton est désactivé.

Vue d'ensemble des transports
-----------------------------

L'outil web utilise trois chemins indépendants :

.. code-block:: text

   Page navigateur (localhost ou HTTPS/GitHub Pages)
     |
     +-- Web Serial --> USB-UART --> moniteur résident / Doom
     |                  |             |
     |                  |             +-- téléversement H3L .h3d
     |                  |             +-- téléversement H3W .wad
     |                  |             +-- terminal / commandes / capture écran
     |
     +-- WebUSB ------> ULX3S US1 FT231X --> ECP5 JTAG --> SRAM FPGA
     |
     +-- HTTP loopback --> web-server.py --> GDB --> OpenOCD --> debug Hazard3
                           127.0.0.1:8000             :3333
                           firmware console uniquement

Web Serial et WebUSB communiquent directement entre le navigateur et les
périphériques choisis dans les boîtes de dialogue d'autorisation. Le chargeur
de firmware console est différent : un navigateur ne peut pas lancer GDB ou
OpenOCD directement, il appelle donc le helper local ``web-server.py`` via HTTP
sur loopback.

La page elle-même n'a pas besoin d'être servie par ``web-server.py``. La page
HTTPS publique peut utiliser le helper qui tourne sur la même machine ; GDB et
OpenOCD restent entièrement locaux.

Prérequis du navigateur
-----------------------

Utilisez un navigateur récent basé sur Chromium, comme Chrome ou Edge. Web
Serial et WebUSB exigent un contexte sécurisé. ``localhost`` convient en local
et HTTPS à l'outil hébergé.

La page publique est disponible ici :

.. code-block:: text

   https://ulx3s.github.io/Hazard3-Doom/

Le terminal UART, les téléversements H3D/IWAD, la capture d'écran et la
programmation FPGA WebUSB n'ont besoin d'aucun serveur local.

Le chargement du firmware console nécessite en plus le helper local. Depuis la
racine du dépôt :

.. code-block:: bash

   python3 web/web-server.py

Le helper n'écoute que sur loopback et utilise par défaut
``127.0.0.1:8000``. Après son démarrage, vous pouvez continuer à utiliser la
page GitHub Pages ou ouvrir ``http://127.0.0.1:8000/``. Le navigateur peut
demander l'autorisation d'accéder au réseau local/loopback ; accordez-la si le
chargeur console est nécessaire.

Le helper n'accepte que des origines explicitement autorisées. Pour une origine
de développement différente :

.. code-block:: bash

   python3 web/web-server.py --allow-origin http://127.0.0.1:9000

Une origine joker ``*`` n'est volontairement pas acceptée.

Clé d'accès optionnelle
~~~~~~~~~~~~~~~~~~~~~~~

Pour une protection supplémentaire :

.. code-block:: bash

   python3 web/web-server.py --access-key

Le helper demande la clé sans l'afficher. Saisissez la même clé dans
**Console firmware uploader**. Le navigateur la conserve seulement en mémoire
de page, pas dans ``localStorage``.

Il est aussi possible de passer la clé directement sur la ligne de commande,
mais c'est moins souhaitable car l'historique du shell ou la liste des
processus peut l'exposer :

.. code-block:: bash

   python3 web/web-server.py --access-key 'example-key'

La clé est une protection supplémentaire : le helper reste limité à loopback,
vérifie exactement l'en-tête ``Origin`` et exige les en-têtes attendus du
chargeur local.

.. warning::

   N'ouvrez pas ``web/index.html`` via une URL ``file://`` pour l'outil complet.
   Utilisez HTTPS ou localhost afin que Web Serial, WebUSB et l'API loopback
   reçoivent le contexte de sécurité attendu par le navigateur.

Vérifications d'état du helper
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

**Console firmware uploader** vérifie périodiquement le helper et propose aussi
**refresh**. Chaque requête contient une valeur ``challenge`` fraîche que le
helper renvoie. Une ancienne réponse ``Ready`` mise en cache ne peut donc pas
faire croire qu'un helper arrêté est toujours vivant.

Des lignes de journal comme celles-ci sont normales :

.. code-block:: text

   GET /api/console-firmware/status?challenge=... HTTP/1.1

Après un premier état **Ready**, la page continue à le revalider. Si
``web-server.py`` s'arrête, l'état redevient indisponible sans recharger la
page.

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

**Connect** ouvre le sélecteur série du navigateur. **Reconnect** ouvre un port
déjà autorisé pour l'origine courante et reste désactivé tant que l'UART est
déjà connecté ; son infobulle explique pourquoi.

Un port série ne peut avoir qu'un propriétaire. L'outil utilise un Web Lock et
``BroadcastChannel`` entre onglets de même origine, afin qu'un second Device
Tool puisse signaler **UART already in use** si le premier possède déjà le
port. Une autre origine, PuTTY ou une autre application ne peut pas être
identifiée par nom, mais l'échec de ``open()`` est affiché comme conflit probable
de propriété du port.

``http://127.0.0.1:8000`` et ``https://ulx3s.github.io`` sont des origines
différentes et ne partagent donc pas ce verrou. Le système empêche néanmoins
les deux pages d'ouvrir simultanément le même port.

Les sections H3D et IWAD affichent aussi clairement le prérequis UART. Sans
connexion, elles proposent leur propre bouton **Connect UART**.

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
lui-même :

#. le navigateur valide l'ELF RISC-V 32 bits little-endian ;
#. il envoie l'ELF au helper loopback ``web-server.py`` ;
#. le helper appelle le chargeur firmware local ;
#. GDB se connecte à OpenOCD, arrête Hazard3, écrit et vérifie les sections ELF,
   positionne le compteur ordinal, reprend le processeur puis se déconnecte.

Démarrez d'abord la bonne configuration OpenOCD et laissez son serveur GDB
écouter sur le port ``3333``. Déconnectez le flasher FPGA WebUSB de ``US1`` :
le navigateur et OpenOCD ne peuvent pas posséder simultanément le même FT231X
JTAG.

Le panneau affiche séparément :

* **Local loader** - le navigateur peut-il joindre ``web-server.py`` ?
* **OpenOCD** - un listener local est-il présent sur ``127.0.0.1:3333`` ?

Le test OpenOCD est **passif** : le helper inspecte la table locale des ports en
écoute au lieu d'ouvrir une connexion TCP sur ``3333``. Il ne consomme donc pas
de slot GDB et ne perturbe pas un vrai chargement.

Au démarrage, ``web-server.py`` affiche soit l'état prêt, soit un avertissement
si aucun serveur GDB n'est détecté. La page met cet état à jour périodiquement ;
si OpenOCD manque, le bouton de chargement reste désactivé et son infobulle
indique qu'il faut d'abord démarrer OpenOCD.

Une session utilisable contient par exemple :

.. code-block:: text

   Examined RISC-V core; found 1 harts
   Listening on port 3333 for gdb connections

L'adaptateur USB-UART J1 externe utilisé par Web Serial est indépendant de
l'interface JTAG FT231X ``US1`` ; la console UART peut donc rester connectée.

Le chargeur console fonctionne aussi bien depuis la page locale que depuis la
page HTTPS publique. Dans les deux cas, GDB et OpenOCD restent sur la machine
de l'utilisateur.

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

Si le téléversement expire en attendant ``H3L READY``, l'outil affiche maintenant
un diagnostic visible. Vérifiez d'abord que le moniteur résident tourne à
l'invite ``>``. Si le helper local est accessible mais qu'OpenOCD est absent,
l'outil suggère aussi que le moniteur doit peut-être encore être chargé. OpenOCD
n'a pas besoin de rester actif une fois le moniteur chargé.

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

Les diagnostics de timeout H3W utilisent le même guidage concernant le moniteur
résident et OpenOCD que le chargeur H3D.

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

Le bouton **Help** envoie intentionnellement un seul octet brut ``h`` sans
terminaison de ligne ; il n'envoie pas le mot ``help``. Les infobulles sont
également sensibles à l'état : un bouton désactivé explique le prérequis
manquant, et son état actif décrit l'action effectuée.

**Screen snip** peut capturer via UART un affichage HDMI pris en charge et
reconstruire l'image ``1024x600`` dans le navigateur. Voir :doc:`web-serial`
pour la négociation de capacité, le protocole, la reconstruction et les détails
d'implémentation firmware.

Flux de mise en route conseillé
-------------------------------

Pour une session ULX3S typique :

#. Ouvrez ``https://ulx3s.github.io/Hazard3-Doom/`` ou la page locale.
#. Si nécessaire, programmez le ``.bit`` correspondant avec **FPGA web
   flasher**.
#. **Déconnectez le flasher de US1** après programmation. WebUSB et OpenOCD ne
   peuvent pas posséder simultanément le FT231X JTAG.
#. Si le chargement du firmware console peut être nécessaire, lancez
   ``python3 web/web-server.py`` dans un terminal. La page publique peut utiliser
   ce helper loopback sans être rechargée depuis localhost.
#. Dans un autre terminal, lancez ``./scripts/start-openocd.sh`` et attendez
   ``Examined RISC-V core`` puis ``Listening on port 3333``. L'état OpenOCD du
   Device Tool doit passer automatiquement à **Ready** ; **refresh** force une
   nouvelle vérification immédiate.
#. Ouvrez **Serial connection**, choisissez l'UART externe et connectez-vous en
   ``115200 8N1``. L'UART peut rester connecté pendant OpenOCD.
#. Au besoin, chargez ``hazard3-boot-monitor.elf`` avec **Console firmware
   uploader**.
#. Vérifiez que la bannière du moniteur est lisible et que l'invite ``>`` répond
   au bouton **Help** à un octet.
#. Téléversez l'image Doom ``.h3d``.
#. Téléversez un IWAD obtenu légalement avec le profil mémoire du moniteur.
#. Lancez avec ``j`` depuis l'uploader ou le terminal.

Sans carte micro-SD, le moniteur peut d'abord signaler une erreur comme
``CMD0 failed r1=0x000000FF`` avant l'invite ``>``. C'est normal si aucune carte
n'est présente et ce n'est pas une panne UART, SDRAM ou OpenOCD.

Les scripts de ligne de commande restent utiles pour l'automatisation et le
diagnostic ; les uploaders web utilisent les mêmes protocoles H3L/H3W.

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
     - HTTP loopback + GDB/OpenOCD
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
