Conseils pour les machines virtuelles
=====================================

Quelques conseils pour Ubuntu dans une machine virtuelle VMware. Ils ne sont pas
requis par la chaîne d'outils Hazard3-Doom, mais peuvent améliorer l'utilisation.

VMware Tools
------------

Ubuntu 24.04 utilise ``open-vm-tools`` plutôt que l'ancien programme d'installation
VMware Tools fourni séparément. Pour un invité Ubuntu Desktop, installez les outils
de base et l'intégration du bureau :

.. code-block:: bash

   sudo apt update
   sudo apt install open-vm-tools open-vm-tools-desktop
   sudo reboot

Pour un invité sans interface graphique ou de type serveur, ``open-vm-tools`` est
généralement suffisant.

Dossiers partagés
-----------------

Activez d'abord les dossiers souhaités dans les paramètres de la machine virtuelle
VMware. Les versions récentes de VMware Tools/open-vm-tools exposent normalement
les partages activés sous ``/mnt/hgfs``. Vérifiez avec :

.. code-block:: bash

   ls -la /mnt/hgfs

Si les dossiers sont activés mais ne sont pas montés automatiquement, montez-les
manuellement avec ``vmhgfs-fuse`` :

.. code-block:: bash

   sudo mkdir -p /mnt/hgfs

   sudo vmhgfs-fuse .host:/ /mnt/hgfs \
        -o allow_other \
        -o uid="$(id -u)" \
        -o gid="$(id -g)"

Si la synthèse FPGA ou une compilation C++ est interrompue de façon inattendue
dans une petite VM, consultez :doc:`../troubleshooting` avant de conclure à une
erreur du compilateur.
