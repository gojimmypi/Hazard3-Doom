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

L'UART est le chemin logiciel le plus simple vers le moniteur. Le câblage UART
externe Hazard3-Doom testé utilise le connecteur J1 de l'ULX3S comme suit :

.. list-table::
   :header-rows: 1
   :widths: 24 30 46

   * - Fonction côté FPGA
     - Emplacement sur le connecteur ULX3S
     - Connexion de l'adaptateur externe
   * - ``RxD``
     - J1 broche 8 / ``GP1``
     - Vers le TX de l'adaptateur
   * - ``TxD``
     - J1 broche 6 / ``GP0``
     - Vers le RX de l'adaptateur
   * - ``GND``
     - Masse adjacente
     - Vers la masse de l'adaptateur

Ce câblage est une référence de laboratoire du projet, et non un substitut à la
vérification du LPF et du top-level actifs. Vérifiez toujours le build si les
broches UART changent. Consultez :doc:`pinout-and-revisions` pour le brochage
ULX3S complet et les remarques sur les révisions.

GPIO J1/J2
----------

Les deux connecteurs 40 broches exposent 56 signaux GPIO FPGA nommés en paires
``GP``/``GN`` dans la documentation amont. Certains sont des signaux asymétriques
ordinaires, certains correspondent à de vraies paires FPGA capables de
fonctionner en différentiel et certains sont partagés avec des fonctions ESP32
ou ADC selon la révision du PCB.

Le manuel amont signale également un détail mécanique important :
l'interprétation des broches physiques impaires/paires diffère entre les
connecteurs femelles coudés et les connecteurs mâles verticaux. Utilisez le
schéma et les commentaires des contraintes plutôt que de déduire les numéros de
broche à partir d'une photographie.

Partage avec l'ESP32
--------------------

ULX3S peut inclure un ESP32 fournissant Wi-Fi/Bluetooth et participant à la
programmation FPGA ou à des services côté carte. Plusieurs ressources orientées
FPGA sont partagées, notamment micro-SD et certains signaux GPIO/JTAG sur les
révisions de PCB documentées.

Hazard3-Doom traite donc les interfaces partagées comme des problèmes de
propriété. Le côté qui ne possède pas le bus doit le libérer électriquement.
C'est particulièrement important pour la SD et pour toute expérience utilisant
simultanément les chemins JTAG ESP32 et FPGA.

Autres interfaces de la carte
------------------------------

Boutons, LED, ADC, RTC, audio, OLED/LCD et GPIO capables de fournir une horloge
sont disponibles pour l'expérimentation. Ce sont des ressources pédagogiques
utiles même lorsque le SoC Hazard3-Doom actuel ne les utilise pas toutes.
