Interface HDMI I2CDriver
========================

Hazard3-Doom comprend une interface interactive de diagnostic I2C inspirée de
`I2CDriver <https://github.com/jamesbowman/i2cdriver>`_ de James Bowman. Le
firmware I2CDriver original est écrit en MyForth. Hazard3-Doom réutilise le
contrôleur I2C SAO FPGA déjà présent dans le projet pour les transactions de bus
et affiche une interface de type I2CDriver via le chemin HDMI indexé 320x200
existant.

La fonctionnalité est principalement implémentée par :

.. code-block:: text

   src/i2cdriver_hdmi.c
   src/i2cdriver_hdmi.h
   src/sao_console.c

Le moniteur résident doit être reconstruit et rechargé après modification de ces
fichiers. Aucune nouvelle synthèse FPGA n'est nécessaire pour des changements
logiciels uniquement de l'interface HDMI I2CDriver tant que le bitstream en
cours fournit déjà le pont SAO compatible et l'interface HDMI indexée directe.

Démarrer l'interface
--------------------

Revenez d'abord au moniteur résident. Si Doom est en cours d'exécution, appuyez
sur ``Ctrl-X``. Entrez ensuite l'une des commandes :

.. code-block:: text

   i2c gui

ou :

.. code-block:: text

   sao gui

Un lancement réussi affiche :

.. code-block:: text

   Starting I2CDriver HDMI...
   I2CDriver HDMI active. S scan, P probe, R read, W write, X recover, 1/4 speed, C clear, Q exit.

L'affichage HDMI passe à l'écran Hazard3 I2CDriver. Tant que l'interface est
active, les frappes UART contrôlent l'application HDMI plutôt que l'invite de
commande normale du moniteur.

Commandes
---------

.. list-table::
   :header-rows: 1
   :widths: 10 22 68

   * - Touche
     - Opération
     - Description
   * - ``S``
     - Analyse
     - Sonde les adresses I2C 7 bits normales ``0x08`` à ``0x77``. Les adresses qui répondent sont mises en évidence dans la carte d'adresses. L'implémentation actuelle conserve la trace logique de la dernière adresse ayant acquitté.
   * - ``P``
     - Sonde
     - Demande une adresse hexadécimale 7 bits et teste si elle répond par ACK.
   * - ``R``
     - Lecture de registre
     - Demande une adresse de périphérique et un registre 8 bits, puis effectue une lecture d'un octet avec START répété.
   * - ``W``
     - Écriture de registre
     - Demande une adresse de périphérique, un registre 8 bits et un octet de données, puis écrit ce registre.
   * - ``X``
     - Récupération
     - Lance l'opération de récupération du bus du pont SAO FPGA. Utilisez-la lorsque SDA/SCL ou une cible semble bloquée.
   * - ``1``
     - 100 kHz
     - Sélectionne le débit I2C normal de 100 kHz.
   * - ``4``
     - 400 kHz
     - Sélectionne le mode rapide. Avec une horloge système Hazard3 à 50 MHz, le diviseur entier produit environ 403 kHz.
   * - ``C``
     - Effacer
     - Efface la carte thermique, l'historique des transactions et la trace logique. Cela ne réinitialise pas un périphérique I2C connecté.
   * - ``Q``
     - Quitter
     - Rend le contrôle UART au moniteur résident et restaure le bus SAO à 100 kHz.
   * - ``Ctrl-X``
     - Quitter
     - Touche de sortie alternative lorsque l'interface graphique est active.
   * - ``Esc``
     - Annuler/quitter
     - Annule une invite d'opérande. Lorsqu'aucune invite n'est active, ``Esc`` quitte l'interface graphique.

Invites hexadécimales
---------------------

``P``, ``R`` et ``W`` collectent directement les opérandes hexadécimaux dans
l'interface HDMI. Ne saisissez pas de préfixe ``0x``.

Sonder l'adresse ``0x54`` :

.. code-block:: text

   P
   54
   Enter

Lire le registre ``0x00`` du périphérique ``0x54`` :

.. code-block:: text

   R
   5400
   Enter

Écrire la valeur ``0x80`` dans le registre ``0x04`` du périphérique ``0x54`` :

.. code-block:: text

   W
   540480
   Enter

Pendant la saisie des opérandes, Backspace/Delete modifie l'entrée, Enter
exécute une commande complète et Esc l'annule.

.. warning::

   ``W`` modifie l'état du périphérique connecté. Consultez la documentation des
   registres de la cible avant toute écriture. Les lectures peuvent également
   avoir des effets de bord sur les périphériques possédant des registres
   read-to-clear ou de type FIFO.

Carte thermique des adresses
----------------------------

La carte thermique couvre visuellement tout l'espace d'adressage 7 bits, mais
la plage d'analyse normale va de ``0x08`` à ``0x77``. Les adresses hors de cette
plage sont réservées ou inadaptées à l'opération d'analyse ordinaire.

Une adresse qui répond par ACK reçoit une chaleur maximale puis s'atténue
progressivement. Les périphériques récemment actifs restent ainsi visibles sans
marquer définitivement les réponses anciennes.

Un périphérique hors de la plage d'analyse peut toujours être testé
explicitement lorsque l'API de sonde SAO sous-jacente le permet. Ne supposez pas
qu'un périphérique à une adresse réservée apparaîtra dans les résultats de ``S``.

Journal des transactions
------------------------

Le journal des transactions à droite enregistre les opérations récentes de
l'interface, notamment sonde, lecture, écriture, récupération, analyse et
changements de vitesse. Ce journal est un état de diagnostic local ; ``C``
l'efface sans modifier le périphérique connecté.

Trace logique
-------------

Le panneau HDMI inférieur affiche SDA et SCL sous forme de **trace logique de
transaction**. Cette trace est synthétisée à partir des transactions initiées
par Hazard3 via le pont SAO. Elle est utile pour visualiser la structure du
protocole, par exemple :

.. code-block:: text

   START
   address + WRITE     ACK
   register            ACK
   repeated START
   address + READ      ACK
   data                master NACK
   STOP

Pour l'analyse ``S``, l'implémentation actuelle conserve la trace de sonde de la
dernière adresse ayant répondu par ACK. Si un périphérique répond à ``0x54``, la
trace conservée représente START, l'octet d'adresse ``0xA8`` avec ACK, puis STOP.

La trace **n'est pas une capture électrique des fronts SDA/SCL**. L'API SAO de
haut niveau indique également un résultat global de transaction plutôt que la
phase d'octet exacte ayant généré un NACK ; une trace logique multi-octets en
échec ne permet donc pas toujours d'identifier précisément la position de l'ACK
manquant.

État de la capture passive
--------------------------

L'I2CDriver original possède une implémentation de capture passive sensible au
timing dans ``firmware/capture.fs``. Hazard3-Doom n'implémente actuellement pas
le sniffer passif correspondant en logiciel.

Un véritable analyseur passif devrait être implémenté en logique FPGA, en
échantillonnant SDA et SCL indépendamment du CPU Hazard3 et en plaçant les
événements/timestamps décodés dans une FIFO. L'interface HDMI en C pourrait
ensuite afficher ces données capturées. Tant qu'une telle FIFO n'existe pas, le
pied de page décrit volontairement l'affichage comme du trafic initié plutôt
que comme une capture passive.

Récupération du bus
-------------------

``X`` appelle l'opération de récupération existante du pont SAO plutôt que de
bit-banger manuellement SDA/SCL depuis le C. Le timing électrique et la propriété
restent ainsi dans le contrôleur de bus FPGA.

Utilisez la récupération lorsqu'un périphérique a été interrompu au milieu
d'une transaction, que SDA reste à l'état bas ou que le bus ne répond plus après
un branchement à chaud. Un bus sain ne nécessite normalement pas de récupération.

Présentation HDMI
-----------------

L'interface effectue le rendu d'une image indexée 320x200 et la téléverse vers
le framebuffer EBR interne inactif via le chemin direct des registres HDMI. Le
logiciel choisit la banque opposée au framebuffer interne actif puis demande
une permutation pendant le blanking vertical. C'est le même concept de double
buffering que celui utilisé par le chemin de présentation rapide de Doom.

Quitter l'interface graphique ne reconstruit pas l'image visible avant son
entrée. La dernière image de l'analyseur peut rester sur HDMI jusqu'à ce que
Doom ou une autre opération vidéo du moniteur présente une nouvelle image.
L'invite UART du moniteur est l'indication faisant autorité que l'interface est
bien terminée.

Capture d'écran Web Serial
--------------------------

La console Web Serial du navigateur peut capturer l'écran HDMI I2CDriver actuel
lorsque l'interface graphique en cours implémente la négociation de capacité de
capture. L'interface intercepte les octets de contrôle réservés avant le
traitement normal des touches/invites ; une requête d'écran n'est donc pas
interprétée comme une commande I2C.

Les modes de source de capture actuels peuvent être sérialisés en ``320x200`` ou
``400x240``. Chaque pixel ``H3SNIP1`` est un index de palette 8 bits. Les 16
entrées de palette de l'interface sont transmises en premier et les entrées
restantes valent zéro.

Voir :doc:`web-serial` pour la requête de capacité ``0x1c``, l'ACK ``0x06``, la
requête de capture ``0x1d``, les tailles de charge utile, le format RGB332, le
comportement de timeout et la reconstruction PNG.

Workflow de build et de test
----------------------------

Pour des modifications logicielles uniquement de l'implémentation HDMI I2CDriver :

.. code-block:: bash

   ./scripts/build.sh
   ./scripts/load-firmware.sh ./build/hazard3-boot-monitor.elf

Avant de tester l'interface graphique, confirmez le chemin SAO normal :

.. code-block:: text

   sao info
   sao scan
   i2c gui

Une séquence de validation utile dans l'interface est :

.. code-block:: text

   S
   P 54 Enter
   4
   S
   1
   Q

Remplacez ``54`` par un périphérique connu sur le bus SAO connecté.

Si ``i2c gui`` est signalé comme commande inconnue, la carte exécute un ancien
moniteur résident même si un ELF plus récent existe sur disque. Reconstruisez et
chargez ``build/hazard3-boot-monitor.elf`` avant de dépanner l'interface elle-même.

Relation avec I2CDriver amont
-----------------------------

Cette fonctionnalité porte le modèle d'interaction utile plutôt que de traduire
chaque fonction matérielle spécifique de la carte originale. La version
Hazard3-Doom couvre actuellement l'analyse maître active, la sonde, les lectures
et écritures de registre d'un octet, la chaleur d'activité, l'historique des
transactions, les traces logiques, la récupération du bus et la sélection
100/400 kHz.

Les mesures analogiques propres à la carte I2CDriver originale, le matériel de
résistances pull-up commutables, le protocole binaire hôte et la véritable
capture passive ne sont pas fournis implicitement par cette interface C.

I2CDriver est distribué sous licence BSD 3-Clause. Conservez les éléments
d'attribution/licence tiers du projet lors de la copie ou de la redistribution
de code qui en dérive.
