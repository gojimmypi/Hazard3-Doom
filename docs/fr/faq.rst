Foire aux questions
===================

Carte ULX3S non reconnue
------------------------

Vérifiez que le câble USB-A vers Micro-USB est connecté à `US`, le connecteur situé du même côté de la carte que la carte SD.

Utilisez des câbles courts et de bonne qualité. Il ne doit pas s'agir d'un câble « charge uniquement ».

Essayez une connexion directe, sans hub.

Écran HDMI vide
---------------

Si l'écran est resté alimenté sans signal HDMI actif pendant un certain temps, il peut ne pas se réveiller au premier signal vidéo. Essayez de couper l'alimentation et d'attendre quelques secondes avant de réessayer. Ce comportement a été observé avec l'écran HDMI Elecrow 7 pouces.

Commande "monitor" non prise en charge par cette cible.
-------------------------------------------------------

Voir la section suivante : vous ne pouvez pas faire cela lorsque votre cible est ``exec``.

Vous ne pouvez pas faire cela lorsque votre cible est ``exec``
--------------------------------------------------------------

Si vous voyez une erreur semblable à celle-ci lors du chargement du firmware Console Monitor avec gdb, vérifiez qu'OpenOCD est en cours d'exécution et écoute sur le port attendu (par défaut : 3333).

$ ./scripts/load-firmware-12f.sh
Calling /mnt/c/workspace/Hazard3-Doom/scripts/load-firmware.sh \
-rwxr-xr-x 1 gojimmypi gojimmypi 316036 Aug 25 12:10 hazard3-boot-monitor.elf
localhost:3333: Connection timed out.
"monitor" command not supported by this target.
You can't do that when your target is ``exec``
Section .vectors, range 0x20000040 -- 0x20000076: matched.
Section .text, range 0x20000078 -- 0x2000bacb: matched.
Section .srodata.bar_colors.1, range 0x2000bacc -- 0x2000bad4: matched.
Section .data, range 0x2000bad4 -- 0x2000badc: matched.
No registers.

You can't do that when your target is ``exec``


Web Serial ne signale aucun périphérique compatible, mais Windows voit mon port COM. Que dois-je essayer en premier ?
---------------------------------------------------------------------------------------------------------------------

Si Chrome indique qu'une mise à jour du navigateur est en attente, terminez la
mise à jour et relancez complètement Chrome avant de modifier les pilotes série
USB ou la console web Hazard3-Doom.

Voir l'indicateur de mise à jour du navigateur ci-dessous :

.. image:: images/chrome-pending-update.png
   :alt: Indicateur de mise à jour Chrome en attente
   :align: center

Pendant les tests de Hazard3-Doom sous Windows, le journal interne des
périphériques de Chrome signalait toujours l'adaptateur CH340 comme ``COM7``,
mais le sélecteur Web Serial affichait ``No compatible devices found``. Après
avoir terminé la mise à jour Chrome en attente et relancé Chrome, le sélecteur
de port série a recommencé à fonctionner.

La console web Hazard3-Doom demande volontairement un sélecteur de port série
sans filtre ; elle n'est donc pas limitée à CH340, FTDI, CP210x ou à un autre
adaptateur série USB particulier.

Rappelez-vous également que ``navigator.serial.getPorts()`` renvoie les ports
que l'origine actuelle du navigateur a déjà été autorisée à utiliser. Ce n'est
pas la liste de tous les ports COM installés sous Windows.

Si le redémarrage du navigateur mis à jour ne restaure pas le port, continuez
avec :ref:`web-serial-no-compatible-devices`. En particulier, si Chrome a
journalisé la suppression du port COM pendant une session de débogage,
débranchez/rebranchez physiquement l'adaptateur USB-UART externe. Arrêter
OpenOCD seul peut ne pas déclencher la ré-énumération du périphérique série par
Windows / Chrome nécessaire pour rendre le port à nouveau sélectionnable.

OpenOCD peut-il utiliser WinUSB sur l'ULX3S ?
---------------------------------------------

Oui, avec la configuration ULX3S Hazard3-Doom actuelle. Le chemin OpenOCD du
projet utilise l'adaptateur ``ft232r`` via libusb et a été validé avec le FT231X
embarqué associé à WinUSB. libusbK fonctionne également avec OpenOCD, mais
n'est plus un choix de pilote obligatoire. GDB se connecte à OpenOCD par TCP et
fonctionne donc via toute association FT231X qu'OpenOCD parvient à utiliser.

WinUSB est particulièrement pratique car il satisfait aussi le flasher
FPGA/JTAG WebUSB du navigateur. Le pilote FTDI VCP/D2XX normal reste nécessaire
aux applications natives FTDI telles que ``fujprog`` sous Windows. Voir
:doc:`user-guide/web-flasher` pour la matrice de compatibilité.

Pourquoi le flasher FPGA WebUSB a-t-il besoin de WinUSB sous Windows ?
----------------------------------------------------------------------

Le FT231X ``US1`` de l'ULX3S utilise normalement un pilote FTDI Windows.
Chrome/Edge WebUSB ne peut pas ouvrir cette interface via l'association FTDI
VCP/D2XX normale ; le programmateur du navigateur nécessite donc WinUSB pour un
accès USB direct. Cela n'affecte que le chemin WebUSB/JTAG ; un adaptateur
USB-UART séparé peut continuer à desservir la console Web Serial Hazard3-Doom.

Voir :doc:`user-guide/web-flasher` pour les instructions de configuration et de
restauration du pilote, ou :ref:`webusb-access-denied` si le navigateur signale
``Access denied``.
