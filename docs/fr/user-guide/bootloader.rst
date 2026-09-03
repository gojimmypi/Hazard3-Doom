Fonctionnement et récupération du bootloader DFU
=================================================

.. important::

   Le remplacement du bootloader DFU de la carte est **très inhabituel**. Il ne
   fait **pas** partie de l'installation normale de Hazard3-Doom, du chargement
   d'un nouveau bitstream FPGA, de la mise à jour du moniteur Hazard3 ni des
   mises à jour de Doom.

   En utilisation normale, conservez le bootloader existant et remplacez
   uniquement le **bitstream utilisateur** dans la zone DFU prévue à cet effet.
   N'exposez et n'écrivez la zone flash du bootloader que pour le développement
   intentionnel du bootloader ou pour récupérer une carte dont le bootloader
   persistant est absent, corrompu ou connu comme incompatible.

Cette page décrit le bootloader USB DFU de niveau carte utilisé par ULX3S et
ULX4M-LD. L'utilisation DFU normale est volontairement séparée de la procédure
rare de remplacement et de récupération du bootloader.

Ne pas confondre ces trois composants
-------------------------------------

``Bootloader DFU``
   Configuration FPGA persistante et petit environnement firmware au début de
   la flash SPI. Il fournit l'accès USB DFU puis transfère le contrôle vers
   l'image FPGA utilisateur.

``Bitstream FPGA utilisateur``
   Image FPGA normale de Hazard3-Doom. Sa mise à jour est courante et ne
   nécessite pas le remplacement du bootloader DFU.

``Moniteur de démarrage Hazard3``
   Firmware RISC-V construit par Hazard3-Doom, par exemple
   ``hazard3-boot-monitor.elf``. Le reconstruire ou le charger ne signifie pas
   qu'il faut remplacer le bootloader DFU de la carte.

Pour tester ou installer une nouvelle image FPGA Hazard3-Doom, utilisez
:doc:`../getting-started/programming`. Pour le débogage firmware via JTAG,
utilisez :doc:`jtag-debugging`.

Quand un remplacement du bootloader est réellement justifié
------------------------------------------------------------

Le remplacement doit être considéré comme une opération avancée de maintenance
ou de récupération. Les raisons typiques sont limitées aux cas suivants :

* le bootloader DFU persistant ne s'énumère plus et a été diagnostiqué comme
  absent ou corrompu ;
* une révision de carte exige une modification volontaire du brochage ou de la
  compatibilité du bootloader ;
* vous développez et validez le bootloader lui-même.

L'installation de Hazard3-Doom, un nouveau bitstream FPGA, une modification de
Hazard3/LiteDRAM, une mise à jour de ``hazard3-boot-monitor.elf`` ou le chargement
de Doom ne sont **pas** des raisons de remplacer le bootloader.

Utilisation normale
-------------------

Le périphérique USB DFU s'énumère avec VID:PID ``1d50:614b``. Le bitstream
utilisateur normal utilise l'alternate setting 0. Une mise à jour normale cible
donc **alt 0**, pas la zone du bootloader.

ULX3S
~~~~~

Le bootloader ULX3S fournit DFU sur ``US2``. Le passthrough ``US1`` destiné à la
programmation ESP32 est spécifique à ULX3S et ne doit pas être supposé sur
ULX4M-LD.

Pour entrer en DFU sur ULX3S, maintenez ``BTN1`` ou placez ``SW1`` sur ON puis
connectez ``US2``. Vérifiez avec :

.. code-block:: bash

   dfu-util -l

Programmez normalement le bitstream utilisateur sur alt 0 :

.. code-block:: bash

   dfu-util -a 0 -D blink.bit

Pour quitter DFU et exécuter l'image stockée :

.. code-block:: bash

   dfu-util -a 0 -e

ULX4M-LD
~~~~~~~~

Le brochage validé ULX4M-LD v0.0.3 utilise les étiquettes physiques suivantes :

.. list-table:: Comportement au démarrage ULX4M-LD
   :header-rows: 1
   :widths: 35 65

   * - Condition
     - Résultat
   * - Aucun bouton
     - Démarre le bitstream utilisateur à partir de ``0x200000``.
   * - PCB ``BTN3``
     - DFU normal ; alt 0 à 4 visibles, alt 5 caché.
   * - PCB ``BTN2`` + ``BTN3``
     - DFU de mise à niveau du bootloader ; alt 0 à 5 visibles.

.. warning::

   ``BTN2`` + ``BTN3`` n'est **pas** le mode normal de programmation. Il expose
   alt 5, qui contient le bootloader. Pour une mise à jour Hazard3-Doom normale,
   utilisez ``BTN3`` seul et programmez alt 0.

Le layout DFU validé est :

.. list-table:: Alternate settings ULX4M-LD
   :header-rows: 1
   :widths: 10 35 55

   * - Alt
     - Plage flash
     - Usage
   * - 5
     - ``0x000000-0x1FFFFF``
     - Bootloader, caché en DFU normal.
   * - 4
     - ``0x800000-0xFFFFFF``
     - Données utilisateur.
   * - 3
     - ``0x400000-0xFFFFFF``
     - Données utilisateur.
   * - 2
     - ``0x360000-0x3FFFFF``
     - Zone SaxonSoc U-Boot.
   * - 1
     - ``0x340000-0x35FFFF``
     - Zone SaxonSoc ``fw_jump``.
   * - 0
     - ``0x200000-0xFFFFFF``
     - Bitstream utilisateur normal.

Commande normale de programmation Hazard3-Doom :

.. code-block:: bash

   ./bin/openFPGALoader.exe --dfu \
       --vid 0x1d50 --pid 0x614b --altsetting 0 \
       ./build/fpga_ulx4m_ld.bit

Puis, pour quitter DFU :

.. code-block:: bash

   ./bin/dfu-util.exe -a 0 -e

Cette commande ``-e`` ne remplace pas le bootloader ; elle démarre l'image
utilisateur déjà stockée.

Remplacement et récupération rares
-----------------------------------

.. danger::

   Ne remplacez pas un bootloader fonctionnel simplement parce qu'une nouvelle
   version de Hazard3-Doom est disponible. Une mise à jour du bootloader écrit
   les premiers 2 Mio de flash et peut supprimer le chemin de récupération DFU
   le plus simple.

Pour ULX4M-LD, la règle essentielle est de valider le nouveau bootloader en SRAM
FPGA **avant** d'écrire la zone persistante alt 5.

Séquence conservatrice :

#. Construire le bootloader pour la carte et le FPGA exacts.
#. Créer et tester une image SRAM sans ``--bootaddr`` persistant.
#. Vérifier séparément le DFU normal et le mode de mise à niveau.
#. Sauvegarder les 2 Mio existants d'alt 5.
#. Préparer une image alt 5 de exactement 2 Mio.
#. Exécuter un bootloader connu comme bon depuis la SRAM en mode mise à niveau.
#. Écrire alt 5.
#. Relire alt 5 avant toute coupure d'alimentation.
#. Vérifier taille et SHA256.
#. Seulement ensuite effectuer les tests de démarrage à froid.

Sauvegarde alt 5 :

.. code-block:: bash

   ./bin/dfu-util.exe -d 1d50:614b -a 5 \
       -U bootloader-alt5-before-update.bin

La taille attendue est exactement ``2097152`` octets.

Après l'écriture, relisez la région et comparez les hashes avant de couper
l'alimentation. Si DFU persistant est indisponible, la procédure ULX4M-LD
validée utilise Tigard/JTAG pour charger en SRAM un bootloader d'urgence avec
``EMERGENCY_RESTORE2`` puis restaurer alt 5.

Pour les commandes exactes de construction, de repacking SRAM, de récupération
et de validation, consultez ``bootloader/README_ULX4M_BOOTLOADER.md``. Ces étapes
restent volontairement séparées du chemin normal de programmation.

Sources
-------

* ``bootloader/README.md`` - fonctionnement DFU ULX3S et protection flash.
* ``bootloader/README_ULX4M_BOOTLOADER.md`` - procédure ULX4M-LD validée de
  construction, test SRAM, sauvegarde, récupération, installation et readback.
