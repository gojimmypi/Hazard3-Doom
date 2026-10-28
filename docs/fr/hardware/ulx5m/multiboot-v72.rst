ULX5M-GS v72 : démarrage secondaire en fonctionnement vérifié (28 octobre 2026)
================================================================================

.. important::

   Cette page documente une expérience matérielle **isolée** réussie sur la
   carte ULX5M-GS V005. Le primaire v72 n'implémente pas l'USB DFU. Le
   bootloader de production SERV/BTN2 n'est **pas encore terminé**. Conservez
   les fichiers de restauration v63c, les sauvegardes intégrales du flash
   d'origine et le candidat v72 exact.

Preuves de validation matérielle
--------------------------------

L'outil d'installation v72c a indiqué que les deux lectures indépendantes de
référence du flash de 4 Mio étaient identiques, avec le SHA-256
``644c7c1b26e4cc2ba419a59a53ca8ffbbc02e808920d68336e84ac886d81cb02``.
Il a vérifié un seul IDCODE JTAG GateMate ``0x20000001``, le JEDEC du flash
``1f 42 16`` et l'image intégrale du flash après écriture. Seuls les premiers
64 Kio du primaire ont été remplacés ; l'application secondaire v41 vérifiée
est restée à ``0x201000``. Le premier bloc v63c sauvegardé et l'image
intégrale de la puce ont été conservés.

Après avoir coupé l'alimentation, placé SW1 sur OFF/OFF (SPI actif), laissé
BTN2 relâché et remis la carte sous tension, l'utilisateur a observé D6
allumée et D7 clignotante, puis D0 clignotante et D1-D7 défilantes. Ce motif
confirme l'exécution de l'application v41 connue, et non seulement l'écriture
réussie d'une commande ou une simulation de RECFG. Aucune configuration du
FPGA par SRAM/JTAG n'a participé à ce démarrage SPI actif.

.. list-table:: Empreintes du matériel et des images
   :header-rows: 1
   :widths: 37 63

   * - Élément
     - Valeur vérifiée
   * - Taille du primaire v72
     - 14 987 octets
   * - SHA-256 du primaire v72
     - ``839696d7c8a4ecdf63dff904c01ce85aea280bd885eda4309c7e5d25800e3aa0``
   * - SHA-256 de la commande dérivée de l'image v72
     - ``8fbec9715a209dac2dc35dc6b517972b9d64dcdc5a7b4437fac7731a0d2849e4``
   * - SHA-256 du candidat v72c des premiers 64 Kio
     - ``b31d6b84b9fd849007da4aae23010fd1f98efa000a74aab7336a495eb5699fdc``
   * - SHA-256 du flash intégral v63c avant installation
     - ``644c7c1b26e4cc2ba419a59a53ca8ffbbc02e808920d68336e84ac886d81cb02``
   * - SHA-256 du flash intégral après installation de v72
     - ``56d10293b68afbf21c353c7733a0a5d39a97c20d3f5a9c87b0335a09c7f36397``
   * - SHA-256 du secteur secondaire v41
     - ``28b1e5cbfa45a319600ec38c81207a36d9889c3179e8055f5a663c616ef97bee``
   * - Session de récupération v72c
     - ``build-ulx5m-gs/v72c-registered-ab-20261028T193955726442Z-508``
   * - Outils et routage
     - OSS CAD Suite 2026-07-20 ; objectif 25 MHz, fréquence maximale après
       routage 79,26 MHz ; seed 302, CCGM1A1

Le fichier ``state.json`` d'origine de cette session indique que le transfert
d'exécution n'avait pas été testé : c'était son état lors de l'installation.
L'observation ultérieure des LED après mise sous tension a confirmé le résultat
matériel. Ne modifiez pas rétroactivement ce fichier historique pour revendiquer
une vérification matérielle automatisée.

Ce que démontrent les essais réussis et échoués
-----------------------------------------------

.. list-table:: Comparaisons matérielles contrôlées
   :header-rows: 1
   :widths: 13 53 34

   * - Variante
     - Particularité
     - Résultat matériel
   * - v65
     - RECFG minimal en SPI actif, sans les six entrées GPIO West-A
     - Démarrage secondaire : PASS
   * - v66
     - Six broches du flash de configuration affectées à des GPIO utilisateur
       exclusivement en entrée
     - Démarrage secondaire : FAIL
   * - v67
     - Conception v66 routée, bit de propriété des E/S d'état de configuration
       effacé dans l'image empaquetée
     - Démarrage secondaire : PASS
   * - v68
     - Mise à jour de l'état de banque avant RECFG
     - Démarrage secondaire : FAIL
   * - v70
     - Commande exacte de 27 octets dérivée de TinyDFU, attente de repos plus
       courte et enregistrement différent des sorties
     - Démarrage secondaire : FAIL
   * - v72
     - Commande, données et validité enregistrées, avec la séquence finale
       documentée et l'attente après commande inspirée de TinyDFU
     - Démarrage secondaire : PASS

Cette comparaison établit qu'un CRC et une charge utile d'état corrects ne
suffisent pas à eux seuls. Elle ne révèle **pas** une unique défaillance de
temporisation de v70. Ne raccourcissez pas la séquence v72 validée sans nouvel
essai distinct.

Séquence de commande et du contrôleur validée
---------------------------------------------

La commande finale utilisée sur v72 a été générée à partir des enregistrements
d'état de configuration de sa **propre image empaquetée**. Les 27 octets sont :

.. code-block:: text

   DB 0C B8 7E 17 10 00 20 04 01 00 00 00 00 00 00
   5D 31 00 00 00 00 33 00 00 00 00

Cette commande est une référence de reproductibilité **uniquement pour l'image
v72**. Elle ne doit pas être codée en dur dans le bitstream SERV final à
48 MHz. La transformation dérivée de TinyDFU efface les bits pertinents de
commande de configuration et de propriété des E/S utilisateur, active les
indicateurs requis d'horloge autonome et recalcule les deux CRC. L'image finale
empaquetée doit être auditée à nouveau en regard de la ROM intégrée.

Le séquenceur v72 ``CC_CFG_CTRL`` utilise ``EN``, ``VALID`` et ``DATA``
enregistrés, avec au moins trois cycles d'avance pour EN, au moins un cycle
inactif entre les octets valides, au moins huit cycles EN à l'état haut après
le dernier octet, puis un intervalle de repos de 16 comptes avec EN à l'état
bas avant l'activation de ``RECFG``. La section 7.6 d'UG1001 de Cologne Chip
décrit l'avance EN, l'intervalle interoctets et la séquence finale EN haute.
TinyDFU fournit en complément une référence pour la machine à états enregistrée
et l'attente de repos. L'essai matériel réussi démontre le fonctionnement de
cette séquence combinée sur cette carte, sans prouver que chaque délai est
minimal.

Limites de l'intégration en production
--------------------------------------

Le micrologiciel SERV actuel comporte déjà une sonde en lecture seule du secteur
natif v41 (``fw/ulx5m_spi_active_boot.c``), un callback de libération du flash
et des requêtes Wishbone ARM/BOOT. Le RTL Wishbone de
``rtl/ulx5m_spi_active_reboot_wb.v`` ne câble actuellement ``CC_CFG_CTRL`` que
pour **RECFG** (CLK/EN/VALID/DATA reliés au niveau bas). Il faut le remplacer
par la séquence de commande enregistrée v72 validée, sans changer l'interface
publique d'état ARM/BOOT ni supprimer le contrôle CRC du secteur effectué par
le micrologiciel. Une écriture vers BOOT signifie *requête acceptée*, pas
confirmation du transfert d'exécution.

Séquence nécessaire pour la version intégrée :

#. Conserver exactement le verrouillage BTN2 au démarrage : maintenir BTN2
   lors de la mise sous tension sélectionne DFU, et le relâcher après
   énumération ne doit **pas** désactiver DFU. Le chemin normal ne doit jamais
   émettre de commande en fonctionnement si le mode DFU a été verrouillé.
#. En mode normal, conserver la validation en lecture seule du secteur natif
   v41 secondaire à ``0x201000`` ; ne pas confondre l'ancien emballage de
   test U5IM à ``0x200000`` avec l'entrée du bitstream brut v41.
#. Attendre l'inactivité du contrôleur flash et libérer physiquement les six
   broches flash de leurs pilotes FPGA avant d'émettre la commande de
   configuration. Conserver le protocole Wishbone ARM/BOOT ; la nouvelle
   machine à états ne s'exécute qu'après BOOT.
#. Intégrer la machine à états enregistrée v72 d'émission des octets dans le
   périphérique Wishbone. L'horloger avec la **véritable** horloge du
   contrôleur intégré (nominalement 48 MHz), et non celle de la sonde v72
   à 25 MHz. Modéliser l'état et un reset sûr en cas d'échec.
#. Produire un primaire final empaqueté avec ``--reconfig`` et
   ``--bootaddr 2101248`` (``0x201000``). Générer la ROM de 27 octets
   depuis cette image finale exacte. Itérer synthèse, placement/routage,
   empaquetage et vérification de la commande dérivée jusqu'à un point fixe
   exact et borné. Rejeter ROM périmée, CRC erroné, mauvaise adresse de
   démarrage, régression de propriété des broches, bits d'horloge manquants
   ou absence de convergence.
#. Tester la poignée de main Wishbone intégrée, le passage des broches en
   haute impédance, les signaux EN/VALID, la ROM finale empaquetée, la lecture
   du secteur natif entier, l'isolation DFU et le comportement USB. Effectuer
   le routage local à **48 MHz** avec la chaîne d'outils figée ; le succès de
   la sonde v72 minimale à 25 MHz ne valide pas cette conception.
#. Conserver les sauvegardes intégrales de flash v63c et v72, employer la
   procédure établie d'installation/vérification/restauration JTAG protégée
   pour tout candidat et ne modifier aucun secteur secondaire protégé.
   L'acceptation physique exige à la fois un démarrage normal à froid avec
   LED défilantes et un démarrage DFU à froid avec BTN2 maintenu, suivi de
   l'énumération persistante ``1D50:614B`` **après relâchement de BTN2**,
   puis de contrôles en lecture seule et d'essais d'écriture DFU
   expressément autorisés.

Ceci constitue un plan d'intégration technique, **pas** une autorisation de
programmer un candidat combiné. v72 ne dispose pas de DFU et aucun candidat
combiné à 48 MHz n'est encore qualifié. Si la sonde v72 est conservée pour
faire des mesures, ne revendiquez pas de récupération USB. Restaurez le
primaire v63c exact grâce à la session JTAG conservée avant de reprendre le
développement DFU ordinaire.

Références
----------

* `Source TinyDFU ULX5M <https://github.com/pu-cc/tinydfu-bootloader/tree/master/boards/ulx5m>`_
  (``mkcmd.py`` et contrôleur enregistré dans ``tinydfu_ulx5m.v``).
* `Cologne Chip UG1001 section 7.6 <https://www.colognechip.com/docs/ug1001-gatemate1-primitives-library-latest.pdf>`_
  (contraintes ``CC_CFG_CTRL``).
* Sources, essais et outils v72 locaux dans ``bootloader-serv/`` ; fichier
  ``manifest.json`` de la session v72c locale et LED observées indépendamment.

Suite de l'intégration SERV/DFU v73 (28 octobre 2026)
-----------------------------------------------------

Le primaire v72 peut rester installé pendant la construction hors ligne du
candidat combiné v73 ; la restauration v63c n'est pas nécessaire pour le
développement. v72 ne possède pas d'USB DFU : la récupération repose encore
sur JTAG jusqu'à ce qu'un candidat intégré réussisse les deux modes
d'acceptation physique. La construction v73 reproduit la commande d'état
enregistrée connue à partir du **primaire SERV combiné final**, et non de la
ROM v72, et ne produit qu'un candidat expérimental empaqueté. Ne le programmez
pas tant qu'un nouvel installateur A/B à empreinte SHA figée n'a pas été
qualifié pour l'état actuel du flash v72. Voir
``bootloader-serv/README_ULX5M_GS_V73_INTEGRATION_20261028.md`` pour les
étapes locales de construction et d'acceptation.
