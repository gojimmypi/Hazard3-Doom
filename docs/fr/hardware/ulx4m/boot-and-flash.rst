Configuration, flash SPI, USB DFU et JTAG
=========================================

ULX4M dispose de plusieurs chemins de programmation et de démarrage. Ils ont des
rôles différents.

Trois couches distinctes
------------------------

``Bootloader DFU de la carte``
   Configuration/firmware FPGA persistant près du début de la flash SPI. Il
   fournit l'accès USB DFU et lance normalement l'image utilisateur.

``Bitstream utilisateur Hazard3-Doom``
   Configuration ECP5 contenant le SoC Hazard3, la mémoire, la vidéo et le
   moniteur résident.

``Moniteur Hazard3 / image Doom``
   Logiciel RISC-V exécuté après configuration du FPGA. Sa reconstruction ne
   signifie pas qu'il faut remplacer le bootloader DFU.

Voir :doc:`../../user-guide/bootloader` et
:doc:`../../getting-started/programming`.

Organisation de la flash
-------------------------

La documentation amont décrit les 2 premiers MiB (``0x000000`` à ``0x1fffff``)
comme zone du bootloader/protégée et l'image utilisateur à partir de
``0x200000``. La plupart des expériences FPGA doivent donc rester dans la SRAM
du FPGA ou la zone utilisateur normale.

USB DFU
-------

Le bootloader amont s'énumère avec VID:PID ``1d50:614b`` et le projet utilise
l'alternative DFU 0 pour l'image utilisateur. Le dépôt contient aussi
``scripts/ulx4m-bootloader.sh`` pour les rares opérations de construction,
validation et récupération du bootloader lui-même.

.. warning::

   Ne remplacez pas un bootloader DFU fonctionnel simplement parce que le
   bitstream Hazard3-Doom, le profil mémoire ou le moniteur résident a changé.

JTAG
----

ULX4M propose JTAG externe et des possibilités JTAG via GPIO. Hazard3-Doom
utilise JTAG à la fois pour l'accès au FPGA ECP5 et pour le module de débogage
RISC-V Hazard3 via l'infrastructure JTAG ECP5. La cible ULX4M-LD 85F actuelle
utilise l'IDCODE ``0x01113043``.

Pour une nouvelle route ou un changement risqué, un chargement temporaire en
SRAM FPGA est préférable lorsque le programmateur le permet. Une coupure
d'alimentation restaure alors le chemin persistant.

Tests en SRAM ou en flash
-------------------------

Pour valider un nouveau routage, un profil mémoire ou une modification FPGA à
risque, il est préférable de charger le bitstream dans la SRAM du FPGA lorsque
le programmateur disponible le permet. Un cycle d'alimentation restaure alors
le chemin de configuration persistant. Ne flashez l'image utilisateur qu'après
que le bitstream a réussi les tests de mise au point prévus.
