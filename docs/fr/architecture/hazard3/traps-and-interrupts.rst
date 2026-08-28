Traps, interruptions et CSR
===========================

RISC-V utilise le terme **trap** pour un transfert de contrôle provoqué soit
par une exception synchrone, soit par une interruption asynchrone. Hazard3
implémente l'état de trap en mode machine utilisé par ce projet dans
`hazard3_csr.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_csr.v>`_.

Modèle de privilèges du projet
------------------------------

Le CPU Hazard3-Doom est configuré comme un système embarqué en mode machine :

* le support des CSR machine est activé ;
* le support des traps machine est activé ;
* le mode utilisateur n'est pas activé ;
* l'entrée d'interruption logicielle est forcée à zéro ;
* une entrée d'interruption externe est utilisée pour l'UART ; et
* le timer de plateforme pilote l'entrée d'interruption timer machine.

Le vecteur de reset du processeur est ``0x00000040``. La valeur initiale de
``mtvec`` est ``0x00000000`` dans l'instanciation du SoC d'exemple ; le firmware
de démarrage est responsable de l'établissement du dispositif d'entrée de trap
souhaité à l'exécution.

CSR machine importants
----------------------

Les CSR standard suivants constituent le meilleur point de départ pour les
étudiants :

.. list-table::
   :header-rows: 1
   :widths: 22 78

   * - CSR
     - Rôle
   * - ``mstatus``
     - Activation globale des interruptions machine et état d'interruption/privilège sauvegardé lors de l'entrée et du retour de trap.
   * - ``mtvec``
     - Base du vecteur de trap machine et sélection du mode direct/vectorisé.
   * - ``mepc``
     - Compteur de programme associé à l'instruction ayant provoqué le trap ou au point d'exécution interrompu.
   * - ``mcause``
     - Indique si le trap est une interruption ou une exception et enregistre le code de cause.
   * - ``mie``
     - Activations machine par source d'interruption.
   * - ``mip``
     - État des interruptions en attente visible par le logiciel.
   * - ``mtval``
     - CSR de valeur de trap. Dans cette implémentation Hazard3 épinglée, il est câblé à zéro.
   * - ``mcycle`` / ``minstret``
     - Compteurs de cycles et d'instructions retirées lorsque le support des compteurs est activé.

Le RTL CSR épinglé masque ``mepc`` selon l'alignement des instructions. Comme
``C`` est activé, un PC d'instruction valide peut être aligné sur une frontière
16 bits ; il n'a pas toujours besoin d'être aligné sur 32 bits.

Exception ou interruption
-------------------------

Un modèle mental utile est :

.. code-block:: text

   synchronous problem in current instruction
       -> exception
       -> examples: illegal instruction, access fault, ecall, ebreak

   asynchronous event from outside instruction stream
       -> interrupt
       -> examples: UART or timer event

Les deux entrent dans le chemin de trap machine, mais ``mcause`` les distingue.
Le bit de poids fort indique interruption ou exception, tandis que le champ de
cause identifie la source précise implémentée par le cœur.

Entrée dans un trap
-------------------

À haut niveau, l'entrée dans un trap machine effectue ces actions architecturales :

#. arrêter le retrait normal sur une frontière précise d'instruction ;
#. sauvegarder le PC approprié dans ``mepc`` ;
#. écrire la raison du trap dans ``mcause`` ;
#. mettre à jour l'état empilé d'activation des interruptions machine dans ``mstatus`` ; et
#. rediriger le fetch d'instructions vers l'adresse sélectionnée à partir de ``mtvec``.

Le PC exact sauvegardé pour une exception ne représente pas toujours le même
point conceptuel que pour une interruption. Le contrôle de l'étage M de Hazard3
distingue explicitement les conditions de trap afin que ``mret`` puisse reprendre
au PC architecturalement correct.

Retour de trap
--------------

``mret`` restaure l'état de trap machine et redirige le fetch vers ``mepc``.
C'est une raison pour laquelle le traitement des traps doit être coordonné avec
le front-end du pipeline : toutes les instructions récupérées depuis l'ancien
chemin doivent être abandonnées lorsque l'exécution revient au PC sauvegardé.

Câblage des interruptions externes dans ce projet
-------------------------------------------------

Le fichier épinglé
`example_soc.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/example_soc.v>`_ connecte les ports d'interruption du processeur comme suit :

.. code-block:: text

   hazard3_cpu_1port
       irq[0]    <- UART IRQ
       soft_irq  <- 0
       timer_irq <- platform timer IRQ

``NUM_IRQS=1`` est le réglage Hazard3 normal ici. L'extension optionnelle du
contrôleur d'interruptions personnalisé de Hazard3 n'est pas sélectionnée par le
wrapper ULX3S ; ce design reste donc volontairement proche du modèle standard
d'interruptions machine RISC-V.

Couches d'activation des interruptions
--------------------------------------

Recevoir un signal électrique/d'un périphérique n'est qu'une partie du
traitement d'une interruption. Le logiciel doit généralement aussi configurer :

#. l'état d'activation de l'interruption propre au périphérique ;
#. le bit approprié dans ``mie`` ; et
#. l'activation globale des interruptions machine dans ``mstatus``.

Le handler doit ensuite traiter/acquitter la source périphérique avant de
revenir, sinon une interruption sensible au niveau peut immédiatement redevenir
en attente.

Exemple pédagogique
-------------------

Un exercice minimal d'interruption timer/UART peut être abordé dans cet ordre :

#. installer un handler de trap et régler ``mtvec`` ;
#. inspecter ``mcause`` dans le handler ;
#. activer une seule source d'interruption à la fois ;
#. enregistrer ``mepc`` et certains CSR sur UART ;
#. acquitter le périphérique ; et
#. revenir avec ``mret``.

Cela rend directement visible la relation entre **périphérique**, **état
d'interruption CSR**, **redirection du pipeline** et **logiciel du handler**.

Étude du code source
--------------------

Utilisez ensemble ces fichiers épinglés :

* `hazard3_csr.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_csr.v>`_ - décodage CSR, ``mstatus``, ``mepc``, ``mcause``, état d'interruption et mises à jour de l'état de trap.
* `hazard3_core.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/hdl/hazard3_core.v>`_ - détection des exceptions, séquencement des traps, redirections de fetch et achèvement à l'étage M.
* `example_soc.v <https://github.com/ulx3s/Hazard3/blob/736a74459b3f740c47803f20a62d820fcacbe5c3/example_soc/soc/example_soc.v>`_ - câblage réel des interruptions UART/timer dans le projet.
