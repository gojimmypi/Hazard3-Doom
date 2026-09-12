Interfaces USB, JTAG, UART, GPIO et ESP32
=========================================

Chemin ``US1`` FT231X
---------------------

Le port principal ``US1`` atteint le FT231X utilisé par les workflows de
communication et de programmation JTAG. Hazard3-Doom l'utilise pour
``fujprog``, le flasher WebUSB, OpenOCD avec le support FT231X/``ft232r`` et les
workflows série de la carte/ESP32 lorsque le pilote FTDI normal est actif.

L'UART du moniteur Hazard3 testé par le projet utilise le câblage J1 ``GP0``/``GP1``
décrit ci-dessous ; l'ouverture du port série FT231X de ``US1`` ne doit pas être
considérée comme le même chemin de signal.

Sous Windows, le choix de pilote est important ; consultez
:doc:`../../troubleshooting` et :doc:`../../user-guide/web-flasher` avant de le
modifier.

JTAG externe
------------

ULX3S possède aussi un connecteur JTAG six broches avec TCK, TDI, TDO, TMS,
3,3 V et GND. Vérifiez l'ordre des signaux et la tension avant de brancher un
adaptateur externe.

UART Hazard3-Doom
-----------------

Le câblage UART externe testé utilise :

.. code-block:: text

   RxD -> J1 broche 8 / GP1  (vers TX de l'adaptateur)
   TxD -> J1 broche 6 / GP0  (vers RX de l'adaptateur)
   GND -> masse adjacente

Ce câblage est une référence de laboratoire du projet ; confirmez toujours le
LPF actif si les broches UART ont changé.

GPIO et ESP32
-------------

J1/J2 exposent 56 signaux FPGA sous forme de paires ``GP``/``GN``. Certaines
broches sont simples, d'autres différentielles et certaines sont partagées avec
l'ESP32 ou l'ADC selon la révision PCB. La documentation amont signale aussi une
différence de numérotation physique entre connecteurs femelles coudés et mâles
verticaux.

L'ESP32 peut participer à la programmation et à des services de carte. Les
interfaces partagées, notamment SD et certains signaux JTAG/GPIO, doivent être
gérées comme des problèmes de propriété électrique.
