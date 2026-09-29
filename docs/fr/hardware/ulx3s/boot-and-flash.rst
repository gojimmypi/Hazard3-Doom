Configuration FPGA, flash et chemins de démarrage
=================================================

ULX3S propose plusieurs chemins de programmation. Il faut distinguer clairement
la SRAM de configuration ECP5, la flash SPI et la mémoire logicielle de Hazard3.

Configuration volatile
-----------------------

Le chemin ``US1`` FT231X/JTAG peut charger la SRAM de configuration ECP5 avec
``fujprog``, ``openFPGALoader``, OpenOCD/SVF ou le flasher WebUSB de
Hazard3-Doom. Ce chargement est **volatile** et disparaît à la coupure
d'alimentation.

Flash SPI persistante
---------------------

La flash SPI embarquée contient les images FPGA persistantes chargées au
redémarrage. Un bitstream Hazard3-Doom complet peut également précharger le
moniteur résident dans l'EBR ; ce moniteur apparaît alors lorsque le FPGA se
configure, que le bitstream provienne d'un chargement temporaire ou de la flash.

Rôles de ``US1`` et ``US2``
---------------------------

``US1`` est le port principal pour l'alimentation, le FT231X et les workflows
JTAG habituels. ``US2`` est relié aux broches FPGA et sert notamment au chemin
DFU optionnel lorsque le bootloader ULX3S est installé.

Le flasher WebUSB normal de Hazard3-Doom utilise ``US1``. Le bootloader DFU est
un mécanisme séparé et ne doit pas être remplacé simplement pour installer un
nouveau bitstream Doom.

Voir :doc:`../../user-guide/bootloader` et
:doc:`../../getting-started/programming`.


Flux d'image utilisateur DFU
----------------------------

Lorsque le bootloader DFU ULX3S pris en charge est déjà installé, ``US2`` peut
programmer l'image utilisateur normale dans la flash SPI. La documentation du
bootloader du projet utilise l'alternative DFU 0 pour l'image utilisateur et
réserve le remplacement du bootloader aux opérations avancées de récupération
ou de développement du bootloader.

Consultez :doc:`../../user-guide/bootloader` pour la procédure exacte d'entrée
et :doc:`../../getting-started/programming` pour les choix de programmation
normaux.

Chargement logiciel à l'exécution
---------------------------------

OpenOCD/GDB peut charger du logiciel dans un FPGA déjà configuré sans réécrire
la flash de configuration. Ce changement est lui aussi volatile.

.. code-block:: text

   chargement SRAM FPGA -> configuration matérielle volatile
   écriture flash SPI   -> configuration FPGA persistante
   chargement ELF JTAG  -> état logiciel/moniteur volatile
   fichiers micro-SD    -> données persistantes amovibles
