Brochages des cartes et câblage
================================

Cette page rassemble les schémas de brochage et les connexions les plus utiles
pour relier des adaptateurs UART, des SAO, du matériel de débogage ou d'autres
périphériques. Le guide matériel reste la référence pour les révisions de PCB,
les schémas, les contraintes LPF et les broches du boîtier FPGA.

ULX3S
-----

.. _fig-ulx3s-pinout:

.. figure:: ../images/ulx3s-pinout.png
   :alt: Brochage ULX3S

   **Brochage ULX3S** - GPIO FPGA et affectations des connecteurs.

L'UART du moniteur Hazard3-Doom utilise ces connexions J1 :

.. code-block:: text

   TX adaptateur  -> J1 broche 8 / GP1 -> Hazard3 RxD
   RX adaptateur  <- J1 broche 6 / GP0 <- Hazard3 TxD
   GND adaptateur -> GND J1 adjacent

TX et RX sont nommés du point de vue de chaque appareil et doivent donc être
croisés comme indiqué. Pour le schéma, le LPF, l'orientation du connecteur et
les révisions de carte, voir :doc:`../hardware/ulx3s/pinout-and-revisions`.

Tigard JTAG vers Hazard3 sur ULX3S
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le connecteur J4 de l'ULX3S donne un accès JTAG externe direct à l'ECP5.
Hazard3 utilise le TAP JTAG matériel de l'ECP5 et la primitive ``JTAGG`` pour
exposer son module de débogage RISC-V. Avec Tigard en mode ``SPI/JTAG`` :

.. list-table:: Tigard vers ULX3S J4
   :header-rows: 1
   :widths: 20 20 20 40

   * - Broche Tigard
     - Signal
     - Couleur
     - ULX3S J4
   * - 2
     - GND
     - Noir
     - GND
   * - 3
     - TCK
     - Blanc
     - TCK
   * - 4
     - TDI
     - Gris
     - TDI
   * - 5
     - TDO
     - Violet
     - TDO
   * - 6
     - TMS
     - Bleu
     - TMS

Alimentez l'ULX3S normalement par US1 et utilisez une logique Tigard 3,3 V.
Ne reliez pas ``VTGT`` afin que Tigard n'alimente pas la carte. ``TRST`` et
``SRST`` ne sont pas nécessaires pour Hazard3. Voir :doc:`jtag-debugging` pour
OpenOCD et les exemples de pas-à-pas GDB.

Tigard JTAG vers l'ESP32 intégré
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Il s'agit d'une cible de débogage différente. L'ESP32 classique de l'ULX3S est
un processeur Xtensa et ses GPIO JTAG 12 à 15 sont partagés avec le connecteur
micro-SD. Ce câblage est dérivé du schéma/LPF ULX3S et du brochage JTAG ESP32;
il n'est pas encore qualifié par le projet sur ULX3S.

.. list-table:: Tigard vers l'ESP32 de l'ULX3S
   :header-rows: 1
   :widths: 18 18 18 20 26

   * - Tigard
     - Signal JTAG
     - Broche ESP32
     - Signal SD ULX3S
     - Contact micro-SD
   * - Broche 4 / gris
     - TDI
     - GPIO12 / MTDI
     - DAT2
     - Broche 1
   * - Broche 3 / blanc
     - TCK
     - GPIO13 / MTCK
     - DAT3
     - Broche 2
   * - Broche 6 / bleu
     - TMS
     - GPIO14 / MTMS
     - CLK
     - Broche 5
   * - Broche 5 / violet
     - TDO
     - GPIO15 / MTDO
     - CMD
     - Broche 3
   * - Broche 2 / noir
     - GND
     - GND
     - VSS
     - Broche 6 ou autre GND

.. warning::

   Ces mêmes signaux SD sont aussi reliés à l'ECP5. N'utilisez pas Tigard sur
   l'ESP32 tant qu'une image FPGA peut piloter le bus SD. Retirez la carte SD et
   utilisez une image FPGA vérifiée qui laisse ``SD_D2``, ``SD_D3``, ``SD_CLK``
   et ``SD_CMD`` en haute impédance.

ULX4M-LD sur le carrier Waveshare CM4
-------------------------------------

.. _fig-ulx4m-ld-pinout:

.. figure:: ../images/ulx4m_ld-pinout.png
   :alt: Brochage ULX4M-LD

   **Brochage ULX4M-LD** - affectations FPGA sur le
   `carrier Waveshare CM4 <https://www.waveshare.com/wiki/CM4-IO-BASE-A#Dimension>`_.

Pour la connexion UART Tigard validée par le projet :

.. code-block:: text

   Tigard UART TX  -> broche physique 16 -> GPIO23 -> FPGA N4 -> uart_rx
   Tigard UART RX  <- broche physique 18 -> GPIO24 <- FPGA N3 <- uart_tx
   Tigard GND      -> broche physique 20
   Tigard VCC      -> non connecté

Ne pas alimenter l'ULX4M depuis Tigard. Voir
:doc:`../hardware/ulx4m/pinout-and-revisions` et :doc:`jtag-debugging`.

Générer des brochages personnalisés
------------------------------------

Les schémas peuvent être régénérés avec le
`générateur de brochage ULX <https://github.com/ulx3s/ulx3s-pinout>`_. Il crée
les correspondances à partir des contraintes LPF puis rend les schémas ULX3S ou
ULX4M-LD en SVG, PNG, PDF ou PS. Ceci est utile pour une autre révision de carte,
un LPF modifié ou une vue adaptée à un projet.

Exemple sous Ubuntu ou WSL :

.. code-block:: bash

   git clone https://github.com/ulx3s/ulx3s-pinout.git
   cd ulx3s-pinout
   python3 -m pip install --user --upgrade pinout cairosvg pillow
   ./generate-data-from-lpf.py ulx3s --include aliases \
       --markdown output/ulx3s/PIN-MAPPING.md
   ./generate-pinout.py ulx3s --format png

Avant de connecter du matériel externe
---------------------------------------

* Confirmez la carte et la révision PCB exactes.
* Confirmez le bitstream FPGA actif et les contraintes LPF.
* Vérifiez la tension d'E/S et le sens des signaux.
* Reliez les masses avant de vous fier à un signal UART ou autre signal simple.
* Ne supposez pas qu'une position de connecteur garde la même fonction entre
  différentes révisions de carte ou de carrier.

Références externes
--------------------

* `Manuel matériel ULX3S <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_
* `Générateur de brochage ULX <https://github.com/ulx3s/ulx3s-pinout>`_
* `Tigard <https://github.com/tigard-tools/tigard>`_
* `Brochage JTAG ESP32 <https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/jtag-debugging/configure-other-jtag.html>`_
* `Sources matérielles ULX4M <https://github.com/intergalaktik/ulx4m>`_
