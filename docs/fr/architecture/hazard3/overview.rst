Vue d'ensemble du processeur
============================

Hazard3 est une petite implémentation RISC-V 32 bits dotée d'un pipeline
volontairement compact. Ce n'est pas un CPU pédagogique microcodé, mais sa
structure est suffisamment simple pour suivre le chemin d'une instruction du
fetch jusqu'au retrait dans le RTL.

Le centre architectural est
`hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_. Le cœur présente des interfaces de transaction séparées pour le fetch d'instructions et les loads/stores. Des modules wrappers adaptent ensuite ces interfaces internes aux bus AHB5 :

* `hazard3_cpu_1port.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_cpu_1port.v>`_ arbitre le trafic d'instructions et de données sur un port maître AHB5 unique.
* `hazard3_cpu_2port.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_cpu_2port.v>`_ expose des ports maîtres AHB5 indépendants pour les instructions et les données.

Hazard3-Doom utilise le wrapper **un port** ; les fetches d'instructions et les
accès de données partagent donc finalement le même chemin AHB côté SoC.

Trois étages, pas cinq
----------------------

Les introductions à RISC présentent souvent un pipeline à cinq étages nommé
IF, ID, EX, MEM, WB. Hazard3 organise plutôt le processeur en trois grands
étages :

``F`` - fetch et préparation de l'instruction
   Récupère les mots mémoire alignés, met en tampon les demi-mots d'instruction,
   gère l'alignement et l'expansion des instructions compressées et prépare les
   informations sur les registres sources pour l'étage suivant.

``X`` - décodage et exécution
   Décode l'instruction, lit/transfère les opérandes, effectue les opérations
   ALU et de branchement, calcule les adresses, démarre les opérations
   multi-cycles et détermine si l'instruction peut avancer.

``M`` - achèvement mémoire et retrait
   Termine les loads/stores et autres opérations tardives, sélectionne les
   données de writeback, met à jour l'état architectural et effectue les actions
   de trap/debug au retrait.

Cela ne signifie pas que la mémoire n'existe qu'à l'étage M. Le fetch
d'instructions possède son propre trafic mémoire, et une adresse de load/store
est lancée depuis le chemin d'exécution. Les noms d'étages décrivent où se trouve
une instruction dans le pipeline, pas toutes les activités physiques qui ont
lieu pendant ce cycle.

Carte des modules du cœur
-------------------------

.. list-table::
   :header-rows: 1
   :widths: 32 68

   * - Module source
     - Responsabilité
   * - ``hazard3_frontend.v``
     - File de fetch, assemblage/alignement des instructions, gestion des instructions compressées, redirections de fetch et injection d'instructions de débogage.
   * - ``hazard3_decode.v``
     - Traduit les encodages d'instructions RISC-V en contrôles internes ALU, load/store, CSR, branchement et extensions.
   * - ``hazard3_core.v``
     - Registres de pipeline, forwarding, hazards, flux d'exécution, traps et contrôle de haut niveau du cœur.
   * - ``hazard3_alu.v``
     - Support du datapath pour l'arithmétique entière, la logique, les décalages, comparaisons et manipulations de bits.
   * - ``hazard3_mul_fast.v`` / ``hazard3_muldiv_seq.v``
     - Chemins de multiplication rapide et mécanismes itératifs de multiplication/division/reste sélectionnés par la configuration.
   * - ``hazard3_csr.v``
     - CSR machine/debug, état des traps, compteurs, état de privilège, état des interruptions et contrôle optionnel lié au PMP/triggers.
   * - ``hazard3_regfile_1w2r.v``
     - Fichier de registres entiers à deux ports de lecture et un port d'écriture.
   * - ``hazard3_irq_ctrl.v``
     - Extension optionnelle du contrôleur d'interruptions externes Hazard3.
   * - ``hazard3_pmp.v``
     - Correspondance d'adresses et permissions optionnelles Physical Memory Protection.
   * - ``hazard3_triggers.v``
     - Triggers optionnels de débogage par adresse d'instruction.

Fichier de registres entiers
----------------------------

La configuration RV32I normale possède les registres ``x0`` à ``x31``. ``x0``
est architecturalement fixé à zéro. Le fichier de registres de Hazard3 est
organisé pour deux opérandes sources et une écriture destination par cycle, ce
qui correspond à la forme courante des instructions RISC-V :

.. code-block:: text

   add x5, x6, x7
       ^   ^   ^
       |   |   +-- rs2
       |   +------ rs1
       +---------- rd

Le projet laisse ``EXTENSION_E`` désactivé ; il utilise donc l'ensemble complet
de registres RV32I plutôt que l'ensemble réduit RV32E.

Design embarqué en mode machine
-------------------------------

Hazard3 est suffisamment configurable pour prendre en charge davantage de
fonctions de privilège et de protection, mais l'instanciation Hazard3-Doom est
volontairement simple :

* Le support CSR et trap en mode machine est activé.
* Le mode utilisateur n'est pas activé.
* Les régions PMP ne sont pas activées.
* Le chemin standard de débogage externe est activé.
* Une entrée d'interruption externe est configurée ; le SoC d'exemple la relie à l'interruption UART. Le timer de plateforme pilote l'interruption timer machine.
* L'entrée d'interruption logicielle est forcée à zéro dans le SoC d'exemple.

Cela rend le build bien adapté à l'enseignement bare-metal : le code peut
étudier les interruptions, les CSR, les transactions de bus et le comportement
de débogage sans qu'une MMU ou une pile de privilèges d'OS ne masque le chemin.

État amont
----------

Lors de la revue du 2026-08-19, Hazard3 amont actuel se décrivait toujours comme
un processeur RV32I/RV32E à trois étages avec extensions standard configurables,
prise en charge d'exécution machine/utilisateur, PMP, débogage externe et
triggers d'adresse d'instruction. Il s'agit de capacités amont, pas d'inventions
Hazard3-Doom.

La question propre au projet n'est donc pas « qu'est-ce qui a été modifié dans
le CPU RISC-V pour Doom ? », mais plutôt « quelles options Hazard3 ont été
sélectionnées et quel matériel SoC a été placé autour du CPU ? ». Les pages
suivantes répondent en détail à ces deux questions.
