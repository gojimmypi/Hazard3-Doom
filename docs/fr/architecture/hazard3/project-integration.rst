Hazard3 amont et personnalisation du projet
===========================================

La règle de maintenance la plus importante pour Hazard3-Doom est de garder
visible la frontière du processeur amont. Une quantité importante de matériel a
été ajoutée pour rendre Doom pratique sur ULX3S/ULX4M, mais ces ajouts ne doivent
pas être confondus avec des modifications de l'ISA RISC-V ou du pipeline
fondamental de Hazard3.

Base de comparaison
-------------------

Cette page a été revue le **2026-08-19** par rapport à :

* instantané du projet : `ulx3s/Hazard3 à 736a74459b3f740c47803f20a62d820fcacbe5c3 <https://github.com/ulx3s/Hazard3/tree/736a74459b3f740c47803f20a62d820fcacbe5c3>`_ ;
* branche amont maintenue actuelle : `Wren6991/Hazard3 stable <https://github.com/Wren6991/Hazard3/tree/stable>`_.

L'amont actuel peut changer après cette date. Le SHA épinglé reste la source de
vérité pour le build documenté ici.

Matériel processeur standard amont
----------------------------------

Les éléments suivants relèvent de l'architecture Hazard3 ou d'une infrastructure
amont réutilisable, et non de modifications propres à Doom :

.. list-table::
   :header-rows: 1
   :widths: 34 66

   * - Zone
     - Rôle standard amont
   * - ``hdl/hazard3_core.v``
     - Pipeline CPU in-order à trois étages et contrôle de l'exécution architecturale.
   * - Front-end / décodeur / décompresseur
     - Fetch RISC-V, décodage, gestion des instructions compressées et activation conditionnelle des extensions.
   * - ALU / blocs multiplication-division
     - Exécution entière et datapaths M/manipulation de bits configurables.
   * - Modules CSR, PMP, power, IRQ, trigger
     - Fonctions architecturales/de contrôle configurables fournies par Hazard3.
   * - ``hazard3_cpu_1port.v`` et ``hazard3_cpu_2port.v``
     - Wrappers réutilisables traduisant les transactions du cœur vers des bus système AHB5.
   * - Hazard3 Debug Module et DTM
     - Support standard de débogage externe RISC-V.
   * - Adaptateur DTM ECP5 JTAGG
     - Support Hazard3 amont pour utiliser le TAP de la puce ECP5 avec OpenOCD.
   * - Concept de SoC d'exemple minimal
     - Intégration de référence CPU + debug + RAM + UART + timer.

Dans l'arbre ``stable`` amont actuel, ``example_soc/soc`` reste compact autour
des fichiers de base du SoC d'exemple et du répertoire de périphériques. À
l'inverse, ``example_soc/soc`` du fork ULX3S épinglé contient des modules
supplémentaires de SDRAM, SAO, SD et d'image de démarrage. Cette différence au
niveau du répertoire indique fortement où se concentre la personnalisation
matérielle du projet.

Intégration propre au projet ou au fork
---------------------------------------

Le fork ULX3S épinglé ajoute les fonctionnalités système nécessaires à la
plateforme Doom :

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Zone du projet
     - Rôle
   * - ``ahb_sdram.v`` / ``ulx3s_sdram_controller.v``
     - Relier la SDR SDRAM de la carte au fabric mémoire processeur/système.
   * - ``ahb_litedram.v``
     - Chemin alternatif d'intégration de mémoire externe utilisé par certains profils de cartes.
   * - Accès vidéo/SDRAM natif
     - Permettre au pipeline d'affichage de consommer les données framebuffer sans prétendre que la vidéo est une fonctionnalité du CPU.
   * - ``apb_sao_bridge.v``
     - Contrôle SAO memory-mapped pour le firmware du projet.
   * - ``sao_i2c_engine.v`` / logique de contrôleur partagé
     - Implémenter les fonctions I2C/SAO du projet et la propriété/l'arbitrage explicites.
   * - ``sao_esp32_uart_bridge.v`` / ``sao_uart_phy.v``
     - Communication latérale et partage de ressources avec l'ESP32 compagnon.
   * - ``apb_sd_spi.v``
     - Moteur SPI de carte SD contrôlé par APB pour le chargement autonome.
   * - Préchargement ``hazard3_boot.hex``
     - Placer le moniteur résident dans l'EBR interne lors de la configuration du FPGA.
   * - Wrapper/contraintes de carte ULX3S
     - Connecter SDRAM, HDMI/vidéo, SD, SAO/ESP32, horloges et broches au SoC étendu.

Ce que le commit ``736a744`` a spécifiquement ajouté
----------------------------------------------------

Le commit épinglé s'intitule ``Add SD apb, improve SAO, introduce
hazard3_boot.hex``. Ses modifications sont concentrées dans le SoC d'exemple et
l'intégration de carte ULX3S. Il ajoute notamment le bloc APB SD, active le SPI
SD dans le wrapper ULX3S, ajoute le support de préchargement SRAM du moniteur
résident, met à jour l'intégration SAO et les entrées de synthèse/contraintes
nécessaires à ces fonctions.

C'est exactement le modèle que nous voulons préserver : les fonctions de carte
et d'application sont implémentées autour du processeur plutôt que d'intégrer le
comportement du projet dans le cœur générique.

Les paramètres CPU sélectionnés relèvent de l'intégration, pas d'un fork CPU
----------------------------------------------------------------------------

Choisir les paramètres Hazard3 fait aussi partie de l'intégration du projet,
mais ce n'est pas la même chose que modifier l'implémentation du processeur. Par
exemple :

.. code-block:: text

   EXTENSION_A       = 0
   EXTENSION_C       = 1
   EXTENSION_M       = 1
   EXTENSION_ZBA     = 1
   EXTENSION_ZBB     = 1
   EXTENSION_ZBS     = 1
   BRANCH_PREDICTOR  = 1

Ces valeurs indiquent au RTL Hazard3 standard et paramétrable quel matériel
synthétiser. Le projet possède le choix ; l'amont possède les mécanismes
génériques.

Il en va de même pour ``RESET_VECTOR=0x40`` et ``DEBUG_SUPPORT=1`` dans
l'instance CPU du SoC d'exemple. Ce sont des décisions de configuration pour ce
système.

Pourquoi cette frontière est importante
---------------------------------------

Pour l'enseignement
   Les étudiants peuvent étudier un vrai cœur RISC-V sans devoir d'abord
   démêler les graphismes Doom ou la logique de carte SD du pipeline CPU.

Pour l'upstream
   Les corrections réutilisables du processeur appartiennent à Hazard3 amont ;
   les fonctions de carte/application doivent rester dans le fork ou être
   généralisées avant d'être proposées en amont.

Pour le débogage
   Une instruction illégale oriente d'abord vers la configuration ISA/les flags
   de compilation ; une panne SDRAM/vidéo/SD oriente d'abord vers l'intégration
   SoC. Garder ces domaines séparés réduit l'espace de recherche.

Pour les mises à niveau
   Une future mise à jour du sous-module Hazard3 peut être examinée sous deux
   angles : « qu'est-ce qui a changé dans le comportement processeur/debug
   amont ? » et « notre intégration environnante respecte-t-elle toujours les
   mêmes interfaces ? »

Propriété des dépôts dans Hazard3-Doom
--------------------------------------

Le superprojet doit donc être lu comme trois couches :

.. code-block:: text

   Hazard3-Doom application/monitor/scripts
                 |
                 v
   pinned ulx3s/Hazard3 integration fork
       |                    |
       |                    +-- project SoC/board additions
       v
   upstream Hazard3 CPU/debug architecture

Voir :doc:`../repositories` pour l'organisation correspondante des dépôts et
sous-modules.
