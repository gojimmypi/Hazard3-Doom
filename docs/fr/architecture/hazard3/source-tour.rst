Visite guidée du code source
============================

Cette page est une carte de lecture destinée aux étudiants qui veulent passer
du schéma-blocs au RTL réel. Tous les liens du projet ci-dessous sont épinglés
au commit |hazard3_commit| ; le contenu des lignes ne
changera donc pas silencieusement lorsqu'une branche avance.

Ordre de lecture recommandé
---------------------------

1. Commencer par la configuration
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Commencez avec
:hazard3-src:`hazard3_config.vh <hdl/hazard3_config.vh>` et
:hazard3-src:`hazard3_config_inst.vh <hdl/hazard3_config_inst.vh>`.

Questions auxquelles répondre avant de lire le datapath :

* Quelles extensions ISA cet instantané peut-il synthétiser ?
* Quelles fonctions sont activées ou désactivées par défaut ?
* Quels paramètres affectent l'architecture et lesquels affectent les performances/la surface ?
* Comment les paramètres sont-ils propagés à travers les instances de modules imbriquées ?

Ouvrez ensuite
:hazard3-src:`fpga_ulx3s.v <example_soc/fpga/fpga_ulx3s.v>` et comparez les valeurs du projet à ces valeurs génériques par défaut.

2. Trouver le CPU dans le SoC
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ouvrez
:hazard3-src:`example_soc.v <example_soc/soc/example_soc.v>` et localisez ``hazard3_cpu_1port``. Notez les choix système fixes autour de l'instance : vecteur de reset, support CSR de trap, activation du debug, nombre d'IRQ, interruption UART et interruption timer.

Ouvrez ensuite
:hazard3-src:`hazard3_cpu_1port.v <hdl/hazard3_cpu_1port.v>`. Identifiez trois groupes de signaux :

* le maître AHB5 unique côté SoC ;
* le trafic interne instructions/données connecté à ``hazard3_core`` ; et
* les signaux de contrôle/bus système du débogueur.

Le wrapper constitue une bonne leçon d'adaptation d'interface : le cœur
architectural n'a pas besoin de contenir la politique de partage d'un bus
externe unique.

3. Parcourir le pipeline
~~~~~~~~~~~~~~~~~~~~~~~~

Ouvrez :hazard3-src:`hazard3_core.v <hdl/hazard3_core.v>` et recherchez les titres des étages. Suivez :

* les entrées de l'étage F venant du front-end ;
* les signaux de décodage/exécution de l'étage X ;
* l'ensemble des registres de pipeline X-vers-M ;
* les signaux de writeback et stall de l'étage M ; et
* les chemins de redirection/trap/debug retournant vers le fetch.

N'essayez pas de comprendre chaque fil au premier passage. Suivez une
instruction simple comme ``addi``, puis un load, puis une branche.

4. Étudier le fetch d'instructions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ouvrez
:hazard3-src:`hazard3_frontend.v <hdl/hazard3_frontend.v>` et
:hazard3-src:`hazard3_instr_decompress.v <hdl/hazard3_instr_decompress.v>`.

Recherchez :

* la FIFO de préfetch à deux mots ;
* le tampon des demi-mots d'instruction ;
* la sélection instruction compressée ou 32 bits ;
* les redirections du PC de fetch ;
* les hooks de vérification des permissions d'exécution PMP ; et
* l'injection d'instructions de débogage.

Exercice : dessinez les demi-mots nécessaires lorsqu'une instruction 32 bits
commence à une adresse se terminant par ``...2`` avec ``C`` activé.

5. Décoder quelques instructions
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ouvrez :hazard3-src:`hazard3_decode.v <hdl/hazard3_decode.v>`. Choisissez une instruction de chaque classe :

* ``add`` - ALU entière de base ;
* ``lw`` - chemin load/store ;
* ``beq`` - chemin de branche ;
* ``mul`` - extension M ;
* une instruction scaled-add Zba ; et
* un encodage d'instruction atomique avec ``EXTENSION_A=0``.

Le dernier exemple est particulièrement utile : les paramètres de configuration
participent à la vérification de légalité, de sorte que la configuration de
synthèse devient visible au logiciel via les traps d'instruction illégale.

6. Suivre l'ALU et l'extension M
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Les sources arithmétiques pertinentes comprennent :

* :hazard3-src:`hazard3_alu.v <hdl/arith/hazard3_alu.v>`
* :hazard3-src:`hazard3_mul_fast.v <hdl/arith/hazard3_mul_fast.v>`
* :hazard3-src:`hazard3_muldiv_seq.v <hdl/arith/hazard3_muldiv_seq.v>`

Comparez le multiplicateur rapide à l'unité itérative et reliez-les à
``MUL_FAST``, ``MUL_FASTER``, ``MULH_FAST`` et ``MULDIV_UNROLL``. C'est un
exercice pratique d'architecture FPGA sur l'échange coût LUT/DSP/routage contre
latence.

7. Lire l'état CSR et trap
~~~~~~~~~~~~~~~~~~~~~~~~~~

Ouvrez :hazard3-src:`hazard3_csr.v <hdl/hazard3_csr.v>`. Recherchez ces noms dans l'ordre :

.. code-block:: text

   MSTATUS
   MTVEC
   MEPC
   MCAUSE
   MIE
   MIP
   MCYCLE
   MINSTRET
   DCSR

Remarquez que la présence des CSR est paramétrée. Revenez ensuite à
``hazard3_core.v`` et trouvez où l'entrée et le retour de trap pilotent la
redirection du pipeline.

8. Lire la pile de débogage
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Utilisez cet ordre :

* :hazard3-src:`hazard3_dm.v <hdl/debug/dm/hazard3_dm.v>` - état du Debug Module, commandes abstraites, program buffer et accès au bus système.
* :hazard3-src:`hazard3_ecp5_jtag_dtm.v <hdl/debug/dtm/hazard3_ecp5_jtag_dtm.v>` - transport DMI via ECP5 JTAGG.
* ``hazard3_frontend.v`` et ``hazard3_core.v`` - arrêt/mode debug côté cœur et comportement des instructions injectées.

Comparez ensuite le flux matériel aux commandes de
:doc:`../../user-guide/jtag-debugging`.

9. Franchir la frontière CPU/SoC
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Ce n'est qu'après avoir compris le wrapper CPU qu'il faut étudier les ajouts SoC
propres au projet :

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Source épinglée
     - Ce qu'il faut apprendre
   * - :hazard3-src:`ahb_sdram.v <example_soc/soc/ahb_sdram.v>`
     - Comment le trafic CPU AHB normal est adapté au comportement de la SDRAM externe.
   * - :hazard3-src:`ulx3s_sdram_controller.v <example_soc/soc/ulx3s_sdram_controller.v>`
     - Timing commandes/données de la SDR SDRAM orienté carte.
   * - :hazard3-src:`apb_sd_spi.v <example_soc/soc/apb_sd_spi.v>`
     - Un périphérique APB compact et sa machine d'états SPI.
   * - :hazard3-src:`apb_sao_bridge.v <example_soc/soc/apb_sao_bridge.v>`
     - Contrôle memory-mapped du projet autour du sous-système SAO.
   * - :hazard3-src:`sao_shared_controller.v <example_soc/soc/sao_shared_controller.v>`
     - Politique de propriété/arbitrage des ressources partagées de la carte.
   * - :hazard3-src:`sao_esp32_uart_bridge.v <example_soc/soc/sao_esp32_uart_bridge.v>`
     - Communication latérale du projet avec l'ESP32.

Cet ordre évite une erreur courante de lecture du code : supposer que chaque
module sous ``example_soc`` fait partie du processeur Hazard3.

Questions de laboratoire suggérées
----------------------------------

Pipeline
   Quels motifs de dépendance sont satisfaits par bypass, et lesquels forcent X
   à attendre M ?

ISA compressée
   Pourquoi le bus peut-il récupérer des mots alignés 32 bits alors que le PC
   architectural n'est aligné que sur 16 bits ?

Configuration
   Quel symptôme logiciel apparaîtrait si un binaire contenait une instruction
   ``amo*`` dans ce build ``EXTENSION_A=0`` ?

Interruptions
   Suivez le fil IRQ UART depuis le périphérique UART jusqu'à
   ``hazard3_cpu_1port``, puis jusqu'à ``mip``/la sélection du trap.

Débogage
   Quelles opérations du débogueur exigent que le hart exécute des instructions
   injectées, et lesquelles peuvent utiliser l'accès au bus système ?

Intégration
   Choisissez une adresse SDRAM dans :doc:`../memory-map` et suivez comment le
   load/store ordinaire du CPU devient une transaction SDRAM externe.

Comparaison amont
-----------------

Après avoir étudié les fichiers épinglés, ouvrez
`la branche stable amont actuelle <https://github.com/Wren6991/Hazard3/tree/stable>`_ et comparez les mêmes modules. Considérez les changements présents comme une évolution amont du processeur jusqu'à ce que le projet Hazard3-Doom mette à jour son sous-module épinglé. Cette habitude maintient l'archéologie du code reproductible.
