Prérequis
=========

Environnement hôte
------------------

Le projet est conçu pour être construit de manière reproductible dans un environnement Bash. Sous Windows, WSL est l'environnement en ligne de commande recommandé pour le build ; PowerShell reste pratique pour les scripts de téléversement UART.

Vérification des prérequis de la machine
----------------------------------------

Après avoir cloné le dépôt, exécutez le vérificateur non destructif avant le
premier build :

.. code-block:: bash

   ./scripts/requirements-check.sh

Le vérificateur n'installe aucun paquet et ne modifie pas la configuration. Les
éléments requis manquants produisent un code de sortie en échec ; les outils
optionnels de développement, simulation, débogage et documentation sont signalés
séparément. Il vérifie également que le compilateur RISC-V détecté accepte les
options ISA/ABI RV32 utilisées par Hazard3.

Outils requis
-------------

Installez au minimum :

* Git avec prise en charge des sous-modules récursifs.
* Python 3.
* ``pyserial`` pour les téléversements UART.
* Une chaîne d'outils GCC/GDB RISC-V bare-metal.
* Yosys, nextpnr-ecp5, Project Trellis/ecppack et les outils FPGA ULX3S habituels pour construire les bitstreams.
* OpenOCD pour le débogage JTAG.
* ``shellcheck`` pour valider les scripts shell.

Le build du moniteur utilise actuellement ce préfixe RISC-V par défaut :

.. code-block:: text

   /opt/riscv/bin/riscv32-unknown-elf-

Le vérificateur de machine reconnaît également des alternatives courantes
comme ``riscv-none-elf-`` ainsi que les installations xPack. Remplacez le
préfixe du build lorsque votre compilateur est installé ailleurs. Par exemple :

.. code-block:: bash

   TOOLCHAIN_PREFIX=riscv-none-elf- ./scripts/build.sh

Dépendance Python de l'outil de téléversement
---------------------------------------------

.. code-block:: bash

   python3 -m pip install pyserial

IWAD
----

Le dépôt ne distribue pas d'IWAD Doom commercial. Conservez un ``DOOM.WAD`` obtenu légalement en dehors de Git ou dans le répertoire ignoré ``wads/``.

.. warning::

   Ne validez pas et ne redistribuez pas un IWAD Doom commercial dans le dépôt du projet ou dans le build de la documentation.

Liens associés
--------------

* `RISC-V GCC xPack <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_
