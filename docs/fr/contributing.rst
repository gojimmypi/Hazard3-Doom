Contribuer à la documentation
=============================

Build local de la documentation
-------------------------------

Créez un environnement virtuel dédié :

.. code-block:: bash

   python3 -m venv .venv-docs
   source .venv-docs/bin/activate
   python -m pip install -r docs/requirements.txt
   python -m sphinx -W --keep-going -b html docs docs/_build/html

Sous PowerShell :

.. code-block:: powershell

   py -m venv .venv-docs
   .\.venv-docs\Scripts\Activate.ps1
   py -m pip install -r .\docs\requirements.txt
   py -m sphinx -W --keep-going -b html .\docs .\docs\_build\html

Ouvrez ``docs/_build/html/index.html`` après un build réussi.

Règles de documentation
-----------------------

* Préférez les commandes copiées depuis les scripts actuels plutôt qu'une reformulation de la syntaxe shell.
* Gardez les adresses matérielles et les cartographies mémoire synchronisées avec le sous-module Hazard3 épinglé.
* Identifiez explicitement les fonctionnalités propres à une branche ou expérimentales.
* N'incluez aucun contenu d'IWAD commercial.
* Conservez le câblage spécifique à une carte dans les sections propres à cette carte.
* Ajoutez une entrée de dépannage lorsqu'un mode de panne possède un diagnostic reproductible.
* Le texte humain traduit sous ``docs/<language>/`` est en UTF-8 et doit conserver les caractères natifs de la langue. Gardez inchangés le code source, les scripts, la CI, les noms de fichiers, les commandes littérales, les identifiants, les chemins, les chaînes de protocole et les autres textes destinés aux machines, sauf si l'interface correspondante change réellement.

Publication sur Read the Docs
-----------------------------

Le fichier ``.readthedocs.yaml`` à la racine du dépôt indique à Read the Docs d'utiliser ``docs/conf.py`` et d'installer ``docs/requirements.txt``. Après validation des fichiers, importez le dépôt GitHub dans Read the Docs et sélectionnez la branche/version à publier.
