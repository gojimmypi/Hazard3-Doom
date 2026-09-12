VM Tips
=======

Some tips for Ubuntu on a VMware virtual machine. These tips are not required for the
Hazard3-Doom toolchain, but they may improve your experience.

VMware Tools
------------

Ubuntu 24.04 and 26.04 use ``open-vm-tools`` rather than the older bundled VMware Tools
installer. For an Ubuntu Desktop guest, install both the core tools and desktop
integration:

.. code-block:: bash

   sudo apt update
   sudo apt install open-vm-tools open-vm-tools-desktop
   sudo reboot

For a headless/server guest, ``open-vm-tools`` is normally sufficient.

Shared folders
--------------

Enable the desired shared folders in the VMware virtual-machine settings first.
Recent VMware Tools/open-vm-tools releases normally expose enabled shares below
``/mnt/hgfs``. Check with:

.. code-block:: bash

   ls -la /mnt/hgfs

If the shared folders are enabled but are not mounted automatically, mount them
manually with ``vmhgfs-fuse``:

.. code-block:: bash

   sudo mkdir -p /mnt/hgfs

   sudo vmhgfs-fuse .host:/ /mnt/hgfs \
        -o allow_other \
        -o uid="$(id -u)" \
        -o gid="$(id -g)"

USB passthrough for FPGA and UART devices
-----------------------------------------

When using VMware, make sure the FPGA/JTAG adapter and external USB-UART adapter
are connected to the **guest**, not left attached to the Windows host. Inside the
guest, useful checks are:

.. code-block:: bash

   lsusb
   lsusb -t

A typical ULX3S development setup may expose the on-board FT231X as
``0403:6015`` for JTAG and a separate CH340/CH341 adapter as ``1a86:7523`` for
the Hazard3 monitor UART. These are independent USB paths: OpenOCD can own the
FT231X while Chrome Web Serial owns the external UART adapter.

On Ubuntu, also verify serial-device permissions before launching the browser.
See :doc:`prerequisites` for ``dialout`` setup and :doc:`../troubleshooting` for
``fuser``, ModemManager, temporary ACLs, and one-way UART diagnostics.

If FPGA synthesis or C++ compilation is killed unexpectedly in a small VM, see
:doc:`../troubleshooting` before treating it as a compiler failure.
