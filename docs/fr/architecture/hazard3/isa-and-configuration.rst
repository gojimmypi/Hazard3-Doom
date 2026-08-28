ISA et configuration
====================

Hazard3 est fortement paramétrable. Il est important de distinguer trois choses :

#. ce que le RTL Hazard3 est capable d'implémenter ;
#. les valeurs par défaut de la configuration générique ; et
#. ce que le wrapper ULX3S Hazard3-Doom sélectionne réellement.

La liste de paramètres épinglée faisant autorité est
`hazard3_config.vh <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_config.vh>`_. Les valeurs ULX3S sélectionnées se trouvent dans `fpga_ulx3s.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/fpga/fpga_ulx3s.v>`_.

Profil ISA du projet
--------------------

Le profil effectif du projet est une base RV32I avec certaines extensions
standard :

.. list-table::
   :header-rows: 1
   :widths: 18 22 16 44

   * - Fonction ISA
     - Paramètre Hazard3
     - Projet
     - Rôle
   * - RV32I
     - ``EXTENSION_E=0``
     - Activé
     - ISA entière de base 32 bits avec 32 registres.
   * - M
     - ``EXTENSION_M``
     - Activé
     - Multiplication/division/reste entiers.
   * - A
     - ``EXTENSION_A``
     - Désactivé
     - Les opérations mémoire atomiques sont volontairement absentes de ce build.
   * - C
     - ``EXTENSION_C``
     - Activé
     - Encodages d'instructions compressées 16 bits.
   * - Zba
     - ``EXTENSION_ZBA``
     - Activé
     - Opérations de génération d'adresses telles que les formes scaled-add.
   * - Zbb
     - ``EXTENSION_ZBB``
     - Activé
     - Opérations de manipulation de bits de base.
   * - Zbs
     - ``EXTENSION_ZBS``
     - Activé
     - Opérations set/clear/invert/extract sur bit individuel.
   * - Zifencei
     - ``EXTENSION_ZIFENCEI``
     - Activé
     - Synchronisation du fetch d'instructions ``fence.i``.
   * - Zbc
     - ``EXTENSION_ZBC``
     - Désactivé
     - Multiplication sans retenue non synthétisée.
   * - Zbkb
     - ``EXTENSION_ZBKB``
     - Désactivé
     - Opérations de bits de base orientées crypto scalaire non synthétisées.
   * - Zbkx
     - ``EXTENSION_ZBKX``
     - Désactivé par défaut
     - Sous-ensemble de permutation crossbar non sélectionné par le wrapper.
   * - Zcb / Zclsd / Zcmp
     - paramètres correspondants
     - Désactivés par défaut
     - Sous-ensembles supplémentaires d'instructions compressées non sélectionnés.
   * - Zilsd
     - ``EXTENSION_ZILSD``
     - Désactivé par défaut
     - Extension de paires load/store non sélectionnée.

Le comportement ``Zicsr`` est présent car les blocs CSR machine requis par ce
SoC sont activés. ``CSR_COUNTER=1`` active les compteurs de performance et
l'implémentation des CSR Zicntr dans cet instantané Hazard3. Le mode utilisateur
lui-même reste désactivé dans ce projet.

Comment la configuration atteint le cœur
----------------------------------------

Hazard3 conserve ses paramètres de configuration dans un fichier include
partagé et les propage dans la hiérarchie avec ``hazard3_config_inst.vh``. C'est
un modèle pédagogique propre pour un RTL configurable : l'intégrateur de haut
niveau peut modifier une fonctionnalité sans éditer chaque module du pipeline.

Vue simplifiée :

.. code-block:: text

   fpga_ulx3s.v
       sets feature/performance parameters
              |
              v
   example_soc.v
              |
              v
   hazard3_cpu_1port.v
              |
              v
   hazard3_core.v + decoder/CSR/ALU/front end

Le décodeur utilise ensuite ces paramètres pour rendre illégaux les encodages
d'instructions non pris en charge. Voir
`hazard3_decode.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_decode.v>`_ pour le décodage conditionné par les extensions. Par exemple, les opcodes de l'extension M ne sont routés vers le chemin multiplication/division que lorsque ``EXTENSION_M`` est activé, et les encodages atomiques exigent ``EXTENSION_A``.

Configuration des privilèges et de la protection
------------------------------------------------

Le SoC d'exemple ULX3S impose les réglages nécessaires à un système utile en
mode machine :

.. list-table::
   :header-rows: 1

   * - Réglage
     - Valeur effective
     - Signification
   * - ``CSR_M_MANDATORY``
     - 1
     - Support CSR d'identification/état requis au niveau machine.
   * - ``CSR_M_TRAP``
     - 1
     - Support CSR des traps/interruptions machine.
   * - ``U_MODE``
     - 0 (par défaut)
     - Pas d'exécution en mode utilisateur dans ce build.
   * - ``PMP_REGIONS``
     - 0 (par défaut)
     - Aucune région Physical Memory Protection dans ce build.
   * - ``DEBUG_SUPPORT``
     - 1
     - Mode debug et intégration au Debug Module externe activés.
   * - ``BREAKPOINT_TRIGGERS``
     - 0 (par défaut)
     - Aucun slot optionnel de trigger d'adresse d'instruction sélectionné.
   * - ``NUM_IRQS``
     - 1
     - Une entrée d'interruption externe ; le SoC d'exemple y connecte l'IRQ UART.

Ne confondez pas « Hazard3 prend en charge le mode utilisateur/PMP/triggers »
avec « ce bitstream les contient ». Le premier est une capacité du CPU amont ;
le second dépend des paramètres de synthèse.

Réglages orientés performances
------------------------------

Le projet redéfinit également des choix d'implémentation qui ne sont pas des
extensions ISA :

.. list-table::
   :header-rows: 1

   * - Paramètre
     - Valeur projet
     - Effet
   * - ``REDUCED_BYPASS``
     - 0
     - Conserver le réseau normal de forwarding, plus complet.
   * - ``MUL_FAST``
     - 1
     - Activer l'implémentation de multiplication rapide.
   * - ``MUL_FASTER``
     - 1
     - Activer le chemin de multiplication supplémentaire à plus faible latence fourni par cet instantané.
   * - ``MULH_FAST``
     - 1
     - Accélérer les opérations de multiplication de moitié haute.
   * - ``MULDIV_UNROLL``
     - 4
     - Effectuer davantage de travail itératif multiplication/division par cycle que la configuration minimale.
   * - ``FAST_BRANCHCMP``
     - 1
     - Synthétiser le chemin de comparaison rapide de branche.
   * - ``BRANCH_PREDICTOR``
     - 1
     - Activer la petite structure de prédiction des branches arrière.
   * - ``RESET_REGFILE``
     - 0
     - Ne pas dépenser de logique de reset pour effacer les registres généraux.

Conséquence logicielle
----------------------

Le logiciel doit être compilé pour l'ISA réellement présente dans le FPGA, pas
pour le sur-ensemble que Hazard3 peut théoriquement synthétiser. Une sélection
d'architecture représentative pour du code destiné uniquement à cette
configuration est conceptuellement :

.. code-block:: text

   rv32imc + zba + zbb + zbs + zicsr + zifencei

L'orthographe exacte de ``-march`` pour GCC/LLVM doit suivre la syntaxe
d'extensions acceptée par la chaîne d'outils installée et les scripts de build
du projet. En particulier, n'activez pas ``A`` simplement parce que Hazard3
amont prend en charge les atomics.

Amont contre instantané épinglé
-------------------------------

Hazard3 amont actuel continue d'ajouter des fonctionnalités et des améliorations
d'implémentation. Ces changements sont une documentation de référence utile,
mais le commit ULX3S épinglé reste la source correcte pour répondre aux
questions de cycle ou de configuration concernant cette image FPGA précise.

Pour l'étude architecturale, utilisez les deux :

* `Configuration projet épinglée <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_config.vh>`_ - options exactes et valeurs par défaut disponibles dans cet instantané.
* `Configuration stable amont actuelle <https://github.com/Wren6991/Hazard3/blob/stable/hdl/hazard3_config.vh>`_ - direction actuellement maintenue en amont.
