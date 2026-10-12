Format d'image exécutable H3IMG
================================

H3IMG est le format d'image exécutable utilisé par le moniteur résident de
Hazard3-Doom. Les fichiers portent l'extension ``.h3img``. Le fichier IWAD de
Doom (``DOOM.WAD``) est transféré séparément.

Structure du fichier
--------------------

Un fichier H3IMG contient un en-tête binaire de **64 octets**, suivi des octets
de l'exécutable. L'en-tête indique l'adresse de chargement, le point d'entrée
et la plage BSS.

.. code-block:: text

   Décalage
   0x0000       En-tête H3IMG de 64 octets
   0x0040       Données exécutables (taille définie par l'en-tête)
   ...          Fin du fichier

L'identifiant est ``H3I1`` (octets ASCII ``48 33 49 31``), soit
``0x31493348`` comme entier 32 bits petit-boutiste.

Champs de l'en-tête
-------------------

.. list-table::
   :header-rows: 1
   :widths: 28 72

   * - Champ
     - Fonction
   * - Magic
     - Identifie le format et sa version (``H3I1``).
   * - Adresse de chargement
     - Adresse SDRAM où copier les données exécutables.
   * - Taille des données
     - Nombre d'octets exécutables après l'en-tête.
   * - Adresse d'entrée
     - Adresse utilisée lors du lancement de l'application.
   * - Adresse BSS
     - Début de la zone de données non initialisées.
   * - Taille BSS
     - Taille en octets de cette zone.
   * - CRC32 des données
     - Vérifie l'intégrité des données exécutables.

.. important::

   Cette liste ne définit pas les décalages de tous les champs. Pour créer un
   fichier compatible, vérifier la disposition complète, l'encodage, les
   paramètres CRC32 et les contraintes de mémoire dans le code du moniteur
   et du programme de création correspondant à la version utilisée.

Mémoire et compatibilité
------------------------

Le moniteur charge l'image dans la SDRAM configurée. Les adresses du code,
de la BSS et du point d'entrée doivent correspondre à sa carte mémoire.
Les profils ``32m`` et ``64m`` sont distincts. Le chargement n'exécute pas
l'application : la commande ``j`` du moniteur la lance.

H3IMG n'est pas un fichier ELF. Il ne transporte ni les tables de symboles,
ni les relocalisations, ni les informations de débogage ELF.

Transfert UART (H3L)
--------------------

L'outil Web Device Tool utilise le protocole H3L. Le moniteur doit afficher
l'invite ``>`` avant le transfert.

.. code-block:: text

   navigateur -> l
   moniteur   -> H3L READY
   navigateur -> en-tête H3IMG (64 octets)
   moniteur   -> H3L DATA
   navigateur -> données exécutables
   moniteur   -> H3L OK

Le navigateur vérifie l'en-tête, la longueur du fichier et le CRC32 avant
l'envoi. Le transfert écrit en SDRAM, pas sur la carte SD. Un chargement H3IMG
depuis la carte SD est également pris en charge.

Voir :doc:`../user-guide/web-tool`, :doc:`../user-guide/monitor` et
:doc:`../user-guide/sd-card`.

Implémentation
--------------

Le moniteur et les outils de création et de transfert de la même révision du
dépôt font autorité. La compatibilité avec des versions futures n'est pas
garantie.

* `Dépôt Hazard3-Doom <https://github.com/ulx3s/Hazard3-Doom>`_
* `Branche de développement <https://github.com/gojimmypi/Hazard3-Doom/tree/develop>`_
