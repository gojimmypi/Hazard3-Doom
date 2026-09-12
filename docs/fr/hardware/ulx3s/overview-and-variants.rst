Vue d'ensemble et variantes de carte
====================================

Qu'est-ce qu'ULX3S ?
--------------------

ULX3S est une carte de développement FPGA ECP5 autonome et open hardware,
créée pour l'enseignement de la logique numérique, la recherche et les projets
FPGA embarqués. Elle associe un Lattice ECP5 à de la SDR SDRAM et à de nombreux
périphériques utilisables sans grande carte porteuse.

Les ressources représentatives comprennent un ECP5 en boîtier 381 billes, de
la SDR SDRAM 16 bits, une flash SPI, deux ports micro-USB, un FT231X sur ``US1``,
la vidéo GPDI, une micro-SD, deux connecteurs GPIO 40 broches, un ESP32, des
boutons/LED, l'audio, un connecteur d'affichage, un ADC, un RTC et une horloge
25 MHz.

Hazard3-Doom n'utilise pas tous ces périphériques. Le projet se concentre sur
Hazard3, la SDRAM externe, la vidéo GPDI, le moniteur/UART/JTAG, la
programmation FPGA, le démarrage micro-SD et certaines interfaces partagées
FPGA/ESP32.

Densité FPGA et révision PCB
----------------------------

La famille ULX3S existe avec des ECP5 12F, 25F, 45F et 85F. La révision du PCB
évolue indépendamment de cette densité.

.. list-table:: Cibles Hazard3-Doom documentées
   :header-rows: 1

   * - Cible
     - Profil mémoire
     - Mémoire externe
     - Horloge Hazard3
   * - ULX3S 85F
     - ``64m``
     - SDR SDRAM 16 bits, contrôleur natif du projet
     - 50 MHz
   * - ULX3S 12F
     - ``32m`` par défaut; ``64m`` optionnel si la carte convient
     - SDR SDRAM 16 bits, contrôleur natif du projet
     - 40 MHz

Une carte 25F ou 45F n'est pas automatiquement une cible Hazard3-Doom complète.
Il faut également une route de synthèse qualifiée, des contraintes adaptées et
des essais matériels.

Discipline de révision
----------------------

Pour le débogage matériel, notez au minimum la révision PCB, la densité et le
boîtier FPGA, la population SDRAM et le fichier LPF réellement utilisé. Les
schémas d'une autre révision restent instructifs, mais ne doivent pas être
considérés comme le brochage exact de toutes les cartes ULX3S.
