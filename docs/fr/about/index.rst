À propos de Hazard3-Doom
========================

Hazard3-Doom est un projet ouvert de matériel et de logiciel FPGA construit
autour du processeur RISC-V Hazard3 et des FPGA Lattice ECP5. Il réunit un
processeur logiciel, des contrôleurs mémoire, un moniteur résident, des
applications exécutées depuis la mémoire externe, la vidéo HDMI, le stockage
micro-SD, le débogage série et JTAG ainsi que les E/S des familles ULX3S et
ULX4M.

Doom est l'application la plus visible, mais c'est aussi une charge de travail
système utile. Son exécution exige bien plus qu'un cœur de processeur : le
chargement d'un exécutable, une carte mémoire correcte, des accès soutenus à la
mémoire externe, des temporisateurs, les entrées, le stockage, la vidéo et une
infrastructure logicielle suffisante pour faire fonctionner durablement une
application C importante. Le projet permet donc d'étudier tout le chemin entre
le RTL et un programme interactif.

Ce que vous pouvez apprendre
----------------------------

Hazard3-Doom peut être abordé à plusieurs niveaux. On peut commencer par charger
un bitstream connu et utiliser le moniteur, puis reconstruire ou modifier
progressivement les couches situées en dessous.

.. list-table::
   :header-rows: 1
   :widths: 27 73

   * - Domaine
     - Exemples de sujets
   * - Conception d'un processeur RISC-V
     - Pipeline Hazard3, configuration ISA, CSR, exceptions, interruptions, comportement des branchements et prise en charge du débogage.
   * - Intégration SoC
     - Interconnexions AHB5/APB, décodage d'adresses, cartes mémoire, temporisateurs, UART et périphériques mappés en mémoire.
   * - Systèmes mémoire
     - SRAM EBR interne, SDR SDRAM externe, DDR3, contrôleurs mémoire, latence, bande passante, initialisation et compromis de timing.
   * - Implémentation FPGA
     - Synthèse Yosys, placement/routage nextpnr, contraintes, balayage des seeds, fermeture temporelle et compromis de ressources sur les ECP5.
   * - Logiciel embarqué
     - Code de démarrage, cartes de l'éditeur de liens, firmware résident, chargement d'exécutables, placement du tas, diagnostics et récupération.
   * - Graphisme et E/S
     - Framebuffers indexés, balayage HDMI, stockage micro-SD, protocoles série, périphériques I2C/SAO et ressources partagées de la carte.
   * - Débogage
     - Diagnostics UART, JTAG, OpenOCD, GDB et corrélation entre pannes logicielles, FPGA et mémoire.
   * - Ingénierie ouverte
     - Builds reproductibles, verrouillage des sous-modules, différences entre l'amont et le projet, licences, documentation et tests de régression.

La visite guidée du processeur commence dans :doc:`../architecture/hazard3/index`.
Les différences entre cartes et mémoires sont résumées dans
:doc:`../reference/board-profiles`.

Pourquoi Doom ?
---------------

Une LED clignotante ou un petit test bare-metal peut démontrer qu'un bloc
fonctionne. Doom impose à de nombreux blocs de fonctionner ensemble pendant une
longue durée. Il sollicite l'exécution des instructions, de grandes structures
de données, la mémoire externe, le chargement de fichiers, les mises à jour du
framebuffer, le timing et l'interaction utilisateur, tout en produisant un
résultat facile à observer.

Les pannes deviennent ainsi instructives. Une texture corrompue, un faible taux
d'images, un échec de démarrage, une exception mémoire ou une régression de
timing après routage peuvent mener directement à l'étude d'une partie précise
du système informatique.

Au-delà de l'enseignement
-------------------------

Le projet peut aussi servir de plateforme d'ingénierie et de prototypage.
L'application Doom peut être considérée comme une charge de référence exigeante,
tandis que les mêmes idées de FPGA et de SoC sont adaptées à d'autres logiciels
ou à du RTL personnalisé. Les usages possibles comprennent :

* l'évaluation d'un processeur logiciel RISC-V associé à une logique FPGA spécifique à l'application ;
* le prototypage de périphériques personnalisés, de ponts de protocoles ou de logique de contrôle déterministe ;
* l'expérimentation sur les architectures mémoire et le partage matériel/logiciel ;
* la réalisation de démonstrateurs utilisant vidéo, stockage, capteurs, caméras ou réseau ;
* l'évaluation d'une chaîne d'outils FPGA ouverte avant la conception d'une carte personnalisée ; et
* l'utilisation d'un FPGA modulaire dans une preuve de concept de produit embarqué.

Hazard3-Doom doit lui-même être considéré comme un projet de développement et
d'enseignement, et non comme une conception de référence certifiée pour la
production. Un produit doit faire l'objet des vérifications habituelles :
fermeture temporelle, exigences électriques, fiabilité, sécurité, disponibilité
des composants, tests de fabrication et licences de chaque composant matériel
et logiciel. Les données du jeu Doom ont également des droits de distribution
distincts de ceux du moteur open source et du projet FPGA.

ULX4M et l'écosystème de cartes porteuses Compute Module
--------------------------------------------------------

L'ULX4M est particulièrement intéressant pour le prototypage car il s'agit d'un
système FPGA modulaire sur module, plutôt que d'une carte de développement tout
en un. Le projet matériel ULX4M le décrit comme compatible avec le brochage des
cartes porteuses Raspberry Pi Compute Module 4 (CM4), ce qui permet d'utiliser
le module FPGA sur des cartes de base de type CM4 ou sur une carte porteuse
conçue spécifiquement.

Cette séparation modulaire est utile aussi bien pour l'enseignement que pour
l'exploration d'un produit : le FPGA et la mémoire restent sur l'ULX4M tandis
que la carte porteuse peut fournir les connecteurs, l'alimentation, les caméras,
les écrans, le réseau, le stockage ou d'autres E/S propres à l'application. Une
équipe peut donc expérimenter plusieurs configurations de cartes porteuses avant
de concevoir une carte personnalisée plus petite ne contenant que les
interfaces nécessaires au produit final.

Le projet ULX4M a indiqué avoir effectué des essais avec plusieurs produits de
type CM4, notamment la carte d'E/S Raspberry Pi Compute Module, des cartes
Waveshare, Piunora et la carte porteuse TOFU. Ces résultats doivent être
considérés comme des exemples de compatibilité et non comme une garantie pour
toutes les révisions ou toutes les interfaces. Vérifiez le schéma de la carte
porteuse, la révision de l'ULX4M, les contraintes de broches FPGA, les tensions
et le RTL qui implémente réellement chaque interface avant de connecter le
matériel.

.. important::

   La compatibilité de brochage CM4 ne signifie **pas** que l'ULX4M est un
   Raspberry Pi ni que les logiciels Raspberry Pi peuvent y être exécutés. Le
   format de carte porteuse commun constitue une possibilité d'intégration
   électrique et mécanique ; l'ULX4M contient un FPGA ECP5 et exécute la logique
   définie par son bitstream.

Pour Hazard3-Doom, le chemin ULX4M-LS actuel utilise de la SDR SDRAM, tandis que
le chemin ULX4M-LD utilise de la DDR3 via LiteDRAM. Les deux variantes permettent
donc de comparer non seulement l'intégration sur carte porteuse, mais aussi des
architectures de contrôleurs mémoire très différentes. Consultez
:doc:`../reference/board-profiles` pour l'état actuel des builds et du timing.

Ressources ULX4M externes
-------------------------

* `Documentation ULX4M <https://github.com/intergalaktik/ulx4m-documentation>`_
* `Dépôt matériel ULX4M <https://github.com/intergalaktik/ulx4m>`_
* `Projet ULX4M et notes de compatibilité des cartes porteuses <https://www.crowdsupply.com/intergalaktik/ulx4m/updates/pre-launch-progress>`_
* `Documentation Raspberry Pi Compute Module <https://www.raspberrypi.com/documentation/computers/compute-module.html>`_
* `Certification Open Source Hardware ULX4M <https://certification.oshwa.org/hr000013.html>`_
