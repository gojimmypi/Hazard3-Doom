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
   :class: screenshot

   Exemple de sélection WinUSB pour le FT231X ULX3S.

Voir :doc:`user-guide/web-flasher` pour le flux complet de programmation WebUSB
et les remarques concernant la restauration du pilote.


Zadig signale ``Driver Installation: FAILED (Could not allocate resource)``
----------------------------------------------------------------------------

Si Zadig échoue lors du remplacement du pilote FTDI ULX3S avec un message tel
que ``Driver Installation: FAILED (Could not allocate resource)``, recherchez un
processus auxiliaire libwdi/Zadig resté bloqué avant de supprimer des pilotes ou
de modifier la configuration du périphérique.

Fermer Zadig ne termine pas nécessairement son auxiliaire. Lors d'un échec
confirmé, ``zadig.exe`` n'était plus en cours d'exécution mais
``installer_x64.exe`` restait bloqué en arrière-plan et empêchait l'installation
du pilote suivant.

Dans PowerShell, recherchez les processus d'installation/auxiliaires concernés :

.. code-block:: powershell

   Get-Process installer_x64*, wdi*, dpinst*, pnputil* -ErrorAction SilentlyContinue |
       Select-Object Id, ProcessName, Path

Si un ancien ``installer_x64.exe`` est présent et qu'aucune installation de
pilote n'est volontairement en cours, arrêtez-le :

.. code-block:: powershell

   Stop-Process -Name installer_x64 -Force

Puis confirmez qu'il a disparu :

.. code-block:: powershell

   Get-Process installer_x64* -ErrorAction SilentlyContinue

Si un ancien ``pnputil.exe`` provenant d'une opération abandonnée
d'installation/suppression de périphérique est également encore actif,
arrêtez-le avant de réessayer.

Après avoir supprimé l'auxiliaire bloqué :

#. Fermez Zadig.
#. Débranchez la connexion USB de l'ULX3S.
#. Attendez quelques secondes puis reconnectez-la.
#. Démarrez Zadig en tant qu'administrateur.
#. Activez **Options -> List All Devices**.
#. Sélectionnez l'interface FTDI ULX3S voulue et vérifiez l'ID USB ``0403:6015``.
#. Réessayez l'installation du pilote WinUSB/libusb.

Ne désinstallez pas d'autres périphériques FTDI en première intention. Un
``installer_x64.exe`` résiduel peut provoquer cette erreur même lorsque Zadig,
OpenOCD, ``fujprog`` et les autres outils USB visibles ne sont plus en cours
d'exécution.

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

.. _fig-chrome-pending-update:

.. figure:: images/chrome-pending-update.png
   :alt: Chrome affichant un bouton Finish update alors que la console UART Hazard3-Doom est déconnectée.
   :class: screenshot

   Si le sélecteur Web Serial est vide alors que Chrome affiche une mise à jour
   en attente, terminez la mise à jour et relancez le navigateur avant de
   modifier les pilotes série.


Le sélecteur Web Serial se ferme mais l'UART ne se connecte pas
----------------------------------------------------------------

Si un périphérique série est sélectionné et que le sélecteur du navigateur se
ferme mais que l'outil reste déconnecté, vérifiez d'abord si le port appartient
déjà à une autre application.

L'outil actuel coordonne les onglets d'une même origine avec un Web Lock du
navigateur et ``BroadcastChannel``. Si une autre copie de la même page possède
déjà l'UART, la seconde indique **UART already in use**. Une page d'une autre
origine, PuTTY, un terminal d'IDE ou une autre application ne peut pas être
identifié par son nom ; un échec de ``SerialPort.open()`` est donc signalé comme
un probable conflit de propriété.

Récupération typique :

#. Fermez ou déconnectez l'autre onglet de l'outil ou l'application série.
#. Revenez à la section de connexion H3IMG/IWAD ou Serial.
#. Utilisez **Retry UART** ou **Connect UART** et sélectionnez de nouveau le port.

N'oubliez pas que ``http://127.0.0.1:8000`` et la page publique
``https://ulx3s.github.io`` sont deux origines différentes pour le navigateur.
Leurs Web Locks ne se coordonnent pas, même si le système d'exploitation empêche
toujours les deux pages de posséder simultanément le même port série.

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


WebUSB ne peut pas ouvrir ou revendiquer l'ULX3S
------------------------------------------------

Sous Linux, l'outil Hazard3-Doom peut détecter l'ULX3S tout en échouant à
l'ouvrir.

Deux erreurs sont courantes :

``Access denied``
   Le navigateur ne dispose pas des droits de lecture/écriture sur le
   périphérique USB brut.

``Unable to claim interface``
   Le pilote Linux ``ftdi_sio`` possède déjà l'interface USB FT231X.

Consultez :doc:`user-guide/web-flasher` pour la configuration des permissions
udev sous Linux et la procédure permettant de libérer temporairement
l'interface ULX3S de ``ftdi_sio``.

Dans une machine virtuelle, vérifiez également que le périphérique USB ULX3S est
connecté au système invité et non à l'hôte.

Le téléversement de Doom expire
-------------------------------

* Quittez Doom avec ``Ctrl-X`` afin que le moniteur résident soit à l'écoute.
* Fermez PuTTY ou tout autre programme qui possède le port UART.
* Confirmez le périphérique COM/TTY sélectionné.
* Confirmez que le moniteur et l'outil de téléversement utilisent le même profil mémoire.
* Sur le profil ULX4M-LD qualifié par défaut, l'horloge système Hazard3 est de
  40 MHz et l'UART doit
  néanmoins fonctionner à 115200 bauds. Si une image programmée expire à 115200
  mais répond près de 92160 bauds, cela indique fortement un diviseur UART du
  moniteur calculé avec une hypothèse de 50 MHz alors que le FPGA fonctionne à
  40 MHz (``115200 * 40 / 50 = 92160``). Reconstruisez la cible complète avec
  ``./scripts/build-ulx4m-ld-doom.sh``, reprogrammez le bitstream et retestez à
  115200 ; 92160 n'est qu'un débit de diagnostic.
* Certains ponts série WSL ``/dev/ttyS*`` refusent un débit non standard comme
  92160 avec ``termios.error: (5, 'Input/output error')``. Si ce test est
  nécessaire, utilisez Python Windows avec le port COM correspondant, par
  exemple depuis WSL :

  .. code-block:: bash

     cmd.exe /c "python.exe doom/upload-doom-image.py build/ulx4m-ld/doom-image/hazard3-doom.h3img --port COM8 --baud 92160"
* Si la cible atteint ``H3L READY`` puis signale ``H3L ERROR invalid header``,
  le handshake UART fonctionne. Vérifiez que le moniteur résident et le fichier
  ``.h3img`` proviennent d'un build/profil compatible avant de modifier les
  pilotes série ou le câblage.

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

* Utilisez les noms de fichiers racine ``DOOM.IMG`` et ``DOOM.WAD``.
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


``shellcheck`` n'est pas installé
---------------------------------

ShellCheck est un outil de développement facultatif utilisé pour valider les
scripts shell du dépôt. Il n'est pas nécessaire pour les builds Hazard3-Doom
normaux. Sous Ubuntu/WSL, les développeurs qui souhaitent exécuter la validation
des scripts shell peuvent l'installer avec :

.. code-block:: bash

   sudo apt-get install shellcheck

Pour un contrôle plus général de l'hôte, exécutez
``./scripts/requirements-check.sh``.

La chaîne d'outils GCC RISC-V est introuvable
---------------------------------------------

Le build utilise normalement un compilateur RISC-V bare-metal compatible
disponible dans ``PATH``. Les outils ``riscv-none-elf-*`` sont pris en charge
directement, tandis que ``TOOLCHAIN_PREFIX`` peut sélectionner une autre
installation ou un autre préfixe de compilateur. L'emplacement historique
``/opt/riscv/bin/riscv32-unknown-elf-*`` reste pris en charge uniquement comme
solution de compatibilité. Par exemple, une installation xPack utilise
couramment :

.. code-block:: bash

   TOOLCHAIN_PREFIX=riscv-none-elf- ./scripts/build.sh

Exécutez ``./scripts/requirements-check.sh`` pour détecter les préfixes courants
de chaînes d'outils RISC-V et vérifier que le compilateur accepte les options
ISA/ABI de Hazard3.

``c++: fatal error: Killed signal terminated program cc1plus``
--------------------------------------------------------------

Cela signifie presque toujours que la VM Ubuntu a manqué de RAM disponible et
que l'OOM killer du noyau a arrêté l'un des processus du compilateur C++. Ce
n'est pas une erreur de compilation C++. Augmentez la mémoire ou le swap de la
VM, ou réduisez le parallélisme du build avant de réessayer.

Le workflow indique que CMake est trop ancien
---------------------------------------------

Le vérificateur des prérequis de la machine traite CMake comme un outil de
développement facultatif. Si un workflow particulier exige une version plus
récente, installez ou mettez à niveau CMake vers la version demandée par ce
workflow, puis vérifiez avec ``cmake --version``.

Consultez le script ``install-cmake.sh`` du répertoire ``scripts/`` pour
installer CMake 3.25 ou une version ultérieure.

``ROR: Max frequency for clock '$glbnet$clk_sys': XX.YY MHz (FAIL at 50 MHz)``
------------------------------------------------------------------------------

Si la fréquence routée est inférieure à la cible avec les seeds par défaut,
confirmez d'abord que Yosys et nextpnr correspondent aux versions enregistrées
avec les paramètres de routage de référence dans
``scripts/build-ecp5-bitstream-common.sh``. Les seeds de routage dépendent de la
version des outils.

Consignez les versions locales avec :

.. code-block:: text

   yosys --version
   nextpnr-ecp5 --version
   ecppack --version

Le chargeur du firmware console reste sur ``Loading...``
--------------------------------------------------------

Le chargeur console ne démarre pas OpenOCD. Trois éléments coopèrent :

.. code-block:: text

   page navigateur -> web-server.py loopback -> GDB -> OpenOCD :3333 -> Hazard3

La page peut être la copie publique GitHub Pages ou la page locale servie par
``web-server.py``. GDB et OpenOCD restent toujours locaux.

Démarrez OpenOCD dans un terminal :

.. code-block:: bash

   ./scripts/start-openocd.sh

Une session utilisable atteint ``Examined RISC-V core`` et ``Listening on port
3333 for gdb connections``. Dans un autre terminal :

.. code-block:: bash

   python3 web/web-server.py

Le helper avertit au démarrage si aucun listener n'est détecté sur
``127.0.0.1:3333``. Ce n'est qu'un avertissement, car OpenOCD peut être lancé
plus tard.

Continuez ensuite avec ``https://ulx3s.github.io/Hazard3-Doom/`` ou ouvrez
``http://127.0.0.1:8000/``. N'utilisez pas ``file://`` pour l'outil complet.
Le panneau affiche séparément **Local loader** et **OpenOCD** ; **refresh** force
une vérification immédiate.

Les requêtes d'état contiennent une valeur ``challenge`` changeante pour éviter
qu'une réponse ``Ready`` mise en cache survive à l'arrêt du helper. La détection
OpenOCD est passive : elle inspecte les ports locaux en écoute au lieu d'ouvrir
une connexion TCP sur ``3333``.

Si OpenOCD affiche toutes les quelques secondes des connexions GDB acceptées ou
rejetées alors qu'aucun ELF n'est chargé, un ancien ``web-server.py`` utilisant
une sonde TCP active est probablement encore lancé. Arrêtez-le et lancez le
helper actuel.

Pendant un vrai chargement, une connexion GDB acceptée puis fermée à la fin est
normale.

Vérifications utiles :

.. code-block:: bash

   ss -ltnp | grep ':3333'
   curl http://127.0.0.1:8000/api/console-firmware/status

Déconnectez aussi le flasher FPGA WebUSB de ``US1`` avant OpenOCD, car ils
utilisent le même FT231X JTAG. L'adaptateur J1 USB-UART externe est indépendant
et peut rester connecté.

Si H3IMG/H3W expire ensuite en attendant ``READY``, vérifiez d'abord que le
moniteur résident est réellement à l'invite ``>``. Lorsque le helper répond
mais qu'OpenOCD est absent, le Device Tool rappelle également que le moniteur
doit peut-être encore être chargé.


Vous pouvez ensuite continuer avec :

.. code-block:: text

   https://ulx3s.github.io/Hazard3-Doom/

ou ouvrir la copie locale à ``http://127.0.0.1:8000/``. N'utilisez pas une URL
``file://`` pour l'outil complet.

Une vérification de santé correcte est passive et ne doit donc **pas** créer en
boucle des messages OpenOCD tels que :

.. code-block:: text

   accepting 'gdb' connection on tcp/3333
   attempted 'gdb' connection rejected

Points de contrôle JTAG utiles :

* Sur ULX4M-LD avec Tigard, gardez l'interface 0 sur le pilote FTDI VCP pour l'UART et l'interface 1 sur libusbK pour JTAG. OpenOCD utilise ``ftdi channel 1``.
* Sur ULX4M-LD, l'IDCODE LFE5UM-85F correct est ``0x01113043``. Si OpenOCD lit cet IDCODE mais indique ``dtmcontrol is 0``, le chemin JTAG physique fonctionne ; vérifiez que le bitstream utilisateur a quitté DFU et s'exécute réellement avant de modifier le RTL DTM ou le câblage.

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


ULX4M-LD signale un ``TIMEOUT`` de mémoire externe
--------------------------------------------------

L'attente initiale de 5 secondes du moniteur actuel peut expirer avant la fin de
la calibration LiteDRAM. Ne considérez pas la bannière ``TIMEOUT`` comme un
échec définitif à elle seule. Exécutez ``s`` et vérifiez l'état courant. Un état
DDR utilisable comprend :

.. code-block:: text

   external_memory_ready=YES
   init_done=YES
   init_error=NO
   pll_locked=YES
   user_clock_ready=YES
   ready=YES

Si ces champs sont prêts, exécutez ``q``. Le routage ULX4M-LD qualifié 40/60 MHz
a réussi à plusieurs reprises la suite SDRAM complète ainsi que ``k``, ``d`` et
``x``.

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

Liens associés
--------------

* `RISC-V GCC XPACK <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_
