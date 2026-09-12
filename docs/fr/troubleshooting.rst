Dépannage
=========

Windows ``fujprog`` signale ``Cannot find JTAG cable``
------------------------------------------------------

Sous Windows, ``fujprog`` attend que l'interface FT231X ``US1`` de l'ULX3S
utilise le pilote FTDI VCP/D2XX normal. Si cette interface a été réassociée à
WinUSB pour le flasher WebUSB, ou à un autre pilote libusb pour le JTAG,
restaurez le pilote FTDI dans le Gestionnaire de périphériques avant d'utiliser
``fujprog`` sous Windows.

Fermez d'abord OpenOCD, ``openFPGALoader`` et les sessions WebUSB du navigateur,
restaurez le pilote FTDI, débranchez/rebranchez ``US1``, puis réessayez. Voir
:doc:`user-guide/web-flasher` pour la matrice de compatibilité et la procédure de
restauration du pilote.

.. _webusb-access-denied:

Le flasher WebUSB signale ``USBDevice.open(): Access denied``
-------------------------------------------------------------

Si le flasher FPGA web voit le périphérique FTDI ULX3S mais que Windows refuse
``USBDevice.open()``, le problème survient avant le début du JTAG. L'accès
WebUSB direct exige que l'interface FT231X ULX3S utilise le pilote WinUSB plutôt
que le pilote FTDI VCP/D2XX normal.

#. Fermez ``fujprog``, OpenOCD, ``openFPGALoader`` et les autres programmes susceptibles de posséder le FT231X.
#. Confirmez que le périphérique sélectionné est bien le FT231X ``US1`` de l'ULX3S.
#. Associez cette interface à WinUSB, par exemple avec Zadig.
#. Débranchez puis rebranchez ``US1``.
#. Rechargez l'application web et reconnectez le flasher.

.. warning::

   Remplacer le pilote FTDI modifie la manière dont Windows expose cette
   interface. Vérifiez le périphérique sélectionné avant de changer son pilote.
   Les logiciels qui attendent le pilote FTDI VCP/D2XX normal ne pourront plus
   utiliser cette interface tant que le pilote FTDI n'aura pas été restauré.

.. figure:: images/Zadig-FTDI-to-WinUSB.png
   :alt: Zadig remplaçant le pilote FTDI ULX3S par WinUSB.
   :width: 580px

   Exemple de sélection WinUSB pour le FT231X ULX3S.

Voir :doc:`user-guide/web-flasher` pour le flux complet de programmation WebUSB
et les remarques concernant la restauration du pilote.

Le flasher WebUSB signale un identifiant JTAG non reconnu
---------------------------------------------------------

Ne programmez rien tant que la cible ECP5 physique n'est pas identifiée. Fermez
les autres logiciels JTAG, débranchez/rebranchez ``US1``, reconnectez le
navigateur et relancez la sonde. Une sonde ULX3S saine doit identifier un ECP5
pris en charge comme ``LFE5U-12F`` ou ``LFE5U-85F`` et afficher son IDCODE 32
bits.

La chaîne de produit USB du FT231X ne fait pas autorité pour la variante FPGA.
Utilisez l'identifiant JTAG ECP5 signalé par **Probe JTAG** pour décider si une
image correspond à la carte.

Le flasher WebUSB signale une incompatibilité de cible FPGA
-----------------------------------------------------------

Il s'agit d'un contrôle de sécurité. La cible ECP5 incorporée dans le fichier
``.bit`` sélectionné ne correspond pas à l'identifiant JTAG physique.
Sélectionnez ou reconstruisez le bitstream destiné au FPGA connecté au lieu de
contourner le contrôle.

.. _web-serial-no-compatible-devices:

Le sélecteur Web Serial indique qu'aucun périphérique compatible n'a été trouvé
-------------------------------------------------------------------------------

Si le navigateur ouvre le sélecteur Web Serial mais indique ``No compatible
devices found`` alors que Windows affiche le port COM, vérifiez le navigateur
avant de modifier le matériel ou les pilotes série USB.

#. Si Chrome affiche ``Finish update``, ``Relaunch`` ou un autre indicateur de
   mise à jour en attente, terminez la mise à jour et redémarrez complètement
   Chrome. Pendant les tests Hazard3-Doom, Chrome continuait d'énumérer un
   adaptateur CH340 comme ``COM7`` dans ``chrome://device-log`` alors que le
   sélecteur Web Serial restait vide. Une fois la mise à jour terminée et Chrome
   relancé, le sélecteur a recommencé à fonctionner.
#. Réessayez **Connect**. La console web Hazard3-Doom demande volontairement le
   sélecteur de port série du navigateur sans filtre USB VID/PID ; elle est donc
   conçue pour fonctionner avec tout port série exposé par le navigateur.
#. Fermez PuTTY, les scripts de téléversement, les moniteurs série d'IDE et les
   autres programmes susceptibles de posséder déjà le port.
#. Ouvrez ``chrome://device-log``, activez les catégories Serial et USB, puis
   vérifiez si le port COM attendu a été supprimé sans jamais être ajouté de
   nouveau. Lors d'une session de débogage validée, Chrome a journalisé ``Serial device removed:
   path=COM7`` et ne s'est pas rétabli après le simple
   arrêt d'OpenOCD, alors que PuTTY pouvait toujours ouvrir le port. Débrancher
   puis rebrancher physiquement l'adaptateur USB-UART externe a forcé la
   ré-énumération Windows/Chrome et restauré le sélecteur Web Serial.
#. Si une activité de débogage a précédé la panne, fermez PuTTY et les autres
   propriétaires du port série, arrêtez OpenOCD, puis déconnectez/reconnectez
   physiquement **l'adaptateur USB-UART externe**. Arrêter OpenOCD seul peut
   libérer son handle FT231X/JTAG sans amener Chrome à redécouvrir le port COM
   indépendant.
#. Après reconnexion, ``chrome://device-log`` doit afficher à la fois le
   périphérique USB et un nouvel événement ``Serial device added`` pour le port
   COM attendu. Utilisez **Connect** dans l'interface web pour ouvrir le
   sélecteur du navigateur.
#. N'utilisez pas ``navigator.serial.getPorts()`` comme inventaire complet des
   ports COM Windows. Il ne renvoie que les ports déjà autorisés pour l'origine
   actuelle du navigateur. Utilisez **Connect** pour accorder l'accès à un autre
   port.

.. figure:: images/chrome-pending-update.png
   :alt: Chrome affichant un bouton Finish update alors que la console UART Hazard3-Doom est déconnectée.
   :width: 520px

   Si le sélecteur Web Serial est vide alors que Chrome affiche une mise à jour
   en attente, terminez la mise à jour et relancez le navigateur avant de
   modifier les pilotes série.

Web Serial sélectionne un TTY Linux mais ne parvient pas à l'ouvrir
-------------------------------------------------------------------

Si Chrome peut voir et autoriser un port tel que ``USB2.0-Serial (ttyUSB1)``
mais que ``SerialPort.open()`` échoue, distinguez l'autorisation du navigateur
des permissions du périphérique Linux.

Vérifiez le nœud de périphérique, les groupes de la session actuelle et le
propriétaire actuel :

.. code-block:: bash

   ls -l /dev/ttyUSB1
   groups
   fuser -v /dev/ttyUSB1

Un résultat Ubuntu courant est :

.. code-block:: text

   crw-rw---- 1 root dialout ... /dev/ttyUSB1

Si ``dialout`` possède le périphérique mais n'apparaît pas dans ``groups``,
ajoutez l'utilisateur :

.. code-block:: bash

   sudo usermod -aG dialout "$USER"

La modification s'applique à une **nouvelle session de connexion**. La sortie de
``groups`` dans une session de bureau existante ne change pas simplement parce
que ``usermod`` a réussi, et un processus Chrome déjà lancé conserve les anciens
groupes supplémentaires.

Pour un diagnostic temporaire sans redémarrage, déconnexion ou reconnexion USB,
accordez à l'utilisateur courant une ACL sur le nœud de périphérique existant :

.. code-block:: bash

   sudo setfacl -m u:"$USER":rw /dev/ttyUSB1

Remplacez ``ttyUSB1`` par le port réel. Cette ACL peut disparaître lorsque le
périphérique est ré-énuméré ; l'appartenance à ``dialout`` reste la correction
persistante normale. ``newgrp dialout`` peut créer immédiatement un shell avec
le nouveau groupe, mais ne modifie pas un bureau ou un processus Chrome déjà en
cours d'exécution.

Si les permissions sont correctes mais que l'ouverture échoue encore, vérifiez
avec ``fuser`` si un autre processus possède le port. ModemManager sous Ubuntu
peut aussi sonder les adaptateurs série USB. Pour le diagnostic, arrêtez-le
temporairement avec :

.. code-block:: bash

   sudo systemctl stop ModemManager

Ne désactivez ModemManager définitivement que sur un système où ses fonctions
de modem ne sont volontairement pas nécessaires.

La sortie UART est lisible mais le moniteur ignore les commandes
----------------------------------------------------------------

Un texte de démarrage lisible en ``115200 8N1`` prouve le chemin d'émission du
FPGA et le débit, mais ne prouve **pas** le sens UART opposé. Si le moniteur
affiche une bannière propre et l'invite ``>`` mais que ``h`` ou ``?`` ne donne
aucune réponse, inspectez d'abord le chemin TX de l'adaptateur vers RX du FPGA.
Un cavalier mal connecté peut produire exactement ce symptôme unidirectionnel.

Le câblage ULX3S testé par le projet est :

.. code-block:: text

   adaptateur TX  -> ULX3S J1 broche 8 / GP1 / RxD Hazard3
   adaptateur RX  <- ULX3S J1 broche 6 / GP0 / TxD Hazard3
   adaptateur GND -> GND ULX3S

Voir :doc:`hardware/ulx3s/interfaces` pour la description des interfaces de la
carte.

Pour distinguer un problème du navigateur d'un problème UART physique,
déconnectez Web Serial afin qu'il libère le port, puis testez directement sous
Linux :

.. code-block:: bash

   stty -F /dev/ttyUSB1 \
       115200 cs8 -cstopb -parenb \
       -ixon -ixoff -crtscts raw -echo

   # Dans un terminal :
   cat /dev/ttyUSB1

   # Dans un autre terminal, envoyez la commande d'aide d'un octet du moniteur :
   printf 'h' > /dev/ttyUSB1

Si la sortie de démarrage est propre mais que cette commande ne produit toujours
aucune réponse, concentrez-vous sur le fil TX de l'adaptateur, l'enfichage du
connecteur, la masse et la broche RX du FPGA plutôt que de modifier OpenOCD ou
le débit.

Le téléversement de Doom expire
-------------------------------

* Quittez Doom avec ``Ctrl-X`` afin que le moniteur résident soit à l'écoute.
* Fermez PuTTY ou tout autre programme qui possède le port UART.
* Confirmez le périphérique COM/TTY sélectionné.
* Confirmez que le moniteur et l'outil de téléversement utilisent le même profil mémoire.

Aucune carte micro-SD n'est installée, mais le démarrage à froid signale un échec CMD0
-----------------------------------------------------------------------------------------

C'est normal. Le moniteur résident essaie le chemin de démarrage à froid depuis
la micro-SD avant de revenir à l'invite interactive. Sans carte installée, la
sortie peut contenir :

.. code-block:: text

   ULX3S cold boot: trying micro-SD...
   SD boot: initializing micro-SD...
   SD: CMD0 failed r1=0x000000FF
   SD boot: card initialization failed
   Type h or ? for help.
   >

Si les diagnostics SDRAM/vidéo ont réussi et que l'invite ``>`` apparaît, le
message de carte absente n'indique pas une panne du système.

La carte SD est montée mais les fichiers sont introuvables
----------------------------------------------------------

* Utilisez les noms de fichiers racine ``DOOM.H3D`` et ``DOOM.WAD``.
* Confirmez le formatage FAT16/FAT32.
* Utilisez la commande ``c`` du moniteur pour inspecter le type FAT, l'état de montage et les tailles de fichiers détectées.
* Évitez de dépendre de noms longs ; le chemin de démarrage est conçu autour de noms 8.3 à la racine.

La SD devient peu fiable lorsque le firmware ESP32 s'exécute
------------------------------------------------------------

Confirmez que les GPIO ESP32 14, 15, 2 et 13 sont en haute impédance pendant que Hazard3 possède le bus SD. Un indicateur logiciel de propriété ne suffit pas si les drivers de broches ESP32 restent activés.

L'analyse SAO trouve certains périphériques mais pas d'autres
-------------------------------------------------------------

Tous les SAO ne sont pas nécessairement des périphériques I2C. Certains peuvent utiliser les broches GPIO optionnelles ou un comportement I2C inhabituel. Utilisez ``sao info``, ``sao scan``, ``sao probe`` et la documentation propre au périphérique avant de conclure que le pont est défectueux.

``i2c gui`` est signalé comme commande inconnue
-----------------------------------------------

La carte exécute un ancien moniteur résident. Construire un nouvel ELF ne
remplace pas le firmware déjà en cours d'exécution dans Hazard3. Reconstruisez
et chargez explicitement le moniteur :

.. code-block:: bash

   ./scripts/build.sh
   ./scripts/load-firmware.sh ./build/hazard3-boot-monitor.elf

Après chargement, l'aide du moniteur doit afficher ``sao gui`` et ``i2c gui``.

L'analyse I2C GUI trouve un périphérique mais la trace logique est vide
-----------------------------------------------------------------------

Les anciennes révisions de l'interface HDMI effaçaient la trace logique à la
fin de l'analyse ``S``. Le code actuel conserve la trace de sonde de la dernière
adresse ayant répondu par ACK. Reconstruisez/rechargez le moniteur actuel si la
carte thermique se met à jour mais que la trace d'analyse reste vide. ``P`` sur
une adresse connue permet aussi de vérifier directement le renderer de trace
logique.

I2C GUI reste affiché sur HDMI après la sortie
----------------------------------------------

C'est le comportement attendu avec le logiciel actuel. Quitter restaure le
contrôle UART du moniteur et le débit SAO 100 kHz, mais ne reconstruit pas
l'image visible avant le démarrage de l'interface. Lancez Doom ou présentez une
autre image vidéo du moniteur pour remplacer la dernière image de l'analyseur.

Le chargeur du firmware console reste sur ``Loading...``
--------------------------------------------------------

Le chargeur de firmware console du navigateur ne démarre pas OpenOCD. Trois
éléments doivent fonctionner simultanément :

.. code-block:: text

   navigateur -> web-server.py -> GDB -> OpenOCD :3333 -> Hazard3

Démarrez OpenOCD dans un terminal et laissez-le en cours d'exécution :

.. code-block:: bash

   ./scripts/start-openocd.sh

Une session utilisable atteint à la fois ``Examined RISC-V core`` et
``Listening on port 3333 for gdb connections``. Dans un autre terminal,
démarrez :

.. code-block:: bash

   python3 web/web-server.py

Ouvrez ``http://127.0.0.1:8000/``. N'utilisez pas une URL ``file://`` pour
``web/index.html``. L'état **Local loader Ready** de la page web signifie que
l'assistant HTTP local est joignable ; OpenOCD doit tout de même fonctionner
séparément. Pendant un chargement batch normal, OpenOCD peut journaliser une
connexion GDB acceptée puis ``dropped 'gdb' connection`` lorsque le chargeur se
déconnecte après avoir repris le cœur.

Vérifications utiles :

.. code-block:: bash

   ss -ltnp | grep ':3333'
   curl http://127.0.0.1:8000/api/console-firmware/status

Déconnectez également le flasher FPGA web de ``US1`` avant de démarrer OpenOCD,
car les deux utilisent la même interface JTAG FT231X. L'adaptateur USB-UART J1
externe est distinct et peut rester connecté.

OpenOCD signale un délai USB ou un scan JTAG entièrement nul dans une VM
------------------------------------------------------------------------

Le passthrough USB d'une VM peut parfois produire au départ un message tel que
``LIBUSB_ERROR_TIMEOUT`` suivi de ``JTAG scan chain interrogation failed: all
zeroes``. Examinez l'état final d'OpenOCD avant de conclure que la session a
échoué. S'il signale ensuite :

.. code-block:: text

   Examined RISC-V core; found 1 harts
   Listening on port 3333 for gdb connections

alors GDB peut utiliser le serveur. Arrêtez puis redémarrez immédiatement
OpenOCD une fois pour confirmer que le scan est propre. Si OpenOCD ne trouve
jamais le TAP ECP5 ni le cœur Hazard3, vérifiez que le périphérique USB VMware
est attaché à l'invité, fermez le flasher FPGA WebUSB du navigateur et recherchez
un autre propriétaire du JTAG avant de modifier les horloges ou le RTL.

OpenOCD ne voit pas un module de débogage Hazard3 fonctionnel
-------------------------------------------------------------

* Sous Windows avec ULX3S, utilisez un build OpenOCD récent avec support ``ft232r`` et associez le FT231X embarqué à **WinUSB** ou **libusbK**. La configuration actuelle du projet a été validée avec WinUSB ; libusbK n'est pas obligatoire.
* Ne confondez pas le pilote FT231X/JTAG ``US1`` de l'ULX3S avec le pilote du port COM USB-UART externe utilisé par Web Serial.
* Réduisez la fréquence JTAG.
* Assurez-vous qu'un seul client GDB est connecté.
* Vérifiez que le bitstream FPGA est bien le build Hazard3 attendu.
* Vérifiez que l'ELF correspond au matériel/moniteur en cours d'exécution.
* Distinguez la connectivité du TAP ECP5 de la connectivité du module de débogage Hazard3.

Si le même FT231X doit aussi servir au flasher FPGA du navigateur, préférez
WinUSB afin qu'OpenOCD/GDB et WebUSB fonctionnent sans nouveau changement de
pilote. Ne restaurez le pilote FTDI VCP/D2XX que lorsqu'un outil comme
``fujprog`` sous Windows en a besoin.

Le build change soudainement à cause des sous-modules
-----------------------------------------------------

Vérifiez à la fois l'état du superprojet et des sous-modules :

.. code-block:: bash

   git status
   git submodule status --recursive
   git branch --show-current
   git -C third_party/Hazard3 branch --show-current
   git -C third_party/doomgeneric branch --show-current

Un superprojet propre ne signifie pas qu'un sous-module se trouve sur la branche ou le commit que vous attendiez.
