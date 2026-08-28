Dépannage
=========


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

Le téléversement de Doom expire
-------------------------------

* Quittez Doom avec ``Ctrl-X`` afin que le moniteur résident soit à l'écoute.
* Fermez PuTTY ou tout autre programme qui possède le port UART.
* Confirmez le périphérique COM/TTY sélectionné.
* Confirmez que le moniteur et l'outil de téléversement utilisent le même profil mémoire.

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
