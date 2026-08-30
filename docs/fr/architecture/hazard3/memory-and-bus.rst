Mémoire et interface de bus
===========================

Hazard3 sépare le pipeline du processeur de la cartographie mémoire système.
Cette séparation est particulièrement importante dans Hazard3-Doom car la
plupart des gros mécanismes mémoire et graphiques sont des ajouts propres au SoC
du projet, et non une partie du cœur CPU.

Interfaces de transaction côté cœur
-----------------------------------

`hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_ possède des canaux logiquement séparés pour :

* le fetch d'instructions ; et
* les accès de données load/store.

Cela permet d'encapsuler le même cœur dans différentes architectures système.
Les wrappers Hazard3 standard illustrent deux choix courants :

``hazard3_cpu_2port``
   Conserve le trafic AHB5 instructions et données sur des ports maîtres séparés.

``hazard3_cpu_1port``
   Arbitre les requêtes instructions et données sur un port maître AHB5 unique.

Hazard3-Doom instancie
`hazard3_cpu_1port.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_cpu_1port.v>`_. C'est le premier endroit où un étudiant doit distinguer le **parallélisme du pipeline** du **parallélisme du bus mémoire** : F et M peuvent tous deux avoir besoin d'accéder à la mémoire, mais le wrapper un port doit sérialiser les accès vers l'interface maître externe partagée.

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

* `example_soc.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/example_soc.v>`_ - vecteur de reset CPU et intégration mémoire/périphériques du SoC.
* `fpga_ulx3s.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/fpga/fpga_ulx3s.v>`_ - profondeur SRAM 128 Kio, nom du fichier de préchargement, options de carte et paramètres CPU sélectionnés.
* `hazard3_boot.hex <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/hazard3_boot.hex>`_ - image générée d'initialisation du moniteur résident dans cet instantané du fork.

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
     - LiteDRAM utilise un port utilisateur à 75 MHz avec une interface Wishbone
       128 bits tandis que Hazard3/AHB fonctionne à 50 MHz. L'adaptateur traverse
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
