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

   TX adaptateur  -> J1 broche 6 / GP0 -> Hazard3 RxD
   RX adaptateur  <- J1 broche 8 / GP1 <- Hazard3 TxD
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

Les schémas de brochage peuvent être régénérés ou adaptés avec le
`ULX Pinout Generator <https://github.com/ulx3s/ulx3s-pinout>`_ autonome. L'outil
construit des diagrammes annotés à partir de fichiers de contraintes propres à
la carte, de correspondances de connecteurs, d'images de carte et
d'informations de mise en page, plutôt que de maintenir un seul brochage édité
à la main. Il prend actuellement en charge ULX3S et ULX4M-LD.

Le générateur est utile lorsque vous voulez :

* régénérer le diagramme publié à partir de ses données source ;
* sélectionner un LPF d'une autre révision de carte ULX3S ;
* examiner les alias ou les métadonnées électriques enregistrés dans un LPF ;
* voir quels sites FPGA reliés au connecteur ULX4M-LD sont utilisés par le LPF
  d'un design donné ;
* produire une sortie SVG, PNG, PDF ou PostScript ; ou
* ajuster le placement, la largeur ou la couleur des étiquettes, ainsi que
  d'autres paramètres géométriques du diagramme.

.. warning::

   Les diagrammes générés sont des aides à la documentation, pas un remplacement
   du schéma de la carte ni du fichier de contraintes réellement utilisé pour
   construire l'image FPGA. Avant de connecter du matériel, vérifiez
   l'alimentation des connecteurs, les sites FPGA, la révision du PCB,
   l'orientation des connecteurs, les ressources partagées et le LPF choisi.

Fonctionnement du générateur
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

La génération de la correspondance et le rendu du diagramme sont volontairement
séparés. Le flux normal est :

.. code-block:: text

   board constraint file
           |
           v
   boards/<board>/generator.py
           |
           v
   boards/<board>/data.py
           |
           +---------------- board image
           +---------------- styles.css
           |
           v
   boards/<board>/layout.py
           |
           v
   output/<board>/pinout_*.{svg,png,pdf,ps}

``generate-data-from-lpf.py`` sélectionne le parseur LPF propre à la carte et
écrit les données de correspondance générées. ``generate-pinout.py`` charge le
``layout.py`` de la carte choisie et rend le ``data.py`` existant. Le rendu ne
sélectionne ni ne régénère **silencieusement** une configuration LPF ; régénérez
donc d'abord les données de correspondance chaque fois que vous changez le LPF
ou les options de génération.

Exécutez toutes les commandes depuis la racine du dépôt ``ulx3s-pinout``. La
configuration des cartes utilise des chemins relatifs au dépôt.

Installation sous Ubuntu ou WSL
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le workflow normal est basé sur Python. Sous Ubuntu ou WSL :

.. code-block:: bash

   sudo apt update
   sudo apt install python3-pip

   cd /mnt/c/workspace
   git clone https://github.com/ulx3s/ulx3s-pinout.git
   cd ulx3s-pinout

   python3 -m pip install --user --upgrade pinout cairosvg pillow

Les dépendances ont des rôles distincts :

* ``pinout`` construit le modèle objet du diagramme et exporte le SVG ;
* ``cairosvg`` assure la conversion en PNG, PDF et PostScript ; et
* ``Pillow`` valide les images et normalise la photographie du carrier
  ULX4M-LD avant l'application des coordonnées calibrées des connecteurs.

Listez à tout moment les cartes prises en charge avec :

.. code-block:: bash

   ./generate-data-from-lpf.py --list-boards
   ./generate-pinout.py --list-boards

Démarrage rapide ULX3S
~~~~~~~~~~~~~~~~~~~~~~

Les données ULX3S par défaut sont générées à partir de la configuration LPF
v3.1.6/v3.1.7 et incluent les alias reconnus utilisés par le brochage commité :

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       --include aliases \
       --markdown output/ulx3s/PIN-MAPPING.md

Rendez le SVG par défaut :

.. code-block:: bash

   ./generate-pinout.py ulx3s

Ou rendez un PNG :

.. code-block:: bash

   ./generate-pinout.py ulx3s --format png

Les sorties normales sont :

.. code-block:: text

   output/ulx3s/pinout_ulx3s.svg
   output/ulx3s/pinout_ulx3s.png
   output/ulx3s/PIN-MAPPING.md

Le SVG généré incorpore l'image de la carte et peut donc être consulté sans
connexion réseau.

Utiliser un autre LPF ULX3S
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le dépôt contient plusieurs fichiers de contraintes ULX3S dans
``boards/ulx3s/constraints/``, notamment des variantes v1.7-patch, v2.0, v3.1.4
et v3.1.6. Pour générer à partir d'un LPF précis présent dans le dépôt,
fournissez-le explicitement :

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v20.lpf \
       --include aliases \
       --markdown output/ulx3s/PIN-MAPPING-v20.md

   ./generate-pinout.py ulx3s --format png

Pour expérimenter sans remplacer le ``data.py`` ULX3S commité, écrivez la
correspondance dans un fichier temporaire :

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v20.lpf \
       -o build/ulx3s-v20-data.py

Ce fichier temporaire est utile pour l'inspection et la comparaison. Le renderer
utilise normalement ``boards/ulx3s/data.py`` sauf si l'implémentation de la
carte est modifiée pour consommer autre chose.

Étiquettes LPF optionnelles ULX3S
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le diagramme de base n'a pas besoin d'afficher toutes les métadonnées du LPF.
Utilisez ``--include`` pour sélectionner des champs supplémentaires. Demandez
au générateur installé la liste actuelle faisant autorité avec :

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s --list-fields

Les champs actuels comprennent :

.. code-block:: text

   aliases
   connector
   flags
   iobuf
   pullmode
   io_type
   drive
   frequency
   comment
   all

Voici quelques exemples utiles.

Inclure uniquement les alias :

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v316.lpf \
       --include aliases

Inclure les alias et les métadonnées électriques les plus utiles :

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v316.lpf \
       --include aliases,connector,flags,pullmode,io_type,drive,frequency

Inclure toutes les paires clé/valeur ``IOBUF`` analysées :

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v316.lpf \
       --include iobuf

Demander une clé ``IOBUF`` arbitraire précise :

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s \
       boards/ulx3s/constraints/ulx3s_v316.lpf \
       --iobuf-key SLEWRATE

Les champs ont les significations suivantes :

* ``aliases`` combine les alias reconnus dans les commentaires GP/GN avec les
  autres noms ``LOCATE COMP`` actifs qui utilisent le même site FPGA. Les alias
  en double ne sont émis qu'une fois.
* ``connector`` émet les étiquettes de connecteur telles que ``J1_5+``,
  ``J1_5-``, ``J2_35+`` et ``J2_35-``. Lorsqu'un commentaire LPF fournit un
  token de connecteur explicite, le générateur le vérifie par rapport au modèle
  physique.
* ``flags`` extrait des indicateurs utiles des commentaires, tels que ``DIFF``,
  ``PCLK`` et ``GR_PCLK``.
* ``iobuf`` émet toutes les paires clé/valeur ``IOBUF`` analysées. ``pullmode``,
  ``io_type`` et ``drive`` sélectionnent des sous-ensembles plus restreints.
* ``frequency`` émet les métadonnées ``FREQUENCY PORT`` lorsqu'elles existent.
* ``comment`` émet le commentaire GP/GN complet. Il peut rendre les étiquettes
  très larges et sert principalement à l'audit.
* ``all`` active tous les champs optionnels pris en charge, y compris le
  commentaire brut.

Formes GPIO vectorielles et scalaires ULX3S
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Certains LPF ULX3S contiennent à la fois des noms vectoriels et scalaires pour
les mêmes GPIO :

.. code-block:: text

   gp[0]..gp[27] / gn[0]..gn[27]
   gp0..gp27     / gn0..gn27

Le générateur vérifie que les deux formes se résolvent vers le même ``SITE``
FPGA. En revanche, pour les alias et les métadonnées électriques, les formes ne
sont pas fusionnées aveuglément. ``--gpio-form auto`` est la valeur par défaut
et préfère la forme vectorielle complète.

Sélectionnez explicitement une forme si nécessaire :

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s --gpio-form vector
   ./generate-data-from-lpf.py ulx3s --gpio-form scalar

Le LPF v3.1.6/v3.1.7 contient actuellement une différence connue de métadonnées
pour GN12. La forme vectorielle spécifie ``PULLMODE=UP``, ``IO_TYPE=LVCMOS33``
et ``DRIVE=4`` sans entrée ``FREQUENCY``, tandis que la forme scalaire spécifie
``PULLMODE=NONE``, ``IO_TYPE=LVCMOS33`` et ``FREQUENCY=50 MHZ``. Le générateur
normal signale cela comme un avertissement, et la suite de tests du dépôt
s'attend à cet avertissement.

Pour rendre fatale toute divergence de métadonnées vectoriel/scalair, ajoutez :

.. code-block:: bash

   --strict-form-metadata

Numérotation physique et validation ULX3S
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

La correspondance ULX3S générée suit la convention du fichier de contraintes
pour les connecteurs femelles J1/J2 coudés à 90 degrés montés sur le dessus de
la carte. Si vous utilisez des connecteurs mâles verticaux sous le PCB ou un
câble plat, vérifiez l'orientation avant le câblage. Regarder le connecteur
depuis le côté opposé peut inverser la relation gauche/droite apparente.

Le générateur valide ces invariants importants :

.. code-block:: text

   J1 contains physical pins 1..40 exactly once
   J2 contains physical pins 1..40 exactly once
   GP0..GP27 appear exactly once
   GN0..GN27 appear exactly once

Les plages GPIO sont :

.. code-block:: text

   J1: GP0..GP13 and GN0..GN13
   J2: GP14..GP27 and GN14..GN27

Vérifiez toujours les sites du boîtier FPGA par rapport au LPF sélectionné au
lieu d'inférer un site à partir des broches voisines.

Étiquettes projet/utilisateur ULX3S
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Les étiquettes propres au projet sont séparées des métadonnées dérivées du LPF.
C'est ainsi que le générateur peut afficher des annotations sémantiques comme
les étiquettes UART de GP0 et GP1 sans prétendre que ces significations de
projet font partie du fichier de contraintes de la carte.

Supprimez les étiquettes projet/utilisateur avec :

.. code-block:: bash

   ./generate-data-from-lpf.py ulx3s --no-user-labels

Utilisez ``--include`` pour les informations dérivées du LPF et le mécanisme
d'étiquettes utilisateur pour les significations propres au projet.

Démarrage rapide ULX4M-LD
~~~~~~~~~~~~~~~~~~~~~~~~~

Générez la correspondance ULX4M-LD par défaut et la table Markdown :

.. code-block:: bash

   ./generate-data-from-lpf.py ulx4m-ld \
       --markdown output/ulx4m-ld/PIN-MAPPING.md

Rendez une sortie SVG ou PNG :

.. code-block:: bash

   ./generate-pinout.py ulx4m-ld
   ./generate-pinout.py ulx4m-ld --format png

Les sorties normales sont :

.. code-block:: text

   output/ulx4m-ld/pinout_ulx4m_ld.svg
   output/ulx4m-ld/pinout_ulx4m_ld.png
   output/ulx4m-ld/PIN-MAPPING.md

Le générateur ULX4M-LD garde volontairement deux couches distinctes :

* le câblage fixe connecteur Raspberry Pi -> CM4 -> site FPGA ULX4M-LD ; et
* l'utilisation actuelle de ces sites FPGA par le LPF.

Cette distinction est importante car un site physiquement connecté au
connecteur 40 broches peut aussi être consommé par une autre ressource du
design. Le LPF sélectionné détermine les noms de ressources actifs affichés
dans cette couche du diagramme ; ils ne sont pas codés en dur dans le dessin.

Générer toutes les cartes prises en charge
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Une fois que le ``data.py`` de chaque carte contient la correspondance voulue,
rendez toutes les cartes avec :

.. code-block:: bash

   ./generate-pinout.py all

Là encore, cela rend les données de carte existantes. Les LPF de chaque carte
ne sont pas régénérés.

Formats de sortie et noms de fichiers
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Le renderer prend en charge :

.. code-block:: text

   svg
   png
   pdf
   ps

Exemples :

.. code-block:: bash

   ./generate-pinout.py ulx3s --format svg
   ./generate-pinout.py ulx3s --format png
   ./generate-pinout.py ulx4m-ld --format pdf
   ./generate-pinout.py ulx4m-ld --format ps

Pour un nom de fichier personnalisé lors de la génération d'une seule carte :

.. code-block:: bash

   ./generate-pinout.py ulx4m-ld \
       --format svg \
       --output output/ulx4m-ld/custom.svg

La génération écrase normalement le fichier de sortie choisi. Utilisez
``--no-overwrite`` pour conserver le fichier existant et permettre à
``pinout.manager`` de choisir un nom de sortie unique.

Utilisation avancée directe de pinout.manager
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

``generate-pinout.py`` est le front-end orienté carte recommandé, mais chaque
``layout.py`` de carte expose aussi l'objet de module ``diagram`` attendu par le
workflow ``pinout.manager`` d'origine.

ULX3S :

.. code-block:: bash

   python3 -m pinout.manager \
       --export boards/ulx3s/layout.py output/ulx3s/pinout_ulx3s.svg \
       --overwrite

ULX4M-LD :

.. code-block:: bash

   python3 -m pinout.manager \
       --export boards/ulx4m-ld/layout.py output/ulx4m-ld/pinout_ulx4m_ld.svg \
       --overwrite

Personnaliser les diagrammes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Traitez les LPF, le code du générateur propre à la carte, les images de carte,
le code de mise en page et ``styles.css`` comme des sources. Régénérez
``data.py`` et les images de sortie au lieu de modifier durablement les fichiers
SVG ou PNG générés.

Pour les modifications de correspondance ou d'étiquettes dérivées du LPF,
travaillez dans :

.. code-block:: text

   boards/ulx3s/generator.py
   boards/ulx3s/constraints/*.lpf

   boards/ulx4m-ld/generator.py
   boards/ulx4m-ld/constraints/*.lpf

Pour le placement et la géométrie, modifiez le layout de la carte :

.. code-block:: text

   boards/ulx3s/layout.py
   boards/ulx4m-ld/layout.py

Le layout gère les dimensions du diagramme, le placement de l'image de carte,
les positions des groupes d'étiquettes, la géométrie des lignes de repérage,
les largeurs sémantiques des étiquettes, leur hauteur et espacement, le centrage
de la carte, le placement de la légende et les coordonnées de calibration
propres à la carte.

Les largeurs d'étiquettes ULX3S sont choisies selon leur type sémantique. Le
layout contient notamment :

.. code-block:: text

   PIN_NUMBER_LABEL_WIDTH
   GPIO_SIGNAL_LABEL_WIDTH
   FPGA_SITE_LABEL_WIDTH
   POWER_LABEL_WIDTH
   GROUND_LABEL_WIDTH
   USER_LABEL_WIDTH
   ALIAS_LABEL_WIDTH
   CONNECTOR_LABEL_WIDTH
   METADATA_LABEL_WIDTH
   ANALOG_LABEL_WIDTH
   PWM_LABEL_WIDTH
   TOUCH_LABEL_WIDTH
   DEFAULT_LABEL_WIDTH

La géométrie des pastilles ULX3S est également paramétrée dans
``boards/ulx3s/layout.py``, notamment le rayon des coins, la couleur de bordure
et sa largeur. Le style visuel partagé, comme les couleurs GP/GN, les couleurs
des paires différentielles, les sites FPGA, l'alimentation et la masse, les
alias, les métadonnées de connecteur, les lignes de repérage, les polices et la
légende, se trouve dans ``styles.css``.

Lors d'une modification du placement ULX4M-LD, gardez la calibration mesurée
des extrémités du connecteur Raspberry Pi séparée du placement des étiquettes.
Ce sont les coordonnées du connecteur qui maintiennent les lignes de repérage
attachées aux bonnes broches sur la photographie du carrier.

Valider les modifications
~~~~~~~~~~~~~~~~~~~~~~~~~~

Exécutez les mêmes vérifications de parsing et de rendu que celles du workflow
GitHub Actions du dépôt :

.. code-block:: bash

   ./scripts/test-pinout.sh

Les sorties temporaires de validation sont écrites sous :

.. code-block:: text

   build/pinout-tests/

La suite de tests vérifie la syntaxe Python, la découverte des cartes, l'aide de
la ligne de commande, le rendu SVG et PNG des deux cartes, la lisibilité des
PNG, la reproductibilité des ``data.py`` par défaut commités, la génération de
la table Markdown, chaque fichier de contraintes ULX3S et ULX4M-LD présent dans
le dépôt, le chemin des alias ULX3S, ShellCheck lorsqu'il est disponible, et le
fait que les tests ne modifient aucun fichier suivi.

Une exécution réussie produit au minimum ces fichiers rendus :

.. code-block:: text

   build/pinout-tests/rendered/pinout_ulx3s.svg
   build/pinout-tests/rendered/pinout_ulx3s.png
   build/pinout-tests/rendered/pinout_ulx4m_ld.svg
   build/pinout-tests/rendered/pinout_ulx4m_ld.png

Avant de commiter une modification de brochage, inspectez aussi visuellement les
diagrammes. Confirmez la présence de l'image de carte, que les étiquettes de
connecteur pointent vers les bons trous, que les comptes J1/J2 et GP/GN sont
complets, que les sites du boîtier FPGA correspondent au fichier de contraintes
et que les affectations alimentation/masse correspondent au schéma de la
révision de carte visée. Les vérifications automatisées complètent, mais ne
remplacent pas, la vérification visuelle et du schéma.

Dépannage
~~~~~~~~~

``module '<name>' has no attribute 'diagram'``
   ``pinout.manager`` exige un objet de module nommé ``diagram``. Chaque
   ``layout.py`` de carte doit l'exposer.

L'export PNG, PDF ou PS échoue alors que SVG fonctionne
   Le chemin de conversion CairoSVG est plus strict avec certaines syntaxes CSS
   que les navigateurs modernes. Utilisez des valeurs RGB classiques séparées
   par des virgules, comme ``rgb(34, 173, 0)``, plutôt que les valeurs CSS Color
   4 séparées par des espaces, comme ``rgb(34 173 0)``.

ULX3S signale l'avertissement de métadonnées GN12
   Il s'agit de la différence connue de métadonnées vectoriel/scalair
   v3.1.6/v3.1.7 décrite ci-dessus. Elle est autorisée par la suite de tests
   normale. Utilisez ``--strict-form-metadata`` si vous voulez volontairement
   faire échouer la génération en présence de cette différence.

Le test de reproductibilité ``data.py`` échoue
   Les données de carte commitées doivent être reproductibles avec les options
   de génération par défaut du dépôt. Pour ULX3S, la valeur par défaut commitée
   inclut ``--include aliases``. Le test affiche un diff lorsque les données
   générées ne correspondent pas au fichier commité.

Les étiquettes sont rendues mais l'image de la carte est absente
   Vérifiez que l'image propre à la carte existe :

   .. code-block:: bash

      ls -lh boards/ulx3s/ulx3s.png
      ls -lh boards/ulx4m-ld/cm4-io-base-b-3_3.jpg

   Les deux layouts incorporent l'image de la carte dans le SVG généré.

Le navigateur affiche encore un ancien SVG
   Les fichiers SVG locaux peuvent être mis en cache. Rechargez le fichier ou
   fermez puis rouvrez l'onglet du navigateur après régénération.

Le dépôt contient d'anciens répertoires utilitaires tels que ``fpga2pinout/``,
``svg2png/`` et ``png2base64/``. Ce sont des outils historiques qui ne sont pas
nécessaires au workflow Python actuel de génération ULX3S ou ULX4M-LD.

Avant de connecter du matériel externe
---------------------------------------

* Confirmez la carte exacte et la révision du PCB.
* Confirmez le bitstream FPGA actif et les contraintes LPF.
* Vérifiez la tension d'E/S et la direction des signaux avant toute connexion.
* Connectez les masses avant de compter sur l'UART ou d'autres signaux
  single-ended.
* Ne supposez pas qu'une position de connecteur conserve la même fonction entre
  révisions de carte ou de carrier.

Les diagrammes sont des références visuelles pratiques, mais les contraintes
actives et le schéma du matériel réellement devant vous déterminent la connexion
électrique effective.

Références externes
-------------------

* `Manuel matériel ULX3S <https://github.com/emard/ulx3s/blob/master/doc/MANUAL.md>`_
* `Sources matérielles ULX3S <https://github.com/emard/ulx3s>`_
* `ULX Pinout Generator <https://github.com/ulx3s/ulx3s-pinout>`_
* `Adaptateur matériel/debug Tigard <https://github.com/tigard-tools/tigard>`_
* `Brochage JTAG ESP32 <https://docs.espressif.com/projects/esp-idf/en/stable/esp32/api-guides/jtag-debugging/configure-other-jtag.html>`_
* `Sources matérielles ULX4M <https://github.com/intergalaktik/ulx4m>`_
* `Schéma Waveshare CM4-IO-BASE-A <https://files.waveshare.com/upload/a/aa/CM4-IO-BASE-A_V4_SchDoc.pdf>`_
* `Carrier Waveshare CM4-IO-BASE-A <https://www.waveshare.com/wiki/CM4-IO-BASE-A>`_
