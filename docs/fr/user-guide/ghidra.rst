Analyse statique avec Ghidra
============================

Le projet fournit une extension Ghidra pour analyser les exécutables H3IMG.
Elle comprend un chargeur H3IMG et un analyseur des registres d'entrée/sortie
mappés en mémoire (MMIO). Ghidra ne lance ni le FPGA ni le moniteur.

Sources et installation
-----------------------

Le code et les instructions de compilation et d'installation se trouvent dans
`ghidra/Hazard3H3IMG <https://github.com/ulx3s/Hazard3-Doom/tree/develop/ghidra/Hazard3H3IMG>`_.
Consultez son ``README.md`` pour les versions de Ghidra et Java prises en
charge. Utilisez une extension compatible avec votre version de Ghidra.

Importer une image H3IMG
------------------------

1. Installez l'extension, puis redémarrez Ghidra si nécessaire.
2. Créez ou ouvrez un projet Ghidra.
3. Choisissez **File > Import File** et sélectionnez le fichier ``.h3img``.
4. Sélectionnez le chargeur H3IMG si nécessaire et vérifiez l'architecture
   RISC-V ainsi que la carte mémoire.
5. Ouvrez le programme dans CodeBrowser et exécutez l'analyse.
6. Vérifiez l'adresse d'entrée, la région chargée et la zone BSS.

Le format comprend un en-tête de 64 octets et une charge utile. Voir
:doc:`../reference/h3img-format`. Le chargeur représente la zone BSS comme
mémoire non initialisée; il n'exécute pas le moniteur.

Analyse MMIO
------------

Activez l'analyseur MMIO dans les options d'analyse du programme. Il définit
des plages d'adresses et des noms de registres. Il ne résout pas nécessairement
tous les accès indirects ou les adresses construites par plusieurs instructions
RISC-V. Certaines références doivent être examinées manuellement.

Voir :doc:`../reference/apb-peripherals` et
:doc:`../architecture/memory-map` pour les adresses des registres.

Limitations
-----------

* Ghidra effectue une analyse statique; pour le débogage du matériel actif,
  voir :doc:`jtag-debugging`.
* H3IMG n'est pas ELF et ne contient pas les symboles ELF ou les données DWARF.
  Conservez le fichier ELF correspondant pour l'analyse avec symboles.
* Les adresses MMIO dépendent de la version du matériel et du logiciel.
* Le fichier IWAD de Doom est distinct de l'image H3IMG.
