Doprinos dokumentaciji
======================

Lokalni build dokumentacije
---------------------------

Izradite zasebno virtualno okruženje:

.. code-block:: bash

   python3 -m venv .venv-docs
   source .venv-docs/bin/activate
   python -m pip install -r docs/requirements.txt
   python -m sphinx -W --keep-going -b html docs docs/_build/html

U PowerShellu:

.. code-block:: powershell

   py -m venv .venv-docs
   .\.venv-docs\Scripts\Activate.ps1
   py -m pip install -r .\docs\requirements.txt
   py -m sphinx -W --keep-going -b html .\docs .\docs\_build\html

Nakon uspješnog builda otvorite ``docs/_build/html/index.html``.

Pravila dokumentacije
---------------------

* Preferirajte naredbe kopirane iz trenutačnih skripti umjesto parafrazirane shell sintakse.
* Držite hardverske adrese i memorijske mape usklađene s prikvačenim Hazard3 submodulom.
* Jasno označite značajke dostupne samo na određenoj grani ili eksperimentalne značajke.
* Ne uključujte komercijalni IWAD sadržaj.
* Ožičenje specifično za pločicu držite u odjeljcima za tu pločicu.
* Dodajte stavke za otklanjanje poteškoća kada način kvara ima ponovljivu dijagnozu.
* Prevedeni tekst namijenjen ljudima pod ``docs/<language>/`` je u UTF-8 i treba zadržati izvorne znakove potrebne za taj jezik. Izvorni kod, skripte, CI, nazive datoteka, doslovne naredbe, identifikatore, putanje, protokolarne nizove i drugi tekst namijenjen strojevima ostavite nepromijenjenima osim ako se samo sučelje doista promijeni.

Objavljivanje na Read the Docs
------------------------------

Datoteka ``.readthedocs.yaml`` u korijenu repozitorija usmjerava Read the Docs
na ``docs/conf.py`` i instalira ``docs/requirements.txt``. Nakon commita
datoteka uvezite GitHub repozitorij u Read the Docs i odaberite granu/verziju
koju želite objaviti.
