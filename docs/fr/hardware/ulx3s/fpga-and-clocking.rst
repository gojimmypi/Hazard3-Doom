FPGA, horloges et domaines d'E/S
================================

Famille ECP5
------------

ULX3S utilise des FPGA Lattice ECP5 en boîtier 381 billes. Le matériel amont
prévoit des densités 12F, 25F, 45F et 85F. Hazard3-Doom fournit actuellement
des wrappers complets pour les cibles 85F et 12F.

La densité modifie les LUT, EBR et ressources de routage disponibles, mais
n'identifie pas la révision PCB.

Oscillateur 25 MHz
------------------

La conception ULX3S amont fournit un oscillateur embarqué de 25 MHz.
Hazard3-Doom utilise cette référence pour générer les horloges nécessaires au
processeur, à la SDRAM et à la logique vidéo.

Les références actuelles des profils de carte sont :

.. list-table::
   :header-rows: 1
   :widths: 24 20 56

   * - Cible
     - Horloge Hazard3
     - Rôle
   * - ULX3S 85F
     - 50 MHz
     - CPU, logique AHB/SoC, côté contrôleur SDRAM, moniteur et logique de plate-forme.
   * - ULX3S 12F
     - 40 MHz
     - Cible CPU/SoC et SDRAM à ressources réduites.

La vidéo utilise ses propres horloges dérivées ; le travail de fermeture de
timing doit donc prendre en compte plus que la seule horloge CPU. Les valeurs
d'horloge réellement routées sont des résultats du build, pas des
spécifications permanentes de la carte.

SDRAM et timing
---------------

La mémoire externe est de la SDR SDRAM synchrone. Le wrapper et le contrôleur
maintiennent la relation de phase nécessaire entre la logique système et
l'horloge physique SDRAM. Modifier ``HAZARD3_SYS_CLK_HZ`` affecte donc aussi le
sous-système mémoire et les contraintes de timing.

Les valeurs nextpnr par défaut sont centralisées dans
``scripts/build-ecp5-bitstream-common.sh`` et résumées dans
:doc:`../../reference/board-profiles`. Un seed valide pour 85F ne constitue pas
une preuve pour 12F et doit être requalifié après une modification visible par
la synthèse. Voir :doc:`../../reference/timing-sweeps`.


La fermeture du timing dépend de la cible
-----------------------------------------

Hazard3-Doom centralise les réglages de routage nextpnr par défaut dans
``scripts/build-ecp5-bitstream-common.sh``. Les références actuelles des
versions sont également résumées dans :doc:`../../reference/board-profiles`.

Un seed qui réussit sur ULX3S 85F ne prouve pas qu'il réussira sur 12F, et un seed
précédemment valide ne doit pas être supposé toujours valide après une
modification du RTL visible par la synthèse, du préchargement du moniteur, de la
chaîne d'outils ou des contraintes. Consultez :doc:`../../reference/timing-sweeps`
pour le workflow de sweep du projet.

Normes d'E/S
------------

Le LPF décrit à la fois les broches et le comportement électrique. Les GPIO,
la SDRAM et de nombreux périphériques utilisent du LVCMOS 3,3 V. La vidéo GPDI
utilise des sorties appariées et un routage qui doivent correspondre au wrapper
et au fichier de contraintes sélectionnés.
