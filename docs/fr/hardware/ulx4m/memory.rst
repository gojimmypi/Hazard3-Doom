Mémoire externe : SDRAM et DDR3
===============================

La mémoire externe est la principale différence architecturale entre ULX4M-LS
et ULX4M-LD. Hazard3 exécute toujours des chargements et stockages RISC-V
ordinaires, mais le chemin jusqu'au composant mémoire change complètement.

Voir aussi :doc:`../../architecture/hazard3/memory-and-bus`.

ULX4M-LS : SDR SDRAM native
---------------------------

Le wrapper LS actuel décrit une interface SDR SDRAM 16 bits de 32 MiB et utilise
la même famille de contrôleurs natifs que l'ULX3S :

.. code-block:: text

   Hazard3/AHB -> ahb_sdram.v -> ulx3s_sdram_controller.v -> SDR SDRAM 16 bits

Le profil utilise une horloge système de 50 MHz et une géométrie de 9 bits de
colonne. Le contrôleur gère activation, précharge, CAS, rafraîchissement, masques
d'octets et arbitrage avec la vidéo.

ULX4M-LD : DDR3 LiteDRAM
------------------------

.. code-block:: text

   Hazard3 40 MHz -> AHB5 -> ahb_litedram.v -> CDC
       -> Wishbone 128 bits 60 MHz -> LiteDRAM -> ECP5DDRPHY -> DDR3 x16

Le coeur généré LiteDRAM possède la géométrie, l'initialisation, la planification
des commandes, le rafraîchissement et le PHY DDR. ``ahb_litedram.v`` conserve
la même interface côté processeur lorsque la puce DDR change.

Profils DDR3 pris en charge
---------------------------

.. list-table::
   :header-rows: 1
   :widths: 29 20 20 31

   * - Sélection projet
     - Densité
     - Capacité
     - Classe LiteDRAM
   * - ``MT41K512M16HA``
     - 8 Gbit x16
     - 1 GiB
     - ``MT41K512M16``
   * - ``AS4C256M16D3``
     - 4 Gbit x16
     - 512 MiB
     - ``AS4C256M16D3A``

Le profil logiciel Doom actuel n'expose volontairement que 64 MiB de mémoire
externe; la capacité physique supplémentaire n'a pas besoin d'être mappée.

Profil généré actuel
--------------------

Les métadonnées SERV et VexRisc incluses dans cette version correspondent à la
famille Micron ``MT41K512M16HA``. Les deux enregistrent :

.. code-block:: text

   FPGA: LFE5UM-85F-8BG381C
   LiteDRAM: 2024.12
   LiteX: 2024.12
   input/init clock: 25 MHz
   Hazard3 system clock: 40 MHz
   LiteDRAM user clock: 60 MHz
   DDR clock: 120 MHz
   user port: 128-bit Wishbone
   command buffer depth: 2
   command buffer buffered: true
   auto precharge: true

Le cœur généré peut utiliser SERV ou un VexRiscv minimal comme CPU
d'initialisation LiteX. Ce CPU appartient à l'environnement d'initialisation
DDR ; ce n'est pas le processeur Hazard3 qui exécute ensuite Doom.

.. _fig-alliance-ddr3-variants:

.. figure:: ../../images/as4c256m16d3-flavors.png
   :alt: Variantes de codes de commande Alliance Memory AS4C256M16D3

   **Variantes de la famille Alliance AS4C256M16D3** - les détails du code de
   commande sont importants pour identifier la DDR3 montée ; relevez le marquage
   complet du boîtier et pas seulement le nom de famille de base.

Régénération pour la RAM montée
-------------------------------

Ne modifiez pas manuellement le Verilog LiteDRAM généré. Utilisez les profils
YAML :

.. code-block:: bash

   cd third_party/Hazard3/example_soc/third_party/LiteDRAM
   ./regenerate-ulx4m.sh MT41K512M16HA

ou :

.. code-block:: bash

   ./regenerate-ulx4m.sh AS4C256M16D3

Le générateur produit les variantes ``generated-serv/`` et
``generated-vexrisc/`` et enregistre leur provenance.

.. important::

   Le coeur généré doit correspondre à la DDR3 réellement montée. Une page de
   campagne, un vieux schéma ou la carte d'un autre utilisateur ne suffit pas à
   identifier votre composant.

Géométrie et identification
---------------------------

Pour une DDR3 x16, la géométrie d'adressage fournit un indice visible par le
logiciel. Les deux familles actuellement prises en charge diffèrent par le
nombre de lignes et la classe de capacité. Hazard3-Doom peut utiliser un sondage
mémoire destructif pendant les diagnostics pour distinguer un motif d'alias de
classe 512 Mio d'un motif de classe 1 Gio, mais il faut le considérer comme un
contrôle de géométrie/probabilité et non comme un lecteur électronique de
référence JEDEC.

Lorsque vous documentez une carte, consignez si possible :

* le marquage du boîtier mémoire monté ;
* la référence complète du fabricant si elle est connue ;
* la révision du PCB ;
* la source de schéma/assemblage utilisée pour la comparaison ;
* le nom du profil LiteDRAM généré ; et
* le résultat de qualification matérielle.

Qualification DDR3
------------------

La fermeture du timing ne suffit pas. Le chemin Micron qualifié pour la version
a été testé avec des motifs séquentiels destructifs, des contrôles clairsemés
d'alias/adresse, des tests pseudo-aléatoires dans des régions mémoire séparées,
la suite complète de qualification du moniteur, un test de charge du tas, un
test rapide de la plate-forme Doom et l'exécution depuis la DDR de code RV32
copié.

Cette séquence est volontairement plus stricte que « LiteDRAM s'est calibrée ».
La calibration prouve que la PHY a terminé son initialisation ; elle ne prouve
pas que chaque ligne d'adresse, voie de données, interaction de cache ou accès
logiciel de longue durée est correct.

Interface électrique
---------------------

Le niveau supérieur LD expose une interface DDR3 x16 classique : adresse, trois
bits de banque, RAS/CAS/WE, CKE, CS, ODT, reset, deux voies de masque de données,
seize bits DQ bidirectionnels, deux voies d'octet DQS et une horloge
différentielle. Le LPF associe ces signaux aux broches du boîtier ECP5 et applique
des contraintes d'E/S SSTL/différentielles adaptées à la DDR3.

Ces contraintes font partie du contrôleur mémoire. Un YAML LiteDRAM correct avec
un LPF incorrect ne constitue pas une conception DDR3 valide.

Références externes
-------------------

* `LiteDRAM <https://github.com/enjoy-digital/litedram>`_ - générateur
  configurable de contrôleur/PHY DRAM utilisé par le chemin ULX4M-LD.
* `Page produit Alliance Memory AS4C256M16D3 <https://www.alliancememory.com/as4c256m16d3/>`_ -
  famille de composants actuelle et liens vers les fiches techniques.
* `Ressources Lattice ECP5 / ECP5-5G <https://www.latticesemi.com/ecp5>`_ -
  fiches techniques de la famille FPGA et documentation liée à la DDR.
* :doc:`sources` - schémas ULX4M, dépôts des cartes et hiérarchie des sources du projet.
