Pipeline à trois étages
=======================

La meilleure façon de comprendre Hazard3 est de suivre une instruction à
travers les étages ``F``, ``X`` et ``M`` dans
`hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_ et
`hazard3_frontend.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_frontend.v>`_.

Étage F : fetch et préparation
------------------------------

Le front-end demande des mots alignés 32 bits à la mémoire d'instructions.
Comme l'extension ``C`` est activée dans ce projet, le flux d'instructions peut
contenir des instructions 16 bits ou 32 bits. Une instruction 32 bits peut
aussi commencer dans la moitié haute d'un mot récupéré et se terminer dans la
moitié basse du suivant.

Hazard3 gère ce décalage par mise en tampon plutôt qu'en imposant au bus des
lectures d'instructions 16 bits. Le front-end épinglé contient :

* une file de préfetch de deux entrées de 32 bits ; et
* un tampon d'assemblage d'instructions constitué de demi-mots d'instruction.

La file découple le timing de réponse du bus de la consommation par le pipeline.
Le tampon de demi-mots permet au cœur de former l'instruction architecturale
suivante avec un alignement 16 bits. Les instructions compressées sont
expansées avant d'être consommées par la logique d'exécution normale.

Conceptuellement :

.. code-block:: text

   32-bit fetch words
        |
        v
   +-------------------+
   | prefetch queue    |  two words
   +-------------------+
        |
        v
   +-------------------+
   | halfword assembly |  handles 16/32-bit boundaries
   +-------------------+
        |
        v
   +-------------------+
   | C decompressor    |  if instruction is compressed
   +-------------------+
        |
        v
        X stage

Une redirection de fetch provoquée par un branchement, un saut, un trap, un
retour, un événement debug ou ``fence.i`` invalide le travail issu de l'ancien
flux d'instructions et redémarre le front-end au nouveau PC.

Étage X : décodage et exécution
-------------------------------

L'étage X combine des tâches qu'un processeur pédagogique à cinq étages
répartirait entre les étages de décodage et d'exécution. Les fonctions
importantes comprennent :

* décoder l'instruction et valider les extensions ISA activées ;
* sélectionner les valeurs ``rs1`` et ``rs2``, y compris les résultats bypassés ;
* effectuer les opérations ALU entières ;
* comparer les opérandes de branchement ;
* calculer les cibles de branchement/saut ;
* calculer les adresses load/store ;
* lancer les opérations CSR, multiplication/division et côté mémoire ; et
* décider si l'instruction peut avancer vers M.

Le décodeur tient compte des paramètres. Par exemple, un encodage atomique
n'est pas simplement ignoré lorsque ``EXTENSION_A=0`` ; il est décodé comme une
instruction illégale. C'est pourquoi la configuration synthétisée fait partie
du contrat architectural visible par le logiciel.

Étage M : achèvement et retrait
-------------------------------

L'étage M contient la plus ancienne instruction en vol. C'est là que les
résultats tardifs sont sélectionnés et que l'achèvement architectural devient
définitif. Exemples :

* attendre la fin de la phase de données d'un load ou d'un store ;
* sélectionner les données chargées pour le writeback registre ;
* valider les résultats ALU/multiplication/CSR dans ``rd`` ;
* entrer dans un trap après une exception synchrone ou une interruption acceptée ;
* terminer les transitions de mode debug ; et
* retirer une instruction pour le compteur d'instructions retirées.

Si le système mémoire impose des wait states, l'étage M peut rester bloqué. La
contre-pression se propage alors vers X et F afin qu'aucune instruction plus
jeune ne dépasse l'instruction plus ancienne.

Forwarding des données et hazards
---------------------------------

Même un pipeline court peut rencontrer des hazards read-after-write. Hazard3
inclut des chemins de bypass afin qu'un résultat n'ait pas toujours besoin
d'être écrit dans le fichier de registres puis relu avant que l'instruction
suivante puisse l'utiliser.

Considérons deux instructions ALU dépendantes :

.. code-block:: asm

   add  x5, x6, x7
   xor  x8, x5, x9

Avec la configuration normale de bypass complet, le ``xor`` peut recevoir le
résultat producteur par forwarding plutôt que d'attendre un aller-retour dans
le fichier de registres.

Une dépendance load-use est différente :

.. code-block:: asm

   lw   x5, 0(x6)
   add  x8, x5, x9

La valeur chargée n'existe pas avant le retour de la mémoire. La logique de
hazard du cœur épinglé traite spécifiquement le load-use comme un cas RAW qui
peut nécessiter un stall. Le délai réel dépend également du temps de réponse de
la mémoire/du bus.

Le projet n'active pas ``REDUCED_BYPASS`` ; il utilise donc la configuration de
bypass la plus complète.

Branches et petit prédicteur
----------------------------

Hazard3 peut synthétiser un petit mécanisme de prédiction de branche. Le projet
règle ``BRANCH_PREDICTOR=1``.

Il est volontairement beaucoup plus simple qu'un prédicteur de CPU de bureau.
Le cœur épinglé mémorise une cible de branche arrière récemment utile et peut
rediriger le fetch tôt pour une branche de boucle prédite prise. Les branches
arrière sont une bonne cible pour un petit prédicteur car elles implémentent
souvent des boucles :

.. code-block:: asm

   loop:
       # loop body
       addi x5, x5, -1
       bnez x5, loop

Le prédicteur réduit les bulles de fetch répétées dans les boucles serrées
lorsque son hypothèse simple est correcte. En cas d'erreur, le cœur redirige le
front-end et poursuit sur le chemin architectural. L'entrée dans un trap et la
synchronisation du fetch d'instructions effacent/invalident également l'état de
prédiction lorsque nécessaire.

Comparaison de branche rapide
-----------------------------

``FAST_BRANCHCMP=1`` est sélectionné dans le build ULX3S. Cela active le chemin
dédié de comparaison rapide de branche plutôt que de s'appuyer uniquement sur
un chemin de comparaison ALU plus sérialisé. Il s'agit d'une option
d'implémentation de timing/performance ; elle ne modifie pas la sémantique des
branches visible par RISC-V.

Comportement de multiplication et division
------------------------------------------

Le projet active l'extension ``M`` et sélectionne les options de multiplication
rapide :

.. code-block:: text

   MUL_FAST       = 1
   MUL_FASTER     = 1
   MULH_FAST      = 1
   MULDIV_UNROLL  = 4

Les paramètres de multiplication échangent de la logique FPGA contre une
latence plus faible et un meilleur débit. Division/reste utilisent toujours une
arithmétique itérative ; le facteur d'unroll contrôle la quantité de travail
effectuée par l'unité séquentielle à chaque cycle. C'est un bon exemple d'un
compromis récurrent en conception de processeur : l'ISA ne change pas, tandis
que la surface, le timing et le CPI peuvent varier fortement avec les paramètres
RTL.

Exercice d'étude du pipeline
----------------------------

Un exercice utile de lecture du code consiste à suivre ces quatre séquences dans
le RTL :

#. opérations ALU indépendantes ;
#. résultat ALU consommé par l'instruction suivante ;
#. load immédiatement consommé par l'instruction suivante ; et
#. branche arrière prise dans une boucle.

Commencez dans ``hazard3_core.v`` au niveau des commentaires d'étage, puis
suivez les signaux de stall, bypass, redirection de branche et writeback de
l'étage M. Utilisez ``hazard3_frontend.v`` pour voir l'effet d'une redirection
sur les données d'instruction mises en file.
