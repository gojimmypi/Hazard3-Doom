Contraintes de broches, schémas et révisions
=============================================

Un nom de signal devient du matériel réel au travers d'une chaîne d'artefacts.
Comprendre cette chaîne est l'une des leçons les plus transférables du
développement FPGA.


Du net du schéma au port Verilog
--------------------------------

.. code-block:: text

   net du schéma de la carte
        |
        v
   piste PCB / bille du boîtier FPGA
        |
        v
   contrainte LPF LOCATE + IOBUF
        |
        v
   port Verilog de niveau supérieur
        |
        v
   module / périphérique du projet
        |
        v
   comportement visible par le logiciel

Par exemple, une horloge SD n'est pas « la broche d'horloge SD » simplement
parce que le signal Verilog s'appelle ``sd_clk``. Elle ne devient la bonne
horloge SD que lorsque le LPF correspondant associe ce port à la bille du
boîtier que la révision de PCB sélectionnée relie au signal du socket/de la
carte porteuse.

.. figure:: ../../images/ulx4m_ld-pinout.png
   :alt: Brochage ULX4M-LD

   **Brochage ULX4M-LD** - affectations des broches FPGA sur la
   `carte porteuse Waveshare CM4 <https://www.waveshare.com/wiki/CM4-IO-BASE-A#Dimension>`_.

Fichiers de contraintes Hazard3-Doom
------------------------------------

Les fichiers importants du projet comprennent :

.. code-block:: text

   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld.lpf
   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ld_v002.lpf
   third_party/Hazard3/example_soc/synth/fpga_ulx4m_ls.lpf
   bootloader/data/top-ulx4m-v002.lpf

Le SoC Doom et le bootloader DFU sont deux conceptions FPGA différentes ; ils
n'exposent donc pas nécessairement les mêmes noms de signaux de niveau supérieur,
même lorsqu'ils ciblent la même carte physique.

Le LPF LD contient bien plus que les emplacements : il applique les types d'E/S
SSTL DDR3, les réglages de terminaison/différentiels, les informations de
fréquence de l'oscillateur, les contraintes LVCMOS ordinaires et les affectations
de broches propres à la carte. Considérez-le comme une documentation matérielle
exécutable.
Discipline de révision
----------------------

Pour chaque carte ULX4M, enregistrez : variante LS/LD, révision PCB, référence
complète du FPGA et population mémoire. Deux cartes « ULX4M-LD » peuvent exiger
des profils DDR3 différents.

Lorsque des sources amont se contredisent, conservez le désaccord et recherchez
sa cause : prototype, révision ancienne, BOM alternatif, branche différente ou
retard documentaire. Crowd Supply, par exemple, décrit une LD Micron
``MT41K512M16HA-125`` 1 GiB, tandis qu'un manuel amont mentionne
``MT41K256M16TW-107`` 512 MiB; Hazard3-Doom prend aussi en charge un profil
Alliance ``AS4C256M16D3``.


Les divergences entre sources sont des données
----------------------------------------------

Lorsque deux sources amont se contredisent, ne masquez pas la divergence.
Consignez-la et recherchez-en la cause : ancienne révision, prototype contre
production, BOM alternatif, branche différente ou retard de documentation.

Le projet possède actuellement un exemple concret. La page Crowd Supply décrit
une configuration LD Micron ``MT41K512M16HA-125`` de 1 Gio, tandis qu'une page
du manuel LD amont indique ``MT41K256M16TW-107`` de 512 Mio ; Hazard3-Doom prend
en outre en charge un profil Alliance ``AS4C256M16D3``. Le bon choix de build
est le composant présent sur la carte réelle, et non la première page web ouverte.

Utilisation de la copie locale du schéma
----------------------------------------

Le dépôt contient une copie locale du PDF du schéma ULX4M pour référence pendant
le développement :

:download:`Schémas ULX4M (copie locale) <ULX4M-LS-v0.0.3.pdf>`

Il contient également la fiche technique DDR3 Alliance utilisée lors du travail
sur la mémoire alternative :

:download:`Fiche technique Alliance AS4C256M16D3 (copie locale) <../../AllianceMemory_4G_DDR3_AS4C256M16D3C_May2020_Rev1.1_Final.pdf>`

Ces fichiers sont des références utiles, mais la provenance de la branche/de la
révision reste importante. La présence d'un PDF dans le dépôt ne prouve pas que
toutes les cartes physiques correspondent à cette révision de schéma.

Liste de contrôle avant de modifier une broche
----------------------------------------------

#. Identifiez exactement la carte cible et sa révision.
#. Trouvez le signal dans le schéma correspondant.
#. Confirmez la bille du boîtier FPGA et la banque d'E/S.
#. Vérifiez la tension et la norme d'E/S requises.
#. Modifiez le bon LPF, pas un fichier prototype au nom similaire.
#. Confirmez la direction et la largeur du port Verilog de niveau supérieur.
#. Construisez en prenant les avertissements au sérieux.
#. Testez la fonction physique sur le matériel.
#. Si la modification affecte un bus partagé, vérifiez la propriété et les états
   au repos.
#. Consignez la révision/le profil utilisé pour le résultat de validation.

Ce processus est plus lent que de copier un numéro de broche depuis un forum,
mais bien plus rapide que de déboguer plus tard une conception électriquement
impossible.

Ressources ULX4M externes
-------------------------

* `Documentation ULX4M <https://github.com/intergalaktik/ulx4m-documentation>`_
* `Dépôt matériel ULX4M <https://github.com/intergalaktik/ulx4m>`_
* `Projet ULX4M et notes de compatibilité des cartes porteuses <https://www.crowdsupply.com/intergalaktik/ulx4m/updates/pre-launch-progress>`_
* `Documentation Raspberry Pi Compute Module <https://www.raspberrypi.com/documentation/computers/compute-module.html>`_
* `Schéma Waveshare CM4-IO-BASE-A <https://files.waveshare.com/upload/a/aa/CM4-IO-BASE-A_V4_SchDoc.pdf>`_

* `Certification Open Source Hardware ULX4M <https://certification.oshwa.org/hr000013.html>`_
