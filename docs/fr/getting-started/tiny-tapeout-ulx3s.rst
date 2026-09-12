Builds FPGA Tiny Tapeout sur ULX3S
==================================

Hazard3-Doom contient également un petit projet compatible Tiny Tapeout utilisé
comme test de fumée pour le flux FPGA Tiny Tapeout sur ULX3S. Ce flux est séparé
du build FPGA Hazard3-Doom normal : le flux Tiny Tapeout encapsule un module
utilisateur ``tt_um_*`` dans un top level spécifique à l'ULX3S et construit ce
module pour le FPGA ECP5. Il ne synthétise **pas** le CPU Hazard3 complet, le
contrôleur SDRAM, le framebuffer HDMI, le moniteur résident et l'application
Doom.

La prise en charge Tiny Tapeout pour ULX3S est actuellement développée dans les
branches ``experimental`` de ces forks maintenus par ULX3S :

* `ulx3s/tt-gds-action <https://github.com/ulx3s/tt-gds-action/tree/experimental>`_
  fournit l'Action GitHub réutilisable utilisée par le workflow d'un projet
  Tiny Tapeout.
* `ulx3s/tt-support-tools <https://github.com/ulx3s/tt-support-tools/tree/experimental>`_
  contient l'outil Python de build FPGA, le wrapper ULX3S et les contraintes LPF
  ULX3S.

* `tt-fpga-ulx.yaml <https://github.com/ulx3s/Hazard3-Doom/blob/main/.github/workflows/tt-fpga-ulx.yaml>`_

.. admonition:: État de la branche expérimentale
   :class: important

   Les exemples de cette page utilisent volontairement ``@experimental``. Ne
   les remplacez pas par ``@main`` uniquement pour rendre le workflow plus
   conventionnel. La prise en charge ULX3S est encore en cours d'intégration.
   Lorsque les dépôts ULX3S publieront cette prise en charge sur une branche ou
   un tag stable, mettez à jour ensemble les références de l'action et des
   support-tools afin que le wrapper, l'interface en ligne de commande et le
   workflow restent compatibles.

Rôle des deux dépôts
--------------------

Les deux dépôts ont des fonctions différentes.

``ulx3s/tt-gds-action``
   C'est le point d'entrée GitHub Actions. L'action composite ULX3S est
   ``fpga/ulx3s/action.yml``. Elle récupère les outils de support, installe leurs
   dépendances Python, crée la configuration utilisateur Tiny Tapeout, installe
   une version épinglée d'OSS CAD Suite, exécute l'étape de hardening FPGA ECP5,
   puis téléverse les fichiers de build produits comme artifact du workflow.

``ulx3s/tt-support-tools``
   C'est ici que se trouve l'implémentation du build FPGA. ``tt_fpga.py`` lit
   les métadonnées du projet Tiny Tapeout, génère un wrapper spécifique à la
   carte, exécute Yosys, nextpnr-ecp5 et ecppack, puis écrit le bitstream ECP5 et
   les logs produits sous ``build/``.

Cette séparation est utile pour le diagnostic. Un problème de workflow/YAML se
situe normalement dans la couche action ; un problème de synthèse, de wrapper,
de mapping des broches, de périphérique ECP5 ou de placement-routage se situe
normalement dans la couche support-tools.

Structure requise du projet Tiny Tapeout
----------------------------------------

Le flux attend la structure habituelle des métadonnées et sources d'un projet
Tiny Tapeout. Dans Hazard3-Doom, les fichiers concernés sont :

.. code-block:: text

   info.yaml
   src/
       config.json
       project.v

``info.yaml`` est particulièrement important. Il fournit le nom ``top_module``
et la liste des fichiers source Verilog. Le module supérieur doit utiliser
l'interface Tiny Tapeout ``tt_um_*``. Hazard3-Doom utilise actuellement le petit
module de test de fumée ``tt_um_ulx3s_example`` dans ``src/project.v``.

Le builder FPGA peut être utilisé sans ``info.yaml`` en fournissant manuellement
les options de source et de module supérieur, mais le workflow du dépôt utilise
volontairement les métadonnées Tiny Tapeout standard afin que la même
description de projet reste utile pour les flux ASIC et FPGA.

Workflow GitHub Actions
-----------------------

Le job ULX3S utilisé par Hazard3-Doom est :

.. code-block:: yaml

   fpga-ulx3s:
     runs-on: ubuntu-24.04
     steps:
       - name: checkout repo
         uses: actions/checkout@v7
         with:
           submodules: recursive

       - name: FPGA bitstream for TT ASIC Sim (ULX3S ECP5)
         uses: ulx3s/tt-gds-action/fpga/ulx3s@experimental
         with:
           ecp5-device: 85k
           lpf: tt/fpga/ulx3s/ulx3s_v20.lpf
           artifact-name: fpga_ulx3s_ecp5
           uart-enabled: true

Ce job peut être placé à côté du job FPGA Tiny Tapeout habituel. Le workflow
Hazard3-Doom actuel construit également la cible iCE40 UP5K avec l'action
``fpga/ice40up5k`` correspondante, de sorte que le même projet TT est testé au
travers de deux implémentations FPGA.

Pourquoi utiliser un checkout récursif
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``submodules: recursive`` récupère le projet exactement tel qu'il est représenté
par le dépôt, y compris les dépendances source représentées par des sous-modules
Git. L'action ULX3S effectue ensuite son propre checkout de ``tt-support-tools``
dans un répertoire de travail nommé ``tt``. Il s'agit de deux checkouts distincts :

#. le premier checkout est le projet Tiny Tapeout à construire ;
#. le second checkout fournit les outils de build Tiny Tapeout.

Entrées de l'action
-------------------

``ecp5-device``
   Sélectionne la densité ECP5 transmise à ``tt_fpga.py`` puis à nextpnr-ecp5.
   Hazard3-Doom utilise ``85k`` pour la carte ULX3S 85F. L'outil de support
   actuel accepte ``12k``, ``25k``, ``45k`` et ``85k`` pour les cibles ECP5.

``lpf``
   Chemin vers le Lattice Preference File contenant les contraintes physiques
   de broches et d'horloge de l'ULX3S. Hazard3-Doom sélectionne explicitement
   ``tt/fpga/ulx3s/ulx3s_v20.lpf`` pour ce workflow. L'action ULX3S réutilisable
   utilise actuellement ``ulx3s_v316.lpf`` par défaut ; conserver le LPF
   explicite évite donc de changer silencieusement les contraintes de la carte
   si la valeur par défaut de l'action évolue. Le fichier v20 sélectionné associe
   ``clk_25mhz`` à l'oscillateur de la carte, contraint ce port à 25 MHz et mappe
   les LED, boutons, GPIO et autres signaux utilisés par le wrapper.

``artifact-name``
   Nom de base de l'artifact GitHub Actions. L'action ajoute le périphérique
   ECP5 sélectionné ; l'exemple produit donc un artifact nommé
   ``fpga_ulx3s_ecp5_85k``.

``uart-enabled``
   Lorsque cette valeur est ``true``, l'action transmet la définition Verilog
   ``UART_ENABLED`` au build FPGA. Cela active le mapping UART optionnel du
   wrapper ULX3S. Utilisez ``false`` pour un projet qui ne souhaite pas ce
   mapping.

L'action composite possède aussi les entrées ``tools-repo`` et ``tools-ref``.
Leurs valeurs par défaut actuelles sont ``ulx3s/tt-support-tools`` et
``experimental``. Elles sont normalement laissées telles quelles afin que
l'action utilise la branche support-tools ULX3S correspondante, mais elles sont
utiles pour tester un fork de développement ou un commit précis.

Ce que l'action exécute
-----------------------

L'action composite ULX3S actuelle effectue les opérations suivantes :

#. Checkout de ``ulx3s/tt-support-tools`` à la référence ``tools-ref`` demandée
   dans ``tt/``.
#. Configuration de Python 3.11 et installation de ``tt/requirements.txt``.
#. Si le projet contient ``test/requirements.txt``, installation de ces
   dépendances également.
#. Exécution de ``tt/tt_tool.py --create-user-config`` afin que les outils de
   support connaissent le module supérieur et la configuration des sources du
   projet.
#. Installation d'OSS CAD Suite avec ``YosysHQ/setup-oss-cad-suite@v4``.
   L'action expérimentale actuelle épingle la version de la suite à
   ``2026-04-26``.
#. Exécution de l'équivalent de la commande de build ULX3S suivante :

   .. code-block:: bash

      python tt/tt_fpga.py harden \
          --name tt_um_fpga_ecp5_85k \
          --fpga-target ulx3s-ecp5 \
          --ecp5-device 85k \
          --lpf tt/fpga/ulx3s/ulx3s_v20.lpf \
          --define UART_ENABLED

#. Téléversement des produits de build et des fichiers de projet associés comme
   artifact GitHub Actions, même si une étape ultérieure signale un échec.

L'argument ``--define UART_ENABLED`` n'est inclus que lorsque
``uart-enabled: true``.

À l'intérieur de ``tt_fpga.py``
-------------------------------

Pour la cible ``ulx3s-ecp5``, ``tt_fpga.py`` génère ``src/_tt_fpga_top.v`` à
partir du template support-tools ``fpga/ulx3s/tt_fpga_top_ulx3s.v``. Le module
utilisateur fictif présent dans ce template est remplacé par le ``top_module``
de ``info.yaml``.

Le wrapper généré est ensuite synthétisé avec les sources du projet. Le flux
ECP5 est conceptuellement :

.. code-block:: text

   info.yaml + src/project.v
              |
              v
   generate src/_tt_fpga_top.v
              |
              v
       Yosys synth_ecp5
              |
              v
       build/<name>.json
              |
              v
         nextpnr-ecp5
              |
              v
      build/<name>.config
              |
              v
            ecppack
              |
              v
        build/<name>.bit

Pour l'exemple de workflow, les fichiers importants sont normalement :

.. code-block:: text

   build/01-synth.log
   build/02-nextpnr.log
   build/tt_um_fpga_ecp5_85k.json
   build/tt_um_fpga_ecp5_85k.config
   build/tt_um_fpga_ecp5_85k.bit

``01-synth.log`` est le premier endroit à consulter pour les problèmes HDL, de
module ou de synthèse. ``02-nextpnr.log`` contient l'utilisation du périphérique,
les informations de placement/routage et le timing. Le fichier ``.bit`` est le
bitstream ECP5 destiné à l'ULX3S.

Comportement du wrapper ULX3S
-----------------------------

Le wrapper actuel fournit volontairement un environnement de test Tiny Tapeout
simple et observable :

* l'oscillateur ULX3S ``clk_25mhz`` pilote l'entrée Tiny Tapeout ``clk`` ;
* le bouton 0 de l'ULX3S pilote l'entrée Tiny Tapeout active-bas ``rst_n`` ;
* Tiny Tapeout ``ena`` est maintenu à l'état haut ;
* ``uo_out[7:0]`` est connecté aux huit LED de l'ULX3S ;
* lorsque ``UART_ENABLED`` est défini, ``gp0`` de l'ULX3S est synchronisé et
  mappé vers Tiny Tapeout ``ui_in[3]`` ;
* lorsque ``UART_ENABLED`` est défini, Tiny Tapeout ``uo_out[4]`` pilote
  ``gp1`` de l'ULX3S comme chemin de transmission UART ;
* ``uio_in`` est maintenu à zéro par ce wrapper, même si le projet expose
  toujours l'interface Tiny Tapeout normale ``uio_out`` et ``uio_oe``.

Ce mapping permet de tester directement un projet TT simple avec les LED, les
boutons et l'UART avant de passer au hardening ASIC ou à une navette physique.

Exécuter le même flux ULX3S localement
--------------------------------------

L'Action GitHub est le chemin reproductible le plus simple, mais les mêmes
outils de support peuvent être exécutés localement. Depuis la racine d'un
projet Tiny Tapeout :

.. code-block:: bash

   git clone --branch experimental \
       https://github.com/ulx3s/tt-support-tools.git tt
   python3 -m pip install -r tt/requirements.txt
   python3 tt/tt_tool.py --create-user-config

Yosys, ``nextpnr-ecp5``, Project Trellis/``ecppack`` et leurs données de
périphériques ECP5 doivent également être disponibles dans ``PATH``. L'Action
GitHub les fournit via sa configuration OSS CAD Suite épinglée ; un build local
peut utiliser une installation OSS CAD Suite équivalente.

Exécutez ensuite explicitement le même build FPGA :

.. code-block:: bash

   python3 tt/tt_fpga.py harden \
       --name tt_um_fpga_ecp5_85k \
       --fpga-target ulx3s-ecp5 \
       --ecp5-device 85k \
       --lpf tt/fpga/ulx3s/ulx3s_v20.lpf \
       --define UART_ENABLED

Omettez ``--define UART_ENABLED`` pour construire sans le mapping UART
optionnel.

L'outil de support accepte également les variables d'environnement
``TT_FPGA_SEED`` et ``TT_FPGA_FREQ``, qui sont transmises au flux de
placement-routage. Pour une validation normale du projet, utilisez d'abord les
valeurs par défaut du workflow pris en charge au lieu de modifier arbitrairement
les paramètres de routage ; si un projet nécessite un seed ou une cible de
timing différente, consignez ces réglages avec les résultats du test.

Programmer le bitstream généré
------------------------------

Le fichier ``.bit`` local ou téléchargé est un bitstream ECP5 ULX3S normal.
Avec une installation ``fujprog`` compatible, un chargement volatil du FPGA
peut être effectué avec :

.. code-block:: bash

   fujprog build/tt_um_fpga_ecp5_85k.bit

La configuration SRAM du FPGA est perdue lorsque l'alimentation de la carte est
coupée. C'est généralement le comportement souhaité pour un test de fumée Tiny
Tapeout, car il ne remplace pas une image flash persistante. Voir
:doc:`programming` et :doc:`../user-guide/web-flasher` pour les méthodes de
programmation Hazard3-Doom et les considérations liées aux pilotes USB.

Ne confondez pas ``tt_fpga.py harden`` avec
``tt_fpga.py configure --upload``. La sous-commande ``configure`` actuelle fait
partie du chemin de configuration base de données/breakout Tiny Tapeout et
recherche une image ``.bin``. Le build ECP5 ULX3S décrit ici produit un fichier
``.bit`` ; programmez ce bitstream ECP5 avec un outil de programmation FPGA
ULX3S.

Télécharger et vérifier l'artifact GitHub
-----------------------------------------

Après la fin du job ``fpga-ulx3s``, ouvrez l'exécution du workflow et
téléchargez l'artifact ``fpga_ulx3s_ecp5_85k``. L'action est configurée pour
inclure le répertoire ``build/`` ainsi que ``docs/``, ``src/``, ``info.yaml``,
``LICENSE`` et le fichier LPF sélectionné. L'artifact est ainsi utile à la fois
pour programmer la carte et pour diagnostiquer précisément ce qui a été
construit.

Pour un build réussi, vérifiez au minimum :

#. ``build/tt_um_fpga_ecp5_85k.bit`` existe et n'est pas vide ;
#. ``build/01-synth.log`` montre le module supérieur Tiny Tapeout attendu ;
#. ``build/02-nextpnr.log`` identifie le périphérique ECP5 prévu et ne contient
   aucun échec de routage ;
#. le LPF présent dans l'artifact est bien le fichier de contraintes ULX3S
   attendu par le workflow ;
#. le log GitHub Actions montre les références attendues pour
   ``ulx3s/tt-gds-action`` et ``ulx3s/tt-support-tools``.

Dépannage
---------

``No project yaml, must specify ...``
   Le builder n'a pas trouvé le fichier ``info.yaml`` attendu à la racine du
   projet, ou la commande a été exécutée depuis le mauvais répertoire. Utilisez
   la racine normale du projet TT ou fournissez explicitement les options de
   source/module supérieur.

``ulx3s-ecp5 requires --lpf ...``
   La cible ECP5 a besoin d'un fichier de contraintes physiques. Utilisez le LPF
   ULX3S correspondant depuis l'arborescence support-tools récupérée, sauf si
   vous testez volontairement une autre révision de carte ou un autre mapping de
   broches.

Yosys ne trouve pas le module utilisateur
   Vérifiez ``top_module`` dans ``info.yaml``, la liste ``source_files`` et
   ``build/01-synth.log``. Inspectez également le fichier généré
   ``src/_tt_fpga_top.v`` pour confirmer que le placeholder a été remplacé par
   le module ``tt_um_*`` attendu.

nextpnr signale des erreurs de broches ou de package
   Confirmez que ``ecp5-device`` et le LPF correspondent à la carte ULX3S
   réelle. Ne corrigez pas une incompatibilité de carte en supprimant des
   contraintes.

L'UART ne répond pas
   Confirmez que ``uart-enabled: true`` a été utilisé et rappelez-vous que le
   wrapper mappe ``gp0`` vers ``ui_in[3]`` et ``uo_out[4]`` vers ``gp1``. Le
   module Tiny Tapeout lui-même doit implémenter le comportement de
   réception/transmission correspondant ; activer le wrapper n'ajoute pas de
   cœur UART au design utilisateur.

Le workflow fonctionne mais pas un build manuel
   Comparez d'abord les versions des outils. L'Action GitHub épingle
   volontairement OSS CAD Suite et la branche support-tools ``experimental``.
   Une version locale différente de Yosys, nextpnr-ecp5 ou Project Trellis peut
   produire des résultats différents.

Liens associés
--------------

* `Branche experimental de ULX3S tt-gds-action <https://github.com/ulx3s/tt-gds-action/tree/experimental>`_
* `Branche experimental de ULX3S tt-support-tools <https://github.com/ulx3s/tt-support-tools/tree/experimental>`_
* `Workflow TT ULX3S de Hazard3-Doom <https://github.com/ulx3s/Hazard3-Doom/blob/main/.github/workflows/tt-fpga-ulx.yaml>`_
* `Template Tiny Tapeout ULX3S <https://github.com/ulx3s/ttsky-verilog-template/tree/ulx3s>`_
