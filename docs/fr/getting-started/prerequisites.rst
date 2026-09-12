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

Accès au port série sous Linux
-------------------------------

Sous Linux natif, y compris dans une VM Ubuntu, les adaptateurs USB-UART
apparaissent généralement sous ``/dev/ttyUSB0``, ``/dev/ttyUSB1``, etc. Le nœud
de périphérique appartient normalement à ``root:dialout`` avec le mode
``0660``. Vérifiez le périphérique actif et les groupes de votre session avant
d'utiliser Web Serial ou les chargeurs Python :

.. code-block:: bash

   ls -l /dev/ttyUSB*
   groups

Si le périphérique UART appartient à ``dialout`` mais pas votre utilisateur,
ajoutez celui-ci au groupe :

.. code-block:: bash

   sudo usermod -aG dialout "$USER"

Le nouveau groupe supplémentaire s'applique à une **nouvelle session de
connexion**. Déconnectez-vous du bureau Ubuntu puis reconnectez-vous avant de
lancer le navigateur. Exécuter ``groups`` dans un terminal déjà ouvert juste
après ``usermod`` montre encore les anciens groupes de la session.

Pour un test temporaire sans redémarrage, déconnexion ou reconnexion USB,
accordez à l'utilisateur courant l'accès au nœud de périphérique existant avec
une ACL :

.. code-block:: bash

   sudo setfacl -m u:"$USER":rw /dev/ttyUSB1

Remplacez ``ttyUSB1`` par le périphérique réel. ``setfacl`` est fourni par le
paquet Ubuntu ``acl``. Cette ACL est un état de diagnostic lié au nœud de
périphérique et peut disparaître lors d'une ré-énumération USB ; l'appartenance
à ``dialout`` est la configuration persistante normale.

Voir :doc:`../troubleshooting` pour la propriété du port, ModemManager, Web
Serial et les diagnostics d'un UART fonctionnant dans un seul sens.

IWAD
----

Le dépôt ne distribue pas d'IWAD Doom commercial. Conservez un ``DOOM.WAD`` obtenu légalement en dehors de Git ou dans le répertoire ignoré ``wads/``.

.. warning::

   Ne validez pas et ne redistribuez pas un IWAD Doom commercial dans le dépôt du projet ou dans le build de la documentation.

Liens associés
--------------

* `RISC-V GCC xPack <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_
