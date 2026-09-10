Mémoire externe : SDR SDRAM
===========================

ULX3S fournit de la SDR SDRAM synchrone externe sur 16 bits. Hazard3-Doom
l'utilise comme mémoire de travail principale pour l'application chargée, le
tas, les données IWAD et les autres objets trop volumineux pour l'EBR de l'ECP5.

Voir aussi :doc:`../../architecture/hazard3/memory-and-bus`.

Chemin du contrôleur
--------------------

.. code-block:: text

   Hazard3 -> AHB5 -> ahb_sdram.v -> ulx3s_sdram_controller.v -> SDR SDRAM 16 bits

Le contrôleur gère activation/précharge, latence CAS, rafraîchissement, masques
d'octets et interface physique. L'adaptateur coordonne aussi les accès CPU et
vidéo lorsque la configuration vidéo sélectionnée le requiert.

Profils mémoire
---------------

ULX3S 85F utilise actuellement le profil ``64m`` à 50 MHz. ULX3S 12F utilise
``32m`` par défaut à 40 MHz et peut sélectionner ``64m`` lorsque la population
SDRAM et l'ensemble de la configuration sont adaptés.

Un profil logiciel ne remplace pas l'identification de la mémoire physique. La
documentation ULX3S amont décrit plusieurs capacités SDRAM selon les populations
de carte. Si la capacité exacte compte, vérifiez le marquage, la révision du
schéma/BOM et les tests d'alias mémoire.

EBR et SDRAM sont différentes
-----------------------------

L'EBR est une RAM interne au FPGA et peut contenir le moniteur résident préchargé
dans le bitstream. La SDRAM est un composant externe qui doit être initialisé et
rafraîchi. Le moniteur peut donc démarrer en EBR, initialiser la SDRAM puis y
charger Doom et le WAD.

La configuration réussie du FPGA ne prouve pas à elle seule que la SDRAM est
saine ; les tests mémoire du moniteur et les tests Doom font partie de la
qualification matérielle.
