Référence des scripts
=====================

Le répertoire ``scripts/`` contient les outils côté hôte utilisés par
Hazard3-Doom pour le build, la configuration, la programmation, le débogage, la
validation, les benchmarks, l'audit des sources et le nettoyage. Cette page
décrit les scripts versionnés par objectif et indique quels outils font autorité
pour les tâches de maintenance courantes.

La plupart des scripts Bash déterminent la racine du dépôt à partir de leur
propre emplacement. Sauf indication contraire d'un script, les exemples
ci-dessous supposent que le répertoire courant est la racine du dépôt
Hazard3-Doom.

Pour un résumé plus court organisé par répertoire, voir ``scripts/README.md``
dans le dépôt.

Builds complets des cartes
--------------------------

Les wrappers complets de cartes maintiennent le moniteur, le design FPGA,
l'image Doom et la cartographie mémoire SDRAM cohérents.

``scripts/build-ulx3s-doom.sh``
   Build complet ULX3S 85F. Il construit le moniteur 50 MHz/64 Mio, prépare
   l'image de boot résidente du FPGA, construit ou réutilise le bitstream 85F,
   construit l'image Doom et prépare les fichiers utilisés par le workflow de
   carte SD. Le wrapper 85F active par défaut les modes HDMI étendus ; réglez
   ``HAZARD3_HDMI_EXTENDED_MODES=0`` pour le profil framebuffer allégé limité à
   320x200.

``scripts/build-ulx3s-12f-doom.sh``
   Build compact complet ULX3S 12F. Le profil par défaut utilise 32 Mio de
   mémoire à 40 MHz pour l'horloge système Hazard3. La cartographie 64 Mio est
   optionnelle via ``HAZARD3_MEMORY_PROFILE=64m``. La cible compacte accepte
   volontairement uniquement ``HAZARD3_DOOM_HDMI_RESOLUTION=320x200`` et utilise
   un moniteur résident en SDRAM.

``scripts/build-ulx4m-ld-doom.sh``
   Build complet ULX4M-LD 85F. Il utilise la cartographie logicielle 64 Mio à 40 MHz et
   vérifie les sources LiteDRAM générées requises avant de construire le
   moniteur, l'image de boot embarquée, le bitstream FPGA et l'image Doom. Le
   routage actuel présente des échecs de timing connus pour ``clk_sys`` et
   LiteDRAM ; utilisez ``ALLOW_TIMING_FAILURE=1`` lorsque vous générez
   intentionnellement le bitstream de développement actuel.

Exemples :

.. code-block:: bash

   ./scripts/build-ulx3s-doom.sh
   ./scripts/build-ulx3s-12f-doom.sh
   ALLOW_TIMING_FAILURE=1 ./scripts/build-ulx4m-ld-doom.sh

Pour tester un autre checkout Hazard3 sans modifier le gitlink Hazard3-Doom :

.. code-block:: bash

   HAZARD3_ROOT=/mnt/c/workspace/Hazard3 \
       ./scripts/build-ulx3s-doom.sh

Outils de build du moniteur et du bitstream
-------------------------------------------

``scripts/build.sh``
   Construit le firmware du moniteur résident. Le profil par défaut est la
   cartographie 64 Mio à 50 MHz. Les principales substitutions comprennent
   ``HAZARD3_MEMORY_PROFILE``, ``HAZARD3_SYS_CLK_HZ``, ``HAZARD3_BUILD_DIR``,
   ``TOOLCHAIN_PREFIX`` et ``HAZARD3_MONITOR_LINKER_SCRIPT``. Les sorties
   comprennent ``hazard3-boot-monitor.elf``, ``.map`` et ``.bin`` dans le
   répertoire de build sélectionné.

``scripts/build-ulx3s-85f-bitstream.sh``
   Point d'entrée spécifique à l'ULX3S 85F pour le flux ECP5 partagé.

``scripts/build-ulx3s-12f-bitstream.sh``
   Point d'entrée spécifique à l'ULX3S 12F pour le flux ECP5 partagé. Utilise
   par défaut ``HAZARD3_MEMORY_PROFILE=32m``.

``scripts/build-ulx4m-ld-bitstream.sh``
   Point d'entrée spécifique à l'ULX4M-LD 85F pour le flux ECP5 partagé.

``scripts/build-ecp5-bitstream-common.sh``
   Implémentation interne partagée de synthèse/place-and-route utilisée par les
   trois wrappers de bitstream spécifiques aux cartes. Elle n'est normalement
   pas appelée directement. ``ALLOW_TIMING_FAILURE=1`` permet de générer un
   bitstream tout en conservant les échecs de timing visibles comme
   avertissements ; réservez-le à une exception de timing de développement
   explicitement acceptée, comme la cible ULX4M-LD actuelle.

``scripts/make-boot-hex.py``
   Convertit un binaire du moniteur en fichier d'initialisation hexadécimal
   consommé par la mémoire de boot FPGA.

``scripts/build-xpack.cmd``
   Build natif Windows du moniteur avec ``bin/riscv-gcc``. Ses arguments sont
   ``[build|clean|rebuild] [64m|32m] [50000000|25000000]``. Sans argument, il
   construit le moniteur 64 Mio/50 MHz.

Outils de build Doom et Supercon
--------------------------------

``doom/build-doom-image.sh``
   Construit et empaquette l'application Doom liée. Le moniteur et l'image Doom
   doivent utiliser le même profil mémoire.

``scripts/build-doom-noncombat.sh``
   Construit l'image Supercon noncombat dédiée sous
   ``build/doom-image-noncombat/``. Le script applique la transformation
   uniquement à une copie préparée de DoomGeneric et vérifie les symboles
   marqueurs dans les fichiers objets résultants.

``scripts/apply-doom-noncombat.py``
   Transformation interne des sources utilisée par le build noncombat dédié.
   Elle ne modifie pas le sous-module DoomGeneric checkouté.

``scripts/build-supercon10-wad.py``
   Valide et fusionne le PWAD Supercon du projet avec un ``DOOM1.WAD`` local.
   Par défaut, l'image combinée résultante est ``wads/SUPERCON10.WAD``.

``scripts/cleanup-supercon-dev.py.bak``
   Sauvegarde conservée d'un ancien outil de nettoyage de développement
   Supercon. Il ne fait pas partie du workflow normalement pris en charge.

Sweeps de placement et de seeds routés
--------------------------------------

Les sweeps de placement seul classent rapidement les candidats. Ils ne
constituent pas une preuve finale de timing. Utilisez le sweep routé avant de
sélectionner un seed de production.

Pour l'architecture détaillée du sweep, les paramètres GitHub Actions, le modèle
de netlist figé, le moniteur de timing en direct, les watchdogs, les artifacts
et la stratégie d'expériences A/B, voir :doc:`timing-sweeps`.

``scripts/sweep-peek.sh``
   Sweep nextpnr de placement seul pour ULX3S 85F. Il s'arrête avant le routage.
   Sans argument de seed, il analyse la plage configurée ; un seed explicite
   limite l'exécution. ``SWEEP_JOBS`` contrôle le nombre de placements
   concurrents et ``HAZARD3_HDMI_EXTENDED_MODES`` sélectionne le profil vidéo
   85F.

``scripts/sweep.sh``
   Sweep complet place-and-route ULX3S 85F. Accepte des seeds explicites, des
   seeds séparés par des virgules ou ``--all``. ``SWEEP_JOBS`` contrôle les jobs
   de routage concurrents. Les logs routés et bitstreams sont conservés sous
   ``build/ulx3s-seed-sweep/``.

``scripts/sweep-peek-ulx3s-12f.sh``
   Sweep de placement seul ULX3S 12F. Accepte des seeds explicites ou ``--all``.
   Utilise par défaut quatre jobs concurrents et le profil 32 Mio. Les résultats
   sont écrits sous ``build/ulx3s-12f-placement-sweep/<profile>/``.

``scripts/sweep-ulx3s-12f.sh``
   Sweep routé complet ULX3S 12F. Accepte des seeds explicites ou ``--all``.
   Utilise par défaut quatre routages concurrents et le profil 32 Mio. Les logs
   routés, la configuration, les SVF, bitstreams, métadonnées et résultats CSV
   sont conservés sous ``build/ulx3s-12f-seed-sweep/<profile>/``.

``scripts/sweep-peek-ulx3s-12f-best-peek.sh``
   Outil de suivi qui lance un sweep routé pour les meilleurs candidats de
   placement 12F.

``scripts/sweep-ulx4m-ld.sh``
   Sweep de seeds routés ULX4M-LD. Accepte un seed unique ou une plage de seeds
   et utilise deux jobs concurrents par défaut.

``scripts/sweep-ecp5.sh``
   Répartiteur partagé des cibles, utilisé en local et dans GitHub Actions. Il
   énumère les cibles, prépare/résout les chemins et appelle le sweep routé
   spécifique à la cible.

``scripts/sweep-ecp5-common.sh``
   Implémentation nextpnr partagée. Elle valide les paramètres du placer/router,
   construit les arguments nextpnr, applique les watchdogs, analyse les
   fréquences maximales et écrit les CSV/métadonnées par seed.

``scripts/watch-ecp5-sweep-results.sh``
   Collecteur GitHub en direct. Il observe les artifacts de groupes terminés et
   affiche les métriques, les comptes PASS/FAIL/TIMEOUT/OTHER, les durées et les
   meilleures fréquences maximales observées par domaine.

``scripts/summarize-ecp5-sweep.py``
   Agrégateur CI final. Il combine tous les groupes avec les métadonnées et la
   configuration figées, génère les résumés CSV/Markdown et vérifie que le sweep
   est complet.

Exemples :

.. code-block:: bash

   SWEEP_JOBS=8 ./scripts/sweep-peek.sh
   SWEEP_JOBS=8 ./scripts/sweep.sh --all
   SWEEP_JOBS=30 ./scripts/sweep-peek-ulx3s-12f.sh --all
   SWEEP_JOBS=30 ./scripts/sweep-ulx3s-12f.sh --all
   ./scripts/sweep-ulx4m-ld.sh 1-32

Un seed auparavant bon n'est pas garanti de rester bon après une modification
importante du RTL, de l'horloge, du cache, de l'EBR ou du framebuffer.

Initialisation des sous-modules et contrôles d'état local
---------------------------------------------------------

``scripts/setup-submodules.sh``
   Initialise l'ensemble de sous-modules requis pour le build. Le mode normal
   initialise DoomGeneric et Hazard3 au niveau supérieur, puis les sous-modules
   imbriqués ``scripts`` et ``example_soc/libfpga`` de Hazard3. Réglez
   ``HAZARD3_INIT_ALL_SUBMODULES=1`` pour initialiser tous les sous-modules
   récursifs.

``scripts/doomgeneric-version.sh``
   Définit le dépôt/commit DoomGeneric attendu par les outils de build Doom.

``scripts/setup-doomgeneric.sh``
   Valide le checkout DoomGeneric et les fichiers source requis. Les builds de
   développement volontairement sales exigent
   ``HAZARD3_DOOM_ALLOW_DIRTY_DOOMGENERIC=1``.

``scripts/hazard3-submodule.sh``
   Inspecte ou restaure le sous-module Hazard3. ``status`` indique Hazard3 et
   DoomGeneric. ``diff`` et ``restore`` agissent sur Hazard3 ; restore le ramène
   au gitlink enregistré par le HEAD Hazard3-Doom et met à jour ses sous-modules
   imbriqués.

``scripts/update-hazard3-submodule.sh``
   Met explicitement à jour, affiche ou restaure le gitlink Hazard3. Il ne
   modifie volontairement pas ``.gitmodules``. Les commandes sont ``update``,
   ``status`` et ``restore``.

``scripts/check_submodules.bat``
   Contrôle de sécurité de l'état local sous Windows. Pour chaque sous-module
   vérifié, il compare le checkout, l'index parent, le gitlink du HEAD parent,
   l'état dirty et la branche distante configurée. Le remote est sélectionné en
   faisant correspondre l'URL du fichier ``.gitmodules`` approprié au lieu de
   supposer que le bon remote s'appelle ``origin``. En plus des sous-modules de
   premier niveau Hazard3-Doom, il vérifie le gitlink imbriqué
   ``third_party/Hazard3/example_soc/libfpga`` par rapport à l'index et au HEAD
   propres à Hazard3.

Le vérificateur local de sous-modules est volontairement conservateur. Un
pointeur stagé, une mise à jour non enregistrée, une branche en retard,
divergente ou un checkout incohérent est un problème à comprendre avant le
commit.

Audit des forks et branches
---------------------------

``scripts/hazard3-doom-source-status.sh``
   Rapport complet de l'historique des sources à l'échelle du réseau de forks.
   Le script ne dépend pas des remotes configurés dans le working tree. Il crée
   des dépôts Git bare temporaires, récupère toutes les branches de chaque fork
   configuré, découvre la branche par défaut réelle de chaque dépôt depuis le
   HEAD distant et compare les historiques.

   Les familles de sources actuelles sont :

   * Hazard3-Doom : le fork de l'utilisateur actuel et ``ulx3s/Hazard3-Doom``.
   * DoomGeneric : le fork de l'utilisateur actuel, ``ulx3s/doomgeneric`` et ``ozkl/doomgeneric``.
   * Hazard3 : le fork de l'utilisateur actuel, ``ulx3s/Hazard3`` et ``Wren6991/Hazard3``.
   * Hazard3-libfpga/libfpga : le fork ``Hazard3-libfpga`` de l'utilisateur actuel, ``ulx3s/Hazard3-libfpga`` et le canonique ``Wren6991/libfpga``.

   Pour chaque branche, le rapport affiche les nombres ahead/behind par rapport
   à la branche par défaut de son propre dépôt et à la branche par défaut amont
   canonique, ainsi que la date du commit, le SHA et le sujet. Il effectue aussi
   des comparaisons branche-par-défaut à branche-par-défaut et entre branches de
   même nom à travers les forks. ``UNRELATED`` signifie que Git n'a trouvé aucun
   merge base commun.

   La sortie est affichée en direct et écrite simultanément dans
   ``build/source_status.log``. Le premier argument optionnel sélectionne le nom
   d'utilisateur GitHub ; sa valeur par défaut est ``gojimmypi``.

.. code-block:: bash

   ./scripts/hazard3-doom-source-status.sh
   ./scripts/hazard3-doom-source-status.sh gojimmypi

La distinction est importante : ``check_submodules.bat`` valide la sécurité de
l'état local enregistré des sous-modules, tandis que
``hazard3-doom-source-status.sh`` compare la famille plus large de branches et
de forks sur GitHub.

Programmation et OpenOCD
------------------------

``scripts/start-openocd.sh``
   Démarre OpenOCD depuis Linux ou WSL avec la configuration ULX3S du dépôt. Si
   un OpenOCD Windows natif ``.exe`` est lancé depuis WSL, le script convertit le
   chemin de configuration en syntaxe Windows.

``scripts/start-openocd.bat``
   Lanceur OpenOCD natif Windows. Un exécutable OpenOCD explicite peut être
   fourni comme premier argument ; sinon le binaire du dépôt est utilisé.

``scripts/load-firmware.sh``
   Charge l'ELF normal du moniteur via un serveur GDB OpenOCD en cours
   d'exécution, arrête la cible, charge et compare les sections, règle ``$pc``
   sur ``_start``, reprend l'exécution puis se déconnecte. Cela évite de laisser
   GDB attaché après la programmation.

``scripts/load-firmware-12f.sh``
   Charge le moniteur ULX3S 12F résident en SDRAM après programmation du
   bitstream compact et démarrage d'OpenOCD.

``scripts/load-firmware.bat``
   Chargeur natif Windows du moniteur utilisant GDB et OpenOCD.

``scripts/load-fpga-bitstream.bat``
   Outil natif Windows pour charger un bitstream FPGA généré ou préconstruit.

``scripts/flash-ulx3s-persistent.sh``
   Programme ``build/fpga_ulx3s.bit`` dans la flash SPI ULX3S pour un démarrage
   à froid persistant. Ceci est distinct de la programmation SRAM volatile.

Contrôle UART
-------------

``scripts/return-to-monitor.py``
   Envoie Ctrl-X sur l'UART afin qu'une instance Doom en cours quitte vers le
   moniteur résident, puis libère le port série. Les valeurs par défaut sont
   ``/dev/ttyS7`` et 115200 bauds.

``scripts/restart-from-monitor.py``
   Envoie la commande ``j`` du moniteur pour lancer une image Doom/IWAD déjà
   validée, puis libère le port série. Les valeurs par défaut sont
   ``/dev/ttyS7`` et 115200 bauds.

Outils GDB
----------

``scripts/hazard3-debug.gdb``
   Définitions communes de commandes GDB Hazard3 utilisées par la configuration
   de débogage du projet.

``scripts/gdb/load-hazard3-test-elf.gdb``
   Fichier de commandes GDB ciblé pour charger l'ELF de test/moniteur Hazard3.

``scripts/gdb/sao-probe.gdb``
   Sonde l'état du pont SAO depuis GDB.

``scripts/gdb/sao-scan.gdb``
   Exerce le chemin d'analyse I2C SAO depuis GDB.

``scripts/gdb/sao-touchwheel-test.gdb``
   Séquence de test/débogage du touchwheel SAO.

``scripts/gdb/sao-touchwheel-led-off.gdb``
   Éteint la LED du touchwheel via le chemin de débogage GDB.

CoreMark et analyse ELF
-----------------------

``scripts/build-coremark.sh``
   Construit le port Hazard3 CoreMark. ``COREMARK_BUILD_PROFILE`` sélectionne
   ``baseline`` ou ``tuned`` ; le nombre d'itérations, l'horloge système, le
   répertoire de build, le checkout Hazard3 et le préfixe de chaîne d'outils
   peuvent également être remplacés.

``scripts/run-coremark.sh``
   Exécute les images CoreMark ``performance`` ou ``validation``, ou utilisez
   ``qualify`` pour exécuter les deux et résumer le résultat. Un port série peut
   être fourni pour la capture UART automatisée.

``scripts/peek-elf.sh``
   Inspecte une map/un ELF RISC-V, le multilib GCC sélectionné, les membres
   libgcc liés et les attributs ISA finaux. Sans argument, il examine le build
   CoreMark baseline sous ``build/coremark/baseline/``.

Hygiène du dépôt et inventaire généré
-------------------------------------

``scripts/check-executable.sh``
   Vérifie que les scripts shell suivis modifiés dans les commits récents ont le
   bit exécutable Git. La fenêtre par défaut couvre les cinq commits les plus
   récents.

``scripts/git-exe.sh``
   Marque un fichier suivi comme exécutable dans l'index Git et affiche l'entrée
   d'index résultante.

``scripts/check-nettype.sh``
   Valide la gestion Verilog de ``default_nettype``.

``scripts/inventory.sh``
   Inventorie les fichiers suivis par Git pour le chemin demandé et écrit des
   rapports Markdown, TSV et SHA-256 déterministes. Le script demande à Git les
   fichiers suivis plutôt que de parcourir des toolchains ignorées/non suivies.

``scripts/INVENTORY.md``
   Inventaire généré lisible par l'humain du répertoire scripts.

``scripts/INVENTORY.tsv``
   Inventaire généré lisible par machine du répertoire scripts.

``scripts/INVENTORY.sha256``
   Sortie générée de l'inventaire SHA-256.

``scripts/full-clean.sh``
   Nettoie les cibles de synthèse FPGA prises en charge et supprime l'arbre
   ``build/`` Hazard3-Doom. ``--dry-run`` affiche un aperçu du nettoyage. Les
   sous-modules, fichiers WAD et sources LiteDRAM versionnées sont
   volontairement conservés.

Validation VisualGDB et chaîne d'outils Windows
-----------------------------------------------

``scripts/check-windows-visualgdb.ps1``
   Valide les réglages du projet VisualGDB/NMake Windows natif et les commandes
   attendues de build/nettoyage du moniteur xPack.

``scripts/check-wsl-visualgdb.ps1``
   Valide le pont VisualGDB WSL, les chemins de build/debug WSL attendus et les
   fins de ligne des scripts shell suivis nécessaires à Bash.

``scripts/setup-xpack-riscv-gcc.cmd``
   Installe/configure xPack GNU RISC-V Embedded GCC sous ``bin/riscv-gcc`` pour
   le flux de build natif Windows.

.. note::

   Le comportement des scripts évolue plus vite que la documentation de
   l'architecture. Lorsqu'une option n'est pas documentée ici, utilisez le texte
   usage/help du script checkouté et sa validation des variables d'environnement
   comme source faisant autorité.
