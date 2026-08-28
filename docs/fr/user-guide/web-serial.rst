Console Web Serial et capture d'écran HDMI
==========================================

Hazard3-Doom comprend une console de navigateur sans dépendance dans le
répertoire ``web/``. Elle utilise l'API Web Serial du navigateur pour
communiquer directement avec l'UART de la carte et peut également demander une
capture d'écran aux applications HDMI prises en charge.

La même application web contient aussi un programmateur FPGA WebUSB distinct
pour l'interface JTAG FT231X ``US1`` de l'ULX3S. Web Serial et WebUSB sont des
transports indépendants : la console UART reste sur son adaptateur série tandis
que le programmateur FPGA communique avec le JTAG. Voir :doc:`web-flasher`.

Le chemin de capture d'écran ne capture pas le TMDS, ne relit pas les pixels
depuis le connecteur HDMI physique et ne nécessite aucun serveur. L'application
firmware active envoie l'image source indexée et sa palette via UART. JavaScript
reconstruit localement le raster HDMI actif complet et le télécharge en PNG.

Fichiers de l'application web
-----------------------------

L'application du navigateur est implémentée par :

.. code-block:: text

   web/index.html
   web/app.js
   web/styles.css

``index.html`` contient les contrôles, ``app.js`` gère le transport Web Serial
et le protocole de capture d'écran, et ``styles.css`` fournit le style de
l'interface.

La page est statique. Il n'y a ni gestionnaire de paquets JavaScript, ni
framework, ni backend, ni service cloud dans le chemin de capture d'écran.

Prérequis du navigateur et du serveur
-------------------------------------

Web Serial nécessite un navigateur exposant ``navigator.serial`` et un contexte
sécurisé. ``localhost`` est accepté pour le développement local, et HTTPS
convient à l'hébergement comme GitHub Pages.

Un serveur local simple peut être lancé depuis le répertoire ``web/`` avec :

.. code-block:: bash

   python3 -m http.server 8000

Ouvrez ensuite ``http://localhost:8000/`` dans un navigateur compatible Web Serial.

Les réglages UART normaux de Hazard3-Doom sont :

.. code-block:: text

   115200 baud
   8 data bits
   no parity
   1 stop bit
   no flow control

La console web expose ces réglages série dans l'interface et conserve les
préférences utilisateur dans le ``localStorage`` du navigateur.

Vue d'ensemble de la capture d'écran
------------------------------------

Le contrôle **Screen snip** télécharge l'application HDMI prise en charge
actuelle sous forme de PNG ``1024x600`` complet. L'implémentation est répartie
en trois couches :

#. Le navigateur sonde le consommateur UART actif pour déterminer s'il prend en charge la capture d'écran.
#. Le moniteur résident (lorsque son image de test mise en cache est valide), Doom ou l'interface HDMI I2CDriver sérialise son image source indexée et sa palette RGB332 sur UART.
#. Le navigateur retire le transfert binaire du flux terminal, étend la source indexée à la taille d'affichage annoncée, encode un PNG avec l'API Canvas et lance un téléchargement local.

Le moniteur résident actuel peut également fournir une capture d'écran. Après
avoir présenté avec succès sa mire de test, il stocke une copie validée de cette
image RGB332 dans la SDRAM réservée et peut sérialiser ce cache sur demande.
Doom et l'interface HDMI I2CDriver fournissent leurs propres implémentations
d'écran actif. Une image ``.h3d`` chargée mais non exécutée ne fournit pas la
capacité simplement parce qu'elle est présente en SDRAM.

Détection de capacité
---------------------

La simple connexion d'un port série ne suffit pas pour activer la capture
d'écran. Le navigateur utilise une petite négociation de capacité afin que le
bouton reflète le mode firmware qui consomme actuellement l'entrée UART.

Les octets réservés sont :

.. list-table::
   :header-rows: 1
   :widths: 18 24 58

   * - Octet
     - Nom
     - Signification
   * - ``0x1c``
     - Requête de capacité
     - Envoyée par le navigateur pour demander si l'écran firmware actif prend en charge le protocole de capture d'écran.
   * - ``0x06``
     - ACK de capacité
     - Renvoyé par le moniteur actuel lorsque son image mise en cache est valide, ou par une implémentation Doom/I2CDriver HDMI prise en charge. Le navigateur consomme cet octet et ne l'affiche pas dans le terminal.
   * - ``0x1d``
     - Requête de capture
     - Envoyée uniquement après confirmation de la capacité. Le fournisseur d'écran actif répond avec une image ``H3SNIP1``.

Une sonde de capacité individuelle attend jusqu'à 750 ms un ACK. Autour des
transitions d'exécution, comme le lancement de Doom, l'application web conserve
une fenêtre de réacquisition plus longue et réessaie pendant l'initialisation du
nouveau consommateur UART. Une sonde trop précoce pendant le démarrage de Doom
ne laisse donc pas définitivement le bouton désactivé. Une requête de capture
n'est envoyée qu'après confirmation de la capacité.

L'état de capture d'écran se reflète à la fois dans l'activation du bouton et
dans son texte au survol :

.. list-table::
   :header-rows: 1
   :widths: 25 25 50

   * - État
     - Bouton
     - Signification au survol/état
   * - Pas de connexion série
     - Désactivé
     - Connectez d'abord la carte.
   * - Vérification
     - Désactivé
     - Une requête de capacité est en cours.
   * - Non pris en charge / aucune capture valide
     - Désactivé
     - Le consommateur UART actuel n'a pas signalé de source de capture valide.
   * - Écran moniteur/Doom/I2C pris en charge
     - Activé
     - La source HDMI signalée peut être téléchargée en PNG ``1024x600``.
   * - Capture en cours
     - Désactivé, libellé ``Capturing...``
     - Un transfert binaire d'écran est en cours de réception.

Le HTML place le bouton désactivé dans un élément séparé qui reste survolable.
Les boutons HTML désactivés ne reçoivent pas toujours correctement les événements
de pointeur ; le wrapper porte donc le texte ``title`` et reste survolable même
lorsque le bouton ne peut pas être cliqué.

Quand la capacité est revérifiée
--------------------------------

Le navigateur sonde la capacité lors de l'ouverture d'une connexion série. Il
programme aussi une nouvelle sonde après les commandes qui peuvent changer le
firmware possédant l'UART :

.. code-block:: text

   i2c gui
   sao gui
   j
   b

Les commandes de lancement à un seul caractère utilisent un délai plus long que
les commandes d'interface graphique afin de laisser à la nouvelle application
le temps de prendre le contrôle avant l'arrivée de la sonde.

Si la capture est actuellement indisponible, déplacer le pointeur sur le
contrôle Screen snip lance une nouvelle sonde. L'interface peut ainsi récupérer
automatiquement si le mode firmware a changé par un chemin que le navigateur
n'a pas observé.

Le contrôle **Stop Doom** ``Ctrl-X`` et le contrôle ``Q`` de l'interface I2C
déclenchent la réacquisition de capacité car ces opérations rendent la propriété
de l'UART au moniteur résident. Le moniteur peut répondre par ACK si son image
mise en cache reste valide. Un clic sur **Screen snip** effectue également une
vérification finale de capacité avant d'envoyer ``0x1d``. Cela protège contre
un état d'interface obsolète si le firmware actif a changé depuis la dernière
sonde réussie.

Routage des commandes UART et touche ``H``
------------------------------------------

Le moniteur résident traite la requête de capacité réservée ``0x1c`` et la
requête de capture ``0x1d`` avant l'analyse normale des commandes de la console.
Les touches imprimables normales restent inchangées ; en particulier, le
moniteur conserve ``H`` comme touche d'aide::

   case 'h':
   case 'H':
   case '?':
       console_print_help();
       break;

Lorsque ``i2c gui`` est actif, ``hazard3_sao_console_feed(received)`` reçoit
l'octet UART avant le switch du moniteur résident et consomme les touches de
l'interface telles que ``H``. Le helper privé ``toggle_resolution()`` de
l'interface I2C est ``static`` dans ``src/i2cdriver_hdmi.c`` et ne doit pas être
appelé depuis ``src/main.c``. Cela créerait une référence de linker indéfinie ;
renvoyer une valeur depuis ``console_poll()``, qui retourne ``void``, est
aussi invalide.

Doom et l'interface I2C interceptent également ``0x1c`` et ``0x1d`` dans leurs
chemins d'entrée actifs, de sorte que la capacité suit le runtime qui possède
actuellement l'entrée UART. L'interface I2C doit répondre par ACK à ``0x1c`` en
plus d'implémenter ``0x1d`` ; sinon le navigateur laisse correctement **Screen
snip** désactivé même si un handler de capture existe.

Protocole sur le fil
--------------------

Après réception de ``0x1d``, le firmware écrit un en-tête ASCII terminé par
``CR LF`` puis écrit immédiatement une charge utile binaire.

La grammaire de l'en-tête est :

.. code-block:: text

   H3SNIP1 <source_width> <source_height> <display_width> <display_height> IDX8 <palette_bytes> <pixel_bytes>\r\n

Le firmware actuel émet un ``CR LF`` initial avant ``H3SNIP1`` afin de séparer
visuellement le texte UART normal de l'en-tête du protocole. Le navigateur
accepte et transmet au terminal les lignes de texte ordinaires précédentes
jusqu'à rencontrer une ligne ``H3SNIP1`` valide.

Pour les cibles Hazard3-Doom actuelles, ``display_width`` et ``display_height``
valent ``1024`` et ``600``. ``palette_bytes`` doit être exactement ``256`` et
``pixel_bytes`` doit être égal à ``source_width * source_height``.

Le navigateur rejette les en-têtes invalides, les images sources de plus de
1 000 000 pixels et les images d'affichage de plus de 4 000 000 pixels.
L'en-tête lui-même est également limité à 1024 octets pendant l'attente d'une
ligne de réponse valide.

Charge utile binaire
--------------------

La charge utile binaire qui suit immédiatement l'en-tête est :

#. 256 octets de données de palette RGB332.
#. ``source_width * source_height`` octets de pixels indexés en ordre ligne-major.

Il n'y a ni trailer binaire ni terminateur. Les tailles de l'en-tête validé
indiquent exactement au navigateur combien d'octets consommer. Tous les octets
UART ultérieurs reviennent au traitement normal du terminal.

L'identifiant de protocole actuel ``IDX8`` décrit la représentation sur le fil,
pas nécessairement le packing du framebuffer en mémoire chez le fournisseur.
Chaque pixel transmis consomme un octet et représente un index de palette de 0
à 255.

Modes de source actuels
-----------------------

.. list-table::
   :header-rows: 1
   :widths: 22 18 18 18 24

   * - Fournisseur/mode
     - Géométrie source
     - Octets de pixels
     - Octets binaires palette comprise
     - Remarques
   * - Doom standard
     - ``320x200``
     - ``64000``
     - ``64256``
     - Source indexée native de Doom.
   * - Présentation Doom haute résolution
     - ``400x240``
     - ``96000``
     - ``96256``
     - Doom effectue toujours le rendu en ``320x200`` ; le firmware applique avant sérialisation la même expansion que le chemin de présentation HDMI.
   * - Compatibilité I2CDriver
     - ``320x200``
     - ``64000``
     - ``64256``
     - Source 8 bits indexée compatible EBR.
   * - Mode de test I2CDriver 400
     - ``400x240``
     - ``96000``
     - ``96256``
     - Mode optionnel haute résolution pour comparaison.

Exemples d'en-têtes :

.. code-block:: text

   H3SNIP1 320 200 1024 600 IDX8 256 64000
   H3SNIP1 400 240 1024 600 IDX8 256 96000

Format de palette RGB332
------------------------

Chaque octet de palette est ``RRRGGGBB`` :

.. code-block:: text

   bits 7..5   red,   3 bits
   bits 4..2   green, 3 bits
   bits 1..0   blue,  2 bits

Le navigateur étend les composantes en RGB 8 bits avec la même sémantique de
réplication des bits que le chemin vidéo :

.. code-block:: text

   R8 = (R3 << 5) | (R3 << 2) | (R3 >> 1)
   G8 = (G3 << 5) | (G3 << 2) | (G3 >> 1)
   B8 = B2 * 0x55

Doom envoie les 256 entrées actuelles de palette après conversion en RGB332.
L'interface I2CDriver utilise actuellement 16 couleurs logiques ; les entrées 0
à 15 contiennent la palette de l'interface et les entrées 16 à 255 sont envoyées
à zéro, conformément au comportement de sa palette vidéo.

Timing de capture Doom
----------------------

Doom ne sérialise pas immédiatement le framebuffer depuis son handler d'entrée
UART. La réception de ``0x1d`` positionne un flag pending. La requête est
satisfaite après le prochain chemin de présentation ``DG_DrawFrame()`` terminé,
afin que la capture repose sur une image achevée plutôt que sur un tampon de
travail que Doom peut encore modifier.

Dans le build Doom ``400x240``, Doom reste un renderer ``320x200``. Le code de
capture applique la même expansion de source que la présentation HDMI directe :
16 pixels sources horizontaux deviennent 20 pixels de sortie, et chaque groupe
de cinq lignes sources devient six lignes. La source du protocole résultante est
exactement ``400x240``.

Timing et packing de capture I2CDriver
--------------------------------------

L'interface HDMI I2CDriver traite ``0x1d`` directement depuis sa boucle
d'événements UART. Elle sérialise le framebuffer de l'interface correspondant au
mode source actuellement actif. L'octet de contrôle est intercepté avant le
traitement normal des touches interactives ; la requête n'est donc pas
interprétée comme une commande I2C ou un caractère d'invite.

Chemin de réception du navigateur
---------------------------------

Les octets UART normaux sont décodés par un ``TextDecoder`` persistant et
ajoutés au terminal. La réception d'une capture d'écran ne modifie temporairement
que l'interprétation des octets entrants :

#. Pendant l'attente de l'en-tête, les lignes de texte complètes sont collectées.
#. Les lignes qui ne sont pas un en-tête ``H3SNIP1`` sont renvoyées au terminal.
#. Après un en-tête valide, le navigateur alloue exactement ``palette_bytes + pixel_bytes`` octets.
#. Ces octets sont copiés tels quels et ne passent jamais par le décodeur texte.
#. Une fois la longueur exacte reçue, les octets restants dans le même bloc série retournent au traitement normal du terminal.

Cette séparation est nécessaire car les octets arbitraires du framebuffer et de
la palette ne sont pas du texte UTF-8 et peuvent contenir des caractères de
contrôle, des octets NUL ou des séquences qui corrompraient la sortie du terminal
si elles étaient décodées.

Reconstruction du raster HDMI
-----------------------------

Le navigateur crée un Canvas en mémoire dont les dimensions correspondent à la
taille d'affichage annoncée par l'en-tête. Le firmware actuel annonce
``1024x600``.

Pour chaque pixel d'affichage ``(x, y)``, JavaScript sélectionne le pixel source
correspondant par un mapping entier au plus proche voisin :

.. code-block:: text

   source_x = floor(x * source_width / display_width)
   source_y = floor(y * source_height / display_height)

L'octet source sert d'index dans la palette RGB332 reçue. La valeur RGB étendue
et une valeur alpha de 255 sont écrites dans ``ImageData``. Le navigateur appelle
ensuite ``canvas.toBlob(..., "image/png")`` et télécharge le résultat.

La capture représente donc le raster d'affichage actif reconstruit depuis la
même image source indexée, et non une capture des symboles HDMI électriques.
Cela signifie aussi que le navigateur n'a pas besoin de savoir si la source
firmware provient de l'EBR, de la SDRAM ou d'un tampon d'expansion Doom.

Nom du téléchargement et traitement local
-----------------------------------------

Le nom de fichier généré comprend la géométrie d'affichage reconstruite et un
timestamp ISO UTC, par exemple :

.. code-block:: text

   hazard3-doom-hdmi-1024x600-2026-08-19T18-00-00Z.png

La palette, l'image indexée, l'expansion RGB, le Canvas et le PNG sont traités
localement dans le navigateur. L'application web n'envoie pas la capture vers un
serveur.

Coût du transfert UART
----------------------

Le transport actuel est volontairement non compressé. À 115200 bauds avec un
framing 8-N-1, au maximum 11 520 octets de données UART sont transmis par
seconde avant surcoût logiciel. Les temps minimaux approximatifs de charge utile
binaire sont donc :

.. list-table::
   :header-rows: 1
   :widths: 25 25 25 25

   * - Source
     - Octets binaires
     - Temps minimal approximatif
     - Effet pratique
   * - ``320x200``
     - ``64256``
     - 5,6 s
     - Pause perceptible pendant que le firmware écrit les données UART.
   * - ``400x240``
     - ``96256``
     - 8,4 s
     - Pause plus longue.

L'en-tête ASCII ajoute peu à ces valeurs. Le firmware effectue un flux UART
bloquant pendant la charge utile ; Doom ou l'interface I2C peut donc sembler en
pause jusqu'à la fin du transfert. La taille du PNG n'affecte pas le temps UART
car la compression PNG n'a lieu qu'après réception de la charge utile indexée
par le navigateur.

Timeouts et gestion des erreurs
-------------------------------

Le navigateur utilise deux timeouts indépendants :

* Sonde de capacité : 750 ms.
* Capture d'écran active : 30 secondes.

Le parseur de capture signale une erreur si l'en-tête est mal formé, si les
tailles déclarées sont incohérentes, si l'en-tête devient trop long, si la
connexion série est perdue, si la requête ne peut pas être écrite, si la charge
utile n'est pas terminée avant le timeout de capture ou si le navigateur ne
peut pas encoder le Canvas en PNG.

La déconnexion annule une capture active et remet la capacité à indisponible.

Compatibilité et versionnement
------------------------------

Les anciens firmwares Doom ou I2CDriver ne comprennent pas la requête de
capacité réservée et n'envoient donc aucun ACK ``0x06``. Le navigateur traite ce
cas comme non pris en charge et laisse Screen snip désactivé. Cela évite
d'envoyer une requête de capture binaire à un firmware qui pourrait interpréter
l'octet autrement.

Une révision mixte peut aussi contenir l'implémentation de capture ``0x1d`` sans
la négociation de capacité plus récente ``0x1c``/``0x06``. Le navigateur traite
volontairement cette combinaison comme indisponible. La boucle UART I2CDriver
doit implémenter à la fois l'ACK de capacité et la requête de capture avant que
le bouton puisse s'activer.

``H3SNIP1`` est le marqueur de version du protocole. Les changements qui
amèneraient les parseurs existants à interpréter incorrectement la charge utile
devraient utiliser un nouveau marqueur de version plutôt que de modifier
silencieusement le sens des champs ``H3SNIP1``.

Le moniteur résident ne doit pas répondre à ``0x1c`` s'il ne dispose pas
réellement d'un fournisseur de capture compatible. La capacité doit décrire le
consommateur UART actif, et non simplement le fait que le bitstream possède du
matériel HDMI.

Emplacements d'implémentation
-----------------------------

Les principaux points d'implémentation sont :

.. code-block:: text

   web/app.js
       capability state machine
       raw UART request/ACK handling
       H3SNIP1 parser
       binary payload isolation
       RGB332 expansion
       1024x600 reconstruction
       PNG download

   web/index.html
       Screen snip button and hoverable disabled-state wrapper

   web/styles.css
       disabled-button wrapper pointer behavior

   doom/doomgeneric_hazard3.c
       Doom capability ACK
       deferred capture request
       Doom palette serialization
       320x200 and 400x240 source serialization

   src/i2cdriver_hdmi.c
       I2C GUI capability ACK
       active GUI framebuffer serialization
       GUI palette serialization
       320x200 and 400x240 source handling

Aucune modification HDL du FPGA n'est nécessaire uniquement pour le protocole
Web Serial. Le transport de capture d'écran est implémenté dans le firmware et
le navigateur.

Sécurité et confidentialité
---------------------------

Le navigateur demande à l'utilisateur de sélectionner et d'autoriser un port
série. Le trafic UART circule entre le périphérique série choisi et le
JavaScript du navigateur. Le chemin de capture crée une URL Blob locale juste
assez longtemps pour démarrer le téléchargement PNG, puis révoque cette URL.

Utilisation
-----------

#. Servez le répertoire ``web/`` mis à jour depuis un contexte sécurisé ou localhost.
#. Connectez le navigateur au port série Hazard3-Doom à 115200 8-N-1.
#. Lancez Doom ou ``i2c gui``/``sao gui`` avec un firmware qui implémente ``H3SNIP1`` et l'ACK de capacité.
#. Attendez que **Screen snip** soit activé. Survolez le contrôle pour voir l'état de disponibilité actuel.
#. Appuyez sur **Screen snip**.
#. Gardez le port série connecté jusqu'à la fin du transfert binaire et au début du téléchargement PNG.

Voir :doc:`doom` pour le comportement propre à Doom, :doc:`i2cdriver` pour
l'interface HDMI I2C, :doc:`../architecture/video` pour le chemin d'affichage et
:doc:`../troubleshooting` pour les problèmes courants de capture d'écran.
