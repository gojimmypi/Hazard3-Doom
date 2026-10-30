Bootloader SERV de l'ULX5M-GS : installation, fonctionnement et récupération
============================================================================

.. important:: État des fonctions vérifiées

   Le primaire persistant seed 160 a été validé sur une carte ULX5M-GS V005
   pour le mode USB DFU (BTN2 maintenu au démarrage) et le démarrage autonome
   de l'image secondaire (BTN2 relâché). Le micrologiciel optionnel ``FWTF``
   a été vérifié sur matériel pour l'énumération USB et la **lecture** de la
   flash après chargement temporaire par JTAG. Son chemin d'effacement,
   programmation et finalisation USB d'une image complète n'a **pas** été
   validé sur matériel. Il n'existe pas de retour arrière atomique.

Ce guide concerne le répertoire ``bootloader-serv/`` du projet Hazard3-Doom
et la carte Intergalaktik ULX5M-GS **V005**. Le petit processeur SERV RV32I
utilisé par le bootloader ne doit pas être confondu avec le processeur
Hazard3 destiné aux applications Doom. L'application secondaire vérifiée
est une démonstration à LED défilantes, et non Doom.

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
   * - Écriture USB d'une image secondaire complète
     - Non validée sur matériel
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

``FWTN``
   Profil restreint par défaut, actuellement installé en primaire
   persistant. Le démarrage USB et la lecture de la flash ont été vérifiés.
   Son banc d'essai d'écriture ne couvre que 4 Kio.

``FWTF``
   Profil optionnel activé par ``DFU_FULL_IMAGE=1``. Le récepteur DFU,
   les bornes d'adresses, l'effacement, la programmation et la relecture
   ont passé les tests d'émulation. Chargé temporairement via JTAG,
   ``FWTF`` a énuméré l'USB et relu le secondaire sur matériel, mais
   **aucune écriture USB d'image complète** n'a été validée.

Le protocole expérimental utilise des blocs DNLOAD ordonnés de 64 octets,
un CRC32 du flux, des contrôles explicites ARM/STATUS/FINISH et une
relecture indépendante de l'image. La comparaison SHA-256 effectuée par
l'hôte établit l'identité des octets, pas l'authenticité cryptographique.
Un simple ``dfu-util -D`` n'est pas une procédure de mise à jour qualifiée.
L'outil hôte refuse une écriture destructive vers le profil ``FWTN``.

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

.. code-block:: bash

   cd /mnt/c/workspace/Hazard3-Doom/bootloader-serv
   ../bin/openFPGALoader.exe -c tigard --freq 1000k --detect
   ../bin/openFPGALoader.exe -c tigard --freq 1000k -m \
     "$(wslpath -w "$PWD/build-ulx5m-gs/bootloader/top_ulx5m_gs_bootloader-PACK-ONLY.bit")"

Vérifier l'IDCODE ``0x20000001`` et ``Load SRAM via JTAG: 100%``.
L'option ``-m`` ne programme pas la flash ; **ne pas utiliser ``-f``**.
Attendre l'énumération USB ``1D50:614B`` sous Windows.

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
sinon la récupération externe JTAG/flash est requise. La longue analyse
synchrone de FINISH (relecture et examen des secteurs restants) nécessite
une validation temporelle sur matériel avant toute première écriture.
Aucune commande destructive n'est autorisée par ce guide.

Dépannage
---------

* **JTAG non détecté :** SW1 ON/ON, ULX5M alimentée avant Tigard,
  masse commune, I/O 1,8 V et IDCODE ``0x20000001``.
* **JTAG chargé mais USB absent :** maintenir BTN2 pendant tout le
  chargement ; D4 allumée et D3 éteinte indiquent le mode DFU.
* **Nom ULX4M affiché par Windows :** contrôler le VID:PID et le
  descripteur ``ULX5M-GS FPGA (DFU Probe)``.
* **Aucun périphérique sous WSL :** utiliser Python Windows via PowerShell.
* **PyUSB/libusb absent :** vérifier le Python Windows, pas seulement WSL.
* **Profil ``FWTN`` au lieu de ``FWTF`` :** vérifier l'image chargée et
  son empreinte SHA-256.
* **Image rejetée :** fournir un secondaire natif, jamais le primaire.
* **Mise à jour interrompue :** ne pas supposer un retour arrière ;
  utiliser le DFU avec BTN2 ou la restauration externe.

Référence de reproductibilité
-----------------------------

Les empreintes ci-dessous concernent la configuration vérifiée le
30 octobre 2026, et non toute future compilation :

* Primaire persistant ``FWTN`` : 420 175 octets ; SHA-256
  ``c41830bd09e0e924facd2425f10a8072878e59505d12b82aff533be7df8cfe27``.
* Primaire temporaire ``FWTF`` : SHA-256
  ``6c1bb2b8219f9b0c69c56725467b9a6c40f80a3a5caf6262dfe5769842528c97``.
* Secondaire natif connu : 3 026 octets ; SHA-256
  ``68e15779871aa50d23ccb9cd52d458d072c0ca963310b2c74a96bde2861489dd``.
* Sauvegardes initiales identiques de 4 Mio : SHA-256
  ``09542df4b40bb6bcce00a327bb890f6a2d46099eae2e41f7a89e8e602614007d``.
* Session de récupération du primaire :
  ``build-ulx5m-gs/flash-install-20261030T155241133153Z``.
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
