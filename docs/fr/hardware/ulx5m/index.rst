Notes matérielles ULX5M-GS V005
================================

Ces notes concernent la carte Intergalaktik ULX5M-GS V005 équipée du FPGA
Cologne Chip GateMate CCGM1A1. Elles documentent les contraintes électriques
et les observations matérielles utiles au portage Hazard3-Doom en cours. Elles
ne remplacent ni le schéma de la carte ni la fiche technique du FPGA. Vérifiez
la révision de la carte assemblée avant de les appliquer à une autre unité.

.. warning:: La tension du banc EA dépasse les limites du GateMate

   Le fabricant de la carte ULX5M-GS a confirmé oralement que la carte V005
   examinée, alimentée par USB, utilise **3,3 V sur le banc EA du GateMate**.
   Il s'agit d'une configuration déclarée par le fabricant de la carte, et
   non d'une mesure indépendante de VDD_EA ou d'une validation par le fabricant
   du FPGA.

   La fiche Cologne Chip DS1001 (septembre 2026), tableau 4.5, indique une
   tension VDDIO maximale de fonctionnement de **2,7 V** pour les GPIO à
   terminaison simple. Le tableau 4.1 fixe la limite maximale absolue de
   VDDIO à **2,75 V**. Une alimentation VDD_EA à 3,3 V dépasse donc les deux
   limites. Un fonctionnement apparent des GPIO ou de l'USB ne prouve pas la
   conformité électrique. L'avis du fabricant de la carte selon lequel
   celle-ci devrait fonctionner ne remplace pas les limites du FPGA. La
   fiabilité et la durée de vie à 3,3 V ne sont pas qualifiées ici.

   Ne connectez pas de pilotes 3,3 V supplémentaires en supposant que le FPGA
   accepte 3,3 V. Ne modifiez pas les cavaliers d'alimentation ni les réglages
   des régulateurs sans vérifier le schéma V005 et tous les périphériques
   connectés à EA. Un convertisseur de niveaux sur les signaux ne suffit pas
   à corriger une **alimentation VDD_EA** hors spécification.

Domaines de tension GPIO et éléments de preuve
-----------------------------------------------

Ne supposez pas que tous les bancs GPIO de l'ULX5M ont la même alimentation.
Le README du dépôt matériel annonce une tension GPIO par défaut de 1,8 V,
mais cela ne permet pas de déterminer la tension de chaque banc sur la carte
V005 effectivement testée.

.. list-table:: Tensions observées sur l'ULX5M-GS V005 (octobre 2026)
   :header-rows: 1
   :widths: 16 16 38 30

   * - Alimentation ou interface
     - Tension indiquée
     - Élément de preuve
     - Réserve
   * - ``VDD_EA`` (banc est EA)
     - 3,3 V
     - Confirmation orale du fabricant pour la carte alimentée par USB
     - Pas encore mesurée directement sur un point VDD_EA ; dépasse DS1001
   * - ``VDD_EB`` (banc est EB)
     - Environ 1,8 V
     - Mesure au multimètre rapportée sur la carte testée
     - Alimentation distincte de EA ; ne pas généraliser à toutes les cartes
   * - ``VDD_WA`` (banc configuration/JTAG)
     - 1,8 V sur le schéma V005
     - Le schéma JTAG relie ``VDD_WA`` à ``+1V8`` ; les broches de mode JTAG
       ont aussi été observées autour de 1,8 V
     - Tigard JTAG utilisé en logique 1,8 V ; pas de mesure directe à la bille
       d'alimentation du FPGA
   * - Autres bancs GPIO
     - Non déterminé ici
     - Vérifier le schéma de la révision et les régulateurs montés
     - Ne pas déduire 1,8 V ou 3,3 V des seules étiquettes de connecteurs

Pour les entrées asymétriques, DS1001 indique une plage de ``-0,4 V`` à
``VDDIO + 0,4 V`` (tableau 4.5). Sur un banc à 1,8 V, une entrée directe à
3,3 V est hors de cette plage. Vérifiez l'alimentation réelle et utilisez
une interface adaptée avant de connecter une logique externe. Pour les
périphériques 3,3 V, consultez le guide Cologne Chip UG1003 sur l'adaptation
de niveaux ; ses exemples supposent que l'alimentation du GateMate respecte
ses limites.

Connexion USB-C
---------------

L'implémentation expérimentale de périphérique USB utilise ces broches EA :

.. list-table:: Broches USB du portage ULX5M-GS
   :header-rows: 1
   :widths: 24 26 50

   * - Fonction
     - Signal GateMate
     - Remarque
   * - USB D+
     - ``IO_EA_A1``
     - Alimentation EA annoncée à 3,3 V ; ne pas en déduire la tension
       exacte sur la ligne D+
   * - USB D-
     - ``IO_EA_B1``
     - Partage le banc EA et sa tension VDDIO
   * - Commande de connexion USB
     - ``IO_EA_A2``
     - Commande la résistance de rappel dans la sonde USB actuelle

L'oscillateur 25 MHz de la carte sert de référence à la PLL USB expérimentale.
Une sonde précédente produisait environ 47,9167 MHz pour une horloge USB
nominale de 48 MHz. La configuration de la PLL, la fréquence maximale après
routage, la précision de l'horloge USB et l'intégrité du signal sont des
questions distinctes : réussir le contrôle de timing ne garantit ni la
conformité des signaux USB ni une énumération fiable.

En octobre 2026, une sonde USB chargée en SRAM par JTAG a été reconnue sous
Windows. Les développements ultérieurs du point de terminaison zéro avec SERV
s'énuméraient aussi, mais les requêtes répétées de descripteurs USB pouvaient
échouer de manière intermittente après des succès précédents. La cause n'a
été attribuée ni au coeur SERV, ni au RTL USB, ni au timing, ni aux tensions
matérielles. Ces échanges intermittents ne prouvent ni que VDD_EA à 3,3 V
est sans danger, ni que cette tension explique les erreurs. Consultez
:doc:`../../user-guide/bootloader` pour les limites des premières sondes
testées sur carte.

JTAG et configuration
---------------------

Le schéma V005 relie les signaux JTAG du GateMate au connecteur Raspberry Pi
à 40 broches (GPIO12/16/20/21 ; broches physiques 32/36/38/40), avec des
résistances série de 200 ohms. Le banc de configuration/JTAG est ``WA``,
alimenté en 1,8 V sur le schéma. Le Tigard, alimenté séparément, est configuré
pour des E/S à 1,8 V ; laissez ``VTGT`` déconnecté et reliez les masses.

.. figure:: ../../images/ulx5m-gs-jtag.png
   :alt: Schéma de configuration et JTAG ULX5M-GS V005 indiquant 1,8 V

   Extrait du schéma configuration/JTAG V005. ``VDD_WA`` est relié à
   ``+1V8`` ; ``JTAG_TCK``, ``JTAG_TMS``, ``JTAG_TDI`` et ``JTAG_TDO``
   sont distincts des broches USB du banc EA.

La carte comporte également six pastilles JTAG sur la face avant. Leur
connecteur correspondant n'a pas été identifié avec certitude ; ne supposez
pas un pas standard de 0,1 pouce ni une empreinte SOP/SC70 à partir des
photographies. Vérifiez les dimensions exactes, l'ordre des broches, la
fixation mécanique et la masse avant de souder un adaptateur. Consultez
:doc:`../../user-guide/bootloader` pour la séquence Tigard testée et
:doc:`../../troubleshooting` pour la récupération après démarrage à froid.

Flash de configuration et état du développement
-----------------------------------------------

La flash SPI de la carte testée a renvoyé l'identifiant JEDEC ``1f 42 16``
(AT25QL321, 4 Mio). Le diagnostic actuel du projet peut lire la flash sans
y écrire ; l'image d'origine a été sauvegardée par blocs de 64 Kio. Le
portage ULX5M reste expérimental : programmer la SRAM du FPGA par JTAG
n'installe pas de bootloader DFU persistant et l'image exécutée est perdue
à la coupure d'alimentation. N'appliquez pas les dispositions de flash ou
les commandes de récupération ULX4M à l'ULX5M.

Sources et vérification des révisions
-------------------------------------

* `Dépôt matériel Intergalaktik ULX5M-GS
  <https://github.com/intergalaktik/ulx5m-gs>`_ - sources V005, schéma et
  indication de tension par défaut.
* `Cologne Chip DS1001, fiche technique GateMate FPGA
  <https://colognechip.com/docs/ds1001-gatemate1-datasheet-latest.pdf>`_ -
  septembre 2026 ; tableaux 4.1 et 4.5 (limites d'alimentation et des GPIO).
* `Cologne Chip UG1003, guide d'interface avec les périphériques 3,3 V
  <https://www.colognechip.com/docs/ug1003-gatemate1-level-shifting-latest.pdf>`_
  - août 2025 ; section 1 et exemples d'interface.

Le fichier ``docs/ds1001-gatemate1-datasheet-latest.pdf`` présent dans le
dépôt est une copie de **janvier 2023**, malgré son nom. Les limites indiquées
ici ont été revérifiées dans la DS1001 du fabricant de **septembre 2026**.
Pour les limites en vigueur, consultez le lien du fabricant plutôt que de
supposer que la copie incluse est la dernière version.

Development record (English translation pending)
------------------------------------------------

.. toctree::
   :maxdepth: 1

   bringup
   multiboot-v72
