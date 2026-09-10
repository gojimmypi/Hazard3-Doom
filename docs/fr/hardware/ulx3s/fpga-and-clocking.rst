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

La carte fournit un oscillateur 25 MHz. Hazard3-Doom s'en sert pour générer les
horloges nécessaires au processeur, à la SDRAM et à la vidéo.

Les profils actuels utilisent 50 MHz pour ULX3S 85F et 40 MHz pour ULX3S 12F.
La vidéo possède ses propres horloges dérivées ; une fermeture de timing doit
donc vérifier plus que la seule horloge CPU.

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

Normes d'E/S
------------

Le LPF décrit à la fois les broches et le comportement électrique. Les GPIO,
la SDRAM et de nombreux périphériques utilisent du LVCMOS 3,3 V. La vidéo GPDI
utilise des sorties appariées et un routage qui doivent correspondre au wrapper
et au fichier de contraintes sélectionnés.
