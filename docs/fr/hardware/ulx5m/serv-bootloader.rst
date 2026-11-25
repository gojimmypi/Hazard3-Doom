Bootloader SERV de l'ULX5M-GS : installation, fonctionnement et récupération
============================================================================

.. important:: État des fonctions vérifiées

   Le primaire persistant ``FWTN`` (seed 160) est validé pour le mode DFU
   et le démarrage secondaire autonome. Le profil ``FWTF`` v2d, chargé
   uniquement en SRAM, est validé pour la réécriture USB de la même image
   secondaire de 3 026 octets, avec vérification FINISH, relecture USB et
   comparaison JTAG complète. La mise à jour n'est pas atomique ; les grandes
   images et la reprise après coupure ne sont pas qualifiées.

Ce guide concerne le répertoire ``bootloader-serv/`` du projet Hazard3-Doom
et la carte Intergalaktik ULX5M-GS **V005**. Le petit processeur SERV RV32I
utilisé par le bootloader ne doit pas être confondu avec le processeur
Hazard3 destiné aux applications Doom. L'application secondaire vérifiée
est une démonstration à LED défilantes, et non Doom.

Carte neuve : première installation du bootloader
-------------------------------------------------

.. note::

   Cette procédure utilise des opérations de programmation et de relecture
   de la mémoire flash via JTAG déjà vérifiées. La séquence d'installation
   complète n'a pas encore été testée indépendamment sur une carte neuve.

.. warning:: Programmation persistante de la mémoire flash.

   Écriture persistante réservée à une ULX5M-GS V005 neuve, avec autorisation
   explicite de remplacer la configuration d'usine. L'outil de maintenance
   exige un secondaire existant et une compilation FWTF qualifiée ; ne pas
   l'utiliser ici. Ne jamais installer FWTF comme primaire permanent.

Aucune compilation nécessaire. Obtenir les fichiers de la même version
``bin/ulx5m_gs_bootloader.bit`` (FWTN) et ``bin/ulx5m_gs_blinky.bit``
et le manifeste ``bin/INVENTORY.sha256`` de la même version. Utiliser Tigard, openFPGALoader
v1.2.0 et Python 3. Sous Windows utiliser l'exécutable fourni ; sous Ubuntu
natif installer v1.2.0 dans PATH et configurer les permissions USB.
Sous WSL, le script utilise l’exécutable Windows fourni via
l’interopérabilité Windows. Conserver le dépôt sur un lecteur Windows
(par exemple ``/mnt/c``) ; aucun accès USB natif dans WSL n’est requis.

Les deux appareils hors tension, régler SW1 ON/ON. Relier Tigard en logique
1,8 V, masse commune, VTGT déconnecté ; vérifier les tensions (:doc:`index`).
Alimenter d'abord ULX5M puis Tigard, BTN2 relâché. Attendre un seul IDCODE
``0x20000001`` et JEDEC ``1F 42 16`` ; arrêter en cas d'anomalie.

Avant tout accès JTAG, le script vérifie automatiquement les deux fichiers
avec leurs entrées dans ``bin/INVENTORY.sha256``. Aucune saisie manuelle
n'est nécessaire. Un manifeste absent, une entrée absente ou en double,
un SHA-256 invalide ou différent arrête le script avant tout accès JTAG.
Utiliser le manifeste de la même version de confiance ; ne pas le régénérer
pour contourner une différence.

Exécuter ``scripts/factory-install-ulx5m-bootloader.py`` depuis la racine
du projet. Deux lectures indépendantes de 4 Mio par blocs de 128 Kio précèdent
la confirmation d'écriture. Conserver les sauvegardes hors des dossiers de
compilation. Le primaire occupe 512 Kio à zéro ; le secondaire commence à
``0x201000``. Seuls la partition primaire et les secteurs occupés par le
secondaire sont remplacés ; tout autre octet doit rester intact. Ne pas
utiliser Python -O.

**Windows PowerShell**

.. code-block:: powershell

   cd C:\workspace\Hazard3-Doom
   py -3 .\scripts\factory-install-ulx5m-bootloader.py

**Ubuntu sous WSL (Bash)**

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom
   python3 ./scripts/factory-install-ulx5m-bootloader.py

**Native Ubuntu / Linux (Bash)**

.. code-block:: bash

   cd ~/Hazard3-Doom
   python3 ./scripts/factory-install-ulx5m-bootloader.py

Après PASS, couper les deux alimentations, débrancher Tigard, régler SW1
OFF/OFF. Maintenir BTN2 avant la mise sous tension ; relâcher après détection
USB ``1D50:614B``. Vérifier FWTN avec la requête d'identité ci-dessous.
Redémarrer à froid sans BTN2 : attendre les LED défilantes du secondaire de
démonstration. En cas d'échec, arrêter, conserver les sauvegardes et journaux,
ne pas réessayer ni restaurer automatiquement. Aucun retour arrière automatique.

Fonctions disponibles
---------------------

.. list-table:: Capacités et niveau de validation
   :header-rows: 1
   :widths: 62 38

   * - Fonction
     - Validation
   * - Primaire seed 160 persistant en flash SPI
     - Matériel : PASS
   * - USB DFU avec BTN2 maintenu, puis relâché
     - Matériel : PASS (``FWTN``)
   * - Démarrage secondaire automatique à ``0x201000``
     - Matériel : PASS (LED défilantes)
   * - Énumération USB ``1D50:614B``
     - Matériel : PASS (``FWTN`` et ``FWTF`` chargé en SRAM)
   * - Lecture des 3 026 octets secondaires et contrôle SHA-256
     - Matériel : PASS pour les deux profils
   * - Réception DFU complète et vérification de la flash
     - Tests hors ligne : PASS
   * - Réécriture identique de 3 026 octets et contrôle JTAG de 4 Mio
     - Matériel : PASS (``FWTF`` v2d)
   * - Mise à jour atomique et restauration automatique
     - Non implémentées

Modes de démarrage
------------------

SW1 sélectionne la source de configuration initiale du FPGA. BTN2
sélectionne ensuite le comportement du primaire. Coupez l'alimentation
avant de modifier SW1.

* **SW1 OFF/OFF ; BTN2 maintenu avant la mise sous tension :** le primaire
  persistant démarre depuis la flash SPI et reste en mode USB DFU.
* **SW1 OFF/OFF ; BTN2 relâché :** le primaire persistant passe à l'image
  secondaire native située à ``0x201000``.
* **SW1 ON/ON ; BTN2 maintenu pendant le chargement JTAG :** chargement
  temporaire d'un primaire d'essai en SRAM, avec sélection du mode DFU.

Le verrouillage de BTN2 a lieu au démarrage du primaire. Relâcher BTN2
après la sélection du DFU ne désactive pas l'USB ; appuyer après le
verrouillage du mode normal ne peut pas activer le DFU. SW1 OFF/OFF
correspond au mode SPI actif (``0x0``) et ON/ON au mode JTAG (``0xC``).

Le système comprend une référence à 25 MHz, un domaine SERV/USB nominal
à 48 MHz issu d'une PLL, et un contrôleur de reconfiguration indépendant à
25 MHz (``rtl/ulx5m_cfg_autoboot_25.v``). Le contrôleur libère les broches
de la flash et transmet au GateMate une commande de configuration suivie
de ``RECFG``. Le démarrage autonome ne dépend pas d'un téléchargement USB.
Sur la carte vérifiée, le transfert secondaire s'effectue après environ
2,68 secondes.

.. list-table:: Indicateurs LED pendant l'exécution du primaire
   :header-rows: 1
   :widths: 18 82

   * - LED
     - Signification
   * - D7
     - Clignotement de fonctionnement
   * - D6
     - PLL verrouillée
   * - D5
     - Sélection du mode enregistrée
   * - D4
     - Mode DFU sélectionné
   * - D3
     - Mode normal sélectionné
   * - D2
     - État instantané de BTN2
   * - D0, D1
     - Indicateurs du micrologiciel

Après relâchement de BTN2, le mode DFU persistant vérifié montre D0/D1
allumées, D2/D3 éteintes, D4/D5/D6 allumées et D7 clignotante.
Un clignotement de D7 seul ne prouve pas l'énumération USB. L'application
secondaire utilise une séquence de LED défilantes différente.

Organisation de la flash
------------------------

La flash U9 est une AT25QL321 de 4 Mio (JEDEC ``1F 42 16``), avec des
secteurs d'effacement de 4 096 octets et des pages de programmation de
256 octets. La politique d'adressage utilisée pour le DFU secondaire est :

.. list-table:: Régions de la flash
   :header-rows: 1
   :widths: 34 27 39

   * - Adresses
     - Taille
     - Utilisation
   * - ``0x000000..0x07FFFF``
     - 512 Kio
     - Primaire persistant **protégé**
   * - ``0x080000..0x1FFFFF``
     - 1,5 Mio
     - Contenu existant/inconnu **réservé**
   * - ``0x200000..0x200FFF``
     - 4 Kio
     - Secteur de métadonnées/candidat **réservé**
   * - ``0x201000..0x3FFFFF``
     - 2 093 056 octets
     - Fenêtre secondaire, écriture ``FWTF`` optionnelle

Ces limites sont imposées par le logiciel, sans modifier les bits matériels
de protection de la flash. La taille maximale depuis ``0x201000`` est
``0x1FF000`` octets. L'outil n'accepte pas d'adresse d'écriture fournie
librement par l'hôte. Les zones réservées ne doivent pas être réutilisées.

.. warning:: Distinguer le primaire du secondaire

   ``build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit``
   contient le **primaire** et ne doit jamais être utilisé comme fichier
   secondaire DFU. Le secondaire est une autre image GateMate empaquetée
   pour l'adresse ``0x201000``. Le fichier local de référence
   ``build-ulx5m-gs/native-v41-secondary-3026.bit`` provient d'une image
   flash vérifiée ; il n'est pas créé par une compilation neuve.

Le processeur SERV et son micrologiciel sont stockés dans la RAM interne
du FPGA. Le bus Wishbone raccorde les registres d'état/LED/BUTTON
(``0x80000000``), l'UART (``0x81000000``), l'USB (``0x82000000``), la RAM
des points de terminaison USB (``0x83000000``) et le contrôleur SPI
(``0x84000000``). La commande de reconfiguration dispose de sa propre
synchronisation et de son accusé de réception.

USB et profils du micrologiciel
-------------------------------

L'interface USB pleine vitesse porte l'identifiant ``1D50:614B``, avec
classe/sous-classe/protocole ``FE/01/02``. Les blocs DNLOAD font au plus
64 octets et empruntent le point de terminaison de contrôle EP0, sans
point de terminaison bulk. Le produit USB est annoncé comme
``ULX5M-GS FPGA (DFU Probe)`` ; un ancien nom ULX4M conservé par Windows
n'est pas un identifiant fiable.

``FWTN`` et ``FWTF`` sont des **identifiants de profil du micrologiciel**
de quatre caractères ASCII, et non des noms de fichiers, des commandes
GateMate ou des identifiants USB. Ils occupent les octets 0..3 de la réponse
STATUS fournisseur de 24 octets (requête ``0x5D``). Ils désignent le
micrologiciel qui répond sur USB, pas l'image secondaire stockée en flash.
Les deux profils utilisent le VID:PID ``1D50:614B``.

``FWTN``
   Profil restreint par défaut (sans ``DFU_FULL_IMAGE=1``), installé comme
   primaire persistant de référence. L'énumération USB et la lecture du
   secondaire sont validées sur matériel. Son banc d'essai limité à 4 Kio
   n'est **pas** un outil de mise à jour complète ; ``--execute`` est refusé.

``FWTF``
   Profil d'écriture complète activé par ``DFU_FULL_IMAGE=1``, chargé
   temporairement en SRAM par JTAG ``-m`` et non installé en flash primaire.
   La version v2d a réussi la réécriture physique de 3 026 octets, FINISH
   et la relecture USB indépendante. Deux lectures JTAG complètes, le
   retour à ``FWTN`` et le démarrage autonome ont également réussi.
   La récupération après interruption et les grandes images restent à valider.

Après les quatre caractères, STATUS renvoie cinq entiers de 32 bits en
ordre little-endian : phase, longueur attendue, CRC32 attendu, nombre
d'octets reçus et code d'erreur. Les phases sont ``0`` (désarmé), ``1``
(armé), ``4`` (vérification en cours), ``2`` (vérifié) et ``3`` (échec).
L'accusé de réception de FINISH ne prouve pas la réussite : l'hôte attend
la phase ``2`` sans erreur. SHA-256 vérifie l'égalité des octets mais ne
constitue pas une signature d'authenticité.

Le protocole utilise des blocs DNLOAD ordonnés de 64 octets, CRC32 et les
requêtes fournisseur ARM (``0x5C``), STATUS (``0x5D``) et FINISH (``0x5E``).
``--probe`` accepte les deux profils en **lecture seule** ; ``--execute``
exige ``FWTF``, une confirmation explicite et le SHA-256 attendu de
l'image (vérifié avant tout accès USB). ``dfu-util -D`` seul ne
remplace pas cette procédure de mise à jour protégée.

Prérequis
---------

* Récupérer Hazard3-Doom avec les sous-modules épinglés et travailler dans
  ``bootloader-serv/`` (distinct de l'ancien bootloader PicoRV32).
* Utiliser WSL/Ubuntu ou Linux pour Make, Python, Yosys, nextpnr et les
  tests Icarus. Le point de référence utilisait OSS CAD Suite
  ``2026-07-20`` et le compilateur RISC-V bare-metal GCC ``12.2.0``.
* Sur l'installation Windows/WSL testée, WSL n'a **pas** d'accès USB natif.
  Utiliser ``py -3`` sous Windows avec PyUSB et ``bin/libusb-1.0.dll``.
  Au besoin, installer PyUSB depuis PowerShell :
  ``py -3 -m pip install pyusb``.
* Pour JTAG, utiliser le ``bin/openFPGALoader.exe`` Windows d'origine
  (v1.2.0) et Tigard en logique 1,8 V, avec masse commune et VTGT non
  connecté. Ne pas modifier les pilotes pour faire fonctionner ``lsusb``.
* Vérifier les tensions de la carte V005 et les avertissements dans
  :doc:`index` avant toute connexion matérielle.

Compilation et qualification dans WSL
-------------------------------------

Exécuter à partir de ``bootloader-serv/`` :

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   make -f Makefile.ulx5m-gs show-settings
   make -f Makefile.ulx5m-gs test
   make -f Makefile.ulx5m-gs build SEED=160
   make -f Makefile.ulx5m-gs qualify SEED=160

Ces commandes sélectionnent le profil ``FWTN`` par défaut. Pour construire
le profil d'essai ``FWTF``, demander explicitement :

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   make -f Makefile.ulx5m-gs build SEED=160 DFU_FULL_IMAGE=1
   make -f Makefile.ulx5m-gs qualify SEED=160 DFU_FULL_IMAGE=1

Le fichier produit est
``build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit``.
La commande de configuration GateMate de 27 octets est dérivée et vérifiée
à partir de **cette image exacte**. Un résultat de routage PASS ne vaut
pas validation physique. Le seed 160 est un point de référence daté,
non une garantie de timing pour de nouvelles versions.

Essai JTAG en SRAM, sans écriture flash
---------------------------------------

Couper l'alimentation de l'ULX5M et de Tigard, régler SW1 sur ON/ON,
maintenir BTN2 pendant la mise sous tension de l'ULX5M, puis alimenter
Tigard. **Garder BTN2 maintenu pendant tout le transfert JTAG et jusqu'à
ce que D4 soit allumée.** Relâcher ensuite BTN2 : D4 doit rester allumée
et D3 éteinte. Un appui tardif sur BTN2 ne change pas le mode enregistré.

Les deux ordres de mise sous tension (Tigard ou ULX5M en premier) ont
fonctionné, sans qu'un ordre obligatoire soit établi. Un transfert JTAG
terminé ne prouve pas l'exécution du micrologiciel. Si les LED restent
éteintes ou si l'USB ne s'énumère pas, couper **les deux** alimentations,
essayer l'ordre inverse et garder BTN2 maintenu pendant la configuration.
Vérifier D4 allumée, D3 éteinte et l'énumération USB avant tout accès à la
flash. La cause de cette sensibilité reste inconnue. Laisser VTGT débranché,
relier les masses et ne jamais interrompre un effacement ou une programmation.

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   ../bin/openFPGALoader.exe -c tigard --freq 1000k --detect
   ../bin/openFPGALoader.exe -c tigard --freq 1000k -m \
     "$(wslpath -w "$PWD/build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit")"

Vérifier l'IDCODE ``0x20000001`` et ``Load SRAM via JTAG: 100%``.
L'option ``-m`` ne programme pas la flash ; **ne pas utiliser ``-f``**.
Attendre l'énumération USB ``1D50:614B`` sous Windows.

Un chargement SRAM par JTAG avec SW1 ON/ON ne reproduit pas un
démarrage à froid en mode SPI actif. GateMate mémorise le mode de
configuration au reset ; le mode JTAG ne lance pas automatiquement
une image depuis la flash SPI. BTN2 relâché, D3 allumée, D4 éteinte
et D7 clignotante indiquent le mode normal du primaire, sans prouver
le transfert au secondaire. L'absence des LED défilantes n'établit
pas à elle seule une régression. Vérifier le démarrage autonome par
une mise sous tension distincte avec SW1 OFF/OFF et BTN2 relâché ;
cela teste ``FWTN`` installé, et non ``FWTF`` chargé en SRAM. Ne pas
modifier SW1 pendant que la carte est sous tension.

Sauvegarder le bootloader installé
----------------------------------

Couper les deux alimentations. Régler SW1 sur ON/ON, connecter Tigard avec
masse commune, logique 1,8 V et VTGT déconnecté. Alimenter d'abord l'ULX5M,
puis Tigard. Dans PowerShell Windows, effectuer quatre lectures de 128 Kio
sans écriture. Arrêter si la détection échoue ou si la flash n'est pas
l'AT25QL321 attendu (JEDEC ``1F 42 16``).

.. code-block:: powershell

   cd C:\workspace\Hazard3-Doom
   .\bin\openFPGALoader.exe -c tigard --freq 1000k --detect
   $output = "$HOME\ulx5m-bootloader.bin"
   $data = New-Object 'System.Collections.Generic.List[byte]'
   for ($offset = 0; $offset -lt 524288; $offset += 131072) {
       $chunk = "$output.$offset.chunk"
       if (Test-Path $chunk) { throw "Chunk already exists: $chunk" }
       .\bin\openFPGALoader.exe -c tigard --freq 1000k --dump-flash --file-size 131072 -o $offset $chunk
       if ($LASTEXITCODE -ne 0) { throw "Read failed: $offset" }
       $bytes = [IO.File]::ReadAllBytes($chunk)
       if ($bytes.Length -ne 131072) { throw "Invalid chunk size: $offset" }
       $data.AddRange($bytes)
   }
   if (Test-Path $output) { throw "Backup already exists: $output" }
   [IO.File]::WriteAllBytes($output, $data.ToArray())
   Get-Item $output
   Get-FileHash $output -Algorithm SHA256

**Ubuntu / Linux natif (Bash)**

Utiliser une version Linux native d'openFPGALoader prenant en charge GateMate et Tigard (version Windows testée : v1.2.0), disponible dans PATH, avec les permissions USB configurées. Sous WSL dans la configuration Windows testée, utiliser PowerShell ci-dessus. Arrêter si la détection échoue ou si une lecture indique un JEDEC autre que ``1F 42 16``. Exécuter ce bloc dans Bash ; il crée un nouveau répertoire de sauvegarde et refuse de réutiliser un répertoire existant.

.. code-block:: bash

   (
       set -euo pipefail
       openFPGALoader -c tigard --freq 1000k --detect
       backup_dir="$HOME/ulx5m-bootloader-backup"
       mkdir "$backup_dir"
       cd "$backup_dir"
       for offset in 0 131072 262144 393216; do
           chunk="$offset.chunk"
           openFPGALoader -c tigard --freq 1000k --dump-flash --file-size 131072 -o "$offset" "$chunk"
           test "$(wc -c < "$chunk")" -eq 131072
       done
       cat 0.chunk 131072.chunk 262144.chunk 393216.chunk > ulx5m-bootloader.bin
       test "$(wc -c < ulx5m-bootloader.bin)" -eq 524288
       wc -c ulx5m-bootloader.bin
       sha256sum ulx5m-bootloader.bin
   )

Le fichier brut de 524 288 octets couvre ``0x000000..0x07FFFF``, remplissage
compris ; sa taille peut différer du fichier ``.bit`` original. Conserver
les fragments jusqu'à vérification. Pour une seconde lecture indépendante,
changer le nom de sortie et comparer les SHA-256. Une empreinte seule ne
révèle pas la version. Conserver aussi une sauvegarde complète de 4 Mio
pour la récupération. Couper les deux alimentations et remettre SW1 OFF/OFF.

Identifier le bootloader
------------------------

Tigard déconnecté ou éteint, régler SW1 OFF/OFF hors tension. Maintenir BTN2
à la mise sous tension, puis relâcher après l'énumération DFU. Avec PyUSB
Windows et libusb (voir prérequis), lire STATUS sans image secondaire :

.. code-block:: powershell

   cd C:\workspace\Hazard3-Doom
   $env:PATH = "$PWD\bin;$env:PATH"
   py -3 -c "import usb.core; d=usb.core.find(idVendor=0x1d50,idProduct=0x614b); assert d is not None, 'DFU device not found'; s=bytes(d.ctrl_transfer(0xC0,0x5D,0,0,24)); assert len(s)==24, 'Unexpected STATUS length'; print('Profile:', s[:4].decode('ascii')); print('USB bcdDevice: 0x%04X' % d.bcdDevice)"

**Ubuntu / Linux natif (Bash)**

Sous Ubuntu natif, installer PyUSB et libusb, puis vérifier l'énumération DFU. Les règles udev doivent autoriser l'accès USB. En cas de refus, corriger les permissions avant de réessayer. Sous WSL dans la configuration testée, utiliser PowerShell Windows.

.. code-block:: bash

   sudo apt install python3-usb libusb-1.0-0 usbutils
   lsusb -d 1d50:614b
   python3 -c "import usb.core; d=usb.core.find(idVendor=0x1d50,idProduct=0x614b); assert d is not None, 'DFU device not found'; s=bytes(d.ctrl_transfer(0xC0,0x5D,0,0,24)); assert len(s)==24, 'Unexpected STATUS length'; print('Profile:', s[:4].decode('ascii')); print('USB bcdDevice: 0x%04X' % d.bcdDevice)"

Les alternatives Linux natives n'ont pas été testées sur la carte.

Le résultat attendu est ``FWTN`` ou ``FWTF``. Le descripteur USB
``bcdDevice`` est affiché à titre informatif ; aucun des deux champs n'est
documenté comme identifiant unique de compilation. Cette commande en lecture
seule dérivée du protocole STATUS n'a pas été testée ici sur le matériel.
La procédure ``--probe`` ci-dessous reste l'alternative documentée. Aucune
requête de version sémantique, de commit Git ou de seed n'est établie.

Lecture USB sans modification de la flash
-----------------------------------------

Utiliser un secondaire natif déjà récupéré et vérifié pour la carte
concernée ; le nom suivant est **local**, non généré automatiquement.
Vérifier d'abord le SHA-256 de ce fichier :

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   sha256sum build-ulx5m-gs/native-v41-secondary-3026.bit
   python3 tests/ulx5m_dfu_update.py \
     --image build-ulx5m-gs/native-v41-secondary-3026.bit

La seconde commande effectue seulement le contrôle préalable hors ligne.
Le SHA-256 du secondaire de référence est
``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``.
Pour la **lecture USB**, exécuter le Python Windows depuis WSL :

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   SCRIPT_WIN="$(wslpath -w "$PWD/tests/ulx5m_dfu_update.py")"
   IMAGE_WIN="$(wslpath -w "$PWD/build-ulx5m-gs/native-v41-secondary-3026.bit")"
   BIN_WIN="$(wslpath -w "$PWD/../bin")"
   powershell.exe -NoProfile -Command \
     "\$env:PATH='$BIN_WIN;' + \$env:PATH; py -3 '$SCRIPT_WIN' --image '$IMAGE_WIN' --probe"

Le résultat attendu indique ``Device profile FWTN`` ou ``FWTF``, puis
``Verified 3026/3026 bytes`` et le SHA-256 correspondant. ``--probe``
n'envoie **aucune commande ARM, effacement, programmation, FINISH ou RECFG**.
Ne pas utiliser ``--execute`` pour une installation ordinaire.

Mise à jour secondaire contrôlée (expérimentale)
--------------------------------------------------

La procédure de référence réécrit l'image secondaire connue de 3 026 octets
dans le secteur ``0x201000..0x201FFF``, sans installer de primaire persistant.
La mise à jour s'effectue **sur place**, sans atomicité ni restauration
automatique. Chaque écriture destructive exige une autorisation explicite.

Avant toute écriture, conserver deux lectures indépendantes et identiques
des 4 Mio. La flash de référence a pour SHA-256
``3aa6280fd96de3c00ef844a2f0298a919f7cea9311d5a267ee0be85bc4375c78``
(``../ulx5m-prewrite-readonly-20261030-FN1nVy/``) ; une configuration
future peut différer. Vérifier les empreintes des deux bitstreams, le contenu
``0xFF`` de ``0x201BD2..0x3FFFFF`` pour l'image de référence et l'intégrité
des zones protégées.

Charger le primaire ``FWTF`` v2d en SRAM avec SW1 ON/ON, BTN2 maintenu et
JTAG ``-m`` uniquement. Avant la commande destructive, la sonde USB
``--probe`` doit identifier ``FWTF``, le JEDEC ``1F 42 16`` et les
3 026 octets corrects. Ne jamais installer ``FWTF`` dans la flash primaire.

Après autorisation distincte, la commande **destructive** utilise l'outil
hôte Windows existant :

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   SCRIPT_WIN="$(wslpath -w "$PWD/tests/ulx5m_dfu_update.py")"
   IMAGE_WIN="$(wslpath -w "$PWD/build-ulx5m-gs/native-v41-secondary-3026.bit")"
   BIN_WIN="$(wslpath -w "$PWD/../bin")"
   EXPECTED_SHA256="68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd"
   powershell.exe -NoProfile -Command \
     "\$env:PATH='$BIN_WIN;' + \$env:PATH; py -3 '$SCRIPT_WIN' --image '$IMAGE_WIN' --execute --confirm REPLACE-SECONDARY-0x201000 --expected-sha256 '$EXPECTED_SHA256'"

Après une écriture autorisée, exiger FINISH terminé et une relecture USB
indépendante correspondant au SHA-256 de l'image fournie. L'image secondaire
de référence a pour SHA-256
``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``.
L'hôte n'envoie aucune commande RECFG.

Effectuer une lecture JTAG **indépendante** des 4 Mio à l'aide de
``tests/ulx5m_flash_install.py`` (API ``detect()``/``dump()`` en lecture
seule). Pour la réécriture identique de référence, tous les octets doivent
correspondre à la sauvegarde initiale (SHA-256
``3aa6280fd96de3c00ef844a2f0298a919f7cea9311d5a267ee0be85bc4375c78``).
Pour une image différente, vérifier les octets programmés et préserver toutes
les régions non concernées. Tester ensuite SW1 OFF/OFF avec BTN2 maintenu
pour ``FWTN``, puis BTN2 relâché pour le démarrage secondaire. Seule la
réécriture identique de référence a passé ces contrôles physiques.

En cas d'erreur, conserver les journaux, ne pas relancer l'écriture
ni effectuer de démarrage normal ; revenir au DFU doré avec BTN2 maintenu.

Redémarrage persistant et récupération
--------------------------------------

Après un essai SRAM, éteindre les deux cartes, régler SW1 sur OFF/OFF et
laisser Tigard éteint. Maintenir BTN2 avant d'alimenter l'ULX5M, puis le
relâcher quand le motif DFU apparaît. La lecture USB doit alors identifier
``FWTN``. Lors d'un autre démarrage à froid, laisser BTN2 relâché :
l'application secondaire doit afficher les LED défilantes.

Installer un nouveau primaire persistant est une **opération de maintenance
destructive distincte**. ``-m`` ne l'installe pas. L'outil protégé
``tests/ulx5m_flash_install.py`` prend en charge les sauvegardes, la
vérification du primaire et les contrôles de restauration sur une flash
déjà préparée ; ce n'est pas une recette pour une carte vierge. Conserver
deux sauvegardes indépendantes des 4 Mio et les empreintes d'images.

Une mise à jour ``FWTF`` modifie le secondaire **en place** : une coupure
peut le rendre inutilisable. Si le primaire persistant reste sain,
maintenir BTN2 lors de la mise sous tension permet de retrouver le DFU ;
sinon la récupération externe JTAG/flash est requise. Avec v2d, les blocs
DNLOAD sont programmés hors des callbacks USB et FINISH vérifie l'image de
manière incrémentale sans effacer les secteurs suivants. Les attentes WIP
pour l'effacement et la programmation restent synchrones et peuvent
retarder le service USB. Les durées extrêmes de service USB, les images plus grandes et la reprise
après interruption restent non qualifiées. Cette documentation n'autorise
aucune opération destructive.

Dépannage
---------

* **JTAG non détecté :** SW1 ON/ON, couper les deux alimentations puis
  essayer l'un ou l'autre ordre ; masse commune, I/O 1,8 V, IDCODE ``0x20000001``.
* **JTAG chargé mais USB absent :** vérifier le maintien de BTN2 et les
  LED ; si elles sont toutes éteintes, redémarrer les deux appareils dans
  l'ordre inverse. D4 allumée et D3 éteinte indiquent le mode DFU.
* **Nom ULX4M affiché par Windows :** contrôler le VID:PID et le
  descripteur ``ULX5M-GS FPGA (DFU Probe)``.
* **Aucun périphérique sous WSL :** utiliser Python Windows via PowerShell.
* **PyUSB/libusb absent :** vérifier le Python Windows, pas seulement WSL.
* **Profil ``FWTN`` au lieu de ``FWTF`` :** vérifier l'image chargée et
  son empreinte SHA-256.
* **Image rejetée :** fournir un secondaire natif, jamais le primaire.
* **Mise à jour interrompue :** ne pas supposer un retour arrière ;
  utiliser le DFU avec BTN2 ou la restauration externe.

Messages USBView sous Windows
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Lorsque la carte est en mode DFU, ouvrir l'utilitaire Windows fourni
``bin/usbview.exe``. Sous WSL, utiliser cet utilitaire Windows plutôt
qu'un outil USB Linux natif sur le banc d'essai actuel. Une énumération
DFU réussie indique le VID:PID ``1D50:614B``, le nom de produit
``ULX5M-GS FPGA (DFU Probe)``, la pleine vitesse (Full Speed), la
configuration ``0x01`` et la classe/sous-classe/protocole ``FE/01/02``.

Les messages suivants de USBView peuvent être trompeurs :

* **Ancien nom ULX4M :** Windows peut conserver le nom convivial
  ``ULX4M-LS FPGA (DFU)`` pour le VID:PID partagé. Vérifier le nom de
  produit dans le descripteur de périphérique plutôt que dans l'arborescence.
* **Open Pipes: 0 / No open pipes!:** normal pour cette interface DFU.
  Toutes les requêtes DFU utilisent le point de terminaison de contrôle
  par défaut EP0. Il n'existe aucun point de terminaison supplémentaire
  (``bNumEndpoints = 0``).
* **HID Descriptor avec de nombreuses entrées :** USBView peut confondre
  le descripteur fonctionnel DFU avec un descripteur HID, car tous deux
  utilisent le type ``0x21``. La taille de transfert DFU de 64 octets est
  alors interprétée à tort comme un nombre de 64 entrées HID ; l'outil
  peut afficher des octets sans rapport au-delà du descripteur de neuf
  octets. Il s'agit d'un problème de décodage de USBView, et non d'une
  preuve de corruption du descripteur FPGA.

Pour les octets observés ``09 21 09 00 00 40 00 10 01``, le décodage DFU
correct donne ``bLength = 9``, ``bDescriptorType = 0x21``,
``bmAttributes = 0x09`` (téléchargement vers le périphérique pris en charge,
détachement géré par le périphérique), ``wDetachTimeOut = 0``,
``wTransferSize = 64`` et ``bcdDFUVersion = 0x0110`` (DFU 1.1).

Ne pas modifier le micrologiciel ni réinstaller le pilote USB dans le seul
but de faire disparaître ces messages. L'énumération ne prouve ni la prise
en charge de la mise à jour flash ni l'identité du profil actif ; utiliser
la requête STATUS en lecture seule décrite plus haut. Sous Ubuntu/Linux
natif, utiliser ``lsusb -v -d 1d50:614b`` dans Bash pour examiner les
descripteurs (avec les permissions USB appropriées).

Voir le `code source USBView de Microsoft (DisplayHidDescriptor) <https://github.com/microsoft/Windows-driver-samples/blob/main/usb/usbview/display.c>`_
pour l'implémentation du décodage HID.

Référence de reproductibilité
-----------------------------

Les empreintes ci-dessous concernent la configuration vérifiée le
30 octobre 2026, et non toute future compilation :

* Primaire persistant ``FWTN`` : 420 175 octets ; SHA-256
  ``c41830bd09e0e924facd2425f10a8072878e59505d12b82aff533be7df8cfe27``.
* Primaire temporaire ``FWTF`` v2d : 420 175 octets ; SHA-256
  ``c73b8d6fe1ac1150ad3e3bba72c6d64664ee495185fade339f188f628dcfe167``.
* Secondaire natif connu : 3 026 octets ; SHA-256
  ``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``.
* Deux copies indépendantes avant écriture (4 Mio) : SHA-256
  ``3aa6280fd96de3c00ef844a2f0298a919f7cea9311d5a267ee0be85bc4375c78`` ;
  ``../ulx5m-prewrite-readonly-20261030-FN1nVy/``.
* Deux copies JTAG après écriture (4 Mio) : même SHA-256 ;
  ``../ulx5m-postwrite-readonly-20261030-fiHyVE/``.
* Routage candidat seed 160 : fréquences maximales 67,96 MHz (25 MHz)
  et 49,06 MHz (48 MHz).

Les deux primaires utilisent le même nom de fichier de sortie. Vérifier
leur empreinte SHA-256 avant chaque programmation JTAG ou flash.

Documentation complémentaire
----------------------------

* :doc:`index` - avertissements d'alimentation et détails du V005.
* :doc:`bringup` - relevés d'essais sur matériel.
* :doc:`multiboot-v72` - expérience historique de reconfiguration.
* :doc:`../../user-guide/bootloader` - anciennes procédures ULX3S/ULX4M,
  dont les adresses flash ne doivent pas être appliquées au V005.
