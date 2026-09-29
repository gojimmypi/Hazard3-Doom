Prérequis
=========

Environnement hôte
------------------

Les scripts de build et de développement du projet nécessitent un environnement
Linux/Bash. Sous Linux natif, utilisez le shell Bash normal. Sous Windows,
utilisez **WSL avec Ubuntu** : WSL est requis pour les builds depuis les sources
et pour les scripts shell du dépôt. N'exécutez pas les scripts de build depuis
PowerShell ou ``cmd.exe``.

Windows natif reste approprié lorsque la documentation demande explicitement le
Device Tool du navigateur, la gestion des pilotes USB, un téléversement UART via
port COM ou un ``.exe`` Windows fourni. Sauf mention explicite PowerShell ou
``cmd.exe``, exécutez les blocs de commandes sous WSL/Bash.

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
* Une chaîne d'outils GCC/GDB RISC-V bare-metal disponible dans ``PATH``.
* Yosys, nextpnr-ecp5, Project Trellis/ecppack et les outils FPGA ULX3S habituels pour construire les bitstreams.
* OpenOCD pour le débogage JTAG.
* ``shellcheck`` pour valider les scripts shell (optionnel, mais recommandé).

Chaîne d'outils FPGA
--------------------

La chaîne d'outils FPGA recommandée est `OSS CAD Suite
<https://github.com/YosysHQ/oss-cad-suite-build>`_, fournie sous forme de
binaires précompilés. Elle comprend Yosys, nextpnr, Project Trellis/ecppack et
des outils associés pour Linux, macOS et Windows. Sous Ubuntu/WSL,
``full-install.sh`` installe et active automatiquement la version OSS CAD Suite
attendue par le projet. Vous pouvez également installer vous-même une version
d'OSS CAD Suite et activer son environnement afin que ses outils soient
disponibles dans ``PATH``.

Pour les travaux avancés de développement ou de reproductibilité, les scripts
d'installation proposent également des options de compilation depuis les
sources qui construisent certains outils FPGA à partir de commits GitHub amont
spécifiques. La compilation des outils FPGA depuis les sources n'est pas
nécessaire pour l'installation normale.

Sous Windows, OSS CAD Suite recommande WSL avec le paquet Linux-x64 pour la
meilleure expérience, ce qui correspond également à l'environnement Bash/WSL
utilisé par Hazard3-Doom.

Chaîne d'outils GCC RISC-V
--------------------------

Le build utilise une chaîne d'outils GCC RISC-V bare-metal compatible trouvée
dans ``PATH``. ``riscv-none-elf-*`` est directement pris en charge et les
installations RISC-V GCC xPack sont également reconnues. Sous Ubuntu/WSL,
macOS ou une autre distribution Linux, utilisez un paquet GCC RISC-V bare-metal
adapté à la plate-forme ou installez xPack, puis vérifiez que le compilateur est
disponible dans ``PATH``. Les noms des paquets varient selon la distribution.

Utilisez ``TOOLCHAIN_PREFIX`` pour sélectionner explicitement une installation.
Par exemple :

.. code-block:: bash

   TOOLCHAIN_PREFIX=riscv-none-elf- ./scripts/build.sh

L'ancien préfixe ``/opt/riscv/bin/riscv32-unknown-elf-`` reste pris en charge
pour compatibilité, mais l'installation sous ``/opt`` n'est pas requise.

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

* `OSS CAD Suite <https://github.com/YosysHQ/oss-cad-suite-build>`_
* `RISC-V GCC xPack <https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases>`_

* `Yosys <https://github.com/YosysHQ/yosys>`_
* `nextpnr <https://github.com/YosysHQ/nextpnr>`_
