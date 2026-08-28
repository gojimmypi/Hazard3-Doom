Architecture de débogage RISC-V
===============================

Hazard3 comprend une implémentation amont du débogage externe RISC-V. Il s'agit
d'une capacité du processeur/de la plateforme, et non d'un débogueur spécifique
à Doom ajouté par le projet d'application.

Le chemin utilisé sur ULX3S est particulièrement instructif car il montre
comment un protocole standard de débogage RISC-V peut être relié au matériel
JTAG du fournisseur du FPGA.

Chemin de débogage
------------------

La chaîne conceptuelle est :

.. code-block:: text

   GDB
    |
    v
   OpenOCD
    |
    v
   ECP5 chip JTAG TAP
    |
    v
   ECP5 JTAGG custom data registers
    |
    v
   Hazard3 JTAG Debug Transport Module (DTM)
    |
    v
   Debug Module Interface (DMI)
    |
    v
   Hazard3 Debug Module (DM)
    |
    +--> halt/resume CPU
    +--> inject instructions
    +--> access debug data register
    `--> system-bus access

Le transport spécifique à l'ECP5 est implémenté dans
`hazard3_ecp5_jtag_dtm.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/debug/dtm/hazard3_ecp5_jtag_dtm.v>`_. Il utilise la primitive ECP5 ``JTAGG`` pour relier les registres de données DTMCS et DMI au TAP existant de la puce FPGA. Le design peut ainsi utiliser la connexion USB/JTAG normale de la carte au lieu de nécessiter un second TAP JTAG logiciel dans la logique FPGA.

Debug Module
------------

Le Debug Module Hazard3 standard se trouve dans
`hazard3_dm.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/debug/dm/hazard3_dm.v>`_. Il implémente le plan de contrôle entre un débogueur et un ou plusieurs harts Hazard3. Les mécanismes importants comprennent :

* les requêtes d'arrêt et de reprise ;
* les commandes abstraites d'accès aux registres ;
* un registre de débogage ``data0`` partagé avec un hart arrêté ;
* un petit program buffer pour les instructions de débogage injectées ; et
* un accès au bus système permettant au débogueur de lire/écrire la mémoire indépendamment de l'exécution logicielle normale.

Le projet active ``DEBUG_SUPPORT=1`` dans l'instance CPU, ce qui active côté
cœur le mode debug, les CSR de debug, le comportement run/halt et l'interface
d'injection d'instructions requise par le DM.

Injection d'instructions
------------------------

L'injection d'instructions est un aspect élégant du débogage RISC-V. Au lieu de
construire un chemin entièrement séparé vers chaque registre interne du CPU, le
Debug Module peut arrêter le hart et faire exécuter des instructions soigneusement
choisies en mode debug. Ces instructions peuvent déplacer des données entre les
registres architecturaux et le registre de données de débogage.

Le front-end Hazard3 participe directement : lorsqu'il est arrêté en mode debug,
il peut accepter les mots d'instruction fournis par le débogueur à la place du
trafic normal de fetch. Cela réutilise le vrai datapath de décodage/exécution et
maintient le comportement de débogage proche de l'exécution architecturale.

Accès au bus système
--------------------

Le Debug Module peut également demander des transactions mémoire via l'interface
de bus système de débogage du wrapper CPU. Ceci diffère des instructions
injectées : OpenOCD peut examiner ou modifier la mémoire sans demander au
programme arrêté d'exécuter une séquence normale de load/store RISC-V pour
chaque accès.

Le wrapper un port arbitre ce trafic de débogage avec les mêmes ressources de
bus côté SoC utilisées par le processeur. Lors du débogage d'un périphérique
memory-mapped, rappelez-vous qu'une lecture du débogueur peut avoir les mêmes
effets de bord matériels qu'une lecture logicielle si le périphérique définit
des effets de bord à la lecture.

Triggers de breakpoint matériels
--------------------------------

Hazard3 amont peut implémenter des triggers d'adresse d'instruction. Cependant,
le wrapper ULX3S épinglé ne redéfinit pas ``BREAKPOINT_TRIGGERS``, dont la valeur
par défaut épinglée est zéro. Les étudiants ne doivent donc pas supposer que ce
bitstream contient des slots optionnels de triggers d'exécution matériels
simplement parce que le cœur amont sait les prendre en charge.

Les breakpoints logiciels, l'arrêt debug, le single-step pris en charge par la
pile de débogage et les accès mémoire/registres du débogueur sont des mécanismes
séparés de ces comparateurs de triggers optionnels.

Qu'est-ce qui est standard et qu'est-ce qui est spécifique à la carte ?
-----------------------------------------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 40 60

   * - Concept Hazard3/amont standard
     - Sélection du projet ULX3S
   * - RISC-V Debug Module
     - Utilisé directement.
   * - Logique JTAG-DTM Hazard3
     - Utilisée via le wrapper DTM spécifique à l'ECP5.
   * - Adaptateur ECP5 ``JTAGG``
     - Hazard3 amont fournit déjà cette intégration ECP5 ; ce n'est pas une invention Hazard3-Doom.
   * - Configurabilité ``DEBUG_SUPPORT``
     - Activée dans l'instance CPU du projet.
   * - Flux de protocole OpenOCD/GDB
     - Le projet fournit la configuration et les scripts d'assistance pour sa carte et ses artefacts de build.
   * - Triggers optionnels d'adresse d'exécution
     - Non sélectionnés dans cette configuration CPU ULX3S épinglée.

Débogage pratique
-----------------

Voir :doc:`../../user-guide/jtag-debugging` pour le workflow OpenOCD/GDB et
VisualGDB du projet. Cette page d'architecture explique à quoi ces outils
parlent réellement dans le FPGA.

Un exercice de laboratoire utile consiste à arrêter le moniteur résident dans
une fonction connue, inspecter les registres entiers, lire un mot RAM via le
débogueur, exécuter une instruction en single-step, puis identifier lesquelles
de ces opérations ont utilisé l'état debug du CPU et lesquelles ont utilisé
l'accès au bus système.
