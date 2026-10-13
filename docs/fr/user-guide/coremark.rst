Mesurer Hazard3 avec CoreMark
=============================

CoreMark est un programme autonome bare-metal. Il remplace le moniteur en SRAM
interne et affiche les résultats sur UART. Il ne mesure pas les performances
SDRAM, cache ou framebuffer de Doom et n'utilise pas le protocole H3IMG.

Configuration requise
---------------------

Programmez le bitstream Hazard3 correspondant avant de charger l'ELF. Le port
utilise 128 Kio de SRAM interne, de ``0x00000000`` à ``0x0001FFFF``, avec les
vecteurs à ``0x00000040``. Le script de liaison est
``benchmarks/coremark/link.ld``. Utilisez le modèle ULX3S-85F compatible.
Le modèle compact ULX3S-12F ne possède que 1 Kio de SRAM de démarrage et ne peut
pas exécuter cet ELF sans adaptation. Vérifiez mémoire, ISA, horloge et
périphériques avant d'utiliser le port sur une autre carte.

L'ISA compilée est ``rv32imc_zicsr_zifencei_zba_zbb_zbs``, ABI ``ilp32``.
``HAZARD3_SYS_CLK_HZ`` doit correspondre à l'horloge FPGA réelle. Le script
accepte uniquement ``25000000`` ou ``50000000`` (valeur par défaut).
Un FPGA à 40 MHz nécessite aussi une modification du script de compilation.

Initialisez le sous-module Hazard3 et installez GCC/GDB RISC-V, Python 3 et
OpenOCD. Voir :doc:`../getting-started/prerequisites`. Connectez l'UART externe
à 115200 bauds, 8N1, sans contrôle de flux; voir :doc:`pinouts`.

Compilation
-----------

Depuis la racine du dépôt, dans Bash (WSL sous Windows):

.. code-block:: bash

   ./scripts/build-coremark.sh

Les 3000 itérations par défaut produisent:

.. code-block:: text

   build/coremark/baseline/coremark-performance.elf
   build/coremark/baseline/coremark-validation.elf

``baseline`` et ``tuned`` sélectionnent les optimisations du compilateur.
``performance`` et ``validation`` sélectionnent les configurations de graines;
les deux doivent réussir la validation. Pour les optimisations ``tuned``:

.. code-block:: bash

   COREMARK_BUILD_PROFILE=tuned ./scripts/build-coremark.sh

Les fichiers sont alors dans ``build/coremark/tuned/``. La compilation vérifie
les sources CoreMark contre le commit Hazard3 et les attributs ISA de l'ELF
contre un objet de référence. Elle conserve ``build-info.txt``,
``source-integrity.json``, les fichiers ``.map``, ``.isa.txt`` et ``.isa.json``.
Un résultat ISA PASS à la compilation ne vérifie pas le bitstream actif.

Chargement et capture
---------------------

Dans un terminal séparé, laissez OpenOCD actif:

.. code-block:: bash

   ./scripts/start-openocd.sh ulx3s-85f

Attendez la détection du hart et l'écoute sur le port 3333. Déconnectez les
autres clients GDB, notamment VisualGDB. Voir :doc:`jtag-debugging`.
Pour une capture manuelle, ouvrez l'UART avant le chargement:

.. code-block:: bash

   ./scripts/load-firmware.sh ./build/coremark/baseline/coremark-performance.elf
   ./scripts/load-firmware.sh ./build/coremark/baseline/coremark-validation.elf

Exécutez chaque commande séparément et attendez la fin du benchmark avant la
suivante. Le chargeur arrête le CPU, charge et compare les sections, positionne
``$pc`` sur ``_start``, reprend l'exécution et se déconnecte. Aucun ordre du
moniteur n'est nécessaire. Voir :ref:`load-custom-elf` pour d'autres programmes.

Pour la capture automatique, installez ``pyserial`` dans l'environnement Python
utilisé et fermez les autres applications qui occupent l'UART:

.. code-block:: bash

   ./scripts/run-coremark.sh performance /dev/ttyS7
   ./scripts/run-coremark.sh validation /dev/ttyS7
   ./scripts/run-coremark.sh qualify /dev/ttyS7

Remplacez le port par celui accessible à Python. ``qualify`` exécute les deux
images et exige un port série. Sans port, les modes ``performance`` et
``validation`` chargent uniquement l'ELF pour capture manuelle.
OpenOCD doit déjà fonctionner. Le script crée les fichiers manquants mais ne
recompile pas un ELF existant si les paramètres changent. Recompilez explicitement
et utilisez les mêmes profil et horloge pour compilation et capture:

.. code-block:: bash

   HAZARD3_SYS_CLK_HZ=25000000 COREMARK_BUILD_PROFILE=tuned ./scripts/build-coremark.sh
   HAZARD3_SYS_CLK_HZ=25000000 COREMARK_BUILD_PROFILE=tuned ./scripts/run-coremark.sh qualify /dev/ttyS7

Résultats et dépannage
----------------------

La sortie correcte contient ``Correct operation validated.``, les compteurs
64 bits ``cycles`` et ``instructions``, puis ``COREMARK_DONE``. Utilisez les
valeurs du résumé hôte: durée, CoreMark/s, CoreMark/MHz et cycles par instruction.
Les champs standard du programme cible utilisent des secondes entières avec
``HAS_FLOAT=0`` et perdent en précision.

Chaque exécution doit durer au moins 10 secondes. Si nécessaire, augmentez les
itérations, recompilez et recommencez:

.. code-block:: bash

   COREMARK_ITERATIONS=4000 ./scripts/build-coremark.sh
   ./scripts/run-coremark.sh qualify /dev/ttyS7

``qualify`` affiche ``RESULT : VALID`` seulement si les deux exécutions passent
les contrôles. Conservez ``coremark-<run>.run.log``,
``coremark-<run>.result.json``, métadonnées, empreinte ELF, rapport mémoire,
configuration FPGA et horloge réelle. Voir ``benchmarks/coremark/README.md``.

En l'absence de sortie, vérifiez câblage, port série, 115200 8N1, horloge et
reprise du CPU. Pour une instruction illégale, vérifiez l'ISA du bitstream.
Pour un échec de chargement ou comparaison, vérifiez RAM et configuration
OpenOCD. Pour une durée incorrecte, vérifiez l'horloge dans la compilation et
le script de capture; elle ne modifie pas l'horloge FPGA. Le délai Python par
défaut est de 120 secondes, chargement inclus.

Pour restaurer le moniteur ULX3S-85F, avec OpenOCD toujours actif:

.. code-block:: bash

   ./scripts/load-firmware.sh ./build/ulx3s-85f/monitor/hazard3-boot-monitor.elf

Cette commande recharge la RAM sans programmer le FPGA ou la mémoire SPI flash.
