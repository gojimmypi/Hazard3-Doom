Prérequis
=========

Environnement hôte
------------------

Le projet est conçu pour être construit de manière reproductible dans un environnement Bash. Sous Windows, WSL est l'environnement en ligne de commande recommandé pour le build ; PowerShell reste pratique pour les scripts de téléversement UART.

Outils requis
-------------

Installez au minimum :

* Git avec prise en charge des sous-modules récursifs.
* Python 3.
* ``pyserial`` pour les téléversements UART.
* Une chaîne d'outils GCC/GDB RISC-V bare-metal.
* Yosys, nextpnr-ecp5, Project Trellis/ecppack et les outils FPGA ULX3S habituels pour construire les bitstreams.
* OpenOCD pour le débogage JTAG.

Le préfixe RISC-V connu comme fonctionnel avec le projet est :

.. code-block:: text

   /opt/riscv/bin/riscv32-unknown-elf-

Remplacez-le si nécessaire :

.. code-block:: bash

   TOOLCHAIN_PREFIX=/path/to/riscv32-unknown-elf- ./scripts/build.sh

Dépendance Python de l'outil de téléversement
---------------------------------------------

.. code-block:: bash

   python3 -m pip install pyserial

IWAD
----

Le dépôt ne distribue pas d'IWAD Doom commercial. Conservez un ``DOOM.WAD`` obtenu légalement en dehors de Git ou dans le répertoire ignoré ``wads/``.

.. warning::

   Ne validez pas et ne redistribuez pas un IWAD Doom commercial dans le dépôt du projet ou dans le build de la documentation.
