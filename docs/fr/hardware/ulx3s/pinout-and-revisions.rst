Contraintes de broches, schémas et révisions PCB
================================================

Un signal ULX3S traverse plusieurs artefacts :

.. figure:: ../../images/ulx3s-pinout.png
   :alt: Brochage ULX3S

   **Brochage ULX3S** - affectations des GPIO FPGA et des broches des connecteurs.

Le flux ULX3S Tiny Tapeout réutilisable possède son propre LPF sous
``tt/fpga/ulx3s/``. Ne modifiez pas un fichier de contraintes en supposant que
tous les autres builds ULX3S l'utilisent. Consultez
:doc:`../../getting-started/tiny-tapeout-ulx3s` pour ce flux séparé.

.. code-block:: text

   net du schéma -> piste PCB/bille ECP5 -> contrainte LPF -> port Verilog -> périphérique

Le nom du signal Verilog ne suffit donc pas ; le LPF actif doit correspondre au
PCB réel.

Sources de contraintes du projet
---------------------------------

L'implémentation ULX3S principale se trouve dans le sous-module Hazard3 sous
``example_soc/fpga/`` et ``example_soc/synth/``. Le workflow ULX3S Tiny Tapeout
possède un LPF séparé sous ``tt/fpga/ulx3s/`` ; ne modifiez pas l'un en supposant
que tous les builds consomment le même fichier.


.. code-block:: text

   third_party/Hazard3/example_soc/fpga/
   third_party/Hazard3/example_soc/synth/

Schémas amont révisionnés
-------------------------

Le dépôt ULX3S conserve des PDF de schémas pour plusieurs révisions :

* `v3.0.8 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v308.pdf>`_
* `v3.1.4 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v314.pdf>`_
* `v3.1.6 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v316.pdf>`_
* `v3.1.7 <https://github.com/emard/ulx3s/blob/master/doc/schematics_v317.pdf>`_

Si des copies locales sont ajoutées dans ce dossier, conservez la révision PCB
dans le nom de fichier, par exemple ``ULX3S-v3.1.7-schematics.pdf``. Un nom comme ``ULX3S-v3.1.7-schematics.pdf`` est beaucoup moins ambigu que ``ulx3s-schematics.pdf``.

Attention à la numérotation des connecteurs
--------------------------------------------

Les commentaires de contraintes amont distinguent les connecteurs femelles
coudés des connecteurs mâles verticaux pour l'interprétation des broches
``GP``/``GN``. Pour l'UART testé par Hazard3-Doom :

.. code-block:: text

   J1 broche 6 / GP0 -> TxD Hazard3
   J1 broche 8 / GP1 -> RxD Hazard3

Avant toute modification de broche, identifiez la révision PCB, le FPGA, le
schéma correspondant, la bille ECP5, le domaine d'E/S, le LPF réellement utilisé
et tout partage avec ESP32/ADC/SD, puis validez sur le matériel.

Discipline de révision
----------------------

Avant de modifier une broche ULX3S ou une interface propre à la carte :

#. Identifiez la révision du PCB.
#. Identifiez la densité/le boîtier ECP5 monté.
#. Trouvez le signal dans le schéma correspondant.
#. Confirmez la bille du boîtier et la banque d'E/S.
#. Vérifiez la tension et la norme d'E/S requises.
#. Identifiez le LPF consommé par le wrapper exact du build.
#. Confirmez la direction et la largeur du port Verilog de niveau supérieur.
#. Vérifiez si le signal est partagé avec l'ESP32, l'ADC, la SD ou un autre
   périphérique.
#. Construisez le projet et examinez les avertissements/le timing.
#. Validez la fonction physique sur le matériel.

Cette discipline rend visibles les différences de schéma/contraintes au lieu de
les masquer dans un numéro de broche copié localement.
