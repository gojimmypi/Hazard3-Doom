Mémoire et interface de bus
===========================

Hazard3 sépare le pipeline du processeur de la cartographie mémoire système.
Cette séparation est particulièrement importante dans Hazard3-Doom car la
plupart des gros mécanismes mémoire et graphiques sont des ajouts propres au SoC
du projet, et non une partie du cœur CPU.

Interfaces de transaction côté cœur
-----------------------------------

:hazard3-src:`hazard3_core.v <hdl/hazard3_core.v>` possède des canaux logiquement séparés pour :

* le fetch d'instructions ; et
* les accès de données load/store.

Cela permet d'encapsuler le même cœur dans différentes architectures système.
Les wrappers Hazard3 standard illustrent deux choix courants :

``hazard3_cpu_2port``
   Conserve le trafic AHB5 instructions et données sur des ports maîtres séparés.

``hazard3_cpu_1port``
   Arbitre les requêtes instructions et données sur un port maître AHB5 unique.

Hazard3-Doom instancie
:hazard3-src:`hazard3_cpu_1port.v <hdl/hazard3_cpu_1port.v>`. C'est le premier endroit où un étudiant doit distinguer le **parallélisme du pipeline** du **parallélisme du bus mémoire** : F et M peuvent tous deux avoir besoin d'accéder à la mémoire, mais le wrapper un port doit sérialiser les accès vers l'interface maître externe partagée.

Concepts AHB5 visibles dans le wrapper
--------------------------------------

Le wrapper expose les signaux classiques de phase adresse/contrôle et données de
style AHB, notamment l'adresse, le type de transfert, la taille, le sens
d'écriture, la réponse, ready et les données lues/écrites. Il contient aussi les
signaux d'accès exclusif utilisés lorsque l'extension optionnelle ``A`` de
Hazard3 est synthétisée.

Le projet désactive ``EXTENSION_A`` ; le logiciel ne peut donc pas exécuter
d'instructions mémoire atomiques RISC-V dans ce bitstream, même si le wrapper
standard possède le câblage de bus nécessaire aux configurations qui les
activent.

Hiérarchie des bus du SoC
-------------------------

À haut niveau, le chemin mémoire du projet est :

.. code-block:: text

                     +-------------------+
   instruction ----->|                   |
                     | hazard3_cpu_1port |---- AHB5 ----+
   load/store ------>|                   |              |
                     +-------------------+              v
                                                +---------------+
                                                | example SoC   |
                                                | decode/fabric |
                                                +---------------+
                                                  |     |     |
                                                SRAM  APB   SDRAM

Le CPU n'a pas besoin de savoir si une adresse atteint finalement la Block RAM
ECP5, un UART APB, la SDRAM externe ou une aperture vidéo du projet. Il émet un
load/store architectural normal ; le décodage d'adresse du SoC détermine la
destination.

Vecteur de reset et SRAM résidente
----------------------------------

Le SoC d'exemple épinglé instancie le processeur avec :

.. code-block:: text

   RESET_VECTOR = 0x00000040

Le wrapper ULX3S configure 128 Kio de SRAM interne et fournit
``hazard3_boot.hex`` comme image de préchargement. C'est une personnalisation du
projet : le moniteur résident est disponible immédiatement après la
configuration du FPGA, de sorte que le démarrage à froid ne dépend pas d'un
premier téléchargement de code via le débogueur.

Les emplacements source pertinents sont :

* :hazard3-src:`example_soc.v <example_soc/soc/example_soc.v>` - vecteur de reset CPU et intégration mémoire/périphériques du SoC.
* :hazard3-src:`fpga_ulx3s.v <example_soc/fpga/fpga_ulx3s.v>` - profondeur SRAM 128 Kio, nom du fichier de préchargement, options de carte et paramètres CPU sélectionnés.
* :hazard3-src:`hazard3_boot.hex <example_soc/soc/hazard3_boot.hex>` - image générée d'initialisation du moniteur résident dans cet instantané du fork.

Voir :doc:`../memory-map` pour la cartographie mémoire visible par le logiciel
Hazard3-Doom.

La DRAM externe n'est pas une fonctionnalité du CPU Hazard3
-----------------------------------------------------------

La grande image Doom, le heap, les données IWAD et les tampons vidéo résident
dans la mémoire externe du design du projet. Le support de cette mémoire se
trouve dans l'intégration du SoC d'exemple du fork. Les cibles ULX3S et
ULX4M-LS utilisent le chemin SDR SDRAM natif, tandis que l'ULX4M-LD utilise le
chemin DDR3 LiteDRAM.

Il s'agit d'une frontière architecturale essentielle :

* **Responsabilité CPU amont :** exécuter les loads/stores et respecter les réponses ready/error du bus.
* **Responsabilité SoC du projet :** décoder les fenêtres d'adresses de mémoire externe, implémenter les caches/alias configurés, arbitrer les utilisateurs mémoire et piloter l'interface mémoire de la carte.

Un load CPU depuis ``0x20xxxxxx`` n'est pas une « instruction SDRAM » spéciale.
C'est un load RISC-V normal dont l'adresse physique se trouve être routée vers
le sous-système de mémoire externe.

Implémentations des contrôleurs mémoire
---------------------------------------

Hazard3-Doom utilise trois mécanismes mémoire distincts. L'EBR interne de
l'ECP5 est une SRAM bloc synchrone située dans le FPGA et ne nécessite pas de
contrôleur DRAM. Les composants SDR SDRAM et DDR3 de la carte sont des mémoires
externes séparées et nécessitent des contrôleurs qui gèrent le refresh et les
temporisations DRAM.

.. list-table::
   :header-rows: 1
   :widths: 19 20 27 34

   * - Cible/mémoire
     - Interface physique
     - Chemin du contrôleur
     - Comportement important
   * - EBR interne ECP5
     - SRAM synchrone intégrée
     - ``ahb_sync_sram`` / EBR inférée
     - Pas d'activate/precharge, de refresh ni d'entraînement DRAM. C'est la
       mémoire à latence la plus faible et la plus déterministe, mais la
       capacité EBR est limitée.
   * - ULX3S 12F/85F
     - SDR SDRAM externe 16 bits
     - ``ahb_sdram.v`` -> ``ulx3s_sdram_controller.v``
     - Contrôleur SDR natif du projet. Il accepte une requête de contrôleur à la
       fois, garde les lignes ouvertes lorsque possible, utilise une latence CAS
       de 2 et précharge périodiquement pour le refresh. Les requêtes CPU et
       vidéo sont arbitrées dans l'adaptateur AHB/SDRAM.
   * - ULX4M-LS 85F
     - SDR SDRAM externe 16 bits, composant de 32 Mio sur la carte
     - ``ahb_sdram.v`` -> ``ulx3s_sdram_controller.v``
     - Utilise le même sous-système SDR natif que le chemin ULX3S avec une
       horloge système de 50 MHz. Le wrapper de carte transmet une horloge SDRAM
       décalée d'un demi-cycle et conserve la vidéo sur une PLL séparée.
   * - ULX4M-LD 85F
     - DDR3 externe
     - ``ahb_litedram.v`` -> LiteDRAM généré -> ``ECP5DDRPHY``
     - LiteDRAM utilise un port utilisateur à 60 MHz avec une interface Wishbone
       128 bits tandis que Hazard3/AHB fonctionne à 40 MHz. L'adaptateur traverse
       les domaines d'horloge une requête à la fois. Le firmware de démarrage
       effectue l'initialisation DDR3, le read leveling et un test mémoire avant
       d'autoriser les accès normaux.

Les deux chemins de mémoire externe ont donc des compromis de performances
différents. Le contrôleur SDR natif est plus simple et comporte moins de logique
d'interface, mais la SDR SDRAM externe conserve les latences d'activate, CAS et
refresh. La DDR3 offre une bande passante en rafale bien supérieure, tandis que
l'adaptateur ULX4M-LD actuel ajoute la traversée de domaines d'horloge et la
conversion des requêtes. En particulier, l'adaptateur actuel associe chaque
transfert DDR3 BL8 à un mot Wishbone de 128 bits ; les écritures passent par un
read/modify/write atomique de 128 bits avant l'écriture de la rafale complète.
Pour le cœur Hazard3 in-order, la latence du premier accès et le comportement du
cache peuvent compter davantage que le débit DDR maximal.

Ne confondez pas la SDRAM externe de l'ULX3S avec l'EBR ECP5. L'EBR est une SRAM
physiquement intégrée au FPGA ; le composant SDR SDRAM est un circuit séparé sur
la carte. LiteDRAM n'est pas utilisé dans le chemin SDR natif de l'ULX3S.


Configuration et qualification DDR3 ULX4M-LD
--------------------------------------------

Toutes les cartes de production ULX4M-LD ne contiennent pas nécessairement le
même composant DDR3. Le projet vise à prendre en charge au moins les composants
x16 suivants au moyen de profils LiteDRAM générés séparément :

.. list-table::
   :header-rows: 1
   :widths: 28 22 20 30

   * - Composant
     - Densité
     - Capacité approximative
     - Note du projet
   * - Micron ``MT41K512M16HA``
     - 8 Gbit, x16
     - 1 Gio
     - La carte actuellement qualifiée sur matériel utilise cette famille. Sa
       géométrie LiteDRAM est de 16 bits de ligne, 10 bits de colonne et 3 bits
       de banque.
   * - Alliance ``AS4C256M16D3``
     - 4 Gbit, x16
     - 512 Mio
     - Pris en charge comme population alternative de carte au moyen d'un
       module/profil LiteDRAM généré différent.

La capacité physique de la puce est supérieure à la carte mémoire logicielle
actuelle de Hazard3-Doom. Le projet expose volontairement un profil de mémoire
externe de 64 Mio à ``0x20000000-0x23ffffff`` ainsi que l'alias de diagnostic ;
la capacité physique inutilisée n'est pas nécessaire au logiciel actuel.

Le choix de la puce appartient à la configuration LiteDRAM générée, et non à
``ahb_litedram.v``. L'interface du pont AHB vers LiteDRAM reste identique tandis
que le cœur généré change selon le composant mémoire, le CPU d'initialisation, la
fréquence et d'autres paramètres du profil de build. Les différences de
population de carte restent ainsi hors de l'interface du bus système Hazard3.

Les réglages LiteDRAM actuellement qualifiés sur matériel sont :

.. code-block:: text

   memtype: DDR3
   phy: ECP5DDRPHY
   input/reference clock: 25 MHz
   LiteDRAM user clock: 60 MHz
   LiteDRAM init clock: 25 MHz
   Hazard3/AHB system clock: 40 MHz
   user port: 128-bit Wishbone
   cmd_buffer_depth: 2
   cmd_buffer_buffered: true
   with_auto_precharge: true
   initialization CPU: SERV for the qualified checkpoint

``cmd_buffer_depth=0`` a été rejeté pendant les expériences de timing car il
créait des boucles combinatoires/problèmes de timing. Le profil qualifié conserve
une profondeur de 2. ``with_auto_precharge`` reste ``true`` dans la configuration
qualifiée.

Le CPU d'initialisation (SERV ou VexRiscv, par exemple) fait partie du cœur
LiteDRAM généré et ne modifie pas l'interface de bus ``ahb_litedram.v``. Conservez
des profils générés séparés afin que le type de CPU, le composant DDR et la
fréquence d'horloge utilisateur puissent être balayés par programme sans modifier
manuellement le Verilog généré.

Les profils YAML versionnés sont la source modifiable de ces cœurs générés.
Sélectionnez la référence physique de la RAM ; une commande régénère les deux
variantes de CPU :

.. code-block:: bash

   cd third_party/Hazard3/example_soc/third_party/LiteDRAM
   ./regenerate-ulx4m.sh MT41K512M16HA
   ./regenerate-ulx4m.sh AS4C256M16D3

Chaque invocation remplace ``generated-serv/`` et ``generated-vexrisc/`` par le
profil RAM choisi. Confirmez le ``ram_part`` enregistré dans
``LITEDRAM_VERSIONS.txt`` de chaque répertoire généré avant de construire pour
une carte.

La qualification matérielle ne se limite pas à un PASS de timing nextpnr. Sur la
carte Micron qualifiée, le moniteur a réussi tous les tests suivants avec le
routage LiteDRAM à 60 MHz :

* test séquentiel destructif de 1 Mio avec accès octet/demi-mot/mot et motifs
  zéro, un, adresse et adresse inversée ;
* test clairsemé d'alias/adresse sur toute la fenêtre logicielle de 64 Mio ;
* tests pseudo-aléatoires de 1 Mio dans quatre régions espacées de 16 Mio ;
* suite complète de qualification ``q``, répétée ;
* test d'allocation/de charge du tas de 40 Mio ;
* test rapide mémoire/timer de la plate-forme Doom ; et
* exécution depuis la DDR de code RV32 copié, avec phases GP normale et étrangère,
  interruptions de timer et contrôles de garde.

La commande d'état fait autorité après le démarrage. Lors d'une mise au point,
le moniteur résident a affiché un ``TIMEOUT`` de mémoire externe de 5 secondes
alors que LiteDRAM se calibrait encore, mais un ``s`` ultérieur indiquait
``external_memory_ready=YES``, ``init_done=YES``, ``init_error=NO``,
``pll_locked=YES``, ``user_clock_ready=YES`` et ``ready=YES``. Tous les tests de
qualification qui ont suivi ont réussi. Un message de timeout au démarrage ne
doit donc pas être considéré comme un échec DDR définitif sans vérifier l'état
actuel.

Ordonnancement mémoire et ``fence.i``
-------------------------------------

Le projet active ``Zifencei``. ``fence.i`` sert à synchroniser le fetch
d'instructions avec les écritures antérieures qui peuvent avoir modifié la
mémoire d'instructions. Hazard3 exporte l'intention d'ordonnancement mémoire et
de flush du fetch afin que le système environnant puisse y participer lorsque
nécessaire. Cela devient plus important lorsqu'un SoC gagne des caches ou
d'autres états entre le cœur et la mémoire.

Pour du code auto-modifiant ou un chargeur qui écrit de la mémoire exécutable
puis saute dedans, la séquence conceptuelle à comprendre est :

.. code-block:: text

   write new instruction bytes
          |
          v
   complete required data ordering
          |
          v
       fence.i
          |
          v
   fetch newly written instructions

Le chemin exact de chargement logiciel dans Hazard3-Doom est géré par le
moniteur résident et le système mémoire du projet, mais le mécanisme de
synchronisation du fetch d'instructions est un comportement standard
RISC-V/Hazard3.

Pas de MMU dans ce projet
-------------------------

Cette configuration est un système embarqué bare-metal. Elle n'active pas de
MMU de mémoire virtuelle et n'active pas l'isolation mode utilisateur/PMP. Les
adresses de :doc:`../memory-map` sont donc à comprendre comme des fenêtres
d'adresses physiques du SoC utilisées directement par le firmware en mode
machine et l'application Doom.

Liens associés
--------------

* `nextpnr-ecp5 <https://github.com/YosysHQ/nextpnr>`_

* `Yosys <https://github.com/YosysHQ/yosys>`_
