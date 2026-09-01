Sweeps de timing et de seeds ECP5
=================================

Hazard3-Doom exécute plusieurs routages nextpnr-ecp5 afin de caractériser le
timing ECP5, choisir des seeds utiles, comparer les paramètres de placement et
de routage, et détecter les régressions de timing après une modification du RTL
ou d'un coeur généré. Les mêmes scripts de sweep sont utilisés localement et par
le workflow GitHub Actions ``ECP5 seed sweep``.

Un sweep n'est pas seulement une recherche d'un seed chanceux. C'est aussi une
expérience reproductible : synthétiser un netlist une seule fois, router
exactement ce netlist avec plusieurs seeds, enregistrer la chaîne d'outils et la
configuration, puis comparer tous les domaines d'horloge requis.

Pourquoi les seeds comptent
----------------------------

nextpnr utilise le seed pour influencer certaines décisions aléatoires du
placement et du routage. Des seeds différents explorent donc des
implémentations physiques différentes du même design synthétisé. Un seed peut
améliorer un domaine d'horloge tout en dégradant un autre.

Le numéro du seed n'indique pas sa qualité. Un seed qui passait avec un ancien
netlist ne doit être considéré que comme une référence historique après une
modification importante du RTL, du coeur LiteDRAM généré, des horloges, de la
géométrie mémoire, du framebuffer, des contraintes, de la synthèse ou des
outils CAD.

Pour une comparaison A/B utile, utilisez le **même ensemble de seeds** pour
chaque configuration.

Définition d'un PASS de timing
------------------------------

Un seed routé ne passe que si toutes les horloges requises de la cible passent
dans le même routage.

.. list-table:: Horloges routées requises
   :header-rows: 1
   :widths: 22 18 18 18 18 18

   * - Cible
     - ``clk_sys``
     - Utilisateur LiteDRAM
     - Pixel vidéo
     - TMDS x5
     - Init LiteDRAM
   * - ULX3S 85F
     - 50 MHz
     - n/a
     - 50 MHz
     - 250 MHz
     - n/a
   * - ULX3S 12F
     - 40 MHz
     - n/a
     - 50 MHz
     - 250 MHz
     - n/a
   * - ULX4M-LD 85F
     - Choisie par le workflow ; 40 MHz par défaut
     - 75.01 MHz
     - 50 MHz
     - 250 MHz
     - 25 MHz

Un processus de routage peut se terminer avec succès tout en donnant un statut
``FAIL`` de timing. Le sweep utilise volontairement le mode
``timing-allow-fail`` de nextpnr pour conserver les mesures des routages qui ne
ferment pas le timing.

Sweep local
-----------

Le répartiteur de cibles est ``scripts/sweep-ecp5.sh``. Les scripts spécifiques
aux cartes offrent des points d'entrée directs :

.. code-block:: bash

   ./scripts/sweep-ecp5.sh --list-targets
   ./scripts/sweep-ulx3s-85f.sh 1-32
   ./scripts/sweep-ulx3s-12f.sh 1-32
   ./scripts/sweep-ulx4m-ld.sh 1-32

``SWEEP_JOBS`` contrôle le parallélisme local :

.. code-block:: bash

   SWEEP_JOBS=8 ./scripts/sweep-ulx4m-ld.sh 1-32

Chaque processus nextpnr peut consommer plusieurs centaines de Mio. Une valeur
élevée de ``SWEEP_JOBS`` n'est utile que si le CPU, la RAM, le stockage et le
système hôte peuvent suivre.

.. figure:: ../images/concurrent-nextpnr-ecp5.png
   :alt: Plusieurs processus nextpnr-ecp5 concurrents pendant un sweep local
   :width: 90%

   Plusieurs routages nextpnr-ecp5 peuvent être exécutés en parallèle en local.
   Dimensionnez ``SWEEP_JOBS`` selon la machine.

Le flux synthétise normalement une seule fois puis réutilise le même netlist
pour tous les seeds. N'utilisez ``SWEEP_SKIP_SYNTH=1`` que si le netlist existant
correspond réellement aux sources, horloges et options courantes.

Sweep GitHub Actions
--------------------

Le workflow est actuellement
``.github/workflows/ulx4m-ld-seed-sweep.yml``. Son nom affiché est
``ECP5 seed sweep`` et le sélecteur de cible prend en charge ULX3S 85F,
ULX3S 12F et ULX4M-LD 85F.

Le workflow est lancé manuellement avec ``workflow_dispatch`` et sépare
volontairement la synthèse du routage afin que tous les jobs de routage utilisent
le même netlist figé.

La concurrence est groupée par cible et référence Git avec
``cancel-in-progress: false`` : un second lancement de la même cible/référence
ne doit donc pas annuler un sweep déjà en cours de collecte.

Paramètres du workflow
~~~~~~~~~~~~~~~~~~~~~~

.. list-table:: Guide des paramètres du sweep GitHub
   :header-rows: 1
   :widths: 22 18 60

   * - Paramètre
     - Défaut actuel
     - Utilisation
   * - ``target``
     - ``ulx3s-85f``
     - Cible FPGA : ``ulx3s-85f``, ``ulx3s-12f`` ou ``ulx4m-ld-85f``.
   * - ``seed_first`` / ``seed_last``
     - 1 / 260
     - Plage inclusive. Le workflow actuel impose 1 à 260. Pour les expériences,
       commencez par une plage plus petite.
   * - ``max_parallel``
     - 20
     - Nombre maximal de jobs GitHub de routage simultanés : 4, 8, 12 ou 20.
   * - ``seeds_per_job``
     - 2
     - Nombre de seeds routés en série dans chaque job : 1 à 5. Deux limite
       l'impact d'un seed exceptionnellement lent.
   * - ``retain_bitstreams``
     - false
     - Conserver les ``.bit`` par seed. Laissez désactivé pour un sweep large
       si les bitstreams ne seront pas testés sur le matériel.
   * - ``ulx3s_85f_extended_modes``
     - 1
     - Active les modes HDMI étendus de l'ULX3S 85F.
   * - ``ulx3s_12f_memory_profile``
     - ``32m``
     - Profil SDRAM 12F : ``32m`` ou ``64m``.
   * - ``ulx4m_sys_clk_mhz``
     - 40
     - Horloge système Hazard3 de l'ULX4M-LD : 25, 40 ou 50 MHz. Le domaine
       utilisateur LiteDRAM reste séparé à 75 MHz.
   * - ``ulx4m_litedram_cpu``
     - ``serv``
     - CPU intégré au coeur d'initialisation LiteDRAM : ``serv`` ou ``vexrisc``.
   * - ``placer``
     - ``heap``
     - HeAP ou recuit simulé ``sa``. SA peut être beaucoup plus lent ; utilisez
       un petit ensemble de seeds pour l'évaluer.
   * - ``router``
     - ``router1``
     - ``router1`` ou ``router2``. Comparez-les sur le même netlist et les mêmes
       seeds.
   * - ``heap_timingweight``
     - 10
     - Poids de timing HeAP : 10, 20, 30 ou 40.
   * - ``heap_critexp``
     - 2
     - Exposant de criticité HeAP : 2, 3 ou 4.
   * - ``tmg_ripup``
     - false
     - Active le rip-up expérimental piloté par le timing.
   * - ``router2_alt_weights``
     - false
     - Active les poids alternatifs de Router2.
   * - ``nextpnr_extra_args``
     - vide
     - Arguments nextpnr avancés. Toute utilisation doit être enregistrée comme
       partie de l'expérience.
   * - ``synth_oss_cad_suite_version``
     - ``2026-07-20``
     - Version OSS CAD Suite utilisée pour la synthèse.
   * - ``route_oss_cad_suite_version``
     - ``2026-07-20``
     - Version utilisée par nextpnr dans les jobs de routage. Elle peut être
       différente pour une comparaison contrôlée de versions.

``max_parallel`` et ``seeds_per_job`` sont indépendants. Pour ``N`` seeds, le
workflow crée environ ``ceil(N / seeds_per_job)`` jobs. Au plus
``max_parallel`` jobs s'exécutent simultanément, tandis que les seeds d'un même
job sont routés en série. Avec 260 seeds et deux seeds par job, le workflow crée
130 jobs de routage.

Architecture des jobs
---------------------

Le workflow possède quatre rôles logiques : ``prepare``, ``watch``, ``route``
et ``summarize``.

.. list-table:: Timeouts des jobs GitHub
   :header-rows: 1
   :widths: 24 20 56

   * - Job
     - Timeout
     - Note
   * - ``prepare``
     - 90 min
     - Synthèse, provenance, matrice et publication des entrées figées.
   * - ``watch``
     - 360 min
     - Collecteur live des artifacts.
   * - ``route``
     - 350 min
     - Couvre tout le groupe de matrice et tous ses seeds traités en série.
   * - ``summarize``
     - 60 min
     - Téléchargement, agrégation, contrôle de complétude et artifact final.

Comme le timeout du job ``route`` couvre le groupe complet, une grande valeur
de ``seeds_per_job`` devient risquée si plusieurs seeds approchent leur watchdog.

``prepare`` : figer l'expérience
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le job ``prepare`` valide les paramètres, installe/restaure la chaîne d'outils,
initialise les sous-modules requis, synthétise la cible une seule fois, enregistre
le SHA256 du netlist, les révisions Git et gitlinks, les versions des outils et
les paramètres du workflow, construit la matrice de seeds puis publie une archive
de routage figée.

Chaque job de routage vérifie ensuite le SHA256 avant nextpnr. Cela empêche deux
runners de comparer accidentellement des netlists différents.

L'artifact d'entrée figé et les artifacts de groupes utilisent actuellement une
rétention d'un jour. L'artifact final résumé est conservé 14 jours ; archivez-le
ailleurs lorsqu'il devient un point de contrôle durable du projet.

``route`` : runners indépendants
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Chaque job de matrice dispose de son propre runner Ubuntu. Les runners ne
partagent pas de système de fichiers. Le job télécharge donc l'archive figée,
restaure la version de nextpnr demandée, puis route ses seeds en série avec
``SWEEP_JOBS=1`` et ``SWEEP_SKIP_SYNTH=1``.

Pour chaque seed, le job conserve la sortie console, les logs de routage, le CSV
de résultat, le temps écoulé, le code de sortie, le SHA256 du netlist et,
optionnellement, le bitstream.

``watch`` : moniteur de timing en direct
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le moniteur en direct ne peut pas lire directement les autres runners GitHub.
Les groupes terminés publient donc de petits artifacts. Le job ``watch`` observe
ces artifacts et affiche les nouveaux résultats pendant que le routage continue.

.. code-block:: bash

   ./scripts/watch-ecp5-sweep-results.sh \
       "${SWEEP_TARGET}" \
       "${SWEEP_SEED_FIRST}" \
       "${SWEEP_SEED_LAST}" \
       "${SWEEP_SEEDS_PER_JOB}"

Exemple :

.. code-block:: text

   ------------------------------------------------------------
   LIVE TIMING RESULTS
   Timing-passing seeds: none
   Progress: 40/260 seeds | 20/130 groups | 20/130 jobs
   Status: PASS=0 FAIL=40 TIMEOUT=0 OTHER=0
   Route duration: avg=192s | fastest=118s (seed 6) | slowest=279s (seed 21)
   Best observed max MHz: sys=43.82 (seed 12) | litedram_user=71.70 (seed 10) | video=73.33 (seed 25)
                          tmds=370.23 (seed 4) | init=369.69 (seed 2)
   Timeout seeds: none
   Other/problem seeds: none
   ------------------------------------------------------------

Les artifacts peuvent arriver dans le désordre. Les maxima ``Best observed``
sont calculés séparément pour chaque horloge et peuvent provenir de seeds
différents : ils ne constituent pas un PASS combiné.

``summarize`` : résultat final
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le job final télécharge tous les groupes et les références figées.
``scripts/summarize-ecp5-sweep.py`` génère les résumés Markdown/CSV, l'inventaire
et les sommes SHA256, puis vérifie que chaque seed demandé possède un résultat ou
une classification explicite d'échec/timeout.

Timeouts
--------

Le workflow courant protège les routages longs avec les limites suivantes :

.. list-table:: Watchdogs de routage
   :header-rows: 1
   :widths: 32 22 46

   * - Limite
     - Valeur
     - Rôle
   * - Timeout de routage
     - 7200 s
     - Limite le routage nextpnr interne.
   * - Kill-after de routage
     - 30 s
     - Escalade si le processus ne se termine pas.
   * - Timeout du seed complet
     - 7600 s
     - Encadre l'invocation complète du sweep pour un seed.
   * - Kill-after du seed
     - 30 s
     - Escalade l'arrêt d'un seed bloqué.
   * - Timeout du job GitHub de routage
     - 350 min
     - Limite le job de matrice complet.

Les codes 124 et 137 du watchdog sont enregistrés comme timeout et le job passe
au seed suivant. Une autre erreur inattendue reste un problème d'outil ou
d'intégration et doit rester visible.

Stratégie de sélection des paramètres
-------------------------------------

Pour un nouveau netlist :

#. Établissez une base avec les seeds 1-32 et HeAP/Router1.
#. Répétez exactement les mêmes seeds pour chaque comparaison contrôlée.
#. Étendez la ou les meilleures configurations à 1-128.
#. Ne lancez 1-260 que lorsque la configuration mérite le coût de calcul ou
   lorsqu'une distribution large est nécessaire.

Testez les poids/exposants HeAP, ``tmg_ripup`` et Router2 comme des expériences,
pas comme des améliorations garanties. Pour SA, utilisez un petit sous-ensemble
avec les timeouts actifs.

Si vous comparez des versions de nextpnr, conservez le netlist synthétisé et ne
changez que ``route_oss_cad_suite_version``. Si la synthèse change, le SHA256 du
netlist change également et les anciens classements de seeds ne sont plus
directement comparables.

Interprétation et reproductibilité
----------------------------------

``PASS`` signifie que toutes les horloges requises passent. ``FAIL`` signifie
que le routage s'est terminé mais qu'au moins une horloge a raté sa contrainte.
Un timeout n'est pas une mesure de timing. ``NO_RESULT`` ou ``ERROR`` signale un
problème à diagnostiquer dans les logs.

Avant de comparer deux sweeps, vérifiez le SHA256 du netlist, la cible, les
horloges, le profil de fonctionnalités, le coeur LiteDRAM, les contraintes, la
version de nextpnr, les paramètres du placer/router et l'ensemble de seeds.

Après une modification d'un coeur généré, par exemple une nouvelle géométrie de
mémoire LiteDRAM, resynthétisez et établissez une nouvelle base de seeds.

Pièges courants
---------------

* ``--timing-allow-fail`` permet de collecter les mesures ; il ne transforme pas
  un FAIL en PASS.
* Le meilleur seed d'une seule horloge n'est pas forcément le meilleur seed
  global.
* N'utilisez pas ``SWEEP_SKIP_SYNTH=1`` après une modification du RTL, des
  contraintes, des horloges ou d'un coeur généré sans netlist correspondant.
* Gardez ``seeds_per_job`` petit lorsqu'il existe des seeds très lents.
* ``max_parallel`` contrôle les runners GitHub, pas plusieurs nextpnr dans un
  même job de routage.
* Un ``SWEEP_JOBS`` local trop élevé peut épuiser la RAM.
* Conservez les bitstreams seulement si vous comptez les tester sur le matériel.
* Qualifiez sur carte le candidat destiné à devenir une référence de production.

Fichiers associés
-----------------

.. code-block:: text

   .github/workflows/ulx4m-ld-seed-sweep.yml
   scripts/sweep-ecp5.sh
   scripts/sweep-ecp5-common.sh
   scripts/sweep-ulx3s-85f.sh
   scripts/sweep-ulx3s-12f.sh
   scripts/sweep-ulx4m-ld.sh
   scripts/watch-ecp5-sweep-results.sh
   scripts/summarize-ecp5-sweep.py

Voir aussi :doc:`scripts` et :doc:`board-profiles`.
