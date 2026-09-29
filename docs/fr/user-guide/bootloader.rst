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
connectez ``US2``.

Si la carte ne s'alimente pas depuis ``US2`` en raison de son état d'alimentation USB/RTC, le README du bootloader amont décrit deux options de récupération : connecter également ``US1``, ou maintenir ``BTN1`` et appuyer brièvement sur ``BTN0`` pour alimenter la carte. Vérifiez avec :

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

Pour une mise à jour normale, coupez l'alimentation, maintenez PCB ``BTN3``
pendant la connexion du câble Micro-B, attendez l'énumération de ``1d50:614b``,
puis relâchez ``BTN3``. Le bouton ne doit pas rester maintenu pendant le
transfert. Sous WSL, si Bash signale ``Permission denied`` pour les outils
Windows fournis :

.. code-block:: bash

   chmod +x ./bin/openFPGALoader.exe ./bin/dfu-util.exe

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

Pin de la chaîne d'outils CI pour 0.2.0
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le workflow GitHub Actions ``ULX4M Bootloader`` de la version 0.2.0 épingle
volontairement OSS CAD Suite sur ``2026-09-14``. Cela conserve l'environnement
de synthèse et de placement-routage connu comme bon pour la validation de cette
version au lieu de suivre silencieusement de nouvelles nightly.

Une nightly ultérieure a révélé un problème de pilotes multiples dans
l'utilisation existante de ``TRELLIS_IO`` ECP5 configuré uniquement en entrée.
Le nettoyage RTL, les essais avec une suite plus récente et toute mise à jour
délibérée de la version CAD épinglée sont prévus pour 0.3.0. D'ici là,
l'épinglage 0.2.0 fait partie de l'environnement de build reproductible du
bootloader.

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


La procédure de récupération ULX4M-LD documentée dans ``bootloader/README_ULX4M_BOOTLOADER.md`` a été validée sur une ULX4M-LD v0.0.3 avec un FPGA LFE5UM-85F et l'IDCODE JTAG ``0x01113043``. N'utilisez pas une image construite pour une autre densité FPGA ou un mappage de carte non vérifié.

Séquence de remplacement sûre
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

La règle essentielle est : **validez le bootloader de remplacement dans la SRAM
du FPGA avant d'écrire la région persistante du bootloader en flash**.

Une séquence conservatrice est :

#. Construisez le bootloader prévu pour la carte et le FPGA exacts.
#. Reconditionnez une image de test uniquement SRAM sans le réglage persistant
   ``--bootaddr``.
#. Chargez cette image par JTAG et vérifiez le fonctionnement DFU ordinaire.
#. Vérifiez séparément le mode de mise à niveau du bootloader.
#. Sauvegardez la région bootloader alt 5 existante avant de l'écraser.
#. Préparez une image de exactement 2 Mio pour alt 5.
#. Exécutez depuis la SRAM un bootloader connu comme bon en mode mise à niveau.
#. Écrivez le remplacement dans alt 5 pendant l'exécution de cette copie SRAM.
#. Relisez alt 5 avant tout cycle d'alimentation.
#. Vérifiez la relecture octet par octet ou avec des SHA256 identiques.
#. Ce n'est qu'après une relecture réussie que vous pouvez couper l'alimentation
   et effectuer les tests de démarrage à froid.

Cette procédure évite volontairement d'exécuter le bootloader résidant en flash
pendant le remplacement de cette même région.

Sauvegarder l'alt 5 de l'ULX4M-LD
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Lorsque l'alt 5 a été volontairement exposé par le mode de mise à niveau du
bootloader, sauvegardez les 2 premiers Mio avant toute écriture :

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -U bootloader-alt5-before-update.bin

Vérifiez la taille de la sauvegarde et consignez un hash :

.. code-block:: bash

   stat -c '%n: %s bytes' bootloader-alt5-before-update.bin
   sha256sum bootloader-alt5-before-update.bin

La taille attendue est exactement ``2097152`` octets.

Écrire et vérifier un remplacement
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Avec un bootloader SRAM connu comme bon toujours actif dans le mode de mise à
niveau volontaire, écrivez une image de exactement 2 Mio dans alt 5 :

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -D bootloader-alt5-2m.img

Ne redémarrez **pas** immédiatement. Relisez d'abord la région :

.. code-block:: bash

   ./bin/dfu-util.exe \
       -d 1d50:614b \
       -a 5 \
       -U bootloader-alt5-after-update.bin

Vérifiez ensuite que les deux fichiers font exactement 2 Mio et ont le même
hash :

.. code-block:: bash

   stat -c '%n: %s bytes' \
       bootloader-alt5-2m.img \
       bootloader-alt5-after-update.bin

   sha256sum \
       bootloader-alt5-2m.img \
       bootloader-alt5-after-update.bin

Ne démarrez pas à froid sur le remplacement si les tailles ou les hashes
diffèrent.

Vérification du démarrage à froid ULX4M-LD
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Après une relecture alt 5 vérifiée, coupez complètement l'alimentation pour
perdre l'image de test chargée en SRAM. Vérifiez ensuite les trois chemins de
démarrage persistants :

#. Aucun bouton : le bitstream utilisateur normal démarre.
#. ``BTN3`` du PCB : le DFU ordinaire démarre et alt 5 reste masqué.
#. ``BTN2`` + ``BTN3`` du PCB : le DFU de mise à niveau démarre et alt 5 est visible.

Le remplacement du bootloader n'est terminé qu'après la réussite de ces trois
tests.

Récupération JTAG lorsque le DFU persistant n'est pas disponible
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Si le bootloader persistant ne s'énumère pas comme ``1d50:614b``, le chemin de
récupération ULX4M-LD validé utilise Tigard/JTAG pour charger un bootloader
d'urgence dans la SRAM du FPGA. La source du bootloader fournit
``EMERGENCY_RESTORE2`` afin de forcer à la fois le maintien en DFU et l'autorisation
d'écriture du bootloader pour restaurer alt 5.

La chaîne de récupération est :

.. code-block:: text

   Tigard JTAG
       -> emergency bootloader in FPGA SRAM
       -> USB DFU 1d50:614b
       -> alt 5 access
       -> restore exactly first 2 MiB
       -> read back exactly first 2 MiB
       -> SHA256 match
       -> cold boot from SPI flash

Pour les commandes exactes de build ULX4M-LD, la procédure de reconditionnement
SRAM, le remappage des boutons, le brochage et les détails du build d'urgence,
utilisez le document source du dépôt
``bootloader/README_ULX4M_BOOTLOADER.md``. Ces étapes sont volontairement hors du
chemin de programmation normal de Hazard3-Doom car elles concernent la
récupération de la carte et le développement du bootloader, et non la
programmation ordinaire de l'application.

Note sur la protection en écriture du bootloader ULX3S
------------------------------------------------------

Le bootloader ULX3S amont peut protéger en écriture les 2 premiers Mio sur les
flash 16 Mio ISSI IS25LP128 et Winbond W25Q128 prises en charge. Le comportement
de protection dépend du fabricant de la flash. Le README amont avertit également
que certaines versions de ``openFPGALoader`` peuvent retirer une protection en
écriture non OTP lors de l'écriture de la flash.

Traitez toute mise à jour de la région bootloader ULX3S comme une opération de
maintenance distincte. N'utilisez pas des commandes de flash persistante qui
écrasent les 2 premiers Mio simplement pour installer une nouvelle image
utilisateur Hazard3-Doom.

Sources
-------

* ``bootloader/README.md`` - fonctionnement DFU ULX3S et protection flash.
* ``bootloader/README_ULX4M_BOOTLOADER.md`` - procédure ULX4M-LD validée de
  construction, test SRAM, sauvegarde, récupération, installation et readback.

Références d'implémentation
---------------------------

* `openFPGALoader <https://trabucayre.github.io/openFPGALoader/guide/install.html>`_
