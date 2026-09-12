Savjeti za virtualne strojeve
=============================

Nekoliko savjeta za Ubuntu u VMware virtualnom stroju. Ovi savjeti nisu potrebni
za Hazard3-Doom alatni lanac, ali mogu poboljšati radno iskustvo.

VMware Tools
------------

Ubuntu 24.04 i 26.04 koriste ``open-vm-tools`` umjesto starijeg zasebnog instalacijskog
programa VMware Tools. Za Ubuntu Desktop gosta instalirajte osnovne alate i
integraciju radne površine:

.. code-block:: bash

   sudo apt update
   sudo apt install open-vm-tools open-vm-tools-desktop
   sudo reboot

Za headless/server gosta obično je dovoljan ``open-vm-tools``.

Dijeljene mape
--------------

Najprije omogućite željene dijeljene mape u postavkama VMware virtualnog stroja.
Novije verzije VMware Tools/open-vm-tools u pravilu izlažu omogućene dijeljene
mape pod ``/mnt/hgfs``. Provjerite s:

.. code-block:: bash

   ls -la /mnt/hgfs

Ako su dijeljene mape omogućene, ali nisu automatski montirane, montirajte ih
ručno pomoću ``vmhgfs-fuse``:

.. code-block:: bash

   sudo mkdir -p /mnt/hgfs

   sudo vmhgfs-fuse .host:/ /mnt/hgfs \
        -o allow_other \
        -o uid="$(id -u)" \
        -o gid="$(id -g)"

USB passthrough za FPGA i UART uređaje
--------------------------------------

Kada koristite VMware, provjerite jesu li FPGA/JTAG adapter i vanjski USB-UART
adapter spojeni na **gosta**, a ne ostavljeni priključeni Windows domaćinu. U
gostu su korisne provjere:

.. code-block:: bash

   lsusb
   lsusb -t

Tipična ULX3S razvojna konfiguracija može prikazati ugrađeni FT231X kao
``0403:6015`` za JTAG i zaseban CH340/CH341 adapter kao ``1a86:7523`` za UART
Hazard3 monitora. To su neovisni USB putovi: OpenOCD može koristiti FT231X dok
Chrome Web Serial koristi vanjski UART adapter.

Na Ubuntuu također provjerite dozvole serijskog uređaja prije pokretanja
preglednika. Pogledajte :doc:`prerequisites` za postavljanje grupe ``dialout`` i
:doc:`../troubleshooting` za ``fuser``, ModemManager, privremene ACL-ove i
dijagnostiku jednosmjernog UART-a.

Ako se FPGA sinteza ili C++ kompilacija neočekivano prekine u malom VM-u,
pogledajte :doc:`../troubleshooting` prije nego što to smatrate pogreškom
kompilatora.
